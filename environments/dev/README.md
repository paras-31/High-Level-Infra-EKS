# Environment: `dev`

Secure private EKS — **nodes never on the internet**; **API locked to your IP only**.

| Layer | Setting |
|-------|---------|
| **EKS API (public)** | Enabled, CIDR-locked to `admin_access_cidrs` in `terraform.tfvars` |
| **EKS API (private)** | Always enabled (in-VPC access) |
| **Worker nodes** | Private subnets only, no public IPs |
| **Node security group** | No `0.0.0.0/0` ingress — cluster SG + node-to-node only |
| **VPC** | NACL + NAT + VPC endpoints (from High-level-VPC git module) |
| **IMDSv2** | Required on all nodes |
| **Secrets** | KMS envelope encryption |

## Update your IP

```bash
curl -s ifconfig.me   # then set admin_access_cidrs = ["YOUR.IP/32"] in terraform.tfvars
```

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
aws eks update-kubeconfig --region ap-south-1 --name eks-dev-eks
kubectl get nodes
```
