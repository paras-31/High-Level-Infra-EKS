# Validation Helpers & Expression Patterns

Conditional expressions, boolean helpers, and regex validation patterns for Terraform. Referenced from [reference.md](../reference.md) and [SKILL.md](../SKILL.md).

---

## Conditional (Ternary) Expressions

```hcl
locals {
  name = var.custom_name != "" ? var.custom_name : "default"
}

# Type-safe — explicit conversion when types differ
output "result" {
  value = var.use_number ? tostring(12) : "hello"
}
```

| # | Rule | Severity | Detail |
|---|------|----------|--------|
| 1 | Both branches same type | WARNING | Use `tostring()`, `tolist()`, `tonumber()` |
| 2 | No nested ternaries | WARNING | Extract to `locals` |
| 3 | `coalesce()` over null checks | INFO | `coalesce(var.x, "default")` is cleaner |
| 4 | `try()` for attribute access | INFO | `try(var.obj.key, "fallback")` |
| 5 | Conditional `count` for 0-or-1 | INFO | `count = var.enabled ? 1 : 0` |
| 6 | Readable conditions | INFO | Split `&&` / `||` across lines |

---

## Boolean Evaluation & Validation Helpers

```hcl
# alltrue — every element passes
validation {
  condition = alltrue([for v in var.instances : contains(["t2.micro", "t3.small"], v.type)])
  error_message = "All instance types must be t2.micro or t3.small."
}

# can + regex — pattern validation
validation {
  condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.name))
  error_message = "Must be 3-63 chars, lowercase, starting with a letter."
}

# can — attribute existence
precondition {
  condition     = can(data.terraform_remote_state.network.outputs.vpc_id)
  error_message = "Remote state must export vpc_id."
}

# try — safe access with fallback
locals { region = try(var.config.region, "ap-south-1") }

# contains — allowlist
validation {
  condition     = contains(["dev", "staging", "prod"], var.environment)
  error_message = "Must be dev, staging, or prod."
}
```

| # | Function | Severity | What to Flag |
|---|----------|----------|--------------|
| 1 | `alltrue()` / `anytrue()` | INFO | Prefer over `&&` chains for collections |
| 2 | `can()` | INFO | Existence/format checks only — not business logic |
| 3 | `try()` | INFO | Safe access with fallback — not error suppression |
| 4 | `contains()` | INFO | Keep list short or extract to `local` |
| 5 | `coalesce()` | INFO | Cleaner than ternary null checks |
| 6 | `regex()` in `can()` | WARNING | Always anchor `^...$` |
| 7 | `length()` for emptiness | INFO | `length(var.x) > 0` over `var.x != []` |

---

## Regex Validation

| Function | Returns | On no match | Use case |
|----------|---------|-------------|----------|
| `regex(pattern, string)` | First match | **Error** | Single validation inside `can()` |
| `regexall(pattern, string)` | List of all matches | `[]` | Count matches, extract values |

### Common Patterns

| What | Pattern | Example |
|------|---------|---------|
| AWS account ID | `^[0-9]{12}$` | `123456789012` |
| AWS ARN | `^arn:aws[a-zA-Z-]*:[a-z0-9-]+:[a-z0-9-]*:[0-9]{12}:.*$` | `arn:aws:s3:::bucket` |
| AWS region | `^[a-z]{2}-(north|south|east|west|central|northeast|southeast)-[0-9]$` | `ap-south-1` |
| Azure resource group | `^[a-zA-Z0-9._-]{1,90}$` | `my-rg-prod` |
| Azure subscription ID | `^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$` | UUID |
| GCP project ID | `^[a-z][a-z0-9-]{4,28}[a-z0-9]$` | `my-project-123` |
| CIDR (IPv4) | `^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$` | `10.0.0.0/16` |
| Semantic version | `^[0-9]+\\.[0-9]+\\.[0-9]+$` | `1.2.3` |
| DNS hostname | `^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$` | `api.example.com` |
| Lowercase kebab-case | `^[a-z][a-z0-9-]*$` | `my-resource` |
| Lowercase snake_case | `^[a-z][a-z0-9_]*$` | `my_variable` |

### Examples

```hcl
# AWS account ID
variable "aws_account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Must be exactly 12 digits."
  }
}

# CIDR — prefer cidrhost() over regex for semantic validation
variable "vpc_cidr" {
  type = string
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

# Multiple validations — stacked for clear error messages
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
  validation {
    condition     = can(regex("^[a-z]+$", var.environment))
    error_message = "Must be lowercase letters only."
  }
}

# regexall — count matches
variable "tags" {
  type = map(string)
  validation {
    condition     = length(regexall("^[A-Z][a-zA-Z]+$", lookup(var.tags, "Environment", ""))) > 0
    error_message = "Tag 'Environment' must be PascalCase."
  }
}
```

### Review Rules

| # | Rule | Severity | Detail |
|---|------|----------|--------|
| 1 | Anchor with `^` and `$` | WARNING | Unanchored → silent partial matches |
| 2 | Wrap `regex()` in `can()` in conditions | CRITICAL | Bare `regex()` errors on no match |
| 3 | `regexall()` for match count | INFO | Returns `[]` instead of erroring |
| 4 | `cidrhost()` over regex for CIDR | INFO | Validates semantics, not just format |
| 5 | `contains()` over regex for allowlists | INFO | Clearer, easier to maintain |
| 6 | Clear `error_message` with format | WARNING | Show users what valid input looks like |
| 7 | Escape `\` in HCL (`\\d`, `\\.`) | CRITICAL | `\d` is invalid — use `[0-9]` or `\\d` |
| 8 | POSIX over `\d`, `\w` | INFO | `[0-9]`, `[a-zA-Z0-9_]` — explicit in HCL |
| 9 | Stack `validation` blocks | INFO | Separate error messages per rule |
| 10 | No regex in `for_each`/`count` | CRITICAL | Must be known before apply |
