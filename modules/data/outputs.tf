output "mongo_instance_id" {
  description = "Instance ID of the MongoDB host."
  value       = aws_instance.mongo.id
}

output "mongo_private_ip" {
  description = "Private IP of the MongoDB host."
  value       = aws_instance.mongo.private_ip
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint address."
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "ssm_parameter_names" {
  description = "Parameter Store paths the backend reads at boot."
  value = {
    mongo_uri  = aws_ssm_parameter.mongo_uri.name
    redis_addr = aws_ssm_parameter.redis_addr.name
    jwt_secret = aws_ssm_parameter.jwt_secret.name
    db_name    = aws_ssm_parameter.db_name.name
  }
}

output "ssm_parameter_arns" {
  description = "ARNs so the backend role can be granted read access."
  value = [
    aws_ssm_parameter.mongo_uri.arn,
    aws_ssm_parameter.redis_addr.arn,
    aws_ssm_parameter.jwt_secret.arn,
    aws_ssm_parameter.db_name.arn,
  ]
}
