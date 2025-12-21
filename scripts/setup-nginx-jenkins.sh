#!/usr/bin/env bash
set -euxo pipefail

echo "========================================"
echo " Setting up Nginx as Jenkins Reverse Proxy"
echo "========================================"

DOMAIN="jenkins.manoj-tech-solutions.site"
EMAIL="ss.mano1998@gmail.com"
JENKINS_PORT=8080

# If Nginx site already exists and certificate is present, skip setup
if [[ -f "/etc/nginx/sites-available/jenkins" ]]; then
  if nginx -t >/dev/null 2>&1; then
    if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
      echo "Detected existing Nginx site and certificate for ${DOMAIN}. Skipping Nginx setup."
      exit 0
    else
      echo "Nginx site exists but certificate for ${DOMAIN} not found — continuing to request certificate."
    fi
  else
    echo "Nginx configuration present but invalid; continuing to reconfigure site."
  fi
fi

# -------------------------
# 0. Wait for OS readiness
# -------------------------
sudo cloud-init status --wait || true

# -------------------------
# 1. Install Nginx
# -------------------------
echo "[1/6] Installing Nginx..."
sudo apt-get update -y
sudo apt-get install -y nginx

# -------------------------
# 2. Configure Nginx for Jenkins
# -------------------------
echo "[2/6] Configuring Nginx site for Jenkins..."

sudo tee /etc/nginx/sites-available/jenkins >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${JENKINS_PORT};
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins
sudo rm -f /etc/nginx/sites-enabled/default

echo "Testing Nginx configuration..."
sudo nginx -t
sudo systemctl reload nginx

# -------------------------
# 3. Firewall (optional)
# -------------------------
echo "[3/6] Opening firewall (if enabled)..."
sudo ufw allow 'Nginx Full' || true

# -------------------------
# 4. Remove APT Certbot (broken on Jammy)
# -------------------------
echo "[4/6] Removing APT-based Certbot (if present)..."
sudo apt-get remove -y certbot python3-certbot-nginx python3-certbot || true
sudo apt-get autoremove -y || true

# -------------------------
# 5. Install Snap-based Certbot (official)
# -------------------------
echo "[5/6] Installing Snap-based Certbot..."

if ! command -v snap &>/dev/null; then
  sudo apt-get install -y snapd
fi

sudo snap install core
sudo snap refresh core

if ! snap list | grep -q certbot; then
  sudo snap install --classic certbot
fi

sudo ln -sf /snap/bin/certbot /usr/bin/certbot

# -------------------------
# 6. Request Let's Encrypt certificate
# -------------------------
echo "[6/6] Requesting Let's Encrypt certificate..."

sudo certbot --nginx \
  -d "${DOMAIN}" \
  --non-interactive \
  --agree-tos \
  -m "${EMAIL}" \
  --redirect

echo
echo "========================================"
echo " ✅ Jenkins is now available securely at:"
echo " 👉 https://${DOMAIN}"
echo "========================================"
echo
echo "Nginx + HTTPS setup completed successfully."
