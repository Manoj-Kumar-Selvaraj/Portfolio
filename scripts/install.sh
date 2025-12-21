#!/usr/bin/env bash
set -euxo pipefail
set -x

echo "Starting Jenkins on-demand installation"
chmod +x ./scripts/*.sh
./scripts/setup-jenkins-agent.sh
./scripts/setup-jenkins-controller.sh
./scripts/install-idle-shutdown-service.sh
./scripts/setup-nginx-jenkins.sh
./scripts/az.sh
if ./scripts/fetch_jenkins_token.sh | grep -q ':'; then
  ./scripts/trigger_job_local.sh initial-setup
else
  echo "Jenkins credentials not ready. Skipping trigger."
fi
./scripts/install-idle-shutdown-service.sh

echo "Installation completed successfully"
