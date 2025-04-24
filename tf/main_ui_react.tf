locals {
  react_bucket = "lambda-for-free-react-asdf-ui"
}
resource "aws_s3_bucket" "ui_react" {
  bucket = local.react_bucket
  tags = {
    Name        = "UI Bucket"
    Environment = "Dev"
  }
}


resource "aws_s3_bucket_public_access_block" "ui_public_react" {
  bucket = aws_s3_bucket.ui_react.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "ui_policy_react" {
  bucket = aws_s3_bucket.ui_react.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "arn:aws:s3:::${local.react_bucket}/*"
      }
    ]
  })
}

resource "aws_s3_bucket_website_configuration" "website_react" {
  bucket = aws_s3_bucket.ui_react.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}