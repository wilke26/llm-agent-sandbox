#!/usr/bin/env bash
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_docker
container_id="$(docker compose ps --quiet agent)"
if [[ -z "${container_id}" ]]; then
  echo "Error: the sandbox is not running. Run ./scripts/start.sh first." >&2
  exit 1
fi

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1" >&2; }
fail() { printf 'FAIL  %s\n' "$1" >&2; failures=$((failures + 1)); }

configured_user="$(docker inspect --format '{{.Config.User}}' "${container_id}")"
if [[ -n "${configured_user}" ]] \
  && [[ ! "${configured_user}" =~ ^(root|0+)(:.*)?$ ]] \
  && docker compose exec -T agent sh -c 'test "$(id -u)" -ne 0'; then
  pass "process runs as non-root"
else
  fail "process must run as non-root"
fi

if [[ "$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "${container_id}")" == "true" ]] \
  && ! docker compose exec -T agent sh -c 'touch /etc/agent-sandbox-write-test' >/dev/null 2>&1; then
  pass "root filesystem is read-only"
else
  fail "root filesystem must be read-only"
fi

read -r memory_limit memory_swap_limit < <(
  docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}' "${container_id}"
)
if [[ "${memory_limit}" =~ ^[1-9][0-9]*$ ]] && [[ "${memory_swap_limit}" == "${memory_limit}" ]]; then
  pass "memory and memory-plus-swap limits match (swap disabled)"
else
  fail "memory-plus-swap limit must equal memory limit (Memory=${memory_limit:-unknown}, MemorySwap=${memory_swap_limit:-unknown})"
fi

cap_eff="$(docker compose exec -T agent sh -c "awk '/CapEff/ {print \$2}' /proc/1/status" | tr -d '\r')"
if [[ "${cap_eff}" =~ ^0+$ ]]; then
  pass "effective Linux capabilities are empty"
else
  fail "effective Linux capabilities must be empty (CapEff=${cap_eff:-unknown})"
fi

no_new_privs="$(docker compose exec -T agent sh -c "awk '/NoNewPrivs/ {print \$2}' /proc/1/status" | tr -d '\r')"
if [[ "${no_new_privs}" == "1" ]]; then
  pass "no-new-privileges is active"
else
  fail "no-new-privileges must be active"
fi

security_options="$(docker info --format '{{json .SecurityOptions}}')"
if grep -qi 'seccomp' <<<"${security_options}"; then
  pass "Docker daemon reports seccomp support"
else
  fail "Docker daemon must report seccomp support"
fi

if grep -Eqi 'rootless|userns' <<<"${security_options}"; then
  pass "Docker daemon reports rootless or user-namespace isolation"
else
  warn "Docker daemon does not report rootless/userns isolation; Docker Desktop may provide a separate VM boundary"
fi

if grep -Eqi 'apparmor|selinux' <<<"${security_options}"; then
  pass "Docker daemon reports AppArmor or SELinux support"
else
  warn "Docker daemon does not report AppArmor/SELinux; this protection may be unavailable or reported differently"
fi

network_ids=()
while IFS= read -r network_id; do
  [[ -n "${network_id}" ]] && network_ids+=("${network_id}")
done < <(docker inspect --format '{{range .NetworkSettings.Networks}}{{println .NetworkID}}{{end}}' "${container_id}")
all_internal=true
for network_id in "${network_ids[@]}"; do
  [[ "$(docker network inspect --format '{{.Internal}}' "${network_id}")" == "true" ]] || all_internal=false
done
if (( ${#network_ids[@]} == 1 )) && [[ "${all_internal}" == "true" ]]; then
  pass "the only attached network is internal"
else
  fail "agent must have exactly one internal network"
fi

if ! docker compose exec -T agent curl --fail --silent --show-error --max-time 5 https://example.com >/dev/null 2>&1; then
  pass "ordinary outbound HTTPS is blocked"
else
  fail "outbound HTTPS unexpectedly succeeded"
fi

mounts="$(docker inspect --format '{{range .Mounts}}{{println .Destination}}{{end}}' "${container_id}" | sed '/^$/d')"
if [[ "${mounts}" == "/workspace" ]]; then
  pass "workspace is the only bind/volume mount"
else
  fail "unexpected bind/volume mount destinations: ${mounts:-none}"
fi

marker=".sandbox-write-test-${RANDOM}"
if docker compose exec -T agent sh -c "touch '/workspace/${marker}' && rm '/workspace/${marker}'"; then
  pass "workspace is writable"
else
  fail "workspace must be writable"
fi

if (( failures > 0 )); then
  printf '\nIsolation verification failed: %d check(s).\n' "${failures}" >&2
  exit 1
fi
printf '\nIsolation verification passed.\n'
