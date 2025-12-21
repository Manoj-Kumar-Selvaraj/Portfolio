#!/usr/bin/env bash
set -euxo pipefail
set -x

echo "Starting Jenkins on-demand installation"
chmod +x ./scripts/*.sh
./scripts/setup-jenkins-agent.sh
./scripts/setup-jenkins-controller.sh
./scripts/install-idle-shutdown-service.sh
./scripts/setup-nginx-jenkins.sh

echo "Installation completed successfully"
