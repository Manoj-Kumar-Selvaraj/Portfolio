#!/usr/bin/env bash
set -euxo pipefail
echo "Setting up Nginx as a reverse proxy for Jenkins..."
echo "========================================"

DOMAIN="jenkins.manoj-tech-solution.site"
EMAIL="ss.mano1998@gmail.com"

echo "Installing Nginx and Certbot..."
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx

echo "Configuring Nginx for Jenkins..."
sudo tee /etc/nginx/sites-available/jenkins <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port 443;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins
sudo rm -f /etc/nginx/sites-enabled/default

echo "Testing Nginx config..."
sudo nginx -t
sudo systemctl reload nginx

echo "Opening firewall (if enabled)..."
sudo ufw allow 'Nginx Full' || true

echo "Requesting Let's Encrypt certificate..."
sudo certbot --nginx \
  -d "${DOMAIN}" \
  --non-interactive \
  --agree-tos \
  -m "${EMAIL}"

echo "✅ Jenkins is now available at https://${DOMAIN}"

echo "Nginx setup for Jenkins completed successfully."