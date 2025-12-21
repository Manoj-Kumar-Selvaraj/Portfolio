#!/usr/bin/env bash
set -euo pipefail

echo "Starting Jenkins on-demand installation"

./scripts/setup-jenkins-agent.sh
./scripts/jenkins-controller.sh
./scripts/install-idle-shutdown-service.sh
./scripts/setup-nginx-jenkins.sh

echo "Installation completed successfully"
