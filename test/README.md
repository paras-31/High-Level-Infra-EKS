# Infrastructure tests (Terratest)

Validates **existing** deployed infrastructure. Does **not** run `terraform apply` or `destroy`.

Live checks call the AWS API directly using cluster name `eks-{env}-eks` (no Terraform state/output required).

## What is tested

| Test | Requires AWS | What it checks |
|------|--------------|----------------|
| `TestIsClusterNameOutput` | No | Rejects terraform warning text mistaken as cluster name |
| `TestTerraformValidateEnvironments` | No (init only) | `terraform validate` for dev/staging/prod |
| `TestLiveInfrastructureHealth` | Yes | Cluster ACTIVE, VPC endpoints (ecr.api, ecr.dkr, s3, sts, eks), node groups ACTIVE, core addons ACTIVE |

## Run locally
```bash
# Unit test (no AWS)
cd test && go test ./terratest/... -v -run TestIsClusterNameOutput

# Static validate (needs VPC module checkout — run scripts/fetch-vpc-module.sh first)
cd test && go test ./terratest/... -v -run TestTerraformValidateEnvironments

# Live checks against dev — must be account 765574565805 with eks-dev-eks deployed
aws sts get-caller-identity                    # Account must be 765574565805
aws eks list-clusters --region ap-south-1      # must include eks-dev-eks

export AWS_REGION=ap-south-1
export TEST_ENVIRONMENT=dev
cd test && go test ./terratest/... -v -timeout 30m -run TestLiveInfrastructureHealth
```

## CI

GitHub Actions → **Terratest Live Validation** → pick environment → Run workflow.

Uses read-only `AWS_PLAN_ROLE_ARN` — safe to run anytime.
