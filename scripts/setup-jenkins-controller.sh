#!/usr/bin/env bash
set -euxo pipefail

echo "========================================"
echo " Setting up Jenkins Controller"
echo "========================================"

JENKINS_HOME="/var/jenkins_home"
JENKINS_CONTAINER="jenkins-controller"
JENKINS_IMAGE="jenkins/jenkins:lts"
JENKINS_PORT=8080

# Normalize FORCE environment variable (accept true/1/yes)
# Normalize per-component FORCE environment variables (accept true/1/yes)
# FORCE_CONTROLLER takes precedence; otherwise fall back to FORCE
RAW_FORCE_CONTROLLER="${FORCE_CONTROLLER:-}"
RAW_FORCE_GLOBAL="${FORCE:-0}"
if [ -z "$RAW_FORCE_CONTROLLER" ]; then
  RAW_FORCE_CONTROLLER="$RAW_FORCE_GLOBAL"
fi
case "$(tr '[:upper:]' '[:lower:]' <<<"$RAW_FORCE_CONTROLLER")" in
  1|true|yes) FORCE_CONTROLLER=1 ;;
  *) FORCE_CONTROLLER=0 ;;
esac
export FORCE_CONTROLLER

echo "Preparing Jenkins home..."
# If Jenkins controller container is already running and responding, skip installation (unless FORCE)
if docker ps --filter "name=$JENKINS_CONTAINER" --filter "status=running" --format '{{.Names}}' | grep -q "^${JENKINS_CONTAINER}$" 2>/dev/null; then
  echo "Detected running container ${JENKINS_CONTAINER}. Verifying responsiveness..."
  if [ "${FORCE_CONTROLLER:-0}" -eq 1 ]; then
    echo "FORCE_CONTROLLER set; forcing controller setup despite a running container"
  else
    if curl -sf "http://127.0.0.1:${JENKINS_PORT}/login" >/dev/null 2>&1; then
      echo "Jenkins HTTP endpoint responding. Skipping controller setup."
      exit 0
    fi
    echo "Running container found but Jenkins not yet ready; continuing setup to ensure configuration."
  fi
fi
sudo mkdir -p "$JENKINS_HOME"
sudo chown -R 1000:1000 "$JENKINS_HOME"
sudo chmod 755 "$JENKINS_HOME"

echo "Stopping old Jenkins container (if any)..."
docker stop "$JENKINS_CONTAINER" 2>/dev/null || true
docker rm "$JENKINS_CONTAINER" 2>/dev/null || true

echo "Pulling Jenkins LTS image..."
docker pull "$JENKINS_IMAGE"

echo "Starting Jenkins controller..."
docker run -d \
  --name "$JENKINS_CONTAINER" \
  --restart unless-stopped \
  -p "$JENKINS_PORT:8080" \
  -p 50000:50000 \
  -v "$JENKINS_HOME:/var/jenkins_home" \
  "$JENKINS_IMAGE"

echo ""
echo "✅ Jenkins controller started"
echo "➡ Access: http://<VM_PUBLIC_IP>:8080"
echo ""

echo "Waiting for Jenkins to generate initial admin password..."
# Wait up to 1 minute, printing logs on timeout or if container exits
WAIT_TIMEOUT=60
WAIT_INTERVAL=10
elapsed=0
while ! sudo test -f "$JENKINS_HOME/secrets/initialAdminPassword"; do
  # If the container exited or is not running, dump recent logs
  status=$(docker ps -a --filter "name=$JENKINS_CONTAINER" --format '{{.Status}}' || true)
  if echo "$status" | grep -Eqi 'Exited|Created|Dead'; then
    echo "Jenkins container status: $status"
    echo "--- Jenkins last 200 log lines ---"
    sudo docker logs --tail 200 "$JENKINS_CONTAINER" || true
  fi

  if [ "$elapsed" -ge "$WAIT_TIMEOUT" ]; then
    echo "ERROR: Timeout (${WAIT_TIMEOUT}s) waiting for initial admin password" >&2
    echo "--- Full Jenkins logs (last 500 lines) ---"
    sudo docker logs --tail 500 "$JENKINS_CONTAINER" || true
    exit 1
  fi

  sleep "$WAIT_INTERVAL"
  elapsed=$((elapsed + WAIT_INTERVAL))
done

echo "Initial admin password:"
sudo cat "$JENKINS_HOME/secrets/initialAdminPassword"

echo ""
echo "Please complete the Jenkins setup through the web interface."
