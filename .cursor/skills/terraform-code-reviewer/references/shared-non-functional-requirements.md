# Terraform Shared Non-Functional Requirements (TFSNFR)

Source: [Confluence](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/771655976)

---

## Category 1XX: Code Style

### TFSNFR100 — `versions.tf`

Must contain exactly one `terraform` block. First line defines `required_version` with min AND max major constraints. Use `~> #.#` or `>= #.#.#, < #.#.#`.

```hcl
terraform {
  required_version = ">=1.0, <1.8"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.23, <6"
    }
  }
}
```

### TFSNFR101 — Breaking Changes Review

Potential breaking changes from **resource blocks**:
1. Adding resource without `count`/`for_each` for conditional creation
2. Adding argument with non-default value
3. Adding nested block without `dynamic` or omitting by default
4. Renaming resource without `moved` blocks
5. Switching `count` ↔ `for_each`

Potential breaking changes from **variable/output blocks**:
1. Deleting/renaming a variable
2. Changing `type`, `default`, `nullable` (to false), `sensitive` (false→true)
3. Adding required variable (no default)
4. Deleting output, changing output `value` or `sensitive`

### TFSNFR102 — Deprecated Variables

Move to `variables_deprecated.tf`. Prefix description with `DEPRECATED`:

```hcl
variable "create_nat_gateway_public" {
  description = "DEPRECATED, use `create_public_nat_gateway` instead; Controls if a public NAT Gateway is created"
  type        = bool
  default     = false
}
```

Cleanup during major version release only.

### TFSNFR103 — Deprecated Outputs

Move to `outputs_deprecated.tf`. Cleanup during major version upgrade.

### TFSNFR104 — Provider Declaration

**Never** declare `provider` blocks in modules unless multiple instances needed. Use `configuration_aliases`:

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">=5.23, <6"
      configuration_aliases = [aws.alternate]
    }
  }
}
```

Only `alias` allowed in provider blocks within modules. No other configuration fields.

### TFSNFR105 — `nullable = false`

Set for collection types (sets, maps, lists) used in loops. Scalars may have semantic `null`.

### TFSNFR106 — Variable Descriptions

Every variable needs a `description` targeting module users. Use HEREDOC for objects:

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

### TFSNFR107 — Variable Types

`type` required for every variable. Avoid `any`. Use `bool` for flags, `string` for text, concrete `object` instead of `map(any)`.

### TFSNFR108 — Feature Toggles

New resources in minor/patch releases default OFF:

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
  tags   = merge({ "Name" = "${var.name}-rtb-public" }, var.tags)
}
```

New arguments: use provider schema default or `null`. New nested blocks: `dynamic` with default omitted.

### TFSNFR109 — Locals Ordering

Alphabetical, or logically grouped with each group alphabetical.

### TFSNFR110 — Locals Types

Use precise types: `3` not `"3"` for numbers.

### TFSNFR111 — `locals.tf` Content

Only `locals` blocks allowed.

### TFSNFR112 — No `nullable = true`

Never explicitly declare.

### TFSNFR113 — No `sensitive = false`

Never explicitly declare.

### TFSNFR114 — Variable Naming

Follow HashiCorp naming rules. Feature switches use positive statements: `xxx_enabled`/`enable_xxx`, not `xxx_disabled`.

### TFSNFR115 — Null Comparison for Creation Toggle

Wrap external references in `object` to avoid "known after apply" issues:

```hcl
variable "security_group" {
  type = object({ id = string })
  default = null
}

resource "aws_security_group" "this" {
  count = var.security_group == null ? 1 : 0
  # ...
}
```

### TFSNFR116 — Dynamic Blocks for Optional Nested Objects

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

Use `for_each = <condition> ? [<item>] : []` pattern.

### TFSNFR117 — Variable Ordering

1. Required variables (no default) — alphabetical, under `### Required ###` header
2. Optional variables (with default) — alphabetical, under `### Optional ###` header

### TFSNFR118 — Ordering Within Resource/Data Blocks

**Top meta-arguments (in order):** `provider` → `count` → `for_each`

**Then:** required arguments → optional arguments → required nested blocks → optional nested blocks (each group alphabetical, separated by blank lines)

**Bottom meta-arguments:** `depends_on` → `lifecycle` (`create_before_destroy` → `ignore_changes` → `prevent_destroy`)

`dynamic` blocks ranked by their block name. Code within nested blocks follows same rules.

### TFSNFR119 — Sensitive Outputs

Confidential data outputs must declare `sensitive = true`.

### TFSNFR120 — Output Ordering

All outputs alphabetically ordered.

### TFSNFR121 — Provider Declarations

In `required_providers`: `source` (namespace/name) + `version` (bounded). Providers alphabetical. Only include directly-used providers. Submodules have own `versions.tf`.

### TFSNFR122 — Resource Ordering in Files

Dependencies first, dependents after. Related resources close together.

### TFSNFR123 — `count` and `for_each` Usage

`count` for conditional (0 or 1). `for_each` with `map(xxx)`/`set(xxx)` — keys must be static literals.

### TFSNFR124 — Use `coalesce`/`try` for Defaults

```hcl
# Good
name = coalesce(var.cluster_parameter_group_name, var.name)
name = try(coalesce(var.cluster_parameter_group_name, var.name), var.name)

# Bad
name = var.cluster_parameter_group_name == null ? var.name : var.cluster_parameter_group_name
```

### TFSNFR125 — No Quotes in `ignore_changes`

```hcl
# Good
lifecycle { ignore_changes = [tags] }

# Bad
lifecycle { ignore_changes = ["tags"] }
```

### TFSNFR126 — Sensitive Variable Types

If `object` variable has sensitive field, mark entire variable `sensitive = true` OR extract sensitive field to separate variable.

### TFSNFR127 — Sensitive Variable Defaults

No defaults for sensitive vars. Exception: `default = null` or `default = []` to disable feature.

### TFSNFR128 — Lower Snake Case

All identifiers (`local`, `variable`, `output`, `resource`, `data`, `module`) use `lower_snake_case`.

### TFSNFR129 — Resource Named `this`

Use `this` when no more descriptive name exists or when module has single resource of that type.

### TFSNFR130 — No Resource Type Repetition in Name

```hcl
# Good
resource "aws_route_table" "public" {}

# Bad
resource "aws_route_table" "public_route_table" {}
```

### TFSNFR131 — Singular Nouns

Always use singular nouns for resource names.

### TFSNFR132 — Child Resource Naming

Default prefix with associated abbreviation. Allow override via variable. Primary resource `name` must be provided by consumer (no default).

---

## Category 2XX: Contribution/Support

### TFSNFR200 — GitHub Repo Permissions

`@McK-Internal/pattern-catalog-admin` must be admins.

### TFSNFR201 — Branch Protection on `main`

1. PR required: 1+ approval, code owner review
2. Status checks required, branches up to date
3. Conversation resolution required
4. Linear history required
5. No force pushes, no deletions, no bypass
6. Enforced for administrators

### TFSNFR202 — GitHub Teams Only

Permissions via teams, not individuals. Separate teams for owners vs contributors.

### TFSNFR203 — Issue Response Time

Respond within 3 business days.

### TFSNFR204 — Licensing

No license files. Internal use only within `McK-Internal`.

### TFSNFR205 — Versions Supported

Only latest released major version supported. Fix forward, don't backport.

### TFSNFR206 — GitHub Repo Topics

One `productid-XXXXX` topic per repo.

---

## Category 3XX: Documentation

### TFSNFR300 — Terraform Docs

`.terraform-docs.yml` in root:

```yaml
formatter: markdown table
sort:
  enabled: true
  by: required
```

### TFSNFR301 — Examples Directory

`examples/` with named deployment scenarios.

---

## Category 4XX: Inputs

### TFSNFR400 — Data Types

Use simple (`string`, `number`, `bool`) or complex types (`object`, `list`, `map`) with language-compliant schema.

### TFSNFR401 — No `enabled` or `module_depends_on`

Use native Terraform 0.13+ `count`/`for_each`/`depends_on` on modules. Boolean feature toggles are fine.

### TFSNFR402 — Variables Without Defaults

`name` (resource modules) and `region` must not have defaults.

---

## Category 5XX: Publishing

### TFSNFR500 — Cross-Module Collaboration

Resource/composite module teams should collaborate for consistency.

### TFSNFR501 — Module Registry

Publish to `FIRM-TF-MODULES` TFE organization.

---

## Category 6XX: Release

### TFSNFR600 — Breaking Changes

Avoid breaking changes. Deprecate instead of removing.

### TFSNFR601 — Semantic Versioning

Use release-please. Conventional Commits: `fix:` → PATCH, `feat:` → MINOR. Format: `vX.Y.Z`. Start at `v0.1.0`, promote to `v1.0.0` when stable.

---

## Category 7XX: Testing

### TFSNFR700 — Deployment Tests

E2E from `/examples`, no user input, auto-cleanup.

### TFSNFR701 — Idempotency Tests

Deploy twice, expect no changes on second apply.

### TFSNFR702 — Test Tooling

- `terraform validate/fmt/test`
- tflint (with provider-specific ruleset)
- Wiz CLI (firm scan policy)
- Terratest

### TFSNFR703 — Child Resource Testing

Test submodule deployments separately.

### TFSNFR704 — Unit Tests

Test logic/conditions without deploying resources.

### TFSNFR705 — Upgrade Tests

Ensure non-breaking on minor/patch releases.
