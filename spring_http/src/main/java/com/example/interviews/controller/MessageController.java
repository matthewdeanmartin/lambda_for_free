package com.example.interviews.controller;
// MessageController.java
import com.example.interviews.models.PendingRequest;
import com.example.interviews.models.SendRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.*;

import java.net.URI;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/messages")
public class MessageController {

    private static final int RETRY_AFTER_SECONDS = 5;

    private final SqsClient sqs;
    private final DynamoDbClient dynamo;
    private final String queueUrl;
    private final String tableName;

    public MessageController(
            SqsClient sqs,
            DynamoDbClient dynamo,
            @Value("${app.sqs.queue-url}") String queueUrl,
            @Value("${app.dynamo.table-name}") String tableName
    ) {
        this.sqs = sqs;
        this.dynamo = dynamo;
        this.queueUrl = queueUrl;
        this.tableName = tableName;
    }

    /** 1) Send a message */
    @PostMapping
    public ResponseEntity<Void> send(@RequestBody SendRequest req) {
        String messageId = UUID.randomUUID().toString();
        long now = Instant.now().toEpochMilli();

        // Write REQUEST item with ownerId
        Map<String,AttributeValue> requestItem = Map.of(
                "MessageId",  AttributeValue.builder().s(messageId).build(),
                "RecordType", AttributeValue.builder().s("REQUEST").build(),
                "ownerId",    AttributeValue.builder().s(req.ownerId()).build(),
                "payload",    AttributeValue.builder().s(req.payload()).build(),
                "createdAt",  AttributeValue.builder().n(Long.toString(now)).build()
        );
        dynamo.putItem(PutItemRequest.builder()
                .tableName(tableName)
                .item(requestItem)
                .build());

        // Send to SQS, include MessageId and OwnerId as message attributes
        sqs.sendMessage(SendMessageRequest.builder()
                .queueUrl(queueUrl)
                .messageBody(req.payload())
                .messageAttributes(Map.of(
                        "MessageId", MessageAttributeValue.builder()
                                .dataType("String")
                                .stringValue(messageId)
                                .build(),
                        "OwnerId", MessageAttributeValue.builder()
                                .dataType("String")
                                .stringValue(req.ownerId())
                                .build()
                ))
                .build());

        // 202 Accepted + Location header
        URI location = URI.create("/messages/" + messageId);
        return ResponseEntity
                .accepted()
                .location(location)
                .build();
    }

    /** 2) Poll status (or get final result) */
    @GetMapping("/{id}")
    public ResponseEntity<Object> status(
            @PathVariable String id,
            @RequestHeader("X-Owner-Id") String ownerId
    ) {
        // Fetch both REQUEST, RESULT, CANCELLED items
        QueryResponse qr = dynamo.query(QueryRequest.builder()
                .tableName(tableName)
                .keyConditionExpression("MessageId = :mid")
                .expressionAttributeValues(Map.of(
                        ":mid", AttributeValue.builder().s(id).build()
                ))
                .build());

        // Ensure request exists and owner matches
        Map<String,AttributeValue> requestItem = qr.items().stream()
                .filter(item -> "REQUEST".equals(item.get("RecordType").s()))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("No such request"));
        if (!ownerId.equals(requestItem.get("ownerId").s())) {
            return ResponseEntity.status(404).build();
        }

        // Check for cancellation
        boolean isCancelled = qr.items().stream()
                .anyMatch(item -> "CANCELLED".equals(item.get("RecordType").s()));
        if (isCancelled) {
            // Clean up REQUEST + CANCELLED
            batchDelete(id, List.of("REQUEST", "CANCELLED"));
            Map<String,String> body = Map.of("status", "CANCELLED");
            return ResponseEntity
                    .ok()
                    .header("Content-Location", "/messages/" + id)
                    .body(body);
        }

        // Check for RESULT
        Optional<Map<String,AttributeValue>> resultOpt = qr.items().stream()
                .filter(item -> "RESULT".equals(item.get("RecordType").s()))
                .findFirst();
        if (resultOpt.isEmpty()) {
            // Still pending → 202 + Retry-After
            Map<String,String> body = Map.of("status", "PENDING");
            return ResponseEntity
                    .accepted()
                    .header("Retry-After", String.valueOf(RETRY_AFTER_SECONDS))
                    .body(body);
        }

        // Final result → extract resultData & error
        Map<String,AttributeValue> resultItem = resultOpt.get();
        String error = resultItem.containsKey("error") ? resultItem.get("error").s() : null;
        Map<String,Object> resultData = Map.of(
                "resultData", resultItem.getOrDefault("resultData", AttributeValue.builder().nul(true).build()).s(),
                "completedAt", Long.parseLong(resultItem.get("completedAt").n())
        );

        // Clean up REQUEST + RESULT
        batchDelete(id, List.of("REQUEST", "RESULT"));

        // 200 OK + result body + Content-Location
        Object responseBody = (error != null)
                ? Map.<String,Object>of("error", error)
                : resultData;

        return ResponseEntity
                .ok()
                .header("Content-Location", "/messages/" + id)
                .body(responseBody);
    }

    /** 3) Cancel a pending request */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> cancel(
            @PathVariable String id,
            @RequestHeader("X-Owner-Id") String ownerId
    ) {
        // Verify ownership
        Map<String,AttributeValue> reqItem = dynamo.getItem(GetItemRequest.builder()
                        .tableName(tableName)
                        .key(Map.of(
                                "MessageId", AttributeValue.builder().s(id).build(),
                                "RecordType", AttributeValue.builder().s("REQUEST").build()
                        ))
                        .build())
                .item();
        if (reqItem == null || !ownerId.equals(reqItem.get("ownerId").s())) {
            return ResponseEntity.status(404).build();
        }

        // Write CANCELLED record
        long now = Instant.now().toEpochMilli();
        Map<String,AttributeValue> cancelItem = Map.of(
                "MessageId",  AttributeValue.builder().s(id).build(),
                "RecordType", AttributeValue.builder().s("CANCELLED").build(),
                "ownerId",    AttributeValue.builder().s(ownerId).build(),
                "cancelledAt",AttributeValue.builder().n(Long.toString(now)).build()
        );
        dynamo.putItem(PutItemRequest.builder()
                .tableName(tableName)
                .item(cancelItem)
                .build());

        return ResponseEntity.noContent().build();
    }

    /** 4) List in-flight (pending) requests for this owner */
    @GetMapping
    public ResponseEntity<List<PendingRequest>> listInflight(
            @RequestHeader("X-Owner-Id") String ownerId
    ) {
        // NOTE: for production, create a GSI on ownerId+RecordType rather than scan
        ScanResponse sr = dynamo.scan(ScanRequest.builder()
                .tableName(tableName)
                .filterExpression("ownerId = :oid AND RecordType = :req")
                .expressionAttributeValues(Map.of(
                        ":oid", AttributeValue.builder().s(ownerId).build(),
                        ":req", AttributeValue.builder().s("REQUEST").build()
                ))
                .build());

        List<PendingRequest> pending = sr.items().stream()
                .map(item -> new PendingRequest(
                        item.get("MessageId").s(),
                        Long.parseLong(item.get("createdAt").n())
                ))
                .collect(Collectors.toList());

        return ResponseEntity.ok(pending);
    }

    /** Helper to batch‐delete the REQUEST, RESULT, CANCELLED items by MessageId */
    private void batchDelete(String messageId, List<String> types) {
        List<WriteRequest> deletes = types.stream()
                .map(type -> Map.<String,AttributeValue>of(
                        "MessageId",  AttributeValue.builder().s(messageId).build(),
                        "RecordType", AttributeValue.builder().s(type).build()
                ))
                .map(key -> WriteRequest.builder()
                        .deleteRequest(DeleteRequest.builder().key(key).build())
                        .build())
                .toList();

        dynamo.batchWriteItem(BatchWriteItemRequest.builder()
                .requestItems(Map.of(tableName, deletes))
                .build());
    }

    /** Simple 404 Exception */
    @ResponseStatus(code = org.springframework.http.HttpStatus.NOT_FOUND)
    public static class ResourceNotFoundException extends RuntimeException {
        public ResourceNotFoundException(String msg) { super(msg); }
    }
}
