variable "name" {
  type        = string
  description = "The name of the ec2 machine"
}


variable "environment" {
  type    = string
  default = "dev"
}
