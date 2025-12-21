#!/usr/bin/env bash
set -euo pipefail

# This script sets up Nginx as a reverse proxy for Jenkins with SSL using Let's Encrypt
# Domain: jenkins.manoj-tech-solution.site
# Assumes Jenkins is running on localhost:8080

DOMAIN="jenkins.manoj-tech-solution.site"
EMAIL="ss.mano1998@gmail.com.com"  # Change to your email for Let's Encrypt notifications

# Install Nginx and Certbot
sudo apt-get update
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Configure Nginx reverse proxy for Jenkins
sudo tee /etc/nginx/sites-available/jenkins <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/jenkins
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl reload nginx

# Allow HTTP/HTTPS through firewall (if using UFW)
sudo ufw allow 'Nginx Full' || true

# Obtain SSL certificate from Let's Encrypt
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL

# Auto-renewal is handled by Certbot's systemd timer

echo "Nginx reverse proxy with SSL is set up for $DOMAIN."
