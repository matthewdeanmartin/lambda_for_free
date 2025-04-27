output "api_gateway_endpoint" {
  value = aws_apigatewayv2_api.proxy.api_endpoint
}

###############################################################################
# Outputs
###############################################################################
output "sqs_queue_url" {
  value       = aws_sqs_queue.broker.id
  description = "The SQS queue URL"
}

output "dynamodb_table_name" {
  value       = aws_dynamodb_table.broker.name
  description = "The DynamoDB table name"
}

output "dynamodb_table_arn" {
  value       = aws_dynamodb_table.broker.arn
  description = "The DynamoDB table ARN"
}