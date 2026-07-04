# Terraform Code Review — Detailed Reference

## Version Constraint Syntax

| Operator | Meaning | Example |
|----------|---------|---------|
| `=` (or none) | Exact version | `= 5.34.0` |
| `!=` | Exclude version | `!= 5.30.0` |
| `>`, `>=`, `<`, `<=` | Comparison | `>= 1.5, < 2.0` |
| `~>` | Pessimistic — rightmost increments only | `~> 5.34` allows `5.34.x`, blocks `5.35.0`; `~> 5.0` allows `5.x`, blocks `6.0` |

```
~> 1.0.4   →  >= 1.0.4, < 1.1.0    (patch only)
~> 1.0     →  >= 1.0.0, < 2.0.0    (minor only)
```

| Component | Root Module | Reusable Module | Example Module |
|-----------|-------------|-----------------|----------------|
| `required_version` | `>= 1.5` | `>= 1.5` or `>= 1.5, < 2.0` | `>= 1, < 2` |
| Provider | `~> 5.34` (pin minor) | `>= 5.0` or `>= 5.0, < 6` | `>= 5, < 6` |
| Registry module | `~> 5.5` | `~> 5.5` | `~> 5.5` |

Pre-release versions (e.g. `1.2.0-beta`): Terraform does not match pre-release versions with `>`, `>=`, `<`, `<=`, or `~>` operators unless the constraint itself includes a pre-release segment. Use exact `=` (e.g. `= 1.2.0-beta`) or omit the operator to pin a specific pre-release. See [Version Constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints) for details.

---

## Code Formatting

```hcl
resource "aws_instance" "web" {
  # 1. Meta-argument FIRST, blank line after
  for_each = var.instances

  # 2. Non-block arguments (aligned =)
  ami           = each.value.ami
  instance_type = each.value.instance_type

  # 3. Block arguments
  root_block_device {
    volume_size = 50
    encrypted   = true
  }

  # 4. lifecycle block LAST (blank line before)
  lifecycle {
    create_before_destroy = true
  }

  # 5. depends_on LAST argument
  depends_on = [aws_iam_role_policy.web]
}
```

Prefer `#` for comments (`//` and `/* */` are valid HCL but `#` is the HashiCorp convention). 2-space indent. One blank line between top-level blocks.

---

## Meta-Arguments

### count

```hcl
resource "aws_instance" "server" {
  count         = 4
  ami           = "ami-abc123"
  instance_type = "t2.micro"
  tags          = { Name = "server-${count.index}" }
}
```

Conditional: `count = var.enabled ? 1 : 0`. Reference: `aws_instance.server[0]`, `aws_instance.server[*].id`.

### for_each

```hcl
resource "azurerm_resource_group" "rg" {
  for_each = tomap({ networking = "eastus", compute = "westus2" })
  name     = each.key
  location = each.value
}
```

With set: `for_each = toset(["alice", "bob"])`. Chaining: `for_each = aws_vpc.this` on a dependent resource. Reference: `azurerm_resource_group.rg["networking"]`.

### count vs for_each

| Scenario | Use |
|----------|-----|
| N identical resources | `count` |
| Conditional (0 or 1) | `count = var.x ? 1 : 0` |
| Distinct keys or configs | `for_each` |
| Iterating a list | `for_each = toset(var.list)` |

---

## for Expressions

```hcl
locals {
  upper_names  = [for s in var.names : upper(s)]               # tuple
  upper_map    = { for s in var.names : s => upper(s) }        # object
  vpc_ids      = { for k, v in aws_vpc.this : k => v.id }      # key + value
  admins       = { for n, u in var.users : n => u if u.is_admin } # filter
  by_role      = { for n, u in var.users : u.role => n... }    # grouping
}
```

| # | Rule | Severity | Detail |
|---|------|----------|--------|
| 1 | Bracket type matches intent | WARNING | `[ ]` → list, `{ }` → map |
| 2 | Map keys unique (or use `...`) | CRITICAL | Duplicate keys without `...` → runtime error |
| 3 | `if` clause for filtering | INFO | Prefer inline over separate step |
| 4 | No `for` for nested blocks | WARNING | Use `dynamic` instead |
| 5 | `toset()` for unordered results | INFO | Signals irrelevant order |
| 6 | Descriptive symbols | INFO | `name, user` not `k, v` when non-obvious |
| 7 | Nested `for` > 2 levels | WARNING | Extract into `locals` |
| 8 | Valid input type | CRITICAL | Must be list, set, tuple, map, or object |

---

## dynamic Blocks

```hcl
resource "aws_security_group" "web" {
  name = "web"

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

| # | Rule | Severity | Detail |
|---|------|----------|--------|
| 1 | Only when block count varies | INFO | Static blocks are clearer for fixed configs |
| 2 | Name iterator explicitly if differs from label | WARNING | `iterator = "rule"` avoids confusion |
| 3 | No nesting > 2 levels | WARNING | Refactor into child module |
| 4 | `for_each` known before apply | CRITICAL | Same constraint as resource-level |
| 5 | Reference iterator, not `each` | CRITICAL | `ingress.value.x`, not `each.value.x` |

---

## depends_on

```hcl
resource "aws_instance" "api" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # IAM role policy grants S3 access needed at boot — no attribute ref exists.
  depends_on = [aws_iam_role_policy.s3_access]
}
```

| Flag | Severity | Reason |
|------|----------|--------|
| Without explanatory comment | WARNING | Can't verify hidden dependency is still needed |
| Replaceable by expression reference | WARNING | Expression refs produce more precise plans |
| References entire module | WARNING | Overly broad — forces serial execution |

---

## lifecycle

```hcl
resource "aws_instance" "web" {
  # ...
  lifecycle {
    create_before_destroy = true                        # zero-downtime replacement
    prevent_destroy       = true                        # protect costly resources
    ignore_changes        = [tags, ami]                 # externally managed attrs
    replace_triggered_by  = [aws_ecs_service.main.id]   # managed resources only

    precondition {
      condition     = data.aws_ami.ubuntu.architecture == "x86_64"
      error_message = "AMI must be x86_64."
    }
    postcondition {
      condition     = self.public_dns != ""
      error_message = "Must have public DNS."
    }
  }
}
```

| Rule | Severity | Detail |
|------|----------|--------|
| `create_before_destroy` propagates to deps | WARNING | Verify resource supports concurrent instances |
| `prevent_destroy` — use sparingly | INFO | Does NOT protect if block removed from config |
| `ignore_changes` — list attrs explicitly | WARNING | `= all` requires justifying comment |
| `replace_triggered_by` — managed resources only | WARNING | Not local values or variables |
| `precondition`/`postcondition` — clear `error_message` | WARNING | Users must understand failures |

---

## provider (meta-argument)

```hcl
provider "aws" { region = "us-east-1" }              # default — no alias
provider "aws" { alias = "west"; region = "us-west-2" } # alias first

resource "aws_instance" "west" {
  provider      = aws.west
  ami           = var.ami_id
  instance_type = "t3.micro"
}
```

| # | Rule | Severity |
|---|------|----------|
| 1 | Default provider has no `alias` | WARNING |
| 2 | Default defined first in `providers.tf` | INFO |
| 3 | `alias` is first param in non-default | INFO |
| 4 | All providers in same file | WARNING |

---

## Module Review Checklist

> For Pattern Catalog module review, see [SKILL.md](SKILL.md) Section 9 and [references/pattern-catalog-review.md](references/pattern-catalog-review.md).

| # | Check | Severity |
|---|-------|----------|
| 1 | Declares `required_providers` with bounded version | WARNING |
| 2 | Does NOT contain `provider` blocks (only `configuration_aliases`) | CRITICAL |
| 3 | Variables have `type` and `description` | WARNING |
| 4 | Outputs have `description` | WARNING |
| 5 | Only exposes variables that change between deployments | INFO |
| 6 | Standard layout (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`) | INFO |
| 7 | Local modules in `./modules/<name>/` | INFO |
| 8 | Registry name follows `terraform-<PROVIDER>-<NAME>` | WARNING |
| 9 | `README.md` documents inputs/outputs | INFO |

---

## Security Review Checklist

| # | Check | Severity |
|---|-------|----------|
| 1 | No hardcoded secrets/passwords/keys in `.tf` files | CRITICAL |
| 2 | Sensitive variables use `sensitive = true` | CRITICAL |
| 3 | No full IAM wildcard actions (`"*"` or `"service:*"`) — prefix wildcards like `kms:Get*` are OK | CRITICAL |
| 4 | No wildcard resources (`"Resource": "*"`) without justification | WARNING |
| 5 | Storage encryption at rest (S3 SSE, Azure encryption, GCS) | CRITICAL |
| 6 | No `publicly_accessible = true` on databases | CRITICAL |
| 7 | No `0.0.0.0/0` ingress without justification | WARNING |
| 8 | Remote backend with encryption | WARNING |
| 9 | All taggable resources include `used_for` and `product_id` | WARNING |

---

## Common Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| `count` when instances need distinct values | `for_each` with map |
| `depends_on` for inferable dependencies | Expression references |
| `ignore_changes = all` without comment | Specify attributes or justify |
| Provider without version constraint | `~>` (root) or `>= X, < Y` (module) |
| Hardcoded AMI/account IDs | Data sources or variables |
| Inline IAM policy JSON | `aws_iam_policy_document` data source |
| Monolithic `main.tf` (500+ lines) | Split into logical files |
| Variables without `type`/`description` | Add both |
| Outputs without `description` | Add description |
| Missing `used_for` or `product_id` tags | Add to `default_tags` (AWS) or `var.tags` merge |
| Provider block in reusable module | Remove; use `configuration_aliases` |

> For Pattern Catalog-specific anti-patterns, see [references/pattern-catalog-review.md](references/pattern-catalog-review.md).

---

## Additional Reference Files

- Conditional expressions, boolean helpers, regex validation: [references/validation-helpers.md](references/validation-helpers.md)
- Provider-specific checks (all 9 providers): [references/provider-checks.md](references/provider-checks.md)
- Pattern Catalog review standards (TFSFR, TFSNFR, TFCNFR): [references/pattern-catalog-review.md](references/pattern-catalog-review.md)
- Full TFSFR specifications: [references/shared-functional-requirements.md](references/shared-functional-requirements.md)
- Full TFSNFR specifications: [references/shared-non-functional-requirements.md](references/shared-non-functional-requirements.md)
- Composite module requirements: [references/composite-module-requirements.md](references/composite-module-requirements.md)
- Module support & FAQ: [references/module-support-faq.md](references/module-support-faq.md)
