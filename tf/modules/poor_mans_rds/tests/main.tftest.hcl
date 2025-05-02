# Use moto.
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  // override endpoints to point to localstack
  endpoints {

    account        = "http://localhost:5000"
    apigateway     = "http://localhost:5000"
    apigatewayv2   = "http://localhost:5000"
    autoscaling    = "http://localhost:5000"
    cloudwatch     = "http://localhost:5000"
    cloudwatchlogs = "http://localhost:5000"
    dynamodb       = "http://localhost:5000"

    ec2 = "http://localhost:5000"

    eks    = "http://localhost:5000"
    iam    = "http://localhost:5000"
    lambda = "http://localhost:5000"

    sts = "http://localhost:5000"
    s3  = "http://localhost:5000"
  }
}

variables {
  name        = "test-postgres"
  environment = "test"
}

run "setup_tests" {
  module {
    source = "./tests/setup"
  }
}



run "verify_vpc_and_subnet" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.0.0.0/16"
    error_message = "VPC CIDR block does not match expected value"
  }

  assert {
    condition     = aws_subnet.public.cidr_block == "10.0.1.0/24"
    error_message = "Public subnet CIDR block does not match expected value"
  }

  assert {
    condition     = aws_subnet.public.map_public_ip_on_launch == true
    error_message = "Public subnet does not have map_public_ip_on_launch enabled"
  }
}

run "verify_ec2_instance" {
  command = apply

  assert {
    condition     = aws_instance.postgres.instance_type == "t4g.nano"
    error_message = "EC2 instance type is not t4g.nano"
  }

  assert {
    condition     = aws_instance.postgres.ami == "ami-075adf72623183922"
    error_message = "EC2 AMI does not match expected value"
  }

  assert {
    condition     = aws_instance.postgres.subnet_id != ""
    error_message = "EC2 instance subnet ID is empty"
  }
}

run "verify_security_groups" {
  command = apply

  assert {
    condition     = length(aws_security_group.postgres_sg.ingress) > 0
    error_message = "Postgres security group has no ingress rules"
  }

  assert {
    condition     = aws_security_group.lambda_sg.vpc_id == aws_vpc.main.id
    error_message = "Lambda security group is not in the expected VPC"
  }
}