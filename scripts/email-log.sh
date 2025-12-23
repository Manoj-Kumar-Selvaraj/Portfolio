#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/jenkins-install.log"
EMAIL="ss.mano1998@gmail.com"

if ! command -v mail >/dev/null 2>&1; then
  echo "mail command not found; attempting to install mailutils..."
  echo "postfix postfix/main_mailer_type string 'No configuration'" | sudo debconf-set-selections
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mailutils
fi

if command -v mail >/dev/null 2>&1; then
  mail -s "Jenkins Install Log" "$EMAIL" < "$LOG_FILE"
else
  echo "mail command not found after attempted install; skipping email of log file."
fi
