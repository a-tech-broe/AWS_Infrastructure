terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Manages the Parah user's own permissions, so it uses local state to avoid a
  # circular dependency on the very access it grants. Keep this state safe.
}
