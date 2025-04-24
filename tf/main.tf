module "main_lambda" {
  source = "./modules/java_spring_lambda"
  # ${var.environment}-
  name              = "tf-poc"
  lambda_entrypoint = "com.example.interviews.StreamLambdaHandler::handleRequest"
  cors_origin       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
}