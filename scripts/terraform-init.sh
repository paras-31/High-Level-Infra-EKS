#!/usr/bin/env bash
set -euo pipefail

# Initialize Terraform with the correct S3 backend for the current account.
# Usage: scripts/terraform-init.sh <bootstrap|dev|staging|prod> [-reconfigure]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${ROOT}/account.config"

if [ -f "$CONFIG" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG"
fi

STACK="${1:?Usage: $0 <bootstrap|dev|staging|prod> [-reconfigure]}"
RECONFIGURE="${2:-}"

ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || true)}"
AWS_REGION="${AWS_REGION:-ap-south-1}"

if ! [[ "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "Set ACCOUNT_ID in account.config or configure AWS credentials." >&2
  exit 1
fi

BOOTSTRAP_BUCKET="tf-bootstrap-state-${ACCOUNT_ID}-${AWS_REGION}-an"
STATE_BUCKET="tf-state-${ACCOUNT_ID}-${AWS_REGION}"
KMS_ALIAS="alias/${STATE_BUCKET}"

INIT_ARGS=(-input=false)
if [ "$RECONFIGURE" = "-reconfigure" ]; then
  INIT_ARGS+=(-reconfigure)
fi

case "$STACK" in
  bootstrap)
    cd "${ROOT}/bootstrap"
    terraform init "${INIT_ARGS[@]}" \
      -backend-config="bucket=${BOOTSTRAP_BUCKET}" \
      -backend-config="key=bootstrap/terraform.tfstate" \
      -backend-config="region=${AWS_REGION}" \
      -backend-config="encrypt=true" \
      -backend-config="use_lockfile=true"
    echo "Bootstrap init complete. Plan/apply with:"
    echo "  terraform plan  -var=\"state_bucket_name=${STATE_BUCKET}\""
    echo "  terraform apply -var=\"state_bucket_name=${STATE_BUCKET}\""
    ;;
  dev|staging|prod)
    cd "${ROOT}/environments/${STACK}"
    terraform init "${INIT_ARGS[@]}" \
      -backend-config="bucket=${STATE_BUCKET}" \
      -backend-config="key=${STACK}/terraform.tfstate" \
      -backend-config="region=${AWS_REGION}" \
      -backend-config="dynamodb_table=terraform-state-lock" \
      -backend-config="encrypt=true" \
      -backend-config="kms_key_id=${KMS_ALIAS}"
    ;;
  *)
    echo "Unknown stack: $STACK" >&2
    exit 1
    ;;
esac

echo "Initialized ${STACK} for account ${ACCOUNT_ID} (${AWS_REGION})"
