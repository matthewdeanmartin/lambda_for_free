package com.example.interviews.controller;

import com.example.interviews.models.PendingRequest;
import com.example.interviews.models.SendRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
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

    private SqsClient sqs;
    private DynamoDbClient dynamo;
    private final String queueUrl;
    private final String tableName;
    private final String region;

    public MessageController(
            @Value("${app.sqs.queue-url}") String queueUrl,
            @Value("${app.dynamo.table-name}") String tableName,
            @Value("${aws.region:us-east-2}") String region
    ) {
        this.region = region;
        this.queueUrl = queueUrl;
        this.tableName = tableName;
    }

    private void create_clients() {
        this.sqs = SqsClient.builder()
                .region(Region.of(this.region))
                // .credentialsProvider(DefaultCredentialsProvider.create())
                .build();

        this.dynamo = DynamoDbClient.builder()
                .region(Region.of(this.region))
                // .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }

    /** 1) Send a message */
    @PostMapping
    public ResponseEntity<Void> send(@RequestBody SendRequest req) {
        create_clients();
        String messageId = UUID.randomUUID().toString();
        long now = Instant.now().toEpochMilli();

        Map<String, AttributeValue> requestItem = Map.of(
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
        create_clients();
        QueryResponse qr = dynamo.query(QueryRequest.builder()
                .tableName(tableName)
                .keyConditionExpression("MessageId = :mid")
                .expressionAttributeValues(Map.of(
                        ":mid", AttributeValue.builder().s(id).build()
                ))
                .build());

        Map<String, AttributeValue> requestItem = qr.items().stream()
                .filter(item -> "REQUEST".equals(item.get("RecordType").s()))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("No such request"));

        if (!ownerId.equals(requestItem.get("ownerId").s())) {
            return ResponseEntity.status(404).build();
        }

        boolean isCancelled = qr.items().stream()
                .anyMatch(item -> "CANCELLED".equals(item.get("RecordType").s()));
        if (isCancelled) {
            batchDelete(id, List.of("REQUEST", "CANCELLED"));
            Map<String, String> body = Map.of("status", "CANCELLED");
            return ResponseEntity
                    .ok()
                    .header("Content-Location", "/messages/" + id)
                    .body(body);
        }

        Optional<Map<String, AttributeValue>> resultOpt = qr.items().stream()
                .filter(item -> "RESULT".equals(item.get("RecordType").s()))
                .findFirst();
        if (resultOpt.isEmpty()) {
            Map<String, String> body = Map.of("status", "PENDING");
            return ResponseEntity
                    .accepted()
                    .header("Retry-After", String.valueOf(RETRY_AFTER_SECONDS))
                    .body(body);
        }

        Map<String, AttributeValue> resultItem = resultOpt.get();
        String error = resultItem.containsKey("error") ? resultItem.get("error").s() : null;
        Map<String, Object> resultData = Map.of(
                "resultData", resultItem.getOrDefault("resultData", AttributeValue.builder().nul(true).build()).s(),
                "completedAt", Long.parseLong(resultItem.get("completedAt").n())
        );

        batchDelete(id, List.of("REQUEST", "RESULT"));

        Object responseBody = (error != null)
                ? Map.<String, Object>of("error", error)
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
        create_clients();
        Map<String, AttributeValue> reqItem = dynamo.getItem(GetItemRequest.builder()
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

        long now = Instant.now().toEpochMilli();
        Map<String, AttributeValue> cancelItem = Map.of(
                "MessageId",   AttributeValue.builder().s(id).build(),
                "RecordType",  AttributeValue.builder().s("CANCELLED").build(),
                "ownerId",     AttributeValue.builder().s(ownerId).build(),
                "cancelledAt", AttributeValue.builder().n(Long.toString(now)).build()
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
        create_clients();
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
        create_clients();
        List<WriteRequest> deletes = types.stream()
                .map(type -> Map.<String, AttributeValue>of(
                        "MessageId", AttributeValue.builder().s(messageId).build(),
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
