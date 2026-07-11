#!/usr/bin/env bash
#
# Complete teardown of every AWS resource this repo creates, in dependency order.
#
# Order matters:
#   1. Environments (dev/stg/prod)  — the actual infra; needs the state bucket + Parah perms
#   2. Bootstrap                    — OIDC provider + CI role + policies
#   3. ECS service-linked role      — account-global, best effort
#   4. State backend                — S3 bucket (bypasses prevent_destroy) + DynamoDB table
#   5. Parah access (LAST)          — removes Parah's own permissions
#
# Run as an identity that can do all of the above (Parah, or an admin). Set the
# profile with AWS_PROFILE (defaults to "default").
#
# Usage:
#   AWS_PROFILE=default ./scripts/destroy-all.sh            # interactive confirm
#   AWS_PROFILE=default ./scripts/destroy-all.sh --yes      # skip the prompt
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

: "${AWS_PROFILE:=default}"
export AWS_PROFILE
REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET="bokiti123"
LOCK_TABLE="family_dyning"
ENVIRONMENTS=(dev stg prod)

log()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn] %s\033[0m\n' "$*"; }

# --- Safety confirmation -----------------------------------------------------
if [[ "${1:-}" != "--yes" ]]; then
  cat <<EOF
This will PERMANENTLY DESTROY all resources created by this repo in account:
  $(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo '<unknown>')  (profile: ${AWS_PROFILE}, region: ${REGION})

  - VPCs, subnets, NAT gateways, EIPs, route tables (dev/stg/prod)
  - ECS clusters, log groups, task roles, security groups
  - GitHub OIDC provider + github-actions-terraform role & policies
  - Terraform state bucket (${STATE_BUCKET}) and lock table (${LOCK_TABLE})
  - The ParahAccess policy (Parah loses its permissions)

EOF
  read -r -p 'Type "destroy-everything" to proceed: ' reply
  [[ "$reply" == "destroy-everything" ]] || { echo "Aborted."; exit 1; }
fi

# --- 1. Environments ---------------------------------------------------------
# Must run before the state bucket is deleted (they read remote state).
for env in "${ENVIRONMENTS[@]}"; do
  if [[ -f "environments/${env}/main.tf" ]]; then
    log "Destroying environment: ${env}"
    terraform -chdir="environments/${env}" init -input=false >/dev/null
    terraform -chdir="environments/${env}" destroy -auto-approve -input=false
  fi
done

# --- 2. Bootstrap (OIDC provider + CI role) ---------------------------------
log "Destroying bootstrap (OIDC provider + CI role)"
terraform -chdir=bootstrap init -input=false >/dev/null
terraform -chdir=bootstrap destroy -auto-approve -input=false \
  -var="state_bucket=${STATE_BUCKET}" -var="lock_table=${LOCK_TABLE}"

# --- 3. ECS service-linked role (best effort) -------------------------------
log "Deleting ECS service-linked role (best effort)"
aws iam delete-service-linked-role --role-name AWSServiceRoleForECS >/dev/null 2>&1 \
  && echo "deletion requested" \
  || warn "could not delete AWSServiceRoleForECS (may need admin, or may be in use) — safe to leave; it is free."

# --- 4. State backend --------------------------------------------------------
# The bucket has prevent_destroy and holds versioned state, so terraform destroy
# would fail. Empty every version + delete marker, then delete via the API.
delete_batch() {
  # Delete one class of objects (Versions or DeleteMarkers) from the bucket.
  local bucket="$1" jmes="$2" payload count
  payload="$(aws s3api list-object-versions --bucket "$bucket" \
    --query "{Objects: ${jmes}[].{Key:Key,VersionId:VersionId}}" --output json)"
  count="$(echo "$payload" | python3 -c 'import json,sys;print(len(json.load(sys.stdin).get("Objects") or []))')"
  if [[ "$count" -gt 0 ]]; then
    aws s3api delete-objects --bucket "$bucket" --delete "$payload" >/dev/null
    echo "deleted ${count} ${jmes}"
  fi
}

if aws s3api head-bucket --bucket "$STATE_BUCKET" >/dev/null 2>&1; then
  log "Emptying and deleting state bucket: ${STATE_BUCKET}"
  delete_batch "$STATE_BUCKET" Versions
  delete_batch "$STATE_BUCKET" DeleteMarkers
  aws s3api delete-bucket --bucket "$STATE_BUCKET" --region "$REGION"
  echo "bucket deleted"
else
  warn "state bucket ${STATE_BUCKET} not found — skipping"
fi

log "Deleting lock table: ${LOCK_TABLE}"
aws dynamodb delete-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null 2>&1 \
  && echo "table deletion requested" \
  || warn "lock table ${LOCK_TABLE} not found — skipping"

# backendInfra tracked the now-deleted bucket/table in local state; clear it.
rm -f backendInfra/terraform.tfstate backendInfra/terraform.tfstate.backup 2>/dev/null || true

# --- 5. Parah access (LAST — removes Parah's own permissions) ----------------
log "Destroying Parah access (ParahAccess policy)"
terraform -chdir=access/parah init -input=false >/dev/null
terraform -chdir=access/parah destroy -auto-approve -input=false || \
  warn "access/parah destroy failed — Parah may have already lost the permissions needed. Detach/delete ParahAccess in the console if it remains."

log "Teardown complete."
cat <<'EOF'

Left for a human/admin (created out of band, not managed by this repo):
  - Any inline/managed policies attached to Parah by hand (e.g. ParahAccessManual,
    ParahBootstrapIAM) — remove them in IAM -> Users -> Parah.
  - The AWSServiceRoleForECS service-linked role if deletion above was skipped
    (harmless and free to leave).
  - The AWS_ROLE_ARN GitHub repository secret.
EOF
