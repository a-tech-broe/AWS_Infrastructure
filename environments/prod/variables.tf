variable "aws_region" {
  description = "AWS region to deploy the VPC into."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used for tagging and resource naming."
  type        = string
  default     = "aws-infrastructure"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.2.0.0/16"
}
