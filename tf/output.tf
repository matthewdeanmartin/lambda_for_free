# Output the API Gateway URL
output "api_gateway_endpoint" {
  value = module.main_lambda.api_gateway_endpoint
}