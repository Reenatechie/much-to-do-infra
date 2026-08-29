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
