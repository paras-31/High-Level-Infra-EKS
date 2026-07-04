provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Repo        = "terraform-eks-infra"
    }
  }
}
