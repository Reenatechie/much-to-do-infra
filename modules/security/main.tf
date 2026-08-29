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
