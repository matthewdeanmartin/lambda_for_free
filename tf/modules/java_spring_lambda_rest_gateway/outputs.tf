output "api_gateway_endpoint" {
  value = aws_api_gateway_stage.rest_stage.invoke_url
}