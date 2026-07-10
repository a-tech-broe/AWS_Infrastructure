provider "aws" {
  region = var.aws_region

  # No default_tags here: tagging the managed policy would require iam:TagPolicy,
  # which Parah's self-management grant intentionally omits. Keeping this policy
  # untagged lets Parah manage its own access without that extra permission.
}
