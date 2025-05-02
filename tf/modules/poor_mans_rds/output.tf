output "postgres_instance_id" {
  value = aws_instance.postgres.id
}

output "postgres_public_ip" {
  value = aws_instance.postgres.public_ip
}

output "postgres_sg_id" {
  value = aws_security_group.postgres_sg.id
}

output "lambda_sg_id" {
  value = aws_security_group.lambda_sg.id
}