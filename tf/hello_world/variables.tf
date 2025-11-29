locals {
  environment = var.environment
  region      = var.region # "us-east-2"
  default_tags = {
    Product     = "Hello World"
    Terraform   = "true"
    Environment = var.environment
  }
}

variable "environment" {
  type = string
}

# variables.tf
variable "is_active_region" {
  description = "Whether this region is the active primary region"
  type        = bool
}

variable "region" {
  description = "Which AWS region"
  type        = string
}