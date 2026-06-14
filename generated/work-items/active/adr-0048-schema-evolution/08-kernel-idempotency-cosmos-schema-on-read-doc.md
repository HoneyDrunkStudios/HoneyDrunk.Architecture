---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-3", "kernel", "docs", "schema-on-read", "adr-0048", "wave-4"]
dependencies: ["work-item:00", "work-item:06"]
adrs: ["ADR-0048", "ADR-0042"]
wave: 4
initiative: adr-0048-schema-evolution
node: honeydrunk-kernel
---

# Document the idempotency-store schema-on-read shape

## Summary
Document the canonical document shape for the Cosmos-backed `IIdempotencyStore` dedup state. This is a schema-on-read documentation packet: no DDL, no DACPAC, no EF migration, and no runtime code change.

## Context
ADR-0048 D7 says document stores follow schema-on-read. The idempotency store contract lives in Kernel, while the Cosmos implementation may live in a backing package. The contract-owned shape should be documented next to the Kernel abstraction so all backing implementations preserve the same semantics.

## Scope
- Add `src/HoneyDrunk.Kernel.Abstractions/Schema/README.md`.
- Add `src/HoneyDrunk.Kernel.Abstractions/Schema/Backfill/.gitkeep` so future backfill runbooks have a home.
- No `.csproj` changes unless the repo convention requires docs to be included explicitly.
- No code changes.

## README Content
The README should document:

- Purpose: canonical dedup-state document shape for `IIdempotencyStore`.
- Fields:
  - `id`
  - `consumerGroup` partition key
  - `firstSeenAt`
  - state/lease metadata
  - optional outcome metadata
  - TTL policy
- Schema-on-read rules:
  - new fields are added by writing them
  - readers tolerate missing fields
  - field removal waits until all readers are off the field and the ADR-0048 window has elapsed
- Backfills:
  - recorded under `Schema/Backfill/<YYYYMMDD>-<description>.md`
  - operator-triggered against staging first, then production
- Partition-key changes:
  - not possible in place
  - require a follow-up ADR and a new-container/dual-write/backfill/cutover plan
- Tests:
  - existing idempotency-store contract tests remain the primary behavioral guard
  - future backfills carry targeted integration tests

## Acceptance Criteria
- [ ] `src/HoneyDrunk.Kernel.Abstractions/Schema/README.md` exists
- [ ] README documents the canonical idempotency-store document shape and TTL policy
- [ ] README states that schema-on-read has no DDL, no DACPAC, and no EF migration
- [ ] README defines the `Schema/Backfill/` runbook location
- [ ] `.gitkeep` exists in `Schema/Backfill/`
- [ ] No runtime code or public contract surface changes are introduced

## Referenced ADR Decisions
**ADR-0048 D7** — document stores follow schema-on-read and backfills are runbooked operator jobs.

**ADR-0042** — defines the idempotency contract, consumer-group partitioning, and retention expectations.
