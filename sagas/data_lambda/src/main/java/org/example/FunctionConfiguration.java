package org.example;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public class FunctionConfiguration implements RequestHandler<Map<String, Object>, String> {

    private static final String TABLE_NAME = System.getenv().getOrDefault("TABLE_NAME", "message-broker");
    private final DynamoDbClient dynamoDbClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public FunctionConfiguration() {
        this.dynamoDbClient = DynamoDbClient.builder()
                .region(Region.of(System.getenv().getOrDefault("AWS_REGION", "us-east-2")))
                .build();
    }

    @Override
    public String handleRequest(Map<String, Object> event, Context context) {
        LambdaLogger logger = context.getLogger();
        logger.log("Received event: " + event);


        if (event.containsKey("Records")) {
            List<Map<String, Object>> records = (List<Map<String, Object>>) event.get("Records");

            for (Map<String, Object> record : records) {
                String messageId = record.get("messageId").toString();
                Map<String, Object> messageAttributes = (Map<String, Object>) record.get("messageAttributes");


                String ownerId = null;
                String payload = null;

                if (messageAttributes != null) {
                    Map<String, Object> ownerAttr = (Map<String, Object>) messageAttributes.get("OwnerId");
                    Map<String, Object> payloadAttr = (Map<String, Object>) messageAttributes.get("Payload");

                    if (ownerAttr != null) {
                        ownerId = (String) ownerAttr.get("stringValue");
                    }
                    if (payloadAttr != null) {
                        payload = (String) payloadAttr.get("stringValue");
                    }
                }

                if (ownerId == null || payload == null) {
                    logger.log("Missing OwnerId or Payload in messageAttributes");
                    throw new IllegalArgumentException("Missing OwnerId or Payload");
                }

                // Build SendRequest manually
                SendRequest sendRequest = new SendRequest();
                sendRequest.setOwnerId(ownerId);
                sendRequest.setPayload(payload);
                sendRequest.setMessageId(messageId);

                processRequest(sendRequest, logger);
            }

            return "Processed " + records.size() + " SQS messages.";
        } else {
            // Direct API call
            SendRequest sendRequest = objectMapper.convertValue(event, SendRequest.class);
            String response = processRequest(sendRequest, logger);
            return response;
        }

    }

    private String processRequest(SendRequest request, LambdaLogger logger) {
        logger.log("Processing request: " + request);

        double inputValue;
        try {
            inputValue = Double.parseDouble(request.getPayload());
        } catch (NumberFormatException e) {
            logger.log("Invalid input for logarithm: " + e.getMessage());
            throw new IllegalArgumentException("Invalid input for logarithm calculation: " + request.getPayload());
        }

        double result = Math.log(inputValue);
        long now = Instant.now().toEpochMilli();

        Map<String, AttributeValue> resultItem = Map.of(
                "MessageId", AttributeValue.builder().s(request.getMessageId()).build(),
                "RecordType", AttributeValue.builder().s("RESULT").build(),
                "ownerId", AttributeValue.builder().s(request.getOwnerId()).build(),
                "payload", AttributeValue.builder().s(String.valueOf(result)).build(),
                "completedAt", AttributeValue.builder().n(Long.toString(now)).build()
        );

        dynamoDbClient.putItem(PutItemRequest.builder()
                .tableName(TABLE_NAME)
                .item(resultItem)
                .build());

        String response = "Logarithm of " + inputValue + " is " + result;
        logger.log("Returning response: " + response);
        return response;
    }

//    private Map<String, Object> parseBody(String body) throws Exception {
//        JsonNode jsonNode = objectMapper.readTree(body);
//        return objectMapper.convertValue(jsonNode, Map.class);
//    }

    // --- Request Payload Class ---
    public static class SendRequest {
        private String messageId;
        private String payload;
        private String ownerId;
        public SendRequest() {
            // Needed for Jackson deserialization
        }
        public String getMessageId() {
            return messageId;
        }

        public void setMessageId(String messageId) {
            this.messageId = messageId;
        }



        public String getPayload() {
            return payload;
        }

        public void setPayload(String payload) {
            this.payload = payload;
        }

        public String getOwnerId() {
            return ownerId;
        }

        public void setOwnerId(String ownerId) {
            this.ownerId = ownerId;
        }

        @Override
        public String toString() {
            return "SendRequest{payload='" + payload + "', ownerId='" + ownerId + "'}";
        }
    }
}
