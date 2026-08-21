# Terratest (EKS platform)

Pattern Catalog–style tests for the EKS platform. Structure mirrors
[terraform-aws-secretsmanager/tests](https://github.com/McK-Internal/terraform-aws-secretsmanager/tree/main/tests).

## Layout

```
tests/
  module_test.go   # TestTerraform — main CI entry point
  live.go          # Live AWS health assertions (read-only)
  helpers.go       # Shared helpers
  helpers_test.go  # Unit tests
```

## Difference from module examples

The secretsmanager module runs **apply → assert → destroy** in one test (~minutes).

EKS platform apply takes **30–45 minutes** and is managed by **terraform-apply.yml**.
Terratest here does:

1. **Static validate** — `terraform init -backend=false` + `validate`
2. **Live checks** (optional) — read-only AWS API validation of deployed cluster

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `TEST_ENVIRONMENT` | — | **Required.** `dev`, `staging`, or `prod` |
| `TERRATEST_SKIP_LIVE` | `false` | `true` = validate only (used on PR/push) |
| `AWS_REGION` | `ap-south-1` | AWS region |
| `TEST_AWS_ACCOUNT_ID` | `174765206872` | Fail fast on wrong account |

## Run locally

```bash
# Static validate all environments (no AWS)
cd tests && go test ./... -v -run TestTerraformAllEnvironments

# Validate + live checks for dev (SSO to 174765206872, cluster must exist)
export AWS_REGION=ap-south-1
export TEST_ENVIRONMENT=dev
cd tests && go test ./... -v -timeout 30m -run TestTerraform

# Validate only (no AWS)
export TEST_ENVIRONMENT=dev
export TERRATEST_SKIP_LIVE=true
cd tests && go test ./... -v -run TestTerraform
```

## CI

**GitHub Actions → Terratest** runs a matrix over environments:

- **PR / push to main** — validate dev, staging, prod (parallel, no live checks)
- **Manual dispatch** — validate + live checks for the selected environment

Uses read-only `AWS_PLAN_ROLE_ARN` for live checks.

## Extend tests

Add assertions in `live.go` inside `assertLiveInfrastructure`, or add Terraform
output checks after apply:

```go
output := terraform.Output(t, opts, "cluster_name")
require.Equal(t, expectedClusterName(env), output)
```
