output "api_gateway_endpoint" {
  value = aws_api_gateway_rest_api.rest.endpoint_configuration
}