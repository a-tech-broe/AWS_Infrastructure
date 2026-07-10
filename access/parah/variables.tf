variable "aws_region" {
  description = "AWS region for the provider (IAM itself is global)."
  type        = string
  default     = "us-east-1"
}

variable "user_name" {
  description = "IAM user the access policy is attached to."
  type        = string
  default     = "Parah"
}

variable "policy_name" {
  description = "Name of the managed policy. Must match the ParahAccess ARN referenced inside combined-policy.json."
  type        = string
  default     = "ParahAccess"
}
