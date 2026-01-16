# CICD Infra Lab — Nginx Reverse Proxy Gateway + HTTPS (Let's Encrypt) + nip.io

This repo is the gateway layer for two demo apps running on the same EC2 host:
- GitHub-deployed app:  cicd-github.<EC2_IP>.nip.io  -> 127.0.0.1:8081
- GitLab-deployed app:  cicd-gitlab.<EC2_IP>.nip.io  -> 127.0.0.1:8082

It provides:
- single public entrypoint (80/443)
- TLS termination (Let's Encrypt) + auto-renew
- reverse proxy routing to localhost-only apps

Live demo (current EC2):
- https://cicd-github.18.198.208.36.nip.io/health
- https://cicd-gitlab.18.198.208.36.nip.io/health

## Architecture
On EC2 both apps run in containers but bind to localhost only:
- prod-automation-lab -> 127.0.0.1:8081
- devops-flask-ci-cd  -> 127.0.0.1:8082

Nginx is the only public-facing component:
Internet -> Nginx (80/443) -> localhost containers (8081/8082)

## Recruiter highlights
- Reverse proxy gateway with 2 vhosts (nip.io) on one EC2 IP
- HTTP -> HTTPS redirect (301)
- Let's Encrypt (ACME webroot) + certbot auto-renew (systemd timer)
- Security headers baseline: HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- Deploy pinned to commit SHA (reproducible config)
- Smoke tests with retries

## Repo structure
- nginx/cicd.conf.tpl        : nginx config template with <EC2_IP> placeholder
- scripts/smoke.sh           : retry-based smoke test (used in CI/deploy)
- .github/workflows/*.yml    : lint + deploy workflow(s)

## Verify (from anywhere)
PUB_IP="18.198.208.36"

# redirect
curl -sSI http://cicd-github.${PUB_IP}.nip.io/health | egrep -i 'HTTP/|location'
curl -sSI http://cicd-gitlab.${PUB_IP}.nip.io/health | egrep -i 'HTTP/|location'

# health
curl -sS https://cicd-github.${PUB_IP}.nip.io/health; echo
curl -sS https://cicd-gitlab.${PUB_IP}.nip.io/health; echo

# security headers
curl -sSI https://cicd-github.${PUB_IP}.nip.io/health | egrep -i 'strict-transport|x-content-type|x-frame|referrer|server'
curl -sSI https://cicd-gitlab.${PUB_IP}.nip.io/health | egrep -i 'strict-transport|x-content-type|x-frame|referrer|server'

## Related repos (apps behind this gateway)
- prod-automation-lab  (GitHub Actions -> GHCR -> EC2 via SSM/OIDC)
- devops-flask-ci-cd   (GitLab CI -> EC2 via SSH + rollback + Trivy)
