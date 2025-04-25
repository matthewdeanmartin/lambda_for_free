package com.example.interviews.controller;


import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Collections;
import java.util.List;
import java.util.Map;


@RestController
@RequestMapping("/api")
public class InterviewController {

    @GetMapping("/sliding-window")
    public Map<String, Integer> getMaxSlidingWindowSum(
            @RequestParam List<Integer> numbers,
            @RequestParam int windowSize) {

        int maxSum = calculateMaxSumOfSlidingWindow(numbers, windowSize);
        return Collections.singletonMap("maxSum", maxSum);
    }

    private int calculateMaxSumOfSlidingWindow(List<Integer> numbers, int windowSize) {
        if (numbers == null || numbers.size() < windowSize || windowSize <= 0) {
            return 0;
        }

        int currentWindowSum = 0;
        for (int index = 0; index < windowSize; index++) {
            currentWindowSum += numbers.get(index);
        }

        int maxWindowSum = currentWindowSum;

        for (int windowEndIndex = windowSize; windowEndIndex < numbers.size(); windowEndIndex++) {
            int windowStartIndex = windowEndIndex - windowSize;
            currentWindowSum += numbers.get(windowEndIndex);
            currentWindowSum -= numbers.get(windowStartIndex);
            maxWindowSum = Math.max(maxWindowSum, currentWindowSum);
        }

        return maxWindowSum;
    }
}
