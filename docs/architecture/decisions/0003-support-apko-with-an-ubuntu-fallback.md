# ADR 0003: Support apko/Wolfi with an Ubuntu fallback

- Status: Accepted
- Recorded: 2026-09-21
- Nature: Retrospective, reconstructed from PR 6 merged on 2026-09-16

## Context

The original Ubuntu image is familiar and widely buildable, but its packages are resolved dynamically during `apt` installation. A smaller, locked package image improves reproducibility and reviewability, while not every user environment has apko installed.

## Decision

Support two image-build paths behind the same Compose runtime:

1. Prefer a Wolfi package image built from `agent.apko.yaml.tmpl` and `agent.apko.lock.json` when apko is available.
2. Retain the digest-pinned Ubuntu 24.04 Dockerfile as a documented fallback.

The start scripts reuse an existing `AGENT_IMAGE`; otherwise they build the fallback. Both image paths must pass the same isolation verification. The generated `agent.apko.yaml` is a build artifact and is not committed.

## Alternatives considered

- Replacing the Dockerfile immediately was rejected because it would remove a portable recovery path before the apko path had broader operational history.
- Keeping only Ubuntu was rejected because it does not provide the same package-locking model.
- Maintaining separate runtime Compose services was rejected because security controls could drift between images.

## Consequences

- Users can adopt apko without losing the Docker-native fallback.
- The project temporarily carries two build implementations.
- The apko image needs a small post-build layer to correct the packaged Bash executable mode.
- Behavioral parity is enforced at runtime rather than inferred from package lists.

## Evidence

Commit `dafd928` (`Add optional apko-based agent image build (#6)`), including the apko template, build script, start-script selection logic, documentation, and amd64 validation workflow.
