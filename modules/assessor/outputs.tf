output "user_name" {
  description = "Console sign-in username."
  value       = aws_iam_user.assessor.name
}

output "console_url" {
  description = "Account sign-in page."
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

output "console_password" {
  description = "Console sign-in password."
  value       = aws_iam_user_login_profile.assessor.password
  sensitive   = true
}

output "access_key_id" {
  description = "CLI access key ID."
  value       = aws_iam_access_key.assessor.id
}

output "secret_access_key" {
  description = "CLI secret access key."
  value       = aws_iam_access_key.assessor.secret
  sensitive   = true
}
