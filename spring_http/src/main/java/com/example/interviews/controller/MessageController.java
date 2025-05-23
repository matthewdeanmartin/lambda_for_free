package com.example.interviews.controller;

import com.example.interviews.models.PendingRequest;
import com.example.interviews.models.SendRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.*;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.MessageAttributeValue;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;
import software.amazon.awssdk.services.sqs.model.SendMessageResponse;

import java.net.URI;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
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
        System.out.println("MessageController constructor running");
        this.region = region;
        this.queueUrl = queueUrl;
        this.tableName = tableName;
    }

    private void create_clients() {
        System.out.println("Creating Sqs Client");
//        this.sqs = SqsClient.builder()
//                .region(Region.of(this.region))
//                // .credentialsProvider(DefaultCredentialsProvider.create())
//                .build();

        this.sqs = SqsClient.builder()
//                .credentialsProvider(SdkSystemSetting.AWS_CONTAINER_CREDENTIALS_FULL_URI
//                        .getStringValue()
//                        .isPresent()
//                        ? ContainerCredentialsProvider.builder().build()
//                        : EnvironmentVariableCredentialsProvider.create())
                .region(Region.of(this.region))
                .build();
        System.out.println("Creating DynmoDB Client");
//        this.dynamo = DynamoDbClient.builder()
//                .region(Region.of(this.region))
//                // .credentialsProvider(DefaultCredentialsProvider.create())
//                .build();
        // SdkSystemSetting.AWS_REGION.getStringValueOrThrow()
        this.dynamo = DynamoDbClient.builder()
//                .credentialsProvider(SdkSystemSetting.AWS_CONTAINER_CREDENTIALS_FULL_URI
//                        .getStringValue()
//                        .isPresent()
//                        ? ContainerCredentialsProvider.builder().build()
//                        : EnvironmentVariableCredentialsProvider.create())
                .region(Region.of(this.region))
                .build();
        System.out.println("Done creating Clients");
    }

    /**
     * 1) Send a message
     */
    @PostMapping
    public ResponseEntity<Void> send(@RequestBody SendRequest req) {
//        if (!req.ownerId().equals("matt")) {
//            System.out.println("Wrong owner: " + req.ownerId());
//            System.out.println(req);
//
//            URI location = URI.create("/nowhere/");
//            return ResponseEntity
//                    .accepted()
//                    .location(location)
//                    .build();
//        }

        System.out.println("Sending request: " + req);
        create_clients();
        String messageId = UUID.randomUUID().toString();
        long now = Instant.now().toEpochMilli();


        SendMessageResponse response = sqs.sendMessage(SendMessageRequest.builder()
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
                                .build(),
                        "Payload", MessageAttributeValue.builder()
                                .dataType("String")
                                .stringValue(req.payload())
                                .build()
                ))
                .build());

        Map<String, AttributeValue> requestItem = Map.of(
                "MessageId", AttributeValue.builder().s(response.messageId()).build(),
                "RecordType", AttributeValue.builder().s("REQUEST").build(),
                "ownerId", AttributeValue.builder().s(req.ownerId()).build(),
                "payload", AttributeValue.builder().s(req.payload()).build(),
                "createdAt", AttributeValue.builder().n(Long.toString(now)).build()
        );


        dynamo.putItem(PutItemRequest.builder()
                .tableName(tableName)
                .item(requestItem)
                .build());

        URI location = URI.create("/messages/" + response.messageId());
        return ResponseEntity
                .accepted()
                .location(location)
                .build();
    }

    /**
     * 2) Poll status (or get final result)
     */
    @GetMapping("/{id}")
    public ResponseEntity<Object> status(
            @PathVariable String id,
            @RequestHeader(value = "X-Owner-Id", required = true) String ownerId
    ) {
        System.out.println("Retrieving status: " + id);
        create_clients();
        System.out.println("About to do query");
        QueryResponse qr = dynamo.query(QueryRequest.builder()
                .tableName(tableName)
                .keyConditionExpression("MessageId = :mid")
                .expressionAttributeValues(Map.of(
                        ":mid", AttributeValue.builder().s(id).build()
                ))
                .build());

        System.out.println("About to iterate and find first");
        Map<String, AttributeValue> requestItem = qr.items().stream()
                .filter(item -> "REQUEST".equals(item.get("RecordType").s()))
                .findFirst()
                .orElseThrow(() -> new ResourceNotFoundException("No such request"));

        System.out.println("Time to check owner Id");
        System.out.println("Incoming header ownerId=" + ownerId);
        System.out.println("DynamoDB item ownerId=" + requestItem.get("ownerId"));

        AttributeValue stored = requestItem.get("ownerId");
        if (stored == null || !ownerId.equals(stored.s())) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        System.out.println("Time to check if cancelled");
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

        System.out.println("Time to check if empty");
        if (resultOpt.isEmpty()) {
            Map<String, String> body = Map.of("status", "PENDING");
            return ResponseEntity
                    .accepted()
                    .header("Retry-After", String.valueOf(RETRY_AFTER_SECONDS))
                    .body(body);
        }

        System.out.println("Wasn't empty, time to return result");
        Map<String, AttributeValue> resultItem = resultOpt.get();

        System.out.println("resultItem = " + resultItem);

        String error = resultItem.containsKey("error") ? resultItem.get("error").s() : null;

        // safely extract the "resultData" string (or null if missing)
        String resultDataValue = Optional.ofNullable(resultItem.get("payload"))
                .map(AttributeValue::s)
                .orElse(null);

        // safely extract the "completedAt" number (or throw if missing)
        String completedAtStr = Optional.ofNullable(resultItem.get("completedAt"))
                .map(AttributeValue::n)
                .orElseThrow(() -> new IllegalStateException("Missing completedAt in DynamoDB RESULT record"));
        long completedAt = Long.parseLong(completedAtStr);

        // build a map without ever passing in null values to Map.of
        Map<String,Object> resultData = Map.of(
                "resultData", resultDataValue != null ? resultDataValue : "",
                "completedAt", completedAt
        );



        System.out.println("Time to delete it all");
        batchDelete(id, List.of("REQUEST", "RESULT"));

        Object responseBody = (error != null)
                ? Map.<String, Object>of("error", error)
                : resultData;

        return ResponseEntity
                .ok()
                .header("Content-Location", "/messages/" + id)
                .body(responseBody);
    }

    /**
     * 3) Cancel a pending request
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> cancel(
            @PathVariable String id,
            @RequestHeader("X-Owner-Id") String ownerId
    ) {
        System.out.println("Cancelling request: " + id);
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
                "MessageId", AttributeValue.builder().s(id).build(),
                "RecordType", AttributeValue.builder().s("CANCELLED").build(),
                "ownerId", AttributeValue.builder().s(ownerId).build(),
                "cancelledAt", AttributeValue.builder().n(Long.toString(now)).build()
        );

        dynamo.putItem(PutItemRequest.builder()
                .tableName(tableName)
                .item(cancelItem)
                .build());

        return ResponseEntity.noContent().build();
    }

    /**
     * 4) List in-flight (pending) requests for this owner
     */
    @GetMapping
    public ResponseEntity<List<PendingRequest>> listInflight(
            @RequestHeader("X-Owner-Id") String ownerId
    ) {
        System.out.println("ListInflight request: " + ownerId);
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

    /**
     * Helper to batch‐delete the REQUEST, RESULT, CANCELLED items by MessageId
     */
    private void batchDelete(String messageId, List<String> types) {
        System.out.println("BatchDelete request: " + messageId);
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

    /**
     * Simple 404 Exception
     */
    @ResponseStatus(code = org.springframework.http.HttpStatus.NOT_FOUND)
    public static class ResourceNotFoundException extends RuntimeException {
        public ResourceNotFoundException(String msg) {
            super(msg);
        }
    }
}
