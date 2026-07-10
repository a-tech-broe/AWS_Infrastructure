module "vpc" {
  source = "../../modules/vpc"

  name     = "${var.project}-${var.environment}"
  vpc_cidr = var.vpc_cidr
  az_count = 2

  # 2 public + 2 private subnets are derived automatically from vpc_cidr:
  #   public : 10.2.0.0/24, 10.2.1.0/24
  #   private: 10.2.2.0/24, 10.2.3.0/24

  enable_nat_gateway = true
  single_nat_gateway = false # prod: one NAT per AZ so egress survives an AZ outage

  tags = {
    Environment = var.environment
  }
}
