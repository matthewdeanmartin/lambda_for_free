terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.81.0"
    }
  }
}

# Cheapest instance and free-tier resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group allowing only Lambda SG (placeholder) to access PostgreSQL
resource "aws_security_group" "postgres_sg" {
  name        = "postgres-sg"
  description = "Allow Lambda access to Postgres"
  vpc_id      = aws_vpc.main.id

  # Only allow PostgreSQL (5432) from Lambda SG
  ingress {
    description      = "PostgreSQL from Lambda"
    from_port        = 5432
    to_port          = 5432
    protocol         = "tcp"
    security_groups  = [aws_security_group.lambda_sg.id]
  }

  # Allow outbound traffic (default)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Dummy Lambda SG to show reference (replace or import real Lambda SG)
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Lambda security group for EC2/Postgres access"
  vpc_id      = aws_vpc.main.id
}

# IAM Role for EC2 SSM access
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Launch tiny EC2 instance with PostgreSQL installation at boot
resource "aws_instance" "postgres" {
  ami           = "ami-075adf72623183922"  # Amazon Linux 2023 ARM AMI, us-east-2
  instance_type = "t4g.nano"               # Cheapest ARM instance
  subnet_id     = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.postgres_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras enable postgresql14
              yum install -y postgresql-server postgresql-contrib
              postgresql-setup --initdb
              systemctl enable postgresql
              systemctl start postgresql
              EOF

  tags = {
    Name = var.name
    Environment = var.environment
  }
}
