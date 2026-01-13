# CICD Infra Lab (Nginx Reverse Proxy + nip.io)

This repo provisions an EC2 host with Nginx reverse proxy that routes:
- `cicd-github.<EC2_IP>.nip.io` -> `127.0.0.1:8081`
- `cicd-gitlab.<EC2_IP>.nip.io` -> `127.0.0.1:8082`

## Prerequisites
- EC2 reachable via SSH
- Apps already bound to localhost:
  - GitHub app: `127.0.0.1:8081`
  - GitLab app: `127.0.0.1:8082`

## Apply
```bash
export EC2_HOST="<EC2_PUBLIC_IP>"
export EC2_USER="ec2-user"
export SSH_KEY="$HOME/.ssh/<your_key>"
./scripts/apply-nginx.sh
