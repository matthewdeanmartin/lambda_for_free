package com.example.interviews;

import com.example.interviews.controller.StepFunctionController;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentMatchers;
import software.amazon.awssdk.services.cloudwatchlogs.CloudWatchLogsClient;
import software.amazon.awssdk.services.cloudwatchlogs.model.GetLogEventsRequest;
import software.amazon.awssdk.services.cloudwatchlogs.model.GetLogEventsResponse;
import software.amazon.awssdk.services.cloudwatchlogs.model.OutputLogEvent;
import software.amazon.awssdk.services.sfn.SfnClient;
import software.amazon.awssdk.services.sfn.model.*;

import java.util.List;
import java.util.Map;

import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;

class StepFunctionControllerTest {

    private SfnClient mockSfnClient;
    private CloudWatchLogsClient mockLogsClient;
    private StepFunctionController controller;

    @BeforeEach
    void setup() {
        mockSfnClient = mock(SfnClient.class);
        mockLogsClient = mock(CloudWatchLogsClient.class);
        controller = new StepFunctionController(mockSfnClient, mockLogsClient);
    }

    @Test
    void testStartExecution() {
        when(mockSfnClient.startExecution(any(StartExecutionRequest.class)))
                .thenReturn(StartExecutionResponse.builder().executionArn("arn:aws:states:::example").build());

        var result = controller.startExecution(Map.of("foo", "bar"));
        assertEquals(200, result.getStatusCodeValue());
        assertTrue(result.getBody().toString().contains("arn:aws:states:::example"));
    }

    @Test
    void testStopExecution() {
        StopExecutionResponse mockResponse = StopExecutionResponse.builder().build();

        when(mockSfnClient.stopExecution(any(StopExecutionRequest.class)))
                .thenReturn(mockResponse);

        var response = controller.stopExecution("arn:aws:states:::example");
        assertEquals("Stopped: arn:aws:states:::example", response.getBody());
    }

    @Test
    void testGetStatus() {
        DescribeExecutionResponse mockResponse = DescribeExecutionResponse.builder()
                .status(ExecutionStatus.SUCCEEDED)
                .startDate(java.time.Instant.now())
                .stopDate(java.time.Instant.now())
                .output("{\"result\":\"ok\"}")
                .build();

        when(mockSfnClient.describeExecution(any(DescribeExecutionRequest.class)))
                .thenReturn(mockResponse);

        var response = controller.getStatus("arn:aws:states:::example");
        Map body = (Map) response.getBody();
        assertEquals("SUCCEEDED", body.get("status"));
        assertTrue(body.get("output").toString().contains("ok"));
    }

    @Test
    void testHeartbeat() {
        SendTaskHeartbeatResponse mockResponse = SendTaskHeartbeatResponse.builder().build();

        when(mockSfnClient.sendTaskHeartbeat(any(SendTaskHeartbeatRequest.class)))
                .thenReturn(mockResponse);

        var result = controller.heartbeat("test-token");
        assertEquals("Heartbeat sent", result.getBody());
    }

    @Test
    void testPollForCompletionCompleted() throws InterruptedException {
        DescribeExecutionResponse done = DescribeExecutionResponse.builder()
                .status(ExecutionStatus.SUCCEEDED)
                .output("{\"msg\":\"done\"}")
                .build();

        when(mockSfnClient.describeExecution(any(DescribeExecutionRequest.class)))
                .thenReturn(done);

        var response = controller.pollForCompletion("arn:aws:states:::example");
        Map result = (Map) response.getBody();
        assertEquals("SUCCEEDED", result.get("status"));
    }

    @Test
    void testGetLogs() {
        List<OutputLogEvent> events = List.of(
                OutputLogEvent.builder().message("line 1").build(),
                OutputLogEvent.builder().message("line 2").build()
        );

        when(mockLogsClient.getLogEvents((GetLogEventsRequest) any()))
                .thenReturn(GetLogEventsResponse.builder().events(events).build());

        var response = controller.getLogs("group", "stream");
        List<?> body = (List<?>) response.getBody();
        assertEquals(2, body.size());
    }

    @Test
    void testExecutionHistory() {
        HistoryEvent event = HistoryEvent.builder()
                .id(1L)
                .timestamp(java.time.Instant.now())
                .type(HistoryEventType.TASK_STATE_ENTERED)
                .build();

        GetExecutionHistoryResponse history = GetExecutionHistoryResponse.builder()
                .events(List.of(event))
                .build();

        when(mockSfnClient.getExecutionHistory((GetExecutionHistoryRequest) any()))
                .thenReturn(history);

        var response = controller.executionHistory("arn:aws:states:::example");
        List<?> historyList = (List<?>) response.getBody();
        assertFalse(historyList.isEmpty());
    }
}
