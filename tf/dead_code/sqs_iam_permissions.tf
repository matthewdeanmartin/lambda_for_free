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
  # 1 for debugging, 2 or 3 for production
  # maximum_retry_attempts = 1 # not set here?
}


# resource "aws_api_gateway_resource" "sync_proxy_plus" {
#   rest_api_id = aws_api_gateway_rest_api.rest.id
#   parent_id   = aws_api_gateway_resource.sync_proxy.id
#   path_part   = "{proxy+}"
# }
