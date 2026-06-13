---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "human-only", "adr-0086", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0086", "ADR-0044", "ADR-0005", "ADR-0006"]
accepts: []
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Audit and reuse the existing review-agent GitHub App for the local automation runner

## Summary
Audit the existing ADR-0044 review-agent GitHub App and store its credentials in the shared ADR-0086 automation Vault, confirm it can serve the local runner framework, widen only the minimum permissions needed for the label/comment queue if required, and author the walkthrough doc that records the resulting configuration. This packet **does not create a second GitHub App by default**. A new App is only allowed if the existing ADR-0044 App cannot safely be amended, and that exception must be documented in the walkthrough and PR body.

The Cloudflare Tunnel hostname for review traffic is **not** removed in this packet; that decommission remains packet 08 at Phase A -> Phase B cutover.

## Context
ADR-0086 D4 commits the pull-based worker to authenticate as a GitHub App rather than the operator's `gh` CLI session. The operator already has the ADR-0044 review-agent GitHub App set up from the previous review-agent process. Reusing that identity keeps the audit trail continuous and avoids needless portal churn. Because ADR-0086 now owns a broader runner framework (review, post-merge audit, hive-sync, and Lore jobs), the App credentials are stored in the shared automation Vault rather than under a review-only Vault name.

This is still a human-heavy packet because GitHub App permissions, installation scope, private-key rotation, and Vault secret verification are portal/secret-store work. Marked **`Actor=Human`** because the core work is configuration and verification; the committed artifact is the walkthrough that records what was checked and changed.

**Permission scope.** ADR-0086 D4 requires the worker path to have `pull_requests: write`, `issues: write`, and `contents: read`. If the existing review-agent App already has additional repo-content write permission for the ADR-0044 D9 audit-artifact path, document why it exists and keep the installation scope bounded to enabled repos. Do not introduce broad content-write scope for the queue worker itself.

## Scope
- Existing ADR-0044 review-agent GitHub App audited for name, bot identity, permissions, webhook settings, and installation scope.
- Existing Vault secrets audited and documented:
  - `GitHub--AgentRunner--AppId`
  - `GitHub--AgentRunner--PrivateKey`
  - `GitHub--AgentRunner--InstallationId`
- Shared automation Vault documented:
  - Subscription: `honeydrunk-dev`
  - Resource group: `rg-hd-automation-dev`
  - Key Vault: `kv-hd-automation-dev`
- Existing App permissions widened only if needed to satisfy ADR-0086 D4 (`pull_requests: write`, `issues: write`, `contents: read`).
- Existing App installed on `HoneyDrunk.Architecture` for Phase A and later expanded only to enabled repos per ADR-0086 D11.
- New walkthrough doc, `infrastructure/walkthroughs/review-agent-github-app-local-worker.md`, recording the portal audit, any permission changes, Vault secret names, and rotation procedure.

## Proposed Implementation

### GitHub App audit
1. Open the existing ADR-0044 review-agent GitHub App under `HoneyDrunkStudios`.
2. Record the App name, App ID, bot identity shown in PR timelines, and whether webhook delivery is still configured for the legacy path.
3. Verify repository permissions:
   - **Repository -> Pull requests: Read and write**.
   - **Repository -> Issues: Read and write**.
   - **Repository -> Contents: Read** for the worker path.
4. If any required permission is missing, amend the existing App and record the change. Do not add unrelated permissions.
5. Verify the installation is limited to `HoneyDrunk.Architecture` for Phase A. Phase B/C installation expansion happens later through ADR-0086 rollout packets.

### Vault secret audit
Verify the shared automation Key Vault contains the normalized GitHub App credential triplet:

- `GitHub--AgentRunner--AppId`
- `GitHub--AgentRunner--PrivateKey`
- `GitHub--AgentRunner--InstallationId`

The worker in packet 03 reads these names from `kv-hd-automation-dev` unless the walkthrough documents an explicit exception. Per invariant 9, Vault is the only source of App credentials. No worker config file, environment variable, PR comment, or log may contain secret values.

### Rotation
- **Installation tokens auto-rotate every hour** from the App private key.
- **The App private key** must remain regenerable. The walkthrough records the regeneration procedure: create a new key in the App settings, write the new value to Vault under the same secret name, verify packet 03 can mint a token, then delete the old key in GitHub.
- The ADR-0044 webhook-signing secret is not rotated here; packet 08 handles that at review-path cutover.

### Walkthrough doc
`infrastructure/walkthroughs/review-agent-github-app-local-worker.md` records:

- Existing App identity and why it is reused.
- Exact permission state before and after the audit.
- Exact installation scope.
- Exact Vault secret names, without values.
- Token-minting smoke-test command shape, without printing tokens.
- Private-key regeneration procedure.
- Cross-links to packet 03 (worker), packet 05 (label/comment workflow), and packet 08 (decommission).

Follow the shape of existing infrastructure walkthroughs for layout consistency.

### What this packet does NOT do
- Does **not** create `honeydrunk-review-worker` by default.
- Does **not** create new `review-worker-github-app-*` Vault secrets by default.
- Does **not** use the legacy ADR-0044 `review-agent-github-app-*` secret names for new runner setup.
- Does **not** remove the Cloudflare Tunnel hostname or webhook bridge. Packet 08 owns decommission.

## Affected Files
- `infrastructure/walkthroughs/review-agent-github-app-local-worker.md` (new)
- `CHANGELOG.md`

## NuGet Dependencies
None. This packet creates infrastructure documentation; no .NET project is created or modified.

## Boundary Check
- [x] The walkthrough doc lives in `HoneyDrunk.Architecture/infrastructure/walkthroughs/`.
- [x] GitHub App configuration remains an org-level resource, not repo code.
- [x] Vault is the secret store per invariant 9; no secret is committed.
- [x] App permissions are limited to the ADR-0086 worker path plus any already-documented ADR-0044 audit-artifact need.

## Acceptance Criteria
- [ ] Existing ADR-0044 review-agent GitHub App is audited and selected for the ADR-0086 worker path, or the walkthrough documents why reuse was unsafe
- [ ] App permissions satisfy `pull_requests: write`, `issues: write`, `contents: read`; any extra permission is documented with its ADR/packet reason
- [ ] App installation is scoped to `HoneyDrunk.Architecture` for Phase A
- [ ] `kv-hd-automation-dev` contains `GitHub--AgentRunner--AppId`, `GitHub--AgentRunner--PrivateKey`, and `GitHub--AgentRunner--InstallationId`; no review-only `review-worker-github-app-*` secret triplet is created unless reuse is explicitly rejected
- [ ] `infrastructure/walkthroughs/review-agent-github-app-local-worker.md` records every portal step, every secret name, and the private-key regeneration procedure
- [ ] The walkthrough cross-links to packet 03, packet 05, and packet 08
- [ ] No secret value appears in any committed file
- [ ] CHANGELOG.md updated noting the App reuse audit/walkthrough

## Human Prerequisites
- [ ] Inspect the existing ADR-0044 review-agent GitHub App in the `HoneyDrunkStudios` org portal
- [ ] Amend App permissions only if needed for ADR-0086 D4
- [ ] Verify installation scope for `HoneyDrunk.Architecture`
- [ ] Verify the three `GitHub--AgentRunner--*` secrets in `kv-hd-automation-dev`
- [ ] Confirm the worker host can read those Vault secrets through the chosen Vault CLI binding
- [ ] Do not create a second App unless the existing App cannot safely be amended

## Dependencies
- `work-item:01` — ADR-0086 acceptance.

## Referenced ADR Decisions

**ADR-0086 D4** — Local worker authenticates via a GitHub App installation token, not the operator's `gh` CLI session. ADR-0086 now reuses the existing ADR-0044 review-agent App where possible.

**ADR-0086 D10** — At Phase A -> Phase B cutover, the ADR-0044 webhook-signing secret is rotated out and the Cloudflare Tunnel hostname is removed. This packet does not perform either action.

**ADR-0044** — Existing review-agent GitHub App originated from the prior review-runner work and is reused by this packet where safe.

**ADR-0005 / ADR-0006** — Per-Node Vault model and secret-rotation discipline.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, telemetry, docs, or PR comments.

> **Invariant 9:** Vault is the only source of secrets.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception.

- **Reuse first.** Do not create a second review-worker App unless the existing App cannot safely serve the worker.
- **Minimum permissions.** Widen only to `pull_requests: write`, `issues: write`, and `contents: read` for the worker path unless an existing ADR-0044 audit-artifact reason is documented.
- **Installation scoped to Phase-A repos only.** Expansion waits for Phase B/C.
- **Do not remove the Cloudflare Tunnel hostname** in this packet.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `human-only`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Audit and reuse the existing ADR-0044 review-agent GitHub App for ADR-0086. Verify permissions, installation scope, normalized automation Vault secret names, and rotation procedure; author `infrastructure/walkthroughs/review-agent-github-app-local-worker.md`.

**Target:** `HoneyDrunk.Architecture` for the walkthrough; GitHub org portal and Azure portal for verification.

**Context:** This is the credential prerequisite for packet 03's worker and packet 05's enqueue workflow.

**Acceptance Criteria:** As listed above.

**Key Files:**
- `infrastructure/walkthroughs/review-agent-github-app-local-worker.md` (new)
- `CHANGELOG.md`
