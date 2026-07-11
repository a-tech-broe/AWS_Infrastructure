# AWS Infrastructure

Terraform-managed AWS networking and compute, deployed through a keyless GitHub
Actions pipeline. Reusable **VPC** and **ECS** modules are consumed by
per-environment stacks (`dev`, `stg`, `prod`): each builds a VPC with public and
private subnets across multiple AZs plus a Fargate ECS cluster. State lives in S3
with DynamoDB locking, and CI authenticates to AWS via GitHub OIDC — no
long-lived access keys.

- **Account:** `694992586025`
- **Region:** `us-east-1`
- **Repo:** `a-tech-broe/AWS_Infrastructure`

## Layout

```text
.
├── modules/
│   ├── vpc/                 # Reusable VPC (subnets, IGW, NAT, routing)
│   ├── ecs/                 # Fargate ECS cluster (capacity providers, roles, SG)
│   ├── backend-state/       # S3 + DynamoDB for Terraform remote state
│   └── s3/                  # (placeholder — not yet implemented)
├── environments/
│   ├── dev/                 # 10.0.0.0/16, single NAT, Fargate+Spot
│   ├── stg/                 # 10.1.0.0/16, single NAT, Fargate+Spot
│   └── prod/                # 10.2.0.0/16, one NAT per AZ (HA), on-demand Fargate
├── backendInfra/            # Creates the state bucket + lock table (run once)
├── bootstrap/               # GitHub OIDC provider + CI IAM role (admin, once)
├── access/parah/            # Manages the Parah user's permissions as code
├── policies/                # combined-policy.json — Parah's grant (source of truth)
├── .github/
│   ├── workflows/           # terraform.yml — scan/plan on PR, deploy on merge
│   └── scripts/             # detect-changes.py — dependency-aware env selection
└── .tflint.hcl              # TFLint config (AWS ruleset)
```

## Environments

All three compose the same `vpc` + `ecs` modules (2 public + 2 private subnets
across 2 AZs, plus a Fargate cluster) with isolated CIDRs and remote-state keys.
The ECS cluster is fed directly from the in-stack VPC's outputs.

| Env    | VPC CIDR      | NAT layout             | Fargate         | State key                             |
| ------ | ------------- | ---------------------- | --------------- | ------------------------------------- |
| `dev`  | `10.0.0.0/16` | single (cost)          | on-demand + Spot | `aws-infrastructure/dev/vpc.tfstate`  |
| `stg`  | `10.1.0.0/16` | single (cost)          | on-demand + Spot | `aws-infrastructure/stg/vpc.tfstate`  |
| `prod` | `10.2.0.0/16` | one per AZ (HA egress) | on-demand only   | `aws-infrastructure/prod/vpc.tfstate` |

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

## The ECS module

`modules/ecs` creates a production-ready Fargate cluster, per environment:

- ECS cluster with **Container Insights**
- Capacity providers: `FARGATE` (baseline via `fargate_base`) + optional
  `FARGATE_SPOT`, with a weighted default strategy
- **ECS Exec** sessions logged to a CloudWatch log group (optional KMS)
- Task **execution** role (ECR pull + logs) and a separate **task** role
- A base security group for tasks in the existing VPC (egress-only)

Key inputs: `name`, `vpc_id`, `container_insights`, `enable_fargate_spot`,
`log_retention_days`, `kms_key_arn`, `tags`. Outputs: cluster ID/ARN/name,
execution/task role ARNs, task security group ID, exec log group name.

The clusters have no services yet — this is the cluster foundation. Empty
clusters are free; you pay only when tasks run.

## Remote state

`backendInfra/` (which uses `modules/backend-state`) provisions:

- **S3 bucket `bokiti123`** — versioned, SSE-S3 encrypted, public access blocked,
  TLS-only bucket policy, `prevent_destroy`
- **DynamoDB table `family_dyning`** — `LockID` hash key, pay-per-request

Each environment's `versions.tf` points its `backend "s3"` block at these.
`backendInfra/` itself uses local state (chicken-and-egg) and is applied once.

## CI/CD pipeline (`.github/workflows/terraform.yml`)

Keyless via GitHub OIDC. Triggers on PRs (scan/plan) and pushes to `main`
(deploy), and only runs the environments actually affected by a change.

| Job      | When              | Does                                              |
| -------- | ----------------- | ------------------------------------------------- |
| `detect` | every run         | `detect-changes.py` → dynamic env matrix          |
| `lint`   | every run         | `fmt` check, TFLint, Trivy IaC scan (HIGH/CRIT)   |
| `plan`   | PR + main         | `init` + `validate` + `plan` per selected env     |
| `deploy` | push to `main`    | `apply` per selected env, one at a time           |

**Dependency-aware selection** (`.github/scripts/detect-changes.py`): each
environment declares the local modules it uses (parsed transitively from
`source =` blocks). An environment is selected when its own dir or any module it
depends on changed. So `modules/vpc` or `modules/ecs` changes select every env
(all consume them), a `modules/backend-state` change selects **none** (no env
uses it), and `environments/dev/**` selects just `dev`. The workflow or detect
script changing selects all.

`deploy` binds each job to a GitHub **Environment** (`dev`/`stg`/`prod`), so you
can require manual approval per environment under Settings → Environments.

## Identity & permissions

Two distinct identities, deliberately scoped:

- **`github-actions-terraform`** (IAM role, created by `bootstrap/`) — assumed by
  CI via OIDC. Trusts only this repo's `main` branch, pull requests, and the
  `dev`/`stg`/`prod` environments. Holds VPC, ECS, CloudWatch Logs and
  remote-state permissions (task-role management scoped to `aws-infrastructure-*`).
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

NAT Gateways are essentially the entire fixed cost (~$32/mo each + data, plus
~$3.65/mo per EIP). Fully deployed, the three environments run **4 NAT Gateways**
(dev 1, stg 1, prod 2) ≈ **$146/mo**.

The **ECS clusters add $0 at rest** — empty clusters, capacity providers, log
groups and IAM roles are free. Fargate bills only when tasks run
(~$0.04/vCPU-hr + $0.0044/GB-hr on-demand; Spot ~70% less), plus a small
Container Insights metrics charge while tasks are running.

Tear an environment down with:

```bash
cd environments/<env> && terraform destroy
```

## Notes

- Three Trivy findings are intentionally suppressed with justification:
  `AVD-AWS-0164` (public subnets must auto-assign public IPs), `AVD-AWS-0132`
  (state bucket uses SSE-S3 rather than a KMS CMK), and `AVD-AWS-0104` (ECS task
  security group needs open egress to reach ECR/CloudWatch/dependencies).
- `AWS_ROLE_ARN` is stored as a repository **Secret** and read via
  `secrets.AWS_ROLE_ARN` in the workflow.
- `modules/s3` is an empty placeholder for future use.
