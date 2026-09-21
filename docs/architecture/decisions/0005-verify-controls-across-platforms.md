# ADR 0005: Verify controls across platforms and architectures

- Status: Accepted
- Recorded: 2026-09-21
- Nature: Retrospective, reconstructed from changes made between 2026-09-13 and 2026-09-16

## Context

Static Compose configuration does not prove that Docker, the host kernel, cgroups, mounts, or the built image enforce the intended properties. The template supports Bash-oriented platforms and Windows PowerShell, while local development and CI may use different CPU architectures.

## Decision

Maintain equivalent Bash and PowerShell verification for mandatory runtime properties. Inspect the running container and active cgroup state, including explicit handling of cgroup v1, cgroup v2, and unlimited `memory.swap.max`.

Run the general Dockerfile validation in GitHub Actions and add a dedicated Ubuntu 24.04 amd64 job that builds the committed apko lock, confirms the image architecture, starts the sandbox, and executes the full isolation verification. Local host-architecture testing remains complementary.

## Alternatives considered

- Validating only `docker compose config` was rejected because effective runtime state may differ.
- Maintaining only Bash verification was rejected because PowerShell is a supported Windows entry point.
- Relying only on an ARM/macOS local build was rejected because consumers may use native amd64 Linux.

## Consequences

- Configuration errors, platform differences, and image-content gaps fail before merge.
- Bash and PowerShell checks form a parity pair and must be updated together.
- AppArmor/SELinux and rootless/user-namespace reporting remain warnings because platform reporting differs; mandatory containment properties fail closed.

## Evidence

Commits `1772dc3`, `522193d`, `542c082`, `7b01de7`, `2be3df6`, and `dafd928`, plus the two workflows under `.github/workflows/`.
