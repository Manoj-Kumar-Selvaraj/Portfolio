#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="jenkins-idle-shutdown.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
WATCHER_SCRIPT="/opt/jenkins-install/scripts/idle-shutdown.sh"

# -------- CONFIGURE HERE --------
VM_RG="portfolio-rg"
VM_NAME="jenkins-vm"
IDLE_MINUTES="30"
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

echo "==> Writing systemd unit..."
cat <<EOF > "${SERVICE_PATH}"
[Unit]
Description=Jenkins Idle Shutdown Watcher
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${WATCHER_SCRIPT}
Restart=always
RestartSec=15
User=root
WorkingDirectory=/opt/jenkins-install/scripts

Environment=VM_RG=${VM_RG}
Environment=VM_NAME=${VM_NAME}
Environment=IDLE_MINUTES=${IDLE_MINUTES}

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd..."
systemctl daemon-reexec
systemctl daemon-reload

echo "==> Enabling and starting service..."
systemctl enable --now "${SERVICE_NAME}"

echo "==> Service installed successfully"
systemctl status "${SERVICE_NAME}" --no-pager
