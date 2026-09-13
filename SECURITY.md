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

The template tracks current Docker Engine/Desktop with Compose v2 and Ubuntu 24.04. Users are responsible for applying vendor security updates. No long-term support promise is made for old Docker versions.

## Reporting a vulnerability

Do not include live credentials, private workspace data or working exploits against third-party infrastructure in a public issue. If this repository is published, replace this paragraph with the maintainer's private security-reporting channel (for example, GitHub private vulnerability reporting). Include the affected revision, platform, Docker version, reproduction steps and expected security property.

## Suspected containment failure

Stop the container, disconnect the host from sensitive networks if warranted, preserve relevant logs, rotate any credential that may have been reachable, and treat workspace data as compromised. Recreate the sandbox from a trusted revision; do not reuse the affected container or image cache for investigation without understanding the risk.
