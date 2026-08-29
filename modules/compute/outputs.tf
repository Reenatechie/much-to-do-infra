output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "target_group_arn" {
  description = "ARN of the backend target group."
  value       = aws_lb_target_group.app.arn
}

output "instance_ids" {
  description = "Instance IDs of the backend servers."
  value       = aws_instance.app[*].id
}

output "artifacts_bucket" {
  description = "Bucket CI/CD uploads backend builds to."
  value       = aws_s3_bucket.artifacts.bucket
}

output "log_group_name" {
  description = "CloudWatch log group holding application logs."
  value       = aws_cloudwatch_log_group.app.name
}

output "app_role_arn" {
  description = "IAM role attached to the backend instances."
  value       = aws_iam_role.app.arn
}
