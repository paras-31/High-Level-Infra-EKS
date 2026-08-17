#!/usr/bin/env bash
# Fix degraded EKS addons and failed node group before terraform apply.
# Usage: scripts/fix-eks-addons.sh dev|staging|prod
set -euo pipefail

ENV="${1:?usage: fix-eks-addons.sh dev|staging|prod}"
REGION="${AWS_REGION:-ap-south-1}"

case "$ENV" in
  dev)     CLUSTER=eks-dev-eks;     NG=eks-dev-eks-default ;;
  staging) CLUSTER=eks-staging-eks; NG=eks-staging-eks-default ;;
  prod)    CLUSTER=eks-prod-eks;    NG=eks-prod-eks-default ;;
  *) echo "Unknown environment: $ENV" >&2; exit 1 ;;
esac

K8S_VERSION="$(aws eks describe-cluster --name "$CLUSTER" --region "$REGION" \
  --query 'cluster.version' --output text 2>/dev/null || echo "")"

if [[ -z "$K8S_VERSION" || "$K8S_VERSION" == "None" ]]; then
  echo "Cluster $CLUSTER not found in $REGION — fresh install, skipping addon repair."
  exit 0
fi

echo "Cluster=$CLUSTER kubernetes=$K8S_VERSION"

# Delete failed node group so Terraform can recreate.
STATUS="$(aws eks describe-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NG" \
  --region "$REGION" --query 'nodegroup.status' --output text 2>/dev/null || echo "MISSING")"

if [[ "$STATUS" == "CREATE_FAILED" || "$STATUS" == "DEGRADED" ]]; then
  echo "Deleting node group $NG (status=$STATUS)..."
  aws eks delete-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NG" --region "$REGION"
  aws eks wait nodegroup-deleted --cluster-name "$CLUSTER" --nodegroup-name "$NG" --region "$REGION"
fi

update_addon() {
  local name="$1"
  local extra_args=("${@:2}")
  local version
  version="$(aws eks describe-addon-versions --addon-name "$name" \
    --kubernetes-version "$K8S_VERSION" --query 'addons[0].addonVersions[0].addonVersion' \
    --output text 2>/dev/null || true)"

  if [[ -z "$version" || "$version" == "None" ]]; then
    echo "Skip $name — no compatible version found"
    return 0
  fi

  if aws eks describe-addon --cluster-name "$CLUSTER" --addon-name "$name" --region "$REGION" >/dev/null 2>&1; then
    echo "Updating addon $name -> $version"
    aws eks update-addon \
      --cluster-name "$CLUSTER" \
      --addon-name "$name" \
      --addon-version "$version" \
      --resolve-conflicts OVERWRITE \
      --region "$REGION" \
      "${extra_args[@]}"
  else
    echo "Creating addon $name @ $version"
    aws eks create-addon \
      --cluster-name "$CLUSTER" \
      --addon-name "$name" \
      --addon-version "$version" \
      --resolve-conflicts OVERWRITE \
      --region "$REGION" \
      "${extra_args[@]}"
  fi
}

# Order matters — no IRSA on vpc-cni (node role has AmazonEKS_CNI_Policy).
update_addon "eks-pod-identity-agent"
update_addon "vpc-cni"
update_addon "kube-proxy"

echo "Waiting for core addons to become active..."
for name in eks-pod-identity-agent vpc-cni kube-proxy; do
  echo -n "  $name: "
  aws eks wait addon-active --cluster-name "$CLUSTER" --addon-name "$name" --region "$REGION" && echo "ACTIVE"
done

echo "Done. Run Terraform Apply next."
