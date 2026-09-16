#!/usr/bin/env bash
# Styled after scripts/start.sh + scripts/_common.sh in
# wilke26/llm-agent-sandbox. Builds the agent image from
# agent.apko.yaml.tmpl instead of dockerfiles/agent/Dockerfile, and loads
# it straight into the local Docker daemon so compose.yaml can use it
# unchanged.
#
# Fully build- and runtime-verified end-to-end on 2026-09-16 (macOS/
# aarch64, apko 1.4.1 + Docker Desktop): bash, sh, git, curl, coreutils
# (head/id), python3+venv+pip-wheel all confirmed working in the running
# container, AGENT_UID/AGENT_GID mapping confirmed via `id`.
#
# Background on the patch layer below: Wolfi's bash apk installs
# /usr/bin/bash with mode 0000 (apko skips apk post-install
# scripts/triggers by design - see agent.apko.yaml.tmpl's comment on this
# - and bash's package apparently relies on one to fix its own
# permissions). A `type: permissions` apko paths entry does NOT fix this
# (confirmed: changes the layer digest, not the actual mode bits). So this
# script chmods it in a small `docker build` patch layer after the apko
# build instead - exec-form RUN, no shell needed, since /bin/sh is the
# same broken bash underneath until this patch runs. Confirmed working:
# /usr/bin/bash is -rwxr-xr-x after this step.
#
# Usage:
#   ./scripts/build-agent-image-apko.sh            # normal build, re-locks
#                                                    # every time (see below)
#   ./scripts/build-agent-image-apko.sh --no-lock   # skip re-locking, build
#                                                    # from the existing
#                                                    # agent.apko.lock.json
#                                                    # as-is (fast/offline)
#
set -Eeuo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

require_docker

case "${1:-}" in
    ""|--no-lock) ;;
    *)
        echo "Usage: $0 [--no-lock]" >&2
        exit 2
        ;;
esac

if ! command -v apko >/dev/null 2>&1; then
    echo "apko not found on PATH." >&2
    echo "Install: brew install apko" >&2
    echo "     or: go install chainguard.dev/apko@latest" >&2
    echo "     or: download a release from https://github.com/chainguard-dev/apko/releases" >&2
    exit 1
fi

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="${REPO_ROOT}/agent.apko.yaml.tmpl"
CONFIG="${REPO_ROOT}/agent.apko.yaml"
LOCKFILE="${REPO_ROOT}/agent.apko.lock.json"

# Read AGENT_UID/AGENT_GID from .env - the same file _common.sh's
# prepare_repository() writes the host UID/GID into on Linux - so the
# account baked into this image always matches compose.yaml's
# `user: "${AGENT_UID}:${AGENT_GID}"` override at container start. Without
# this, an image built on a Linux host with a non-default host UID would
# silently mismatch compose.yaml's runtime user, breaking permissions on
# the bind-mounted ./workspace and /home/agent/.cache.
ENV_FILE="${REPO_ROOT}/.env"
if [[ -f "${ENV_FILE}" ]]; then
    AGENT_UID="$(sed -n 's/^AGENT_UID=//p' "${ENV_FILE}" | tail -n1 | tr -d '\r')"
    AGENT_GID="$(sed -n 's/^AGENT_GID=//p' "${ENV_FILE}" | tail -n1 | tr -d '\r')"
fi
AGENT_UID="${AGENT_UID:-10001}"
AGENT_GID="${AGENT_GID:-10001}"

if [[ ! "${AGENT_UID}" =~ ^[1-9][0-9]*$ ]]; then
    echo "AGENT_UID must be a positive integer, got: ${AGENT_UID}" >&2
    exit 1
fi
if [[ ! "${AGENT_GID}" =~ ^[1-9][0-9]*$ ]]; then
    echo "AGENT_GID must be a positive integer, got: ${AGENT_GID}" >&2
    exit 1
fi

echo "Rendering ${TEMPLATE##*/} -> ${CONFIG##*/} (AGENT_UID=${AGENT_UID}, AGENT_GID=${AGENT_GID})"
sed -e "s/__AGENT_UID__/${AGENT_UID}/g" -e "s/__AGENT_GID__/${AGENT_GID}/g" \
    "${TEMPLATE}" > "${CONFIG}"

# agent.apko.lock.json pins exact resolved package versions - the apko
# equivalent of the @sha256 digest-pinning already used for the
# ubuntu:24.04 base image. IMPORTANT: `apko publish --lockfile` treats the
# lock file as the *complete* package set, not just a version constraint on
# packages it already knows about - a package added to the .tmpl but
# missing from an existing lock file is silently dropped, no error. So this
# re-locks on every run by default (the safe default after hitting that
# exact bug); pass --no-lock only when you're sure the lock file already
# matches agent.apko.yaml.tmpl and want to skip the network round-trip.
if [[ "${1:-}" != "--no-lock" ]]; then
    echo "Resolving + locking package versions -> ${LOCKFILE##*/}"
    apko lock "${CONFIG}" --output "${LOCKFILE}"
    echo "Commit ${LOCKFILE##*/} like any other dependency bump."
elif [[ ! -f "${LOCKFILE}" ]]; then
    echo "No ${LOCKFILE##*/} yet and --no-lock given - can't skip the first lock. Run without --no-lock once." >&2
    exit 1
fi

AGENT_IMAGE="${AGENT_IMAGE:-llm-agent-sandbox:local}"
HOST_ARCH="$(uname -m)"
case "${HOST_ARCH}" in
    x86_64) APKO_ARCH="x86_64" ;;
    arm64|aarch64) APKO_ARCH="aarch64" ;;
    *)
        echo "Unrecognized host architecture: ${HOST_ARCH}" >&2
        exit 1
        ;;
esac

BASE_IMAGE="${AGENT_IMAGE}-apko-base"
echo "Building + loading ${BASE_IMAGE} (${APKO_ARCH}) into the local Docker daemon..."
apko publish --local \
    --arch "${APKO_ARCH}" \
    --lockfile "${LOCKFILE}" \
    "${CONFIG}" \
    "${BASE_IMAGE}"

# Patch layer: fix /usr/bin/bash's permissions (see the long comment
# above). Exec-form RUN (JSON array), not shell form - shell form would
# `/bin/sh -c chmod ...`, and /bin/sh is a symlink to this same broken
# bash until this very step runs.
echo "Patching ${BASE_IMAGE} -> ${AGENT_IMAGE} (fixing /usr/bin/bash permissions)..."
# `docker build -t tag -` with no PATH/URL sends only the piped Dockerfile,
# no build context - there's nothing to COPY here, so no context needed.
docker build -t "${AGENT_IMAGE}" - <<EOF
FROM ${BASE_IMAGE}
USER root
RUN ["/usr/bin/chmod", "0755", "/usr/bin/bash"]
USER agent
EOF

echo "Done. The start scripts will prefer the existing ${AGENT_IMAGE} image."
echo "If that image is absent, compose.yaml retains dockerfiles/agent/Dockerfile as a fallback."
echo "Next: run scripts/verify.sh against this image before trusting it."
