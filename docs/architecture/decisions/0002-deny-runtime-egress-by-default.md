# ADR 0002: Deny ordinary runtime egress by default

- Status: Accepted
- Recorded: 2026-09-21
- Nature: Retrospective, reconstructed from the initial repository state of 2026-09-13

## Context

An agent with network access can retrieve unreviewed code, communicate with attacker-controlled services, and exfiltrate workspace data or credentials. Most intended tasks can prepare dependencies at image-build time.

## Decision

Attach the agent to exactly one Docker network configured as internal and non-attachable. Publish no ports and provide no normal second network. Verify both the network topology and failure of an ordinary outbound HTTPS request.

If runtime connectivity becomes necessary, design a separately reviewed allowlisting proxy and reassess installed retrieval tools, credentials, and the threat model before enabling it.

## Alternatives considered

- Unrestricted bridge networking was rejected because it provides direct retrieval and exfiltration paths.
- Per-command network discipline was rejected because generated commands are not trusted to honor policy.

## Consequences

- Runtime package downloads and normal web access do not work by default.
- Dependencies should be incorporated during a reviewed image build.
- Browser and connected-agent workloads need a separate architecture rather than a casual Compose override.

## Evidence

Initial `compose.yaml`, `docs/THREAT-MODEL.md`, and `scripts/verify.sh` in commit `1e7941a`; explicit `attachable: false` and verification hardening in commit `522193d`.
