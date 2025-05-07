variable "name" {
  type        = string
  description = "The name of the product"
}

variable "lambda_entrypoint" {
  type        = string
  description = "The entrypoint function name"
}

variable "cors_origin" {
  type = list(string)
  default = []
}

variable "queue_name" {
  type    = string
  default = "app-message-queue"
}

variable "dynamodb_table_name" {
  type    = string
  default = "message-broker-rest"
}

variable "environment" {
  type    = string
  default = "dev"
}
