output "bucket_domain_name" {
  value = aws_s3_bucket.ui.bucket_domain_name
}

output "bucket_name" {
  value = aws_s3_bucket.ui.id
}

output "website_endpoint" {
  value = aws_s3_bucket_website_configuration.website.website_endpoint
}