#!/usr/bin/env bash
set -euo pipefail

echo "Starting Jenkins on-demand installation"


./scripts/docker.sh
./scripts/setup-docker-compose-harbour.sh
./scripts/jenkins.sh
./scripts/install-idle-shutdown-service.sh
./scripts/setup-nginx-jenkins.sh

echo "Installation completed successfully"
