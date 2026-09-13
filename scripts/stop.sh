#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_docker
docker compose down --remove-orphans
echo "Sandbox container and isolated network removed; workspace files were retained."
