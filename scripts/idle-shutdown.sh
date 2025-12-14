#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Configuration (from systemd)
# ----------------------------
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
IDLE_MINUTES="${IDLE_MINUTES:-30}"
CHECK_INTERVAL=30

VM_RG="${VM_RG:?VM_RG is required}"
VM_NAME="${VM_NAME:?VM_NAME is required}"

IDLE_MS=$((IDLE_MINUTES * 60 * 1000))
DEALLOCATED_FLAG="/var/run/jenkins_vm_deallocated"

log() {
  echo "[idle-shutdown] $(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"
}

now_ms() {
  date +%s%3N
}

wait_for_jenkins() {
  until curl -sf "${JENKINS_URL}/login" >/dev/null; do
    log "Waiting for Jenkins to become available..."
    sleep 10
  done
}

get_last_completed_ms() {
  curl -sf "${JENKINS_URL}/api/json?tree=jobs[name,lastCompletedBuild[timestamp]]" \
    | jq '[.jobs[].lastCompletedBuild.timestamp] | map(select(. != null)) | max // 0' \
    || echo 0
}

# ----------------------------
# Main loop
# ----------------------------
log "Starting Jenkins idle shutdown watcher"
wait_for_jenkins
log "Jenkins is reachable"

while true; do
  busy="$(curl -sf "${JENKINS_URL}/api/json" | jq -r '.busyExecutors // 0' || echo 0)"
  queue_len="$(curl -sf "${JENKINS_URL}/queue/api/json" | jq '.items | length' || echo 0)"

  log "busyExecutors=${busy}, queueLength=${queue_len}"

  if [[ "${busy}" -eq 0 && "${queue_len}" -eq 0 ]]; then
    last_ms="$(get_last_completed_ms)"
    now="$(now_ms)"

    if [[ "${last_ms}" -ne 0 ]]; then
      idle=$((now - last_ms))
      log "Idle for $((idle / 1000)) seconds"

      if [[ "${idle}" -ge "${IDLE_MS}" && ! -f "${DEALLOCATED_FLAG}" ]]; then
        log "Idle threshold reached, deallocating VM"
        az login --identity >/dev/null 2>&1 || true
        az vm deallocate -g "${VM_RG}" -n "${VM_NAME}" --no-wait
        touch "${DEALLOCATED_FLAG}"
      fi
    fi
  fi

  sleep "${CHECK_INTERVAL}"
done
