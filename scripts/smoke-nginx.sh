#!/usr/bin/env bash
set -euo pipefail

PUB_IP="${1:?usage: smoke-nginx.sh <PUB_IP>}"

url1="https://cicd-github.${PUB_IP}.nip.io/health"
url2="https://cicd-gitlab.${PUB_IP}.nip.io/health"

echo "[SMOKE] $url1"
tries=0
until curl -kfsS "$url1" >/dev/null; do
  tries=$((tries+1))
  if [ "$tries" -ge 30 ]; then
    echo "[SMOKE] FAIL url=$url1"
    exit 1
  fi
  echo "[SMOKE] retry $tries"
  sleep 2
done

echo "[SMOKE] $url2"
tries=0
until curl -kfsS "$url2" >/dev/null; do
  tries=$((tries+1))
  if [ "$tries" -ge 30 ]; then
    echo "[SMOKE] FAIL url=$url2"
    exit 1
  fi
  echo "[SMOKE] retry $tries"
  sleep 2
done

echo "[SMOKE] OK"
