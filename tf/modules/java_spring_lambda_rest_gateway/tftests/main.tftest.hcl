# Use moto.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  // override endpoints to point to localstack
  endpoints {

    account        = "http://localhost:5000"
    apigateway     = "http://localhost:5000"
    apigatewayv2   = "http://localhost:5000"
    autoscaling    = "http://localhost:5000"
    cloudwatch     = "http://localhost:5000"
    cloudwatchlogs = "http://localhost:5000"
    dynamodb       = "http://localhost:5000"

    ec2 = "http://localhost:5000"

    eks    = "http://localhost:5000"
    iam    = "http://localhost:5000"
    lambda = "http://localhost:5000"

    sts = "http://localhost:5000"
    s3  = "http://localhost:5000"
  }
}

variables {
  name        = "test-postgres"
  environment = "test"
}

# run "setup_tests" {
#   module {
#     source = "./tests/setup"
#   }
# }


run "verify" {
  command = plan

  assert {
    condition     = aws_lambda_function.compute.function_name == local.lambda_name
    error_message = "Name is what we'd expect."
  }

}