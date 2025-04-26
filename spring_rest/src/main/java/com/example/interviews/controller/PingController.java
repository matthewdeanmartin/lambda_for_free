package com.example.interviews.controller;


import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;

import java.util.Map;

import java.util.*;

@RestController
@EnableWebMvc
@RequestMapping({"/sync", "/async"})
public class PingController {
    @RequestMapping(path = "/ping", method = RequestMethod.GET)
    public Map<String, String> ping() {
        Map<String, String> pong = new HashMap<>();
        pong.put("pong", "Hello, World!");
        return pong;
    }

    @RequestMapping(path = "/pong", method = RequestMethod.GET)
    public Map<String, String> pong() {
        Map<String, String> pong = new HashMap<>();
        pong.put("ping", "Goodbye, World!");
        return pong;
    }
}
