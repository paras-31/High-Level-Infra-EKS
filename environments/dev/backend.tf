terraform {
  backend "s3" {
    bucket         = "tf-state-174765206872-ap-south-1"
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    kms_key_id     = "alias/tf-state-174765206872-ap-south-1"
  }
}
