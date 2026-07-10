output "role_arn" {
  description = "ARN of the IAM role for GitHub Actions. Set this as the AWS_ROLE_ARN repository variable."
  value       = aws_iam_role.terraform.arn
}

output "role_name" {
  description = "Name of the IAM role for GitHub Actions."
  value       = aws_iam_role.terraform.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider."
  value       = local.oidc_provider_arn
}
