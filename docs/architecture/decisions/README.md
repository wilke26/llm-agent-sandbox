# Architecture decision records

ADRs record decisions that materially affect trust boundaries, portability, build reproducibility, or operational governance. Accepted decisions remain in the log even if later superseded.

| ADR | Decision | Status | Nature |
|---|---|---|---|
| [0001](0001-use-a-hardened-compose-runtime.md) | Use a hardened Docker Compose runtime | Accepted | Retrospective |
| [0002](0002-deny-runtime-egress-by-default.md) | Deny ordinary runtime egress by default | Accepted | Retrospective |
| [0003](0003-support-apko-with-an-ubuntu-fallback.md) | Support apko/Wolfi with an Ubuntu fallback | Accepted | Retrospective |
| [0004](0004-version-the-apko-package-lock.md) | Version the apko package lock | Accepted | Retrospective |
| [0005](0005-verify-controls-across-platforms.md) | Verify controls across platforms and architectures | Accepted | Retrospective |
| [0006](0006-refresh-apko-lock-through-reviewed-pull-requests.md) | Refresh the apko lock through reviewed pull requests | Proposed | Prospective |

## ADR format

Each ADR contains its status, recording date, context, decision, alternatives, and consequences. A retrospective ADR also names the repository evidence used to reconstruct it.
