#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# much-to-do-infra : Stage 4  (backend EC2 x2 + ALB + CloudWatch logs)
#
# Run from INSIDE your much-to-do-infra folder:
#     bash setup-stage4-backend.sh
# ---------------------------------------------------------------------------
set -euo pipefail

echo "Creating folder structure..."
mkdir -p modules/compute/templates

# ---------------------------------------------------------------------------
# variables.tf
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
  description = "Your own public IP in CIDR form, for testing the ALB directly."
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

##############################################################################
# Backend application
##############################################################################

variable "app_instance_type" {
  description = "EC2 size for the backend instances."
  type        = string
  default     = "t3.small"
}

variable "app_instance_count" {
  description = "How many backend instances. Two is the project minimum."
  type        = number
  default     = 2
}

variable "app_port" {
  description = "Port the Go backend listens on."
  type        = number
  default     = 8080
}

variable "app_repo_url" {
  description = "Your fork of the application repository."
  type        = string
  default     = "https://github.com/Reenatechie/much-to-do.git"
}

variable "app_repo_branch" {
  description = "Branch to build from on first boot."
  type        = string
  default     = "main"
}

variable "go_version" {
  description = "Go toolchain version used to compile the backend."
  type        = string
  default     = "1.25.1"
}

variable "public_origin" {
  description = <<-DESC
    The public URL the browser loads the app from. Stays as localhost until
    CloudFront exists in the next stage, then becomes the CloudFront domain.
  DESC
  type        = string
  default     = "http://localhost:5173"
}

variable "cookie_domain" {
  description = "Domain the session cookie is issued for."
  type        = string
  default     = "localhost"
}

variable "secure_cookie" {
  description = "Only true once traffic is served over HTTPS."
  type        = bool
  default     = false
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

  public_origin = var.public_origin
  cookie_domain = var.cookie_domain
  secure_cookie = var.secure_cookie

  depends_on = [module.data]
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
  description = "Instance ID of the MongoDB host."
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
EOF

# ===========================================================================
# modules/compute
# ===========================================================================

cat > modules/compute/variables.tf << 'EOF'
variable "project_name" {
  type        = string
  description = "Short name prefixed onto every resource."
}

variable "aws_region" {
  type        = string
  description = "Region, passed into the instance bootstrap script."
}

variable "vpc_id" {
  type        = string
  description = "VPC the load balancer and instances live in."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets for the load balancer."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the backend instances."
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group for the load balancer."
}

variable "app_security_group_id" {
  type        = string
  description = "Security group for the backend instances."
}

variable "instance_type" {
  type        = string
  description = "EC2 size for the backend instances."
}

variable "instance_count" {
  type        = number
  description = "Number of backend instances."
}

variable "app_port" {
  type        = number
  description = "Port the Go backend listens on."
}

variable "app_repo_url" {
  type        = string
  description = "Application repository cloned on first boot."
}

variable "app_repo_branch" {
  type        = string
  description = "Branch to build from."
}

variable "go_version" {
  type        = string
  description = "Go toolchain version."
}

variable "public_origin" {
  type        = string
  description = "Public URL the browser loads the app from."
}

variable "cookie_domain" {
  type        = string
  description = "Domain the session cookie is issued for."
}

variable "secure_cookie" {
  type        = bool
  description = "Whether the session cookie requires HTTPS."
}
EOF

cat > modules/compute/main.tf << 'EOF'
data "aws_caller_identity" "current" {}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_kms_alias" "ssm" {
  name = "alias/aws/ssm"
}

##############################################################################
# Runtime configuration that changes between stages. Kept in Parameter Store
# so the instances can be reconfigured without being rebuilt.
##############################################################################
resource "aws_ssm_parameter" "public_origin" {
  name  = "/${var.project_name}/app/public_origin"
  type  = "String"
  value = var.public_origin
}

resource "aws_ssm_parameter" "cookie_domain" {
  name  = "/${var.project_name}/app/cookie_domain"
  type  = "String"
  value = var.cookie_domain
}

resource "aws_ssm_parameter" "secure_cookie" {
  name  = "/${var.project_name}/app/secure_cookie"
  type  = "String"
  value = tostring(var.secure_cookie)
}

##############################################################################
# Bucket the CI/CD pipeline drops compiled backend binaries into
##############################################################################
resource "aws_s3_bucket" "artifacts" {
  bucket = "${var.project_name}-artifacts-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

##############################################################################
# CloudWatch log groups
##############################################################################
resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/backend"
  retention_in_days = 14

  tags = {
    Name = "${var.project_name}-backend-logs"
  }
}

resource "aws_cloudwatch_log_group" "bootstrap" {
  name              = "/${var.project_name}/bootstrap"
  retention_in_days = 7
}

##############################################################################
# IAM role for the backend instances
##############################################################################
resource "aws_iam_role" "app" {
  name = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Lets the pipeline drive the instances through Systems Manager instead of SSH
resource "aws_iam_role_policy_attachment" "app_ssm_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Lets the CloudWatch agent ship logs
resource "aws_iam_role_policy_attachment" "app_cw_agent" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "app_runtime" {
  name = "${var.project_name}-app-runtime"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = data.aws_kms_alias.ssm.target_key_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.artifacts.arn
      }
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "${var.project_name}-app-profile"
  role = aws_iam_role.app.name
}

##############################################################################
# The backend instances. One per availability zone, both in private subnets.
##############################################################################
resource "aws_instance" "app" {
  count = var.instance_count

  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [var.app_security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.app.name

  user_data = templatefile("${path.module}/templates/app-user-data.sh.tftpl", {
    region           = var.aws_region
    project_name     = var.project_name
    app_port         = var.app_port
    repo_url         = var.app_repo_url
    repo_branch      = var.app_repo_branch
    go_version       = var.go_version
    artifacts_bucket = aws_s3_bucket.artifacts.bucket
    log_group        = aws_cloudwatch_log_group.app.name
    bootstrap_group  = aws_cloudwatch_log_group.bootstrap.name
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = {
    Name        = "${var.project_name}-backend-${count.index + 1}"
    Role        = "backend"
    DeployGroup = var.project_name
  }
}

##############################################################################
# Application Load Balancer in the public subnets
##############################################################################
resource "aws_lb" "this" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids
  idle_timeout       = 60

  tags = {
    Name = "${var.project_name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  # /health reports on MongoDB and Redis too, so an instance that has lost a
  # dependency is pulled out of rotation automatically.
  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  deregistration_delay = 15

  tags = {
    Name = "${var.project_name}-tg"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  count = var.instance_count

  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = var.app_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
EOF

cat > modules/compute/outputs.tf << 'EOF'
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
EOF

cat > modules/compute/templates/app-user-data.sh.tftpl << 'EOF'
#!/bin/bash
# Shell tracing is deliberately OFF: this script handles secrets.
set -uo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "=== Backend bootstrap starting ==="

dnf update -y
dnf install -y git tar gzip amazon-cloudwatch-agent
command -v aws >/dev/null 2>&1 || dnf install -y awscli-2 || true

useradd --system --no-create-home --shell /sbin/nologin muchtodo || true
mkdir -p /opt/much-to-do /var/log/much-to-do
chown muchtodo:muchtodo /var/log/much-to-do

# -------------------------------------------------------------------------
# refresh-config.sh
#
# Writes the .env file the application reads at startup. This has to be a
# real file rather than exported environment variables: the app loads its
# config with Viper, and Viper only maps environment variables onto fields
# it already knows about from a config file or a default. MONGO_URI and
# JWT_SECRET_KEY have neither, so without this file they arrive empty and
# the process exits.
# -------------------------------------------------------------------------
cat > /opt/much-to-do/refresh-config.sh << 'CONFIGEOF'
#!/bin/bash
set -uo pipefail

REGION="__REGION__"
PREFIX="__PREFIX__"

param() {
  aws ssm get-parameter --name "$1" --with-decryption \
    --region "$REGION" --query 'Parameter.Value' --output text
}

MONGO_URI=$(param "/$PREFIX/app/mongo_uri")
DB_NAME=$(param "/$PREFIX/app/db_name")
JWT_SECRET=$(param "/$PREFIX/app/jwt_secret")
REDIS_ADDR=$(param "/$PREFIX/app/redis_addr")
PUBLIC_ORIGIN=$(param "/$PREFIX/app/public_origin")
COOKIE_DOMAIN=$(param "/$PREFIX/app/cookie_domain")
SECURE_COOKIE=$(param "/$PREFIX/app/secure_cookie")

umask 077
cat > /opt/much-to-do/.env << ENVEOF
PORT=__APP_PORT__
MONGO_URI=$MONGO_URI
DB_NAME=$DB_NAME
JWT_SECRET_KEY=$JWT_SECRET
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=true
REDIS_ADDR=$REDIS_ADDR
REDIS_PASSWORD=
LOG_LEVEL=INFO
LOG_FORMAT=json
ALLOWED_ORIGINS=$PUBLIC_ORIGIN
COOKIE_DOMAINS=$COOKIE_DOMAIN
SECURE_COOKIE=$SECURE_COOKIE
ENVEOF

chown muchtodo:muchtodo /opt/much-to-do/.env
chmod 600 /opt/much-to-do/.env
echo "config refreshed"
CONFIGEOF

sed -i "s|__REGION__|${region}|g; s|__PREFIX__|${project_name}|g; s|__APP_PORT__|${app_port}|g" \
  /opt/much-to-do/refresh-config.sh
chmod 700 /opt/much-to-do/refresh-config.sh

# -------------------------------------------------------------------------
# deploy.sh - used by the CI/CD pipeline through SSM Run Command
# -------------------------------------------------------------------------
cat > /opt/much-to-do/deploy.sh << 'DEPLOYEOF'
#!/bin/bash
set -euo pipefail

BUCKET="__BUCKET__"
KEY="backend/much-to-do"

aws s3 cp "s3://$BUCKET/$KEY" /opt/much-to-do/much-to-do.new
chmod 755 /opt/much-to-do/much-to-do.new
mv /opt/much-to-do/much-to-do.new /opt/much-to-do/much-to-do
chown muchtodo:muchtodo /opt/much-to-do/much-to-do

/opt/much-to-do/refresh-config.sh
systemctl restart much-to-do
echo "deployed"
DEPLOYEOF

sed -i "s|__BUCKET__|${artifacts_bucket}|g" /opt/much-to-do/deploy.sh
chmod 700 /opt/much-to-do/deploy.sh

# -------------------------------------------------------------------------
# systemd unit. stdout and stderr go to a file so the CloudWatch agent can
# tail it.
# -------------------------------------------------------------------------
cat > /etc/systemd/system/much-to-do.service << 'UNITEOF'
[Unit]
Description=Much-to-Do API
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=muchtodo
WorkingDirectory=/opt/much-to-do
ExecStart=/opt/much-to-do/much-to-do
Restart=always
RestartSec=5
StandardOutput=append:/var/log/much-to-do/app.log
StandardError=append:/var/log/much-to-do/app.log

[Install]
WantedBy=multi-user.target
UNITEOF

# -------------------------------------------------------------------------
# CloudWatch agent
# -------------------------------------------------------------------------
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CWEOF'
{
  "agent": { "run_as_user": "root" },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/much-to-do/app.log",
            "log_group_name": "__LOG_GROUP__",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "__BOOTSTRAP_GROUP__",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CWEOF

sed -i "s|__LOG_GROUP__|${log_group}|g; s|__BOOTSTRAP_GROUP__|${bootstrap_group}|g" \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# -------------------------------------------------------------------------
# First build. Later deployments come from S3 via the pipeline instead.
# -------------------------------------------------------------------------
echo "Installing Go ${go_version}..."
curl -sSL "https://go.dev/dl/go${go_version}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/go.tar.gz

echo "Cloning application..."
rm -rf /tmp/app
git clone --depth 1 --branch "${repo_branch}" "${repo_url}" /tmp/app

echo "Building backend..."
cd /tmp/app/Server/MuchToDo
/usr/local/go/bin/go build -o /opt/much-to-do/much-to-do ./cmd/api/main.go
chown muchtodo:muchtodo /opt/much-to-do/much-to-do
chmod 755 /opt/much-to-do/much-to-do

echo "Writing configuration..."
/opt/much-to-do/refresh-config.sh

echo "Starting service..."
systemctl daemon-reload
systemctl enable --now much-to-do
sleep 5
systemctl is-active much-to-do

echo "=== Backend bootstrap finished ==="
EOF

echo ""
echo "Done. Files written:"
find . -name "*.tf" -o -name "*.tftpl" | sort
echo ""
echo "Next:  terraform init  ->  terraform plan  ->  terraform apply"
