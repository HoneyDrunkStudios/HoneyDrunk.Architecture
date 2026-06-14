---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-3", "meta", "docs", "adr-0048", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0048", "ADR-0008"]
wave: 2
initiative: adr-0048-schema-evolution
node: honeydrunk-architecture
---

# Add schema-change detection to scope-agent packet pre-flight

## Summary
Extend `.claude/agents/scope.md` with a packet pre-flight check that detects whether a packet implies schema changes — and if so, flags the packet so the operator and downstream agents know the work will trigger `database` specialist review. Per ADR-0048 D13: "The agent is also invoked from the `scope` agent when packets imply schema changes — the packet pre-flight check warns the operator that the work will trigger a migration review, so the packet author can sequence Expand and Contract correctly from the start."

## Context
ADR-0048's Follow-up Work names: "Update `.claude/agents/scope.md` packet pre-flight to detect schema-change-implying packets."

`.claude/agents/scope.md` is the scope-agent definition file (the agent producing this packet right now). It governs how scope-agent threads research, decompose, and author work items. Adding a pre-flight schema-change detector means: when the scope agent is given a feature request that might touch a `DbContext`, a `Migrations/` folder, or a relational data layout, the agent recognizes that the resulting packet will trigger `database` specialist review and acts accordingly — warning the operator, sequencing Expand and Contract phases correctly across packets, and including the right boilerplate (e.g. `[ExpandPhase("...")]`/`[ContractPhase("...")]` attribute usage, round-trip test acceptance criteria, `[Rollback]` attribute acceptance criteria) in the packet body.

The pre-flight is **advisory-by-text**, not a hard gate. The scope agent doesn't refuse to author a packet that implies schema changes; it surfaces a banner-style warning and includes the right boilerplate. The human operator is the final arbiter (consistent with the broader advisory posture per ADR-0011 D5 / ADR-0046 D1).

**Coupling with the review agent's context-loading contract.** Per invariant 33, the set of files loaded by the review agent must be a superset of the set loaded by the scope agent. ADR-0048 adds `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md`, the per-Node `integration-points.md` Migration Coordination section (added in packet 01), and `catalogs/grid-health.json`'s `schema_evolution` field (added in packet 01) to the scope agent's awareness surface. The `review` agent's context-loading list must be updated to include these in the same PR or a follow-up that mirrors the addition — this packet records the obligation in the constraints section and adds the files to the `scope.md` context-loading section. **Whether `review.md`'s context-loading list is mirrored in this packet or in packet 03 is a sequencing call** — packet 03 explicitly does NOT touch `review.md`'s context-loading list (it only touches the D3 category 13 stanza). Therefore this packet ALSO updates `review.md`'s context-loading list to preserve the invariant-33 symmetry. (This is the one cross-file edit in this packet beyond `scope.md`.)

This is a docs/agent-configuration packet. No code, no .NET project.

## Scope
- `.claude/agents/scope.md` — add a packet pre-flight schema-change-detection section; add the three new files (ADR-0048, `integration-points.md` Migration Coordination, `grid-health.json`'s `schema_evolution` field) to the context-loading list.
- `.claude/agents/review.md` — add the same three files to the context-loading list, preserving invariant 33's coupling. This is the only `review.md` edit in this packet (the D3 category 13 stanza is owned by packet 03).
- No edit to `database.md` (packet 02 owns it).
- No new agent file.

## Proposed Implementation

### 1. `.claude/agents/scope.md` — packet pre-flight schema-change detection

Locate the section of `scope.md` that documents the scope agent's pre-flight checks (the "Before Scoping" or "Phase 2: Research" section, depending on the file's current structure). Add a new sub-section, titled along the lines of:

```markdown
### Pre-flight: schema-change detection

When scoping work, detect whether the resulting packet(s) will touch schema. **Triggers:**

- The request mentions a new entity, a new column, a column rename, a column type change, a new table, a new index, a foreign-key change, or any DDL-flavoured verb against a relational store.
- The request targets a Node whose `catalogs/grid-health.json` `schema_evolution` field is `ef-core-migrations` and the work modifies the Node's `DbContext` or a model file referenced from it.
- The request targets a Node whose `schema_evolution` field is `cosmos-schema-on-read` and the work adds/removes a document field or changes a partition key.

**When a trigger fires, the scope agent:**

1. Adds a banner-style warning at the top of each affected packet body, reading: "**Schema change detected.** This packet will trigger `database` specialist review per ADR-0048 D13. Sequence the work as Expand / migrate code / Contract phases per ADR-0048 D2; include `[ExpandPhase("MIG-...")]` or `[ContractPhase("MIG-...")]` attributes per ADR-0048 D5; include a `[Rollback(Strategy = ..., Notes/Reason = "...")]` attribute per ADR-0048 D10; include a Tier 2b round-trip test per ADR-0048 D12 and ADR-0047 D11."
2. Adds boilerplate to the packet's Acceptance Criteria: `[Rollback]` attribute presence, `[ExpandPhase]`/`[ContractPhase]` annotation if part of a paired migration, Tier 2b round-trip test in `HoneyDrunk.<Node>.Tests.Integration.Containers/Migrations/<Node>MigrationRoundTripTests.cs`, online-primitive usage if the target table is or might be ≥ 100k rows.
3. If the schema change requires Expand and Contract phases, **decomposes the work into multiple packets** — one for Expand, one for the code migration, one for Contract — separated by the appropriate backward-compatibility window per ADR-0048 D5 (Audit indefinite; Tier 0/1 customer-facing 14 days; Tier 2 internal 1 deploy; idempotency 30 days).
4. Warns the operator in the final summary that the resulting packet(s) will trigger `database` specialist review.
5. For document-store changes (`cosmos-schema-on-read`), follows ADR-0048 D7 instead of D2 — the change is a new field write or a `Migrations/Backfill-YYYYMMDD-{description}.md` runbook, not an EF migration; partition-key changes are flagged as a deferred-ADR follow-up (D7 names it as the most expensive Cosmos migration shape, gated on a follow-up ADR).
6. For `AuditEntry`-touching changes, additionally enforces ADR-0048 D8: no column drops, no type narrowing, no `NOT NULL` additions; new columns always nullable; suggest the paired-table pattern (`AuditEntryV2`) for any case that genuinely needs a new shape.
```

Match the file's existing tone, formatting, and severity language. The check is advisory-by-text: the scope agent doesn't refuse to author a packet that implies schema changes; it surfaces the warning and includes the right boilerplate.

### 2. `.claude/agents/scope.md` — context-loading list additions

In the section that lists the files the scope agent loads before producing a packet (per invariant 33), add:

- `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md` — needed to apply the D2/D5/D6/D8/D9/D10/D12 boilerplate correctly when a schema change is detected.
- The per-Node `repos/HoneyDrunk.<Node>/integration-points.md` Migration Coordination section — gives the scope agent the per-Node migration framework and cross-Node coordination context.
- `catalogs/grid-health.json` — the `schema_evolution` field per Node tells the scope agent whether the target is relational (ADR-0048 D2 path) or document-store (ADR-0048 D7 path) or no-schema (no detector fires).

### 3. `.claude/agents/review.md` — mirror the context-loading additions

Per invariant 33, the review agent's context-loading set must be a superset of the scope agent's. Add the same three files to `review.md`'s context-loading list:

- `adrs/ADR-0048-data-schema-evolution-and-migration-policy.md`
- The per-Node `integration-points.md` Migration Coordination section
- `catalogs/grid-health.json` (specifically the `schema_evolution` field per Node)

This is the only `review.md` edit in this packet. The D3 category 13 stanza (packet 03) is a separate, parallel edit; the two packets edit different sections of `review.md` and can land in either order.

## Affected Files
- `.claude/agents/scope.md` — pre-flight schema-change-detection section + context-loading additions.
- `.claude/agents/review.md` — context-loading additions only (the D3 category 13 stanza is packet 03's responsibility).

## NuGet Dependencies
None. This packet touches only Markdown agent-definition files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `.claude/agents/` is governance content that lives in this repo.
- [x] No code change in any other repo.
- [x] The pre-flight detection is the ADR-0008-established scope-agent surface; this packet extends it with a schema-change detector, consistent with ADR-0048 D13's explicit instruction.

## Acceptance Criteria
- [ ] `.claude/agents/scope.md` carries a pre-flight schema-change-detection sub-section with the trigger conditions named explicitly (entity/column/table/index DDL verbs; `ef-core-migrations` or `cosmos-schema-on-read` Node; `DbContext` modification)
- [ ] The detector lists the six actions the scope agent takes when a trigger fires (banner warning; acceptance-criteria boilerplate; Expand/Contract decomposition; final-summary warning; D7 path for document stores; D8 enforcement for `AuditEntry`)
- [ ] `.claude/agents/scope.md` context-loading list includes ADR-0048, the per-Node `integration-points.md` Migration Coordination section, and `catalogs/grid-health.json`'s `schema_evolution` field
- [ ] `.claude/agents/review.md` context-loading list includes the same three additions (preserving invariant 33's coupling)
- [ ] No edit to `review.md`'s D3 category 13 rubric stanza in this packet (that is packet 03's responsibility)
- [ ] No edit to `database.md` in this packet (that is packet 02's responsibility)
- [ ] The detector is documented as advisory — the scope agent surfaces the warning but does not refuse to author a packet
- [ ] The format matches `scope.md`'s existing conventions

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0048 D13 — Specialist `database` agent on every migration-touching PR; also invoked from `scope` when packets imply schema changes.** "The agent is also invoked from the `scope` agent when packets imply schema changes — the packet pre-flight check warns the operator that the work will trigger a migration review, so the packet author can sequence Expand and Contract correctly from the start."

**ADR-0048 D2 — Expand → migrate code → Contract pattern.** Non-trivial schema changes are three deploys, not one. The detector's role is to make the scope agent decompose accordingly.

**ADR-0048 D5 — Backward-compatibility window per tier.** Audit indefinite; Tier 0/1 customer-facing 14 days; Tier 2 internal 1 deploy; idempotency 30 days. The detector inserts the appropriate window guidance into multi-packet decomposition.

**ADR-0048 D7 — Document stores follow schema-on-read.** No DDL; new fields by writing; backfill via `Migrations/Backfill-YYYYMMDD-{description}.md` runbook; partition-key change is a container migration and a deferred-ADR trigger. The detector switches to the D7 path when the target Node's `schema_evolution` is `cosmos-schema-on-read`.

**ADR-0048 D8 — Audit table specifics.** No column drops, no type narrowing, no `NOT NULL` add; new columns always nullable; paired-table pattern for breaking changes. The detector enforces these when the target is `AuditEntry` or any append-only-by-interface store.

**ADR-0048 D10 — `[Rollback]` attribute.** Every migration class carries `[Rollback(Strategy = ..., Notes/Reason = "...")]`. The detector includes this in the packet's acceptance criteria.

**ADR-0048 D12 — Round-trip test in `HoneyDrunk.<Node>.Tests.Integration.Containers/Migrations/<Node>MigrationRoundTripTests.cs`.** Tier 2b CI gate per ADR-0047 D11. The detector includes this in the packet's acceptance criteria.

**ADR-0008 — Scope agent and packet conventions.** The scope agent owns the packet pre-flight; this packet extends it.

**Invariant 33 — Review-agent and scope-agent context-loading contracts are coupled.** "The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other." This packet mirrors the additions in both files to preserve the invariant.

## Constraints
- **Advisory-by-text, not a hard gate.** The detector surfaces warnings and includes boilerplate; it does not refuse to author a packet. The human operator is the final arbiter per ADR-0011 D5.
- **Mirror the context-loading list in both `scope.md` and `review.md`.** Invariant 33 requires it. The scope-side and review-side additions land in the same PR (this packet); the D3 category 13 stanza (packet 03) is a separate edit that does not touch the context-loading list.
- **Decompose into multiple packets when Expand and Contract are needed.** Per ADR-0048 D2, a non-trivial schema change is three deploys; the scope agent decomposes accordingly. Do not author a single packet that bundles Expand + Contract.
- **Document-store path uses D7, not D2.** When the target Node's `schema_evolution` is `cosmos-schema-on-read`, the detector switches paths; no EF migration is authored, and a `Migrations/Backfill-YYYYMMDD-{description}.md` runbook is the artifact.
- **`AuditEntry` enforcement is hard.** D8's prohibitions (no column drops, no type narrowing, no `NOT NULL` add) are migration-time invariants per ADR-0030 D4 and ADR-0048 D8. The detector surfaces these as blocking-level guidance, not advisory.

## Labels
`feature`, `tier-3`, `meta`, `docs`, `adr-0048`, `wave-2`

## Agent Handoff

**Objective:** Add a schema-change pre-flight detector to `.claude/agents/scope.md` and mirror the new context-loading entries to `.claude/agents/review.md` per invariant 33.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the scope agent self-aware of schema-changing work, surface a warning to the operator, sequence Expand and Contract phases correctly across packets, and preserve invariant 33's review/scope context-loading symmetry.
- Feature: ADR-0048 Schema Evolution rollout, Wave 2.
- ADRs: ADR-0048 D13/D2/D5/D7/D8/D10/D12 (primary), ADR-0008 (scope-agent surface), ADR-0011 D5 (advisory posture), ADR-0046 D1/D3 (specialist pattern), ADR-0047 D11 (Tier 2b round-trip test).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0048 must be Accepted so the detector can cite its decisions as live rules.

**Constraints:**
- Advisory-by-text — the detector surfaces warnings, does not refuse to author.
- Mirror context-loading additions in both `scope.md` and `review.md` (invariant 33).
- Decompose multi-phase schema changes into multiple packets (one for Expand, one for Contract).
- Document-store path uses D7, not D2.
- `AuditEntry` D8 prohibitions are hard.

**Key Files:**
- `.claude/agents/scope.md` (pre-flight detector + context-loading additions).
- `.claude/agents/review.md` (context-loading additions only).

**Contracts:** None changed.
