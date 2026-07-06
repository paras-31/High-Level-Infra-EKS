# Environment: `prod`

The production EKS environment. Thin wrapper over [`modules/platform`](../../modules/platform)
plus the account-level [`security-baseline`](../../modules/security-baseline).

## Characteristics

| Aspect | prod value |
|--------|-----------|
| VPC CIDR | `10.30.0.0/16` |
| AZs | 3 (`ap-south-1a/b/c`) |
| NAT | **one per AZ** (HA) |
| API endpoint | **private only** |
| Node groups | `system` (tainted, 3–6) + `apps` (2–10); app scale via Karpenter |
| Log retention | 365 days |
| Governance | CloudTrail + GuardDuty + Security Hub + Config **enabled** |

## Prerequisites

1. `bootstrap/` applied → update `backend.tf` bucket/table if you changed names.
2. `cp terraform.tfvars.example terraform.tfvars` and fill in a unique
   `security_log_bucket_name` and your `platform_admin_role_arn`.

## Deploy

```bash
cd environments/prod
terraform init
terraform plan  -out=prod.plan
terraform apply prod.plan

# then point kubectl at it:
aws eks update-kubeconfig --region ap-south-1 --name eks-prod-eks
```

## After apply — install controllers (your Helm/CD flow)

Use the output role ARNs for the service-account annotations:

- `load_balancer_controller_role_arn` → `aws-load-balancer-controller`
- `external_dns_role_arn` → `external-dns`
- `karpenter_controller_role_arn` → Karpenter SA, plus
  `karpenter_node_instance_profile_name` and `karpenter_interruption_queue_name`
  in Karpenter's Helm values. Your `karpenter/*.yml` manifests apply here.

## Notes

- Because the endpoint is **private**, run `terraform`/`kubectl` from a host with
  network reachability to the VPC (VPN, bastion via SSM, or a self-hosted CI runner).
- `security-baseline` services are account singletons — if already enabled
  elsewhere, flip the relevant `enable_*` to `false` in `main.tf`.
