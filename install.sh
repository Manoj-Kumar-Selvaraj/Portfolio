#!/usr/bin/env bash
set -euxo pipefail
set -x

echo "[FORCE FLAGS]"
echo "FORCE=$FORCE"
echo "FORCE_NGINX=$FORCE_NGINX"
echo "FORCE_CONTROLLER=$FORCE_CONTROLLER"
echo "FORCE_AGENT=$FORCE_AGENT"
echo "===================="

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

unset FORCE FORCE_NGINX FORCE_CONTROLLER FORCE_AGENT

echo "Installation completed successfully"
