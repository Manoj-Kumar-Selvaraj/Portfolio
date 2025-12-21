#!/usr/bin/env bash
set -euo pipefail

# Fetch Jenkins token from Azure Key Vault and output only the secret value
# Require environment variables to be set; give clear errors otherwise
if [[ -z "${AZURE_KV_NAME:-}" ]]; then
  echo "ERROR: AZURE_KV_NAME is not set" >&2
  exit 1
fi
if [[ -z "${KV_SECRET_NAME:-}" ]]; then
  echo "ERROR: KV_SECRET_NAME is not set" >&2
  exit 1
fi

az login --identity >/dev/null 2>&1 || true

az keyvault secret show \
  --vault-name "${AZURE_KV_NAME}" \
  --name "${KV_SECRET_NAME}" \
  --query value -o tsv