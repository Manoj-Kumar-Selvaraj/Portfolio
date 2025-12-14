#!/usr/bin/env bash
set -euo pipefail

az login --identity >/dev/null 2>&1 || true

az keyvault secret show \
  --vault-name "${AZURE_KV_NAME}" \
  --name "${KV_SECRET_NAME}" \
  --query value -o tsv
