output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_domain" {
  description = "Hosted UI domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "client_ids" {
  description = "Map of client names to their IDs"
  value = {
    django  = aws_cognito_user_pool_client.django.id
    android = aws_cognito_user_pool_client.android.id
    lambda  = aws_cognito_user_pool_client.lambda.id
  }
}

output "client_secrets" {
  description = "Secret for Django client (others use PKCE and have no secret)"
  sensitive   = true
  value       = aws_cognito_user_pool_client.django.client_secret
}

output "group_names" {
  description = "List of created group names"
  value       = [for g in aws_cognito_user_group.groups : g.name]
}


output "login_url" {
  description = "Cognito Hosted UI login URL for the Django app"
  value = format(
    "https://%s.auth.%s.amazoncognito.com/login?client_id=%s&response_type=code&scope=email+openid+profile&redirect_uri=%s",
    aws_cognito_user_pool_domain.main.domain,
    data.aws_region.current.name,
    aws_cognito_user_pool_client.django.id,
    var.django_callback_urls[0]
  )
}

output "signup_url" {
  description = "Cognito Hosted UI signup (sign up) URL for the Django app"
  value = format(
    "https://%s.auth.%s.amazoncognito.com/signup?client_id=%s&response_type=code&scope=email+openid+profile&redirect_uri=%s",
    aws_cognito_user_pool_domain.main.domain,
    data.aws_region.current.name,
    aws_cognito_user_pool_client.django.id,
    var.django_callback_urls[0]
  )
}