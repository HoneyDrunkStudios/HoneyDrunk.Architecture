---
name: GitHub App + Key Vault Provisioning (Human Portal)
type: human-prerequisite
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "infrastructure", "human-only", "adr-0085", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0085", "ADR-0005", "ADR-0006"]
accepts: []
source: strategic
generator: scope
wave: 1
initiative: adr-0085-docs-sync
node: honeydrunk-architecture
---

# Register the `docs-sync` GitHub App + provision `kv-hd-docs-sync-prod` (HUMAN-ONLY portal work)

## Summary
`Actor=Human`. Portal-only provisioning: register a new GitHub App named `docs-sync` under the `HoneyDrunkStudios` organization with the minimal permissions ADR-0085 D4 names (Contents: read+write, Pull requests: read+write, Metadata: read), install it on every Grid repo, store the App's private key + App ID + installation ID in a new Key Vault `kv-hd-docs-sync-prod` per ADR-0005 naming, configure rotation per ADR-0006 Tier 2, and capture the App ID + KV name + secret names + paths in a hand-off note for packet 01b. **No commits, no files, no PRs in this packet.** The walkthrough doc documenting this work is split into packet 01b (`Actor=Agent`).

**This packet stands up agent infrastructure, not a Node.** Per ADR-0082 packet 01's "operator-internal automation infrastructure carve-out," the `docs-sync` agent's GitHub App + `kv-hd-docs-sync-prod` Key Vault are operator-internal automation infrastructure governed by ADR-0085 and ADR-0005, not by ADR-0082's Node-standup invariant (102). The ten-item Node-registration checklist does not bind this packet's deliverables.

## Context
ADR-0085 D4 (the PAT-scope and secret-management subsection) names the GitHub App as the **recommended** PAT-replacement path and explicitly rejects classic PAT on the operator account on blast-radius and audit-posture grounds. App-installation tokens auto-rotate (1-hour lifetime), do not consume PAT inventory, are auditable per-installation in the org audit log, and survive operator rotation. The fallback (fine-grained PAT on a dedicated `tatteddev-bot` machine user) is documented as a temporary measure with a follow-up packet to migrate to the App pattern.

This packet is **portal-heavy human work**: GitHub App creation, private key generation, App installation, Azure Key Vault provisioning (new vault `kv-hd-docs-sync-prod`), Key Vault RBAC assignments, secret writes, and rotation configuration are all manual portal steps that an agent has no API path into. The deliverable of this packet is the App + the vault + the captured IDs/names handed off to packet 01b. Packet 01b authors the walkthrough doc that documents what 01a actually did (so the walkthrough records concrete IDs, paths, and choices rather than placeholder text).

## Scope
- A new GitHub App `docs-sync` (or the operator's chosen canonical name) registered under the `HoneyDrunkStudios` org.
- Installation of the App on every Grid repo under `HoneyDrunkStudios/HoneyDrunk.*`.
- A new Key Vault `kv-hd-docs-sync-prod` per ADR-0005's `kv-hd-{service}-{env}` convention.
- Three secrets in `kv-hd-docs-sync-prod`: `docs-sync-github-app-id`, `docs-sync-github-app-private-key`, `docs-sync-github-app-installation-id`.
- Diagnostic settings on `kv-hd-docs-sync-prod` routed to the shared Log Analytics workspace (invariant 22).
- RBAC: operator `Key Vault Secrets Officer`; OpenClaw runtime identity `Key Vault Secrets User`.
- The App private key rotation disposition (Tier-2 automated rotator path OR a logged Log Analytics exception with a calendar reminder).

**Not in scope for this work-item:** the walkthrough doc itself. That lives in packet 01b.

## Proposed Implementation

### Pre-check: name collision
Before naming, the operator confirms:
- No existing `docs-sync` GitHub App exists on the `HoneyDrunkStudios` org.
- No existing `docs-sync` GitHub App exists on the operator's personal account.

If either exists, use the fallback name `honeydrunk-docs-sync` and record the canonical name in the hand-off note. Cross-link the same fallback into packet 01b so the walkthrough records the actual name used.

### GitHub App registration
1. **Settings → Developer settings → GitHub Apps → New GitHub App** under the HoneyDrunkStudios org.
2. Name: `docs-sync` (or `honeydrunk-docs-sync` if collision).
3. Permissions per ADR-0085 D4:
   - **Repository → Contents:** Read and write (the agent commits doc edits to feature branches before opening PRs)
   - **Repository → Pull requests:** Read and write (the agent opens and updates PRs)
   - **Repository → Metadata:** Read (default; required for any GitHub App)
4. No webhook needed (the App is used only for installation-token minting).
5. Generate a private key (`.pem`). Note the App ID.
6. **Install the App on the HoneyDrunkStudios org** — choose "All repositories" so future Grid repos are picked up automatically without a re-install pass.
7. Note the installation ID.

### Key Vault creation
1. Create `kv-hd-docs-sync-prod` in the appropriate Azure subscription per ADR-0005, with Azure RBAC enabled. Access policies are forbidden per invariant 17.
2. Naming: `kv-hd-docs-sync-prod` is 19 characters — well under the 24-character limit (invariant 19). `docs-sync` is 9 chars — well under the 13-char service-name cap.
3. Diagnostic settings routed to the shared Log Analytics workspace per invariant 22. Use the `infrastructure/walkthroughs/log-analytics-workspace-and-alerts.md` playbook.
4. RBAC: grant the operator `Key Vault Secrets Officer` for provisioning, and grant the OpenClaw execution surface's managed identity (or service principal) `Key Vault Secrets User` so the runtime can read the secrets. Use the `infrastructure/walkthroughs/key-vault-rbac-assignments.md` playbook.

### Secret writes
Store all three values as secrets in `kv-hd-docs-sync-prod`:
- `docs-sync-github-app-id` (numeric App ID)
- `docs-sync-github-app-private-key` (the `.pem` contents)
- `docs-sync-github-app-installation-id` (numeric installation ID)

Per invariant 9, Vault is the only source of secrets. The agent's `Bash` invocations of `gh pr create` resolve the installation token at runtime by minting it from the App ID + private key + installation ID at the start of each run.

### Rotation (per ADR-0006)
- The GitHub App **installation token** is short-lived (1 hour) and auto-rotated by GitHub; no SLA work needed on the token itself.
- The GitHub App **private key** is the long-lived secret subject to standard SLAs. Per ADR-0085 D4, rotate per **ADR-0006 Tier 2** (third-party rotation SLA ≤ 90 days; invariant 20).
- Configure rotation via the existing Tier-2 rotation path (HoneyDrunk.Vault.Rotation), or log a documented rotation-SLA exception in Log Analytics with a calendar reminder. **Record the disposition in the hand-off note** so packet 01b records it in the walkthrough.

### Hand-off note for packet 01b
The operator captures the following in a brief note attached to this packet's close comment (and pasted into packet 01b's open issue body):
- Canonical App name (`docs-sync` or `honeydrunk-docs-sync`).
- App ID.
- KV name (`kv-hd-docs-sync-prod` confirmed).
- Three secret names (verbatim).
- Installation ID (or org-wide "All repositories" confirmed).
- Rotation disposition (automated rotator OR logged exception + calendar reminder).
- RBAC assignments performed.

These are inputs packet 01b authors the walkthrough against. Do NOT paste any secret VALUE into the note — only names/IDs/paths/dispositions.

## Affected Files
**None.** This packet creates no commits, no files, no PRs.

## NuGet Dependencies
None.

## Boundary Check
- [x] The GitHub App and Key Vault are org/external resources, not repo code.
- [x] Vault is the secret store per invariant 9 — no secret value is committed to any repo (no commits are produced).
- [x] The App's `Contents: Write` + `Pull requests: Write` scope is across all `HoneyDrunkStudios` repos — necessary for the agent's Grid-wide reconciliation mandate, bounded by per-phase auto-fix scope (D8).

## Acceptance Criteria
- [ ] A GitHub App named `docs-sync` (or recorded canonical name) exists under the `HoneyDrunkStudios` org with permissions: Contents read+write, Pull requests read+write, Metadata read; no webhook
- [ ] The App is installed on the org with "All repositories" selected
- [ ] Key Vault `kv-hd-docs-sync-prod` exists with Azure RBAC enabled (access policies forbidden per invariant 17)
- [ ] Diagnostic settings on `kv-hd-docs-sync-prod` routed to the shared Log Analytics workspace (invariant 22)
- [ ] Three secrets stored in `kv-hd-docs-sync-prod` with the exact names: `docs-sync-github-app-id`, `docs-sync-github-app-private-key`, `docs-sync-github-app-installation-id`
- [ ] The OpenClaw execution surface's identity has `Key Vault Secrets User` RBAC on `kv-hd-docs-sync-prod`
- [ ] The App private key's rotation disposition is recorded (automated rotator path OR a logged Log Analytics exception with a calendar reminder)
- [ ] No secret value appears in any committed file (invariant 8) — N/A here because this packet produces no commits
- [ ] Hand-off note captured with the canonical App name, App ID, KV name, secret names, installation ID, rotation disposition, and RBAC assignments — pasted into packet 01b's issue body so 01b's walkthrough records concrete values

## Human Prerequisites
- [ ] Operator confirms no existing `docs-sync` GitHub App on the HoneyDrunkStudios org or on the operator's personal account before naming. Fallback name: `honeydrunk-docs-sync`.
- [ ] Operator creates the GitHub App in the HoneyDrunkStudios org portal and generates its private key.
- [ ] Operator installs the GitHub App on the HoneyDrunkStudios org with "All repositories" selected.
- [ ] Operator provisions Key Vault `kv-hd-docs-sync-prod` in the appropriate Azure subscription (Azure RBAC enabled, no access policies).
- [ ] Operator wires Log Analytics diagnostic settings on the new vault (invariant 22).
- [ ] Operator writes the three secrets into `kv-hd-docs-sync-prod` with the exact names listed in Scope.
- [ ] Operator assigns `Key Vault Secrets User` RBAC on the new vault to the OpenClaw execution surface's identity.
- [ ] Operator configures or documents the App private key rotation per ADR-0006 Tier 2.
- [ ] Operator confirms the App-installation token can be minted manually (e.g., a short curl-based JWT exchange test from the operator's workstation) before declaring this packet done.
- [ ] Operator captures the hand-off note and pastes it into packet 01b's issue body.

## Dependencies
- `work-item:01` — soft. ADR-0085 must be Accepted (packet 01) so the App is provisioned against a clearly defined consumer.

## Referenced ADR Decisions

**ADR-0085 D4 (PAT-scope and secret-management subsection)** — GitHub App installation token is the recommended path (1-hour lifetime, auto-rotated, auditable per-installation, survives operator rotation).
**ADR-0085 D8 Phase 1** — GitHub App registration is a discrete Phase-1 subtask.
**ADR-0005** — Key Vault naming convention `kv-hd-{service}-{env}`. RBAC-enabled; access policies forbidden.
**ADR-0006 Tier 2** — Third-party secret rotation SLA ≤ 90 days.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. (Applies to the hand-off note: names/IDs/paths only, never secret values.)

> **Invariant 9:** Vault is the only source of secrets.

> **Invariant 17:** One Key Vault per deployable Node per environment. Named `kv-hd-{service}-{env}`, with Azure RBAC enabled.

> **Invariant 19:** Service names in Azure resource naming must be ≤ 13 characters. (`docs-sync` is 9 chars; fits.)

> **Invariant 20:** No secret may exceed its tier's rotation SLA without an active exception.

> **Invariant 22:** Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.

- **GitHub App permissions stay minimal:** Contents read+write, Pull requests read+write, Metadata read. No webhook, no other permission scope.
- **Do not commit any secret.** Secret values live in Vault; the agent resolves them at run start. No commit is produced by this packet anyway.
- **App installation is org-wide ("All repositories")** — deliberate choice; blast-radius offset by per-phase auto-fix scope discipline (D8) + per-PR `pr-core` gate.
- **No code, no commit, no PR.** This is portal work only. The agent who runs this packet (a human) closes it with a manual GitHub-issue close, not a PR merge.

## Labels
`chore`, `tier-2`, `meta`, `infrastructure`, `human-only`, `adr-0085`, `wave-1`

## Agent Handoff

**Objective:** `Actor=Human` packet. The operator registers the GitHub App, provisions `kv-hd-docs-sync-prod`, writes the three secrets, wires RBAC + diagnostics, configures rotation, and captures the hand-off note. No code is authored; no commit is produced.

**Target:** HoneyDrunkStudios org portal + Azure portal (for the App + Vault provisioning). No repo target — this packet produces no commits.

**Context:**
- Goal: Stand up the infrastructure substrate (App + Vault + secrets + RBAC + rotation disposition) so packet 01b can author the walkthrough doc against concrete IDs and paths, and packet 02 (Phase 2 — cross-repo PR authority) can mint installation tokens at runtime.
- Feature: Grid-Wide Documentation Currency Agent rollout, Phase 1 (App provisioning, human portion).
- ADRs: ADR-0085 (primary, D4 PAT-scope + D8 Phase 1), ADR-0005 (Vault naming + RBAC), ADR-0006 (rotation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — soft (ADR accepted before App is provisioned against a clearly defined consumer).

**Constraints:**
- App permissions minimal: Contents/PRs read+write, Metadata read. No webhook.
- Vault is the only secret store (invariant 9); no secret committed anywhere (invariant 8) — N/A here because no commits.
- App private key rotation SLA ≤ 90 days or a logged exception (invariants 20 + 22).
- Org-wide installation ("All repositories") is deliberate; blast-radius offset by per-phase auto-fix scope.

**Key Files:** None — portal work only.

**Contracts:** None.
