variable "project_name" {
  type        = string
  description = "Short name prefixed onto every resource."
}

variable "user_name" {
  type        = string
  description = "Login name for the assessor account."
  default     = "much-to-do-assessor"
}
