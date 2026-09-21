# ADR 0006: Refresh the apko lock through reviewed pull requests

- Status: Proposed
- Recorded: 2026-09-21
- Nature: Prospective; implementation is intentionally pending

## Context

The committed apko lock makes builds reproducible but does not make packages current. Refreshing it is currently a manual operation. Direct scheduled writes to the protected default branch would bypass the repository's review-oriented release process and could incorporate a faulty or compromised upstream update immediately.

## Proposed decision

Add a daily scheduled GitHub Actions workflow with a manual-dispatch option. It will:

1. Install the pinned apko tool version and render the canonical configuration.
2. Regenerate `agent.apko.lock.json` from current Wolfi packages.
3. Exit without changes when the lock is unchanged.
4. Build the refreshed amd64 image and run the full isolation verification.
5. Fail if files other than the expected lock artifact change.
6. Commit an actual change to a fixed automation branch and create or update one pull request.
7. Require the existing protected-branch checks and human review before merge.

The workflow will use least-privilege repository permissions, SHA-pinned actions, concurrency control, and no `pull_request_target` execution. The initial implementation should use the repository `GITHUB_TOKEN`; a narrowly scoped GitHub App is preferred later if token-generated pull-request workflow approval becomes operationally burdensome.

This workflow updates the package lock. Publishing a final OCI image and pinning its registry digest is a separate future decision.

## Alternatives considered

- Direct commits to `main` are rejected because they conflict with branch protection and remove the review gate.
- A new branch and PR for every daily run is rejected because concurrent stale PRs would accumulate.
- Keeping the process entirely manual remains safe but makes security updates easy to postpone unnoticed.

## Consequences

- Dependency drift becomes visible as a reviewable pull request with an audit trail.
- No-change days produce no repository noise.
- Upstream failures or suspicious lock diffs cannot alter the default branch automatically.
- A maintainer remains responsible for reviewing and merging updates.
- Workflow credentials and repository settings become part of the trusted automation boundary.

## Acceptance criteria

This ADR may move to Accepted only after the workflow is merged into the default branch, a no-change run is observed, a changed-lock PR is created or updated successfully, and all image and isolation checks pass on that PR.
