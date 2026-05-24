---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0058", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0058"]
wave: 1
initiative: adr-0058-caching-strategy
node: honeydrunk-architecture
---

# Add the three ADR-0058 caching invariants to constitution/invariants.md

## Summary
Add the three new caching invariants ADR-0058 commits — per-Node opaque caches (D1), tenant-key isolation (D5), and data-classification inheritance (D6) — to `constitution/invariants.md` at numbers `{N1}, {N2}, {N3}`. The three numbers are determined at edit time by reading the ADR-0058 reservation row in `constitution/invariant-reservations.md` (claimed by packet 00) and consuming the block that row reserves. Place each invariant under the appropriate topic group. Governance-only packet; no code, no .NET project.

## Context
ADR-0058 Consequences/Invariants commits three new invariants:

- **D1 invariant** — caches are per-Node, internal, and never crossed through `Abstractions`. This restates Invariant 3's boundary-preservation rule against the specific risk of cache-as-leak.
- **D5 invariant** — any cache holding tenant-scoped data keys by `TenantId` using the `tenant-{tenantId}-{logical-key}` convention. Tenant-scoping is a property of the value, not of the backing.
- **D6 invariant** — cached values inherit the classification of their source per ADR-0049. Caches holding Restricted or Sensitive PII material respect Restricted-tier storage and observability rules.

The Kernel contract packet (04) and the `InMemoryCacheStore<T>` runtime packet (05) reference these invariants as live rules. This packet lands them so subsequent code packets can quote them inline (per the issue-authoring rule that invariants must be inlined as full text, not just cited by number).

This is a docs/governance packet. No code, no workflow, no .NET project.

## Scope
- `constitution/invariants.md` — add three new invariants at numbers `{N1}, {N2}, {N3}` (see Constraints for the numbering rule). Each goes into an appropriate topic group:
  - `{N1}` (caches are per-Node-opaque, D1) — Dependency Invariants group (alongside invariants 1–4 and the existing boundary rules; the cache-opacity rule is a specialization of invariant 3 for the cache case).
  - `{N2}` (tenant-key isolation, D5) — Multi-Tenant Boundary Invariants group (alongside invariant 39; this extends the tenant-keying discipline).
  - `{N3}` (classification inheritance, D6) — new **Data Classification Invariants** section if no such section exists today, placed after the Audit Invariants section; otherwise append into the existing section that already holds any ADR-0049 invariants (if ADR-0049's block has merged into `invariants.md` ahead of this packet). Verify at edit time which arrangement is current.

## Proposed Implementation
0. **Resolve `{N1}/{N2}/{N3}`.** Open `constitution/invariant-reservations.md`. Find the ADR-0058 row in the **Active Reservations** table (claimed by packet 00). The row gives the 3-invariant block (e.g. `54–56`, `57–59`, etc.). `{N1}` is the first number in the block, `{N2}` the second, `{N3}` the third. If packet 00 has not yet landed when this packet is executed, claim the block in `invariant-reservations.md` first per its "How a packet 00 claims a block" procedure (this packet authors the reservation row in that case). Do **not** invent numbers from memory — read the file each time.

1. Add three new invariants to `constitution/invariants.md` (substituting the resolved numbers below):

   **Invariant `{N1}` — Caches are per-Node, internal, and never crossed through `Abstractions`.**
   > A Node's cache is an implementation detail behind its public contracts; no consumer reaches into another Node's cache. Cache hit/miss/eviction telemetry is operational signal (Pulse channel), not a public surface. There is no `ICacheStore<T>` exposed on any Node's `Abstractions` package — the contract lives in `HoneyDrunk.Kernel.Abstractions` and is consumed from there. See ADR-0058 D1.

   **Invariant `{N2}` — Tenant-scoped cached data keys by TenantId.**
   > Any cache holding tenant-scoped data must key by `TenantId` using the `tenant-{tenantId}-{logical-key}` convention. `TenantId.Internal` collapses to the node-level convention without `tenant-` interpolation. Tenant-scoping is a property of the value being cached, not of the backing. The cache backing does not interpret the key — the discipline lives at the call site. See ADR-0058 D5.

   **Invariant `{N3}` — Cached values inherit the classification of their source.**
   > A cache that holds Restricted-tier or Sensitive-PII material inherits Restricted-tier handling rules: encrypted at rest in tenant-isolated backings, never logged in observability or telemetry channels, and subject to right-to-erasure on receipt of the erasure event. Inherited Confidential-tier values follow Confidential handling rules; Internal-tier values follow Internal rules. The cache is a transmission medium for the source's classification, not a laundering surface that converts Restricted to Internal by virtue of being a copy. See ADR-0058 D6 and ADR-0049.

2. Place each invariant in the appropriate topic group. The file is topic-grouped and NOT contiguously numbered, so scan the whole file before placement:
   - `{N1}` in the Dependency Invariants group (alongside 1–4).
   - `{N2}` in the Multi-Tenant Boundary Invariants group (alongside 39).
   - `{N3}` — verify whether a "Data Classification Invariants" section already exists. If yes, append there. If no, create one and place `{N3}` in it, after the Audit Invariants section.

3. **Move the reservation row to history.** In `constitution/invariant-reservations.md`, move the ADR-0058 row from **Active Reservations** to **Reservation History** with the merge date (per the file's "When a reservation is consumed" procedure). The reservation is "consumed" the moment the invariants land in `invariants.md`.

## Affected Files
- `constitution/invariants.md` — three new invariants at the numbers resolved from the ADR-0058 reservation.
- `constitution/invariant-reservations.md` — move the ADR-0058 row from **Active Reservations** to **Reservation History** with merge date. (If packet 00 has not yet claimed a reservation row by the time this packet executes, this packet authors it before consuming it.)

## NuGet Dependencies
None. Markdown-only packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Governance-only — no runtime impact, no canary required.

## Acceptance Criteria
- [ ] `constitution/invariants.md` carries three new invariants at the numbers resolved from the ADR-0058 row in `constitution/invariant-reservations.md`, each citing ADR-0058
- [ ] The first reserved number (`{N1}`) is placed in the Dependency Invariants group
- [ ] The second reserved number (`{N2}`) is placed in the Multi-Tenant Boundary Invariants group
- [ ] The third reserved number (`{N3}`) is placed in a Data Classification Invariants section (new or existing — executor verifies which is current)
- [ ] The full text of each invariant is included, not a placeholder or stub — the body is what gets quoted inline by downstream packets
- [ ] No existing invariant is renumbered
- [ ] `constitution/invariant-reservations.md` has had the ADR-0058 row moved from **Active Reservations** to **Reservation History** with the merge date
- [ ] No ADR status edit in this packet — the ADR-0058 status flip is a separate scope-agent housekeeping step (see the dispatch plan's "Status flip handling" section)

## Human Prerequisites
None. The invariant-number collision check (see Constraints) is a verification step the executing agent performs at edit time, not a portal/human action.

## Referenced ADR Decisions
**ADR-0058 D1 — Caching is per-Node, internal, and opaque across Node boundaries.** A cache is an implementation detail of the Node that owns the cached data. No Node reaches into another Node's cache through `Abstractions`, through composition, or through any other surface.

**ADR-0058 D5 — Tenant-key isolation invariant.** Any cache that holds tenant-scoped data must prefix-key by `TenantId`. The committed key shape mirrors Vault's pattern: `{cache-purpose}:tenant-{tenantId}:{logical-key}`. For `TenantId.Internal` the prefix may collapse to the node-level convention. The discipline lives at the call site; the backing stores what it is given.

**ADR-0058 D6 — Data classification inheritance.** Cached values inherit the classification of their source per ADR-0049. A cache holding Restricted-tier material respects Restricted-tier handling rules: encrypted at rest, never in telemetry, subject to right-to-erasure on receipt of the erasure event.

**ADR-0058 Consequences/Invariants section.** The ADR explicitly enumerates the three new invariants and the topic groups they belong in (Dependency / Multi-Tenant Boundary / Data Classification).

## Constraints
- **Invariant numbers come from `constitution/invariant-reservations.md`, not from this packet.** The reservation file is the single source of truth for in-flight invariant numbering. The procedure at execution time:
  1. Open `constitution/invariant-reservations.md` and read the **Active Reservations** table.
  2. Locate the ADR-0058 row (authored by packet 00). The row gives a contiguous 3-number block.
  3. `{N1}/{N2}/{N3}` = the three numbers in that block (in ascending order).
  4. If the row is missing (packet 00 has not landed yet), author it in this packet first: pick the next free triple above the highest existing reservation per the file's "How a packet 00 claims a block" procedure, add the row, then continue.
  5. Cross-check against `constitution/invariants.md` — if any number in the block has already landed there (i.e. another ADR raced and won), shift the reservation upward to the next free triple, update the row, and update every `{N1}/{N2}/{N3}` placeholder in this packet and in packets 04/05 (whose XML doc inlines these invariants by number).
- **Topic-grouped placement.** The file is topic-grouped, not contiguously numbered. Place each invariant in its appropriate topic group — do not append all three at the end.
- **Full invariant text, not a number-only reference.** Each invariant's body must contain the full text so downstream packets can quote it inline without a follow-up scan (per the issue-authoring rule that invariants must be inlined as full text, not just cited by number).
- **Consume the reservation.** Once the three invariants land in `invariants.md`, move the ADR-0058 row from **Active Reservations** to **Reservation History** in `invariant-reservations.md` with the merge date. A consumed reservation lives in history, not in the active table.
- **No status flip.** ADR-0058's `Status:` header stays `Proposed`. The flip is a separate post-merge housekeeping step gated on ADR-0059's acceptance and the Kernel `0.8.0` release — not part of this packet.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0058`, `wave-1`

## Agent Handoff

**Objective:** Land the three new caching invariants from ADR-0058 in `constitution/invariants.md` at the pre-assigned numbers 82, 83, 84, each in its appropriate topic group.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the three caching invariants live before the Kernel code packets (04 + 05) reference them.
- Feature: ADR-0058 Grid-Wide Caching Strategy rollout, Wave 1.
- ADRs: ADR-0058 D1/D5/D6 (primary), ADR-0049 (classification regime), ADR-0026 (tenant primitives).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — initiative registered in `active-initiatives.md` so the invariants can reference a known initiative slug if useful.

**Constraints:**
- Use numbers **82, 83, 84** unless the pre-edit collision check shows a higher number has landed from outside the ADR-0058 reservation — in that case shift upward, never reuse.
- Place each invariant in its topic group (Dependency / Multi-Tenant Boundary / Data Classification), not at the end of the file.
- Include the full invariant text in each body.
- Do NOT flip the ADR-0058 status — that is a separate housekeeping step.

**Key Files:**
- `constitution/invariants.md` — the three new invariants in their topic groups.

**Contracts:** None changed. Governance only.
