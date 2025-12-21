#!/usr/bin/env bash
set -euxo pipefail
# Force C locale for predictable date parsing
export LC_ALL=C
echo "Starting Jenkins idle shutdown script"
# ----------------------------
# Configuration (from systemd)
# ----------------------------
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
IDLE_MINUTES="${IDLE_MINUTES:-30}"
CHECK_INTERVAL=15

# Allow configuration via /etc/default/jenkins-idle-shutdown (written by installer)
if [[ -f "/etc/default/jenkins-idle-shutdown" ]]; then
  # shellcheck source=/dev/null
  source /etc/default/jenkins-idle-shutdown
fi

VM_RG="${VM_RG:?VM_RG is required}"
VM_NAME="${VM_NAME:?VM_NAME is required}"

IDLE_MS=$((IDLE_MINUTES * 60 * 1000))
DEALLOCATED_FLAG="/var/run/jenkins_vm_deallocated"

log() {
  echo "[idle-shutdown] $(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"
}

now_ms() {
  # Return current time in milliseconds since epoch reliably
  # Use seconds and nanoseconds (GNU date) and convert to milliseconds
  sec=$(date +%s)
  nsec=$(date +%N)
  # Force base-10 interpretation of $nsec to avoid errors when it has leading zeros
  ms=$(((10#$nsec) / 1000000))
  printf '%s%03d' "$sec" "$ms"
}

# Trap signals for graceful shutdown
graceful_shutdown=0
on_term() {
  log "Received termination signal, exiting gracefully"
  graceful_shutdown=1
}
trap on_term SIGINT SIGTERM

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

# Path to Jenkins or proxy access log (can be overridden via env or /etc/default)
ACCESS_LOG="${ACCESS_LOG:-/var/log/jenkins/jenkins.log}"  # Change if using nginx/apache
# How many minutes to consider as 'recent access'
PORTAL_IDLE_MINUTES=15

while true; do
  if [[ "$graceful_shutdown" -eq 1 ]]; then
    log "Exiting main loop due to signal"
    break
  fi
  busy="$(curl -sf "${JENKINS_URL}/api/json" | jq -r '.busyExecutors // 0' || echo 0)"
  queue_len="$(curl -sf "${JENKINS_URL}/queue/api/json" | jq '.items | length' || echo 0)"

  log "busyExecutors=${busy}, queueLength=${queue_len}"

  # Check for recent portal access
  recent_access=0
  if [[ -f "${ACCESS_LOG}" ]]; then
    # Get timestamp for N minutes ago
    since_epoch=$(date --date="-${PORTAL_IDLE_MINUTES} minutes" +%s)
    # Count log lines with access in the last N minutes
    recent_access=$(awk -v since="$since_epoch" '{
      match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2})/, arr);
      if (arr[1] != "") {
        cmd = "date -d \"" arr[1] "\" +%s";
        cmd | getline t;
        close(cmd);
        if (t >= since) { print $0; }
      }
    }' "$ACCESS_LOG" | wc -l)
  fi

  log "Recent portal access in last ${PORTAL_IDLE_MINUTES} min: ${recent_access}"

  if [[ "${busy}" -eq 0 && "${queue_len}" -eq 0 && "${recent_access}" -eq 0 ]]; then
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

echo "Exiting Jenkins idle shutdown script"