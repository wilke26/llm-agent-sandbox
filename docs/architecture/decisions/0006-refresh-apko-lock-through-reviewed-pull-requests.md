# ADR 0006: Refresh the apko lock through reviewed pull requests

- Status: Accepted
- Recorded: 2026-09-21
- Accepted: 2026-09-21
- Nature: Prospective decision, implemented and operationally validated

## Context

The committed apko lock makes builds reproducible but does not make packages current. Refreshing it is currently a manual operation. Direct scheduled writes to the protected default branch would bypass the repository's review-oriented release process and could incorporate a faulty or compromised upstream update immediately.

## Proposed decision

Add `.github/workflows/refresh-apko-lock.yml`, running daily at 04:17 UTC with a manual-dispatch option. It will:

1. Install the pinned apko tool version and render the canonical configuration.
2. Regenerate `agent.apko.lock.json` from current Wolfi packages.
3. Exit without changes when the lock is unchanged.
4. Build the refreshed amd64 image and run the full isolation verification.
5. Fail if files other than the expected lock artifact change.
6. Commit an actual change to a fixed automation branch and create or update one pull request.
7. Require the existing protected-branch checks and human review before merge.

The workflow will use narrowly scoped repository permissions, SHA-pinned actions, concurrency control, and no `pull_request_target` execution. Checkout will not persist credentials during build and verification; the repository `GITHUB_TOKEN` is exposed only to the final branch and pull-request step. A narrowly scoped GitHub App is preferred later if token-generated pull-request workflow approval becomes operationally burdensome.

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

## Validation

The decision was implemented by [PR 9](https://github.com/wilke26/llm-agent-sandbox/pull/9). The first [manual workflow run](https://github.com/wilke26/llm-agent-sandbox/actions/runs/35604269130) completed successfully, rebuilt and verified the amd64 image, detected a real lock change, and created the dedicated update branch and pull request. The generated [PR 10](https://github.com/wilke26/llm-agent-sandbox/pull/10) passed the required checks and was reviewed and merged into `main`. A second [manual workflow run](https://github.com/wilke26/llm-agent-sandbox/actions/runs/35607796286) then verified the no-change path: the build and isolation checks passed and the commit/pull-request step was skipped.

These results satisfy the operational acceptance criteria.
