# Security policy

## Safe use

This repository provides defense in depth, not an absolute sandbox. Use a patched Docker Engine/Desktop and host OS. Inspect changes before rebuilding, keep sensitive data out of `workspace/`, and run the verification script after startup.

Never add any of the following merely to make a workload convenient:

- `privileged: true`
- the Docker/Podman socket
- the host root, home directory, SSH directory or credential stores
- host networking or an unrestricted second network
- `seccomp=unconfined` or AppArmor/SELinux disabling
- `SYS_ADMIN` on the general agent service

For workloads that actively execute unknown or hostile binaries, use a disposable VM or a separately evaluated stronger runtime in addition to these controls.

## Supported versions

The template tracks current Docker Engine/Desktop with Compose v2. The optional apko build uses locked Wolfi packages; the documented fallback uses a digest-pinned Ubuntu 24.04 base image. Users are responsible for reviewing lock and digest updates and applying vendor security updates. No long-term support promise is made for old Docker versions.

## Swap-accounting limitation

The configured `memswap_limit` is effective only when the Docker host or Docker Desktop VM exposes working cgroup swap accounting. Some Linux hosts disable it at boot, and Docker versions may reject the container, warn, or retain the requested configuration without enforcing it. The verification scripts therefore check both Docker's `MemorySwap` setting and the active kernel cgroup: `memory.swap.max` must be `0` on cgroup v2, while the finite `memory.memsw.limit_in_bytes` and `memory.limit_in_bytes` values must match on cgroup v1. Missing, unreadable or inconsistent controller files fail verification. Do not treat the sandbox as swap-constrained until this check passes.

## Reporting a vulnerability

Do not include live credentials, private workspace data or working exploits against third-party infrastructure in a public issue. If this repository is published, replace this paragraph with the maintainer's private security-reporting channel (for example, GitHub private vulnerability reporting). Include the affected revision, platform, Docker version, reproduction steps and expected security property.

## Suspected containment failure

Stop the container, disconnect the host from sensitive networks if warranted, preserve relevant logs, rotate any credential that may have been reachable, and treat workspace data as compromised. Recreate the sandbox from a trusted revision; do not reuse the affected container or image cache for investigation without understanding the risk.
