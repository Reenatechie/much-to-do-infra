variable "project_name" {
  description = "Short name prefixed onto every resource."
  type        = string
}

variable "vpc_cidr" {
  description = "IP address range for the whole VPC."
  type        = string
}

variable "availability_zones" {
  description = "AZs to spread subnets across."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Ranges for the public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Ranges for the private subnets."
  type        = list(string)
}
