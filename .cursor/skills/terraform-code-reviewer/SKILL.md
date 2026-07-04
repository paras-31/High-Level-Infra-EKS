---
name: terraform-code-reviewer
description: Reviews Terraform code for quality, standards compliance, security, and best practices per HashiCorp style guide. Covers meta-arguments (count, for_each, lifecycle, depends_on), provider version pinning, linting (terraform fmt, TFLint), module structure, naming conventions, and security hardening. Optionally validates McKinsey Pattern Catalog standards (TFSFR, TFSNFR, TFCNFR). Applicable when reviewing Terraform configurations, pull requests with .tf files, or Terraform code review requests.
allowed-tools:
  - shell
  - Read
  - Grep
  - Glob
---

# Terraform Code Reviewer

Review Terraform code against HashiCorp official standards, provider documentation, and infrastructure best practices. Multi-provider: AWS, Azure, GCP, Kubernetes, Vault, PostgreSQL, Dynatrace, Cribl, Cloudflare.

## When to Use

- Reviewing Terraform configurations for quality and standards compliance
- Pull requests that add or modify `.tf` files
- Security audits of Infrastructure-as-Code
- Onboarding reviews to enforce team conventions on Terraform modules

## When Not to Use

- **Not a replacement for `terraform validate` or `tflint`** — this skill recommends running those tools but focuses on higher-level quality, security, and standards compliance that linters don't catch
- **Not for non-Terraform IaC** — Pulumi, CloudFormation, Ansible, and other IaC tools have different conventions
- **Not for live infrastructure state** — this is a static `.tf` file review; it does not inspect running resources or Terraform state files

## Review Workflow

```
Review Progress:
- [ ] 1. Code formatting & linting
- [ ] 2. File organization & naming
- [ ] 3. Resource & variable naming conventions
- [ ] 4. Version pinning (Terraform, providers, modules)
- [ ] 5. Meta-arguments usage
- [ ] 6. Module structure & composition
- [ ] 7. Security hardening
- [ ] 8. Summary & recommendations
- [ ] 9. Pattern Catalog compliance (optional — only for FIRM-TF-MODULES)
```

## Important: Verify Before Flagging

**NEVER flag a missing file without first confirming it does not exist.** Always list or read the directory before reporting a file absent.

**NEVER flag variable parameter ordering when `description` appears before `type` (or vice versa).** Both orderings are valid. Only flag ordering issues for parameters that come after type/description (e.g. `default` appearing before `type`).

## Severity Levels

- **CRITICAL**: Must fix — security risk, state corruption risk, or will cause runtime failure
- **WARNING**: Should fix — violates HashiCorp style guide or creates maintenance burden
- **INFO**: Nice to have — minor improvement or stylistic preference

---

## 1. Code Formatting & Linting

### terraform fmt

All `.tf` files must pass `terraform fmt -check -recursive -diff`.

Key rules: 2-space indentation, align `=` signs, arguments before nested blocks (separated by blank line), meta-arguments first, lifecycle block last, one blank line between top-level blocks, prefer `#` for comments.

### TFLint

Run `tflint --init && tflint --recursive`. Flag: deprecated attributes, invalid instance types, missing required tags.

For detailed formatting rules, see [reference.md](reference.md).

---

## 2. File Organization

| File | Contents |
|------|----------|
| `versions.tf` or `terraform.tf` | `terraform` block with `required_version` and `required_providers` |
| `providers.tf` | All `provider` blocks and configuration |
| `backend.tf` | Backend configuration (optional — not needed for reusable modules) |
| `variables.tf` | All variable blocks (alphabetical) |
| `outputs.tf` | All output blocks (alphabetical) |
| `main.tf` | Primary resources and data sources |
| `locals.tf` | Local values (optional — only when referenced across files) |
| `data.tf` | Data sources (optional — acceptable to separate from `main.tf`) |

For larger codebases, split resources into logical files (`network.tf`, `compute.tf`, `storage.tf`, etc.). Verify it is immediately clear where to find any resource.

---

## 3. Naming Conventions

### Resources & data sources
- Use descriptive nouns, underscore-separated: `"web_api"`, `"primary_db"`
- Never include the resource type in the name (address already includes it)
- Wrap type and name in double quotes
- **Bad**: `resource aws_instance webAPI-aws-instance {...}`
- **Good**: `resource "aws_instance" "web_api" {...}`

### Variables & outputs
- Descriptive nouns, underscore-separated
- Every variable must have `type` and `description`
- Every output must have `description`
- Optional variables must have a sensible `default`
- Sensitive variables: set `sensitive = true`

### Variable parameter order
`type` and `description` are interchangeable — **do NOT flag or warn** either ordering. The remaining parameters must follow: `default` → `sensitive` → `validation`.

### Output parameter order
1. `description` → 2. `value` → 3. `sensitive`

---

## 4. Version Pinning

### Terraform version
Require minimum version with `>=` in root modules:

```hcl
terraform {
  required_version = ">= 1.5"
}
```

### Provider versions — use pessimistic constraint (`~>`)

Root modules pin to minor version:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.34"
    }
  }
}
```

**Reusable modules**: use `>=` (minimum only) or `>= X, < Y` (range constraint) — both are acceptable.

**Example modules**: use `>= X, < Y` range constraints (e.g. `>= 1, < 2`).

### Module versions
Pin registry modules with `~>` to minor version:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"
}
```

For full version constraint syntax and all supported providers, see [reference.md](reference.md).

---

## 5. Meta-Arguments

### Argument ordering within resource blocks
1. `count` or `for_each` (meta-argument — first, with blank line after)
2. Resource-specific non-block arguments
3. Resource-specific block arguments
4. `lifecycle` block (last block, with blank line before)
5. `depends_on` (last argument)

### count vs for_each
- **`for_each`**: preferred when instances need distinct values derived from keys/maps
- **`count`**: only for nearly identical instances or conditional creation (`count = var.enabled ? 1 : 0`)
- Never use both in the same block
- `for_each` keys must be known before apply — no computed values

### depends_on
- Use only as last resort for hidden dependencies Terraform cannot infer
- Prefer expression references to imply dependencies
- Always add a comment explaining why `depends_on` is needed

### lifecycle
- `create_before_destroy` — for zero-downtime replacements; propagates to dependencies
- `prevent_destroy` — protect costly resources; use sparingly
- `ignore_changes` — specify attributes explicitly, avoid `all` unless justified
- `replace_triggered_by` — reference managed resources only
- `precondition` / `postcondition` — validate assumptions; include clear `error_message`

### Dynamic blocks

Use `dynamic` blocks for generating repeated nested blocks from collections. Use only when count varies; name iterator explicitly if different from block label; avoid nesting > 2 levels; `for_each` must be known before apply; reference iterator name not `each`.

### provider meta-argument
- Only needed with aliased providers; omit when using the default

For detailed rules on `for` expressions, conditional expressions, boolean helpers, and regex validation, see [reference.md](reference.md) and [references/validation-helpers.md](references/validation-helpers.md).

---

## 6. Module Structure

### Standard module layout
```
modules/<module-name>/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── README.md
```

### Review checklist for modules
- Module groups logically related resources
- Variables expose only what changes between deployments (avoid over-parameterization)
- Outputs expose values needed by callers
- Module does not contain `provider` blocks (passed by caller)
- Module declares its own `required_providers` with minimum version (`>=`)
- Local child modules live in `./modules/<name>/`
- Registry-published modules follow `terraform-<PROVIDER>-<NAME>` naming

---

## 7. Security Hardening

### Encryption
- Verify storage resources enable encryption at rest (S3 SSE, Azure Storage encryption, GCS CMEK)
- Verify encryption in transit (TLS/HTTPS) for load balancers, API gateways, databases

### IAM & least privilege
- No full wildcard actions (`"Action": "*"` or `"Action": "service:*"`) in IAM policies
- Prefix wildcards are acceptable (`kms:Get*`, `s3:List*`, `logs:Create*`)
- No wildcard resources (`"Resource": "*"`) unless unavoidable — add justifying comment
- Verify `assume_role_policy` is scoped to expected principals

### Network security
- Security groups: no `0.0.0.0/0` ingress unless public-facing by design
- Verify CIDR blocks are appropriately scoped
- Database resources should not have `publicly_accessible = true`

### Secrets
- No hardcoded secrets, passwords, or keys in `.tf` files
- Use `sensitive = true` on sensitive variables and outputs
- Reference secrets from Vault, AWS Secrets Manager, or environment variables
- State contains secrets in plaintext — verify remote backend with encryption

### Tagging standards
All taggable resources should include these tags for traceability and cost attribution:

| Tag | Required | Purpose |
|-----|----------|---------|
| `used_for` | Yes | Identifies the workload or purpose (e.g. `"data-pipeline"`, `"web-frontend"`) |
| `product_id` | Yes | Maps resource to a product/cost center for billing and ownership |

Use a `default_tags` block (AWS) or equivalent provider mechanism to enforce tags globally. Pass tags via a `var.tags` map and merge with required defaults.

```hcl
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  tags = merge(var.tags, {
    "used_for"   = var.used_for
    "product_id" = var.product_id
  })
}
```

For provider-specific security checks, see [references/provider-checks.md](references/provider-checks.md).

---

## 8. Review Output Format

Structure your review using tables. Every section outputs a table — no prose-only sections.

```markdown
## Terraform Code Review

### Summary

| Metric | Value |
|--------|-------|
| Files reviewed | 8 |
| Total findings | 12 |
| Critical | 2 |
| Warning | 6 |
| Info | 4 |
| Overall verdict | NEEDS FIXES |

### Findings

| # | Severity | Category | File:Line | Issue | Suggested Fix |
|---|----------|----------|-----------|-------|---------------|
| 1 | CRITICAL | Security | main.tf:42 | Wildcard IAM action | Scope to specific actions |
| 2 | WARNING | Version | versions.tf:5 | No version constraint | Add `version = "~> 5.34"` |
| 3 | INFO | Naming | main.tf:15 | Name includes type | Rename to `"web"` |

### Recommendations

| Priority | Action | Impact |
|----------|--------|--------|
| 1 | Fix CRITICAL security findings | Blocks merge |
| 2 | Add version constraints | Prevents surprise upgrades |
```

For the full output template including version pinning, meta-argument, and security tables, see [reference.md](reference.md).

---

## 9. Pattern Catalog Standards (Optional)

> **This section is an add-on.** Apply it only when reviewing modules intended for the McKinsey Pattern Catalog (`FIRM-TF-MODULES` registry). Skip for general Terraform reviews.

If the module targets Pattern Catalog, verify these additional standards. For full details with code examples, see [references/pattern-catalog-review.md](references/pattern-catalog-review.md).

### Quick Compliance Checklist

| # | Check | Standard |
|---|-------|----------|
| 1 | `versions.tf` with bounded `required_version` (min AND max major) | TFSNFR100 |
| 2 | Provider versions bounded (e.g. `>=5.0, <6` or `~> 5.0`) | TFSNFR121 |
| 3 | No `provider` blocks in module — use `configuration_aliases` only | TFSNFR104 |
| 4 | Variables ordered: Required (alphabetical) → Optional (alphabetical) with section headers | TFSNFR117 |
| 5 | Every variable has `type` (no `any`) and `description` (HEREDOC for objects) | TFSNFR106/107 |
| 6 | `nullable = false` for collections in loops; never declare `nullable = true` or `sensitive = false` | TFSNFR105/112/113 |
| 7 | Feature toggles: new resources in minor/patch default OFF | TFSNFR108 |
| 8 | Mandatory tags: `tf_module_name`, `tf_deployment_id`, `tf_module_version` on all taggable resources; good-to-have: `used_for`, `product_id` | TFSFR300 |
| 9 | Required outputs: `arn` and `ssm_info` (if applicable) | TFSFR200 |
| 10 | Only reference modules from `FIRM-TF-MODULES` registry | TFSFR101 |
| 11 | Composite modules built from Pattern Catalog resource modules | TFCNFR100 |
| 12 | `.terraform-docs.yml` present; `examples/` directory exists | TFSNFR300/301 |
| 13 | Outputs alphabetical; confidential outputs `sensitive = true` | TFSNFR119/120 |
| 14 | Lower `snake_case`, singular nouns, `this` naming, no type repetition | TFSNFR128-131 |
| 15 | Deprecated vars in `variables_deprecated.tf`; deprecated outputs in `outputs_deprecated.tf` | TFSNFR102/103 |

### Pattern Catalog Output Table

When reviewing Pattern Catalog modules, add this table to your review output:

```markdown
### Pattern Catalog Compliance

| # | Standard | Check | Status |
|---|----------|-------|--------|
| 1 | TFSFR200 | Required outputs (`arn`, `ssm_info`) | PASS/FAIL |
| 2 | TFSFR300 | Mandatory tags | PASS/FAIL |
| 3 | TFSNFR104 | No provider blocks in module | PASS/FAIL |
| ... | ... | ... | ... |
```

---

## Additional Resources

- Detailed rules, version constraints, meta-argument examples, checklists, and anti-patterns: [reference.md](reference.md)
- Provider-specific checks (all 9 providers): [references/provider-checks.md](references/provider-checks.md)
- Conditional expressions, boolean helpers, regex validation: [references/validation-helpers.md](references/validation-helpers.md)
- Pattern Catalog review standards (TFSFR, TFSNFR, TFCNFR) with code examples: [references/pattern-catalog-review.md](references/pattern-catalog-review.md)
- Full TFSFR specifications: [references/shared-functional-requirements.md](references/shared-functional-requirements.md)
- Full TFSNFR specifications: [references/shared-non-functional-requirements.md](references/shared-non-functional-requirements.md)
- Composite module requirements (TFCNFR): [references/composite-module-requirements.md](references/composite-module-requirements.md)
- Module support & FAQ: [references/module-support-faq.md](references/module-support-faq.md)
- [HashiCorp Style Guide](https://developer.hashicorp.com/terraform/language/style)
- [HashiCorp Terraform Docs](https://developer.hashicorp.com/terraform/docs)
