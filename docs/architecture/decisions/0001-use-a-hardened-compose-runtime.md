# ADR 0001: Use a hardened Docker Compose runtime

- Status: Accepted
- Recorded: 2026-09-21
- Nature: Retrospective, reconstructed from the initial repository state of 2026-09-13

## Context

An LLM agent may execute incorrect or hostile commands. The environment must be reusable on Linux, macOS, and Windows without presenting a container as an absolute security boundary.

## Decision

Use one Docker Compose service as the shared runtime enforcement point. Run it as a fixed non-root UID/GID with a read-only root filesystem, all Linux capabilities dropped, no-new-privileges enabled, constrained tmpfs mounts, and limits for CPU, memory, memory-plus-swap, PIDs, and file descriptors.

Expose exactly one persistent bind mount: the dedicated workspace at `/workspace`. Do not expose the Docker socket, host home directory, secrets, devices, or ports by default. Keep the container disposable and verify the effective controls after startup.

## Alternatives considered

- Running the agent directly on the host was rejected because it provides no narrow filesystem or process boundary.
- A privileged or broadly mounted development container was rejected because convenience would defeat the primary containment goal.
- A VM-only design was not selected as the portable default because of operational weight, though a VM remains recommended for stronger hostile-code isolation.

## Consequences

- The same Compose controls apply to every supported image.
- Workspace data must be treated as fully accessible to the agent.
- Native Linux still shares the host kernel; Docker Desktop relies on its VM boundary.
- Workloads needing additional privileges require separate review rather than weakening the default service.

## Evidence

Initial `compose.yaml`, `README.md`, `SECURITY.md`, `docs/THREAT-MODEL.md`, and verification scripts in commit `1e7941a`.
