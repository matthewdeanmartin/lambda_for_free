# Generic JSB Lambda

Web API Lambda interacts with API Gateway. If it sends an SQS message and puts the pending state in DynamoDB, so it can be handled by the 
broker.

The broker Lambda receives messages from SQS, and puts results into DynamoDB.

