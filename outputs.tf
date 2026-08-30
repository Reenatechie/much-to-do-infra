output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (ALB lives here)."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (EC2 and databases live here)."
  value       = module.network.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs private instances appear as when calling out."
  value       = module.network.nat_gateway_public_ips
}

output "mongo_instance_id" {
  description = "Instance ID of the MongoDB host."
  value       = module.data.mongo_instance_id
}

output "redis_primary_endpoint" {
  description = "Redis endpoint the backend connects to."
  value       = module.data.redis_primary_endpoint
}

output "alb_dns_name" {
  description = "Public DNS name of the load balancer."
  value       = module.compute.alb_dns_name
}

output "app_instance_ids" {
  description = "Instance IDs of the two backend servers."
  value       = module.compute.instance_ids
}

output "artifacts_bucket" {
  description = "S3 bucket the CI/CD pipeline uploads backend builds to."
  value       = module.compute.artifacts_bucket
}

output "log_group_name" {
  description = "CloudWatch log group holding application logs."
  value       = module.compute.log_group_name
}

##############################################################################
# The three values below are what the CI/CD pipelines and the submission
# document need.
##############################################################################

output "live_url" {
  description = "THE LIVE APPLICATION URL - submit this one."
  value       = "https://${module.frontend.cloudfront_domain_name}"
}

output "frontend_bucket" {
  description = "S3 bucket the built React app is uploaded to."
  value       = module.frontend.bucket_name
}

output "cloudfront_distribution_id" {
  description = "Distribution ID, used to invalidate the cache after a deploy."
  value       = module.frontend.distribution_id
}

output "github_actions_role_arn" {
  description = "Add this to GitHub as the secret AWS_DEPLOY_ROLE_ARN."
  value       = module.cicd.role_arn
}

output "deployer_access_key_id" {
  description = "Add to GitHub as the secret AWS_ACCESS_KEY_ID."
  value       = module.cicd.deployer_access_key_id
}

output "deployer_secret_access_key" {
  description = "Add to GitHub as the secret AWS_SECRET_ACCESS_KEY."
  value       = module.cicd.deployer_secret_access_key
  sensitive   = true
}

##############################################################################
# Assessor credentials - submit these, not your own.
##############################################################################

output "assessor_user_name" {
  description = "Console sign-in username for the assessor."
  value       = module.assessor.user_name
}

output "assessor_console_url" {
  description = "Console sign-in page for the assessor."
  value       = module.assessor.console_url
}

output "assessor_console_password" {
  description = "Console password. Retrieve with: terraform output -raw assessor_console_password"
  value       = module.assessor.console_password
  sensitive   = true
}

output "assessor_access_key_id" {
  description = "CLI access key ID for the assessor."
  value       = module.assessor.access_key_id
}

output "assessor_secret_access_key" {
  description = "CLI secret key. Retrieve with: terraform output -raw assessor_secret_access_key"
  value       = module.assessor.secret_access_key
  sensitive   = true
}
