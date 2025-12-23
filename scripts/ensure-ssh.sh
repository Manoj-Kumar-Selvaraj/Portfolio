#!/usr/bin/env bash
set -Eeuo pipefail

# Ensure SSH service is running and enabled
if systemctl list-unit-files | grep -q '^ssh\.service'; then
  echo "Found ssh.service, starting and enabling..."
  sudo systemctl start ssh || true
  sudo systemctl enable ssh || true
  sudo systemctl status ssh --no-pager || true
elif systemctl list-unit-files | grep -q '^sshd\.service'; then
  echo "Found sshd.service, starting and enabling..."
  sudo systemctl start sshd || true
  sudo systemctl enable sshd || true
  sudo systemctl status sshd --no-pager || true
else
  echo "No SSH service found, installing openssh-server..."
  # Fix any interrupted dpkg operations first
  sudo dpkg --configure -a || true
  sudo apt-get update -y
  sudo apt-get install -y openssh-server
  sudo systemctl start ssh || sudo systemctl start sshd
  sudo systemctl enable ssh || sudo systemctl enable sshd
  echo "SSH service installed and started."
fi
