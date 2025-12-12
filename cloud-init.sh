#!/usr/bin/env bash
# cloud-init.sh - provision VM: docker, jenkins container, scripts, idle-shutdown service
set -eux

# Variables (can be overridden by TF via template rendering or env)
JENKINS_HOME_DIR=/var/jenkins_home
JENKINS_PORT=8080
JENKINS_CONTAINER_NAME=jenkins-controller
AZURE_KV_NAME="{{key_vault_name}}"
KV_SECRET_NAME="jenkins-apitoken"
VM_RG="{{resource_group_name}}"
VM_NAME="{{vm_name}}"
IDLE_MINUTES=5

# install packages
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl jq lsb-release gnupg

# install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $$(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# create Jenkins home dir
mkdir -p $${JENKINS_HOME_DIR}
chown 1000:1000 $${JENKINS_HOME_DIR}  # Jenkins official container uses UID 1000

# pull jenkins image and run (expose 8080, 50000)
docker pull jenkins/jenkins:lts
docker run -d --name $${JENKINS_CONTAINER_NAME} \
  --restart unless-stopped \
  -p $${JENKINS_PORT}:8080 -p 50000:50000 \
  -v $${JENKINS_HOME_DIR}:/var/jenkins_home \
  jenkins/jenkins:lts

# install azure-cli (for VM-managed identity calls)
curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# place helper scripts
mkdir -p /opt/jenkins
cat > /opt/jenkins/fetch_jenkins_token.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
VAULT_NAME="{{key_vault_name}}"
SECRET_NAME="jenkins-apitoken"
# retrieve secret using VM managed identity via azure cli
az login --identity >/dev/null 2>&1 || true
az keyvault secret show --vault-name "$$VAULT_NAME" --name "$$SECRET_NAME" --query value -o tsv
EOF
chmod +x /opt/jenkins/fetch_jenkins_token.sh

cat > /opt/jenkins/trigger_job_local.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
JOB_NAME="$${1:-deploy-site}"
JENKINS_URL="http://localhost:8080"

# fetch jenkins user:token from Key Vault via managed identity
CRED=$$(bash /opt/jenkins/fetch_jenkins_token.sh)
JUSER=$$(echo "$$CRED" | cut -d: -f1)
JTOKEN=$$(echo "$$CRED" | cut -d: -f2-)

# get crumb
CRUMB_JSON=$$(curl -s -u "$${JUSER}:$${JTOKEN}" "$${JENKINS_URL}/crumbIssuer/api/json" || true)
CRUMB=$$(echo "$$CRUMB_JSON" | jq -r .crumb)
CRUMB_FIELD=$$(echo "$$CRUMB_JSON" | jq -r .crumbRequestField)

# trigger job
curl -X POST -u "$${JUSER}:$${JTOKEN}" -H "$${CRUMB_FIELD}: $${CRUMB}" "$${JENKINS_URL}/job/$${JOB_NAME}/build?delay=0"
echo "Triggered $${JOB_NAME}"
EOF
chmod +x /opt/jenkins/trigger_job_local.sh

# idle-shutdown script (uses az login --identity to deallocate VM)
cat > /opt/jenkins/idle-shutdown.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
JENKINS_URL="http://localhost:8080"
IDLE_MINUTES=$${IDLE_MINUTES}
AZURE_RG="$${VM_RG}"
AZURE_VM_NAME="$${VM_NAME}"
IDLE_MS=$$((IDLE_MINUTES * 60 * 1000))

now_ms() { date +%s%3N; }

get_last_completed_ms() {
  # return max lastCompletedBuild.timestamp (ms) across jobs, or 0
  val=$$(curl -s "$$JENKINS_URL/api/json?tree=jobs[name,lastCompletedBuild[timestamp]]" | jq '[.jobs[].lastCompletedBuild.timestamp] | map(select(. != null)) | max // 0')
  echo "$$val"
}

while true; do
  busy=$$(curl -s "$$JENKINS_URL/api/json" | jq -r .busyExecutors // 0)
  queue_len=$$(curl -s "$$JENKINS_URL/queue/api/json" | jq -r '.items | length' // 0)

  if [ "$$busy" -eq 0 ] && [ "$$queue_len" -eq 0 ]; then
    last_ms=$$(get_last_completed_ms)
    now=$$(now_ms)
    if [ "$$last_ms" -eq 0 ]; then
      # no builds yet; sleep and re-evaluate
      sleep 60
    else
      idle_time=$$((now - last_ms))
      if [ "$$idle_time" -ge "$$IDLE_MS" ]; then
        echo "VM idle for $${idle_time} ms; deallocating..."
        az login --identity >/dev/null 2>&1 || true
        az vm deallocate -g "$$AZURE_RG" -n "$$AZURE_VM_NAME" --no-wait || true
        exit 0
      fi
    fi
  fi
  sleep 30
done
EOF
chmod +x /opt/jenkins/idle-shutdown.sh

# systemd unit for idle-shutdown
cat > /etc/systemd/system/jenkins-idle-shutdown.service <<'EOF'
[Unit]
Description=Jenkins Idle Shutdown Service
After=network-online.target docker.service
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

# done
echo "Provisioning complete"
