#!/usr/bin/env bash
set -euo pipefail

apt-get update -y
apt-get install -y docker.io jq curl

systemctl enable docker
systemctl start docker
