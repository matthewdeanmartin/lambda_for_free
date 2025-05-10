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
    cognitoidentity = "http://localhost:5000"
    cognitoidentityprovider = "http://localhost:5000"
  }
}


variables {
  product              = "exampleapp"
  environment          = "test"
  domain_prefix        = "exampleapp-auth-test"
  django_callback_urls = ["https://exampleapp.test/login/callback"]
  android_callback_urls = ["exampleapp://callback"]
  lambda_callback_urls  = ["https://lambda.exampleapp.test/callback"]
  is_test = true
}

run "plan_cognito_module" {
  command = plan

  assert {
    condition     = aws_cognito_user_pool.main.name == "exampleapp-auth-test-pool"
    error_message = "User pool name does not match expected value."
  }

  assert {
    condition     = aws_cognito_user_pool.main.mfa_configuration == "OPTIONAL"
    error_message = "MFA configuration is not set to OPTIONAL."
  }

  assert {
    condition     = aws_cognito_user_pool.main.software_token_mfa_configuration[0].enabled == true
    error_message = "TOTP MFA is not enabled."
  }

  assert {
    condition     = contains(aws_cognito_user_pool.main.username_attributes, "email")
    error_message = "Email is not set as a username attribute."
  }

  assert {
    condition     = contains(aws_cognito_user_pool.main.auto_verified_attributes, "email")
    error_message = "Email is not set for auto verification."
  }
}

run "apply_and_verify_outputs" {
  command = apply

  assert {
    condition     = length(aws_cognito_user_group.groups) == 4
    error_message = "Expected 4 user groups to be created."
  }

  assert {
    condition     = aws_cognito_user_pool_client.django.generate_secret == true
    error_message = "Django client should have a generated secret."
  }

  assert {
    condition     = aws_cognito_user_pool_client.android.allowed_oauth_flows_user_pool_client == true
    error_message = "Android client should have user pool OAuth flows enabled."
  }

  assert {
    condition     = aws_cognito_user_pool_client.lambda.allowed_oauth_flows_user_pool_client == true
    error_message = "Lambda client should have user pool OAuth flows enabled."
  }
}
