###############################################################################
# Remote state — values come from the bootstrap stack outputs.
# Bucket + DynamoDB table + KMS key are created by /bootstrap (Tier 1).
###############################################################################
terraform {
  backend "s3" {
    bucket         = "tf-state-018701995398-ap-south-1"
    key            = "prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/tf-state-018701995398-ap-south-1"
  }
}
