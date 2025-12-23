#!/usr/bin/env bash
set -Eeuo pipefail

# Force non-interactive apt and pre-configure postfix to avoid prompts
export DEBIAN_FRONTEND=noninteractive
echo 'postfix postfix/main_mailer_type select No configuration' | sudo debconf-set-selections
sudo dpkg --configure -a || true

echo "Installing Azure CLI..."

sudo apt-get update
sudo apt-get install -y ca-certificates curl apt-transport-https lsb-release gnupg
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null

sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" \
| sudo tee /etc/apt/sources.list.d/azure-cli.list
sudo apt-get update
sudo apt-get install -y azure-cli
echo "Azure CLI installed successfully. Version:"
az version
