# Module: `platform`

Wires the full EKS stack. **VPC is not defined in this repo.**

```
kms
 └─► High-level-VPC (git)     ← you pass subnet CIDRs, NAT, NACL flags
 └─► network-eks              ← EKS-only: intra, tags, endpoints, flow logs
 └─► eks (private API only)
 └─► eks-addons
 └─► ecr
```

## VPC values passed to High-level-VPC

Set in each `environments/<env>/main.tf` or override via platform variables:

| Variable | Secure private default |
|----------|------------------------|
| `vpc_enable_public_subnets` | `true` (NAT + external LBs — **not** public EKS API) |
| `vpc_enable_private_subnets` | `true` |
| `vpc_enable_nat_gateway` | `true` |
| `vpc_enable_nacl` | `true` |
| `single_nat_gateway` | `true` dev/staging, `false` prod |

EKS API is **private inside the VPC**; optional public access is CIDR-locked via `admin_access_cidrs`.

VPC module ref is pinned in `main.tf` (`?ref=main`). To upgrade, edit that static `source` line.

See root [README](../../README.md) for `GH_MODULE_TOKEN` setup.
