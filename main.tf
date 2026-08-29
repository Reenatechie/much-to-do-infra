##############################################################################
# Networking : VPC, public + private subnets across 2 AZs, IGW, NAT gateways
##############################################################################
module "network" {
  source = "./modules/network"

  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

##############################################################################
# Security : one security group per tier, least privilege between them
##############################################################################
module "security" {
  source = "./modules/security"

  project_name  = var.project_name
  vpc_id        = module.network.vpc_id
  admin_ip_cidr = var.admin_ip_cidr
  app_port      = var.app_port
}

##############################################################################
# Data layer : MongoDB on EC2 + ElastiCache Redis, both in private subnets
##############################################################################
module "data" {
  source = "./modules/data"

  project_name            = var.project_name
  aws_region              = var.aws_region
  private_subnet_ids      = module.network.private_subnet_ids
  mongo_security_group_id = module.security.mongo_security_group_id
  redis_security_group_id = module.security.redis_security_group_id
  mongo_instance_type     = var.mongo_instance_type
  mongo_username          = var.mongo_username
  mongo_db_name           = var.mongo_db_name
  redis_node_type         = var.redis_node_type
}

##############################################################################
# Compute : two backend instances behind an Application Load Balancer
##############################################################################
module "compute" {
  source = "./modules/compute"

  project_name          = var.project_name
  aws_region            = var.aws_region
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  app_security_group_id = module.security.app_security_group_id

  instance_type   = var.app_instance_type
  instance_count  = var.app_instance_count
  app_port        = var.app_port
  app_repo_url    = var.app_repo_url
  app_repo_branch = var.app_repo_branch
  go_version      = var.go_version

  depends_on = [module.data]
}

##############################################################################
# Frontend : S3 + CloudFront.
#
# The distribution fronts BOTH the React app and the API:
#
#     https://<domain>/          -> S3 bucket   (the SPA)
#     https://<domain>/api/...   -> ALB         (the Go backend)
#
# Serving both from one domain makes them same-origin. That matters because
# this application authenticates with httpOnly cookies and axios sends them
# with withCredentials. Across two different domains the browser would treat
# the cookie as third-party and silently drop it, so every request after
# login would come back 401. Same-origin also removes CORS entirely and
# avoids mixed-content blocking, since an HTTPS page cannot call an HTTP ALB.
##############################################################################
module "frontend" {
  source = "./modules/frontend"

  project_name = var.project_name
  alb_dns_name = module.compute.alb_dns_name
}

##############################################################################
# Runtime configuration for the backend.
#
# These live at the root rather than inside the compute module because their
# values come from CloudFront, and CloudFront already depends on compute.
##############################################################################
resource "aws_ssm_parameter" "public_origin" {
  name  = "/${var.project_name}/app/public_origin"
  type  = "String"
  value = "https://${module.frontend.cloudfront_domain_name}"
}

resource "aws_ssm_parameter" "cookie_domain" {
  name  = "/${var.project_name}/app/cookie_domain"
  type  = "String"
  value = module.frontend.cloudfront_domain_name
}

resource "aws_ssm_parameter" "secure_cookie" {
  name  = "/${var.project_name}/app/secure_cookie"
  type  = "String"
  value = "true"
}

# Tell Terraform these three moved out of the compute module rather than
# being deleted and recreated.
moved {
  from = module.compute.aws_ssm_parameter.public_origin
  to   = aws_ssm_parameter.public_origin
}

moved {
  from = module.compute.aws_ssm_parameter.cookie_domain
  to   = aws_ssm_parameter.cookie_domain
}

moved {
  from = module.compute.aws_ssm_parameter.secure_cookie
  to   = aws_ssm_parameter.secure_cookie
}
