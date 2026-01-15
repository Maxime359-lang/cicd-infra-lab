#!/usr/bin/env bash
set -euo pipefail

: "${EC2_HOST:?set EC2_HOST (public IP or DNS)}"
: "${EC2_USER:=ec2-user}"
: "${SSH_KEY:?set SSH_KEY (path to private key)}"

SSH_OPTS=(-i "$SSH_KEY" -o StrictHostKeyChecking=no)

# 1) Resolve public IP from the EC2 itself (source of truth)
PUB_IP="$(ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" "curl -s ifconfig.me")"
echo "EC2 public IP: $PUB_IP"
echo "Hosts:"
echo "  http://cicd-github.${PUB_IP}.nip.io"
echo "  http://cicd-gitlab.${PUB_IP}.nip.io"

# 2) Render template locally
TMP_CONF="$(mktemp)"
sed "s/<EC2_IP>/${PUB_IP}/g" nginx/cicd.conf.tpl > "$TMP_CONF"

# 3) Install & start nginx (idempotent)
ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<'SSH'
set -euo pipefail
sudo dnf install -y nginx >/dev/null
sudo systemctl enable --now nginx
SSH

# 4) Upload config and validate
scp "${SSH_OPTS[@]}" "$TMP_CONF" "${EC2_USER}@${EC2_HOST}:/tmp/cicd.conf"

ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<'SSH'
set -euo pipefail
sudo mv /tmp/cicd.conf /etc/nginx/conf.d/cicd.conf
sudo nginx -t
sudo systemctl reload nginx
SSH

rm -f "$TMP_CONF"

# 5) Local tests on EC2 (host header)
ssh "${SSH_OPTS[@]}" "${EC2_USER}@${EC2_HOST}" <<SSH
set -euo pipefail
PUB_IP="$PUB_IP"
curl -sS -H "Host: cicd-github.${PUB_IP}.nip.io" http://127.0.0.1/health
echo
curl -sS -H "Host: cicd-gitlab.${PUB_IP}.nip.io" http://127.0.0.1/health || true
echo
SSH

echo "Done. Next: open inbound TCP/80 in Security Group and test from your laptop."
