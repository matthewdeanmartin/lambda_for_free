package com.example.spring_initializer;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;


@RestController
public class InterviewController {
    @RequestMapping(path = "/fizzbuzz", method = RequestMethod.GET)
    public String fizzbuzz(int size) {
        return "fizzbuzz";
    }
}
