# CICD Infra Lab (Nginx Reverse Proxy + HTTPS + nip.io)

This repo configures an EC2 host as a **reverse proxy gateway** for two demo apps running on the same machine:

- GitHub-deployed app: `cicd-github.<EC2_IP>.nip.io` → `127.0.0.1:8081`
- GitLab-deployed app: `cicd-gitlab.<EC2_IP>.nip.io` → `127.0.0.1:8082`

## Live demo (current EC2)
- https://cicd-github.18.198.208.36.nip.io/health
- https://cicd-gitlab.18.198.208.36.nip.io/health

## Prerequisites on EC2
- Nginx installed
- Apps bound to localhost only:
  - GitHub app: `127.0.0.1:8081`
  - GitLab app: `127.0.0.1:8082`

Security Group (recommended):
- inbound: 80/tcp, 443/tcp
- inbound: 22/tcp only from your IP (or use SSM and close 22)
- do **NOT** expose 8081/8082 publicly

## Apply Nginx reverse proxy (HTTP + HTTPS vhost config)
```bash
export EC2_HOST="18.198.208.36"
export EC2_USER="ec2-user"
export SSH_KEY="$HOME/.ssh/<your_key>"
./scripts/apply-nginx.sh
```

## Enable HTTPS (Let's Encrypt) + auto-renew
```bash
export EC2_HOST="18.198.208.36"
export EC2_USER="ec2-user"
export SSH_KEY="$HOME/.ssh/<your_key>"
./scripts/enable-https.sh
```

## Verify (from anywhere)
```bash
PUB_IP="18.198.208.36"
curl -sS https://cicd-github.${PUB_IP}.nip.io/health
curl -sS https://cicd-gitlab.${PUB_IP}.nip.io/health
```

## Files
- `nginx/cicd.conf.tpl` – vhost template for both hosts
- `scripts/apply-nginx.sh` – installs/updates nginx config and reloads nginx
- `scripts/enable-https.sh` – issues Let's Encrypt certs and configures renewal

## Related repos
- GitHub app (SSM + OIDC deploy): `prod-automation-lab`
- GitLab app (GitLab CI + SSH deploy + rollback): `devops-flask-ci-cd`

This repo acts as the gateway (Nginx + HTTPS) for both apps.
