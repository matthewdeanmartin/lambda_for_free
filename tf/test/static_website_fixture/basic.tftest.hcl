run "basic" {
  command = plan

  assert {
    condition = length(aws_s3_bucket.ui) > 0
    error_message   = "Expected at least one S3 bucket"
  }

  assert {
    condition = aws_s3_bucket_website_configuration.website.index_document.suffix == "index.html"
    error_message   = "Expected index document to be 'index.html'"
  }
}