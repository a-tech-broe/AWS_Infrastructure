variable "bucket_name" {
  description = "Globally-unique name of the S3 bucket that stores Terraform state."
  type        = string
}

variable "table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  type        = string
}

variable "force_destroy" {
  description = "Allow deleting the state bucket even if it still holds state versions. Keep false in real use."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to the bucket and table."
  type        = map(string)
  default     = {}
}
