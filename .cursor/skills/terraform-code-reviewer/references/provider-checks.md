# Provider-Specific Checks

Security and configuration checks for each supported Terraform provider. Referenced from [reference.md](../reference.md) and [SKILL.md](../SKILL.md) Section 7.

---

## AWS (`hashicorp/aws`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | `default_tags` | Must include `used_for` and `product_id`; merge with `var.tags` |
| 2 | All taggable resources | `tags` | Inherit `default_tags`; verify no resource overrides remove required tags |
| 3 | `aws_s3_bucket` | `server_side_encryption_configuration` | SSE-S3 or SSE-KMS |
| 4 | `aws_s3_bucket_public_access_block` | All four `block_*` flags | `true` unless public by design |
| 5 | `aws_db_instance` | `storage_encrypted` | `true` |
| 6 | `aws_db_instance` | `deletion_protection` | `true` for production |

## Azure (`hashicorp/azurerm`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | `features {}` present | Required |
| 2 | All taggable resources | `tags` | Must include `used_for` and `product_id`; pass via `var.tags` merge |
| 3 | `azurerm_storage_account` | `min_tls_version` | `"TLS1_2"` |
| 4 | `azurerm_storage_account` | `allow_nested_items_to_be_public` | `false` |
| 5 | `azurerm_key_vault` | `purge_protection_enabled` | `true` |
| 6 | `azurerm_key_vault` | `soft_delete_retention_days` | `>= 7` |

## GCP (`hashicorp/google`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | `project` and `region` | Explicit |
| 2 | All labelable resources | `labels` | Must include `used_for` and `product_id`; pass via `var.labels` merge |
| 3 | `google_storage_bucket` | `uniform_bucket_level_access` | `true` |
| 4 | `google_storage_bucket` | `encryption` block | CMEK or default |
| 5 | `google_container_cluster` | `enable_shielded_nodes` | `true` |
| 6 | `google_container_cluster` | `release_channel` | `REGULAR` or `STABLE` |

## Kubernetes (`hashicorp/kubernetes`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | Auth mechanism | `exec`, `config_path`, or variable token |
| 2 | All resources | `metadata.labels` | Must include `used_for` and `product_id` labels |
| 3 | Role / ClusterRole | RBAC rules | No `*` verbs/resources |
| 4 | All resources | `namespace` | Explicit (not `default`) |

## Vault (`hashicorp/vault`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | `address` | From variable (not hardcoded) |
| 2 | Provider block | `token` | `sensitive` variable, env var (`VAULT_TOKEN`), or auth backend — never hardcoded |
| 3 | Provider block | TLS | `skip_tls_verify = false` (default) — only override in dev with justifying comment |
| 4 | `vault_mount` | Secrets engine type | Use `kv-v2` over `kv` for versioned secrets |
| 5 | `vault_policy` | Policy scope | Least privilege — no `path "*"` with `capabilities = ["sudo"]` |
| 6 | `vault_auth_backend` | Auth methods | Prefer `oidc`, `aws`, `kubernetes` over `token`-only for production |
| 7 | `vault_generic_secret` | Secret data | Never inline secret values in `.tf` — use `data` source reads or external injection |

## PostgreSQL (`cyrilgdn/postgresql`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | `host` | From variable (not hardcoded) |
| 2 | Provider block | `password` | `sensitive` variable or secrets manager — never hardcoded |
| 3 | Provider block | `sslmode` | `require`, `verify-ca`, or `verify-full` — never `disable` in production |
| 4 | `postgresql_role` | `superuser` | `false` unless strictly justified — use least privilege |
| 5 | `postgresql_role` | `login` + `connection_limit` | Set `connection_limit` for service accounts to prevent pool exhaustion |
| 6 | `postgresql_role` | `password` | Marked `sensitive` or injected externally — never in plaintext |
| 7 | `postgresql_grant` | Privilege scope | Grant specific privileges (`SELECT`, `INSERT`) — avoid `ALL` without justification |
| 8 | `postgresql_database` | `encoding` + `lc_collate` | Explicit — `UTF8` unless specific locale requirement |

## Dynatrace (`dynatrace-oss/dynatrace`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | `dt_env_url` | From variable |
| 2 | Provider block | `dt_api_token` | `sensitive` variable or secrets manager |
| 3 | All resources | Token permissions | Match managed resource scopes |

## Cribl (`cribl/cribl`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | API credentials | `client_id` and `client_secret` from `sensitive` variables or secrets manager |
| 2 | `cribl_worker_group` | Fleet management | Worker groups scoped to specific environments |
| 3 | All resources | Naming convention | Consistent naming aligned with Cribl organization hierarchy |

## Cloudflare (`cloudflare/cloudflare`)

| # | Resource / Config | Check | Expected |
|---|-------------------|-------|----------|
| 1 | Provider block | API auth | Scoped token (not global key) |
| 2 | `cloudflare_ruleset` | WAF rules | Active |
| 3 | Zone settings | `min_tls_version` | `"1.2"` |
