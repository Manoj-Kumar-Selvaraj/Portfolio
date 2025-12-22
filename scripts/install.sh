
#!/usr/bin/env bash
set -Eeuo pipefail

LOG_FILE="/var/log/jenkins-install.log"
if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="/tmp/jenkins-install.log"
fi
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

# Optionally set up Jenkins agent as a service if flag is set
./scripts/setup-jenkins-agent-service.sh

# Ensure SSH is running
./scripts/ensure-ssh.sh

echo "[FORCE FLAGS]"
echo "FORCE=$FORCE"
echo "FORCE_NGINX=$FORCE_NGINX"
echo "FORCE_CONTROLLER=$FORCE_CONTROLLER"
echo "FORCE_AGENT=$FORCE_AGENT"
echo "===================="

./scripts/setup-jenkins-agent.sh
./scripts/setup-jenkins-controller.sh
./scripts/setup-nginx-jenkins.sh

./scripts/install-idle-shutdown-service.sh
./scripts/az.sh


if ./scripts/fetch_jenkins_token.sh | grep -q ':'; then
  ./scripts/trigger_job_local.sh initial-setup
else
  echo "Jenkins credentials not ready. Skipping trigger."
fi
echo "Jenkins installation and setup completed."

# Email the install log
./scripts/email-log.sh