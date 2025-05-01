variable "bucket_name" {
    type = string
    description = "The name of the bucket"
}
variable "tags" {
    type = map(string)
    default = {
        Name        = "UI Bucket"
        Environment = "Dev"
    }
    description = "Tags to apply to the S3 bucket"
}