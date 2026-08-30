output "role_arn" {
  description = "ARN GitHub Actions can assume via OIDC."
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "deployer_user_name" {
  description = "IAM user the pipelines authenticate as."
  value       = aws_iam_user.deployer.name
}

output "deployer_access_key_id" {
  description = "Store in GitHub as AWS_ACCESS_KEY_ID."
  value       = aws_iam_access_key.deployer.id
}

output "deployer_secret_access_key" {
  description = "Store in GitHub as AWS_SECRET_ACCESS_KEY."
  value       = aws_iam_access_key.deployer.secret
  sensitive   = true
}
