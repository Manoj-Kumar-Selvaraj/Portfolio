#!/usr/bin/env bash
set -Eeuo pipefail

echo "Installing Jenkins idle shutdown service..."

# Normalize per-component FORCE environment variables (accept true/1/yes)
# FORCE_IDLE_SHUTDOWN takes precedence; otherwise fall back to FORCE
RAW_FORCE_IDLE_SHUTDOWN="${FORCE_IDLE_SHUTDOWN:-}"
RAW_FORCE_GLOBAL="${FORCE:-0}"
if [ -z "$RAW_FORCE_IDLE_SHUTDOWN" ]; then
  RAW_FORCE_IDLE_SHUTDOWN="$RAW_FORCE_GLOBAL"
fi
case "$(tr '[:upper:]' '[:lower:]' <<<"$RAW_FORCE_IDLE_SHUTDOWN")" in
  1|true|yes) FORCE_IDLE_SHUTDOWN=1 ;;
  *) FORCE_IDLE_SHUTDOWN=0 ;;
esac
export FORCE_IDLE_SHUTDOWN

SERVICE_NAME="jenkins-idle-shutdown.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
WATCHER_SCRIPT="/opt/jenkins-install/scripts/idle-shutdown.sh"

# Check if service already exists and is active
if systemctl is-active --quiet "${SERVICE_NAME}" && [ "${FORCE_IDLE_SHUTDOWN:-0}" -eq 0 ]; then
  echo "Idle shutdown service already running. Skipping setup (use FORCE_IDLE_SHUTDOWN=1 to reinstall)."
  exit 0
fi

if [ "${FORCE_IDLE_SHUTDOWN:-0}" -eq 1 ]; then
  echo "FORCE_IDLE_SHUTDOWN set; forcing idle-shutdown service reinstallation"
fi

# -------- CONFIGURE HERE --------
VM_RG="portfolio-rg"
VM_NAME="jenkins-vm"
# Default is 30 minutes idle threshold
IDLE_MINUTES="30"
# Optional: path to access log (default to dedicated Jenkins nginx access log)
ACCESS_LOG="/var/log/nginx/jenkins.access.log"
# --------------------------------

echo "==> Stopping existing service..."
systemctl stop "${SERVICE_NAME}" || true
systemctl disable "${SERVICE_NAME}" || true

echo "==> Removing old unit file..."
rm -f "${SERVICE_PATH}"

echo "==> Validating watcher script..."
if [[ ! -f "${WATCHER_SCRIPT}" ]]; then
  echo "ERROR: ${WATCHER_SCRIPT} not found"
  exit 1
fi

# Guardrail: ensure watcher is NOT an installer
if grep -q "systemctl stop" "${WATCHER_SCRIPT}"; then
  echo "ERROR: ${WATCHER_SCRIPT} contains systemctl calls (wrong file)"
  exit 1
fi

chmod +x "${WATCHER_SCRIPT}"

[ -d /etc/default ] || sudo mkdir -p /etc/default
echo "==> Writing environment file /etc/default/jenkins-idle-shutdown"
cat <<EENV > /etc/default/jenkins-idle-shutdown
# Environment for Jenkins idle shutdown watcher
VM_RG=${VM_RG}
VM_NAME=${VM_NAME}
IDLE_MINUTES=${IDLE_MINUTES}
ACCESS_LOG=${ACCESS_LOG}
EENV

echo "==> Writing systemd unit..."
cat <<EOF > "${SERVICE_PATH}"
[Unit]
Description=Jenkins Idle Shutdown Watcher
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash -euxo pipefail ${WATCHER_SCRIPT}
EnvironmentFile=/etc/default/jenkins-idle-shutdown
Restart=always
RestartSec=15
User=root
WorkingDirectory=/opt/jenkins-install/scripts


[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd..."
systemctl daemon-reexec
systemctl daemon-reload

echo "==> Enabling and starting service..."
systemctl enable --now "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"
echo "==> Service installed successfully"
systemctl status "${SERVICE_NAME}" --no-pager

echo "✅ Jenkins idle shutdown service installation completed."