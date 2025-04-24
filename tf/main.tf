module "react_website" {
  source      = "./modules/static_website"
  bucket_name = "lambda-for-free-react-asd-ui"
}

module "angular_website" {
  source      = "./modules/static_website"
  bucket_name = "lambda-for-free-angular-asd-ui"
}


module "main_lambda" {
  source = "./modules/java_spring_lambda"
  # ${var.environment}-
  name              = "tf-poc"
  lambda_entrypoint = "com.example.interviews.StreamLambdaHandler::handleRequest"
  cors_origin = [
    "http://${module.react_website.bucket_domain_name}",
    "http://${module.angular_website.bucket_domain_name}"
    # "http://${aws_s3_bucket_website_configuration.website.website_endpoint}",
    # "http://lambda-for-free-react-asdf-ui.s3-website.us-east-2.amazonaws.com"
  ]
}