#!/usr/bin/env bash
# Import AWS resources left behind after a partial apply or state wipe.
# Usage: scripts/adopt-orphans.sh dev|staging|prod
set -euo pipefail

ENV="${1:?usage: adopt-orphans.sh dev|staging|prod}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}/environments/${ENV}"

case "$ENV" in
  dev)     CLUSTER=eks-dev-eks;     VPC_PREFIX=eks-dev ;;
  staging) CLUSTER=eks-staging-eks; VPC_PREFIX=eks-staging ;;
  prod)    CLUSTER=eks-prod-eks;    VPC_PREFIX=eks-prod ;;
  *) echo "Unknown environment: $ENV" >&2; exit 1 ;;
esac

REGION="${AWS_REGION:-ap-south-1}"
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"

terraform init -input=false

import_if_missing() {
  local addr="$1" id="$2"
  shift 2

  if [[ -z "$id" || "$id" == "None" || "$id" == "null" ]]; then
    echo "Skip import — no AWS id for $addr"
    return 0
  fi
  if terraform state show "$addr" >/dev/null 2>&1; then
    echo "Already in state: $addr"
    return 0
  fi
  if [[ $# -gt 0 ]] && ! "$@"; then
    echo "Skip import — not in AWS (will be created by apply): $addr"
    return 0
  fi
  echo "Importing $addr <= $id"
  terraform import -input=false "$addr" "$id"
}

resolve_vpc_id() {
  local addr='module.platform.module.vpc.module.core.aws_vpc.this'
  if terraform state show "$addr" >/dev/null 2>&1; then
    terraform state show -no-color "$addr" | awk '/^[[:space:]]+id[[:space:]]+=/{print $3; exit}' | tr -d '"'
    return 0
  fi
  aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=${VPC_PREFIX}-vpc" \
    --query 'Vpcs[?State==`available`] | [0].VpcId' --output text
}

log_group_exists() {
  local name="$1"
  [[ "$(aws logs describe-log-groups --log-group-name-prefix "$name" \
    --query "logGroups[?logGroupName=='${name}'] | length(@)" --output text 2>/dev/null || echo 0)" == "1" ]]
}

VPC_ID="$(resolve_vpc_id)"
if [[ -z "$VPC_ID" || "$VPC_ID" == "None" ]]; then
  echo "Could not resolve VPC id for ${ENV}" >&2
  exit 1
fi
echo "Using VPC_ID=$VPC_ID"

# IAM — load balancer controller policy
LBC_POLICY_ARN="arn:aws:iam::${ACCOUNT}:policy/${CLUSTER}-aws-lb-controller"
import_if_missing \
  'module.platform.module.eks_addons.aws_iam_policy.lbc[0]' \
  "$LBC_POLICY_ARN" \
  aws iam get-policy --policy-arn "$LBC_POLICY_ARN"

# VPC flow logs (network-eks module)
FLOW_LOG_GROUP="/aws/vpc/${VPC_PREFIX}/flow-logs"
import_if_missing \
  'module.platform.module.network_eks.aws_cloudwatch_log_group.flow_log[0]' \
  "$FLOW_LOG_GROUP" \
  log_group_exists "$FLOW_LOG_GROUP"

FLOW_LOG_ID="$(aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=${VPC_ID}" \
  --query 'FlowLogs[0].FlowLogId' --output text 2>/dev/null || true)"
import_if_missing \
  'module.platform.module.network_eks.aws_flow_log.this[0]' \
  "$FLOW_LOG_ID"

# VPC endpoints — common after failed apply (DNS/route conflicts)
VPCE_SG="$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=${VPC_ID}" "Name=group-name,Values=${VPC_PREFIX}-vpce" \
  --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)"
import_if_missing \
  'module.platform.module.network_eks.aws_security_group.vpce[0]' \
  "$VPCE_SG" \
  aws ec2 describe-security-groups --group-ids "$VPCE_SG"

S3_VPCE="$(aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=${VPC_ID}" \
            "Name=service-name,Values=com.amazonaws.${REGION}.s3" \
            "Name=vpc-endpoint-type,Values=Gateway" \
  --query 'VpcEndpoints[0].VpcEndpointId' --output text 2>/dev/null || true)"
import_if_missing \
  'module.platform.module.network_eks.aws_vpc_endpoint.s3[0]' \
  "$S3_VPCE"

INTERFACE_ENDPOINTS=(ecr.api ecr.dkr ec2 sts logs elasticloadbalancing autoscaling eks)
for svc in "${INTERFACE_ENDPOINTS[@]}"; do
  VPCE_ID="$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=${VPC_ID}" \
              "Name=service-name,Values=com.amazonaws.${REGION}.${svc}" \
              "Name=vpc-endpoint-type,Values=Interface" \
    --query 'VpcEndpoints[0].VpcEndpointId' --output text 2>/dev/null || true)"
  import_if_missing \
    "module.platform.module.network_eks.aws_vpc_endpoint.interface[\"${svc}\"]" \
    "$VPCE_ID"
done

echo "Adopt orphans finished for ${ENV}. Re-run terraform apply."
