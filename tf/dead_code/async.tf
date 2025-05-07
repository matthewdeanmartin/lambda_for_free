terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.97.0"
    }
  }
}
resource "aws_sqs_queue" "async_queue" {
  name = "${var.name}-async-queue"
}

resource "aws_iam_role" "apigw_sqs_role" {
  name = "${var.name}-apigw-sqs-role"

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

resource "aws_iam_role_policy_attachment" "attach_full_access_apigw_sqs_role" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  role       = aws_iam_role.apigw_sqs_role.name
}

resource "aws_iam_role_policy" "apigw_sqs_policy" {
  name = "${var.name}-apigw-sqs-policy"
  role = aws_iam_role.apigw_sqs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sqs:SendMessage"
      # Action = "sqs:*"
      Resource =  aws_sqs_queue.async_queue.arn
    },    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ],
      "Resource": "*"
    }
    ]
  })
}


resource "aws_api_gateway_resource" "async_proxy" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_rest_api.rest.root_resource_id
  path_part   = "async"
}

resource "aws_api_gateway_resource" "async_proxy_plus" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  parent_id   = aws_api_gateway_resource.async_proxy.id
  path_part   = "{proxy+}"
}


resource "aws_api_gateway_method" "async_proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.rest.id
  resource_id   = aws_api_gateway_resource.async_proxy_plus.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "async_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest.id
  resource_id             = aws_api_gateway_resource.async_proxy_plus.id
  http_method             = aws_api_gateway_method.async_proxy_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  # Must be account/queue-name
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.async_queue.name}"

  credentials             = aws_iam_role.apigw_sqs_role.arn
  passthrough_behavior    = "NEVER"
  request_templates = {
    # If this is too complex (?) or too large (?) it will be rejected with a IAM permission error(!!)
    # Also this is too far different for the java-serverless-container code to recognize it as a request.
    "application/json" = <<EOF
Action=SendMessage&MessageBody={
  "method": "$context.httpMethod",
  "body-json" : $input.json('$'),
  "queryParams": {
    #foreach($param in $input.params().querystring.keySet())
    "$param": "$util.escapeJavaScript($input.params().querystring.get($param))" #if($foreach.hasNext),#end
  #end
  },
  "pathParams": {
    #foreach($param in $input.params().path.keySet())
    "$param": "$util.escapeJavaScript($input.params().path.get($param))" #if($foreach.hasNext),#end
    #end
  }
EOF
#     "application/json" = <<EOF
# #set($inputRoot = $input.path('$'))
# Action=SendMessage&MessageBody=$util.urlEncode($input.body)
# EOF
  }



   request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
}


resource "aws_api_gateway_method_response" "async_200" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.async_proxy_plus.id
  http_method = aws_api_gateway_method.async_proxy_method.http_method
  status_code = "200"

  # response_models = {
  #   "application/json" = "Empty"
  # }
}

resource "aws_api_gateway_method_response" "async_400" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.async_proxy_plus.id
  http_method = aws_api_gateway_method.async_proxy_method.http_method
  status_code = "400"


  # response_models = {
  #   "application/json" = "Empty"
  # }
}


resource "aws_api_gateway_method_response" "async_500" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.async_proxy_plus.id
  http_method = aws_api_gateway_method.async_proxy_method.http_method
  status_code = "500"

  # response_models = {
  #   "application/json" = "Empty"
  # }
}


resource "aws_api_gateway_integration_response" "async_200" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.async_proxy_plus.id
  http_method = aws_api_gateway_method.async_proxy_method.http_method
  status_code = aws_api_gateway_method_response.async_200.status_code
  selection_pattern = "2\\d{2}" # any 2xx response
  # response_templates = {
  #   "application/json" = ""
  # }
}

resource "aws_api_gateway_integration_response" "async_500" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.async_proxy_plus.id
  http_method = aws_api_gateway_method.async_proxy_method.http_method
  status_code = aws_api_gateway_method_response.async_500.status_code
  selection_pattern = "5\\d{2}" # any 5xx response
#   response_templates = {
#     "application/json" = <<EOF
# {
#   "error": "Internal error occurred"
# }
# EOF
#   }
}

resource "aws_api_gateway_integration_response" "async_400" {
  rest_api_id = aws_api_gateway_rest_api.rest.id
  resource_id = aws_api_gateway_resource.async_proxy_plus.id
  http_method = aws_api_gateway_method.async_proxy_method.http_method
  status_code = aws_api_gateway_method_response.async_400.status_code
  selection_pattern = "4\\d{2}" # any 4xx response

#   response_templates = {
#     "application/json" = <<EOF
# {
#   "error": "Internal error occurred"
# }
# EOF
#   }
}
