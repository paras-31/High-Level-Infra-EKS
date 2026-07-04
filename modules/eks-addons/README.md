# Module: `eks-addons`

Creates the **IAM/IRSA plumbing** for the cluster's higher-level controllers,
using native `aws_*` resources only. Following the "Terraform owns IAM, your CD
flow owns Helm" split, this module does **not** install the controllers — it
produces the role ARNs you feed into their Helm values / service-account
annotations. This keeps Terraform state decoupled from cluster availability.

## What it provisions

| Controller | IAM created | You install (Helm) with |
|-----------|-------------|--------------------------|
| **AWS Load Balancer Controller** | IRSA role + full official IAM policy | `serviceAccount.annotations.eks.amazonaws.com/role-arn = <load_balancer_controller_role_arn>` |
| **external-dns** | IRSA role + scoped Route53 policy | `<external_dns_role_arn>`; scope zones via `external_dns_hosted_zone_arns` |
| **Karpenter** | Controller IRSA role, node role + instance profile, SQS interruption queue, EventBridge rules | controller role ARN, node role name, instance profile, and queue name (all outputs) |
| **metrics-server** | *none needed* | Install directly; it requires no AWS IAM. |

## Karpenter specifics

- **Controller role** — scoped policy for `RunInstances`/`CreateFleet`, `iam:PassRole` limited to the Karpenter node role, SQS access, `eks:DescribeCluster`, SSM AMI lookup, pricing.
- **Node role + instance profile** — reference `karpenter_node_instance_profile_name` in your `EC2NodeClass`.
- **Interruption handling** — an SQS queue plus EventBridge rules for spot interruption, rebalance recommendations, instance state changes, and AWS Health events. Set `settings.interruptionQueue = <karpenter_interruption_queue_name>` in Karpenter's Helm values.
- Your existing `karpenter/ec2pool.yml` and `karpenter/nodepool.yml` manifests plug straight into this.

## Toggles

`enable_load_balancer_controller`, `enable_external_dns`, `enable_karpenter`
(all default `true`). Set any to `false` to skip.

## Inputs

`cluster_name`, `aws_region`, `oidc_provider_arn`, `oidc_provider_url`,
`permissions_boundary_arn`, `external_dns_hosted_zone_arns`, `karpenter_namespace`.

## Outputs

`load_balancer_controller_role_arn`, `external_dns_role_arn`,
`karpenter_controller_role_arn`, `karpenter_node_role_name`,
`karpenter_node_instance_profile_name`, `karpenter_interruption_queue_name`.
