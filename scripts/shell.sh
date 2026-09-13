#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_docker
container_id="$(docker compose ps --quiet agent)"
if [[ -z "${container_id}" ]]; then
  echo "Error: the sandbox is not running. Run ./scripts/start.sh first." >&2
  exit 1
fi
exec docker compose exec agent bash
