---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "infrastructure", "docs", "adr-0036", "wave-1"]
dependencies: []
adrs: ["ADR-0036"]
accepts: ["ADR-0036"]
wave: 1
initiative: adr-0036-disaster-recovery
node: honeydrunk-architecture
---

# Accept ADR-0036 — flip status, add the two DR invariants, register the initiative

## Summary
Flip ADR-0036 (Disaster Recovery and Backup Policy) from Proposed to Accepted: update the ADR header, update the ADR index row, add the two new DR invariants ADR-0036 commits in its Consequences section to `constitution/invariants.md`, and register the `adr-0036-disaster-recovery` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0036 sets the Grid-wide disaster-recovery and backup policy: three durability tiers (T0/T1/T2) with explicit RPO/RTO targets, geo posture, and restore-drill cadence (D1); concrete Azure backup mechanics per backing slot (D2); restore drills as proof (D3); manual cross-region failover with documented runbooks (D4); tenant-scoped restore for multi-tenant Nodes (D5); a Vault bootstrap-recovery procedure that must exist before any other T0 drill (D6); backup-vs-data-subject-deletion handling (D7); a cost ceiling that makes tier promotion an ADR amendment (D8); and the documentation surface — per-Node `dr-runbook.md`, a `dr_tier` field in `catalogs/grid-health.json`, and `generated/restore-drills/` (D9).

Every other packet in this initiative references ADR-0036's D-decisions as live rules. The acceptance flip must land first so those references read against Accepted text.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0036-disaster-recovery-and-backup-policy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0036 row Status column to Accepted.
- `constitution/invariants.md` — add the two new DR invariants ADR-0036 commits (see Proposed Implementation for exact text) as invariants **60** and **61** (pre-reserved numbers — see Constraints).
- `initiatives/active-initiatives.md` — register the `adr-0036-disaster-recovery` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0036 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0036 index row in `adrs/README.md` to Accepted.
3. Add two new invariants to `constitution/invariants.md` as invariants **60** and **61**. The text, taken verbatim-in-substance from ADR-0036's "Invariants" Consequences subsection:
   - **60. Every Node holding state has a `dr_tier` assignment in `catalogs/grid-health.json`.** A Node that holds durable state with no `dr_tier` field is drift; `hive-sync` (ADR-0014) reports it. Stateless Nodes are not tiered. See ADR-0036 D1.
   - **61. A missed restore drill freezes Tier-affecting tenant onboarding for the affected Node.** No new tenants are onboarded against a Node whose last restore drill is overdue per its tier cadence. Recovery is "complete the drill," not "wave the requirement." See ADR-0036 D3.
   The current highest invariant in `constitution/invariants.md` is 51 (verified at scope time); numbers 60–61 are pre-reserved for ADR-0036 as part of a 12-ADR batch. Add them under the existing `## Infrastructure & Configuration Invariants` section (they are infrastructure rules) or a new `## Disaster Recovery Invariants` section — match the file's current sectioning convention.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0036-disaster-recovery-and-backup-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0036 header reads `**Status:** Accepted`
- [ ] The ADR-0036 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the two new DR invariants (`dr_tier` assignment is mandatory; missed drill freezes tier-affecting onboarding), numbered **60** and **61**, each citing ADR-0036
- [ ] `initiatives/active-initiatives.md` registers the `adr-0036-disaster-recovery` initiative with a packet checklist
- [ ] No catalog schema change in this packet (`grid-health.json`'s `dr_tier` field is added in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0036 D1 — Three durability tiers.** Every Node holding state is assigned T0/T1/T2; each tier fixes RPO/RTO, geo posture, and restore-drill cadence. Stateless Nodes are not tiered. The mapping is recorded in `catalogs/grid-health.json` under a new `dr_tier` field; `hive-sync` treats a stateful Node without `dr_tier` as drift.

**ADR-0036 D3 — Restore drills are the proof.** A missed drill is an incident; it triggers a Tier-promotion freeze on the affected Node (no new tenants onboarded against a Node whose last drill is overdue).

**ADR-0036 Consequences — Invariants.** ADR-0036 adds exactly two invariants: (1) every stateful Node has a `dr_tier`; missing assignment is drift; (2) a missed restore drill freezes tier-affecting tenant onboarding for the affected Node.

## Constraints
- **Acceptance precedes flip.** ADR-0036 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers 60–61 are pre-reserved** as part of a 12-ADR batch; the verified current highest invariant is 51. If any invariant above 51 lands from outside this batch before merge, shift this block upward — never reuse a number. Do not renumber existing invariants; append.

## Labels
`chore`, `tier-3`, `infrastructure`, `docs`, `adr-0036`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0036 to Accepted, add the two DR invariants to `constitution/invariants.md`, and register the disaster-recovery initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0036 so the DR packets can reference its decisions as live rules.
- Feature: ADR-0036 Disaster Recovery and Backup Policy rollout, Wave 1.
- ADRs: ADR-0036 (primary), ADR-0008 (initiative/packet conventions), ADR-0014 (`hive-sync` drift reconciliation).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0036 stays Proposed until this PR merges.
- Add the two new invariants as numbers **60** and **61** (verified current highest is 51; 60–61 pre-reserved for ADR-0036 in a 12-ADR batch). If an invariant above 51 lands from outside the batch before merge, shift this block upward — never reuse a number. Do not renumber existing invariants.

**Key Files:**
- `adrs/ADR-0036-disaster-recovery-and-backup-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
