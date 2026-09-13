#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${REPO_DIR}"

require_docker() {
  command -v docker >/dev/null 2>&1 || {
    echo "Error: Docker is not installed or not on PATH." >&2
    exit 1
  }
  docker compose version >/dev/null 2>&1 || {
    echo "Error: Docker Compose v2 ('docker compose') is required." >&2
    exit 1
  }
  docker info >/dev/null 2>&1 || {
    echo "Error: the Docker daemon is not available." >&2
    exit 1
  }
}

prepare_repository() {
  if [[ ! -f .env ]]; then
    cp .env.example .env
    host_uid="$(id -u)"
    host_gid="$(id -g)"
    if [[ "$(uname -s)" == "Linux" ]] && (( host_uid >= 1000 )); then
      sed -i.bak -e "s/^AGENT_UID=.*/AGENT_UID=${host_uid}/" -e "s/^AGENT_GID=.*/AGENT_GID=${host_gid}/" .env
      rm -f .env.bak
      echo "Mapped the container user to host UID:GID ${host_uid}:${host_gid}."
    fi
    echo "Created .env from .env.example; review it before sensitive workloads."
  fi
  mkdir -p workspace
}
