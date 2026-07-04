# Module: `eks`

The hardened EKS control plane and managed node groups, built **entirely from
native `aws_*` resources** — `aws_eks_cluster`, `aws_eks_node_group`,
`aws_launch_template`, `aws_eks_addon`, `aws_iam_openid_connect_provider`,
`aws_eks_access_entry`, etc. No community modules, so you can bump the cluster
version or flip any attribute yourself.

## Files

| File | Contents |
|------|----------|
| `main.tf` | Cluster, control-plane log group, additional control-plane SG, EKS managed add-ons |
| `iam.tf` | Cluster role, node role, OIDC provider, IRSA roles for VPC-CNI and EBS-CSI |
| `nodes.tf` | Node SG + rules, per-group launch templates, managed node groups |
| `access.tf` | EKS access entries + policy associations (API auth mode) |

## Security defaults baked in

| Control | Implementation |
|---------|----------------|
| **Private API endpoint** | `endpoint_private_access = true`; public access off by default, CIDR-allowlisted when on. |
| **Secrets encryption** | `encryption_config` envelope-encrypts secrets with a customer-managed KMS key. |
| **Audit / control-plane logs** | All 5 log types to an explicitly-created, KMS-encrypted CloudWatch group with retention. |
| **IRSA / OIDC** | `aws_iam_openid_connect_provider` created; VPC-CNI and EBS-CSI get their own least-privilege roles (CNI policy is **not** on the node role). |
| **IMDSv2 enforced** | Launch template sets `http_tokens = required`, hop limit 1. |
| **Encrypted node disks** | gp3 root volumes encrypted with the EBS CMK. |
| **API auth mode** | `API_AND_CONFIG_MAP` + access entries — no manual `aws-auth` edits. |
| **SSM, no SSH** | Node role gets `AmazonSSMManagedInstanceCore`; no key pair, no port 22. |
| **Permissions boundary** | Optional `permissions_boundary_arn` applied to every role this module creates. |

## Managed add-ons

`coredns`, `kube-proxy`, `vpc-cni` (IRSA + prefix delegation),
`eks-pod-identity-agent`, `aws-ebs-csi-driver` (IRSA + KMS grant). Higher-level
controllers (LB controller, Karpenter, external-dns) get their **IRSA roles**
from the [`eks-addons`](../eks-addons) module and are Helm-installed by your CD flow.

## Defining node groups

```hcl
managed_node_groups = {
  system = {
    desired_size   = 2
    min_size       = 2
    max_size       = 4
    instance_types = ["m6i.large"]
    labels         = { role = "system" }
    taints = [{ key = "CriticalAddonsOnly", value = "true", effect = "NO_SCHEDULE" }]
  }
}
```

`desired_size` drift is ignored after creation so autoscalers can own it.

## Defining cluster access

```hcl
access_entries = {
  platform_admins = {
    principal_arn = "arn:aws:iam::123456789012:role/PlatformAdmin"
    policy_associations = [{
      policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
      access_scope = { type = "cluster" }
    }]
  }
}
```

## Key outputs

`cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data`,
`oidc_provider_arn`, `oidc_provider_url`, `cluster_security_group_id`,
`node_security_group_id`, `node_iam_role_arn`.
