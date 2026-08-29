terraform {
  backend "s3" {
    bucket         = "much-to-do-tfstate-reena2026"
    key            = "much-to-do/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "much-to-do-tflock"
    encrypt        = true
  }
}
