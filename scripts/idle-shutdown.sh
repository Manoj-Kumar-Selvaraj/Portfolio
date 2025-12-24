#!/usr/bin/env bash
set -Eeuo pipefail

# ----------------------------
# Locale & safety
# ----------------------------

export LC_ALL=C
export LANG=C

log() {
  echo "[idle-shutdown] $(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"
}

# ----------------------------
# Configuration
# ----------------------------
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
IDLE_MINUTES="${IDLE_MINUTES:-30}"
CHECK_INTERVAL=15

ACCESS_LOG="${ACCESS_LOG:-/var/log/nginx/jenkins.access.log}"

VM_RG="${VM_RG:?VM_RG is required}"
VM_NAME="${VM_NAME:?VM_NAME is required}"

IDLE_MS=$((IDLE_MINUTES * 60 * 1000))
DEALLOCATED_FLAG="/var/run/jenkins_vm_deallocated"

# ----------------------------
# Time helpers
# ----------------------------
now_ms() {
  printf '%s%03d' "$(date +%s)" "$((10#$(date +%N) / 1000000))"
}

# ----------------------------
# Signal handling
# ----------------------------
graceful_shutdown=0
trap 'graceful_shutdown=1; log "Received termination signal"' SIGINT SIGTERM

# ----------------------------
# Jenkins availability
# ----------------------------
wait_for_jenkins() {
  until curl -sf "${JENKINS_URL}/login" >/dev/null; do
    log "Waiting for Jenkins to become available..."
    sleep 10
  done
}

# ----------------------------
# Parse nginx access log safely
# ----------------------------
get_last_access_ms() {
  [[ -f "$ACCESS_LOG" ]] || { echo 0; return; }

  awk '
    match($0, /\[([0-9]{2})\/([A-Za-z]{3})\/([0-9]{4}):([0-9]{2}:[0-9]{2}:[0-9]{2})/, a) {
      # Convert nginx time → ISO 8601
      cmd = "date -u -d \"" a[3] "-" a[2] "-" a[1] " " a[4] "\" +%s"
      cmd | getline t
      close(cmd)
      if (t > max) max = t
    }
    END {
      if (max > 0) print max * 1000
      else print 0
    }
  ' "$ACCESS_LOG" 2>/dev/null
}

# ----------------------------
# Main
# ----------------------------
log "Starting Jenkins idle shutdown watcher"
log "Idle threshold: ${IDLE_MINUTES} minutes"
log "Access log: ${ACCESS_LOG}"

wait_for_jenkins
log "Jenkins is reachable"

start_ms="$(now_ms)"
# Grace period: Wait at least 10 minutes after service start before allowing shutdown
GRACE_PERIOD_MS=$((10 * 60 * 1000))
log "Grace period: 10 minutes from service start"

while true; do
  [[ "$graceful_shutdown" -eq 1 ]] && break

  access_ms="$(get_last_access_ms)"
  now="$(now_ms)"

  if [[ "$access_ms" -eq 0 ]]; then
    idle=$((now - start_ms))
    log "No portal access recorded yet; idle since start: $((idle / 1000))s"
    # Enforce idle shutdown only if no portal access for full IDLE_MINUTES
    if [[ "$idle" -ge "$IDLE_MS" && ! -f "$DEALLOCATED_FLAG" ]]; then
      log "Idle threshold reached (no portal access) → deallocating VM ${VM_NAME}"
      az login --identity >/dev/null 2>&1 || true
      az vm deallocate \
        --resource-group "$VM_RG" \
        --name "$VM_NAME" \
        --no-wait
      touch "$DEALLOCATED_FLAG"
      log "Deallocation triggered (one-time)"
    fi
  else
    idle=$((now - access_ms))
    log "Idle since last portal access: $((idle / 1000))s"
    # Enforce idle shutdown only if idle since last access for full IDLE_MINUTES
    if [[ "$idle" -ge "$IDLE_MS" && ! -f "$DEALLOCATED_FLAG" ]]; then
      log "Idle threshold reached (since last portal access) → deallocating VM ${VM_NAME}"
      az login --identity >/dev/null 2>&1 || true
      az vm deallocate \
        --resource-group "$VM_RG" \
        --name "$VM_NAME" \
        --no-wait
      touch "$DEALLOCATED_FLAG"
      log "Deallocation triggered (one-time)"
    fi
  fi

  sleep "$CHECK_INTERVAL"
done

log "Idle shutdown watcher exiting"
