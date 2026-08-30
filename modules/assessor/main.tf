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
