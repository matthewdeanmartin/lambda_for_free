locals {
  lambda_name = "${var.name}-compute"
}

resource "aws_lambda_function" "compute" {
  function_name = local.lambda_name
  role          = aws_iam_role.jbs_lambda_role.arn
  handler       = var.lambda_entrypoint
  runtime       = "java21"
  filename      = "${path.module}/lambda_shim/main.zip"

  timeout     = 3
  memory_size = 128
  snap_start {
    apply_on = "PublishedVersions"
  }
  publish = true
}

data "aws_iam_policy_document" "receive_sqs_messages_policy_data" {
  statement {
    # sid       = ""
    actions   = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.async_queue.arn
    ]
  }
}

resource "aws_iam_policy" "receive_sqs_messages_policy" {
  name   = "RecieveSqsMessagesPolicy"
  policy = data.aws_iam_policy_document.receive_sqs_messages_policy_data.json
}

resource "aws_iam_role_policy_attachment" "attach_sqs_policy_to_lambda_execution" {
  role       = aws_iam_role.jbs_lambda_role.name
  policy_arn = aws_iam_policy.receive_sqs_messages_policy.arn
}

resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn = aws_sqs_queue.async_queue.arn
  function_name    = aws_lambda_function.compute.arn
  batch_size       = 1              # or more, depending on your use case
  enabled          = true
}

resource "aws_api_gateway_rest_api" "rest" {
  name        = "${var.name}-rest-gateway-api"
  description = "REST API for ${var.name}"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "sync_proxy" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_rest_api.rest.root_resource_id
  path_part   = "sync"
}

resource "aws_api_gateway_resource" "sync_proxy_plus" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_resource.sync_proxy.id
  path_part   = "{proxy+}"
}


resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  resource_id   = aws_api_gateway_resource.sync_proxy_plus.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest.id
  resource_id             = aws_api_gateway_resource.sync_proxy_plus.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.compute.invoke_arn
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_deployment" "rest_deploy" {
  depends_on = [
    aws_api_gateway_integration.proxy_integration,
    aws_api_gateway_integration.async_proxy_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.rest.id
  description = "Deployment for ${var.name}"
  # stage_name is intentionally omitted per best practice
}


resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}

resource "aws_iam_role" "apigw_cloudwatch_role" {
  name = "${var.name}-apigw-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_logs" {
  role       = aws_iam_role.apigw_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.name}-rest"
  retention_in_days = 5
}

resource "aws_api_gateway_stage" "rest_stage" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  deployment_id = aws_api_gateway_deployment.rest_deploy.id
  description   = "Production stage"

  depends_on = [aws_api_gateway_account.main]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId       = "$context.requestId"
      ip              = "$context.identity.sourceIp"
      caller          = "$context.identity.caller"
      user            = "$context.identity.user"
      requestTime     = "$context.requestTime"
      httpMethod      = "$context.httpMethod"
      resourcePath    = "$context.resourcePath"
      status          = "$context.status"
      protocol        = "$context.protocol"
      responseLength  = "$context.responseLength"

      # debug
      authorizerError: "$context.authorizer.error"
      error_message:"$context.error.message"
      error_string:"$context.error.messageString"
      error_response_type:"$context.error.responseType"
      integration_error: "$context.integration.error"
      integration_status: "$context.integration.integrationStatus"
    })
  }

}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  stage_name  = aws_api_gateway_stage.rest_stage.stage_name
  method_path = "*/*"

  settings {
      // resource_path = "/*"
      // http_method   = "*"
      logging_level = "INFO"
      metrics_enabled = true
      data_trace_enabled = false
  }
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compute.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest.execution_arn}/*/*/sync/*"
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 5
}
