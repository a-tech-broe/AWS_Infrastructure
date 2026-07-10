locals {
  tags = merge(var.tags, {
    Purpose   = "terraform-state"
    ManagedBy = "terraform"
  })
}

# ---------------------------------------------------------------------------
# S3 bucket that stores the state files
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(local.tags, { Name = var.bucket_name })

  # State is the source of truth for all managed infrastructure. Guard against
  # an accidental `terraform destroy` wiping it out.
  lifecycle {
    prevent_destroy = true
  }
}

# Keep a history of every state write so a bad apply can be rolled back.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (it can contain secrets in plaintext).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# State must never be public.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Reject any request that isn't over TLS.
data "aws_iam_policy_document" "state" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json

  # The policy references the public access block; apply it after so the two
  # don't race on create.
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ---------------------------------------------------------------------------
# DynamoDB table used for state locking
# ---------------------------------------------------------------------------
resource "aws_dynamodb_table" "locks" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST" # no capacity to manage; you pay per lock op
  hash_key     = "LockID"

  # Terraform's S3 backend uses a fixed attribute named "LockID".
  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.tags, { Name = var.table_name })
}
