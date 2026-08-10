# Environment: `dev`

Cost-optimized development EKS environment.

| Aspect | dev value |
|--------|-----------|
| VPC CIDR | `10.10.0.0/16` |
| NAT | **single shared** (cheaper, non-HA) |
| API endpoint | public **but locked to your laptop IP /32** (`cluster_endpoint_public_access_cidrs`) |
| Node group | one SPOT `t3.large` group (1–4) |
| Log retention | 30 days |
| Governance | none (that lives in `prod`) |

## Deploy

```bash
cd environments/dev
cp terraform.tfvars.example terraform.tfvars   # set your egress CIDR + admin role
terraform init
terraform apply
aws eks update-kubeconfig --region ap-south-1 --name eks-dev-eks
```

> Public endpoint access is a dev convenience for kubectl from your laptop.
> Set `cluster_endpoint_public_access_cidrs` to your public IP as `/32` only.
> Open internet (`0.0.0.0/0`) is blocked by Terraform validation and OPA.
