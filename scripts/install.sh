#!/usr/bin/env bash
set -euo pipefail

echo "Starting Jenkins on-demand installation"

./scripts/docker.sh
./scripts/jenkins.sh
./scripts/systemd.sh

echo "Installation completed successfully"
