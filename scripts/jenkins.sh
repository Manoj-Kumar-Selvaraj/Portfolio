#!/usr/bin/env bash
set -euo pipefail

JENKINS_HOME_DIR="/var/jenkins_home"
JENKINS_PORT=8080
JENKINS_CONTAINER_NAME="jenkins-controller"
JENKINS_IMAGE="jenkins/jenkins:lts"

echo "Stopping existing Jenkins container (if any)..."
docker stop "${JENKINS_CONTAINER_NAME}" 2>/dev/null || true

echo "Removing existing Jenkins container (if any)..."
docker rm "${JENKINS_CONTAINER_NAME}" 2>/dev/null || true

echo "Ensuring Jenkins home directory exists..."
mkdir -p "${JENKINS_HOME_DIR}"
chown -R 1000:1000 "${JENKINS_HOME_DIR}"
chmod 755 "${JENKINS_HOME_DIR}"

echo "Pulling latest Jenkins LTS image..."
docker pull "${JENKINS_IMAGE}"

echo "Starting Jenkins container..."
docker run -d \
  --name "${JENKINS_CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${JENKINS_PORT}:8080" \
  -p 50000:50000 \
  -v "${JENKINS_HOME_DIR}:/var/jenkins_home" \
  "${JENKINS_IMAGE}"

echo "Jenkins container started successfully."
docker ps --filter "name=${JENKINS_CONTAINER_NAME}"
