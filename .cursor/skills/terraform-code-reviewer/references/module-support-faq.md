# Module Support & FAQ

Sources:
- [Module Support](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/772965129)
- [FAQ](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/854786714)

---

## Support Levels

Issues should be raised on the module's GitHub repository.

| Level | Description | Response Time |
|-------|-------------|---------------|
| **Operational** | Dedicated team maintains modules | 1 business day |
| **Provisional** | Community-maintained | 3-5 business days |

Response times are for a reasonable response towards resolution, **not** for a fix within these durations.

---

## RACI Matrix (Shared Responsibility Model)

| Responsibility | Module Owner/Maintainers | Consumers | Pattern Catalog Product Team | Technical Oversight Committee |
|---|---|---|---|---|
| Platform McKinsey Integration | I | I | R, A | - |
| Product features (maturity rating, adoption) | I | C, I | R, A | C |
| Feature requests / usage issues | R, A | C, I | - | - |
| Bug fix / security patching | R, A | I | - | - |
| Remediate vulnerabilities of module instances | - | R, A | - | - |

---

## FAQ

### Releasing a Module

Each repo uses **release-please** for GitHub releases. Requirements:
1. Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
2. After merging to `main`, approve and merge the release-please PR

### Bringing Your Own Cloud Account for Testing

Yes — modify GitHub repository variables with your AWS account or Azure subscription details. The Terratest reusable workflow reads from these variables.

### Using Azure Verified Modules

Hybrid approach:
- Modules needing McKinsey adaptations → clone to Pattern Catalog
- Modules usable "as is" → consume from public registry

See [ADR documentation](https://github.com/McK-Internal/cdx-adr/tree/master/golden-paths/pattern-catalog/005-Azure-Verified-Modules).

### Pre-commit Failing on First/Major Release

Known issue: pre-commit fails when referencing TFE Registry for unpublished patterns. Workaround:

```bash
git commit --no-verify -m "Commit message"
```

### Reporting Bugs (Consumers)

Open issue in GitHub repo → "Issues" tab → "New issue" → "Bug report". PRs with fixes are welcome.

### Requesting Features (Consumers)

Open issue → "New issue" → "Feature request". PRs extending functionality are welcome.

### Version Update Notifications

Use [Dependabot](https://docs.github.com/en/code-security/dependabot/dependabot-version-updates/about-dependabot-version-updates), already configured for firm's private TFE Registry.

### Module Lifecycle

Refer to [module lifecycle documentation](https://mckinsey.atlassian.net/wiki/spaces/BCKD95/pages/771817812).
