package com.example.interviews;

import com.example.interviews.controller.InterviewController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(InterviewController.class)
public class InterviewControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void testGetMaxSlidingWindowSum_validInput_returnsCorrectSum() throws Exception {
        mockMvc.perform(get("/api/sliding-window")
                        .param("numbers", "1", "3", "5", "7", "9")
                        .param("windowSize", "3"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxSum", is(21))); // 5+7+9
    }

    @Test
    void testGetMaxSlidingWindowSum_windowSizeTooLarge_returnsZero() throws Exception {
        mockMvc.perform(get("/api/sliding-window")
                        .param("numbers", "1", "2")
                        .param("windowSize", "5"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxSum", is(0)));
    }

    @Test
    void testGetMaxSlidingWindowSum_windowSizeZero_returnsZero() throws Exception {
        mockMvc.perform(get("/api/sliding-window")
                        .param("numbers", "1", "2", "3")
                        .param("windowSize", "0"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxSum", is(0)));
    }

    @Test
    void testGetMaxSlidingWindowSum_emptyNumbers_returnsZero() throws Exception {
        mockMvc.perform(get("/api/sliding-window")
                        .param("numbers", "")
                        .param("windowSize", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxSum", is(0)));
    }
}

