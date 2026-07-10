# ---------------------------------------------------------------------------
# Source of truth for the Parah user's permissions.
#
# Edit ../../policies/combined-policy.json, then run `terraform apply` here to
# push a new version of the managed policy. Terraform creates a new policy
# version and prunes the oldest, so Parah's leverage updates on the fly.
# ---------------------------------------------------------------------------
resource "aws_iam_policy" "parah_access" {
  name        = var.policy_name
  description = "Permissions for the ${var.user_name} bootstrap user. Source of truth: policies/combined-policy.json."
  policy      = file("${path.module}/../../policies/combined-policy.json")
}

resource "aws_iam_user_policy_attachment" "parah_access" {
  user       = var.user_name
  policy_arn = aws_iam_policy.parah_access.arn
}
