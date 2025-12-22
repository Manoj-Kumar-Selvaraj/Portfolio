#!/usr/bin/env bash
set -Eeuo pipefail

# Ensure SSH service is running and enabled
if systemctl list-unit-files | grep -q '^ssh\.service'; then
  sudo systemctl start ssh
  sudo systemctl enable ssh
  sudo systemctl status ssh
elif systemctl list-unit-files | grep -q '^sshd\.service'; then
  sudo systemctl start sshd
  sudo systemctl enable sshd
  sudo systemctl status sshd
else
  echo "No SSH service found."
  exit 1
fi
