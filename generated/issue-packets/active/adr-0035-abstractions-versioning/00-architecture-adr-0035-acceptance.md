---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0035", "wave-1"]
dependencies: []
adrs: ["ADR-0035", "ADR-0034"]
accepts: ["ADR-0035"]
wave: 1
initiative: adr-0035-abstractions-versioning
node: honeydrunk-architecture
---

# Accept ADR-0035 — flip status, add the three versioning invariants, declare the Kernel.Abstractions 1.0.0 baseline, register the initiative

## Summary
Flip ADR-0035 (Abstractions Versioning and Deprecation Policy) from Proposed to Accepted: update the ADR header, update the ADR index row, add the three new versioning invariants ADR-0035 commits in its Consequences section to `constitution/invariants.md`, record the retroactive Kernel.Abstractions 1.0.0 baseline declaration, and register the `adr-0035-abstractions-versioning` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0035 is the policy that makes the Grid's Abstractions-first coupling rule (every stand-up ADR from ADR-0016 through ADR-0031 pins consumers to `*.Abstractions` packages) safe to rely on. It governs version-number semantics (strict SemVer per D1), what changes are allowed at each level, the binary-compatibility guarantee (D2), interface evolution (D3 — no default-interface-member additions), record/DTO evolution (D4 — `init` members not positional syntax), the pre-release channel (D5 — 14-day `-preview` floor), the deprecation window (D6 — 60-day floor for 1.0+ packages), the coordinated-cascade procedure (D7 — cascade ABI bumps are initiatives), the private-package carve-out (D8), and three CI enforcement gates (D9).

Every other packet in this initiative references ADR-0035's D-decisions as live rules. The acceptance flip must land first so those references read against Accepted text.

**ADR-0034 lands together — separate initiative.** ADR-0034 D7 and ADR-0035 D10 both state explicitly: ADR-0034 (Public Package Distribution) and ADR-0035 "must land together; neither is useful alone." ADR-0034 governs *distribution* (feeds, metadata, the publish workflow); ADR-0035 governs *version semantics* (SemVer rules, deprecation windows, the API-diff job). ADR-0034 is scoped under `adr-0034-public-package-distribution`; its acceptance packet is `00-architecture-adr-0034-acceptance.md`. This packet flips **ADR-0035 only**. Its PR and ADR-0034's acceptance PR must be merged in the same session so the two land together; this packet does not touch ADR-0034's file.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0035-abstractions-versioning-and-deprecation-policy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0035 row Status column to Accepted.
- `constitution/invariants.md` — add the three new versioning invariants ADR-0035 commits (see Proposed Implementation for exact text). They take the **pre-reserved numbers 57, 58, 59** (see Proposed Implementation step 3 for the reservation rule).
- `initiatives/active-initiatives.md` — register the `adr-0035-abstractions-versioning` initiative with the packet checklist for this folder.
- The Kernel.Abstractions 1.0.0 baseline is **recorded** in this packet (a note in the ADR's Consequences-implementing trail and/or `repos/HoneyDrunk.Kernel/`), but the **release tag** itself is not pushed here — agents never push tags (invariant 27). See Proposed Implementation step 5.

## Proposed Implementation
1. Edit the ADR-0035 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0035 index row in `adrs/README.md` to Accepted.
3. Add three new invariants to `constitution/invariants.md`. Append to the existing `## Packaging Invariants` section (or a new `## Versioning & Compatibility Invariants` section — match the file's current sectioning). **The true current maximum invariant number in `constitution/invariants.md` is 51 (verified). ADR-0035's reserved block is invariants 57, 58, 59 — use those hard numbers.** The numbers 57-59 are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number. Do not renumber existing invariants. The text, taken from ADR-0035's "Invariants" Consequences subsection:
   - **Invariant 57 — Every public Abstractions package follows strict SemVer per ADR-0035 D1.** Major bumps on any frozen-contract break; minor is additive-only; patch is doc/metadata-only. Calendar versions, marketing versions, and Node-aligned versions are forbidden — the version number is a breaking-change signal, not a release date. See ADR-0035 D1.
   - **Invariant 58 — No default-interface-member additions on shipped public interfaces.** New behavior on an existing surface lands on a new, intention-revealing successor interface (`IModelRouter` → `IModelRouter2` / `IModelRouterWithCostFloors`); consumers opt in by taking the new dependency. The original interface gets `[Obsolete]` only after the successor has shipped at the same major and the 60-day deprecation window has elapsed. See ADR-0035 D3.
   - **Invariant 59 — A major-version cascade is an initiative, not a loose set of packets.** When a major bump on a Kernel-level Abstractions package cascades through dependent Nodes, the cascade is scoped as a named initiative under the ADR-0008 D10 slug convention, recording the bumping Node and version delta, every downstream Node, the topological upgrade order, the `main` freeze status, and the pre-release window dates. Ad-hoc cross-Node ABI changes are forbidden. See ADR-0035 D7.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. Include a note in the registration that **ADR-0035 D2 (the per-Node binary-compatibility canary extension) is an explicit deferred follow-up** — extending each Node's contract-shape canary (invariants 43, 46, 49) to assert the binary-compat guarantee specifically is per-Node canary work not covered by this initiative. "ADR-0035 Accepted" must not be read as "D2 fully enforced": the `job-api-diff.yml` gate (packet 03) is the package-level mechanical enforcement, but the finer-grained per-Node canary extension remains outstanding.
5. **Record the Kernel.Abstractions 1.0.0 baseline declaration.** ADR-0035's Affected Nodes section states: "Kernel.Abstractions — currently at the version that absorbed ADR-0026's `TenantId` strict-typing. That bump is retroactively declared the **1.0.0 baseline** for the policy; pre-baseline history is grandfathered." Add a short retroactive note recording this declaration. Place it where the repo records cross-cutting version facts — preferably a one-line entry in `repos/HoneyDrunk.Kernel/` (e.g. `overview.md` or `active-work.md`, matching the file convention there) and a mention in this initiative's `active-initiatives.md` entry. Do **not** push the `1.0.0` git tag — tagging the corresponding Kernel release is a Human Prerequisite (agents never push tags, invariant 27). The note simply records *which already-shipped version* is hereby designated 1.0.0.

## Affected Files
- `adrs/ADR-0035-abstractions-versioning-and-deprecation-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`
- `repos/HoneyDrunk.Kernel/` — the file that records the 1.0.0-baseline note (match existing convention; `overview.md` or `active-work.md`)

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0035 header reads `**Status:** Accepted`
- [ ] The ADR-0035 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the three new versioning invariants (strict SemVer per D1 = invariant 57, no default-interface-member additions per D3 = invariant 58, major-cascade-is-an-initiative per D7 = invariant 59), each citing ADR-0035
- [ ] A retroactive note records the Kernel.Abstractions 1.0.0 baseline declaration in `repos/HoneyDrunk.Kernel/` and is referenced in the initiative's `active-initiatives.md` entry
- [ ] `initiatives/active-initiatives.md` registers the `adr-0035-abstractions-versioning` initiative with a packet checklist
- [ ] No git tag is pushed by this packet (tagging the Kernel 1.0.0 release is a Human Prerequisite)
- [ ] No change to ADR-0034's file in this packet

## Human Prerequisites
- [ ] Tag the corresponding `HoneyDrunk.Kernel` release as the `1.0.0` baseline for `Kernel.Abstractions`. ADR-0035 Follow-up Work: "Declare Kernel.Abstractions 1.0.0 baseline in a retroactive note; tag the corresponding release." The note is authored by this packet's agent; pushing the release tag is a manual step (agents never push tags — invariant 27).

## Referenced ADR Decisions
**ADR-0035 D10 — Relationship to ADR-0034.** "This ADR governs version semantics. ADR-0034 governs distribution. The two land together; neither is useful alone, and `catalogs/package-feeds.json` (ADR-0034 D8) is the authority for which feeds these rules apply to." This acceptance PR must merge in the same session as ADR-0034's acceptance PR.

**ADR-0035 Consequences — Invariants.** ADR-0035 adds exactly three invariants: (1) every public Abstractions package follows strict SemVer per D1 — calendar/marketing/Node-aligned versions forbidden; (2) no default-interface-member additions on shipped public interfaces — successors land on new interfaces; (3) a major-version cascade is an initiative, not a loose set of packets — procedure D7 is mandatory.

**ADR-0035 Affected Nodes — Kernel.Abstractions baseline.** The version that absorbed ADR-0026's `TenantId` strict-typing (`IGridContext.TenantId` promoted from `string?` to `TenantId?`) is retroactively declared the 1.0.0 baseline; pre-baseline history is grandfathered. Every other Node's Abstractions package stays pre-1.0 and operates outside the window guarantee until it deliberately reaches 1.0.0 — no bulk-bump (ADR-0035 Follow-up Work: "Move each Node's Abstractions package to 1.0.0 only on deliberate review; do not bulk-bump.").

## Constraints
- **Acceptance precedes flip.** ADR-0035 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Land together with ADR-0034.** Per ADR-0035 D10 / ADR-0034 D7, coordinate the merge of this PR with ADR-0034's acceptance PR. This packet does not edit ADR-0034's file — that is ADR-0034's own acceptance packet's job.
- **Use the pre-reserved invariant numbers 57, 58, 59.** The true current maximum invariant in `constitution/invariants.md` is 51 (verified). Numbers 57-59 are pre-reserved for ADR-0035 as part of a 12-ADR batch; ADR-0034's acceptance packet holds its own distinct reserved block. Do not renumber existing invariants; append at 57-59. If any invariant above 51 lands from outside this 12-ADR batch before merge, shift this block upward — never reuse a number.
- **No bulk 1.0.0 bump.** This packet records *only* the Kernel.Abstractions baseline. It does not declare any other Node's Abstractions package 1.0.0 — that is a deliberate per-Node review (ADR-0035 Follow-up Work), out of scope here.
- **No tag push.** Agents never push git tags (invariant 27). The 1.0.0 baseline note is authored; the tag is a Human Prerequisite.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0035`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0035 to Accepted, add the three versioning invariants to `constitution/invariants.md`, record the Kernel.Abstractions 1.0.0 baseline declaration, and register the abstractions-versioning initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0035 so the versioning-policy packets can reference its decisions as live rules.
- Feature: ADR-0035 Abstractions Versioning and Deprecation Policy rollout, Wave 1.
- ADRs: ADR-0035 (primary), ADR-0034 (lands together — separate initiative), ADR-0026 (the `TenantId` strict-typing bump being declared the 1.0.0 baseline), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0035 stays Proposed until this PR merges.
- Coordinate the merge with ADR-0034's acceptance PR (ADR-0035 D10 / ADR-0034 D7 — they land together).
- Append the three new invariants at the pre-reserved numbers 57, 58, 59 (true current max is 51; 57-59 are reserved for ADR-0035 in a 12-ADR batch). Do not renumber existing invariants. If any invariant above 51 lands from outside the batch before merge, shift the block upward — never reuse a number.
- Record only the Kernel.Abstractions 1.0.0 baseline — no bulk 1.0.0 bump for other Nodes.
- No git tag push — agents never push tags (invariant 27).

**Key Files:**
- `adrs/ADR-0035-abstractions-versioning-and-deprecation-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`
- `repos/HoneyDrunk.Kernel/` (the 1.0.0-baseline note)

**Contracts:** None changed.
