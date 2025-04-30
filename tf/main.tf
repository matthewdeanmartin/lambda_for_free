resource "random_string" "random" {
  length  = 12
  upper   = false
  numeric = false
  lower   = true
  special = false
}

locals {
  react_bucket_name   = "lambda-for-free-react-${random_string.random.result}"
  angular_bucket_name = "lambda-for-free-angular-${random_string.random.result}"
}

module "react_website" {
  source      = "./modules/static_website"
  bucket_name = local.react_bucket_name
}

module "angular_website" {
  source      = "./modules/static_website"
  bucket_name = local.angular_bucket_name
}


module "main_lambda" {
  source = "./modules/java_spring_lambda"
  # ${var.environment}-
  name              = "tf-poc"
  lambda_entrypoint = "com.example.interviews.StreamLambdaHandler::handleRequest"
  cors_origin = [
    "http://${module.react_website.bucket_domain_name}",
    "http://${module.angular_website.bucket_domain_name}",
    "https://hlg0m0h7e6.execute-api.us-east-2.amazonaws.com" # API Gateway URL
  ]
}


module "main_rest_gateway" {
  source = "./modules/java_spring_lambda_rest_gateway"
  # ${var.environment}-
  name              = "tf-poc-rest-gateway"
  lambda_entrypoint = "com.example.interviews.StreamLambdaHandler::handleRequest"
  cors_origin = [
    "http://${module.react_website.bucket_domain_name}",
    "http://${module.angular_website.bucket_domain_name}"
  ]
}

module "poor_mans_rds" {
  source      = "./modules/poor_mans_rds"
  name        = "tf-poc-rds"
  environment = "dev"
}