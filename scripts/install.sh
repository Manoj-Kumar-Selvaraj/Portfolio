#!/usr/bin/env bash
set -euo pipefail

echo "Starting Jenkins on-demand installation"

./scripts/docker.sh
./scripts/jenkins.sh
./scripts/install-idle-shutdown-service.sh

echo "Installation completed successfully"
