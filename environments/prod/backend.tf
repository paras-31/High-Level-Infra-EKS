###############################################################################
# Remote state — values come from the bootstrap stack outputs.
# Bucket + DynamoDB table must already exist (see /bootstrap).
###############################################################################
terraform {
  backend "s3" {
    bucket         = "acme-eks-tfstate-123456789012" # <- from bootstrap output
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    # kms_key_id   = "arn:aws:kms:us-east-1:...:key/..."  # optional: bootstrap state key
  }
}
