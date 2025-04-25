package com.example.interviews;


import com.amazonaws.serverless.exceptions.ContainerInitializationException;
import com.amazonaws.serverless.proxy.model.AwsProxyRequest;
import com.amazonaws.serverless.proxy.model.AwsProxyResponse;
import com.amazonaws.serverless.proxy.spring.SpringBootLambdaContainerHandler;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestStreamHandler;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;


public class StreamLambdaHandler implements RequestStreamHandler {
    private static SpringBootLambdaContainerHandler<AwsProxyRequest, AwsProxyResponse> handler;
    private static final ObjectMapper objectMapper = new ObjectMapper();

    static {
        try {
            handler = SpringBootLambdaContainerHandler.getAwsProxyHandler(Application.class);
        } catch (ContainerInitializationException e) {
            // if we fail here. We re-throw the exception to force another cold start
            e.printStackTrace();
            throw new RuntimeException("Could not initialize Spring Boot application", e);
        }
    }

//    @Override
//    public void handleRequest(InputStream inputStream, OutputStream outputStream, Context context)
//            throws IOException {
//        handler.proxyStream(inputStream, outputStream, context);
//    }

//    @Override
//    public void handleRequest(InputStream inputStream, OutputStream outputStream, Context context)
//            throws IOException {
//
//        // Read all input into a byte array
//        byte[] inputBytes = inputStream.readAllBytes();
//
//        // Log the input (convert to String if appropriate, like assuming UTF-8)
//        String inputString = new String(inputBytes, StandardCharsets.UTF_8);
//        context.getLogger().log("Received input: " + inputString);
//
//        // Pass a new InputStream based on the bytes to handler
//        InputStream newInputStream = new ByteArrayInputStream(inputBytes);
//
//        handler.proxyStream(newInputStream, outputStream, context);
//    }

    @Override
    public void handleRequest(InputStream inputStream, OutputStream outputStream, Context context)
            throws IOException {
        byte[] inputBytes = inputStream.readAllBytes();

        // Log the original input
        String inputString = new String(inputBytes, StandardCharsets.UTF_8);
        context.getLogger().log("Original SQS input: " + inputString);

        // Parse JSON and extract body
        // Parse JSON
        JsonNode root;
        try {
            root = objectMapper.readTree(inputBytes);
            JsonNode records = root.path("Records");
            if (!records.isArray() || records.isEmpty()) {
                context.getLogger().log("SQS has no records");
                // Pass a new InputStream based on the bytes to handler
                InputStream newInputStream = new ByteArrayInputStream(inputBytes);

                handler.proxyStream(newInputStream, outputStream, context);
                return;
            }

            String rawBody = records.get(0).path("body").asText();
            context.getLogger().log("Raw body string: " + rawBody);

            // Return as new InputStream
            InputStream newInputStream = new ByteArrayInputStream(rawBody.getBytes(StandardCharsets.UTF_8));
            handler.proxyStream(newInputStream, outputStream, context);
        } catch (Exception e) {
            context.getLogger().log("Failed to parse input as JSON, assuming raw passthrough.");
            InputStream newInputStream = new ByteArrayInputStream(inputBytes);
            handler.proxyStream(newInputStream, outputStream, context);
        }

    }
}