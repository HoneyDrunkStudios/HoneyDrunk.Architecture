---
name: docs-sync App Registration — Walkthrough Doc
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infrastructure", "adr-0085", "wave-1"]
dependencies: ["packet:01", "packet:01a"]
adrs: ["ADR-0085", "ADR-0005", "ADR-0006"]
accepts: []
source: strategic
generator: scope
wave: 1
initiative: adr-0085-docs-sync
node: honeydrunk-architecture
---

# Author `infrastructure/walkthroughs/docs-sync-github-app-registration.md` (AGENT, documents what 01a did)

## Summary
`Actor=Agent`. Author the walkthrough doc `infrastructure/walkthroughs/docs-sync-github-app-registration.md` that records the GitHub App + Key Vault provisioning work the operator completed in packet 01a. The walkthrough uses the **concrete IDs, paths, names, and dispositions captured in packet 01a's hand-off note** — not placeholder text. Cross-link the walkthrough from packet 02's body (Phase 2 enablement) and from the agent definition at `.claude/agents/docs-sync.md` (the "credentials" section).

**This packet documents agent infrastructure, not a Node.** Per ADR-0082 packet 01's "operator-internal automation infrastructure carve-out," the `docs-sync` GitHub App + Key Vault are operator-internal automation infrastructure governed by ADR-0085 and ADR-0005, not by ADR-0082's Node-standup invariant. This walkthrough lives alongside other operator-internal-infra walkthroughs (`key-vault-creation.md`, `key-vault-rbac-assignments.md`, `log-analytics-workspace-and-alerts.md`, `github-app-hive-walkthrough.md`).

## Context
ADR-0085 D4 commits the GitHub App pattern (1-hour auto-rotated installation tokens, auditable per-installation, no PAT inventory). Packet 01a (`Actor=Human`) provisions the App + Key Vault + secrets + RBAC + rotation disposition; this packet (`Actor=Agent`) authors the walkthrough that documents what 01a actually did, against the concrete values 01a captured in its hand-off note. The split is the simpler factoring than bundling portal work and walkthrough authoring in one human-only packet: human runs the portal, hands off the values, agent writes the doc.

## Scope
- `infrastructure/walkthroughs/docs-sync-github-app-registration.md` (new) — full walkthrough recording every portal step, every secret name, every RBAC assignment, the rotation disposition, and pointers to canonical playbooks.
- Optional: a one-line cross-link in `.claude/agents/docs-sync.md`'s "credentials" section pointing at the new walkthrough (only if 01a/01b land after the agent definition lands; if 01a/01b land first, the cross-link is added by packet 01).

## Proposed Implementation

### Author the walkthrough doc

1. Read packet 01a's hand-off note (canonical App name, App ID, KV name, secret names, installation ID, rotation disposition, RBAC assignments).
2. Create `infrastructure/walkthroughs/docs-sync-github-app-registration.md` with sections:

   **Preamble**
   - Purpose: documents the one-time provisioning of the `docs-sync` GitHub App + `kv-hd-docs-sync-prod` Key Vault for the ADR-0085 agent.
   - Status: post-execution record (the work was performed by the operator in packet 01a; this doc captures what was done).
   - Cross-links: ADR-0085 D4 (App pattern), ADR-0005 (KV naming/RBAC), ADR-0006 (rotation), the canonical playbooks named below.

   **GitHub App registration** (records the canonical name 01a chose, the exact permissions, the no-webhook decision, the App ID captured, the "All repositories" installation choice, the installation ID captured).

   **Key Vault provisioning** (records the canonical KV name `kv-hd-docs-sync-prod`, Azure RBAC enabled, the subscription chosen, the diagnostic-settings target Log Analytics workspace, the operator's `Key Vault Secrets Officer` role assignment, the OpenClaw runtime identity's `Key Vault Secrets User` role assignment).

   **Secret writes** (records the three exact secret names and the format of each value — App ID is numeric, private key is PEM, installation ID is numeric — without recording the values themselves; invariant 8).

   **Rotation disposition** (records which path 01a took — automated Tier-2 rotator OR logged Log Analytics exception with calendar reminder; if the latter, records the cadence and the exception identifier).

   **Operational notes** — how to read the secrets at runtime (the OpenClaw managed identity / service principal reads via `ISecretStore`); how to verify the App token mints correctly (the curl-based JWT-exchange smoke-test 01a executed); how to revoke and re-issue the App if compromised.

   **Cross-references** to canonical playbooks: `key-vault-creation.md`, `key-vault-rbac-assignments.md`, `log-analytics-workspace-and-alerts.md`, `github-app-hive-walkthrough.md`.

3. Cross-link this walkthrough from packet 02's body (Phase 2 — cross-repo PR authority) and from `.claude/agents/docs-sync.md`'s "credentials" section (if the agent file is already in tree).

## Affected Files
- `infrastructure/walkthroughs/docs-sync-github-app-registration.md` (new)
- `.claude/agents/docs-sync.md` (optional — one-line "credentials" cross-link, depending on landing order)

## NuGet Dependencies
None.

## Boundary Check
- [x] The walkthrough doc lives in `HoneyDrunk.Architecture/infrastructure/walkthroughs/` (existing dir holding all portal walkthroughs).
- [x] Vault is the secret store per invariant 9 — no secret value committed.
- [x] The walkthrough records names/IDs/paths/dispositions only; never secret values (invariant 8).

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/docs-sync-github-app-registration.md` exists and records the canonical App name (`docs-sync` or fallback), App ID, KV name (`kv-hd-docs-sync-prod`), three secret names, installation ID (or "All repositories" confirmation), rotation disposition, RBAC assignments — sourced from packet 01a's hand-off note
- [ ] The walkthrough cross-links the canonical playbooks (`key-vault-creation.md`, `key-vault-rbac-assignments.md`, `log-analytics-workspace-and-alerts.md`, `github-app-hive-walkthrough.md`)
- [ ] No secret value appears in the walkthrough (invariant 8) — names, IDs, paths, and dispositions only
- [ ] The walkthrough is cross-linked from packet 02's body and from `.claude/agents/docs-sync.md`'s "credentials" section (if applicable per landing order)
- [ ] The repo-level `CHANGELOG.md` carries an entry for the walkthrough doc addition (per invariant 12)

## Human Prerequisites
- [ ] Packet 01a's hand-off note is captured and pasted into this packet's issue body before this packet's PR is opened. The agent authors the walkthrough against the captured values.

## Dependencies
- `packet:01` — **hard**. Agent definition + capability-matrix row + report directory must exist so the walkthrough can cross-link them.
- `packet:01a` — **hard**. The App + Vault + secrets + RBAC + rotation disposition must exist and the hand-off note must be available before the walkthrough can record concrete values.

## Referenced ADR Decisions

**ADR-0085 D4** — GitHub App authority model (1-hour auto-rotated installation tokens).
**ADR-0085 D8 Phase 1** — App provisioning is a discrete Phase-1 subtask split across 01a (portal) + 01b (walkthrough).
**ADR-0005** — Vault naming + RBAC.
**ADR-0006 Tier 2** — Rotation SLA.

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Walkthrough records names/IDs/paths only.

> **Invariant 9:** Vault is the only source of secrets. Walkthrough documents the Vault entries but does not duplicate values.

- **Author against captured values, not placeholders.** Use 01a's hand-off note. If the note is missing or incomplete, surface that as a blocker rather than ship a walkthrough with `<TODO>` placeholders.
- **PR metadata:** `Authorship: agent-claude-code` + `Packet: HoneyDrunkStudios/HoneyDrunk.Architecture#<issue-number>` once filed.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `infrastructure`, `adr-0085`, `wave-1`

## Agent Handoff

**Objective:** Author the walkthrough doc documenting the App + Vault provisioning packet 01a performed, against concrete IDs/names/paths/dispositions captured in 01a's hand-off note.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Permanent record of the one-time provisioning, cross-linked from packet 02 and from the agent definition.
- Feature: Grid-Wide Documentation Currency Agent rollout, Phase 1 (App provisioning, doc-authoring portion).
- ADRs: ADR-0085 (D4 + D8 Phase 1), ADR-0005, ADR-0006.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — hard.
- `packet:01a` — hard.

**Constraints:**
- Author against captured values, not placeholders.
- Invariant 8: names/IDs only; never secret values.
- PR metadata: `Authorship: agent-claude-code` + `Packet: <path>`.

**Key Files:**
- `infrastructure/walkthroughs/docs-sync-github-app-registration.md` (new)
- `infrastructure/walkthroughs/key-vault-creation.md` (existing playbook to cross-link)
- `infrastructure/walkthroughs/key-vault-rbac-assignments.md` (existing playbook to cross-link)
- `infrastructure/walkthroughs/log-analytics-workspace-and-alerts.md` (existing playbook to cross-link)
- `infrastructure/walkthroughs/github-app-hive-walkthrough.md` (existing precedent to cross-link)
- `.claude/agents/docs-sync.md` (optional — one-line credentials cross-link)

**Contracts:** None.
