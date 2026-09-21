# Architecture

This documentation explains the current architecture of the LLM Agent Sandbox. It complements the operational guidance in the root README, the [security policy](../../SECURITY.md), and the [threat model](../THREAT-MODEL.md).

Most initial decisions were reconstructed on 2026-09-21 from repository history, pull requests, CI results, and review notes. Retrospective ADRs are marked accordingly; they describe the rationale visible in that evidence without pretending that an ADR existed when the original decision was made.

## Purpose and quality goals

The repository provides a small, reusable execution environment for LLM agents with terminal access. Its primary goals, in order, are:

1. Limit access to the host and network by default.
2. Make the effective isolation controls observable and testable.
3. Work on Linux, macOS, and Windows with Docker Compose.
4. Keep image construction reviewable and reproducible.
5. Remain small enough that security-relevant changes can be understood in one review.

The sandbox is defense in depth, not a VM-grade security boundary. The host OS, Docker daemon, container runtime, and image supply chain remain trusted dependencies.

## Views

- [System context](system-context.md) — users, external systems, and trust boundaries
- [Container and build view](container-view.md) — runtime components and the two image paths
- [Security architecture](security-architecture.md) — controls, verification, and residual risks
- [Architecture decisions](decisions/README.md) — decision log and status

## Architectural invariants

Changes must preserve these properties unless a reviewed ADR explicitly replaces them:

- The agent runs as a non-root user with all Linux capabilities dropped.
- The root filesystem is read-only; only the dedicated workspace is persistent and writable.
- The agent has exactly one internal Docker network and no ordinary outbound route.
- No Docker socket, host home directory, credentials, device, or host port is exposed by default.
- Memory, memory-plus-swap, CPU, PID, and file-descriptor limits are configured.
- Bash and PowerShell verification cover the same security properties.
- Image changes and dependency locks are reviewed and validated before entering the protected default branch.

## Change process

Update the relevant view and ADR when a change alters a trust boundary, build path, persistent mount, network path, privilege, supported platform, or dependency-update policy. Update the threat model before adding egress, credentials, devices, browsers, extra mounts, or privileged runtime features.
