data "aws_caller_identity" "current" {}

##############################################################################
# Values the workflows look up at run time, so no infrastructure detail has
# to be copied into GitHub by hand.
##############################################################################
resource "aws_ssm_parameter" "frontend_bucket" {
  name  = "/${var.project_name}/cicd/frontend_bucket"
  type  = "String"
  value = var.frontend_bucket
}

resource "aws_ssm_parameter" "artifacts_bucket" {
  name  = "/${var.project_name}/cicd/artifacts_bucket"
  type  = "String"
  value = var.artifacts_bucket
}

resource "aws_ssm_parameter" "distribution_id" {
  name  = "/${var.project_name}/cicd/distribution_id"
  type  = "String"
  value = var.distribution_id
}

resource "aws_ssm_parameter" "target_group_arn" {
  name  = "/${var.project_name}/cicd/target_group_arn"
  type  = "String"
  value = var.target_group_arn
}

resource "aws_ssm_parameter" "api_base_url" {
  name  = "/${var.project_name}/cicd/api_base_url"
  type  = "String"
  value = var.api_base_url
}

##############################################################################
# Deployment permissions, defined once and attached to both the OIDC role
# and the deployment user.
##############################################################################
data "aws_iam_policy_document" "deploy" {
  statement {
    sid     = "ReadPipelineParameters"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/cicd/*"
    ]
  }

  statement {
    sid       = "PublishFrontend"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["${var.frontend_bucket_arn}/*"]
  }

  statement {
    sid       = "ListFrontendBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.frontend_bucket_arn]
  }

  statement {
    sid       = "PublishBackendArtifact"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${var.artifacts_bucket}/*"]
  }

  statement {
    sid       = "InvalidateCache"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
    resources = [var.distribution_arn]
  }

  statement {
    sid       = "DiscoverInstances"
    effect    = "Allow"
    actions   = ["ec2:DescribeInstances"]
    resources = ["*"]
  }

  statement {
    sid    = "RollingDeploy"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTargetGroups",
    ]
    resources = ["*"]
  }

  # Scoped by tag, so this identity cannot run commands on any other
  # instance in the account.
  statement {
    sid       = "RunDeployScript"
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/DeployGroup"
      values   = [var.project_name]
    }
  }

  statement {
    sid       = "UseShellDocument"
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript"]
  }

  statement {
    sid       = "ReadCommandResults"
    effect    = "Allow"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations", "ssm:ListCommands"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy" {
  name        = "${var.project_name}-deploy"
  description = "Least-privilege permissions for the deployment pipelines"
  policy      = data.aws_iam_policy_document.deploy.json
}

##############################################################################
# Deployment user. Its keys go into GitHub repository secrets - never into
# the repository itself.
##############################################################################
resource "aws_iam_user" "deployer" {
  name = "${var.project_name}-deployer"
  tags = {
    Purpose = "GitHub Actions deployment"
  }
}

resource "aws_iam_user_policy_attachment" "deployer" {
  user       = aws_iam_user.deployer.name
  policy_arn = aws_iam_policy.deploy.arn
}

resource "aws_iam_access_key" "deployer" {
  user = aws_iam_user.deployer.name
}

##############################################################################
# GitHub OpenID Connect. Retained as the preferred long-term approach.
##############################################################################
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  description        = "Assumed by GitHub Actions to deploy the application"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.deploy.arn
}
