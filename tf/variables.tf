locals {
  environment = "PROD"
  region      = "us-east-2"
  default_tags = {
    Terraform   = "true"
    Environment = var.environment
  }
}

variable "environment" {
  type = string
}