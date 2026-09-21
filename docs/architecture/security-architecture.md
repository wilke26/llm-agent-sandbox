# Security architecture

## Security model

The design assumes that model output, processed documents, task files, and commands executed by the agent may be hostile. It limits their reachable resources while treating the host, Docker daemon, container runtime, repository configuration, and reviewed build inputs as trusted.

The controls are layered so that a single configuration mistake is less likely to expose the host silently. Verification observes the running container rather than relying only on static configuration.

## Control map

| Objective | Preventive control | Runtime verification | Residual risk |
|---|---|---|---|
| Prevent container root use | Fixed non-root UID/GID in image and Compose | Inspect configured user and execute `id -u` | Kernel/runtime vulnerabilities remain |
| Limit privilege escalation | Drop all capabilities; enable no-new-privileges; Docker default seccomp | Inspect capability and `NoNewPrivs` state; require daemon seccomp support | Docker's default profile is not workload-specific |
| Protect container filesystem | Read-only root filesystem; `noexec,nosuid,nodev` tmpfs | Attempt a write beneath `/etc` | tmpfs and workspace remain writable by design |
| Limit host-file access | Exactly one bind mount at `/workspace` | Inspect all mount destinations | Workspace has no disk quota and is fully exposed |
| Block ordinary exfiltration | Exactly one non-attachable internal network; no ports | Inspect network and attempt outbound HTTPS | A runtime or engine flaw can bypass assumptions |
| Limit resource exhaustion | CPU, memory, swap, PID, and descriptor limits | Compare Docker limits and active cgroup swap state | Host disk usage through workspace is not bounded |
| Avoid daemon takeover | Never mount Docker/Podman socket | Mount allowlist check | Anyone with host Docker access is already privileged |
| Reduce persistence | Disposable container, read-only root, ephemeral tmpfs | Lifecycle and filesystem checks | Agent may persist changes in workspace |
| Reduce supply-chain drift | Digest-pinned Ubuntu base; committed apko package lock; SHA-pinned actions | CI rebuilds and runs the resulting image | Registries, build tools, and package signing remain trusted dependencies |

## Verification policy

`scripts/verify.sh` and `scripts/Verify.ps1` are security controls, not convenience smoke tests. A failed mandatory check means the sandbox has not established its expected security properties and must not be trusted for the workload.

The two implementations must remain behaviorally aligned. Platform-specific reporting differences for rootless/user namespaces and AppArmor/SELinux are warnings because Docker Desktop may provide a separate VM boundary or report the feature differently. Seccomp, non-root execution, filesystem restrictions, cgroup swap enforcement, network isolation, mount restrictions, and workspace writability are mandatory.

## Supply-chain lifecycle

Build-time dependency retrieval is intentionally separated from runtime execution. The runtime container has no ordinary egress. Lock and digest changes are reviewable repository changes and must pass the relevant image build plus the full isolation verification.

The proposed daily apko refresh will create or update a pull request rather than write to the protected default branch. Until that decision is implemented, lock refreshes remain manual. See [ADR 0006](decisions/0006-refresh-apko-lock-through-reviewed-pull-requests.md).

## Escalation points

A new ADR and threat-model update are required before adding any normal egress route, proxy, additional mount, device, credential, browser, extra capability, privileged mode, or Docker socket. Hostile-binary analysis and strong multi-tenant isolation require a separately evaluated VM or stronger sandbox runtime.
