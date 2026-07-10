provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-infrastructure"
      Component = "tf-state-backend"
      ManagedBy = "terraform"
    }
  }
}
