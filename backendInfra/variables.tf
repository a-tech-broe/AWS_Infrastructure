variable "aws_region" {
  description = "AWS region for the state bucket and lock table."
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket that stores Terraform state."
  type        = string
  default     = "bokiti123"
}

variable "table_name" {
  description = "Name of the DynamoDB table for Terraform state locking."
  type        = string
  default     = "family_dyning"
}
