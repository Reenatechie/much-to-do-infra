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
