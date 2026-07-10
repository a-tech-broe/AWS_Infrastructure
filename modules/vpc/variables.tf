variable "name" {
  description = "Name prefix applied to all resources and their Name tags."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to spread public/private subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2
    error_message = "az_count must be at least 2 for a highly available network."
  }
}

variable "public_subnet_cidrs" {
  description = "Explicit CIDRs for public subnets. Leave empty to auto-derive from vpc_cidr."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.public_subnet_cidrs) == 0 || length(var.public_subnet_cidrs) == var.az_count
    error_message = "public_subnet_cidrs must be empty or contain exactly az_count entries."
  }
}

variable "private_subnet_cidrs" {
  description = "Explicit CIDRs for private subnets. Leave empty to auto-derive from vpc_cidr."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.private_subnet_cidrs) == 0 || length(var.private_subnet_cidrs) == var.az_count
    error_message = "private_subnet_cidrs must be empty or contain exactly az_count entries."
  }
}

variable "enable_nat_gateway" {
  description = "Create NAT Gateway(s) so private subnets get outbound internet access."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one shared NAT Gateway instead of one per AZ. Cheaper, but a single point of failure."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags applied to every resource in the module."
  type        = map(string)
  default     = {}
}
