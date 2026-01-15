# CICD Infra Lab (Nginx Reverse Proxy + HTTPS + nip.io)

This repo configures an EC2 host as a **reverse proxy gateway** for two demo apps running on the same machine:

- GitHub-deployed app: `cicd-github.<EC2_IP>.nip.io` → `127.0.0.1:8081`
- GitLab-deployed app: `cicd-gitlab.<EC2_IP>.nip.io` → `127.0.0.1:8082`

## Live demo
Replace `<EC2_IP>` with your EC2 public IPv4:
- https://cicd-github.<EC2_IP>.nip.io/health
- https://cicd-gitlab.<EC2_IP>.nip.io/health

Example:
- https://cicd-github.18.198.208.36.nip.io/health
- https://cicd-gitlab.18.198.208.36.nip.io/health

## What this repo does
- Renders nginx vhost template (`nginx/cicd.conf.tpl`) using EC2 public IP
- Deploys nginx config to EC2 via **SSM Run Command** (GitHub Actions OIDC)
- Runs smoke checks

## Prerequisites on EC2
- Amazon Linux 2023
- SSM agent working
- Security Group:
  - inbound: **80/tcp**, **443/tcp**
  - (optional) **22/tcp** only from your IP, or keep SSH closed and use SSM
  - do **NOT** expose **8081/8082** publicly
- Two apps already running on localhost only:
  - GitHub app: `127.0.0.1:8081`
  - GitLab app: `127.0.0.1:8082`

## Deploy (GitHub Actions)
Workflow: `.github/workflows/deploy-ec2.yml`

Required secrets:
- `AWS_DEPLOY_ROLE_ARN`
- `AWS_EC2_INSTANCE_ID`

Required repo variable:
- `EC2_PUBLIC_IP` = your EC2 public IPv4 (example: `18.198.208.36`)

## Verify
~~~bash
PUB_IP="<EC2_PUBLIC_IP>"
curl -sS https://cicd-github.${PUB_IP}.nip.io/health
curl -sS https://cicd-gitlab.${PUB_IP}.nip.io/health
~~~

## Troubleshooting

### 502 Bad Gateway
Check upstream:
~~~bash
curl -sS http://127.0.0.1:8081/health
curl -sS http://127.0.0.1:8082/health
docker ps
sudo tail -n 50 /var/log/nginx/error.log
~~~

### invalid server name "cicd-github..nip.io"
Happens when EC2 IP rendered as empty. Ensure repo variable `EC2_PUBLIC_IP` is set.

## Related repos
- GitHub app (SSM + OIDC deploy): `prod-automation-lab`
- GitLab app (GitLab CI + SSH deploy + rollback): `devops-flask-ci-cd`
