#!/usr/bin/env bash
set -e

############################################
# Terraform-injected variables
############################################

AZURE_KV_NAME="${key_vault_name}"
VM_RG="${resource_group_name}"
VM_NAME="${vm_name}"
IDLE_MINUTES=${IDLE_MINUTES}

JENKINS_HOME_DIR="/var/jenkins_home"
JENKINS_PORT=8080
JENKINS_CONTAINER_NAME="jenkins-controller"
KV_SECRET_NAME="jenkins-apitoken"

############################################
# Base system setup
############################################

apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates \
  curl \
  jq

############################################
# Install Docker (Ubuntu-native, cloud-init safe)
############################################

apt-get install -y docker.io
systemctl enable docker
systemctl start docker

############################################
# Jenkins container
############################################

mkdir -p "$${JENKINS_HOME_DIR}"
chown 1000:1000 "$${JENKINS_HOME_DIR}"

docker pull jenkins/jenkins:lts

docker run -d --name "$${JENKINS_CONTAINER_NAME}" \
  --restart unless-stopped \
  -p "$${JENKINS_PORT}":8080 \
  -p 50000:50000 \
  -v "$${JENKINS_HOME_DIR}":/var/jenkins_home \
  jenkins/jenkins:lts

############################################
# Install Azure CLI (Managed Identity)
############################################

curl -sL https://aka.ms/InstallAzureCLIDeb | bash

mkdir -p /opt/jenkins

############################################
# fetch_jenkins_token.sh
############################################

cat > /opt/jenkins/fetch_jenkins_token.sh <<EOF
#!/usr/bin/env bash
set -euo pipefail

VAULT_NAME="${key_vault_name}"
SECRET_NAME="jenkins-apitoken"

az login --identity >/dev/null 2>&1 || true
az keyvault secret show \
  --vault-name "\$VAULT_NAME" \
  --name "\$SECRET_NAME" \
  --query value -o tsv
EOF

chmod +x /opt/jenkins/fetch_jenkins_token.sh

############################################
# trigger_job_local.sh
############################################

cat > /opt/jenkins/trigger_job_local.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

JOB_NAME="$${1:-deploy-site}"
JENKINS_URL="http://localhost:8080"

CRED=$$(/opt/jenkins/fetch_jenkins_token.sh)
JUSER=$$(echo "$$CRED" | cut -d: -f1)
JTOKEN=$$(echo "$$CRED" | cut -d: -f2-)

CRUMB_JSON=$$(curl -s -u "$${JUSER}:$${JTOKEN}" "$${JENKINS_URL}/crumbIssuer/api/json" || true)
CRUMB=$$(echo "$$CRUMB_JSON" | jq -r .crumb)
CRUMB_FIELD=$$(echo "$$CRUMB_JSON" | jq -r .crumbRequestField)

curl -X POST \
  -u "$${JUSER}:$${JTOKEN}" \
  -H "$${CRUMB_FIELD}: $${CRUMB}" \
  "$${JENKINS_URL}/job/$${JOB_NAME}/build?delay=0"

echo "Triggered job: $${JOB_NAME}"
EOF

chmod +x /opt/jenkins/trigger_job_local.sh

############################################
# idle-shutdown.sh  (FIXED)
############################################

cat > /opt/jenkins/idle-shutdown.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="http://localhost:8080"
IDLE_MINUTES=${IDLE_MINUTES}
AZURE_RG="${resource_group_name}"
AZURE_VM_NAME="${vm_name}"

IDLE_MS=\$((IDLE_MINUTES * 60 * 1000))

now_ms() {
  date +%s%3N
}

get_last_completed_ms() {
  curl -s "$${JENKINS_URL}/api/json?tree=jobs[name,lastCompletedBuild[timestamp]]" \
    | jq '[.jobs[].lastCompletedBuild.timestamp] | map(select(. != null)) | max // 0'
}

while true; do
  busy="$$(curl -s "$${JENKINS_URL}/api/json" | jq -r .busyExecutors)"
  queue_len="$$(curl -s "${JENKINS_URL}/queue/api/json" | jq '.items | length')"

  if [[ "$${busy}" -eq 0 && "$${queue_len}" -eq 0 ]]; then
    last_ms="$$(get_last_completed_ms)"
    now="$$(now_ms)"

    if [[ "$${last_ms}" -ne 0 ]]; then
      idle=$$((now - last_ms))
      if [[ "$${idle}" -ge "$${IDLE_MS}" ]]; then
        az login --identity >/dev/null 2>&1 || true
        az vm deallocate -g "$${AZURE_RG}" -n "$${AZURE_VM_NAME}" --no-wait
        exit 0
      fi
    fi
  fi

  sleep 30
done
EOF

chmod +x /opt/jenkins/idle-shutdown.sh

############################################
# systemd service
############################################

cat > /etc/systemd/system/jenkins-idle-shutdown.service <<'EOF'
[Unit]
Description=Jenkins Idle Shutdown Service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/jenkins/idle-shutdown.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now jenkins-idle-shutdown.service

echo "Provisioning complete"
