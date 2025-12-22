#!/usr/bin/env bash
set -Eeuo pipefail

# Only run if FORCE_JENKINS_AGENT_SERVICE is set to 1
if [[ "${FORCE_JENKINS_AGENT_SERVICE:-0}" != "1" ]]; then
  echo "FORCE_JENKINS_AGENT_SERVICE not set; skipping Jenkins agent service setup."
  exit 0
fi

# Configurable variables (set via env or defaults)
JENKINS_URL="${JENKINS_URL:-https://jenkins.manoj-tech-solutions.site}"
AGENT_SECRET="${JENKINS_AGENT_SECRET:-REPLACE_ME_WITH_SECRET}"
AGENT_NAME="${JENKINS_AGENT_NAME:-Linux-01}"
WORK_DIR="${JENKINS_AGENT_WORKDIR:-/var/jenkins}"
JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
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

ExecStart=/usr/bin/java -jar $AGENT_JAR \
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
