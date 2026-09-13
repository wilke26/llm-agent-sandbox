# Seccomp guidance

This template intentionally uses Docker Engine's built-in default seccomp profile. With no `seccomp=` override, Docker applies its maintained allowlist profile and adapts it to the daemon/runtime and architecture. This is more portable and normally safer than a short custom denylist whose default action is to allow unknown system calls.

## When to create a custom profile

Create one only for a stable, narrowly defined workload and test it separately for every supported CPU architecture, browser/runtime and Docker Engine version. A profile copied from another host can break on arm64 versus amd64, or silently become stale as applications begin using newer system calls.

Recommended process:

1. Confirm `seccomp` appears under `docker info` security options.
2. Obtain the default profile matching the deployed Docker Engine version from the upstream Moby source tree.
3. Record required system calls from representative test runs in a non-production environment.
4. Tighten the matching default allowlist; do not replace it with an allow-by-default denylist.
5. Review high-risk calls including `bpf`, `clone3`, `keyctl`, `mount`, `perf_event_open`, `ptrace`, `reboot`, `unshare` and namespace-related clone flags. Some are already blocked or argument-filtered by Docker's default profile.
6. Save the reviewed file as `seccomp/agent-seccomp.json`, then add a **local** Compose override:

```yaml
services:
  agent:
    security_opt:
      - no-new-privileges:true
      - seccomp=./seccomp/agent-seccomp.json
```

7. Run the complete workload test suite and `scripts/verify.sh` or `scripts/Verify.ps1`.

Never set `seccomp=unconfined` to solve an application error without an explicit risk review. Browser workloads need their own profile and service; do not weaken the general agent service.
