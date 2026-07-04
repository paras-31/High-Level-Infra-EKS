# Module: `kms`

Creates three **customer-managed KMS keys (CMKs)** with rotation enabled, one per
concern, so encryption-at-rest is under your control (not AWS-owned keys):

| Alias | Used by | Notes |
|-------|---------|-------|
| `alias/<prefix>-eks` | EKS secrets envelope encryption | Attached to the cluster's `encryption_config`. |
| `alias/<prefix>-ebs` | EBS CSI driver / node root volumes | Key policy grants the AutoScaling service-linked role so nodes can mount encrypted volumes. |
| `alias/<prefix>-logs` | CloudWatch Logs (control-plane & flow logs) | Key policy scoped to the `logs.<region>.amazonaws.com` service via encryption context. |

## Why separate keys

Blast-radius isolation and least-privilege: a compromised node role that can use
the EBS key still cannot decrypt Kubernetes secrets. Each key rotates
automatically every year and has a configurable deletion window (default 30 days).

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `name_prefix` | Alias prefix | — |
| `aws_region` | Region (for the Logs key policy) | — |
| `deletion_window_in_days` | Scheduled-deletion waiting period | `30` |

## Outputs

`eks_key_arn`, `ebs_key_arn`, `logs_key_arn`, and `key_arns` (map).
