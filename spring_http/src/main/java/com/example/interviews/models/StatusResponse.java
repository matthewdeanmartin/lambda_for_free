package com.example.interviews.models;

// StatusResponse.java
import java.util.Map;
public record StatusResponse(
        String status,
        Map<String,Object> result,
        String error
) { }