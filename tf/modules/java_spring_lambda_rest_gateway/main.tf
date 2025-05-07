locals {
  lambda_name = "${var.name}-compute"
  worker_name = "${var.name}-async-worker"
  saga_name_suffix = "rest"
}

resource "aws_lambda_function" "compute" {
  function_name = local.lambda_name
  role          = aws_iam_role.jbs_lambda_role.arn
  handler       = var.lambda_entrypoint
  runtime       = "java21"
  filename      = "${path.module}/lambda_shim/main.zip"

  tracing_config {
    mode = "Active"
  }

  timeout = "6"
  memory_size = "1024" # Cheapest
  architectures = ["arm64"] # Cheaper
  snap_start {
    apply_on = "PublishedVersions"
  }
  publish = true
}

resource "aws_lambda_alias" "web_api_live" {
  name             = "live"
  description      = "Alias for the latest published version"
  function_name    = aws_lambda_function.compute.function_name
  function_version = aws_lambda_function.compute.version
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
  path_part   = "{proxy+}"
}


resource "aws_api_gateway_method" "proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  resource_id   = aws_api_gateway_resource.sync_proxy.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest.id
  resource_id             = aws_api_gateway_resource.sync_proxy.id
  http_method             = aws_api_gateway_method.proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.compute.invoke_arn
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_deployment" "rest_deploy" {
  depends_on = [
    aws_api_gateway_integration.proxy_integration,
  ]
  rest_api_id = aws_api_gateway_rest_api.rest.id
  description = "Deployment for ${var.name}"
}


resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
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

  xray_tracing_enabled = true


  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId    = "$context.requestId"
      ip           = "$context.identity.sourceIp"
      caller       = "$context.identity.caller"
      user         = "$context.identity.user"
      requestTime  = "$context.requestTime"
      httpMethod   = "$context.httpMethod"
      resourcePath = "$context.resourcePath"
      status       = "$context.status"
      protocol     = "$context.protocol"
      responseLength = "$context.responseLength"

      # debug
      authorizerError : "$context.authorizer.error"
      error_message : "$context.error.message"
      error_string : "$context.error.messageString"
      error_response_type : "$context.error.responseType"
      integration_error : "$context.integration.error"
      integration_status : "$context.integration.integrationStatus"
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
    logging_level      = "INFO"
    metrics_enabled    = true
    data_trace_enabled = false
  }
}

resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.compute.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.rest.execution_arn}/*/*/*"
}

resource "aws_cloudwatch_log_group" "lambda_log" {
  name              = "/aws/lambda/${local.lambda_name}"
  retention_in_days = 5
}


# resource "aws_api_gateway_method" "options" {
#   rest_api_id   = aws_api_gateway_rest_api.rest.id
#   resource_id   = aws_api_gateway_resource.sync_proxy.id
#   http_method   = "OPTIONS"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "options_integration" {
#   rest_api_id          = aws_api_gateway_rest_api.rest.id
#   resource_id          = aws_api_gateway_resource.sync_proxy.id
#   http_method          = aws_api_gateway_method.options.http_method
#   type                 = "MOCK"
#   passthrough_behavior = "WHEN_NO_MATCH"
#
#   request_templates = {
#     "application/json" = <<EOF
# {
#   "statusCode": 200
# }
# EOF
#   }
# }
#
# resource "aws_api_gateway_method_response" "options_response" {
#   rest_api_id = aws_api_gateway_rest_api.rest.id
#   resource_id = aws_api_gateway_resource.sync_proxy.id
#   http_method = aws_api_gateway_method.options.http_method
#   status_code = "200"
#
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = true
#     "method.response.header.Access-Control-Allow-Methods" = true
#     "method.response.header.Access-Control-Allow-Origin"  = true
#   }
# }
#
# resource "aws_api_gateway_integration_response" "options_integration_response" {
#   rest_api_id = aws_api_gateway_rest_api.rest.id
#   resource_id = aws_api_gateway_resource.sync_proxy.id
#   http_method = aws_api_gateway_method.options.http_method
#   status_code = aws_api_gateway_method_response.options_response.status_code
#
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
#     "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,PUT,DELETE'"
#     "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_origin)}'"
#   }
#
#   response_templates = {
#     "application/json" = ""
#   }
# }


# attempt 2 at cors
# resource "aws_api_gateway_integration_response" "options_integration_response" {
#   rest_api_id = aws_api_gateway_rest_api.rest.id
#   resource_id = aws_api_gateway_resource.sync_proxy.id
#   http_method = aws_api_gateway_method.options.http_method
#   status_code = aws_api_gateway_method_response.options_response.status_code
#
#   response_parameters = {
#     "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
#     "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,PUT,DELETE'"
#     "method.response.header.Access-Control-Allow-Origin"  = "'${join(",", var.cors_origin)}'"
#   }
#
#   response_templates = {
#     "application/json" = ""
#   }
# }
#
# resource "aws_api_gateway_gateway_response" "default_4xx" {
#   rest_api_id   = aws_api_gateway_rest_api.rest.id
#   response_type = "DEFAULT_4XX"
#
#   response_parameters = {
#     "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'" // Replace '*' with your frontend's domain if needed
#     "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,PUT,DELETE'"
#     "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
#   }
#
#   response_templates = {
#     "application/json" = "{\"message\":$context.error.messageString}"
#   }
# }
#
# resource "aws_api_gateway_gateway_response" "default_5xx" {
#   rest_api_id   = aws_api_gateway_rest_api.rest.id
#   response_type = "DEFAULT_5XX"
#
#   response_parameters = {
#     "gatewayresponse.header.Access-Control-Allow-Origin" = "'*'" // Replace '*' with your frontend's domain if needed
#     "gatewayresponse.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS,PUT,DELETE'"
#     "gatewayresponse.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
#   }
#
#   response_templates = {
#     "application/json" = "{\"message\":$context.error.messageString}"
#   }
# }


module "cors" {
  source  = "squidfunk/api-gateway-enable-cors/aws"
  version = "0.3.3"

  api_id          = aws_api_gateway_rest_api.rest.id
  api_resource_id = aws_api_gateway_resource.sync_proxy.id
  allow_origin = join(",", var.cors_origin)
}