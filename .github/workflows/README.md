# CI/CD Workflows

Five GitHub Actions pipelines. **All auth is OIDC** — GitHub federates into AWS
IAM roles, so there are **no long-lived AWS keys** in the repo. Two roles:

| Secret | Used by | Privilege |
|--------|---------|-----------|
| `AWS_PLAN_ROLE_ARN` | plan, security-scan, drift | read-only (Describe/Get/List + state access) |
| `AWS_APPLY_ROLE_ARN` | apply | write (scoped to the resources Terraform manages) |

## Pipelines

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **terraform-plan.yml** | PR touching infra | `fmt` + `validate` + `plan` for dev/staging/prod (matrix), posts the plan as a PR comment, uploads the plan artifact. |
| **security-scan.yml** | PR + push to main | Checkov + tfsec + Trivy static analysis (SARIF → Security tab) **and** OPA/Conftest guardrails against each plan. Blocks merge on failure. |
| **terraform-apply.yml** | merge to main (dev) / manual dispatch (any env) | `apply` behind a protected **GitHub Environment** approval for staging/prod. |
| **drift-detection.yml** | weekday cron 06:00 UTC + manual | `plan -detailed-exitcode` against live state; opens/updates a `drift`-labelled issue when reality diverges from code. |
| **terraform-destroy.yml** | manual dispatch only | ⚠️ Tears down a whole environment. Requires typing `destroy <env>`, runs behind the environment approval, empties S3/ECR, and temporarily disables `prevent_destroy` (in the runner checkout only). Optionally destroys the state backend. |

## Destroying an environment

> **Destructive and irreversible.** Everything Terraform created for the chosen
> environment is deleted.

**Via CI:** Actions → *Terraform Destroy* → *Run workflow* →
- pick the `environment`,
- type the confirmation `destroy <environment>` (e.g. `destroy dev`),
- (optional) tick `destroy_bootstrap` **only** when every environment is already gone,
- approve the protected-environment gate.

**Locally** (needed for private prod/staging endpoints — run from a VPC-reachable host):

```bash
bash scripts/destroy.sh dev                 # destroy one environment
bash scripts/destroy.sh prod --with-bootstrap   # env, then the state backend
```

What the teardown handles that a bare `terraform destroy` cannot:
- **`prevent_destroy`** on the state bucket and security-log bucket — disabled in the working copy only (the local script reverts the edit on exit; CI never commits it).
- **Non-empty S3 buckets** — all object versions + delete markers are purged first.
- **Non-empty ECR repositories** — all images are deleted first.

Notes:
- **KMS keys** don't delete immediately — they enter a pending-deletion window (30 days) and can be cancelled during it.
- **Order matters:** destroy `dev`/`staging`/`prod` before `bootstrap`, because the environment state files live in the bootstrap S3 bucket.
- Some **account-level governance** singletons (GuardDuty, Security Hub, Config) live in `prod`; destroying `prod` removes them.

## One-time setup

1. **Create the two IAM roles** with a GitHub OIDC trust policy
   (`token.actions.githubusercontent.com`), scoped to this repo/branch.
2. Add repo secrets `AWS_PLAN_ROLE_ARN` and `AWS_APPLY_ROLE_ARN`.
3. Create GitHub **Environments** `dev`, `staging`, `prod`; add required
   reviewers to `staging` and `prod` for the approval gate.
4. (Private clusters) apply/plan for staging/prod need VPC network reachability —
   use a **self-hosted runner** in the VPC or a runner with VPN/VPC connectivity.

## Promotion flow

```
PR ──► plan + security-scan (gate) ──► merge ──► auto-apply dev
                                          └──► manual dispatch ──► approve ──► apply staging ──► approve ──► apply prod
```
