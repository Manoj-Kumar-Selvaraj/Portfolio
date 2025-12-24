#!/usr/bin/env bash
set -Eeuo pipefail

# Default all variables to avoid unbound variable errors
FORCE_AGENT_SERVICE="${FORCE_AGENT_SERVICE:-0}"
JENKINS_AGENT_SECRET="${JENKINS_AGENT_SECRET:-REPLACE_ME_WITH_SECRET}"
JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME:-Linux-01}"
JENKINS_AGENT_WORKDIR="${JENKINS_AGENT_WORKDIR:-/var/jenkins}"
JENKINS_AGENT_USER="${JENKINS_AGENT_USER:-azureuser}"
JENKINS_AGENT_GROUP="${JENKINS_AGENT_GROUP:-azureuser}"

# Only run if FORCE_AGENT_SERVICE is set to 1
if [[ "${FORCE_AGENT_SERVICE}" != "1" ]]; then
  echo "FORCE_AGENT_SERVICE not set; skipping Jenkins agent service setup."
  exit 0
fi

# Install Java 17 and ensure it's the default
echo "Ensuring Java 17 is installed and set as default..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get install -y openjdk-17-jre-headless

# Set Java 17 as the system default
sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java || true

# Verify Java version
echo "Active Java version: $(java -version 2>&1 | head -n 1)"

# Configurable variables (set via env or defaults)
JENKINS_URL="${JENKINS_URL:-https://jenkins.manoj-tech-solutions.site}"
AGENT_SECRET="${JENKINS_AGENT_SECRET:-REPLACE_ME_WITH_SECRET}"
AGENT_NAME="${JENKINS_AGENT_NAME:-Linux-01}"
WORK_DIR="${JENKINS_AGENT_WORKDIR:-/var/jenkins}"
JAVA_17_PATH="/usr/lib/jvm/java-17-openjdk-amd64/bin/java"
JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
AGENT_JAR="${AGENT_JAR:-$WORK_DIR/agent.jar}"
USER="${JENKINS_AGENT_USER:-azureuser}"
GROUP="${JENKINS_AGENT_GROUP:-azureuser}"

sudo mkdir -p "$WORK_DIR"
sudo chown "$USER:$GROUP" "$WORK_DIR"

# Download agent.jar from Jenkins if not present
if [[ ! -f "$AGENT_JAR" ]]; then
  echo "Downloading agent.jar from $JENKINS_URL/jnlpJars/agent.jar ..."
  curl -fsSL "$JENKINS_URL/jnlpJars/agent.jar" -o "$AGENT_JAR"
  sudo chown "$USER:$GROUP" "$AGENT_JAR"
fi

sudo tee /etc/systemd/system/jenkins-agent.service >/dev/null <<EOF
[Unit]
Description=Jenkins Agent
After=network-online.target
Wants=network-online.target

[Service]
User=$USER
Group=$GROUP
WorkingDirectory=$WORK_DIR

ExecStart=$JAVA_17_PATH -jar $AGENT_JAR \
  -url $JENKINS_URL \
  -secret $AGENT_SECRET \
  -name $AGENT_NAME \
  -workDir $WORK_DIR \
  -webSocket

Restart=always
RestartSec=10
SuccessExitStatus=143

Environment="JAVA_HOME=$JAVA_HOME"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable jenkins-agent
sudo systemctl restart jenkins-agent

echo "Jenkins agent service setup complete."
