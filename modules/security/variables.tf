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
