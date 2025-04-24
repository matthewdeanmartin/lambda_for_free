terraform {
  backend "s3" {
    bucket = "java-serverless-container-tf-state-asdf"
    key    = "java-serverless-container/state"
    region = "us-east-2"
  }
}
