# CI/CD Workflows

Four GitHub Actions pipelines. **All auth is OIDC** — GitHub federates into AWS
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
