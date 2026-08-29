provider "aws" {
  region = var.aws_region

  # Every resource we create gets these tags automatically.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Owner     = var.owner
    }
  }
}
