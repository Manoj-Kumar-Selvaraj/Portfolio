#!/usr/bin/env bash
set -euo pipefail

JOB_NAME="${1:-deploy-site}"
JENKINS_URL="http://localhost:8080"

CRED="$(./scripts/fetch_jenkins_token.sh)"
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
