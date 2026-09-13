# LLM Agent Sandbox

[Deutsche Version](README.de.md)

This repository is a reusable, deliberately small sandbox for running an LLM agent with terminal access. It limits the blast radius; it is **not** a perfect security boundary. Containers share a kernel on native Linux, and any mounted data must be treated as readable and writable by the agent.

## Security properties

- No default internet route (`internal: true` network)
- Non-root user (`10001:10001`)
- Read-only root filesystem; small, ephemeral `tmpfs` mounts
- All Linux capabilities dropped and no-new-privileges enabled
- CPU, memory, process and file-descriptor limits
- Exactly one bind mount: `./workspace` at `/workspace`
- No Docker socket, host home directory, secrets or published ports
- Disposable container lifecycle and automated isolation checks
- Docker's maintained default seccomp profile (see [Seccomp guidance](seccomp/README.md))

## Prerequisites

| Platform | Requirements and notes |
|---|---|
| Linux | Docker Engine 24+ with Compose v2. Rootless Docker or user-namespace remapping is recommended. Resource limits depend on cgroup support. |
| macOS | Current Docker Desktop with Compose v2. Linux containers run inside Docker Desktop's VM. File sharing must permit this repository directory. |
| Windows | Current Docker Desktop using the WSL2 backend and **Linux containers**. Clone into the WSL filesystem for better performance, or allow drive sharing for a Windows path. Run the Bash scripts in WSL/Git Bash, or use the PowerShell scripts. |

Podman may work with its Compose compatibility layer, but it is not tested by this template.

## Quick start

1. Copy `.env.example` to `.env` and review the resource limits.
2. Put only disposable/non-sensitive task files in `workspace/`.
3. Start and verify the sandbox:

**macOS/Linux/WSL/Git Bash**

```bash
./scripts/start.sh
./scripts/verify.sh
./scripts/shell.sh
```

**Windows PowerShell**

```powershell
./scripts/Start.ps1
./scripts/Verify.ps1
./scripts/Shell.ps1
```

Stop and remove the disposable container with `./scripts/stop.sh` or `./scripts/Stop.ps1`. Workspace files remain on the host.

## Operating model

The long-running service only sleeps so that tools can attach with `docker compose exec`. Replace neither `command` nor the security controls casually. To run a command directly:

```bash
docker compose run --rm agent python3 -c 'print("hello from the sandbox")'
```

The internal network prevents ordinary outbound access. If the workload needs downloads, prefer preparing dependencies in the image at build time. For controlled runtime access, add a separately reviewed allowlisting proxy rather than attaching the agent to a normal network. Do not pass credentials the agent can read unless disclosure is an accepted consequence.

## Browser/computer-use workloads

Browser automation is intentionally not bundled. Chromium adds packages, shared-memory requirements and a separate sandbox model. Create a separate image and Compose override for it. Do **not** add `SYS_ADMIN` to this general-purpose agent service. Prefer a browser image that supports an unprivileged user and its own sandbox; increase `/dev/shm` only for that service.

## Platform-specific adjustments

- On SELinux hosts, append `:Z` to the workspace bind mount in a local Compose override if labeling blocks access. Do not commit that change when the repository is shared with macOS/Windows users.
- Docker Desktop resource limits are also capped globally in Desktop settings. The lower effective limit wins.
- Bind-mount ownership differs across hosts. The fixed UID/GID works directly on Linux; Docker Desktop translates host file access. If Linux files are not writable, set `AGENT_UID` and `AGENT_GID` to the owner of `workspace/`, then rebuild.
- `timeout` is not required: the container is stopped explicitly and resource-constrained. Use external job timeouts in CI/automation for a hard wall-clock limit.

## Customization checklist

Before adding packages, mounts, networks or credentials, update [the threat model](docs/THREAT-MODEL.md). Keep the workspace narrow, rebuild rather than installing at runtime, pin critical dependencies, and rerun verification after every security-relevant change.

See [SECURITY.md](SECURITY.md) for limitations and incident handling, and [CONTRIBUTING.md](CONTRIBUTING.md) before proposing changes.

## License

MIT — see [LICENSE](LICENSE).
