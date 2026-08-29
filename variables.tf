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
