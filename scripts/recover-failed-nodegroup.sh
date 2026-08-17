#!/usr/bin/env bash
# Delete CREATE_FAILED EKS node groups so the next apply can recreate them.
# Usage: scripts/recover-failed-nodegroup.sh dev|staging|prod
set -euo pipefail

ENV="${1:?usage: recover-failed-nodegroup.sh dev|staging|prod}"
REGION="${AWS_REGION:-ap-south-1}"

case "$ENV" in
  dev)     CLUSTER=eks-dev-eks;     NG=eks-dev-eks-default ;;
  staging) CLUSTER=eks-staging-eks; NG=eks-staging-eks-default ;;
  prod)    CLUSTER=eks-prod-eks;    NG=eks-prod-eks-default ;;
  *) echo "Unknown environment: $ENV" >&2; exit 1 ;;
esac

if ! STATUS="$(aws eks describe-nodegroup \
  --cluster-name "$CLUSTER" \
  --nodegroup-name "$NG" \
  --region "$REGION" \
  --query 'nodegroup.status' \
  --output text 2>/dev/null)"; then
  echo "No node group $NG — nothing to recover."
  exit 0
fi

echo "Node group $NG status=$STATUS"

case "$STATUS" in
  CREATE_FAILED|DEGRADED)
    echo "Deleting unhealthy node group so Terraform can recreate it..."
    aws eks delete-nodegroup \
      --cluster-name "$CLUSTER" \
      --nodegroup-name "$NG" \
      --region "$REGION"
    aws eks wait nodegroup-deleted \
      --cluster-name "$CLUSTER" \
      --nodegroup-name "$NG" \
      --region "$REGION"
    echo "Deleted. Re-run apply."
    ;;
  DELETING)
    echo "Waiting for in-progress delete..."
    aws eks wait nodegroup-deleted \
      --cluster-name "$CLUSTER" \
      --nodegroup-name "$NG" \
      --region "$REGION"
    ;;
  ACTIVE|CREATING|UPDATING)
    echo "No recovery needed."
    ;;
  *)
    echo "Unknown status — not auto-deleting."
    ;;
esac
