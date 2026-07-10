# access/parah — Parah's permissions as code

`../../policies/combined-policy.json` is the **single source of truth** for what
the `Parah` IAM user can do. This stack turns that file into a managed policy
(`ParahAccess`) and attaches it to the user.

## Grant Parah more (the on-the-fly loop)

1. Edit `policies/combined-policy.json` — add actions/resources to an existing
   statement, or add a new statement.
2. Apply:
   ```bash
   cd access/parah
   terraform apply
   ```
   Terraform pushes a new version of the `ParahAccess` policy. The change is
   live immediately; no console clicks.

Keep the JSON valid (`terraform validate` will catch syntax errors) and under
the 6144-character managed-policy limit (currently ~2.8k).

## First-time setup (one admin action)

The initial `terraform apply` creates the policy and attaches it to `Parah`,
which requires `iam:CreatePolicy` + `iam:AttachUserPolicy` — permissions `Parah`
doesn't have yet. So an **admin runs the first apply once**:

```bash
AWS_PROFILE=<admin> terraform apply
```

The policy JSON already includes `SelfManageAccessPolicy` and
`SelfAttachAccessPolicy`, so **after** that first apply `Parah` can run every
future apply itself.

Then remove any older hand-attached inline policies from `Parah` (e.g.
`ParahBootstrapIAM`, `ParahBackendState`) so this stack is the only source of
truth and state doesn't drift.

## ⚠️ Security note

`SelfManageAccessPolicy` + `SelfAttachAccessPolicy` let `Parah` edit its own
permissions — effectively self-escalation to anything in the account. That is
the "edit on the fly" capability you asked for. In a hardened setup you'd keep
this policy admin-managed instead and drop those two statements.
