# Threat model

## Goal

Limit damage from faulty agent behavior, hostile instructions in processed content, malicious task files, and unexpected tool execution. The sandbox is designed for disposable local workloads whose only required persistent data is a dedicated workspace.

## Trust boundaries

- **Trusted:** host operating system, Docker installation/daemon, base image supply chain, Compose and start scripts.
- **Untrusted:** model output, websites and documents consumed by the model, commands produced by the agent, packages or repositories processed inside the workspace.
- **Explicitly exposed:** every file beneath `workspace/`, container CPU/memory, and any information intentionally copied into the image.
- **Not exposed by default:** host home directory, Docker socket, host credentials, ports, normal outbound network access, additional Linux capabilities.

## Primary threats and controls

| Threat | Default control | Residual risk |
|---|---|---|
| Host-file theft or modification | Only `./workspace` is mounted | Workspace data is fully exposed; kernel/runtime escapes remain possible |
| Network exfiltration | Docker internal network, no proxy or second network | Engine/runtime bugs and local-network implementation differences require defense in depth |
| Privilege escalation | Non-root user, all capabilities dropped, no-new-privileges, default seccomp | Containers are not VMs; kernel attack surface remains |
| Persistence | Read-only root, ephemeral tmpfs, disposable container | Agent can persist changes in the workspace |
| Resource exhaustion | CPU, memory, swap, PID and descriptor limits | Disk use in the bind-mounted workspace is not quota-limited |
| Host control via Docker | Docker socket is not mounted | Anyone with host Docker access already has highly privileged control |
| Supply-chain compromise | Small image and build-time package installation | Ubuntu packages and future additions must still be trusted and updated |

## Out of scope

- Protecting secrets deliberately placed in the workspace or image
- Defending a compromised Docker daemon or host kernel
- Multi-tenant isolation against determined hostile code
- Guaranteed anonymity, malware analysis, or forensic containment
- Browser automation, audio/video devices, GPUs, USB devices or host GUI access

## Assumptions to revisit

Update this document before adding mounts, `device` access, host networking, published ports, environment secrets, extra capabilities, privileged mode, a browser, a proxy, or a Docker socket. When adding a proxy, second network or any other egress path, reassess whether `curl` and `git` are necessary because both become direct retrieval and exfiltration tools. High-risk hostile-code workloads should use a dedicated VM or stronger runtime such as gVisor/Kata after compatibility testing.
