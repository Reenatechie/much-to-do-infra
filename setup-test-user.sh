#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# much-to-do-infra : read-only test user for the assessor
#
# Deliverable 5: "AWS Console and CLI credentials for a test user ... this
# user MUST have the permission to see all the resources created."
#
# Run from INSIDE your much-to-do-infra folder:
#     bash setup-test-user.sh
# ---------------------------------------------------------------------------
set -euo pipefail

if [ ! -f "main.tf" ]; then
  echo "ERROR: main.tf not found. Are you in much-to-do-infra?"
  exit 1
fi

mkdir -p modules/assessor

cat > modules/assessor/variables.tf << 'EOF'
variable "project_name" {
  type        = string
  description = "Short name prefixed onto every resource."
}

variable "user_name" {
  type        = string
  description = "Login name for the assessor account."
  default     = "much-to-do-assessor"
}
EOF

cat > modules/assessor/main.tf << 'EOF'
data "aws_caller_identity" "current" {}

##############################################################################
# A read-only account for whoever is marking this project.
#
# ReadOnlyAccess covers every service used here - VPC, EC2, ELB, S3,
# CloudFront, ElastiCache, CloudWatch Logs, IAM and Systems Manager - while
# making it impossible to change or delete anything.
##############################################################################
resource "aws_iam_user" "assessor" {
  name          = var.user_name
  force_destroy = true

  tags = {
    Purpose = "Read-only assessment access"
  }
}

resource "aws_iam_user_policy_attachment" "read_only" {
  user       = aws_iam_user.assessor.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Console access. password_reset_required is false so the assessor can sign
# in and look around without being forced through a password change.
resource "aws_iam_user_login_profile" "assessor" {
  user                    = aws_iam_user.assessor.name
  password_length         = 20
  password_reset_required = false

  lifecycle {
    ignore_changes = [password_length, password_reset_required]
  }
}

# CLI access
resource "aws_iam_access_key" "assessor" {
  user = aws_iam_user.assessor.name
}
EOF

cat > modules/assessor/outputs.tf << 'EOF'
output "user_name" {
  description = "Console sign-in username."
  value       = aws_iam_user.assessor.name
}

output "console_url" {
  description = "Account sign-in page."
  value       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
}

output "console_password" {
  description = "Console sign-in password."
  value       = aws_iam_user_login_profile.assessor.password
  sensitive   = true
}

output "access_key_id" {
  description = "CLI access key ID."
  value       = aws_iam_access_key.assessor.id
}

output "secret_access_key" {
  description = "CLI secret access key."
  value       = aws_iam_access_key.assessor.secret
  sensitive   = true
}
EOF

if ! grep -q 'module "assessor"' main.tf; then
cat >> main.tf << 'EOF'

##############################################################################
# Assessor : a read-only account so the project can be reviewed without
# handing over personal credentials.
##############################################################################
module "assessor" {
  source = "./modules/assessor"

  project_name = var.project_name
}
EOF
fi

if ! grep -q "assessor_console_url" outputs.tf; then
cat >> outputs.tf << 'EOF'

##############################################################################
# Assessor credentials - submit these, not your own.
##############################################################################

output "assessor_user_name" {
  description = "Console sign-in username for the assessor."
  value       = module.assessor.user_name
}

output "assessor_console_url" {
  description = "Console sign-in page for the assessor."
  value       = module.assessor.console_url
}

output "assessor_console_password" {
  description = "Console password. Retrieve with: terraform output -raw assessor_console_password"
  value       = module.assessor.console_password
  sensitive   = true
}

output "assessor_access_key_id" {
  description = "CLI access key ID for the assessor."
  value       = module.assessor.access_key_id
}

output "assessor_secret_access_key" {
  description = "CLI secret key. Retrieve with: terraform output -raw assessor_secret_access_key"
  value       = module.assessor.secret_access_key
  sensitive   = true
}
EOF
fi

echo ""
echo "Done."
echo "Next:  terraform apply"
