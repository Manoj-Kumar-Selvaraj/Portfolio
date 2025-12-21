#!/usr/bin/env bash
set -euo pipefail

# Install Docker Compose (if not already installed)
if ! command -v docker-compose &> /dev/null; then
  echo "Installing Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
else
  echo "Docker Compose is already installed."
fi

# Install Python 3.13 if not present
if ! python3.13 --version &> /dev/null; then
  echo "Installing Python 3.13..."
  sudo add-apt-repository ppa:deadsnakes/ppa -y
  sudo apt-get update
  sudo apt-get install -y python3.13 python3.13-venv python3.13-distutils
else
  echo "Python 3.13 is already installed."
fi

# Install uv (modern Python package manager)
if ! command -v uv &> /dev/null; then
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
else
  echo "uv is already installed."
fi

# Install Harbor using uv and Python 3.13
echo "Installing Harbor CLI with uv (Python 3.13)..."
uv tool install harbor==0.1.25 --python 3.13

echo "\nTo use Harbor CLI, configure your API keys (add these to your ~/.bashrc or ~/.zshrc for persistence):"
echo "export OPENAI_API_KEY=\"<your-portkey-api-key>\""
echo "export OPENAI_BASE_URL=\"https://api.portkey.ai/v1\""

echo "Docker Compose, Python 3.13, uv, and Harbor CLI setup complete."
