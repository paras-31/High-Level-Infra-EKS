# Module: `vpc`

Production VPC networking for EKS, built **entirely from native `aws_*`
resources** — no external/community modules. You own every resource, so cluster
and network upgrades never fight a third-party module's opinions.

## Resources created

| Resource | Purpose |
|----------|---------|
| `aws_vpc` + `aws_internet_gateway` | The VPC and its internet door |
| `aws_subnet.public[*]` | Internet-facing LB subnets (tagged `kubernetes.io/role/elb`) |
| `aws_subnet.private[*]` | Worker node / pod subnets (tagged `internal-elb` + `karpenter.sh/discovery`) |
| `aws_subnet.intra[*]` | Optional isolated tier — no internet route |
| `aws_eip` + `aws_nat_gateway` | Egress for private subnets (single or one-per-AZ) |
| `aws_route_table.*` + routes + associations | Public→IGW, private→NAT, intra→local only |
| `aws_flow_log` + `aws_cloudwatch_log_group` + IAM role | VPC Flow Logs to an encrypted CloudWatch group |
| `aws_vpc_endpoint.s3` (Gateway) | Free S3 access without NAT |
| `aws_vpc_endpoint.interface[*]` + SG | ECR/EC2/STS/Logs/ELB/Autoscaling on the AWS backbone |

## Subnet discovery tags

EKS, the AWS Load Balancer Controller, and Karpenter discover subnets by tag.
These are applied automatically from `cluster_name`, so you never tag by hand.

## HA vs cost

- **prod** → `single_nat_gateway = false` → one NAT + one private route table per AZ (no cross-AZ blast radius).
- **dev/staging** → `single_nat_gateway = true` → one shared NAT to save cost.

## Inputs (highlights)

| Name | Description | Default |
|------|-------------|---------|
| `vpc_cidr` | VPC CIDR | `10.0.0.0/16` |
| `azs` | AZ list | required |
| `private_subnet_cidrs` / `public_subnet_cidrs` / `intra_subnet_cidrs` | Subnet CIDRs, one per AZ | — |
| `enable_nat_gateway` | Create NAT gateways | `true` |
| `single_nat_gateway` | One shared NAT | `false` |
| `interface_endpoints` | AWS services to expose via interface endpoints | ECR/EC2/STS/Logs/ELB/Autoscaling |
| `logs_kms_key_arn` | CMK for flow-log encryption | `null` |

## Outputs

`vpc_id`, `vpc_cidr_block`, `private_subnets`, `public_subnets`, `intra_subnets`,
`private_route_table_ids`, `nat_public_ips`.

## Upgrades / tweaks

Everything is a first-class resource. Want a 4th AZ? Add a CIDR to each list.
Want an extra interface endpoint? Append to `interface_endpoints`. Nothing is
hidden behind a module version bump.
