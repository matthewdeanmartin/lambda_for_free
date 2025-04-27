###############################################################################
# SQS Queue
###############################################################################
resource "aws_sqs_queue" "broker" {
  name                       = var.queue_name
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600   # 4 days

  tags = {
    Environment = var.environment
    Application = "message-broker"
  }
}

###############################################################################
# DynamoDB Table for REQUEST/RESULT/CANCELLED records
###############################################################################
resource "aws_dynamodb_table" "broker" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  # Primary key: MessageId (PK) + RecordType (SK)
  hash_key  = "MessageId"
  range_key = "RecordType"

  attribute {
    name = "MessageId"
    type = "S"
  }

  attribute {
    name = "RecordType"
    type = "S"
  }

  # For in-flight scans: ownerId + RecordType
  attribute {
    name = "ownerId"
    type = "S"
  }

  global_secondary_index {
    name               = "ownerId-recordType-index"
    hash_key           = "ownerId"
    range_key          = "RecordType"
    projection_type    = "ALL"
  }

  tags = {
    Environment = var.environment
    Application = "message-broker"
  }
}

