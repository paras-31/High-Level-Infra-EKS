# Terraform Composite Module Non-Functional Requirements (TFCNFR)

Source: [Confluence](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/772735833)

---

## Category 1XX: Composition

### TFCNFR100 — Use Resource Modules to Build Composite Modules

A composite module **should** be built from Pattern Catalog resource modules to establish a standardized code base and improve maintainability.

A composite module **may** contain native resources ("vanilla" code) only when a valid reason exists:
- When using a resource module would hit limitations or reduce capabilities
- Time constraint without required resource modules available (must be updated when resource module becomes available)

A composite module **must not** contain references to non-Pattern Catalog modules.

Ideally, all required resource modules should be developed first, then leveraged by the composite module.

### TFCNFR101 — Use Other Composite Modules

A composite module **may** contain and be built using other Pattern Catalog composite modules.

A composite module **must not** reference non-Pattern Catalog modules.
