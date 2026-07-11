output "cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "execution_role_arn" {
  description = "ARN of the task execution role (image pull + logs)."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role (application identity)."
  value       = aws_iam_role.task.arn
}

output "task_security_group_id" {
  description = "ID of the base security group for Fargate tasks."
  value       = aws_security_group.tasks.id
}

output "exec_log_group_name" {
  description = "CloudWatch log group name for ECS Exec sessions."
  value       = aws_cloudwatch_log_group.exec.name
}

output "capacity_providers" {
  description = "Capacity providers enabled on the cluster."
  value       = aws_ecs_cluster_capacity_providers.this.capacity_providers
}
