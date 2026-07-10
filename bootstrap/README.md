# Bootstrap — GitHub Actions OIDC

One-time setup that lets GitHub Actions run Terraform against AWS using
**short-lived, keyless credentials** (OpenID Connect) instead of a static IAM
user with long-lived access keys.

It creates:

- The GitHub OIDC identity provider in IAM (`token.actions.githubusercontent.com`)
- An IAM role (`github-actions-terraform`) that only the `a-tech-broe/AWS_Infrastructure`
  repo can assume, scoped to the `main` branch and pull requests
- The least-privilege VPC policy (from `../policies/vpc-terraform-policy.json`)
  attached to that role
- Optionally, S3 + DynamoDB permissions for remote state

## Apply (run once, by an account admin)

This is the chicken-and-egg step: creating an OIDC provider and IAM role
requires IAM admin, so it is applied by a human admin — not by CI.

```bash
cd bootstrap
terraform init
terraform apply

# note the output
terraform output role_arn
```

If the account **already has** a GitHub OIDC provider, don't create a second
one (AWS allows only one per URL):

```bash
terraform apply -var="create_oidc_provider=false"
```

To also grant remote-state access, pass your bucket/table:

```bash
terraform apply \
  -var="state_bucket=my-org-terraform-state" \
  -var="lock_table=terraform-locks"
```

## Wire it into GitHub

Set the role ARN as a **repository variable** (Settings → Secrets and variables
→ Actions → Variables), which the workflow reads as `${{ vars.AWS_ROLE_ARN }}`:

```bash
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw role_arn)"
```

After that, `.github/workflows/terraform.yml` will:

- run `plan` on every pull request
- run `apply` on every push to `main`

with no AWS keys stored in GitHub.

## Tightening trust

The default trust allows the `main` branch and any pull request. To restrict
further (e.g. GitHub Environments), override `allowed_subs`:

```bash
terraform apply -var='allowed_subs=["repo:a-tech-broe/AWS_Infrastructure:environment:production"]'
```
