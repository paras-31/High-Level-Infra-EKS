# Module: `ecr`

Creates hardened **Elastic Container Registry** repositories for your images.

## Security defaults

| Control | Setting |
|---------|---------|
| **Immutable tags** | `image_tag_mutability = "IMMUTABLE"` — a tag can never be overwritten, so `:v1.2.3` is reproducible and can't be swapped by an attacker. |
| **Scan on push** | Every pushed image is CVE-scanned automatically. |
| **Encryption** | KMS (pass `kms_key_arn`) or AES256 at rest. |
| **Lifecycle policy** | Untagged images expire after `untagged_expiry_days`; only the newest `max_image_count` tagged images are kept — controls storage cost and cruft. |
| **Repo policy** | Optional `repository_policy_json` for scoped cross-account pulls. |

## Usage

```hcl
module "ecr" {
  source           = "../../modules/ecr"
  repository_names = ["frontend", "backend"]
  kms_key_arn      = module.kms.ebs_key_arn # or a dedicated key
  tags             = var.tags
}
```

## Outputs

`repository_urls` (map name→URL, use in CI to build/push) and `repository_arns`.
