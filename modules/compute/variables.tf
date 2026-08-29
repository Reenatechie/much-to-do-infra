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
