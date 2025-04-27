package example.models;

// SendRequest.java
// Clients must send both ownerId and payload
public record SendRequest(
        String ownerId,
        String payload
) { }

