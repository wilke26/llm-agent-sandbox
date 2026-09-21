# Container and build view

## Runtime view

```mermaid
flowchart TB
    scripts[Start, stop, shell, and verify scripts\nBash and PowerShell]
    compose[Docker Compose model]
    service[agent container\nnon-root, read-only rootfs]
    tmpfs[tmpfs\n/tmp and agent cache]
    workspace[bind mount\n./workspace to /workspace]
    network[isolated internal network]
    engine[Docker Engine or Desktop VM]

    scripts --> compose
    compose --> engine
    engine --> service
    service --> tmpfs
    service <--> workspace
    service --> network
```

There is one long-running service. Its `sleep infinity` command keeps the hardened container available for `docker compose exec`; it is not an application server. The service exposes no port and has no restart policy.

The Compose model is the common enforcement point for both image-build paths. An image already present under `AGENT_IMAGE` is reused. If it is absent, the start scripts build the Dockerfile fallback.

## Image-build view

```mermaid
flowchart LR
    template[agent.apko.yaml.tmpl]
    env[.env UID and GID]
    render[build-agent-image-apko.sh]
    config[generated agent.apko.yaml\nignored]
    lock[agent.apko.lock.json\ncommitted]
    apko[apko package image]
    patch[small Docker patch layer\nfix bash executable mode]
    apkoimage[local apko/Wolfi agent image]

    dockerfile[Ubuntu 24.04 Dockerfile\ndigest-pinned base]
    fallback[Docker fallback build]
    ubuntuimage[local Ubuntu agent image]

    template --> render
    env --> render
    render --> config
    config -->|resolve packages| lock
    config --> apko
    lock --> apko
    apko --> patch --> apkoimage

    dockerfile --> fallback --> ubuntuimage
    apkoimage --> compose[common Compose runtime]
    ubuntuimage --> compose
```

### apko/Wolfi path

- The template is rendered with the same UID/GID that Compose uses at runtime.
- A normal build refreshes the committed package lock before building.
- `--no-lock` is reserved for reproducing and validating the committed lock.
- apko supplies the minimal package filesystem. A small Docker layer corrects the executable mode of Wolfi's packaged Bash, because this installation path does not run the package trigger that normally performs that correction.
- CI builds and runs this path on native amd64; local builds use the host architecture.

### Ubuntu fallback

- The base image identity is pinned by digest while remaining on Ubuntu 24.04.
- Package installation still resolves against Ubuntu repositories at build time and is therefore less reproducible than the locked apko path.
- It remains available for systems without apko and as a comprehensible recovery path during the transition.

Both outputs must pass the same runtime verification before use.
