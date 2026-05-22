---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0034", "wave-1"]
dependencies: []
adrs: ["ADR-0034", "ADR-0035"]
accepts: ["ADR-0034"]
wave: 1
initiative: adr-0034-public-package-distribution
node: honeydrunk-architecture
---

# Accept ADR-0034 — flip status, add the three packaging invariants, register the distribution initiative

## Summary
Flip ADR-0034 (Public Package Distribution and NuGet Policy) from Proposed to Accepted: update the ADR header, update the ADR index row, add the three new packaging invariants ADR-0034 commits in its Consequences section to `constitution/invariants.md`, and register the `adr-0034-public-package-distribution` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0034 decides where and how the Grid's public packages are distributed — nuget.org under the `HoneyDrunkStudios` owner as the primary feed, GitHub Packages for private revenue Nodes, Azure Artifacts retained as pre-release staging, mandatory package metadata, SourceLink + symbols, deterministic builds, author signing, and a single `job-publish-nuget.yml` reusable workflow. Every other packet in this initiative references ADR-0034's D-decisions as live rules. The acceptance flip must land first so those references read against Accepted text.

ADR-0034 D7 states explicitly that ADR-0034 and ADR-0035 (Abstractions Versioning and Deprecation Policy) "must land together; neither is useful alone." ADR-0035 is being scoped under its own initiative folder (`adr-0035-abstractions-versioning`). This packet flips **ADR-0034 only**. Its PR and ADR-0035's acceptance PR should be merged in the same session so the two land together; this packet does not touch ADR-0035's file.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0034-public-package-distribution-and-nuget-policy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0034 row Status column to Accepted.
- `constitution/invariants.md` — add the three new packaging invariants ADR-0034 commits (see Proposed Implementation for exact text). They are **invariants 54, 55, 56** — pre-reserved numbers (see the coordination note below).
- `initiatives/active-initiatives.md` — register the `adr-0034-public-package-distribution` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0034 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0034 index row in `adrs/README.md` to Accepted.
3. Add three new invariants to `constitution/invariants.md` under a new `## Distribution & Packaging Invariants` section (or appended to the existing `## Packaging Invariants` section — match the file's current sectioning), as **invariants 54, 55, 56** in this exact order. The text, taken from ADR-0034's "Invariants" Consequences subsection:
   - **54 — Every public package is owned by `HoneyDrunkStudios` on nuget.org.** No fork-owned, no individual-developer-owned public packages. See ADR-0034 D1.
   - **55 — Every public package ships SourceLink + symbols.** The build fails if SourceLink is not produced. See ADR-0034 D4.
   - **56 — Package publish runs through the HoneyDrunk.Actions reusable workflow.** Consumer release workflows do not call `dotnet nuget push` directly. (Parallels ADR-0012's deploy-mechanics rule.) See ADR-0034 D6.

**Invariant-numbering coordination note.** The current highest invariant in `constitution/invariants.md` is **51** (1–51 all present). Invariant numbers **54–56** are pre-reserved for ADR-0034 as part of a 12-ADR batch that reserves blocks of invariant numbers across ADRs 0034–0042/0045 (ADR-0034's block is 54–56; numbers 52–53 belong to a sibling ADR in the batch). Do **not** scan for the current max or compute "next free number" — use the hard numbers 54, 55, 56. If any invariant above 51 lands from **outside** this batch before this PR merges, shift this block upward to the next free triple and never reuse a number.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0034-public-package-distribution-and-nuget-policy.md`
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
- [ ] ADR-0034 header reads `**Status:** Accepted`
- [ ] The ADR-0034 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the three new packaging invariants (nuget.org ownership, SourceLink + symbols, publish-via-reusable-workflow) as invariants **54, 55, 56** in that order, each citing ADR-0034
- [ ] `initiatives/active-initiatives.md` registers the `adr-0034-public-package-distribution` initiative with a packet checklist
- [ ] No catalog schema change in this packet (`catalogs/package-feeds.json` is created in packet 01)
- [ ] No change to ADR-0035's file in this packet

## Human Prerequisites
None. (The nuget.org owner-account claim and the BDR-0001 signing-certificate procurement are operational prerequisites surfaced in packets 01 and 04 respectively — they are not blockers for the acceptance flip itself.)

## Referenced ADR Decisions
**ADR-0034 D7 — Versioning is governed by ADR-0035.** ADR-0034 decides *where and how* packages publish; ADR-0035 decides version semantics, deprecation rules, and ABI-stability. "The two ADRs must land together; neither is useful alone." This acceptance PR should merge in the same session as ADR-0035's acceptance PR.

**ADR-0034 Consequences — Invariants.** ADR-0034 adds exactly three invariants: (1) public-package nuget.org ownership by `HoneyDrunkStudios`; (2) every public package ships SourceLink + symbols, build fails otherwise; (3) publish runs through the HoneyDrunk.Actions reusable workflow, not inline `dotnet nuget push`.

## Constraints
- **Acceptance precedes flip.** ADR-0034 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Land together with ADR-0035.** Per ADR-0034 D7, coordinate the merge of this PR with ADR-0035's acceptance PR. This packet does not edit ADR-0035's file — that is ADR-0035's own acceptance packet's job.
- **Use the pre-reserved invariant numbers 54, 55, 56.** Do not renumber existing invariants and do not scan for the current max — 54–56 are reserved for ADR-0034 by the 12-ADR batch. Only shift the block upward if an out-of-batch invariant above 51 lands first (see the coordination note in Proposed Implementation).

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0034`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0034 to Accepted, add the three packaging invariants to `constitution/invariants.md`, and register the public-package-distribution initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0034 so the distribution packets can reference its decisions as live rules.
- Feature: ADR-0034 Public Package Distribution rollout, Wave 1.
- ADRs: ADR-0034 (primary), ADR-0035 (lands together — separate initiative), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0034 stays Proposed until this PR merges.
- Coordinate the merge with ADR-0035's acceptance PR (ADR-0034 D7 — they land together).
- Add the three new invariants as the pre-reserved numbers 54, 55, 56; do not renumber existing invariants and do not scan for the current max (see the coordination note in Proposed Implementation).

**Key Files:**
- `adrs/ADR-0034-public-package-distribution-and-nuget-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
