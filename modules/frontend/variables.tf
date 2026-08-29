variable "project_name" {
  type        = string
  description = "Short name prefixed onto every resource."
}

variable "alb_dns_name" {
  type        = string
  description = "DNS name of the load balancer, used as the API origin."
}
