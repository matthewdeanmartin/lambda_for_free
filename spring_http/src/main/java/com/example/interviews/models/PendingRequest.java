package com.example.interviews.models;

// PendingRequest.java
// Returned by GET /messages to list in-flight
public record PendingRequest(
        String messageId,
        long createdAt
) { }