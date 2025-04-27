package com.example.interviews;


import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.context.annotation.Import;



@SpringBootApplication
// We use direct @Import instead of @ComponentScan to speed up cold starts
@ComponentScan(basePackages = "com.example.interviews.controller")
//@Import({ PingController.class, InterviewController.class, MessageController.class })
public class Application {

    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}