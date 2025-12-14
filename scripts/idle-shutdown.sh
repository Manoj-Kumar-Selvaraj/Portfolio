#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="http://localhost:8080"

IDLE_MS=$((IDLE_MINUTES * 60 * 1000))

now_ms() {
  date +%s%3N
}

get_last_completed_ms() {
  curl -s "${JENKINS_URL}/api/json?tree=jobs[name,lastCompletedBuild[timestamp]]" \
    | jq '[.jobs[].lastCompletedBuild.timestamp] | map(select(. != null)) | max // 0'
}

while true; do
  busy="$(curl -s "${JENKINS_URL}/api/json" | jq -r .busyExecutors)"
  queue_len="$(curl -s "${JENKINS_URL}/queue/api/json" | jq '.items | length')"

  if [[ "${busy}" -eq 0 && "${queue_len}" -eq 0 ]]; then
    last_ms="$(get_last_completed_ms)"
    now="$(now_ms)"

    if [[ "${last_ms}" -ne 0 ]]; then
      idle=$((now - last_ms))
      if [[ "${idle}" -ge "${IDLE_MS}" ]]; then
        az login --identity >/dev/null 2>&1 || true
        az vm deallocate -g "${VM_RG}" -n "${VM_NAME}" --no-wait
        exit 0
      fi
    fi
  fi

  sleep 30
done
