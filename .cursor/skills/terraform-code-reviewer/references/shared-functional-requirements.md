# Terraform Shared Functional Requirements (TFSFR)

Source: [Confluence](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/771754368)

---

## Category 1XX: Composition

### TFSFR100 — Availability Zones

Modules that deploy **zone-redundant** resources should enable spanning across at least 3 availability zones by default.

Modules that deploy **zonal** resources should provide the ability to specify a zone but should NOT default to any particular zone.

Both cases must expose configuration via variables.

### TFSFR101 — Cross-Referencing Modules

Modules may cross-reference other modules to build composite modules. They **must** be referenced only from the Pattern Catalog `FIRM-TF-MODULES` registry:

```hcl
module "other-module" {
  source  = "terraform.mckinsey.cloud/FIRM-TF-MODULES/vpc/aws"
  version = ">=1, <2"
}
```

---

## Category 2XX: Outputs

### TFSFR200 — Minimum Required Outputs

Every module must output (if applicable):

```hcl
output "arn" {
  value       = resource.this.arn
  description = "The Amazon Resource Name (ARN) of the resource"
}
```

```hcl
output "ssm_info" {
  value       = try(aws_ssm_parameter.this[0].name, "")
  description = "Path to the AWS System Manager Parameter Store key with all information about provisioned resource"
}
```

---

## Category 3XX: Traceability

### TFSFR300 — Mandatory Tags

All AWS resources that support tags must include:

| Tag Key | Tag Value |
|---------|-----------|
| `tf_module_name` | `terraform.mckinsey.cloud/FIRM-TF-MODULES/<module-name>/<module-provider>` |
| `tf_module_version` | Semantic version of the module |

Implementation pattern:

```hcl
locals {
  tf_module_version = trim(file("${path.module}/version.txt"), " \n")
  tf_module_name    = "terraform.mckinsey.cloud/FIRM-TF-MODULES/vpc/aws"

  tags = merge(
    var.tags,
    {
      "tf_module_name"    = local.tf_module_name
      "tf_module_version" = local.tf_module_version
    }
  )
}
```

```hcl
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr_block

  tags = merge(
    { "Name" = var.name },
    local.tags
  )
}
```
