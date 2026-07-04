# Pattern Catalog Review Standards

Detailed review standards for Terraform modules published to McKinsey's Pattern Catalog (`FIRM-TF-MODULES` registry). Based on [Azure Verified Modules specs](https://azure.github.io/Azure-Verified-Modules/specs/), adapted for firm requirements.

Source: [Module specifications](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/771916098)

> **Apply these standards only when the module targets the Pattern Catalog registry.** For general Terraform reviews, use the core review sections in [SKILL.md](../SKILL.md).

---

## File Organization (Pattern Catalog Additions)

Pattern Catalog modules require these additional files beyond the standard layout:

| File | Contents | Standard |
|------|----------|----------|
| `variables_deprecated.tf` | Deprecated variables with `DEPRECATED` prefix in description | TFSNFR102 |
| `outputs_deprecated.tf` | Deprecated outputs | TFSNFR103 |
| `version.txt` | Module semantic version for mandatory tags | TFSFR300 |
| `.terraform-docs.yml` | Auto-generated documentation config | TFSNFR300 |
| `examples/` | Named deployment scenarios | TFSNFR301 |

Locals must be alphabetically ordered (or logically grouped, each group alphabetical) with precise types — use `3` not `"3"` for numbers (TFSNFR109-110). `locals.tf` must contain only `locals` blocks (TFSNFR111).

Dependencies come first in file, dependents after — related resources close together (TFSNFR122).

---

## Version Pinning (Pattern Catalog)

### Bounded constraints required (TFSNFR100, TFSNFR121)

Pattern Catalog modules must constrain both minimum AND maximum major version. `>=` alone (no upper bound) is **not acceptable**.

```hcl
terraform {
  required_version = ">=1.0, <1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.0, <6"  # any bounded range is valid (e.g. ">=6, <7", ">=5.23, <6")
    }
  }
}
```

Both `~> #.#` and `>= #.#, < #` formats are acceptable. Providers alphabetically ordered; only include directly-used providers. Submodules have their own `versions.tf`.

### Cross-referencing modules (TFSFR101)

Only reference modules from the Pattern Catalog `FIRM-TF-MODULES` registry:

```hcl
module "other-module" {
  source  = "terraform.mckinsey.cloud/FIRM-TF-MODULES/vpc/aws"
  version = ">=1, <2"
}
```

---

## Naming Conventions (Pattern Catalog Additions)

| Rule | ID | Severity |
|------|----|----------|
| **Lower snake_case** for all identifiers (`local`, `variable`, `output`, `resource`, `data`, `module`) | TFSNFR128 | WARNING |
| Use `this` when only one resource of that type exists or no better name available | TFSNFR129 | INFO |
| Never include the resource type in the name | TFSNFR130 | WARNING |
| Always use **singular nouns** for names | TFSNFR131 | WARNING |
| Child resources prefixed with parent name; allow override via variable | TFSNFR132 | WARNING |
| Feature switches use **positive statements**: `xxx_enabled`/`enable_xxx`, not `xxx_disabled` | TFSNFR114 | WARNING |

---

## Variable & Output Standards

### Variable rules

| Rule | ID | Severity |
|------|----|----------|
| Every variable must have `type` — avoid `any` | TFSNFR107 | WARNING |
| Every variable must have `description` — target module users; use HEREDOC for objects | TFSNFR106 | WARNING |
| Use precise types: `bool` for flags, `string` for text, concrete `object` over `map(any)` | TFSNFR107 | WARNING |
| Set `nullable = false` for collections (sets, maps, lists) used in loops | TFSNFR105 | WARNING |
| Never explicitly declare `nullable = true` | TFSNFR112 | WARNING |
| Never explicitly declare `sensitive = false` | TFSNFR113 | WARNING |
| Sensitive variables must not have defaults (except `null`/`[]` to disable feature) | TFSNFR127 | CRITICAL |
| If `object` has sensitive field, mark whole variable `sensitive = true` or extract the field | TFSNFR126 | WARNING |
| `name` (resource modules) and `region` must NOT have defaults | TFSNFR402 | WARNING |
| Do not use `enabled` or `module_depends_on` variables — use native `count`/`for_each`/`depends_on` on modules | TFSNFR401 | WARNING |

### Variable ordering (TFSNFR117)

Variables must be ordered with section headers:

```hcl
################
### Required ###
################

variable "name" {
  description = "The name of the resource"
  type        = string
}

################
### Optional ###
################

variable "alias" {
  description = "The alias of the resource"
  type        = string
  default     = null
}
```

Required (no `default`) first, then optional — each group alphabetical.

### HEREDOC descriptions for object variables (TFSNFR106)

```hcl
variable "file_system_config" {
  description = <<-EOT
  Connection settings for an EFS file system.
  - `arn`               (Required) ARN of the EFS Access Point.
  - `local_mount_path`  (Required) Path starting with /mnt/.
EOT
  type = object({
    arn              = string
    local_mount_path = string
  })
  default = null
}
```

### Output rules

| Rule | ID | Severity |
|------|----|----------|
| Outputs alphabetically ordered | TFSNFR120 | WARNING |
| Confidential outputs must declare `sensitive = true` | TFSNFR119 | CRITICAL |
| Deprecated outputs go in `outputs_deprecated.tf` | TFSNFR103 | WARNING |

### Required outputs (TFSFR200)

Every module must output (if applicable):

```hcl
output "arn" {
  description = "The Amazon Resource Name (ARN) of the resource"
  value       = resource.this.arn
}

output "ssm_info" {
  description = "Path to the AWS System Manager Parameter Store key with all information about provisioned resource"
  value       = try(aws_ssm_parameter.this[0].name, "")
}
```

---

## Resource Block Ordering (TFSNFR118)

Pattern Catalog modules enforce stricter ordering within resource/data blocks:

```
Top meta-arguments (in order):
  1. provider
  2. count
  3. for_each

Then:
  1. Required arguments (alphabetical)
  2. Optional arguments (alphabetical)
  3. Required nested blocks (alphabetical)
  4. Optional nested blocks (alphabetical)

Bottom meta-arguments (in order):
  1. depends_on
  2. lifecycle (create_before_destroy → ignore_changes → prevent_destroy)
```

Separate each group with blank lines. `depends_on` and `ignore_changes` values alphabetical. `dynamic` blocks ranked by their block name. Code within nested blocks follows same ordering rules.

### Null comparison for creation toggle (TFSNFR115)

Wrap external resource references in `object` to avoid "known after apply" issues:

```hcl
variable "security_group" {
  description = "Existing security group"
  type = object({
    id = string
  })
  default = null
}

resource "aws_security_group" "this" {
  count = var.security_group == null ? 1 : 0
  # ...
}
```

### Dynamic blocks for optional nested objects (TFSNFR116)

```hcl
dynamic "condition" {
  for_each = length(local.role_sts_externalid) != 0 ? [true] : []

  content {
    test     = "StringEquals"
    variable = "sts:ExternalId"
    values   = local.role_sts_externalid
  }
}
```

### Misc code style

| Rule | ID |
|------|----|
| Use `coalesce`/`try` for defaults, not ternary null checks | TFSNFR124 |
| No quotes in `ignore_changes` values | TFSNFR125 |

---

## Provider Declaration in Modules (TFSNFR104)

**Never** declare `provider` blocks in modules unless multiple instances of the same provider are needed. Use `configuration_aliases`:

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">=5.0, <6"  # any bounded range
      configuration_aliases = [aws.alternate]
    }
  }
}
```

Only `alias` is allowed in provider blocks within modules — no other configuration fields. Declaring other fields prevents module consumers from using `count`, `for_each`, or `depends_on`.

---

## Mandatory Tags (TFSFR300)

All taggable resources must include module traceability tags.

### Required tags (must be present)

| Tag | Source | Purpose |
|-----|--------|---------|
| `tf_module_name` | Computed from module registry path | Identifies which Pattern Catalog module provisioned the resource |
| `tf_deployment_id` | Unique identifier per deployment | Correlates all resources from a single module invocation |
| `tf_module_version` | Read from `version.txt` | Tracks which module version was deployed |

### Good-to-have tags (recommended)

| Tag | Source | Purpose |
|-----|--------|---------|
| `used_for` | Passed via `var.tags` or dedicated variable | Identifies the workload or purpose (e.g. `"data-pipeline"`) |
| `product_id` | Passed via `var.tags` or dedicated variable | Maps resource to a product/cost center for billing and ownership |

### Implementation

```hcl
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  tf_module_version = trim(file("${path.module}/version.txt"), " \n")
  tf_module_name    = "terraform.mckinsey.cloud/FIRM-TF-MODULES/<module-name>/<provider>"
  tf_deployment_id  = var.tf_deployment_id

  tags = merge(var.tags, {
    "tf_module_name"    = local.tf_module_name
    "tf_deployment_id"  = local.tf_deployment_id
    "tf_module_version" = local.tf_module_version
  })
}
```

---

## Availability Zones (TFSFR100)

- Zone-redundant resources: span 3+ AZs by default
- Zonal resources: expose zone selection variable, no default zone
- Both cases must expose configuration via variables

---

## Composite Module Rules (TFCNFR)

| Rule | ID | Severity |
|------|----|----------|
| Build from Pattern Catalog resource modules; native resources only when resource module would be limiting or isn't available yet | TFCNFR100 | WARNING |
| May use other Pattern Catalog composite modules | TFCNFR101 | INFO |
| Must NOT reference non-Pattern Catalog modules | TFCNFR100/101 | CRITICAL |
| Replace native resources with resource modules when they become available | TFCNFR100 | INFO |

---

## Feature Toggles (TFSNFR108)

New resources in minor/patch releases must default to OFF to prevent surprise plan changes:

```hcl
variable "create_route_table_public" {
  description = "Whether to create `public` route table"
  type        = bool
  default     = false
  nullable    = false
}

resource "aws_route_table" "public" {
  count  = var.create_route_table_public ? 1 : 0
  vpc_id = aws_vpc.this.id
}
```

New arguments: use provider schema default or `null`. New nested blocks: use `dynamic` with omitted default.

---

## Breaking Changes Review (TFSNFR101)

Review with caution — potential breaking changes:

**Resource blocks:** adding resources without conditional creation, non-default argument values, non-dynamic nested blocks, renaming without `moved` blocks, switching `count`↔`for_each`

**Variable/output blocks:** deleting/renaming variables, changing type/default/nullable/sensitive, adding required variables, deleting/changing outputs

Use `moved` blocks for safe resource renames.

---

## Testing & Documentation

### Documentation (TFSNFR300-301)

`.terraform-docs.yml` must be present in the module root:

```yaml
formatter: markdown table
sort:
  enabled: true
  by: required
```

An `examples/` directory must exist with named deployment scenarios.

### Testing requirements

| Test Type | ID | Description |
|-----------|----|-------------|
| Deployment (E2E) | TFSNFR700 | Deploy real resources from `/examples`, no user input, auto-cleanup |
| Idempotency | TFSNFR701 | Deploy twice; expect no changes on second apply |
| Unit | TFSNFR704 | Test logic/conditions without deploying resources |
| Upgrade | TFSNFR705 | Ensure non-breaking on minor/patch releases |
| Child resources | TFSNFR703 | Test submodule deployments separately |

### Tooling (TFSNFR702)

- `terraform validate/fmt/test`
- tflint (with AWS/Azure/GCP ruleset)
- Wiz CLI (firm scan policy)
- Terratest

---

## GitHub & Contribution Standards (TFSNFR200-206)

| Standard | Requirement |
|----------|-------------|
| TFSNFR200 | `@McK-Internal/pattern-catalog-admin` must be repo admins |
| TFSNFR201 | Branch protection on `main`: PR required, 1+ approval, code owner review, linear history, no force push |
| TFSNFR202 | Permissions via GitHub teams only (no individual users) |
| TFSNFR203 | Respond to issues within 3 business days |
| TFSNFR204 | No license files (internal use only) |
| TFSNFR205 | Only latest major version supported |
| TFSNFR206 | One `productid-XXXXX` topic per repo |

---

## Additional Reference Documents

- Full TFSFR specifications: [shared-functional-requirements.md](shared-functional-requirements.md)
- Full TFSNFR specifications: [shared-non-functional-requirements.md](shared-non-functional-requirements.md)
- Composite module requirements: [composite-module-requirements.md](composite-module-requirements.md)
- Module support & FAQ: [module-support-faq.md](module-support-faq.md)
- [Module specifications (Confluence)](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/771916098)
