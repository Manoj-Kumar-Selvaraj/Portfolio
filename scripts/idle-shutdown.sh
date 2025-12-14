#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="jenkins-idle-shutdown.service"
SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}"
SCRIPT_PATH="/opt/jenkins-install/scripts/idle-shutdown.sh"

# >>> CONFIGURE THESE <<<
VM_RG="portfolio-rg"
VM_NAME="jenkins-vm"
IDLE_MINUTES="30"

echo "==> Stopping service if running..."
systemctl stop "${SERVICE_NAME}" || true

echo "==> Disabling service if enabled..."
systemctl disable "${SERVICE_NAME}" || true

echo "==> Removing existing service file..."
rm -f "${SERVICE_PATH}"

echo "==> Validating idle shutdown script..."
if [[ ! -f "${SCRIPT_PATH}" ]]; then
  echo "ERROR: ${SCRIPT_PATH} not found"
  exit 1
fi
chmod +x "${SCRIPT_PATH}"

echo "==> Recreating service file..."
cat <<EOF > "${SERVICE_PATH}"
[Unit]
Description=Jenkins Idle Shutdown Service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${SCRIPT_PATH}
Restart=always
RestartSec=15
User=root

Environment=VM_RG=${VM_RG}
Environment=VM_NAME=${VM_NAME}
Environment=IDLE_MINUTES=${IDLE_MINUTES}

[Install]
WantedBy=multi-user.target
EOF

echo "==> Reloading systemd daemon..."
systemctl daemon-reexec
systemctl daemon-reload

echo "==> Enabling and starting service..."
systemctl enable --now "${SERVICE_NAME}"

echo "==> Service recreated successfully."
systemctl status "${SERVICE_NAME}" --no-pager
