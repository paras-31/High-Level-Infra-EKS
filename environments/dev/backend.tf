terraform {
  backend "s3" {
    bucket         = "acme-eks-tfstate-123456789012" # <- from bootstrap output
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
