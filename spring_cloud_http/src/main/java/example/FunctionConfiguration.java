package example;

import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;

import example.models.SendRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;

@SpringBootApplication
public class FunctionConfiguration {

	public static void main(String[] args) {
		//SpringApplication.run(FunctionConfiguration.class, args);
	}

	@Bean
	public Function<String, String> uppercase() {
		return value -> value.toUpperCase();
	}
	@Bean
	public Function<SendRequest, String> logFunction(DynamoDbClient dynamoDbClient,
													 @Value("${app.dynamo.table-name}") String tableName) {
		return (SendRequest req) -> {
			// Extract the payload, assuming it's a number for the logarithm calculation
			double inputValue;
			try {
				inputValue = Double.parseDouble(req.payload());
			} catch (NumberFormatException e) {
				throw new IllegalArgumentException("Invalid input for logarithm calculation: " + req.payload());
			}

			// Calculate the logarithm
			double result = Math.log(inputValue);

			// Create a unique messageId
			String messageId = UUID.randomUUID().toString();
			long now = Instant.now().toEpochMilli();

			// Prepare the result to be stored in DynamoDB
			Map<String, AttributeValue> resultItem = Map.of(
					"MessageId", AttributeValue.builder().s(messageId).build(),
					"RecordType", AttributeValue.builder().s("RESULT").build(),
					"payload", AttributeValue.builder().s(String.valueOf(result)).build(),
					"completedAt", AttributeValue.builder().n(Long.toString(now)).build()
			);

			// Put the result into DynamoDB
			dynamoDbClient.putItem(PutItemRequest.builder()
					.tableName(tableName)
					.item(resultItem)
					.build());

			// Return the result (optional, depending on your use case)
			return "Logarithm of " + inputValue + " is " + result;
		};
	}
}
