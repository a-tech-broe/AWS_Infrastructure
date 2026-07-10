terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }

  # Bootstrap state is small and one-time. Keep it locally, or point it at the
  # same S3 backend once that exists. It is created by an admin, not by CI.
}
