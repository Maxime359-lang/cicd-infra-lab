#!/usr/bin/env bash
set -euo pipefail

PUB_IP="${1:?usage: smoke-nginx.sh <PUB_IP>}"

url1="http://cicd-github.${PUB_IP}.nip.io/health"
url2="http://cicd-gitlab.${PUB_IP}.nip.io/health"

smoke_one () {
  local url="$1"
  echo "[SMOKE] $url"
  local tries=0
  until curl -fsS "$url" >/dev/null; do
    tries=$((tries+1))
    if [ "$tries" -ge 30 ]; then
      echo "[SMOKE] FAIL url=$url"
      exit 1
    fi
    echo "[SMOKE] retry $tries"
    sleep 2
  done
  echo "[SMOKE] OK url=$url"
}

smoke_one "$url1"
smoke_one "$url2"

echo "[SMOKE] ALL OK"
