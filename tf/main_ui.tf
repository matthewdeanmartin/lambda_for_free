resource "aws_s3_bucket" "ui" {
  bucket = "lambda-for-free-asdf-ui"
  tags = {
    Name        = "UI Bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.ui.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }

  # routing_rule {
  #   condition {
  #     key_prefix_equals = "docs/"
  #   }
  #   redirect {
  #     replace_key_prefix_with = "documents/"
  #   }
  # }
}