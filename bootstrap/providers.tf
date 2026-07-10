provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "aws-infrastructure"
      Component = "ci-oidc"
      ManagedBy = "terraform"
    }
  }
}
