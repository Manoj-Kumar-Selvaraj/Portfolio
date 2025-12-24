
#!/usr/bin/env bash
set -Eeuo pipefail

# Default all force flags to avoid unbound variable errors
FORCE="${FORCE:-0}"
FORCE_NGINX="${FORCE_NGINX:-0}"
FORCE_CONTROLLER="${FORCE_CONTROLLER:-0}"
FORCE_AGENT_ENV="${FORCE_AGENT_ENV:-0}"
FORCE_AGENT_SERVICE="${FORCE_AGENT_SERVICE:-0}"
FORCE_IDLE_SHUTDOWN="${FORCE_IDLE_SHUTDOWN:-0}"
FORCE_AZ_CLI="${FORCE_AZ_CLI:-0}"

# # Stop idle-shutdown service immediately to prevent VM shutdown during deployment
# echo "Stopping idle-shutdown service during deployment..."
# sudo systemctl stop jenkins-idle-shutdown.service 2>/dev/null || true
# sudo systemctl stop jenkins-agent.service
# sudo systemctl disable jenkins-agent.service

# Fix corrupted postfix installation once at the start
echo "Cleaning up any corrupted postfix installation..."
export DEBIAN_FRONTEND=noninteractive
sudo systemctl stop postfix 2>/dev/null || true
sudo apt-get remove --purge -y postfix 2>/dev/null || true
sudo rm -rf /var/lib/dpkg/info/postfix.* 2>/dev/null || true
sudo rm -rf /etc/postfix 2>/dev/null || true
sudo dpkg --configure -a 2>/dev/null || true
sudo apt-get autoremove -y 2>/dev/null || true
sudo apt-get clean 2>/dev/null || true
echo "Postfix cleanup complete."

LOG_FILE="/var/log/jenkins-install.log"
if [[ -z "$LOG_FILE" ]]; then
  LOG_FILE="/tmp/jenkins-install.log"
fi
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[FORCE FLAGS]"
echo "FORCE=$FORCE"
echo "FORCE_NGINX=$FORCE_NGINX"
echo "FORCE_CONTROLLER=$FORCE_CONTROLLER"
echo "FORCE_AGENT_ENV=$FORCE_AGENT_ENV"
echo "FORCE_AGENT_SERVICE=$FORCE_AGENT_SERVICE"
echo "FORCE_IDLE_SHUTDOWN=$FORCE_IDLE_SHUTDOWN"
echo "FORCE_AZ_CLI=$FORCE_AZ_CLI"
echo "===================="

./scripts/setup-jenkins-agent.sh
./scripts/setup-jenkins-controller.sh
./scripts/setup-nginx-jenkins.sh

# Set up Jenkins agent as a service AFTER Java is installed
./scripts/setup-jenkins-agent-service.sh

./scripts/install-idle-shutdown-service.sh
./scripts/az.sh


if ./scripts/fetch_jenkins_token.sh | grep -q ':'; then
  ./scripts/trigger_job_local.sh initial-setup
else
  echo "Jenkins credentials not ready. Skipping trigger."
fi
echo "Jenkins installation and setup completed."
