---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["chore", "tier-3", "core", "docs", "adr-0048", "wave-4"]
dependencies: ["packet:00", "packet:06"]
adrs: ["ADR-0048", "ADR-0042"]
wave: 4
initiative: adr-0048-schema-evolution
node: honeydrunk-kernel
---

# Document the Cosmos schema-on-read pattern for the Kernel idempotency dedup store

## Summary
Phase 2 of ADR-0048's rollout (D14): the Kernel's Cosmos-backed idempotency dedup store (per ADR-0042 D2) gains its schema-on-read documentation per ADR-0048 D7. Author `src/HoneyDrunk.Kernel/Migrations/README.md` (or `src/HoneyDrunk.Kernel.Idempotency.Cosmos/Migrations/README.md`, depending on where the Kernel's idempotency-Cosmos surface lives at execution time) — a Markdown doc describing the dedup-state document shape, the partition key, the TTL policy, the schema-on-read field-evolution rules, and a placeholder backfill-runbook location.

## Context
ADR-0048 D14 Phase 2: "(Week 2–4) — Pilot on **HoneyDrunk.Kernel.Idempotency** (per ADR-0042). The idempotency store contract test (Tier 2a per ADR-0047 D4) gains the round-trip migration test in Tier 2b; the Cosmos backing follows D7's schema-on-read pattern. This pilot exercises the document-store side of the policy on a Node that already has a contract test."

ADR-0048 D7 specifies the document-store policy: "The `IIdempotencyStore` default backing per ADR-0042 D2 is Cosmos, which means the idempotency store follows D7, not D1. The dedup-state schema is documented in the Kernel's `Migrations/` folder as a Markdown doc with the document shape, partition key, and TTL policy — not as an EF migration."

This packet ships **the Markdown doc** — not a new schema, not a new code change, not a new test. It is the schema-on-read equivalent of an EF migration: a deliberate record of the document shape and its evolution rules. Future field additions to the dedup-state document are reflected by editing this doc; field removals follow the schema-on-read Contract-phase analogue per ADR-0048 D7.

**Location of the doc.** ADR-0048 D7 names "the Kernel's `Migrations/` folder" without disambiguating whether that's `src/HoneyDrunk.Kernel/Migrations/` (the runtime package — which doesn't host the Cosmos store) or `src/HoneyDrunk.Kernel.Idempotency.Cosmos/Migrations/` (the Cosmos-backed idempotency package, which is the actual carrier of the document shape). **The Cosmos backing package is shipped from `HoneyDrunk.Data`, not `HoneyDrunk.Kernel`** — per the ADR-0042 initiative's dispatch plan, the package names are `HoneyDrunk.Data.Idempotency.Cosmos` and `HoneyDrunk.Data.Idempotency.InMemory`. This creates a path discrepancy: ADR-0048 D7 says "the Kernel's `Migrations/` folder" but the actual Cosmos backing lives in the Data repo.

**Resolution.** The dedup-state document shape is a Kernel contract (the `IIdempotencyStore` interface lives in `HoneyDrunk.Kernel.Abstractions`); the Cosmos backing is a Data implementation. The schema-on-read doc, like an EF migration, belongs **with the code that owns the schema** — which is the Cosmos backing in the Data repo. **Pragmatic choice for this packet**: target `HoneyDrunk.Kernel`, and ship the doc in `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` — placing it next to the contract, where it survives any future re-homing of the Cosmos backing. The doc describes the **canonical document shape any backing must conform to**, with the Cosmos-specific details (partition key field name, TTL field name) noted as the v1 backing's implementation. This is the cleanest mapping of ADR-0048 D7's intent ("the dedup-state schema is documented in the Kernel's `Migrations/` folder") to the Grid's actual package layout.

**Why target Kernel rather than Data.** If the doc lives in Data, every consumer of the contract has to fetch the Data repo to understand the dedup-state shape. If the doc lives next to the Kernel-owned contract, it travels with the contract — every consumer of `HoneyDrunk.Kernel.Abstractions` has the doc adjacent to the interface it implements/consumes. This is the same principle that puts the `[IIdempotencyStore]` interface in Kernel.Abstractions despite the backing living in Data.

**Alternative path: ship the doc in Data instead.** If the executor and operator prefer to keep the doc adjacent to the implementation (the Data repo, alongside `HoneyDrunk.Data.Idempotency.Cosmos`), retarget this packet's `target_repo` to `HoneyDrunkStudios/HoneyDrunk.Data` and adjust the path to `src/HoneyDrunk.Data.Idempotency.Cosmos/Migrations/README.md`. The acceptance criteria are otherwise identical. The default in this packet is Kernel for the reasons named above; the alternative is a one-line edit if the operator prefers it.

This is a docs/governance packet. No code change in the Kernel runtime or in the Kernel.Abstractions contracts.

## Scope
- `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` — new file documenting the dedup-state document shape, partition key, TTL policy, schema-on-read evolution rules, and a placeholder backfill-runbook location.
- `src/HoneyDrunk.Kernel.Abstractions/Migrations/Backfill/` — new directory created empty (with a `.gitkeep` if necessary) so future backfill runbooks have a home matching ADR-0048 D7's convention.
- Optionally, a per-package CHANGELOG entry for `HoneyDrunk.Kernel.Abstractions` noting the new doc. The doc itself is not a behavioral change; if the Kernel solution chooses not to bump for a docs-only addition, no version bump is needed — but per invariant 27 if any version bump is needed for another reason in the same release, the doc rides along.
- Repo-level `CHANGELOG.md` entry only if the solution version bumps.

## Proposed Implementation

### 1. Author `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md`

Sections (matching the template from packet 06 with adaptations for the schema-on-read case):

```markdown
# Migrations — Kernel.Abstractions (dedup-state document shape)

This is the Kernel-owned record of the **document shape** for the `IIdempotencyStore` Cosmos-backed dedup state introduced by ADR-0042 D2. The Cosmos backing follows **schema-on-read** per ADR-0048 D7 — there is no DDL, no EF migration, and no `[Rollback]` attribute. This README is the schema-on-read equivalent of a migration history.

## Framework

- **Schema-evolution posture:** `cosmos-schema-on-read` (matches `catalogs/grid-health.json` `schema_evolution` field for `honeydrunk-kernel`).
- **Provider:** Azure Cosmos DB (Core SQL API).
- **Backing package (v1):** `HoneyDrunk.Data.Idempotency.Cosmos` (shipped from the Data repo per the ADR-0042 initiative).

## Canonical document shape (v1)

```json
{
  "id": "<IdempotencyKey value, a string per ADR-0042 D1>",
  "consumerGroup": "<consumer-group name; partition key>",
  "firstSeenAt": "<ISO-8601 timestamp>",
  "state": "Claimed | Completed",
  "leaseExpiresAt": "<ISO-8601 timestamp; null when Completed>",
  "outcome": {
    "status": "Succeeded | Failed",
    "payload": "<small optional payload for ADR-0042 D6 reply derivation>"
  },
  "ttl": "<seconds-to-live; Cosmos native TTL>"
}
```

### Fields

- **`id`** — the `IdempotencyKey` string value (ADR-0042 D1). Cosmos document key.
- **`consumerGroup`** — the consumer-group name. **Partition key** per ADR-0042 D2.
- **`firstSeenAt`** — ISO-8601 timestamp at which the consumer first claimed the key.
- **`state`** — `Claimed` or `Completed`. State machine per ADR-0042 D3.
- **`leaseExpiresAt`** — ISO-8601 timestamp for the claim's lease expiry; null once `state` flips to `Completed`. Drives the take-over-expired-lease branch of `TryClaim`.
- **`outcome`** — present only when `state == Completed`. The `IdempotencyOutcome` record (status + small optional payload).
- **`ttl`** — Cosmos native TTL in seconds. Per ADR-0042 D4: 7 days standard, 30 days for billing/audit consumer-groups. The store does not hardcode; the caller supplies the TimeSpan to `TryClaim`.

## Partition key

`/consumerGroup`. Per ADR-0042 D2 — each consumer-group's dedup state lives in its own partition. Cross-consumer-group queries are not part of the read surface; the only operations are per-key point-reads and per-key writes within a partition.

## TTL policy

- Container-level default TTL is enabled. Per-item TTL via the `ttl` field on the document overrides the default.
- ADR-0042 D4 ranges: 7 days standard; 30 days for billing/audit consumer-groups. The caller (`AddCosmosIdempotencyStore(consumerGroup, ttl, ...)`) supplies the TimeSpan; the store writes it into `ttl`.
- Cosmos honours per-item TTL natively — no application-level expiry is needed.

## Schema-on-read evolution

Per ADR-0048 D7, schema-on-read changes proceed as follows:

### New fields

- **Adding a field:** write it on the next write. Reading code tolerates absence (missing fields default to type zero values per ADR-0048 D7).
- **Backward-compatibility window:** matches the idempotency-store window per ADR-0048 D5: **2 stable deploys minimum, or 30 days of uptime, whichever is longer**. The dedup state must survive rollback of the consumer; old entries must remain legible to the old code revision.

### Field removal

- Only after **all reading code has dropped its reference** to the field.
- Only after a window matching the idempotency-store tier (30 days per ADR-0048 D5).
- No DDL — reading code simply stops referencing the field; new writes stop writing it; old documents retain it until TTL purges them.

### Type changes on an existing field

- Same constraints as field removal: only after all reading code is tolerant of both the old and new type.
- For string-typed fields where a discriminant value space changes (e.g. adding `"Cancelled"` to `state`), the new value is read by tolerant reading code immediately; old reading code must tolerate the unknown value (raise or default per the application's choice — document the choice in the calling code, not here).

### Partition key changes

**Not possible in place.** Per ADR-0048 D7: a partition-key change is a **container migration** — new container, dual-write window, backfill, dual-read window, cut over reads, drain old container, delete.

If a partition-key change is ever needed for the dedup-state container, it triggers a **follow-up ADR** per ADR-0048 D7 ("the most expensive migration shape in the Grid; record it as a follow-up ADR if and when the first partition-key change is needed").

## Backfill runbooks

Backfill jobs for retroactively populating a new field onto existing dedup-state documents live as Markdown runbooks in `Migrations/Backfill/<YYYYMMDD>-<description>.md`. None today; the directory is created empty in anticipation.

Each runbook documents: the field being backfilled, the read-modify-write loop, the rate limit and partition iteration strategy, the verification step, and the rollback (typically "do nothing — the new field is additive").

## Running schema-on-read changes

There is no `migrate.yml` invocation for a schema-on-read change — by definition, no DDL runs. The procedure for a new field:

1. Write a PR adding a new optional property to the `IIdempotencyStore` implementation (`CosmosIdempotencyStore` in `HoneyDrunk.Data.Idempotency.Cosmos`).
2. Update this README's "Canonical document shape" with the new field.
3. Deploy the PR. New writes carry the new field; old documents do not (the reading code tolerates absence).
4. After the ADR-0048 D5 backward-compatibility window (30 days for the idempotency store), and only if every reading-code revision tolerates the new field, the field is considered fully part of the canonical shape.

The procedure for a field removal:

1. Update reading code to stop referencing the field; deploy.
2. Wait the ADR-0048 D5 window (30 days).
3. Update writing code to stop writing the field; deploy.
4. Update this README's "Canonical document shape" to remove the field.
5. Old documents retain the field until TTL purges them; no rewrite job is needed.

## Tests

The Cosmos backing's behavior is exercised by the ADR-0047 D11 contract test for `IIdempotencyStore` (the Tier 2a contract test in `HoneyDrunk.Kernel.Abstractions.Tests` or the per-Node convention). ADR-0047 packet 12 (the Cosmos-bound Tier 2b run of the contract test) is unparked once the Cosmos backing exists (ADR-0042 packet 03 ships it). Round-trip migration tests in the relational-store sense (ADR-0048 D12) do not apply to schema-on-read; the contract test is the equivalent gate.

## See also

- ADR-0042 — Idempotency Contract for Async Boundaries (the contract this backing implements).
- ADR-0048 — Data Schema Evolution and Migration Policy (the schema-on-read policy this README implements; D7 specifically).
- `HoneyDrunk.Data.Idempotency.Cosmos` — the v1 Cosmos backing package; shipped from the Data repo per the ADR-0042 initiative.
```

### 2. Create the empty `Backfill/` directory

`src/HoneyDrunk.Kernel.Abstractions/Migrations/Backfill/.gitkeep` — empty file so the directory is committed.

### 3. CHANGELOG updates

- If the Kernel solution version is being bumped for another reason in the same release, the doc rides along — add a one-line per-package CHANGELOG entry for `HoneyDrunk.Kernel.Abstractions` noting the new doc.
- If the Kernel solution is not bumping, do not bump for a docs-only addition. The doc lands without a version bump; per invariant 12/27 a docs-only change to an existing project does not require a per-package CHANGELOG entry on its own.
- Confirm the Kernel solution's release state at execution time. If a release is imminent, attach to it; if not, ship the doc on its own and let the next release pick it up.

## Affected Files
- `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` (new).
- `src/HoneyDrunk.Kernel.Abstractions/Migrations/Backfill/.gitkeep` (new, empty).
- Conditionally: `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` if a solution bump rides along; repo-level `CHANGELOG.md` if applicable.

## NuGet Dependencies
None. This packet touches only Markdown files; no .NET project is created or modified (the `.gitkeep` is in a directory next to an existing project, not inside the project's compiled sources).

## Boundary Check
- [x] All edits in `HoneyDrunk.Kernel`. Routing rule "context, GridContext, NodeContext, OperationContext, lifecycle, ... → HoneyDrunk.Kernel" maps for Kernel-owned contracts and adjacent reference docs.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime edge. The doc lives next to the `IIdempotencyStore` contract, which Kernel already owns.
- [x] The path placement (Kernel.Abstractions, not the Cosmos backing in Data) is justified in Proposed Implementation; the alternative (placing the doc in Data) is documented as a one-line retarget if the operator prefers it.

## Acceptance Criteria
- [ ] `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` exists with all eight sections named in Proposed Implementation: Framework, Canonical document shape, Partition key, TTL policy, Schema-on-read evolution (with new fields / field removal / type changes / partition-key sub-sections), Backfill runbooks, Running schema-on-read changes, Tests, See also
- [ ] The canonical document shape lists all seven fields with types and a brief description (`id`, `consumerGroup`, `firstSeenAt`, `state`, `leaseExpiresAt`, `outcome`, `ttl`)
- [ ] The partition key is named as `/consumerGroup` per ADR-0042 D2
- [ ] The TTL policy cites ADR-0042 D4's 7-day standard and 30-day billing/audit windows
- [ ] The schema-on-read evolution section names the 30-day window for the idempotency store per ADR-0048 D5
- [ ] The partition-key-change sub-section names the deferred follow-up ADR per ADR-0048 D7
- [ ] The "Running schema-on-read changes" section documents the field-add procedure and the field-removal procedure
- [ ] The "Tests" section references ADR-0047 packet 12 as the unparked contract-test gate
- [ ] `src/HoneyDrunk.Kernel.Abstractions/Migrations/Backfill/.gitkeep` exists so the directory is committed
- [ ] No new compiled file is added to any `.csproj`; the doc is `.md`-only and is not picked up as compiled content
- [ ] If a Kernel solution bump rides along, `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` carries a per-package entry; if not, no version bump for the docs-only addition
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Path-placement decision (optional, before execution).** Default is `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` (next to the contract); alternative is `src/HoneyDrunk.Data.Idempotency.Cosmos/Migrations/README.md` (next to the v1 backing, requires retargeting this packet to the Data repo). The default is the cleaner long-term answer (the doc travels with the contract); the alternative is the conventional EF Core placement (the doc lives with the implementation). If the operator prefers the alternative, retarget the packet before execution.

## Referenced ADR Decisions

**ADR-0048 D7 — Document stores follow schema-on-read.** New fields by writing them; reading code tolerates absence; backfill via `Migrations/Backfill/<YYYYMMDD>-<description>.md` runbooks; field removal mirrors relational Contract phase; partition-key changes are container migrations and a deferred-ADR trigger. "The `IIdempotencyStore` default backing per ADR-0042 D2 is Cosmos, which means the idempotency store follows D7, not D1. The dedup-state schema is documented in the Kernel's `Migrations/` folder as a Markdown doc with the document shape, partition key, and TTL policy — not as an EF migration."

**ADR-0048 D14 Phase 2 — Pilot on `HoneyDrunk.Kernel.Idempotency`.** "The Cosmos backing follows D7's schema-on-read pattern. This pilot exercises the document-store side of the policy on a Node that already has a contract test."

**ADR-0048 D5 — Backward-compatibility window for idempotency stores.** "Two stable deploys minimum, or 30 days of uptime (matching ADR-0042 D4's billing/audit TTL). The dedup state must survive rollback of the consumer; old entries must remain legible to the old code revision."

**ADR-0042 D1 — `IdempotencyKey` shape.** Opaque string; produced once at message origination; UUID v4 by default; deterministic keys allowed. Lives in the document's `id` field.

**ADR-0042 D2 — Consumer-side dedup state, per consumer-group.** "Default backing is a small Cosmos container, partition key = consumer-group." Drives the `consumerGroup` field as Cosmos partition key.

**ADR-0042 D3 — Consumer pattern: claim, process, complete.** Drives the `state` field (`Claimed`/`Completed`) and `leaseExpiresAt`/`outcome` fields.

**ADR-0042 D4 — TTL ranges.** 7 days standard, 30 days for billing/audit consumer-groups. The caller supplies the TimeSpan; the store does not hardcode. The `ttl` field carries the per-item TTL.

**ADR-0042 D6 — Request/reply key derivation.** Drives the small optional `payload` on the `outcome` field (for `SHA256(request:reply)` derivation).

**ADR-0047 D11 — Tier 2a/2b contract test for `IIdempotencyStore`.** ADR-0047 packet 12 is the Cosmos-bound Tier 2b run; unparked once the Cosmos backing exists (ADR-0042 packet 03 shipped it). This README points at packet 12 as the equivalent of the relational-store round-trip test gate.

## Constraints
- **No EF migration in this packet.** Schema-on-read has no DDL by definition. Do not invoke `dotnet ef migrations add`.
- **No `[Rollback]` attribute.** ADR-0048 D7 / D12 do not require it for schema-on-read; the attribute applies to EF migration classes only.
- **No code change in `HoneyDrunk.Kernel.Abstractions` or `HoneyDrunk.Kernel`.** The doc is reference content adjacent to the contract; the contract itself (`IIdempotencyStore`) is unchanged.
- **Path placement is Kernel by default.** The doc lives next to the contract per the long-term reasoning in Proposed Implementation. Operator may retarget to Data before execution.
- **The 30-day window matches ADR-0048 D5 idempotency-store tier and ADR-0042 D4 billing/audit TTL.** Do not paraphrase or round.
- **Partition-key change is a deferred follow-up ADR.** Do not author the follow-up in this packet; just record the trigger.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0048`, `wave-4`

## Agent Handoff

**Objective:** Author the schema-on-read documentation for the Cosmos-backed `IIdempotencyStore` dedup state per ADR-0048 D7 and D14 Phase 2.

**Target:** `HoneyDrunk.Kernel`, branch from `main`. (Alternative: `HoneyDrunk.Data` — see Human Prerequisites for the path-placement decision.)

**Context:**
- Goal: Exercise the document-store side of ADR-0048's policy on the first Node that has a contract test (the Kernel idempotency-store contract test from ADR-0047 packet 11/12).
- Feature: ADR-0048 Schema Evolution rollout, Wave 4 (Phase 2 pilot).
- ADRs: ADR-0048 D7/D14 (primary), ADR-0042 D1/D2/D3/D4/D6 (the contract being documented), ADR-0047 D11 (the contract-test gate), ADR-0048 D5 (the 30-day idempotency-store window).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0048 must be Accepted so the schema-on-read policy is a live rule.
- `packet:06` — the canonical `Migrations/README.md` template is the structural reference. If 06 hasn't merged, the executor reads ADR-0048 D7 and D11 directly.

**Constraints:**
- No EF migration; schema-on-read has no DDL.
- No `[Rollback]` attribute.
- Path is Kernel by default; operator may retarget to Data.
- 30-day window verbatim per ADR-0048 D5.
- Partition-key change triggers a deferred follow-up ADR; do not author it here.

**Key Files:**
- `src/HoneyDrunk.Kernel.Abstractions/Migrations/README.md` (new).
- `src/HoneyDrunk.Kernel.Abstractions/Migrations/Backfill/.gitkeep` (new, empty).
- Conditionally: `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, repo-level `CHANGELOG.md`.

**Contracts:** None changed.
