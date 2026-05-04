---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ai", "adr-0016", "constitution"]
dependencies: ["packet:01"]
adrs: ["ADR-0016"]
wave: 1
initiative: adr-0016-honeydrunk-ai-standup
node: honeydrunk-ai
---

# Chore: Add ADR-0016's three new invariants to the Grid constitution

## Summary
Add three new invariants to `constitution/invariants.md` derived from ADR-0016 D9 (downstream coupling rule), D5 (App Configuration sourcing), and D8 (contract-shape canary). Assign them numbers 39, 40, and 41 (the next three free slots after invariant 38 — the most recent addition from ADR-0014's Hive Sync rollout).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0016 explicitly delegates final invariant numbering to the scope agent at acceptance time. The three invariants the ADR proposes (in its "New invariants" section under Consequences) need to land in `constitution/invariants.md` so the canary infrastructure, downstream Node packets, and the review agent all have a numbered, citable rule to reference.

These three rules govern the AI Node's first-shipping behavior:

- **D9 — downstream coupling.** Every AI-sector Node from packet 03 onward will compile against `HoneyDrunk.AI.Abstractions` and only that package. Without an invariant, drift toward `HoneyDrunk.AI` direct references is silent until canaries catch it. Better to forbid it explicitly.
- **D5 — App Configuration sourcing.** Cost-rate tables and routing policies in code defeat the entire reason `IRoutingPolicy` and `ICostLedger` exist. An invariant makes a hardcoded rate a build-time gating concern, not a runtime discovery.
- **D8 — contract-shape canary.** Even with the canary wired in CI (handled by packet 03), the obligation to *keep* the canary running on the four hot-path contracts must outlive any single CI workflow file. An invariant ensures any future CI rewrite preserves the gate.

## Proposed Implementation

### `constitution/invariants.md` — append three new entries to the existing AI Invariants section

The existing AI Invariants section (starting at line 105) already contains invariant 28 with a `(Proposed — this invariant takes effect when ADR-0010 is accepted)` qualifier and a placeholder reserving invariants 29–30 for the Observation Layer (ADR-0010). Per the active-initiatives.md sync (2026-05-03), ADR-0010 Phase 1 work is in progress; invariants 29–30 are still reserved.

Add three new invariants at the **next free numbers** — currently **39, 40, 41**. Verify the highest assigned number in `constitution/invariants.md` at edit time and shift if any newly accepted ADRs have grabbed 39/40/41 between when this packet was written and when it lands.

The three entries are appended directly to the existing `## AI Invariants` section, immediately after the `_Invariants 29–30 are reserved..._` line. **Do not introduce a new section header.** Non-monotonic numbering within a section (28, then 39/40/41 after the 29–30 reservation) is fine — other sections in this file already do the same kind of sparse sequencing.

The current end of the AI Invariants section reads:

```markdown
## AI Invariants

28. **Application code must never hardcode a model name or provider.**
    All model selection goes through `IModelRouter` in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy. See ADR-0010 (Proposed — this invariant takes effect when ADR-0010 is accepted).

_Invariants 29–30 are reserved for the Observation Layer (ADR-0010). They will be added here when ADR-0010 is accepted._

## Code Review Invariants
```

Append the three new entries between the `_Invariants 29–30 are reserved..._` line and the `## Code Review Invariants` header so the section reads:

```markdown
## AI Invariants

28. **Application code must never hardcode a model name or provider.**
    All model selection goes through `IModelRouter` in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy. See ADR-0010 (Proposed — this invariant takes effect when ADR-0010 is accepted).

_Invariants 29–30 are reserved for the Observation Layer (ADR-0010). They will be added here when ADR-0010 is accepted._

39. **Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`.**
    Composition against `HoneyDrunk.AI` and any `HoneyDrunk.AI.Providers.*` package is a host-time concern resolved at application startup from App Configuration. This is the same abstraction/runtime split applied for Vault and Transport, restated here because it is the specific rule that allows blocked AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) to proceed on `Abstractions` alone without waiting for provider packages. See ADR-0016 D9.

40. **Token cost rates, routing policies, and capability declarations are sourced from Azure App Configuration via Vault's `IConfigProvider`.**
    Hardcoded rates, policies, or capability declarations in application code are forbidden. Rate-table refresh is operator-driven — change the config value, restart or hot-reload, no deploy required. This applies in particular to the cost-rate table consumed by `ICostLedger`: token prices per model are operator-configurable, never compiled constants. See ADR-0016 D5 and ADR-0005.

41. **The HoneyDrunk.AI Node CI must include a contract-shape canary that fails the build on shape drift to `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, or `IModelRouter` without a corresponding version bump.**
    These four are the hot-path abstractions every downstream consumer compiles against. Accidental shape drift on any of them breaks every AI-sector Node simultaneously. The canary makes this a compile-time failure at AI's own CI, not a discovery at consumer sites. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.AI.Abstractions`; the obligation is to keep the gate, not to use any specific implementation. See ADR-0016 D8.

## Code Review Invariants
```

Notes for the executing agent:

- The three new entries land **inside** the existing `## AI Invariants` section. Do **not** create a `## AI Invariants (continued)` or any other new heading — the section header at line 105 covers all of 28, 39, 40, 41.
- Do not modify the existing 28's `(Proposed — this invariant takes effect when ADR-0010 is accepted)` qualifier — that is ADR-0010's concern, not this packet's.
- Do not modify the `_Invariants 29–30 are reserved..._` placeholder line — it stays where it is, between 28 and the new 39.
- Mark the three new invariants with the same convention used elsewhere — they should **not** carry a `(Proposed)` qualifier because ADR-0016 is being flipped to Accepted concurrently with this initiative landing (the scope agent flips Status → Accepted after this initiative's PR merges, per the user's ADR acceptance workflow).

### Verify no number collision

Before committing, scan `constitution/invariants.md` and confirm the highest existing number. If invariants 32–38 are present (Code Review + Container Apps + Hive Sync waves), 39 is the next free number. If any newer ADR has grabbed 39/40/41 in the interim, shift this packet's three entries to the next three free numbers and update the cross-references in:

- `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` (the "New invariants (proposed for `constitution/invariants.md`)" section under Consequences) — replace the bullet text with the assigned numbers.
- The packet 03 source file at `generated/issue-packets/active/adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold.md` — update any "see invariant 39/40/41" or "Invariant 39/40/41" references to match the assigned numbers. Packet 03 has not been filed yet at the time packet 02 lands (per the dispatch plan filing order), so amending its source file in place is permitted under invariant 24's pre-filing carve-out.

### `CHANGELOG.md` (Architecture repo)
Append to the Unreleased section: `Architecture: Add invariants 39 (AI downstream coupling), 40 (App Config-sourced AI rate tables and policies), and 41 (AI contract-shape canary) per ADR-0016 D9, D5, D8.`

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` (only if the assigned numbers differ from 39/40/41)
- `CHANGELOG.md`

## NuGet Dependencies
None. Architecture is a knowledge repo.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No new design decisions — invariant text is taken verbatim from ADR-0016's "New invariants" section, with light wordsmithing for the constitution's voice.
- [x] No existing invariants modified, only appended.

## Acceptance Criteria
- [ ] Three new invariants present in `constitution/invariants.md` with text matching ADR-0016 D9, D5, D8.
- [ ] The three new invariants are **appended directly to the existing `## AI Invariants` section** (which begins at line 105), immediately after the `_Invariants 29–30 are reserved..._` line. No new section header is introduced — `## AI Invariants (continued)` or similar is forbidden.
- [ ] Assigned numbers verified against the current highest number in the file (39, 40, 41 unless taken — the file's highest existing number as of 2026-05-03 is 38).
- [ ] Each invariant's body cites its source ADR decision (D5 / D8 / D9) and any related ADRs (ADR-0005 for D5).
- [ ] If invariant numbers shift away from 39/40/41 due to collision, packet 03's source file at `generated/issue-packets/active/adr-0016-honeydrunk-ai-standup/03-ai-node-scaffold.md` is updated before that packet is filed. The dispatch plan's filing-order rule guarantees packet 03 has not been filed yet at the time packet 02 lands.
- [ ] If numbers shifted from 39/40/41, the corresponding bullets in ADR-0016's Consequences section ("New invariants (proposed for `constitution/invariants.md`)") are updated to match, and packet 03's source file is updated to match.
- [ ] `CHANGELOG.md` Unreleased section updated with the three invariant numbers actually assigned.

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0016 D5 (Routing policy source — App Configuration via Vault):** Routing policies, cost-rate tables, and capability declarations all live in Azure App Configuration and are read through `IConfigProvider` from the Vault Node per ADR-0005. No policies or rate tables are hardcoded in application code. — This is the source for invariant 40.

**ADR-0016 D8 (Contract-shape canary):** A fifth canary is added to the AI Node's CI: a contract-shape canary that fails the build if any of `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, or `IModelRouter` change shape without a corresponding version bump. — This is the source for invariant 41.

**ADR-0016 D9 (Downstream coupling rule):** Downstream AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) compile only against `HoneyDrunk.AI.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.AI` or any `HoneyDrunk.AI.Providers.*` package. — This is the source for invariant 39.

## Dependencies
- `packet:01` — packet 01 lands the catalog surface that invariant 41's canary will guard. Filing 02 before 01 would leave a forward-reference dangling.

## Labels
`chore`, `tier-2`, `architecture`, `ai`, `adr-0016`, `constitution`

## Agent Handoff

**Objective:** Land three new ADR-0016-derived invariants in the Grid constitution at the next available numbers, in a single edit.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: ADR-0016's "New invariants" section is a placeholder with the qualifier "Numbering is tentative — scope agent finalizes at acceptance." This packet is the finalization.
- Feature: ADR-0016 standup initiative.
- ADRs: ADR-0016 (sole source); ADR-0005 (referenced by invariant 40 for the App Config split).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 of this initiative (catalog registration) must merge first.

**Constraints:**

- **No `(Proposed)` qualifier on the new invariants.** ADR-0016 is flipping to Accepted concurrently with this initiative landing; the new invariants take effect immediately. The user's ADR acceptance workflow handles the Status flip after merge — this packet's text should read as fully active.
- **Number collision check is a hard gate.** If 39/40/41 are taken, shift to the next free numbers and update both ADR-0016's Consequences section and packet 03 (the scaffold packet) cross-references. Do not file partial edits.
- **Verbatim alignment with ADR-0016.** The invariant bodies should restate D5/D8/D9 with constitutional voice, not introduce new requirements. Anything novel belongs in a follow-up ADR.

**Key Files:**
- `constitution/invariants.md` — append three entries to the AI Invariants section
- `adrs/ADR-0016-stand-up-honeydrunk-ai-node.md` — only edited if numbers shifted from 39/40/41
- `CHANGELOG.md`

**Contracts:** None.
