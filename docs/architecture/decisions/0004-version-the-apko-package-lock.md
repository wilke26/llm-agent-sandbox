# ADR 0004: Version the apko package lock

- Status: Accepted
- Recorded: 2026-09-21
- Nature: Retrospective, reconstructed from PR 6 merged on 2026-09-16

## Context

Building against a moving package repository makes two builds from the same source resolve different package sets. apko also treats the supplied lock as the complete resolved package set, so a stale lock may omit a package newly added to the template.

## Decision

Commit `agent.apko.lock.json` and review its changes like dependency updates. A normal local apko build regenerates the lock before building. `--no-lock` is limited to reproducing or validating the already committed lock. The lock must be generated from the rendered configuration with the canonical CI UID/GID when used by CI.

Template changes and lock changes belong in the same reviewed change. The generated `agent.apko.yaml` remains ignored.

## Alternatives considered

- Resolving current packages on every build without a committed lock was rejected because builds would drift invisibly.
- Treating an existing lock as a partial constraint set was rejected because that is not how apko consumes it.

## Consequences

- Package versions and checksums are reviewable and reproducible.
- Refreshing dependencies produces a potentially large but auditable diff.
- The lock checksum is sensitive to the rendered configuration, including canonical UID/GID values and YAML content.
- A separate automation policy is needed to keep the lock current without bypassing review.

## Evidence

`scripts/build-agent-image-apko.sh`, `agent.apko.lock.json`, and the lock-regeneration commits included in `dafd928`.
