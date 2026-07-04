# Module: `security-baseline`

Account-level **governance & threat-detection** controls, all native `aws_*`
resources. Deploy this once per account (typically alongside `prod`, or in a
dedicated security account). Every service is individually toggleable.

## What it enables

| Service | Resource(s) | What it gives you |
|---------|-------------|-------------------|
| **CloudTrail** | `aws_cloudtrail` | Multi-region audit trail with log-file validation, KMS encryption, S3 + Lambda data events → immutable record of every API call. |
| **GuardDuty** | `aws_guardduty_detector` (+ feature) | Continuous threat detection incl. **EKS audit-log analysis** and **EKS runtime monitoring**, plus EBS malware scanning. |
| **Security Hub** | `aws_securityhub_account` + subscriptions | CSPM dashboard aggregating findings; **AWS Foundational Security Best Practices** + **CIS** benchmarks with auto-enabled controls. |
| **AWS Config** | recorder + delivery channel + 10 managed rules | Continuous config recording and compliance checks (public S3, unencrypted volumes, MFA, IMDSv2, **EKS secrets encrypted**, **EKS endpoint not public**, CloudTrail enabled). |

## Shared log bucket

A single hardened S3 bucket (`log_bucket_name`) receives CloudTrail and Config
data: versioned, KMS/AES256-encrypted, public-access-blocked, TLS-only bucket
policy, Glacier transition + expiry, and `prevent_destroy`.

## Usage

```hcl
module "security_baseline" {
  source           = "../../modules/security-baseline"
  name_prefix      = "eks-prod"
  log_bucket_name  = "acme-security-logs-123456789012"
  logs_kms_key_arn = module.kms.logs_key_arn
  tags             = var.tags
}
```

## Toggles

`enable_cloudtrail`, `enable_guardduty`, `enable_security_hub`, `enable_config`
— all default `true`. `organization_trail` for org-wide CloudTrail (management account only).

> These are **account/region singletons**. If another stack already enabled
> GuardDuty/Security Hub/Config in the account, set the matching toggle to `false`
> to avoid a conflict.
