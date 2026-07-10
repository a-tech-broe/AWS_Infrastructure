output "bucket_name" {
  description = "Name of the state S3 bucket."
  value       = module.state_backend.bucket_name
}

output "table_name" {
  description = "Name of the state-lock DynamoDB table."
  value       = module.state_backend.table_name
}

output "backend_config" {
  description = "Snippet to paste into other stacks' backend \"s3\" block."
  value       = module.state_backend.backend_config
}
