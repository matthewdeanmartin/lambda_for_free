variable "name" {
    type = string
    description = "The name of the product"
}

variable "lambda_entrypoint" {
    type = string
    description = "The entrypoint function name"
}

variable "cors_origin" {
    type = string
    default = ""
}