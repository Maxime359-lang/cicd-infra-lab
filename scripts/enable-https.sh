#!/usr/bin/env bash
set -euo pipefail

: "${EC2_HOST:?set EC2_HOST (public IP or DNS)}"
: "${EC2_USER:=ec2-user}"
: "${SSH_KEY:?set SSH_KEY (path to private key)}"

SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=no)

# Source of truth: public IP as seen from EC2
PUB_IP="$(ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" "curl -s ifconfig.me")"
DOM_GH="cicd-github.${PUB_IP}.nip.io"
DOM_GL="cicd-gitlab.${PUB_IP}.nip.io"
CERT_NAME="cicd-nipio"

echo "EC2 public IP: $PUB_IP"
echo "Domains:"
echo "  https://${DOM_GH}"
echo "  https://${DOM_GL}"

# 1) Install packages + create webroot for ACME challenge
ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<'SSH'
set -euo pipefail
sudo dnf install -y nginx certbot >/dev/null
sudo systemctl enable --now nginx
sudo mkdir -p /var/www/letsencrypt
sudo chown -R nginx:nginx /var/www/letsencrypt || true
SSH

# 2) Put nginx config that serves ACME challenge on :80 + redirects to https (once cert exists)
#    For the first run (before cert), :443 blocks won't validate yet if cert missing.
#    We'll write a "bootstrap http-only" config first.
TMP_BOOT="$(mktemp)"
cat > "$TMP_BOOT" <<EOF2
server {
    listen 80;
    server_name ${DOM_GH} ${DOM_GL};

    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }

    location / {
        return 200 "ACME bootstrap OK\n";
    }
}
EOF2

scp "${SSH_OPTS[@]}" "$TMP_BOOT" "${EC2_USER}@${EC2_HOST}:/tmp/cicd-bootstrap.conf"
rm -f "$TMP_BOOT"

ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<'SSH'
set -euo pipefail
sudo mv /tmp/cicd-bootstrap.conf /etc/nginx/conf.d/cicd.conf
sudo chown root:root /etc/nginx/conf.d/cicd.conf
sudo chmod 644 /etc/nginx/conf.d/cicd.conf
sudo nginx -t
sudo systemctl reload nginx
SSH

# 3) Issue cert (webroot challenge). No email (ok for lab); works only if :80 reachable from the internet.
ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<EOF2
set -euo pipefail
sudo certbot certonly --webroot -w /var/www/letsencrypt \
  -d "${DOM_GH}" -d "${DOM_GL}" \
  --cert-name "${CERT_NAME}" \
  --agree-tos --non-interactive --register-unsafely-without-email
EOF2

# 4) Write final nginx config with HTTPS + redirect 80->443 + proxy routing
TMP_FINAL="$(mktemp)"
cat > "$TMP_FINAL" <<EOF3
# HTTP: only ACME + redirect to HTTPS
server {
    listen 80;
    server_name ${DOM_GH} ${DOM_GL};

    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
        default_type "text/plain";
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS: GitHub app
server {
    listen 443 ssl http2;
    server_name ${DOM_GH};

    ssl_certificate     /etc/letsencrypt/live/${CERT_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${CERT_NAME}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# HTTPS: GitLab app
server {
    listen 443 ssl http2;
    server_name ${DOM_GL};

    ssl_certificate     /etc/letsencrypt/live/${CERT_NAME}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${CERT_NAME}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:8082;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF3

scp "${SSH_OPTS[@]}" "$TMP_FINAL" "${EC2_USER}@${EC2_HOST}:/tmp/cicd.conf"
rm -f "$TMP_FINAL"

ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<'SSH'
set -euo pipefail
sudo mv /tmp/cicd.conf /etc/nginx/conf.d/cicd.conf
sudo chown root:root /etc/nginx/conf.d/cicd.conf
sudo chmod 644 /etc/nginx/conf.d/cicd.conf
sudo nginx -t
sudo systemctl reload nginx
SSH

# 5) Renewal: systemd timer that reloads nginx after renew
ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<'SSH'
set -euo pipefail

sudo tee /etc/systemd/system/certbot-renew.service >/dev/null <<'UNIT'
[Unit]
Description=Renew Let's Encrypt certificates

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"
UNIT

sudo tee /etc/systemd/system/certbot-renew.timer >/dev/null <<'TIMER'
[Unit]
Description=Run certbot renew twice daily

[Timer]
OnCalendar=*-*-* 03,15:00:00
RandomizedDelaySec=15m
Persistent=true

[Install]
WantedBy=timers.target
TIMER

sudo systemctl daemon-reload
sudo systemctl enable --now certbot-renew.timer
sudo systemctl list-timers | grep certbot-renew || true
SSH

echo "HTTPS enabled."
echo "Test:"
echo "  https://${DOM_GH}/health"
echo "  https://${DOM_GL}/health"
