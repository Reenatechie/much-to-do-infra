variable "project_name" {
  type        = string
  description = "Short name prefixed onto every resource."
}

variable "aws_region" {
  type        = string
  description = "Region the pipeline operates in."
}

variable "github_owner" {
  type        = string
  description = "GitHub user or organisation."
}

variable "github_repo" {
  type        = string
  description = "Application repository name."
}

variable "frontend_bucket" {
  type        = string
  description = "Bucket the built React app is uploaded to."
}

variable "frontend_bucket_arn" {
  type        = string
  description = "ARN of the frontend bucket."
}

variable "artifacts_bucket" {
  type        = string
  description = "Bucket compiled backend binaries are uploaded to."
}

variable "distribution_id" {
  type        = string
  description = "CloudFront distribution to invalidate after a deploy."
}

variable "distribution_arn" {
  type        = string
  description = "ARN of the CloudFront distribution."
}

variable "target_group_arn" {
  type        = string
  description = "Target group the rolling deploy drains instances from."
}

variable "api_base_url" {
  type        = string
  description = "Value baked into the React build as VITE_API_BASE_URL."
}
