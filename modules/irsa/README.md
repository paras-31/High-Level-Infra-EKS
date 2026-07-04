# Module: `irsa`

Reusable **IAM Roles for Service Accounts** primitive. Instead of giving worker
nodes broad IAM permissions, IRSA lets a *specific* Kubernetes service account
assume a *specific* IAM role through the cluster's OIDC provider — the
least-privilege way to grant AWS access to pods.

## How it works

1. The EKS cluster exposes an OIDC identity provider (created by the `eks` module).
2. This module builds an IAM trust policy that only allows
   `system:serviceaccount:<namespace>:<name>` (the `sub` claim) with audience
   `sts.amazonaws.com` to assume the role.
3. You attach managed policy ARNs and/or an inline policy.
4. Annotate the Kubernetes service account:
   `eks.amazonaws.com/role-arn: <role_arn output>`.

## Example

```hcl
module "app_s3_access" {
  source            = "../../modules/irsa"
  role_name         = "prod-app-s3-reader"
  oidc_provider_arn = module.platform.oidc_provider_arn
  service_accounts  = [{ namespace = "app", name = "worker" }]
  policy_arns       = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]
  permissions_boundary_arn = var.permissions_boundary_arn
  tags              = var.tags
}
```

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| `role_name` | IAM role name | — |
| `oidc_provider_arn` | Cluster OIDC provider ARN | — |
| `service_accounts` | List of `{namespace, name}` allowed to assume | — |
| `policy_arns` | Managed policies to attach | `[]` |
| `inline_policy_json` | Optional inline policy | `null` |
| `permissions_boundary_arn` | Optional permissions boundary | `null` |

## Outputs

`role_arn`, `role_name`.
