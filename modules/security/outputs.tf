output "alb_security_group_id" {
  description = "Security group for the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "Security group for the backend EC2 instances."
  value       = aws_security_group.app.id
}

output "mongo_security_group_id" {
  description = "Security group for the MongoDB host."
  value       = aws_security_group.mongo.id
}

output "redis_security_group_id" {
  description = "Security group for ElastiCache Redis."
  value       = aws_security_group.redis.id
}
