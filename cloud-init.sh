#!/usr/bin/env bash
set -euxo pipefail

# Base packages
apt-get update -y
apt-get install -y git curl ca-certificates

# Clone repo
cd /opt

if [ ! -d /opt/jenkins-install ]; then
   echo "directory exists"
   git clone -b Azure-Scripts https://github.com/Manoj-Kumar-Selvaraj/Portfolio.git /opt/jenkins-install
   cd /opt/jenkins-install
   git fetch origin
   git checkout Azure-Scripts
   git pull
else
  mkdir /opt/jenkins-install
  git clone -b Azure-Scripts https://github.com/Manoj-Kumar-Selvaraj/Portfolio.git /opt/jenkins-install
  cd /opt/jenkins-install
  git fetch origin
  git checkout Azure-Scripts
  git pull
else
fi


# Run installer
cd /opt/jenkins-install
chmod +x scripts/*.sh
./scripts/install.sh
