#!/usr/bin/env bash
set -euo pipefail
set -x

REPO_DIR="/opt/jenkins-install"

echo "[FORCE FLAGS]"
echo "FORCE=${FORCE:-0}"
echo "FORCE_NGINX=${FORCE_NGINX:-0}"
echo "FORCE_CONTROLLER=${FORCE_CONTROLLER:-0}"
echo "FORCE_AGENT=${FORCE_AGENT:-0}"
echo "===================="

# -------------------------------------------------
# Ensure repo exists (Run Command safe)
# -------------------------------------------------
if [[ ! -d "$REPO_DIR/scripts" ]]; then
  echo "Repo not found. Cloning..."
  rm -rf "$REPO_DIR"
  git clone -b Azure-Scripts \
    https://github.com/Manoj-Kumar-Selvaraj/Portfolio.git \
    "$REPO_DIR"
fi

cd "$REPO_DIR"

chmod +x scripts/*.sh

echo "Starting Jenkins on-demand installation"

./scripts/setup-jenkins-agent.sh        > /var/log/jenkins-agent.log 2>&1
./scripts/setup-jenkins-controller.sh   > /var/log/jenkins-controller.log 2>&1
./scripts/install-idle-shutdown-service.sh > /var/log/jenkins-idle.log 2>&1
./scripts/setup-nginx-jenkins.sh        > /var/log/nginx-jenkins.log 2>&1
./scripts/az.sh                         > /var/log/azure-setup.log 2>&1


if ./scripts/fetch_jenkins_token.sh | grep -q ':'; then
  ./scripts/trigger_job_local.sh initial-setup
else
  echo "Jenkins credentials not ready. Skipping trigger."
fi

echo "Installation completed successfully"
