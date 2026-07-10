data "aws_caller_identity" "current" {}

locals {
  # Default trust: only the main branch and pull requests from this exact repo.
  default_subs = [
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_org}/${var.github_repo}:pull_request",
  ]
  allowed_subs = length(var.allowed_subs) > 0 ? var.allowed_subs : local.default_subs

  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ---------------------------------------------------------------------------
# GitHub OIDC identity provider
# ---------------------------------------------------------------------------
# Fetch GitHub's current certificate so the thumbprint stays correct even if
# GitHub rotates it, rather than hardcoding a fingerprint that can go stale.
data "tls_certificate" "github" {
  count = var.create_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [for cert in data.tls_certificate.github[0].certificates : cert.sha1_fingerprint]
}

# Look up an existing provider instead when create_oidc_provider = false.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# ---------------------------------------------------------------------------
# IAM role assumed by GitHub Actions via web identity federation
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    # Audience must be the AWS STS audience configured in the workflow.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restrict which repo/branch/event can assume the role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.allowed_subs
    }
  }
}

resource "aws_iam_role" "terraform" {
  name                 = var.role_name
  description          = "Assumed by GitHub Actions to run Terraform for ${var.github_org}/${var.github_repo}."
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  max_session_duration = 3600
}

# ---------------------------------------------------------------------------
# Permissions: least-privilege VPC/networking actions the CI role may perform.
# Kept inline (not in policies/) so the CI role's scope can't be widened by
# accident — policies/combined-policy.json is only for the human bootstrap user.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "vpc" {
  statement {
    sid    = "VpcNetworkingManagement"
    effect = "Allow"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes",
      "ec2:CreateVpc",
      "ec2:DeleteVpc",
      "ec2:DescribeVpcs",
      "ec2:ModifyVpcAttribute",
      "ec2:DescribeVpcAttribute",
      "ec2:CreateSubnet",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      "ec2:ModifySubnetAttribute",
      "ec2:CreateInternetGateway",
      "ec2:DeleteInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DescribeInternetGateways",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:DescribeRouteTables",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:AllocateAddress",
      "ec2:ReleaseAddress",
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "vpc" {
  name        = "${var.role_name}-vpc"
  description = "VPC/networking actions Terraform needs to manage the environments."
  policy      = data.aws_iam_policy_document.vpc.json
}

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.vpc.arn
}

# ---------------------------------------------------------------------------
# Optional: remote-state access, granted only when a bucket/table is provided
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "state" {
  count = var.state_bucket != "" ? 1 : 0

  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
  }

  statement {
    sid       = "StateObjectAccess"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/*"]
  }

  dynamic "statement" {
    for_each = var.lock_table != "" ? [1] : []
    content {
      sid       = "StateLockTable"
      effect    = "Allow"
      actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
      resources = ["arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.lock_table}"]
    }
  }
}

resource "aws_iam_policy" "state" {
  count       = var.state_bucket != "" ? 1 : 0
  name        = "${var.role_name}-state"
  description = "Access to the Terraform remote state bucket and lock table."
  policy      = data.aws_iam_policy_document.state[0].json
}

resource "aws_iam_role_policy_attachment" "state" {
  count      = var.state_bucket != "" ? 1 : 0
  role       = aws_iam_role.terraform.name
  policy_arn = aws_iam_policy.state[0].arn
}
