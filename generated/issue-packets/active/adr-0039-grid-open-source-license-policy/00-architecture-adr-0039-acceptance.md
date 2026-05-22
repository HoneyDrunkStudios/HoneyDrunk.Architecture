---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0039", "wave-1"]
dependencies: []
adrs: ["ADR-0039", "ADR-0027", "ADR-0034"]
accepts: ["ADR-0039"]
wave: 1
initiative: adr-0039-grid-open-source-license-policy
node: honeydrunk-architecture
---

# Accept ADR-0039 — flip status, add the two license invariants, register the license-policy initiative

## Summary
Flip ADR-0039 (Grid Open Source License Policy) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the two new license invariants ADR-0039 commits in its Consequences section to `constitution/invariants.md`, and register the `adr-0039-grid-open-source-license-policy` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0039 records the Grid's first Grid-level license decision: MIT as the default for every Node (D1); FSL-1.1-MIT for revenue Nodes, formalizing the one-off ADR-0027 precedent (D2); MIT for client SDKs even when the engine is FSL (D3); proprietary copyright-reservation for private Nodes (D4); DCO not CLA for contributions (D5); no per-file license headers (D6); CC-BY-4.0 for documentation/content (D7); a `license` field added to `catalogs/nodes.json` (D8); and a heavyweight ADR-amendment procedure for any future license change (D9).

Every other packet in this initiative references ADR-0039's D-decisions as live rules. The acceptance flip must land first so those references read against Accepted text.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0039-grid-open-source-license-policy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0039 row Status column to Accepted.
- `constitution/invariants.md` — add the two new license invariants ADR-0039 commits (see Proposed Implementation for exact text). ADR-0039's reserved invariant block is **67 and 68**. The current highest invariant in `constitution/invariants.md` is 51 (verified); numbers 67-68 are pre-reserved as part of a 12-ADR batch, leaving a deliberate gap above 51. If any invariant above 51 lands from outside this batch before merge, shift this block upward — never reuse a number.
- `initiatives/active-initiatives.md` — register the `adr-0039-grid-open-source-license-policy` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0039 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0039 index row in `adrs/README.md` to Accepted.
3. Add two new invariants to `constitution/invariants.md` under a new `## Licensing Invariants` section, appended after the existing `## Audit Invariants` section. Use ADR-0039's pre-reserved invariant numbers **67 and 68**. The text, taken verbatim-in-substance from ADR-0039's Consequences "Invariants" subsection:
   - **Every Node has a `license` field in `catalogs/nodes.json` and a matching `LICENSE` file in the repo root.** The SPDX expression in the catalog (`MIT`, `FSL-1.1-MIT`, or `proprietary`) must match the actual `LICENSE` / `LICENSE.md` file the repo carries. Drift is reconciled by `hive-sync`. See ADR-0039 D8.
   - **SDK and client-library packages do not inherit the engine's restrictive license.** When a revenue Node's engine is FSL-1.1-MIT, its client SDK is MIT, set by a per-project `<PackageLicenseExpression>MIT</PackageLicenseExpression>` override that supersedes the FSL `Directory.Build.props` default. See ADR-0039 D3.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0039-grid-open-source-license-policy.md`
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
- [ ] ADR-0039 header reads `**Status:** Accepted`
- [ ] The ADR-0039 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the two new license invariants (license-field-matches-LICENSE-file; SDKs do not inherit the engine's restrictive license), numbered 67 and 68, each citing ADR-0039
- [ ] `initiatives/active-initiatives.md` registers the `adr-0039-grid-open-source-license-policy` initiative with a packet checklist
- [ ] No catalog schema change in this packet (the `license` field is added to `catalogs/nodes.json` in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0039 D8 — License catalog.** `catalogs/nodes.json` gains a `license` field per Node with the SPDX expression (`MIT`, `FSL-1.1-MIT`, `proprietary`). The catalog is the single source of truth; ADR-0034's `Directory.Build.props` default and CI gates derive from it; `hive-sync` reconciles the catalog with each repo's actual `LICENSE` file.

**ADR-0039 D3 — SDKs and client libraries: MIT regardless of engine license.** A revenue Node's client SDK is MIT-licensed even when the engine is FSL. The SDK's project carries a per-project `<PackageLicenseExpression>MIT</PackageLicenseExpression>` that overrides the `Directory.Build.props` default.

**ADR-0039 Consequences — Invariants.** ADR-0039 adds exactly two invariants: (1) every Node has a `license` field in the catalog and a matching `LICENSE` file, reconciled by `hive-sync`; (2) SDK packages do not inherit the engine's restrictive license — per-project override required when the engine is FSL.

## Constraints
- **Acceptance precedes flip.** ADR-0039 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Use the pre-reserved invariant numbers 67 and 68.** The current highest invariant in `constitution/invariants.md` is 51 (verified). Invariant numbers 67-68 are pre-reserved as part of a 12-ADR batch — there is a deliberate gap above 51. If any invariant above 51 lands from outside this batch before merge, shift this block upward; never reuse a number. Do not renumber existing invariants.
- This is the first packet in the initiative — nothing blocks it.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0039`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0039 to Accepted, add the two license invariants to `constitution/invariants.md`, and register the license-policy initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0039 so the license-fan-out packets can reference its decisions as live rules.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 1.
- ADRs: ADR-0039 (primary), ADR-0027 (FSL precedent for Notify/Communications, formalized by D2), ADR-0034 (the `<PackageLicenseExpression>` consumer of this policy), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0039 stays Proposed until this PR merges.
- Append the two new invariants as 67 and 68 (ADR-0039's pre-reserved block; current max is 51, with a deliberate batch gap above it). If any invariant above 51 lands from outside the batch before merge, shift this block upward — never reuse a number. Do not renumber existing invariants.

**Key Files:**
- `adrs/ADR-0039-grid-open-source-license-policy.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
