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
