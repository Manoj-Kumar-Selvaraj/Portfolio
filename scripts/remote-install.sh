#!/usr/bin/env bash
set -Eeuo pipefail

VM_NAME=jenkins-vm
RESOURCE_GROUP=portfolio-rg
INSTALL_DIR=/opt/jenkins-install
LOG_FILE="/var/log/jenkins-install.log"

mkdir -p /var/log
if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="/tmp/jenkins-install.log"
fi

touch "$LOG_FILE"
exec >>"$LOG_FILE"
exec 2>&1

echo "====================================="
echo "Jenkins install started at $(date -u)"
echo "VM=$VM_NAME RG=$RESOURCE_GROUP"
echo "FORCE=$FORCE"
echo "FORCE_NGINX=$FORCE_NGINX"
echo "FORCE_CONTROLLER=$FORCE_CONTROLLER"
echo "FORCE_AGENT=$FORCE_AGENT"
echo "====================================="

if [[ -z "$AZURE_KV_NAME" || -z "$KV_SECRET_NAME" ]]; then
  echo "ERROR: Azure Key Vault variables missing"
  exit 1
fi

rm -rf "$INSTALL_DIR"
git clone -b Azure-Scripts \
  https://github.com/Manoj-Kumar-Selvaraj/Portfolio.git \
  "$INSTALL_DIR"

cd "$INSTALL_DIR"
chmod -R +x scripts

env \
  FORCE="$FORCE" \
  FORCE_NGINX="$FORCE_NGINX" \
  FORCE_CONTROLLER="$FORCE_CONTROLLER" \
  FORCE_AGENT="$FORCE_AGENT" \
  AZURE_KV_NAME="$AZURE_KV_NAME" \
  KV_SECRET_NAME="$KV_SECRET_NAME" \
  FORCE_JENKINS_AGENT_SERVICE="$FORCE_JENKINS_AGENT_SERVICE" \
  JENKINS_AGENT_SECRET="$JENKINS_AGENT_SECRET" \
  JENKINS_AGENT_NAME="$JENKINS_AGENT_NAME" \
  bash scripts/install.sh

echo "Jenkins install completed at $(date -u)"
