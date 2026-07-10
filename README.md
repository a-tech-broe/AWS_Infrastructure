# AWS Infrastructure

Terraform-managed AWS networking, deployed through a keyless GitHub Actions
pipeline. A reusable **VPC module** provisions a VPC with public and private
subnets across multiple Availability Zones; per-environment stacks (`dev`,
`stg`, `prod`) consume it. State lives in S3 with DynamoDB locking, and CI
authenticates to AWS via GitHub OIDC — no long-lived access keys.

- **Account:** `694992586025`
- **Region:** `us-east-1`
- **Repo:** `a-tech-broe/AWS_Infrastructure`

## Layout

```text
.
├── modules/
│   ├── vpc/                 # Reusable VPC (subnets, IGW, NAT, routing)
│   ├── backend-state/       # S3 + DynamoDB for Terraform remote state
│   └── s3/                  # (placeholder — not yet implemented)
├── environments/
│   ├── dev/                 # 10.0.0.0/16, single NAT
│   ├── stg/                 # 10.1.0.0/16, single NAT
│   └── prod/                # 10.2.0.0/16, one NAT per AZ (HA)
├── backendInfra/            # Creates the state bucket + lock table (run once)
├── bootstrap/               # GitHub OIDC provider + CI IAM role (admin, once)
├── access/parah/            # Manages the Parah user's permissions as code
├── policies/                # combined-policy.json — Parah's grant (source of truth)
├── .github/workflows/       # terraform.yml — scan/plan on PR, deploy on merge
└── .tflint.hcl              # TFLint config (AWS ruleset)
```

## Environments

All three use the same VPC module (2 public + 2 private subnets across 2 AZs)
with isolated CIDRs and remote-state keys.

| Env    | VPC CIDR      | NAT layout             | State key                             |
| ------ | ------------- | ---------------------- | ------------------------------------- |
| `dev`  | `10.0.0.0/16` | single (cost)          | `aws-infrastructure/dev/vpc.tfstate`  |
| `stg`  | `10.1.0.0/16` | single (cost)          | `aws-infrastructure/stg/vpc.tfstate`  |
| `prod` | `10.2.0.0/16` | one per AZ (HA egress) | `aws-infrastructure/prod/vpc.tfstate` |

Subnets are derived from the VPC CIDR: public `x.x.0.0/24` + `x.x.1.0/24`,
private `x.x.2.0/24` + `x.x.3.0/24`. AZs come from `aws_availability_zones`, so
each stack is region-portable.

## The VPC module

`modules/vpc` creates, per environment:

- VPC (DNS support + hostnames enabled)
- 2 public subnets (auto-assign public IP) + 2 private subnets
- Internet Gateway and a shared public route table
- NAT Gateway(s) + EIP(s) — one shared, or one per AZ (`single_nat_gateway`)
- Per-AZ private route tables routed through NAT

Key inputs: `name`, `vpc_cidr`, `az_count` (default 2), `enable_nat_gateway`,
`single_nat_gateway`, `tags`. Outputs: VPC ID, subnet IDs, NAT public IPs, AZs,
route table IDs.

## Remote state

`backendInfra/` (which uses `modules/backend-state`) provisions:

- **S3 bucket `bokiti123`** — versioned, SSE-S3 encrypted, public access blocked,
  TLS-only bucket policy, `prevent_destroy`
- **DynamoDB table `family_dyning`** — `LockID` hash key, pay-per-request

Each environment's `versions.tf` points its `backend "s3"` block at these.
`backendInfra/` itself uses local state (chicken-and-egg) and is applied once.

## CI/CD pipeline (`.github/workflows/terraform.yml`)

Keyless via GitHub OIDC. Triggers on PRs (scan/plan) and pushes to `main`
(deploy). Only environments with actual file changes run; a change to
`modules/**` or the workflow rebuilds all environments.

| Job      | When              | Does                                              |
| -------- | ----------------- | ------------------------------------------------- |
| `detect` | every run         | Diffs changed paths → dynamic env matrix          |
| `lint`   | every run         | `fmt` check, TFLint, Trivy IaC scan (HIGH/CRIT)   |
| `plan`   | PR + main         | `init` + `validate` + `plan` per changed env      |
| `deploy` | push to `main`    | `apply` per changed env, one at a time            |

`deploy` binds each job to a GitHub **Environment** (`dev`/`stg`/`prod`), so you
can require manual approval per environment under Settings → Environments.

## Identity & permissions

Two distinct identities, deliberately scoped:

- **`github-actions-terraform`** (IAM role, created by `bootstrap/`) — assumed by
  CI via OIDC. Trusts only this repo's `main` branch, pull requests, and the
  `dev`/`stg`/`prod` environments. Holds VPC + remote-state permissions only.
- **`Parah`** (IAM user) — the human/bootstrap operator. Its permissions are
  managed as code: `policies/combined-policy.json` is the **source of truth**,
  applied via `access/parah/` as the `ParahAccess` managed policy.

To grant `Parah` more, edit `policies/combined-policy.json` and:

```bash
cd access/parah && terraform apply
```

## Usage

### One-time setup (admin)

```bash
# 1. State backend
cd backendInfra && terraform init && terraform apply

# 2. OIDC provider + CI role (grant state access too)
cd ../bootstrap && terraform init && \
  terraform apply -var="state_bucket=bokiti123" -var="lock_table=family_dyning"

# 3. Publish the role ARN to GitHub (repo secret AWS_ROLE_ARN)
#    used by the workflow's configure-aws-credentials step
```

### Day-to-day

Open a PR → `lint` + `plan` run for the changed environments. Merge to `main` →
`deploy` applies them. To run an environment locally:

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

## Cost & teardown

NAT Gateways are the main cost (~$32/mo each + data). Fully deployed, the three
environments run **4 NAT Gateways** (dev 1, stg 1, prod 2) ≈ $130/mo. Tear an
environment down with:

```bash
cd environments/<env> && terraform destroy
```

## Notes

- Two Trivy findings are intentionally suppressed with justification:
  `AVD-AWS-0164` (public subnets must auto-assign public IPs) and `AVD-AWS-0132`
  (state bucket uses SSE-S3 rather than a KMS CMK).
- `AWS_ROLE_ARN` is stored as a repository **Secret** and read via
  `secrets.AWS_ROLE_ARN` in the workflow.
- `modules/s3` is an empty placeholder for future use.
