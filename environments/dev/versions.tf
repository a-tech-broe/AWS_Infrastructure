terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Remote state in the bucket/table provisioned by backendInfra/.
  backend "s3" {
    bucket         = "bokiti123"
    key            = "aws-infrastructure/dev/vpc.tfstate"
    region         = "us-east-1"
    dynamodb_table = "family_dyning"
    encrypt        = true
  }
}
