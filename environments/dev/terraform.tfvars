aws_region = "ap-south-1"

# Only this IP can reach the EKS API from the internet (kubectl / aws eks update-kubeconfig).
# Find yours: curl -s ifconfig.me
admin_access_cidrs = ["134.238.10.24/32"]
