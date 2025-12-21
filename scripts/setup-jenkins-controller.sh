#!/usr/bin/env bash
set -euo pipefail

JENKINS_HOME="/var/jenkins_home"
JENKINS_CONTAINER="jenkins-controller"
JENKINS_IMAGE="jenkins/jenkins:lts"
JENKINS_PORT=8080

echo "Preparing Jenkins home..."
sudo mkdir -p "$JENKINS_HOME"
sudo chown -R 1000:1000 "$JENKINS_HOME"
sudo chmod 755 "$JENKINS_HOME"

echo "Stopping old Jenkins container (if any)..."
docker stop "$JENKINS_CONTAINER" 2>/dev/null || true
docker rm "$JENKINS_CONTAINER" 2>/dev/null || true

echo "Pulling Jenkins LTS image..."
docker pull "$JENKINS_IMAGE"

echo "Starting Jenkins controller..."
docker run -d \
  --name "$JENKINS_CONTAINER" \
  --restart unless-stopped \
  -p "$JENKINS_PORT:8080" \
  -p 50000:50000 \
  -v "$JENKINS_HOME:/var/jenkins_home" \
  "$JENKINS_IMAGE"

echo ""
echo "✅ Jenkins controller started"
echo "➡ Access: http://<VM_PUBLIC_IP>:8080"
echo ""
echo "Initial admin password:"
sudo cat "$JENKINS_HOME/secrets/initialAdminPassword"
