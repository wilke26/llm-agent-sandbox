#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_docker
prepare_repository
docker compose up --detach --build --remove-orphans agent
echo "Sandbox started. Run ./scripts/verify.sh before use."
