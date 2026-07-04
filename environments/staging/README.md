# Environment: `staging`

Pre-production environment that mirrors `prod`'s topology (private endpoint,
3 AZs) but at lower cost (single NAT, smaller baseline node group). Use it to
validate changes — cluster upgrades, add-on bumps, app releases — before prod.

| Aspect | staging value |
|--------|--------------|
| VPC CIDR | `10.20.0.0/16` |
| NAT | single shared |
| API endpoint | private only |
| Node group | `system` `m6i.large` (2–4) + Karpenter for apps |
| Log retention | 90 days |
| Governance | none (account-level lives in `prod`) |

## Deploy

```bash
cd environments/staging
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
aws eks update-kubeconfig --region us-east-1 --name eks-staging-eks
```

Private endpoint → run from a network-reachable host (VPN / SSM bastion / self-hosted runner).
