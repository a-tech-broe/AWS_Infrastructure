module "vpc" {
  source = "../../modules/vpc"

  name     = "${var.project}-${var.environment}"
  vpc_cidr = var.vpc_cidr
  az_count = 2

  # 2 public + 2 private subnets are derived automatically from vpc_cidr:
  #   public : 10.0.0.0/24, 10.0.1.0/24
  #   private: 10.0.2.0/24, 10.0.3.0/24

  enable_nat_gateway = true
  single_nat_gateway = true # dev: one NAT to save cost. Set false in prod for HA.

  tags = {
    Environment = var.environment
  }
}
