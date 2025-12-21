#!/usr/bin/env bash
set -euxo pipefail
echo "Triggering Jenkins job locally..."

JOB_NAME="${1:-deploy-site}"
JENKINS_URL="http://localhost:8080"

# Fetch credentials (expected format: user:token)
if ! CRED="$(./scripts/fetch_jenkins_token.sh)"; then
  echo "ERROR: failed to fetch Jenkins credentials" >&2
  exit 1
fi

if [[ -z "${CRED}" ]]; then
  echo "ERROR: empty credentials received from fetch_jenkins_token.sh" >&2
  exit 1
fi

if ! echo "${CRED}" | grep -q ':'; then
  echo "ERROR: credential format invalid. Expected 'user:token' (got: ${CRED})" >&2
  exit 1
fi

JUSER="$(echo "${CRED}" | cut -d: -f1)"
JTOKEN="$(echo "${CRED}" | cut -d: -f2-)"

CRUMB_JSON="$(curl -s -u "${JUSER}:${JTOKEN}" "${JENKINS_URL}/crumbIssuer/api/json")"
CRUMB="$(echo "${CRUMB_JSON}" | jq -r .crumb)"
CRUMB_FIELD="$(echo "${CRUMB_JSON}" | jq -r .crumbRequestField)"

curl -X POST \
  -u "${JUSER}:${JTOKEN}" \
  -H "${CRUMB_FIELD}: ${CRUMB}" \
  "${JENKINS_URL}/job/${JOB_NAME}/build?delay=0"

echo "Triggered job: ${JOB_NAME}"

echo "✅ Jenkins job triggered successfully."
