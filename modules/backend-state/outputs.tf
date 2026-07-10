output "bucket_name" {
  description = "Name of the state S3 bucket."
  value       = aws_s3_bucket.state.id
}

output "bucket_arn" {
  description = "ARN of the state S3 bucket."
  value       = aws_s3_bucket.state.arn
}

output "table_name" {
  description = "Name of the state-lock DynamoDB table."
  value       = aws_dynamodb_table.locks.name
}

output "table_arn" {
  description = "ARN of the state-lock DynamoDB table."
  value       = aws_dynamodb_table.locks.arn
}

output "backend_config" {
  description = "Copy this into a `backend \"s3\"` block in the stacks that should use remote state."
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.state.id}"
      key            = "<stack>/terraform.tfstate"
      region         = "${data.aws_region.current.region}"
      dynamodb_table = "${aws_dynamodb_table.locks.name}"
      encrypt        = true
    }
  EOT
}

data "aws_region" "current" {}
