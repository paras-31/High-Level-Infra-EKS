#!/usr/bin/env bash
# Clone/update High-level-VPC for local terraform init (same path CI uses).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROOT}/.terraform-modules/High-level-VPC"
REF="${1:-main}"
REPO="https://github.com/paras-31/High-level-VPC.git"

if [ -d "${DEST}/.git" ]; then
  echo "Updating ${DEST} (ref: ${REF})..."
  git -C "${DEST}" fetch origin "${REF}"
  git -C "${DEST}" checkout "${REF}"
  git -C "${DEST}" pull --ff-only origin "${REF}" 2>/dev/null || true
else
  echo "Cloning ${REPO} -> ${DEST} (ref: ${REF})..."
  mkdir -p "$(dirname "${DEST}")"
  git clone --branch "${REF}" --depth 1 "${REPO}" "${DEST}"
fi

test -f "${DEST}/modules/vpc/main.tf"
echo "VPC module ready at .terraform-modules/High-level-VPC"
