# Output the API Gateway URL
output "http_api_gateway_endpoint" {
  value = module.main_lambda.api_gateway_endpoint
}

output "web_lambda_function_url" {
  value = module.main_lambda.lambda_function_url
}

output "rest_api_gateway_endpoint" {
  value = module.main_rest_gateway.api_gateway_endpoint
}

output "react_website_url" {
  value = module.react_website.bucket_domain_name
}

output "angular_website_url" {
  value = module.angular_website.bucket_domain_name
}

output "login_url" {
  value = module.cognito.login_url
}

output "signup_url" {
  value = module.cognito.signup_url
}