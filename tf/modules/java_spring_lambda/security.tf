terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
}
# security
data "aws_iam_policy_document" "jsb_lambda_execution_policy_document" {
  statement {
    effect = "Allow"
    actions = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",


    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_name}:*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [
      aws_sqs_queue.broker.arn
    ]
  }
}


resource "aws_iam_role" "jbs_lambda_role" {
  name = "${var.name}-jsb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "jsb_lambda_role_policy" {
  policy = data.aws_iam_policy_document.jsb_lambda_execution_policy_document.json
  role   = aws_iam_role.jbs_lambda_role.name
}


resource "aws_iam_role_policy_attachment" "jsb_can_read_write_db" {
  policy_arn = aws_iam_policy.broker_access_policy.arn
  role       = aws_iam_role.jbs_lambda_role.name
}
resource "aws_iam_policy" "broker_access_policy" {
  name        = "DynamoDBBrokerAccessPolicy"
  description = "IAM policy for accessing the Broker DynamoDB table, its indexes, and streams"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DynamoDBIndexAndStreamAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:GetShardIterator",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:DescribeStream",
          "dynamodb:GetRecords",
          "dynamodb:ListStreams",
        ]
        Resource = [
          "${aws_dynamodb_table.broker.arn}/index/*",
          "${aws_dynamodb_table.broker.arn}/stream/*",
        ]
      },
      {
        Sid    = "DynamoDBTableAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:PutItem",
          "dynamodb:DescribeTable",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
        ]
        Resource = aws_dynamodb_table.broker.arn
      },
      {
        Sid    = "DynamoDBDescribeLimitsAccess"
        Effect = "Allow"
        Action = "dynamodb:DescribeLimits"
        Resource = [
          aws_dynamodb_table.broker.arn,
          "${aws_dynamodb_table.broker.arn}/index/*",
        ]
      },
    ]
  })
}
