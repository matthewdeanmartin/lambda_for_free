# Reuse same code across four logical lambdas
resource "aws_lambda_function" "write_db" {
  function_name = "write_db-${local.saga_name_suffix}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "com.example.WriteHandler"
  runtime       = "java21"

  # filename         = "${path.module}/data_lambda/data_lambda.jar"
  # source_code_hash = filebase64sha256("${path.module}/data_lambda/data_lambda.jar")

  filename      = "${path.module}/lambda_shim/main.zip"

  tracing_config {
    mode = "Active"
  }


  # Snapstart and Performance Tuning
  timeout     = "6"
  memory_size = "1024" # Cheapest (128 doesn't run at all!)
  architectures = ["arm64"] # Cheaper
  snap_start {
    apply_on ="PublishedVersions"
  }
  publish = true
}

resource "aws_lambda_alias" "write_db_alias" {
  name             = "live"
  description      = "Alias for the latest published version"
  function_name    = aws_lambda_function.write_db.function_name
  function_version = aws_lambda_function.write_db.version
}


resource "aws_lambda_function" "unwrite_db" {
  function_name = "unwrite_db-${local.saga_name_suffix}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "com.example.UnwriteHandler"
  runtime       = "java21"

  filename         = aws_lambda_function.write_db.filename
  # source_code_hash = aws_lambda_function.write_db.source_code_hash

  tracing_config {
    mode = "Active"
  }
  # Snapstart and Performance Tuning
  timeout     = "6"
  memory_size = "1024" # Cheapest (128 doesn't run at all!)
  architectures = ["arm64"] # Cheaper
  snap_start {
    apply_on ="PublishedVersions"
  }
  publish = true
}

resource "aws_lambda_alias" "unwrite_db_alias" {
  name             = "live"
  description      = "Alias for the latest published version"
  function_name    = aws_lambda_function.unwrite_db.function_name
  function_version = aws_lambda_function.unwrite_db.version
}

resource "aws_lambda_function" "call_api" {
  function_name = "call_api-${local.saga_name_suffix}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "com.example.RemoteCallHandler"
  runtime       = "java21"


  filename         = aws_lambda_function.write_db.filename
  # source_code_hash = aws_lambda_function.write_db.source_code_hash

  tracing_config {
    mode = "Active"
  }
  # Snapstart and Performance Tuning
  timeout     = "6"
  memory_size = "1024" # Cheapest (128 doesn't run at all!)
  architectures = ["arm64"] # Cheaper
  snap_start {
    apply_on ="PublishedVersions"
  }
  publish = true
}

resource "aws_lambda_alias" "call_api_alias" {
  name             = "live"
  description      = "Alias for the latest published version"
  function_name    = aws_lambda_function.call_api.function_name
  function_version = aws_lambda_function.call_api.version
}

resource "aws_lambda_function" "cancel_api" {
  function_name = "cancel_api-${local.saga_name_suffix}"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "com.example.CancelRemoteHandler"
  runtime       = "java21"
  filename         = aws_lambda_function.write_db.filename
  source_code_hash = aws_lambda_function.write_db.source_code_hash

  tracing_config {
    mode = "Active"
  }

  # Snapstart and Performance Tuning
  timeout     = "6"
  memory_size = "1024" # Cheapest (128 doesn't run at all!)
  architectures = ["arm64"] # Cheaper
  snap_start {
    apply_on ="PublishedVersions"
  }
  publish = true
}

resource "aws_lambda_alias" "cancel_api_alias" {
  name             = "live"
  description      = "Alias for the latest published version"
  function_name    = aws_lambda_function.cancel_api.function_name
  function_version = aws_lambda_function.cancel_api.version
}

# IAM Role
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role-${local.saga_name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# State Machine IAM Role
resource "aws_iam_role" "sf_role" {
  name = "step_function_role-${local.saga_name_suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "states.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sf_policy" {
  name = "step_function_policy-${local.saga_name_suffix}"
  role = aws_iam_role.sf_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "lambda:InvokeFunction",
        Resource = [
          aws_lambda_function.write_db.arn,
          aws_lambda_function.unwrite_db.arn,
          aws_lambda_function.call_api.arn,
          aws_lambda_function.cancel_api.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "states:StartExecution"
        ],
        Resource = "*" # Tighten later
      }
    ]
  })
}

# EXPRESS state machine (lower cost)
resource "aws_sfn_state_machine" "express_saga" {
  name     = "express-saga-${local.saga_name_suffix}"
  role_arn = aws_iam_role.sf_role.arn
  type     = "EXPRESS"

  definition = jsonencode({
    StartAt = "WriteDB",
    States = {
      "WriteDB" = {
        Type = "Task",
        Resource = aws_lambda_function.write_db.arn,
        Next     = "CallAPI",
        Parameters = {
          "execution_id.$" = "$$.Execution.Id"
        }
      },
      "CallAPI" = {
        Type = "Task",
        Resource = aws_lambda_function.call_api.arn,
        Next     = "Done",
        Parameters = {
          "execution_id.$" = "$$.Execution.Id"
        }
      },
      "Done" = { Type = "Succeed" }
    }
  })
}

# STANDARD state machine (wrapper)
resource "aws_sfn_state_machine" "standard_saga" {
  name     = "standard-saga-${local.saga_name_suffix}"
  role_arn = aws_iam_role.sf_role.arn
  type     = "STANDARD"

  definition = jsonencode({
    StartAt = "StartExpressSaga",
    States = {
      "StartExpressSaga" = {
        Type     = "Task",
        Resource = "arn:aws:states:::states:startExecution.sync:2", # sync Express execution
        Parameters = {
          StateMachineArn = aws_sfn_state_machine.express_saga.arn,
          Name            = "saga-$.Execution.Id",
          Input = {
            "execution_id.$" = "$$.Execution.Id"
          }
        },
        End = true
      }
    }
  })
}


resource "aws_iam_policy" "step_functions_eventbridge_policy" {
  name        = "StepFunctionsEventBridgePolicy-${local.saga_name_suffix}"
  description = "Allows Step Functions to manage EventBridge rules for .sync integrations"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DescribeRule"
        ],
        Resource = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForStepFunctionsExecutionRule"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_eventbridge_policy" {
  role       = aws_iam_role.sf_role.name
  policy_arn = aws_iam_policy.step_functions_eventbridge_policy.arn
}