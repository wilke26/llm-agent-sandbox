#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_docker
prepare_repository

agent_image="$(docker compose config --images | sed -n '1p')"
if [[ -z "${agent_image}" ]]; then
  echo "Error: Docker Compose did not resolve an image for the agent service." >&2
  exit 1
fi

if docker image inspect "${agent_image}" >/dev/null 2>&1; then
  echo "Using existing agent image: ${agent_image}"
  docker compose up --detach --no-build --remove-orphans agent
else
  echo "Agent image ${agent_image} is not present; building the Dockerfile fallback."
  docker compose up --detach --build --remove-orphans agent
fi
echo "Sandbox started. Run ./scripts/verify.sh before use."
