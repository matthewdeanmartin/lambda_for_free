#
# resource "aws_s3_bucket" "ui" {
#   bucket = var.bucket_name
#   tags = {
#     Name        = "UI Bucket"
#     Environment = "Dev"
#   }
#   force_destroy = true
#   lifecycle {
#     prevent_destroy = false
#   }
# }
#
#
# resource "aws_s3_bucket_public_access_block" "ui_public" {
#   bucket = aws_s3_bucket.ui.id
#
#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }
#
# resource "aws_s3_bucket_policy" "ui_policy" {
#   bucket = aws_s3_bucket.ui.id
#
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid       = "PublicReadGetObject",
#         Effect    = "Allow",
#         Principal = "*",
#         Action    = "s3:GetObject",
#         Resource  = "arn:aws:s3:::${var.bucket_name}/*"
#       }
#     ]
#   })
# }
#
# resource "aws_s3_bucket_website_configuration" "website" {
#   bucket = aws_s3_bucket.ui.id
#
#   index_document {
#     suffix = "index.html"
#   }
#
#   error_document {
#     key = "index.html"
#   }
# }
#
# output "bucket_domain_name" {
#   value = aws_s3_bucket.ui.bucket_domain_name
# }
#
# output "bucket_name" {
#   value = aws_s3_bucket.ui.id
# }
#
# output "website_endpoint" {
#   value = aws_s3_bucket_website_configuration.website.website_endpoint
# }
#
# variable "bucket_name" {
#     type = string
#     description = "The name of the bucket"
# }
# variable "tags" {
#     type = map(string)
#     default = {
#         Name        = "UI Bucket"
#         Environment = "Dev"
#     }
#     description = "Tags to apply to the S3 bucket"
# }