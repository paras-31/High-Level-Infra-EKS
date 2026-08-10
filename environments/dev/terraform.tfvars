aws_region = "ap-south-1"

# Laptop public IP — only this host can reach the EKS API (kubectl, aws eks update-kubeconfig).
cluster_endpoint_public_access_cidrs = ["134.238.10.24/32"]
