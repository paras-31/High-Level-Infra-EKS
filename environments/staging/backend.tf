terraform {
  backend "s3" {
    bucket         = "tf-state-765574565805-ap-south-1"
    key            = "staging/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/tf-state-765574565805-ap-south-1"
  }
}
