# Module: `platform`

The **composition root** — one module call that stands up a complete, hardened
EKS environment by wiring together the in-house building blocks in the right order:

```
kms  ──►  vpc  ──►  eks  ──►  eks-addons (IRSA)
                     │
                     └──►  ecr
```

Each environment (`environments/dev|staging|prod`) is just a thin wrapper that
calls this module with environment-specific values. That keeps the three
environments consistent and drift-free while letting each tune size/HA/cost.

## What a single call creates

- **KMS** — 3 customer-managed keys (secrets / EBS / logs).
- **VPC** — 3-tier subnets, NAT, flow logs, VPC endpoints.
- **EKS** — private control plane, OIDC/IRSA, managed node groups, encrypted disks, audit logs.
- **eks-addons** — IRSA roles for LB controller, external-dns, Karpenter (+ node role, instance profile, interruption queue).
- **ECR** — image repositories (immutable, scan-on-push).

Governance (`security-baseline`) is intentionally **not** part of this module —
it is account-level and deployed once (see the `prod` environment).

## Usage

```hcl
module "platform" {
  source = "../../modules/platform"

  name_prefix = "eks-prod"
  environment = "prod"
  aws_region  = "ap-south-1"

  vpc_cidr             = "10.30.0.0/16"
  azs                  = ["ap-south-1a", "ap-south-1b", "ap-south-1c"]
  private_subnet_cidrs = ["10.30.0.0/20", "10.30.16.0/20", "10.30.32.0/20"]
  public_subnet_cidrs  = ["10.30.48.0/24", "10.30.49.0/24", "10.30.50.0/24"]
  intra_subnet_cidrs   = ["10.30.60.0/24", "10.30.61.0/24", "10.30.62.0/24"]
  single_nat_gateway   = false

  cluster_version = "1.31"
  managed_node_groups = {
    system = { desired_size = 3, min_size = 3, max_size = 6, instance_types = ["m6i.large"] }
  }

  ecr_repository_names = ["frontend", "backend"]
  tags                 = { Project = "eks-platform" }
}
```

## Outputs

Networking (`vpc_id`, subnets), cluster (`cluster_name`, `cluster_endpoint`,
`oidc_provider_arn`), KMS ARNs, all add-on IRSA role ARNs + Karpenter
instance-profile/queue, and `ecr_repository_urls`.
