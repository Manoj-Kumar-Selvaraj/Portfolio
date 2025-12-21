#!/usr/bin/env bash
set -Eeuo pipefail

echo "Triggering Jenkins job locally..."

JOB_NAME="${1:-deploy-site}"
JENKINS_URL="http://localhost:8080"

# Fetch credentials (expected format: user:token)
CRED="$(./scripts/fetch_jenkins_token.sh || true)"

# Handle bootstrap / first-run case
if [[ -z "${CRED}" || "${CRED}" == "PLACEHOLDER_REPLACE_AFTER_JENKINS_SETUP" ]]; then
  echo "⚠️ Jenkins API credentials not configured yet."
  echo ""
  echo "➡ Jenkins is running, but API token is not available."
  echo "➡ Complete Jenkins UI setup first:"
  echo "   1. Open ${JENKINS_URL}"
  echo "   2. Finish setup wizard"
  echo "   3. Create API token"
  echo "   4. Store token in Azure Key Vault"
  echo ""
  echo "ℹ️ Skipping job trigger for now (this is expected on first install)."
  exit 0
fi

# Validate credential format
if ! echo "${CRED}" | grep -q ':'; then
  echo "ERROR: Invalid credential format. Expected 'user:token'" >&2
  exit 1
fi

JUSER="$(echo "${CRED}" | cut -d: -f1)"
JTOKEN="$(echo "${CRED}" | cut -d: -f2-)"

# Fetch CSRF crumb
CRUMB_JSON="$(curl -sf -u "${JUSER}:${JTOKEN}" \
  "${JENKINS_URL}/crumbIssuer/api/json")"

CRUMB="$(echo "${CRUMB_JSON}" | jq -r .crumb)"
CRUMB_FIELD="$(echo "${CRUMB_JSON}" | jq -r .crumbRequestField)"

# Trigger job
curl -sf -X POST \
  -u "${JUSER}:${JTOKEN}" \
  -H "${CRUMB_FIELD}: ${CRUMB}" \
  "${JENKINS_URL}/job/${JOB_NAME}/build?delay=0"

echo "✅ Jenkins job '${JOB_NAME}' triggered successfully."
