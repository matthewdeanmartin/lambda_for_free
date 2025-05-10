data "aws_region" "current" {}

locals {
  base_name = "${var.product}-auth-${var.environment}"
}

resource "aws_cognito_user_pool" "main" {
  name = "${local.base_name}-pool"

  username_attributes        = ["email"]
  auto_verified_attributes   = ["email"]
  mfa_configuration          = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = false
    require_uppercase = false
    require_numbers   = false
    require_symbols   = false
  }

  lambda_config {
    post_confirmation = aws_lambda_function.post_confirmation.arn
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # Have to duplicate this resource block and use count to parameterize!
  # https://stackoverflow.com/questions/62427931/terraform-conditionally-apply-lifecycle-block
  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "aws_cognito_user_pool_client" "django" {
  name                                = "${local.base_name}-client-django"
  user_pool_id                        = aws_cognito_user_pool.main.id
  generate_secret                     = true
  allowed_oauth_flows                = ["client_credentials"]
  # allowed_oauth_scopes               = ["email", "openid"]
  supported_identity_providers        = ["COGNITO"]
  callback_urls                       = var.django_callback_urls
  logout_urls                         = var.django_callback_urls
}

resource "aws_cognito_user_pool_client" "android" {
  name                                = "${local.base_name}-client-android"
  user_pool_id                        = aws_cognito_user_pool.main.id
  allowed_oauth_flows                = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes               = ["email", "openid", "profile"]
  supported_identity_providers        = ["COGNITO"]
  callback_urls                       = var.android_callback_urls
  logout_urls                         = var.android_callback_urls
}

resource "aws_cognito_user_pool_client" "lambda" {
  name                                = "${local.base_name}-client-lambda"
  user_pool_id                        = aws_cognito_user_pool.main.id
  allowed_oauth_flows                = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes               = ["email", "openid", "profile"]
  supported_identity_providers        = ["COGNITO"]
  callback_urls                       = var.lambda_callback_urls
  logout_urls                         = var.lambda_callback_urls
}


resource "aws_cognito_user_pool_client" "angular" {
  name                                = "${local.base_name}-client-angular"
  user_pool_id                        = aws_cognito_user_pool.main.id
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                = ["code"]
  allowed_oauth_scopes               = ["email", "openid", "profile"]
  supported_identity_providers       = ["COGNITO"]

  callback_urls = [
    "http://localhost:4200/auth-callback",        # Dev
    "https://your-angular-app.com/auth-callback"  # Prod
  ]

  logout_urls = [
    "http://localhost:4200/logout",
    "https://your-angular-app.com/logout"
  ]


   token_validity_units {
 access_token  = "minutes"
 id_token      = "minutes"
 refresh_token = "days"

}

}

resource "awscc_cognito_managed_login_branding" "web_style" {
  user_pool_id = aws_cognito_user_pool.main.id
  client_id    = aws_cognito_user_pool_client.angular.id

  # Note: Settings format depends on the specific Cognito UI version you're using
  settings = jsonencode({})
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
  managed_login_version = 2
}


resource "aws_cognito_user_group" "groups" {
  for_each = toset(["free-user", "paid-user", "staff", "admin"])

  user_pool_id = aws_cognito_user_pool.main.id
  name         = each.key
  precedence   = 1
}

resource "aws_iam_role" "lambda_exec" {
  name = "${local.base_name}-post-confirm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "post_confirmation" {
  function_name    = "${local.base_name}-post-confirmation"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "post_confirmation.handler"
  runtime          = "python3.13"
  timeout          = 5
  filename         = "lambda/post_confirmation.zip"
  source_code_hash = filebase64sha256("lambda/post_confirmation.zip")
}

resource "aws_lambda_permission" "allow_cognito_invoke" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}
