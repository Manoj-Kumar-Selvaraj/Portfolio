#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME=jenkins-idle-shutdown.service
SERVICE_PATH=/etc/systemd/system/${SERVICE_NAME}

echo "Stopping service if running..."
systemctl stop ${SERVICE_NAME} || true

echo "Disabling service if enabled..."
systemctl disable ${SERVICE_NAME} || true

echo "Removing existing service file..."
rm -f ${SERVICE_PATH}

echo "Recreating service file..."
cat <<EOF > ${SERVICE_PATH}
[Unit]
Description=Jenkins Idle Shutdown Service
After=docker.service network-online.target
Wants=network-online.target

[Service]
ExecStart=/opt/jenkins-on-demand/scripts/idle-shutdown.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
systemctl daemon-reexec
systemctl daemon-reload

echo "Enabling and starting service..."
systemctl enable --now ${SERVICE_NAME}

echo "Service recreated successfully."
systemctl status ${SERVICE_NAME} --no-pager
