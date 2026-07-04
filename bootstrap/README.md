# Bootstrap — Terraform Remote State Backend

This stack creates the **S3 bucket** and **DynamoDB table** that every other
environment uses for remote Terraform state and state locking. It is the very
first thing you apply, and it runs with **local state** (chicken-and-egg: you
can't store the state backend's state in the backend it is creating).

## What it creates

| Resource | Purpose | Security controls |
|----------|---------|-------------------|
| `aws_s3_bucket.state` | Holds `*.tfstate` files | Versioning, KMS encryption, public access block, TLS-only bucket policy, `prevent_destroy` |
| `aws_kms_key.state` | Encrypts the state bucket | Key rotation enabled, 30-day deletion window |
| `aws_dynamodb_table.lock` | Prevents concurrent `apply` | SSE + point-in-time recovery |

## Usage

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # edit the bucket name to be globally unique
terraform init
terraform apply
```

Copy the `backend_config_hint` output into each `environments/<env>/backend.tf`
(the values are already pre-filled there as placeholders — just match them).

## Why local state here

The `terraform.tfstate` for *this* stack lives on your machine / CI runner. That
is acceptable because it only manages the backend itself. Keep the file safe
(it is git-ignored) — or, once created, you may optionally migrate it into the
bucket with a `backend.tf` pointing at a `bootstrap/` key.

## Destroy

The bucket is protected with `prevent_destroy = true`. To tear down you must
first remove that lifecycle block, empty the bucket (including all versions),
then `terraform destroy`. Do this only when decommissioning the whole account.
