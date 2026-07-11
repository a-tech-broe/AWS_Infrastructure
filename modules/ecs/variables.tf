variable "name" {
  description = "Name of the ECS cluster and prefix for its supporting resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the task security group is created in (from the vpc module)."
  type        = string
}

variable "container_insights" {
  description = "Enable CloudWatch Container Insights on the cluster."
  type        = bool
  default     = true
}

variable "enable_fargate_spot" {
  description = "Add FARGATE_SPOT as a capacity provider. Leave off in prod for interruption-free tasks."
  type        = bool
  default     = true
}

variable "fargate_base" {
  description = "Minimum number of tasks always placed on on-demand FARGATE before the weighted split applies."
  type        = number
  default     = 1
}

variable "fargate_weight" {
  description = "Relative weight of on-demand FARGATE in the default capacity provider strategy."
  type        = number
  default     = 1
}

variable "fargate_spot_weight" {
  description = "Relative weight of FARGATE_SPOT in the default capacity provider strategy."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "Retention for the ECS Exec / cluster CloudWatch log group."
  type        = number
  default     = 30
}

variable "kms_key_arn" {
  description = "Optional KMS key ARN to encrypt ECS Exec logs. Null uses default CloudWatch encryption."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
