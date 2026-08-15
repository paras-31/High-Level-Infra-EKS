# terraform-eks-infra

Production-grade **Amazon EKS** platform on AWS, built **entirely from native
`aws_*` Terraform resources** — no community/public modules. You own every
resource, so cluster upgrades and attribute changes are always in your hands.

Region: **ap-south-1** · State: **S3 + DynamoDB** · CI/CD: **GitHub Actions (OIDC)**
· Governance: **CloudTrail + GuardDuty + Security Hub + AWS Config**.

---

## Repository layout

```
terraform-eks-infra/
├── bootstrap/                 # ➊ S3 + DynamoDB remote-state backend (run once)
├── modules/                   # reusable in-house building blocks
│   ├── network-eks/           #   intra subnets, EKS tags, flow logs, VPC endpoints
│   ├── kms/                   #   CMKs for EKS secrets / EBS / logs
│   ├── eks/                   #   native cluster, OIDC/IRSA, node groups, addons, access entries
│   ├── eks-addons/            #   IRSA for LB controller, external-dns, Karpenter (+queue, node role)
│   ├── ecr/                   #   image repos: immutable, scan-on-push, lifecycle
│   ├── irsa/                  #   reusable "IAM role for a service account" primitive
│   ├── security-baseline/     #   CloudTrail, GuardDuty, Security Hub, Config
│   └── platform/              #   composition: wires the modules into one environment
├── environments/
│   ├── dev/                   # ➋ cost-optimized, single NAT, private API
│   ├── staging/               #   prod-like, private endpoint
│   └── prod/                  # ➌ HA, private, full governance
├── policies/                  # Checkov config + OPA/Conftest guardrails
└── .github/workflows/         # plan · apply · security-scan · drift-detection
```

Every folder has its own `README.md` explaining what it does and how to use it.

---

## Architecture at a glance

```
                 ┌──────────────────── AWS Account (ap-south-1) ────────────────────┐
                 │                                                                  │
   GitHub ──OIDC─┼─► IAM roles (plan / apply)                                       │
   Actions       │                                                                  │
                 │   VPC (per env)                                                  │
                 │   ├─ public subnets  ─► internet-facing LBs (via LB Controller)  │
                 │   ├─ private subnets ─► EKS nodes + pods ─┐                       │
                 │   │                                       ├─ Karpenter scales     │
                 │   ├─ intra subnets   ─► isolated tier     │  app nodes            │
                 │   ├─ NAT + flow logs + VPC endpoints       │                      │
                 │   │                                                              │
                 │   EKS control plane (PRIVATE endpoint)                            │
                 │   ├─ secrets encrypted (KMS CMK)                                  │
                 │   ├─ audit + control-plane logs ─► CloudWatch (KMS)               │
                 │   └─ OIDC provider ─► IRSA roles (per-workload least privilege)   │
                 │                                                                  │
                 │   ECR (immutable, scan-on-push)                                   │
                 │   Governance: CloudTrail · GuardDuty · Security Hub · Config      │
                 └──────────────────────────────────────────────────────────────────┘
```

---

## Security & governance controls (summary)

| Layer | Controls |
|-------|----------|
| **Network** | Private cluster endpoint, 3-tier subnets, per-AZ NAT (prod), VPC flow logs, VPC endpoints, least-privilege security groups |
| **Encryption** | Customer-managed KMS keys for EKS secrets, EBS volumes, and CloudWatch logs; encrypted state bucket + ECR |
| **Identity** | IRSA/OIDC for pods, EKS access entries (no `aws-auth` edits), optional IAM permissions boundary, no wildcard IAM (OPA-enforced) |
| **Compute** | IMDSv2 enforced, encrypted gp3 disks, SSM instead of SSH, Karpenter-managed scaling |
| **Images** | Immutable tags, scan-on-push, lifecycle expiry |
| **Detection** | GuardDuty (EKS audit + runtime), Security Hub (AWS FSBP + CIS), AWS Config rules, multi-region CloudTrail |
| **Pipeline** | OIDC (no static keys), Checkov + tfsec + Trivy, OPA/Conftest plan guardrails, scheduled drift detection, protected apply approvals |

---

## Quick start

```bash
# 0. Prereqs: terraform >= 1.6, awscli configured, an AWS account.

# 1. Create the remote-state backend (once per account)
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # set a globally-unique bucket name
terraform init && terraform apply

# 2. Point each environment's backend.tf at the bucket/table from step 1
#    (dev/staging/prod backend.tf — update `bucket` if you renamed it)

# 3. Stand up an environment (dev first)
cd ../environments/dev
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply

# 4. Connect kubectl
aws eks update-kubeconfig --region ap-south-1 --name eks-dev-eks

# 5. Install controllers via your Helm/CD flow using the output role ARNs
#    (load_balancer_controller_role_arn, external_dns_role_arn,
#     karpenter_controller_role_arn + instance profile + interruption queue)
```

For prod, also set `security_log_bucket_name` (governance) — see
[`environments/prod/README.md`](environments/prod/README.md).

---

## Cluster upgrades (why it's all in-house)

Because nothing is hidden behind a third-party module, upgrades are explicit:

1. Bump `cluster_version` in the target environment's `main.tf` (e.g. `1.31` → `1.32`).
2. `terraform plan` — review the control-plane change.
3. `terraform apply` (control plane upgrades first).
4. Node groups roll to the new version via their launch templates
   (`create_before_destroy`, `max_unavailable_percentage`), or let Karpenter
   drain/replace app nodes.
5. Managed add-ons (`coredns`, `kube-proxy`, `vpc-cni`, `ebs-csi`) are set to
   `most_recent`-compatible resolution; bump/verify after the control plane.

Any attribute — subnet count, instance types, log retention, endpoint policy,
IAM boundaries — is a first-class resource you can edit directly.

---

## CI/CD

See [`.github/workflows/README.md`](.github/workflows/README.md). PRs get a plan
comment + security scan; merges auto-apply dev; staging/prod apply behind
protected environment approvals; a cron job reports drift.

## Private VPC module (`High-level-VPC`)

The platform pulls VPC networking from the private repo
[`paras-31/High-level-VPC`](https://github.com/paras-31/High-level-VPC) (public + private
subnets, NAT, NACL). EKS-specific overlays (intra subnets, discovery tags, flow
logs, VPC endpoints) live in `modules/network-eks/`.

### GitHub Actions setup (required once)

1. Create a **fine-grained PAT** with **Contents: Read** on `paras-31/High-level-VPC`
   (or a classic PAT with the **`repo`** scope).
2. Add a **repository secret** (not environment-only):
   **`GH_MODULE_TOKEN`** = the PAT value  
   (`Settings → Secrets and variables → Actions → Repository secrets`)
3. Workflows call `.github/actions/setup-private-modules` before `terraform init`.

> **Important:** If `GH_MODULE_TOKEN` exists only under GitHub Environments
> (dev/staging/prod), jobs that do not set `environment:` (e.g. Security Scan on
> push) will get a 403. Either duplicate the secret at repository level, or we
> can wire `environment:` on those jobs (may trigger environment approval gates).

### Local `terraform init`

```bash
git config --global url."https://x-access-token:YOUR_PAT@github.com/".insteadOf "https://github.com/"
cd environments/dev && terraform init
```

## Secure private EKS

All environments use:

- **Private Kubernetes API** (`cluster_endpoint_public_access = false`)
- **NACLs** on public/private subnets
- **VPC endpoints** for AWS APIs (reduce NAT dependency)
- **VPC flow logs** to encrypted CloudWatch

Access `kubectl` via VPN, bastion, or SSM — not from the public internet.

## Conventions

- **State:** one key per env (`dev/`, `staging/`, `prod/`) in the shared bucket.
- **Naming:** `eks-<env>` prefix; cluster is `eks-<env>-eks`.
- **Tagging:** `Environment`, `ManagedBy`, `Project`, `CostCenter` on everything.
- **Secrets:** never commit `*.tfvars` (only `*.tfvars.example`); no AWS keys — OIDC only.
