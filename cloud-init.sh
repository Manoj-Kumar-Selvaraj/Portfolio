#!/usr/bin/env bash
set -euxo pipefail

# Base packages
apt-get update -y
apt-get install -y git curl ca-certificates

# Clone repo
cd /opt
git clone -b Azure-Scripts https:https://github.com/Manoj-Kumar-Selvaraj/Portfolio /opt/jenkins-install

# Export env vars from Terraform
export AZURE_KV_NAME="${key_vault_name}"
export VM_RG="${resource_group_name}"
export VM_NAME="${vm_name}"
export IDLE_MINUTES=${IDLE_MINUTES}
export KV_SECRET_NAME="${vault_secret_name}"

# Run installer
cd /opt/jenkins-install
chmod +x scripts/*.sh
./scripts/install.sh
