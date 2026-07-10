output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "availability_zones" {
  description = "Availability Zones the subnets are spread across."
  value       = local.azs
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways (empty if disabled)."
  value       = aws_nat_gateway.this[*].id
}

output "nat_public_ips" {
  description = "Public Elastic IPs assigned to the NAT Gateways."
  value       = aws_eip.nat[*].public_ip
}

output "public_route_table_id" {
  description = "ID of the shared public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs of the per-AZ private route tables."
  value       = aws_route_table.private[*].id
}
