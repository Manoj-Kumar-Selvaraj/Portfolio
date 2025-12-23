#!/usr/bin/env bash
set -Eeuo pipefail

# Force non-interactive apt and pre-configure postfix to avoid prompts
export DEBIAN_FRONTEND=noninteractive
echo 'postfix postfix/main_mailer_type select No configuration' | sudo debconf-set-selections
sudo dpkg --configure -a || true

echo "========================================"
echo " Setting up Nginx as Jenkins Reverse Proxy"
echo "========================================"

DOMAIN="jenkins.manoj-tech-solutions.site"
EMAIL="ss.mano1998@gmail.com"
JENKINS_PORT=8080

# Normalize per-component FORCE environment variables (accept true/1/yes)
# FORCE_NGINX takes precedence; otherwise fall back to FORCE
RAW_FORCE_NGINX="${FORCE_NGINX:-}" 
RAW_FORCE_GLOBAL="${FORCE:-0}"
if [ -z "$RAW_FORCE_NGINX" ]; then
  RAW_FORCE_NGINX="$RAW_FORCE_GLOBAL"
fi
case "$(tr '[:upper:]' '[:lower:]' <<<"$RAW_FORCE_NGINX")" in
  1|true|yes) FORCE_NGINX=1 ;;
  *) FORCE_NGINX=0 ;;
esac
export FORCE_NGINX

# If Nginx site already exists and certificate is present, skip setup (unless FORCE)
# If Nginx site already exists and certificate is present, skip setup (unless FORCE_NGINX)
if [[ -f "/etc/nginx/sites-available/jenkins" ]]; then
  if [ "${FORCE_NGINX:-0}" -eq 1 ]; then
    echo "FORCE_NGINX set; forcing Nginx reconfiguration"
  else
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

  # Dedicated access log for Jenkins site to allow precise idle detection
  access_log /var/log/nginx/jenkins.access.log;

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

# Ensure dedicated Jenkins access log file exists and has correct ownership
if [[ ! -f /var/log/nginx/jenkins.access.log ]]; then
  sudo touch /var/log/nginx/jenkins.access.log
fi
sudo chown www-data:adm /var/log/nginx/jenkins.access.log || true
sudo chmod 664 /var/log/nginx/jenkins.access.log || true

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
