output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the two public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the two private subnets."
  value       = module.vpc.private_subnet_ids
}

output "nat_public_ips" {
  description = "Public IPs of the NAT Gateway(s)."
  value       = module.vpc.nat_public_ips
}

output "availability_zones" {
  description = "AZs the subnets span."
  value       = module.vpc.availability_zones
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = module.ecs.cluster_arn
}

output "ecs_task_security_group_id" {
  description = "Base security group for Fargate tasks."
  value       = module.ecs.task_security_group_id
}
