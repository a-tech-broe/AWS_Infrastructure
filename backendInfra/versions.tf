terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # This stack CREATES the remote-state backend, so it must use local state
  # itself (chicken-and-egg). Commit the resulting terraform.tfstate, or keep
  # it safe — it is small and only tracks the bucket + table.
}
