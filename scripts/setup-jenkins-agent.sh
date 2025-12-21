#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo " Jenkins Agent + Harbor Environment Setup"
echo "========================================"

# -------------------------
# 1. System prerequisites
# -------------------------
echo "[1/7] Updating system and installing base packages..."
sudo apt-get update -y
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  software-properties-common \
  zip \
  unzip \
  jq \
  git

# -------------------------
# 2. Install Docker Engine
# -------------------------
if ! command -v docker &>/dev/null; then
  echo "[2/7] Installing Docker Engine..."
  curl -fsSL https://get.docker.com | sudo sh
else
  echo "[2/7] Docker already installed."
fi

sudo systemctl enable docker
sudo systemctl start docker

# -------------------------
# 3. Allow Jenkins user to run Docker
# -------------------------
JENKINS_USER="jenkins"

if id "$JENKINS_USER" &>/dev/null; then
  echo "[3/7] Adding Jenkins user to docker group..."
  sudo usermod -aG docker "$JENKINS_USER"
else
  echo "[3/7] Jenkins user not found (will be added later by controller)."
fi

# -------------------------
# 4. Install Docker Compose v2
# -------------------------
if ! docker compose version &>/dev/null; then
  echo "[4/7] Installing Docker Compose v2..."
  sudo mkdir -p /usr/local/lib/docker/cli-plugins
  sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
else
  echo "[4/7] Docker Compose already installed."
fi

# -------------------------
# 5. Install Python 3.13
# -------------------------
if ! python3.13 --version &>/dev/null; then
  echo "[5/7] Installing Python 3.13..."
  sudo add-apt-repository ppa:deadsnakes/ppa -y
  sudo apt-get update
  sudo apt-get install -y python3.13 python3.13-venv python3.13-distutils
else
  echo "[5/7] Python 3.13 already installed."
fi

# -------------------------
# 6. Install uv
# -------------------------
if ! command -v uv &>/dev/null; then
  echo "[6/7] Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  echo "[6/7] uv already installed."
fi

# Ensure uv is in PATH for non-login shells (Jenkins)
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# -------------------------
# 7. Install Harbor CLI
# -------------------------
echo "[7/7] Installing Harbor CLI..."
uv tool install harbor==0.1.25 --python 3.13

echo
echo "========================================"
echo " ✅ Jenkins Agent setup complete"
echo "========================================"
echo
echo "NEXT STEPS:"
echo "1. Reboot the VM (required for docker group changes)"
echo "2. Configure this VM as a Jenkins agent"
echo "3. Set environment variables in Jenkins:"
echo "   OPENAI_API_KEY"
echo "   OPENAI_BASE_URL=https://api.portkey.ai/v1"
echo
