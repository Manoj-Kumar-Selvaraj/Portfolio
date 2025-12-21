#!/usr/bin/env bash
set -euxo pipefail
# Force C locale for predictable date parsing
export LC_ALL=C
echo "Starting Jenkins idle shutdown script"
# ----------------------------
# Configuration (from systemd)
# ----------------------------
JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
# Default idle threshold (minutes) — portal access only
IDLE_MINUTES="${IDLE_MINUTES:-3}"
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

# Jenkins home (used to read file timestamps if running in container)
JENKINS_HOME="${JENKINS_HOME:-/var/jenkins_home}"

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


# Return last access time from ACCESS_LOG in milliseconds, or 0
get_last_access_ms() {
  if [[ ! -f "${ACCESS_LOG}" ]]; then
    echo 0
    return
  fi

  awk -v OFS="" '
    { if (match($0, /\[([0-9]{2}\/[^\/]+\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2})/, a)) {
        cmd = "date -d \"" a[1] "\" +%s";
        cmd | getline t; close(cmd);
        if (t > max) max = t
      }
    }
    END { if (max) print max * 1000; else print 0 }
  ' "${ACCESS_LOG}" || echo 0
}

# Return mtime of a key jenkins file (initialAdminPassword) in milliseconds, or 0
get_jenkins_file_ms() {
  local f="${JENKINS_HOME}/secrets/initialAdminPassword"
  if [[ -f "$f" ]]; then
    # stat -c %Y gives seconds since epoch
    sec=$(stat -c %Y "$f" 2>/dev/null || echo 0)
    if [[ "$sec" -ne 0 ]]; then
      echo $((sec * 1000))
      return
    fi
  fi
  echo 0
}


# ----------------------------
# Main loop (portal-access-only policy)
# ----------------------------
log "Starting Jenkins idle shutdown watcher (portal-access-only, ${IDLE_MINUTES} minute threshold)"
wait_for_jenkins
log "Jenkins is reachable"

# Path to Jenkins or proxy access log (can be overridden via env or /etc/default)
# Default to the dedicated Jenkins nginx access log (created by setup script)
ACCESS_LOG="${ACCESS_LOG:-/var/log/nginx/jenkins.access.log}"

# Track when the watcher started so we can deallocate if no access ever occurs
start_ms=$(now_ms)

while true; do
  if [[ "$graceful_shutdown" -eq 1 ]]; then
    log "Exiting main loop due to signal"
    break
  fi

  # Check most recent access time
  access_ms="$(get_last_access_ms)"
  now="$(now_ms)"

  if [[ "${access_ms}" -eq 0 ]]; then
    # No access recorded yet — consider time since start
    idle=$((now - start_ms))
    log "No portal access recorded yet; idle since start: $((idle / 1000)) seconds"
  else
    idle=$((now - access_ms))
    log "Idle since last portal access: $((idle / 1000)) seconds"
  fi

  if [[ "${idle}" -ge "${IDLE_MS}" && ! -f "${DEALLOCATED_FLAG}" ]]; then
    log "Portal idle threshold reached (${IDLE_MINUTES} minutes), deallocating VM"
    az login --identity >/dev/null 2>&1 || true
    az vm deallocate -g "${VM_RG}" -n "${VM_NAME}" --no-wait
    touch "${DEALLOCATED_FLAG}"
  fi

  sleep "${CHECK_INTERVAL}"
done

echo "Exiting Jenkins idle shutdown script"