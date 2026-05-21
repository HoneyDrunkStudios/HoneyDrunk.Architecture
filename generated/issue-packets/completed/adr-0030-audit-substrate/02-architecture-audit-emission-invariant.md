---
name: Add the audit-emission boundary invariant to the Grid constitution
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "architecture", "constitution", "adr-0030", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0030", "ADR-0031"]
wave: 1
initiative: adr-0030-audit-substrate
node: honeydrunk-architecture
---

# Chore: Add ADR-0030's audit-emission boundary invariant to the Grid constitution

## Summary
Add one new invariant to `constitution/invariants.md` derived from ADR-0030's Consequences section ("New invariant (proposed for `constitution/invariants.md`)"): auditable security events must be emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog` on a durable channel separate from observability telemetry. Assign it number **44** — the next free slot after invariant 43 (the highest existing number as of this scoping run). Numbers **45** and **46** are explicitly reserved for ADR-0031's two restated invariants (Audit downstream Abstractions-only coupling; Audit contract-shape canary) and are **not** landed by this packet — they land when the ADR-0031 standup initiative is scoped and executed. This split is deliberate, to keep ADR-0030 and ADR-0031 from double-numbering the same constitution.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0030 explicitly delegates final invariant numbering to the scope agent at acceptance time ("Numbering is tentative — scope agent finalizes at acceptance"; "Scope agent assigns final invariant numbers when flipping Status → Accepted"). The substrate-level invariant ADR-0030 proposes — the audit-emission boundary — is the Grid-level rule the entire HoneyDrunk.Audit Node exists to enforce. Without a numbered, citable rule in `constitution/invariants.md`:

- The review agent has no constitutional anchor to catch a Node routing auditable security events only to sampled telemetry (Pulse/Loki) instead of the durable audit channel.
- The future ADR-0031 standup packets, the Auth first-emitter packet, and the Operator reconciliation packet have no numbered invariant to reference for the "durable channel separate from observability" rule.
- ADR-0030's Consequences section stays a placeholder with the tentative-numbering qualifier intact.

ADR-0031 (the standup ADR) restates two further invariants for the stand-up's contract-coupling and canary rules. Per ADR-0031's own Consequences section, the audit-emission boundary invariant is the substrate-level invariant and "is not restated here to avoid double-numbering. The scope agent assigns final numbers across both ADRs at acceptance." This packet lands **only** the ADR-0030 substrate invariant (44) and reserves 45/46 for the ADR-0031 standup initiative. That separation honors the user's explicit constraint that the two ADRs not double-number.

## Proposed Implementation

### `constitution/invariants.md` — add invariant 44 in a new section

The file's highest existing invariant number is **43** (ADR-0019 Communications canary). The file is organized into themed sections (Dependency, Context, Secrets & Trust, Packaging, Testing, Infrastructure, Work Tracking, AI, Code Review, Hosting Platform, Hive Sync, Multi-Tenant Boundary, Communications). The audit-emission boundary invariant is its own concern — it does not belong under AI, Secrets, or Communications. Add a new section header **`## Audit Invariants`** at the end of the file (after the existing `## Communications Invariants` section) and place invariant 44 under it.

Append exactly this block after the last line of the `## Communications Invariants` section:

```markdown
## Audit Invariants

44. **Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry.**
    Login attempts, authorization grants and denials, and privileged-action execution are recorded durably and attributably through `IAuditLog`. Auditable security events routed only to sampled or retention-bounded observability (Pulse / Loki) are a boundary violation — observability answers "is the system healthy in aggregate," audit answers "who did what, when, against what, and was it allowed." The audit channel and the telemetry channel are never merged: audit *records* are not telemetry and never flow to Pulse, and the Audit Node's own operational telemetry flows one-way to Pulse with no runtime dependency on Pulse. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. See ADR-0030 D1, D6, D7, D9.

_Invariants 45–46 are reserved for the HoneyDrunk.Audit stand-up (ADR-0031): the Audit downstream Abstractions-only coupling rule (D9) and the Audit contract-shape canary requirement (D8). They will be added here when the ADR-0031 standup initiative is scoped and executed — deliberately not landed with invariant 44, to keep ADR-0030 and ADR-0031 from double-numbering._
```

Notes for the executing agent:

- **Number-collision check is a hard gate.** Before committing, scan `constitution/invariants.md` and confirm the highest existing number is still **43**. If a newer ADR has grabbed 44 since this packet was authored, shift this invariant to the next free number, keep 45/46 (or the next two after the shifted number) reserved for ADR-0031, and update the cross-references in:
  - `adrs/ADR-0030-grid-wide-audit-substrate.md` — the "New invariant (proposed for `constitution/invariants.md`)" bullet in Consequences: replace the tentative-numbering note with the assigned number.
  - `repos/HoneyDrunk.Audit/invariants.md` (created by packet 01) — the cross-reference line currently reads "Constitutional invariant 44 (the audit-emission boundary invariant...)". Update the number if it shifted. Packet 01 is in the same initiative folder and lands first (this packet's `dependencies: ["packet:01"]`), so its file exists in the working tree by the time this packet's PR is authored; editing the committed `repos/HoneyDrunk.Audit/invariants.md` on `main` is a normal repo edit, not a packet-file edit.
- **Do not land 45 or 46.** ADR-0031's two restated invariants are out of scope for this initiative. The reservation line above is the placeholder; the actual numbered entries are added by the ADR-0031 standup initiative when the user scopes it. Landing them here would pre-empt the standup ADR's acceptance and risk double-numbering if ADR-0031's scoping later renumbers.
- **No `(Proposed)` qualifier on invariant 44.** ADR-0030 is flipped to Accepted by packet 01 of this same initiative (concurrently — the scope agent flips Status after the initiative's PRs merge, per the user's ADR acceptance workflow). The invariant text reads as fully active. The substrate it governs is registered by packet 01.
- The new `## Audit Invariants` section header is correct even though it contains a single numbered invariant plus a reservation note — other sections in this file (AI Invariants) follow the same single-plus-reservation shape.

### `adrs/ADR-0030-grid-wide-audit-substrate.md` — finalize the invariant number

In ADR-0030's Consequences section, the "New invariant (proposed for `constitution/invariants.md`)" subsection currently opens with: `Numbering is tentative — scope agent finalizes at acceptance.` Replace that sentence with: `Assigned invariant number: **44** (see `constitution/invariants.md`, `## Audit Invariants`).` Leave the invariant's body text in the ADR as-is — only the tentative-numbering preamble changes. If the number shifted due to collision, use the assigned number.

### `CHANGELOG.md` (Architecture repo)
Append to the Unreleased section: `Architecture: Add invariant 44 (audit-emission boundary — auditable security events emitted to the HoneyDrunk.Audit substrate via IAuditLog on a durable channel separate from observability; Phase 1 append-only-by-interface, not tamper-evident) per ADR-0030 D1/D6/D7/D9, in a new "## Audit Invariants" section. Invariants 45-46 reserved for the ADR-0031 standup (Audit downstream coupling + contract-shape canary), deliberately not landed here to avoid double-numbering across the two ADRs.`

## Affected Files
- `constitution/invariants.md` (add `## Audit Invariants` section with invariant 44 + the 45/46 reservation note)
- `adrs/ADR-0030-grid-wide-audit-substrate.md` (finalize the invariant number in Consequences)
- `repos/HoneyDrunk.Audit/invariants.md` (only if the assigned number shifted from 44 — update the cross-reference line)
- `CHANGELOG.md` (Unreleased entry)

## NuGet Dependencies
None. Architecture is a knowledge repo.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No new design decision — invariant text is taken from ADR-0030's "New invariant" Consequences subsection, with light wordsmithing for the constitution's voice and the honest-limitation clause folded in from D9.
- [x] No existing invariants modified — only a new section and a new number appended.
- [x] Only ADR-0030's substrate invariant lands (44). ADR-0031's two invariants (45/46) are explicitly reserved, not landed — no double-numbering.

## Acceptance Criteria
- [ ] `constitution/invariants.md` carries a new `## Audit Invariants` section appended after the `## Communications Invariants` section.
- [ ] Invariant **44** is present under that section with text matching ADR-0030 D1/D6/D7/D9 — including the explicit "NOT tamper-evident at Phase 1" clause.
- [ ] The 45–46 reservation note is present immediately after invariant 44, explicitly attributing 45/46 to the ADR-0031 standup (Audit downstream coupling + contract-shape canary) and stating the deliberate avoid-double-numbering reason.
- [ ] Number assignment verified against the current highest number in the file (44 unless a newer ADR has grabbed it — highest existing as of this scoping run is 43).
- [ ] **Invariants 45 and 46 are NOT added by this packet** — only the reservation note exists for them.
- [ ] Invariant 44 carries no `(Proposed)` qualifier (ADR-0030 is flipped to Accepted by packet 01 of this same initiative).
- [ ] `adrs/ADR-0030-grid-wide-audit-substrate.md` Consequences "New invariant" subsection has the tentative-numbering preamble replaced with the assigned number (44, or the shifted number).
- [ ] If the number shifted from 44, `repos/HoneyDrunk.Audit/invariants.md`'s cross-reference line is updated to the assigned number.
- [ ] `CHANGELOG.md` Unreleased section updated with the assigned number and the 45/46-reservation rationale.
- [ ] Before merge, packet 01's PR is confirmed merged to `main`: `catalogs/nodes.json` carries `honeydrunk-audit` and `repos/HoneyDrunk.Audit/invariants.md` exists on `main`. This PR is NOT merged ahead of packet 01.
- [ ] PR body states: only ADR-0030's substrate invariant landed; ADR-0031's two invariants are reserved (45/46) for the separate standup initiative to avoid double-numbering.

## Human Prerequisites
- [ ] Confirm the invariant-numbering split is correct before merge: ADR-0030 takes **44**; ADR-0031's two restated invariants are reserved for **45** and **46** and land only when the ADR-0031 standup initiative is scoped. This is the coordination the user explicitly asked for (no double-numbering across the two ADRs). If the user wants a different allocation, adjust before this packet's PR merges.

## Referenced ADR Decisions

**ADR-0030 D1 (Audit is distinct from observability):** Observability (Pulse) answers "is the system healthy in aggregate"; audit answers "who did what, when, against what, and was it allowed" — durably, attributably, queryable after the fact. The two are not the same channel; conflating them was the latent bug. — Source for invariant 44's "channels never merged" clause.

**ADR-0030 D6 (First emitter is Auth, additively):** Auth records durable attributable security events (login attempts, authz grants/denials) on a *separate durable channel*, additive to its existing OTel traces; the identity-out-of-traces rule is untouched. — Source for invariant 44's enumeration of the auditable security events.

**ADR-0030 D7 (Telemetry — Pulse consumes, Audit does not depend):** Audit emits its own operational telemetry one-way to Pulse; Audit *records* are not telemetry and never flow to Pulse; Audit has no runtime dependency on Pulse. — Source for invariant 44's one-way-telemetry clause.

**ADR-0030 D9 (Phase 1 is append-only, NOT tamper-evident):** `IAuditLog` exposes no update or delete; a privileged actor with direct store access is not cryptographically prevented from altering history; hash-chain/WORM is deferred. Do not market or document Phase 1 as tamper-evident. — Source for invariant 44's honest-limitation clause.

**ADR-0031 Consequences (deliberate non-restatement):** ADR-0031 restates two invariants for the stand-up's contract-coupling (D9) and canary (D8) rules but explicitly does **not** restate the audit-emission boundary invariant "to avoid double-numbering. The scope agent assigns final numbers across both ADRs at acceptance." — This packet honors that: 44 here; 45/46 reserved for the ADR-0031 standup.

## Referenced Invariants

> **Invariant 12:** Semantic versioning with CHANGELOG and README. — This packet updates the Architecture repo-level `CHANGELOG.md`. No package CHANGELOGs apply (Architecture has no packages).

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. — This packet is filed as an issue against `HoneyDrunk.Architecture`.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled; the review agent must be able to catch at PR time any defect the scope agent could introduce. — A numbered, citable audit-emission invariant is precisely what lets the review agent flag a future Node that routes auditable security events only to Pulse/Loki. Landing it closes that review-coverage gap.

## Dependencies
- `packet:01` — packet 01 registers the `honeydrunk-audit` Node, the contract surface, the `repos/HoneyDrunk.Audit/` context folder (whose `invariants.md` cross-references invariant 44), and flips ADR-0030 to Accepted. Filing 02 before 01 would leave invariant 44 referencing an unregistered substrate and a forward-reference dangling in `repos/HoneyDrunk.Audit/invariants.md`.

## Labels
`chore`, `tier-2`, `meta`, `architecture`, `constitution`, `adr-0030`, `wave-1`

## Agent Handoff

**Objective:** Land ADR-0030's audit-emission boundary invariant in the Grid constitution at the next free number (44), in a new `## Audit Invariants` section, and explicitly reserve 45/46 for the separate ADR-0031 standup so the two ADRs do not double-number.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: ADR-0030's "New invariant" Consequences subsection is a placeholder with "Numbering is tentative — scope agent finalizes at acceptance." This packet is the finalization for the substrate-level invariant only.
- Feature: Grid-wide durable, attributable security and action audit substrate.
- ADRs: ADR-0030 (sole source of invariant 44's text); ADR-0031 (the standup ADR — its two restated invariants are reserved for 45/46 and are NOT landed here).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 of this initiative (catalog registration + ADR-0030 acceptance + context folder) must merge first.

**Constraints:**

- **Merge-order gate (hard).** `dependencies: ["packet:01"]` is only a Hive board blocked-by edge — it does **not** gate the git merge. Do **not** merge this PR until packet 01's PR is merged to `main`. Before merging, verify on `main` that `catalogs/nodes.json` carries the `honeydrunk-audit` Node and `repos/HoneyDrunk.Audit/invariants.md` exists (these are packet 01's artifacts that invariant 44's substrate reference and the `repos/HoneyDrunk.Audit/invariants.md` cross-reference line depend on). If either is absent on `main`, packet 01 has not landed — hold this PR until it has. Merging 02 ahead of 01 leaves invariant 44 referencing an unregistered substrate and a dangling forward-reference.
- **Number-collision check is a hard gate.** Highest existing invariant number as of this scoping run is 43. 44 is the target. If a newer ADR has grabbed 44, shift to the next free number, keep the next two after it reserved for ADR-0031, and update the cross-references in `adrs/ADR-0030-grid-wide-audit-substrate.md` and `repos/HoneyDrunk.Audit/invariants.md`. Do not file partial edits.
- **Land only invariant 44.** ADR-0031's two invariants (Audit downstream Abstractions-only coupling; Audit contract-shape canary) are out of scope for this initiative — they are 45/46 and land when the ADR-0031 standup is scoped. Only the reservation note for 45/46 is written here. This is the user's explicit no-double-numbering coordination requirement.
- **No `(Proposed)` qualifier.** ADR-0030 is flipped to Accepted by packet 01 of this same initiative. Invariant 44 is fully active.
- **Verbatim alignment with ADR-0030.** Invariant 44's body restates D1/D6/D7/D9 in constitutional voice — including the honest "NOT tamper-evident at Phase 1" clause from D9. Do not introduce new requirements; anything novel belongs in a follow-up ADR.
- **New section header.** The invariant lands under a new `## Audit Invariants` section appended after `## Communications Invariants`, not folded into AI/Secrets/Communications.

**Key Files:**
- `constitution/invariants.md` — append `## Audit Invariants` section with invariant 44 + the 45/46 reservation note
- `adrs/ADR-0030-grid-wide-audit-substrate.md` — replace the tentative-numbering preamble in the "New invariant" Consequences subsection with the assigned number
- `repos/HoneyDrunk.Audit/invariants.md` — only edited if the assigned number shifted from 44
- `CHANGELOG.md` — Unreleased entry

**Contracts:** None.
