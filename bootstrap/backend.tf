###############################################################################
# S3 backend for bootstrap's own state.
#
# Design: two-tier state backend
#
#   Tier 0 — SEED bucket (created MANUALLY, once per account, via CLI):
#     tf-bootstrap-state-<account>-<region>
#     Holds ONLY bootstrap/terraform.tfstate.
#     Locking is done natively by S3 (use_lockfile=true, Terraform >= 1.10).
#     No DynamoDB, no KMS — kept intentionally minimal so it can be created
#     with three CLI commands on a brand-new account.
#
#   Tier 1 — ENV bucket (created BY THIS module, applied via CI):
#     tf-state-<account>-<region>
#     terraform-state-lock  (DynamoDB)
    # alias/tf-state-<account>-<region>  (KMS)
#     Holds every environment's state file (dev/staging/prod/...).
#     Used by terraform-plan.yml and terraform-apply.yml.
#
# Once the seed bucket exists, bootstrap can be run entirely by CI — no
# more local terraform apply / state migration ever again.
###############################################################################

terraform {
  backend "s3" {
    bucket       = "tf-bootstrap-state-018701995398-ap-south-1"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true # Terraform 1.10+ native S3 locking; no DynamoDB needed
  }
}
