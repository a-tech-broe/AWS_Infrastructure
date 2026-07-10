provider "aws" {
  region = var.aws_region

  # Tags applied automatically to every resource that supports tagging.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
