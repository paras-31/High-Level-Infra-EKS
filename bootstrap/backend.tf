###############################################################################
# S3 backend for bootstrap's own state.
#
# Chicken-and-egg note:
#   The bucket + DynamoDB + KMS key referenced below are CREATED by this same
#   module. So the very first apply on a NEW account MUST run with LOCAL state:
#
#     terraform init                          # local state
#     terraform apply                         # creates S3 + DDB + KMS
#     terraform init -migrate-state -force-copy   # move local state into S3
#
#   All subsequent runs (including in CI) use this S3 backend directly.
#   The ./bootstrap-account.sh script automates that first-time flow.
###############################################################################

terraform {
  backend "s3" {
    bucket         = "tf-state-018701995398-ap-south-1"
    key            = "bootstrap/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/tf-state-018701995398-ap-south-1"
  }
}
