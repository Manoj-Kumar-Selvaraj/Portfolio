#!/usr/bin/env bash
set -euo pipefail

JENKINS_HOME_DIR="/var/jenkins_home"
JENKINS_PORT=8080
JENKINS_CONTAINER_NAME="jenkins-controller"

mkdir -p "${JENKINS_HOME_DIR}"
chown 1000:1000 "${JENKINS_HOME_DIR}"

docker pull jenkins/jenkins:lts

docker run -d \
  --name "${JENKINS_CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "${JENKINS_PORT}:8080" \
  -p 50000:50000 \
  -v "${JENKINS_HOME_DIR}:/var/jenkins_home" \
  jenkins/jenkins:lts
