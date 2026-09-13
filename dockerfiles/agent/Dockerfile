# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG AGENT_UID=10001
ARG AGENT_GID=10001

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && (getent group "${AGENT_GID}" >/dev/null || groupadd --gid "${AGENT_GID}" agent) \
    && useradd --uid "${AGENT_UID}" --gid "${AGENT_GID}" \
        --create-home --shell /bin/bash agent \
    && mkdir -p /workspace /home/agent/.cache \
    && chown -R "${AGENT_UID}:${AGENT_GID}" /workspace /home/agent

USER agent
WORKDIR /workspace

CMD ["sleep", "infinity"]
