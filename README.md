# AWS Infrastructure

Terraform-managed AWS networking. The core building block is a reusable **VPC
module** that provisions a VPC with public and private subnets across multiple
Availability Zones, plus the routing needed for internet and NAT egress.

## Layout

```
.
├── modules/
│   └── vpc/                 # Reusable VPC module
│       ├── main.tf          # VPC, subnets, IGW, NAT, route tables
│       ├── variables.tf     # Inputs (with validation)
│       ├── outputs.tf       # IDs/CIDRs consumed by other stacks
│       └── versions.tf      # Provider/version constraints
└── environments/
    └── dev/                 # Dev stack that consumes the module
        ├── main.tf          # module "vpc" { ... }
        ├── providers.tf     # AWS provider + default tags
        ├── variables.tf
        ├── outputs.tf
        ├── versions.tf      # Includes a commented S3 backend
        └── terraform.tfvars.example
```

## What gets created (dev)

For `vpc_cidr = 10.0.0.0/16` and `az_count = 2`:

| Resource            | Count | Notes                                        |
| ------------------- | ----- | -------------------------------------------- |
| VPC                 | 1     | DNS support + hostnames enabled              |
| Public subnets      | 2     | `10.0.0.0/24`, `10.0.1.0/24`, auto-assign IP |
| Private subnets     | 2     | `10.0.2.0/24`, `10.0.3.0/24`                 |
| Internet Gateway    | 1     | Default route for public subnets             |
| NAT Gateway + EIP   | 1     | Outbound egress for private subnets          |
| Public route table  | 1     | Shared by both public subnets                |
| Private route tables | 2    | One per AZ, routed via NAT                    |

Subnets are spread across the first two AZs returned by
`aws_availability_zones`, so the stack is region-portable.

## Usage

```bash
cd environments/dev

# Optional: create your own tfvars from the example (gitignored)
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan
terraform apply
```

Requires AWS credentials in the environment (`AWS_PROFILE`, env vars, or an
assumed role) and Terraform >= 1.5.

## Module inputs (highlights)

| Variable             | Default        | Description                                       |
| -------------------- | -------------- | ------------------------------------------------- |
| `name`               | —              | Name prefix for all resources                     |
| `vpc_cidr`           | `10.0.0.0/16`  | VPC CIDR block                                    |
| `az_count`           | `2`            | Number of AZs to span                             |
| `enable_nat_gateway` | `true`         | Provision NAT for private egress                  |
| `single_nat_gateway` | `true`         | One shared NAT (cheap) vs one per AZ (HA)         |

For production, set `single_nat_gateway = false` so each AZ egresses through
its own NAT Gateway and the network survives a single-AZ failure.

## Remote state

`versions.tf` in each environment ships with a commented-out S3 backend.
Provision an encrypted S3 bucket + DynamoDB lock table once, uncomment the
block, and re-run `terraform init` to migrate state off local disk.
