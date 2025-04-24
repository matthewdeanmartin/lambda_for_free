locals {
  lambda_name = "${var.name}-compute"
}
# compute
resource "aws_lambda_function" "compute" {
  function_name = local.lambda_name
  role          = aws_iam_role.jbs_lambda_role.arn
  handler       = var.lambda_entrypoint
  runtime       = "java21"
  filename      = "${path.module}/lambda_shim/main.zip"
  # source = "terraform-aws-modules/lambda/aws"
  # create_package         = false
  # local_existing_package = "./lambda_shim/main.zip"


  # Snapstart and Performance Tuning
  timeout     = "3"
  memory_size = "128"
  snap_start {
    apply_on ="PublishedVersions"
  }
  publish = true
}

# endpoint
resource "aws_apigatewayv2_api" "proxy" {
  name          = "${var.name}-jsb-gateway"
  protocol_type = "HTTP"
  cors_configuration {
    #  "http://lambda-for-free-asdf-ui.s3-website.us-east-2.amazonaws.com/"
    allow_origins = [var.cors_origin, "http://lambda-for-free-react-asdf-ui.s3-website.us-east-2.amazonaws.com"]
    allow_headers = ["Content-Type","X-Amz-Date","Authorization","X-Api-Key","X-Amz-Security-Token"]
  }
}

resource "aws_apigatewayv2_integration" "proxy" {
  api_id           = aws_apigatewayv2_api.proxy.id
  integration_type = "AWS_PROXY"

  connection_type = "INTERNET"
  # content_handling_strategy = "CONVERT_TO_TEXT" # not supported?
  description          = "${var.name}"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.compute.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"

  # java serverless container doesn't support v2?
  payload_format_version = "1.0"
}


resource "aws_apigatewayv2_route" "proxy" {
  api_id    = aws_apigatewayv2_api.proxy.id
  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.proxy.id}"
}

resource "aws_apigatewayv2_stage" "proxy" {
  name        = "$default"
  api_id      = aws_apigatewayv2_api.proxy.id
  auto_deploy = true

  # adds error messages.
  access_log_settings {
    destination_arn = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_name}"
    format          = "{ \"requestId\":\"$context.requestId\", \"ip\": \"$context.identity.sourceIp\", \"requestTime\":\"$context.requestTime\", \"httpMethod\":\"$context.httpMethod\",\"routeKey\":\"$context.routeKey\", \"status\":\"$context.status\",\"protocol\":\"$context.protocol\", \"responseLength\":\"$context.responseLength\" , \"authorizerError\": \"$context.authorizer.error\", \"error_message\":\"$context.error.message\", \"error_string\": \t\"$context.error.messageString\", \"error_response_type\",\"$context.error.responseType\", \"integration_error\": \"$context.integration.error\", \"integration_status\":\"$context.integration.integrationStatus\"}"
  }

}

resource "aws_lambda_permission" "api_key" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compute.function_name
  principal = "apigateway.amazonaws.com"
  #  Suffix must match route name!
  source_arn    = "${aws_apigatewayv2_api.proxy.execution_arn}/*/*/{proxy+}"
}


# logs
resource "aws_cloudwatch_log_group" "logs" {
  # Suffix must match lambda name.
  name = "/aws/lambda/${local.lambda_name}"
}


