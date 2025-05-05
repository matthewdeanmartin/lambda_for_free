package com.example.interviews;

// AwsConfig.java
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Lazy;
import software.amazon.awssdk.auth.credentials.DefaultCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cloudwatchlogs.CloudWatchLogsClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.sfn.SfnClient;
import software.amazon.awssdk.services.sqs.SqsClient;

@Configuration
public class AwsConfig {

    @Value("${aws.region:us-east-2}")
    private String region;

    @Bean
    @Lazy
    public SqsClient sqsClient() {
        return SqsClient.builder()
                .region(Region.of(region))
                //.credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }

    @Bean
    @Lazy
    public DynamoDbClient dynamoDbClient() {
        return DynamoDbClient.builder()
                .region(Region.of(region))
                //.credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }

    @Bean
    public SfnClient sfnClient() {
        return SfnClient.builder()
                .region(Region.of(region))
                //.credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }

    @Bean
    public CloudWatchLogsClient cloudWatchLogsClient() {
        return CloudWatchLogsClient.builder()
                .region(Region.of(region))
                // .credentialsProvider(DefaultCredentialsProvider.create())
                .build();
    }
}
