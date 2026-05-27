---
name: Infrastructure
type: architecture-decision
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "human-only", "adr-0086", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0086", "ADR-0005", "ADR-0006"]
accepts: []
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Create the honeydrunk-review-worker GitHub App and provision its credentials in Vault

## Summary
Create a new GitHub App `honeydrunk-review-worker` under the `HoneyDrunkStudios` org with the minimum permissions ADR-0086 D4 specifies (`pull_requests: write`, `issues: write`, `contents: read`), install it on `HoneyDrunk.Architecture` for Phase A, write its app-id / installation-id / private-key into HoneyDrunk.Vault per ADR-0005, and author the walkthrough doc that records the portal steps so the provisioning is repeatable and auditable. The Cloudflare Tunnel hostname for review traffic is **not** removed in this packet — that decommission is packet 08 at Phase A → Phase B cutover.

## Context
ADR-0086 D4 commits the pull-based worker to authenticate as a **dedicated GitHub App** rather than the operator's `gh` CLI session. The reasons are codified in D4: scope reduction (the operator's PAT can do anything; the App's installation token is bounded), audit trail clarity (`honeydrunk-review-worker[bot]` shows up in PR timelines), ADR-0006 rotation alignment (installation tokens auto-rotate every hour from the App's private key), no `gh` session expiry surprises, rate-limit separation, and future multi-worker support.

This is the credential-and-infrastructure prerequisite for the worker build (packet 03) and the label+comment workflow rewrite (packet 05). It is portal-heavy: GitHub App creation, private key generation, Azure Key Vault writes, and installation are all manual. Marked **`Actor=Human`** because the entire work item is portal/manual provisioning with no delegable code artifact — the walkthrough doc itself is a record of the work the operator performed, not the work itself.

**Permission scope.** ADR-0086 D4 enumerates exactly three permissions: `pull_requests: write` (for label swaps, queue comment edits, verdict posts), `issues: write` (because GitHub treats labels and PR comments under issues APIs), and `contents: read` (for the PR diff and repo checkout the worker performs locally). The App is **not** granted any write access to repo contents — the worker never pushes commits. The App is installed only on `enabled` repos (`HoneyDrunk.Architecture` for Phase A; expanded in Phase B/C per D11). The operator's `gh` CLI auth on the worker host is unchanged; it may still be present for interactive use but the worker uses the App installation token exclusively (D4 "Auth surfaces").

## Scope
- A new GitHub App `honeydrunk-review-worker` created under the `HoneyDrunkStudios` org, with `pull_requests: write`, `issues: write`, `contents: read`, installed on `HoneyDrunk.Architecture` only.
- HoneyDrunk.Vault (the Azure Key Vault for the CI/automation surface, per ADR-0005) receives: the GitHub App ID, the GitHub App private key, and the GitHub App installation ID — all named per the convention in the walkthrough.
- A new walkthrough doc, `infrastructure/walkthroughs/honeydrunk-review-worker-github-app.md`, recording every portal step.

## Proposed Implementation

### GitHub App
1. Create a GitHub App under HoneyDrunkStudios: **Settings → Developer settings → GitHub Apps → New GitHub App**.
2. Name: `honeydrunk-review-worker` (per ADR-0086 D4 recommended name).
3. Permissions:
   - **Repository → Pull requests: Read and write** (label swaps, verdict comment posts, queue-comment edits per ADR-0086 D2/D3).
   - **Repository → Issues: Read and write** (the GitHub API groups labels and PR comments under issues endpoints).
   - **Repository → Contents: Read** (the worker checks out the target repo locally to read the diff; no write needed because the worker never pushes commits).
   - **No webhook subscriptions.** The App is used only for installation-token minting; the worker pulls from GitHub via the polling cadence in D4. The "Webhook" section of the App config should be left empty (no URL, no secret) — this is one of the architectural differences from ADR-0044's webhook-bridge App.
4. Generate a private key (`.pem`). Note the App ID printed on the App's settings page.
5. Install the App on `HoneyDrunkStudios/HoneyDrunk.Architecture` only ("Only select repositories"). Note the installation ID from the URL after install (`/settings/installations/{id}`).

### Vault storage (per ADR-0005, invariant 9)
Store all three values as secrets in the Key Vault that serves the CI/automation surface (the same Vault that holds ADR-0044's `review-agent-github-app-*` secrets from the previous review-runner work — the Vault location is the existing CI-surface Key Vault; the walkthrough records its exact name from the infrastructure inventory):

- `review-worker-github-app-id`
- `review-worker-github-app-private-key`
- `review-worker-github-app-installation-id`

Per invariant 9, Vault is the only source of secrets — no Node reads these from env vars or config files directly. The local worker (packet 03) resolves them at tick startup, exchanges them for a 1-hour installation token via `POST /app/installations/{installation_id}/access_tokens`, and uses the resulting short-lived token for the tick. The local worker runs on the home server (per ADR-0081 D1) and reads from Vault via the operator's authenticated Azure CLI session or an equivalent Vault-CLI binding — the walkthrough documents the chosen path.

### Rotation (per ADR-0006)
- **Installation tokens auto-rotate every hour** from the App's private key. This is the App's native key-rotation flow and is one of the explicit reasons D4 commits to the App rather than a PAT.
- **The App's private key itself** has no SLA-bound rotation but should be regenerable; the walkthrough documents the regeneration procedure (generate a new key in the App's settings, write the new value into Vault under the same secret name, delete the old key entry in the App's settings — the worker picks up the new key on the next tick because it re-reads from Vault each tick).

### Walkthrough doc
`infrastructure/walkthroughs/honeydrunk-review-worker-github-app.md` records every step above with exact portal navigation, exact secret names, and the rotation disposition. Cross-link it from the worker packet (03), the label+comment workflow packet (05), and the decommission packet (08). Follow the shape of the existing `infrastructure/walkthroughs/github-app-hive-walkthrough.md` for layout consistency.

### What this packet does NOT do
- Does **not** touch ADR-0044's existing `review-agent-github-app-*` Vault secrets — those served the OpenClaw webhook bridge and are not re-used here. The webhook-signing secret rotation is the decommission packet 08's concern.
- Does **not** remove the Cloudflare Tunnel hostname `grid-review.honeydrunkstudios.com` (or equivalent) — that's packet 08 at Phase A → Phase B cutover (ADR-0086 D10).

## Affected Files
- `infrastructure/walkthroughs/honeydrunk-review-worker-github-app.md` (new)
- `CHANGELOG.md`

## NuGet Dependencies
None. This packet creates infrastructure and a Markdown walkthrough; no .NET project is created or modified.

## Boundary Check
- [x] The walkthrough doc lives in `HoneyDrunk.Architecture/infrastructure/walkthroughs/` — the established home for portal-step walkthroughs (matches `github-app-hive-walkthrough.md`, `key-vault-creation.md`, etc.).
- [x] The GitHub App is an org-level resource, not repo code.
- [x] Vault is the secret store per invariant 9 — no secret committed to any repo.
- [x] App permissions are exactly the three D4 enumerates; no webhook subscription; installation scoped to Phase-A repos only.

## Acceptance Criteria
- [ ] A GitHub App named `honeydrunk-review-worker` exists under `HoneyDrunkStudios` with **exactly** `pull_requests: write`, `issues: write`, `contents: read` permissions and **no** webhook configuration
- [ ] The App is installed on `HoneyDrunkStudios/HoneyDrunk.Architecture` only ("Only select repositories")
- [ ] All three secrets are stored in the CI-surface Key Vault with the exact names listed above (`review-worker-github-app-id`, `review-worker-github-app-private-key`, `review-worker-github-app-installation-id`)
- [ ] `infrastructure/walkthroughs/honeydrunk-review-worker-github-app.md` exists and records every portal step, every secret name, and the private-key regeneration procedure
- [ ] The walkthrough cross-links to packet 03 (worker), packet 05 (label+comment workflow), and packet 08 (decommission)
- [ ] No secret value appears in any committed file (invariant 8)
- [ ] CHANGELOG.md updated noting the walkthrough creation

## Human Prerequisites
- [ ] Create the GitHub App in the `HoneyDrunkStudios` org portal with exactly the three permissions and no webhook subscription
- [ ] Generate the App's private key (`.pem`) and capture the App ID
- [ ] Install the App on `HoneyDrunk.Architecture` only; capture the installation ID
- [ ] Write the three secrets into the CI-surface Azure Key Vault with the exact names listed above
- [ ] Pay any Azure Key Vault transaction charges (Vault writes are de minimis but operator covers them)
- [ ] Cross-reference the existing ADR-0044 `review-agent-github-app-*` secrets in Vault: do NOT delete or rotate them in this packet (packet 08 handles the webhook-signing secret rotation at cutover)

## Dependencies
- `packet:01` — ADR-0086 acceptance (soft; this packet's text references ADR-0086 D4 / D10 as live rules).

## Referenced ADR Decisions

**ADR-0086 D4** — Dedicated GitHub App named `honeydrunk-review-worker`, installed on the org and granted only to `enabled` repos. Minimum permissions: `pull_requests: write`, `issues: write`, `contents: read`. App's private signing key stored in HoneyDrunk.Vault per ADR-0005 / ADR-0006. Worker exchanges it for a 1-hour installation token at the start of each tick. The operator's personal `gh` CLI auth is not used by the worker.

**ADR-0086 D10** — At Phase A → Phase B cutover, the ADR-0044 webhook-signing secret is rotated out and the `grid-review.honeydrunkstudios.com` Cloudflare Tunnel hostname is removed. **This packet does not perform either of those actions** — it provisions only the new App. Packet 08 handles the cutover work.

**ADR-0086 Affected Nodes — HoneyDrunk.Vault** — One new secret is provisioned: the `honeydrunk-review-worker` GitHub App's private signing key (plus app-id and installation-id). The worker reads it at tick startup, exchanges it for an installation token via `POST /app/installations/{installation_id}/access_tokens`, and uses the resulting short-lived token for the tick. Rotation is the App's native key-rotation flow per ADR-0006.

**ADR-0005** — Per-Node Vault model; secrets resolved via `ISecretStore`; never hardcoded.

**ADR-0006** — Secret rotation discipline. Installation tokens auto-rotate every hour from the App's private key; the private key itself has no SLA-bound rotation but must be regenerable.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced.

> **Invariant 9:** Vault is the only source of secrets. No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception. The App's installation tokens are 1-hour-lived and rotate natively (well inside any SLA); the App's private key has no SLA-bound rotation but the regeneration procedure must be documented (the walkthrough is the documented procedure).

- **App permissions stay exactly minimal.** Three permissions, no webhook, no other scope. Adding permissions later requires an ADR amendment or a follow-up packet.
- **Installation scoped to Phase-A repos only.** `HoneyDrunk.Architecture` today; Phase B/C expansions happen via the App-installation portal at those phase boundaries — they are not part of this packet.
- **Do not commit any secret.** Secret values live in Vault.
- **Do not touch ADR-0044's `review-agent-github-app-*` secrets** in this packet. They served the old OpenClaw webhook bridge; their rotation is packet 08's concern.
- **Do not remove the Cloudflare Tunnel hostname** in this packet. Packet 08 handles the decommission at Phase A → Phase B cutover.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `human-only`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** This is an `Actor=Human` packet. Provision the `honeydrunk-review-worker` GitHub App, write its three credentials into Vault, and author the walkthrough doc that records every portal step.

**Target:** `HoneyDrunk.Architecture` (for the walkthrough doc); GitHub org portal and Azure portal (for the provisioning).

**Context:**
- Goal: Provide the worker (packet 03) and the label+comment workflow (packet 05) with the App credentials they need.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A.
- ADRs: ADR-0086 (primary, D4 + Affected Nodes), ADR-0005 (Vault storage), ADR-0006 (rotation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0086 acceptance (soft).

**Constraints:**
- GitHub App permissions exactly minimal (three, no webhook, no other scope); installation scoped to `HoneyDrunk.Architecture` only.
- Vault is the only secret store (invariant 9); no secret committed anywhere (invariant 8).
- Do not touch ADR-0044's existing `review-agent-github-app-*` secrets; packet 08 handles that rotation.
- Do not remove the Cloudflare Tunnel hostname; packet 08 handles that decommission.

**Key Files:**
- `infrastructure/walkthroughs/honeydrunk-review-worker-github-app.md` (new)
- `CHANGELOG.md`

**Contracts:** None.
