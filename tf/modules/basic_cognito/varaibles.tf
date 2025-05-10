variable "product" {
  description = "Product name for namespacing"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "domain_prefix" {
  description = "Prefix for Cognito hosted domain (must be globally unique)"
  type        = string
}

variable "android_callback_urls" {
  type        = list(string)
  description = "Callback URLs for the Android app"
}

variable "lambda_callback_urls" {
  type        = list(string)
  description = "Callback URLs for the Lambda app"
}

variable "django_callback_urls" {
  type        = list(string)
  description = "Callback URLs for the Django app"
}

variable "is_test" {
  type = bool
  default = false
  description = "Disables destruction unless it is a test"
}