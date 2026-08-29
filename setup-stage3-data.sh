#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# much-to-do-infra : Stage 3  (security groups + MongoDB + Redis + secrets)
#
# Run from INSIDE your much-to-do-infra folder:
#     bash setup-stage3-data.sh
# ---------------------------------------------------------------------------
set -euo pipefail

echo "Creating folder structure..."
mkdir -p modules/security modules/data/templates

# ---------------------------------------------------------------------------
# versions.tf  -- now also needs the random provider
# ---------------------------------------------------------------------------
cat > versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
EOF

# ---------------------------------------------------------------------------
# variables.tf  -- adds admin_ip_cidr and instance sizing
# ---------------------------------------------------------------------------
cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS region everything is deployed into."
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Short name prefixed onto every resource."
  type        = string
  default     = "much-to-do"
}

variable "owner" {
  description = "Who owns this stack (used as a tag)."
  type        = string
  default     = "reena"
}

variable "vpc_cidr" {
  description = "IP address range for the whole VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "The two AZs we spread across for high availability."
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "public_subnet_cidrs" {
  description = "Ranges for the public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Ranges for the private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "admin_ip_cidr" {
  description = <<-DESC
    Your own public IP in CIDR form, e.g. "102.89.1.5/32".
    Temporarily allows you to curl the load balancer directly while testing.
    Leave empty to lock the ALB down to CloudFront only.
  DESC
  type        = string
  default     = ""
}

variable "mongo_instance_type" {
  description = "EC2 size for the MongoDB host."
  type        = string
  default     = "t3.small"
}

variable "mongo_username" {
  description = "MongoDB root username."
  type        = string
  default     = "muchtodousr"
}

variable "mongo_db_name" {
  description = "Database name the application uses."
  type        = string
  default     = "much_todo_db"
}

variable "redis_node_type" {
  description = "ElastiCache node size."
  type        = string
  default     = "cache.t4g.micro"
}
EOF

# ---------------------------------------------------------------------------
# main.tf
# ---------------------------------------------------------------------------
cat > main.tf << 'EOF'
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
}

##############################################################################
# Data layer : MongoDB on EC2 + ElastiCache Redis, both in private subnets
##############################################################################
module "data" {
  source = "./modules/data"

  project_name        = var.project_name
  aws_region          = var.aws_region
  private_subnet_ids  = module.network.private_subnet_ids
  mongo_security_group_id = module.security.mongo_security_group_id
  redis_security_group_id = module.security.redis_security_group_id
  mongo_instance_type = var.mongo_instance_type
  mongo_username      = var.mongo_username
  mongo_db_name       = var.mongo_db_name
  redis_node_type     = var.redis_node_type
}
EOF

# ---------------------------------------------------------------------------
# outputs.tf
# ---------------------------------------------------------------------------
cat > outputs.tf << 'EOF'
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
  description = "Instance ID of the MongoDB host (use with SSM Session Manager)."
  value       = module.data.mongo_instance_id
}

output "mongo_private_ip" {
  description = "Private IP of the MongoDB host."
  value       = module.data.mongo_private_ip
}

output "redis_primary_endpoint" {
  description = "Redis endpoint the backend connects to."
  value       = module.data.redis_primary_endpoint
}

output "ssm_parameter_names" {
  description = "Where the backend reads its configuration from at boot."
  value       = module.data.ssm_parameter_names
}
EOF

# ===========================================================================
# modules/security
# ===========================================================================

cat > modules/security/variables.tf << 'EOF'
variable "project_name" {
  description = "Short name prefixed onto every resource."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security groups belong to."
  type        = string
}

variable "admin_ip_cidr" {
  description = "Optional single IP allowed to reach the ALB directly for testing."
  type        = string
  default     = ""
}

variable "app_port" {
  description = "Port the Go backend listens on."
  type        = number
  default     = 8080
}
EOF

cat > modules/security/main.tf << 'EOF'
##############################################################################
# CloudFront's published list of edge server IP ranges. Using this means the
# load balancer only accepts traffic that actually came through CloudFront.
##############################################################################
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

##############################################################################
# Security groups. Rules are declared separately from the groups so that two
# groups can reference each other without creating a circular dependency.
##############################################################################

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Public entry point. Accepts HTTP from CloudFront only."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Backend EC2 instances. Accepts traffic from the ALB only."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

resource "aws_security_group" "mongo" {
  name        = "${var.project_name}-mongo-sg"
  description = "MongoDB host. Accepts 27017 from the backend only."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-mongo-sg"
  }
}

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "ElastiCache Redis. Accepts 6379 from the backend only."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-redis-sg"
  }
}

##############################################################################
# ALB rules
##############################################################################
resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from CloudFront edge locations"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
}

# Only created when admin_ip_cidr is set. For testing with curl.
resource "aws_vpc_security_group_ingress_rule" "alb_from_admin" {
  count = var.admin_ip_cidr == "" ? 0 : 1

  security_group_id = aws_security_group.alb.id
  description       = "Temporary direct access for testing"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.admin_ip_cidr
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests to the backend instances"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

##############################################################################
# Backend application rules
##############################################################################
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application traffic from the load balancer"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

# Outbound is open so instances can reach SSM, CloudWatch, S3 and package
# repositories through the NAT gateway. Inbound remains locked down.
resource "aws_vpc_security_group_egress_rule" "app_outbound" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound to AWS services and package repos via NAT"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

##############################################################################
# MongoDB rules
##############################################################################
resource "aws_vpc_security_group_ingress_rule" "mongo_from_app" {
  security_group_id            = aws_security_group.mongo.id
  description                  = "MongoDB wire protocol from the backend"
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "mongo_outbound" {
  security_group_id = aws_security_group.mongo.id
  description       = "Outbound for docker pull, SSM and updates via NAT"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

##############################################################################
# Redis rules
##############################################################################
resource "aws_vpc_security_group_ingress_rule" "redis_from_app" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from the backend"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.app.id
}
EOF

cat > modules/security/outputs.tf << 'EOF'
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
EOF

# ===========================================================================
# modules/data
# ===========================================================================

cat > modules/data/variables.tf << 'EOF'
variable "project_name" {
  description = "Short name prefixed onto every resource."
  type        = string
}

variable "aws_region" {
  description = "Region, passed into the instance bootstrap script."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the database tier."
  type        = list(string)
}

variable "mongo_security_group_id" {
  description = "Security group applied to the MongoDB host."
  type        = string
}

variable "redis_security_group_id" {
  description = "Security group applied to ElastiCache."
  type        = string
}

variable "mongo_instance_type" {
  description = "EC2 size for the MongoDB host."
  type        = string
}

variable "mongo_username" {
  description = "MongoDB root username."
  type        = string
}

variable "mongo_db_name" {
  description = "Application database name."
  type        = string
}

variable "redis_node_type" {
  description = "ElastiCache node size."
  type        = string
}
EOF

cat > modules/data/main.tf << 'EOF'
##############################################################################
# Latest Amazon Linux 2023 AMI, looked up rather than hardcoded
##############################################################################
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

##############################################################################
# Generated secrets. special = false keeps them URL-safe so they can be
# embedded in a MongoDB connection string without percent-encoding.
##############################################################################
resource "random_password" "mongo" {
  length  = 32
  special = false
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}

##############################################################################
# Parameter Store. The application reads these at boot using its IAM role,
# which is why no secret ever appears in git or in a pipeline variable.
##############################################################################
resource "aws_ssm_parameter" "mongo_password" {
  name  = "/${var.project_name}/mongo/password"
  type  = "SecureString"
  value = random_password.mongo.result
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/${var.project_name}/app/jwt_secret"
  description = "Shared across both backend instances so sessions survive failover"
  type        = "SecureString"
  value       = random_password.jwt.result
}

resource "aws_ssm_parameter" "mongo_uri" {
  name  = "/${var.project_name}/app/mongo_uri"
  type  = "SecureString"
  value = "mongodb://${var.mongo_username}:${random_password.mongo.result}@${aws_instance.mongo.private_ip}:27017/?replicaSet=rs0&authSource=admin"
}

resource "aws_ssm_parameter" "redis_addr" {
  name  = "/${var.project_name}/app/redis_addr"
  type  = "String"
  value = "${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/app/db_name"
  type  = "String"
  value = var.mongo_db_name
}

##############################################################################
# IAM role for the MongoDB host. Grants Session Manager access (so we never
# need SSH or a bastion) and permission to read its own password.
##############################################################################
resource "aws_iam_role" "mongo" {
  name = "${var.project_name}-mongo-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "mongo_ssm_core" {
  role       = aws_iam_role.mongo.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "mongo_read_secret" {
  name = "${var.project_name}-mongo-read-secret"
  role = aws_iam_role.mongo.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = aws_ssm_parameter.mongo_password.arn
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = data.aws_kms_alias.ssm.target_key_arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongo" {
  name = "${var.project_name}-mongo-profile"
  role = aws_iam_role.mongo.name
}

##############################################################################
# The MongoDB host itself. Single-node replica set, because the application
# uses transactions and MongoDB refuses those on a standalone server.
##############################################################################
resource "aws_instance" "mongo" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.mongo_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.mongo_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.mongo.name

  user_data                   = templatefile("${path.module}/templates/mongo-user-data.sh.tftpl", {
    region               = var.aws_region
    mongo_user           = var.mongo_username
    mongo_password_param = aws_ssm_parameter.mongo_password.name
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name = "${var.project_name}-mongodb"
    Role = "database"
  }
}

##############################################################################
# ElastiCache Redis. Two nodes across two AZs with automatic failover.
##############################################################################
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnets"
  subnet_ids = var.private_subnet_ids
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.project_name}-redis"
  description          = "Cache for the Much-to-Do backend"

  engine               = "redis"
  engine_version       = "7.1"
  parameter_group_name = "default.redis7"
  node_type            = var.redis_node_type
  port                 = 6379

  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [var.redis_security_group_id]

  # The Go redis client in this application connects without TLS.
  transit_encryption_enabled = false
  at_rest_encryption_enabled = true

  apply_immediately = true

  tags = {
    Name = "${var.project_name}-redis"
  }
}
EOF

cat > modules/data/outputs.tf << 'EOF'
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
EOF

cat > modules/data/templates/mongo-user-data.sh.tftpl << 'EOF'
#!/bin/bash
set -uxo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== MongoDB bootstrap starting ==="

dnf update -y
dnf install -y docker openssl
command -v aws >/dev/null 2>&1 || dnf install -y awscli-2 || true

systemctl enable --now docker

# Find our own private IP via IMDSv2. The replica set member has to be
# registered under an address the backend can actually dial.
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)
echo "Private IP is $PRIVATE_IP"

MONGO_USER="${mongo_user}"
MONGO_PASS=$(aws ssm get-parameter \
  --name "${mongo_password_param}" \
  --with-decryption \
  --region "${region}" \
  --query 'Parameter.Value' \
  --output text)

# MongoDB requires a shared keyfile for internal authentication as soon as
# both replication and access control are switched on.
mkdir -p /opt/mongo/keyfile /opt/mongo/data
openssl rand -base64 756 > /opt/mongo/keyfile/mongodb.key
chmod 400 /opt/mongo/keyfile/mongodb.key
chown 999:999 /opt/mongo/keyfile/mongodb.key
chown -R 999:999 /opt/mongo/data

docker run -d --name mongodb --restart unless-stopped \
  -p 27017:27017 \
  -v /opt/mongo/data:/data/db \
  -v /opt/mongo/keyfile:/data/keyfile:ro \
  -e MONGO_INITDB_ROOT_USERNAME="$MONGO_USER" \
  -e MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASS" \
  mongo:8.0 \
  --replSet rs0 --bind_ip_all --keyFile /data/keyfile/mongodb.key

echo "Waiting for mongod to accept connections..."
for i in $(seq 1 60); do
  if docker exec mongodb mongosh --quiet --eval 'db.runCommand({ping:1})' >/dev/null 2>&1; then
    echo "mongod is up"
    break
  fi
  sleep 5
done

echo "Initiating replica set..."
docker exec mongodb mongosh \
  -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet \
  --eval "try { rs.status().ok } catch (e) { rs.initiate({_id: 'rs0', members: [{_id: 0, host: '$PRIVATE_IP:27017'}]}) }"

sleep 10
docker exec mongodb mongosh \
  -u "$MONGO_USER" -p "$MONGO_PASS" --authenticationDatabase admin --quiet \
  --eval "rs.status().myState"

echo "=== MongoDB bootstrap finished ==="
EOF

echo ""
echo "Done. Files written:"
find . -name "*.tf" -o -name "*.tftpl" | sort
echo ""
echo "Next:  terraform init  ->  terraform plan  ->  terraform apply"
