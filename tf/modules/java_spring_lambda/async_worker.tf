# 1) Grant the Lambda role permission to read from & delete messages on the queue
data "aws_iam_policy_document" "lambda_sqs" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [ aws_sqs_queue.broker.arn ]
  }
}

# Creates inline policy
resource "aws_iam_role_policy" "lambda_sqs" {
  name   = "lambda-sqs-access"
  role   = aws_iam_role.jbs_lambda_role.name
  policy = data.aws_iam_policy_document.lambda_sqs.json
}

# 2) Hook the queue up to the function
resource "aws_lambda_event_source_mapping" "trigger_worker_from_sqs" {
  event_source_arn  = aws_sqs_queue.broker.arn
  function_name     = aws_lambda_function.async_worker.function_name
  enabled           = true

  # Batch size 1 good for debugging, but increase to save costs at the risk of latency
  batch_size                        = 1
  maximum_batching_window_in_seconds = 30
  # 1 retry is good for debugging. 2 or 3 is good if you know that it succeeds 99% of the time and 1% of the time it fails but succeeds on retry.
  # maximum_retry_attempts = "1" # Not set here?
}

resource "aws_lambda_function" "async_worker" {
  function_name = local.worker_name
  role          = aws_iam_role.jbs_lambda_role.arn
  handler       = "org.example.FunctionConfiguration::handleRequest" # var.lambda_entrypoint
  runtime       = "java21"
  filename      = "${path.module}/lambda_shim/main.zip"

  # Snapstart and Performance Tuning
  timeout     = "3"
  memory_size = "128" # Cheapest
  architectures = ["arm64"] # Cheaper
  snap_start {
    apply_on ="PublishedVersions"
  }

  publish = true
}