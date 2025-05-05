package com.example.interviews.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.services.sfn.SfnClient;
import software.amazon.awssdk.services.sfn.model.*;
import software.amazon.awssdk.services.cloudwatchlogs.CloudWatchLogsClient;
import software.amazon.awssdk.services.cloudwatchlogs.model.*;

import java.time.Duration;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/saga")
@RequiredArgsConstructor
@Slf4j
public class StepFunctionController {

    private final SfnClient sfnClient;
    private final CloudWatchLogsClient logsClient;

    private static final String STATE_MACHINE_ARN = System.getenv("STATE_MACHINE_ARN");

    @PostMapping("/start")
    public ResponseEntity<?> startExecution(@RequestBody Map<String, Object> payload) {
        StartExecutionResponse response = sfnClient.startExecution(StartExecutionRequest.builder()
                .stateMachineArn(STATE_MACHINE_ARN)
                .input(payload.toString())
                .name("exec-" + System.currentTimeMillis())
                .build());

        return ResponseEntity.ok(Map.of("executionArn", response.executionArn()));
    }

    @PostMapping("/stop")
    public ResponseEntity<?> stopExecution(@RequestParam String executionArn) {
        sfnClient.stopExecution(StopExecutionRequest.builder()
                .executionArn(executionArn)
                .cause("Manually cancelled via API")
                .build());
        return ResponseEntity.ok("Stopped: " + executionArn);
    }

    @GetMapping("/status")
    public ResponseEntity<?> getStatus(@RequestParam String executionArn) {
        DescribeExecutionResponse response = sfnClient.describeExecution(
                DescribeExecutionRequest.builder().executionArn(executionArn).build());
        return ResponseEntity.ok(Map.of(
                "status", response.statusAsString(),
                "startTime", response.startDate(),
                "stopTime", response.stopDate(),
                "output", response.output()
        ));
    }

    @PostMapping("/heartbeat")
    public ResponseEntity<?> heartbeat(@RequestParam String taskToken) {
        sfnClient.sendTaskHeartbeat(SendTaskHeartbeatRequest.builder()
                .taskToken(taskToken)
                .build());
        return ResponseEntity.ok("Heartbeat sent");
    }

    @GetMapping("/poll")
    public ResponseEntity<?> pollForCompletion(@RequestParam String executionArn) throws InterruptedException {
        long timeoutMs = 30_000;
        long pollInterval = 2_000;
        long waited = 0;

        while (waited < timeoutMs) {
            DescribeExecutionResponse response = sfnClient.describeExecution(
                    DescribeExecutionRequest.builder().executionArn(executionArn).build());

            if (!response.status().equals(ExecutionStatus.RUNNING)) {
                return ResponseEntity.ok(Map.of(
                        "status", response.statusAsString(),
                        "output", response.output()
                ));
            }

            Thread.sleep(pollInterval);
            waited += pollInterval;
        }

        return ResponseEntity.status(202).body("Still running");
    }

    @GetMapping("/logs")
    public ResponseEntity<?> getLogs(@RequestParam String logGroup, @RequestParam String logStream) {
        GetLogEventsResponse logs = logsClient.getLogEvents(GetLogEventsRequest.builder()
                .logGroupName(logGroup)
                .logStreamName(logStream)
                .limit(100)
                .build());

        return ResponseEntity.ok(logs.events().stream().map(OutputLogEvent::message).toList());
    }

    @GetMapping("/history")
    public ResponseEntity<?> executionHistory(@RequestParam String executionArn) {
        GetExecutionHistoryResponse history = sfnClient.getExecutionHistory(GetExecutionHistoryRequest.builder()
                .executionArn(executionArn)
                .build());

        return ResponseEntity.ok(history.events().stream()
                .map(e -> Map.of(
                        "timestamp", e.timestamp(),
                        "type", e.typeAsString(),
                        "details", e.toString()
                )).toList());
    }

    @GetMapping("/list")
    public ResponseEntity<?> listExecutions() {
        ListExecutionsResponse executions = sfnClient.listExecutions(ListExecutionsRequest.builder()
                .stateMachineArn(STATE_MACHINE_ARN)
                .maxResults(10)
                .build());

        return ResponseEntity.ok(executions.executions());
    }
}
