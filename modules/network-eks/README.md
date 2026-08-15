# Module: `network-eks`

**EKS-only** network resources. Does **not** create the VPC.

| Resource | Why it's here (not in High-level-VPC) |
|----------|----------------------------------------|
| Intra subnets | EKS control-plane ENI isolation |
| `kubernetes.io/*` tags | LB Controller + Karpenter discovery |
| VPC endpoints | ECR/STS/Logs without public internet |
| Flow logs | Audit trail for the VPC |

VPC (public/private subnets, NAT, NACL) comes from
[`paras-31/High-level-VPC`](https://github.com/paras-31/High-level-VPC) via `modules/platform`.
