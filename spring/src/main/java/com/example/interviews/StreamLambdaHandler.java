package com.example.interviews;


import com.amazonaws.serverless.exceptions.ContainerInitializationException;
import com.amazonaws.serverless.proxy.model.AwsProxyRequest;
import com.amazonaws.serverless.proxy.model.AwsProxyResponse;
import com.amazonaws.serverless.proxy.spring.SpringBootLambdaContainerHandler;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestStreamHandler;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;


public class StreamLambdaHandler implements RequestStreamHandler {
    private static SpringBootLambdaContainerHandler<AwsProxyRequest, AwsProxyResponse> handler;
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

    @Override
    public void handleRequest(InputStream inputStream, OutputStream outputStream, Context context)
            throws IOException {

        // Read all input into a byte array
        byte[] inputBytes = inputStream.readAllBytes();

        // Log the input (convert to String if appropriate, like assuming UTF-8)
        String inputString = new String(inputBytes, StandardCharsets.UTF_8);
        context.getLogger().log("Received input: " + inputString);

        // Pass a new InputStream based on the bytes to handler
        InputStream newInputStream = new ByteArrayInputStream(inputBytes);

        handler.proxyStream(newInputStream, outputStream, context);
    }
}