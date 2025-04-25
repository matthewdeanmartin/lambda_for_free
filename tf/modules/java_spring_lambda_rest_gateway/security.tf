
# security
data "aws_iam_policy_document" "jsb_lambda_execution_policy_document" {
  statement {
    effect   = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.lambda_name}:*"
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
