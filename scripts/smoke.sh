#!/usr/bin/env bash
set -euo pipefail

URL="${1:-}"
CONTAINER="${2:-}"

if [[ -z "${URL}" ]]; then
  echo "Usage: smoke.sh <url> [container]"
  exit 2
fi

tries=0
max=30
sleep_s=2

while true; do
  if curl -fsS "${URL}" >/dev/null; then
    echo "SMOKE_OK url=${URL}"
    exit 0
  fi

  tries=$((tries+1))
  if [[ "${tries}" -ge "${max}" ]]; then
    echo "SMOKE_FAIL url=${URL}"
    if [[ -n "${CONTAINER:-}" ]]; then
      docker logs --tail=200 "${CONTAINER}" || true
    fi
    exit 1
  fi

  echo "SMOKE_retry_${tries}"
  sleep "${sleep_s}"
done
