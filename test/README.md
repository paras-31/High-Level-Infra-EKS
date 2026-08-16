# Infrastructure tests (Terratest)

Validates **existing** deployed infrastructure. Does **not** run `terraform apply` or `destroy`.

Live checks call the AWS API directly. If Terraform state has no `cluster_name` output (partial apply), the test falls back to `eks-{env}-eks`.

## What is tested

| Test | Requires AWS | What it checks |
|------|--------------|----------------|
| `TestTerraformValidateEnvironments` | No (init only) | `terraform validate` for dev/staging/prod |
| `TestLiveInfrastructureHealth` | Yes | Cluster ACTIVE, VPC endpoints (ecr.api, ecr.dkr, s3, sts, eks), node groups ACTIVE, core addons ACTIVE |

## Run locally

```bash
# Static validate (needs VPC module checkout — run scripts/fetch-vpc-module.sh first)
cd test && go test ./terratest/... -v -run TestTerraformValidateEnvironments

# Live checks against dev (SSO to account 765574565805)
export AWS_REGION=ap-south-1
export TEST_ENVIRONMENT=dev
cd test && go test ./terratest/... -v -timeout 30m -run TestLiveInfrastructureHealth
```

## CI

GitHub Actions → **Terratest Live Validation** → pick environment → Run workflow.

Uses read-only `AWS_PLAN_ROLE_ARN` — safe to run anytime.
