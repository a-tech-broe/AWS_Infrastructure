output "policy_arn" {
  description = "ARN of the managed access policy."
  value       = aws_iam_policy.parah_access.arn
}

output "policy_id" {
  description = "Stable ID of the managed access policy."
  value       = aws_iam_policy.parah_access.policy_id
}

output "attached_user" {
  description = "IAM user the policy is attached to."
  value       = var.user_name
}
