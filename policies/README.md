# Policy-as-Code

Two complementary layers of automated governance that run in CI (and locally):

## 1. Checkov — static security scanning (`.checkov.yaml`)

Scans the Terraform source for hundreds of built-in misconfiguration checks
(encryption, logging, public exposure, IAM). Config lives in `.checkov.yaml`:
every skip is documented with a reason, and the EKS/IMDSv2/EBS checks are marked
`hard-fail`.

```bash
pip install checkov
checkov -d . --config-file policies/.checkov.yaml
```

## 2. OPA / Conftest — org guardrails on the plan (`opa/eks_guardrails.rego`)

Checkov covers "is this generally insecure?". Conftest encodes **our** rules —
what a linter can't know — by evaluating the actual Terraform *plan*:

| Rule | Enforces |
|------|----------|
| Public endpoint | Only `dev` may enable a public EKS API endpoint |
| Secrets encryption | Every cluster has `encryption_config` |
| Control-plane logs | All 5 log types enabled |
| IMDSv2 | Launch templates set `http_tokens = required` |
| No wildcard IAM | No `Action:* on Resource:*` inline/managed policy |
| Immutable ECR | Repositories are `IMMUTABLE` |
| S3 public block | `block_public_acls = true` |

```bash
# from an environment directory:
terraform plan -out=tfplan
terraform show -json tfplan > plan.json
conftest test plan.json --policy ../../policies/opa
```

Both run automatically in `.github/workflows/security-scan.yml` and gate every PR.

## Adding a rule

- **Generic security check** → prefer enabling/adjusting a Checkov check.
- **Company/EKS-specific policy** → add a `deny` block to `eks_guardrails.rego`.
