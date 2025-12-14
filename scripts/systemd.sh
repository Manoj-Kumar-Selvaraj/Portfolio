#!/usr/bin/env bash
set -euo pipefail

cat > /etc/systemd/system/jenkins-idle-shutdown.service <<EOF
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

systemctl daemon-reload
systemctl enable --now jenkins-idle-shutdown.service
