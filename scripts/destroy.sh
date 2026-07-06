#!/usr/bin/env bash
###############################################################################
# destroy.sh — locally tear down everything Terraform created for one env.
#
# Mirrors .github/workflows/terraform-destroy.yml for use from a workstation
# (or a VPC-reachable host, since prod/staging endpoints are private).
#
# Usage:
#   ./scripts/destroy.sh <dev|staging|prod> [--with-bootstrap]
#
# It will:
#   1. require you to type the confirmation phrase
#   2. temporarily disable prevent_destroy (reverted on exit)
#   3. empty S3 buckets + ECR repos
#   4. terraform destroy
###############################################################################
set -euo pipefail

ENV="${1:-}"
WITH_BOOTSTRAP="${2:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
  echo "Usage: $0 <dev|staging|prod> [--with-bootstrap]" >&2
  exit 1
fi

echo "⚠️  This will PERMANENTLY DESTROY the '$ENV' environment."
read -r -p "Type 'destroy $ENV' to confirm: " reply
[ "$reply" = "destroy $ENV" ] || { echo "Confirmation mismatch. Aborting." >&2; exit 1; }

# Restore prevent_destroy on exit no matter what.
cleanup() { git -C "$REPO_ROOT" checkout -- '*.tf' 2>/dev/null || true; }
trap cleanup EXIT

disable_prevent_destroy() {
  find "$1" -name '*.tf' -type f -exec sed -i.bak 's/prevent_destroy *= *true/prevent_destroy = false/g' {} +
  find "$1" -name '*.tf.bak' -delete
}

empty_buckets() {
  local buckets
  buckets=$(terraform state pull | jq -r '.resources[]? | select(.type=="aws_s3_bucket") | .instances[].attributes.bucket' | sort -u)
  for b in $buckets; do
    echo "  emptying s3://$b"
    aws s3 rm "s3://$b" --recursive || true
    local v m
    v=$(aws s3api list-object-versions --bucket "$b" --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null || echo '{}')
    [ "$(echo "$v" | jq '.Objects | length // 0')" -gt 0 ] && aws s3api delete-objects --bucket "$b" --delete "$v" >/dev/null || true
    m=$(aws s3api list-object-versions --bucket "$b" --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json 2>/dev/null || echo '{}')
    [ "$(echo "$m" | jq '.Objects | length // 0')" -gt 0 ] && aws s3api delete-objects --bucket "$b" --delete "$m" >/dev/null || true
  done
}

empty_ecr() {
  local repos
  repos=$(terraform state pull | jq -r '.resources[]? | select(.type=="aws_ecr_repository") | .instances[].attributes.name' | sort -u)
  for r in $repos; do
    echo "  emptying ECR repo $r"
    local ids
    ids=$(aws ecr list-images --repository-name "$r" --query 'imageIds[*]' --output json 2>/dev/null || echo '[]')
    [ "$(echo "$ids" | jq 'length')" -gt 0 ] && aws ecr batch-delete-image --repository-name "$r" --image-ids "$ids" >/dev/null || true
  done
}

echo "==> Destroying environment: $ENV"
cd "$REPO_ROOT/environments/$ENV"
disable_prevent_destroy "$REPO_ROOT"
terraform init -input=false
empty_buckets
empty_ecr
terraform destroy -input=false -auto-approve
echo "==> Environment '$ENV' destroyed. (KMS keys enter a pending-deletion window.)"

if [ "$WITH_BOOTSTRAP" = "--with-bootstrap" ]; then
  echo "==> Destroying bootstrap (state backend)"
  cd "$REPO_ROOT/bootstrap"
  disable_prevent_destroy "$REPO_ROOT/bootstrap"
  terraform init -input=false
  empty_buckets
  terraform destroy -input=false -auto-approve
  echo "==> Bootstrap destroyed."
fi

echo "✅ Teardown complete."
