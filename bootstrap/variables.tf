variable "aws_region" {
  description = "AWS region for the bootstrap resources (IAM is global, but the provider needs a region)."
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization or user that owns the repository."
  type        = string
  default     = "a-tech-broe"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "AWS_Infrastructure"
}

variable "role_name" {
  description = "Name of the IAM role GitHub Actions will assume."
  type        = string
  default     = "github-actions-terraform"
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set to false if one already exists in the account (only one per URL is allowed)."
  type        = bool
  default     = true
}

variable "allowed_subs" {
  description = "OIDC 'sub' claims allowed to assume the role. Leave empty to allow main branch pushes, pull requests, and the configured environments from this repo."
  type        = list(string)
  default     = []
}

variable "github_environments" {
  description = "GitHub Environments whose deploy jobs may assume the role. Jobs that set `environment:` get an environment-scoped OIDC sub (repo:ORG/REPO:environment:NAME)."
  type        = list(string)
  default     = ["dev", "stg", "prod"]
}

variable "state_bucket" {
  description = "S3 bucket used for Terraform remote state. Leave empty to skip granting state permissions."
  type        = string
  default     = ""
}

variable "lock_table" {
  description = "DynamoDB table used for Terraform state locking. Leave empty to skip granting lock permissions."
  type        = string
  default     = ""
}
