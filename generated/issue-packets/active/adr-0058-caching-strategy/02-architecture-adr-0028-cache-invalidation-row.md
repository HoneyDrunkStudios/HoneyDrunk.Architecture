---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0058", "adr-0028", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0058", "ADR-0028"]
wave: 2
initiative: adr-0058-caching-strategy
node: honeydrunk-architecture
---

# Add a Cache Invalidation row to ADR-0028's D2 use-case to backing matrix

## Summary
Per ADR-0058 D7's explicit follow-up: add a "Cache Invalidation" row to ADR-0028's D2 use-case → backing matrix enumerating the three named invalidation lanes (in-process direct invocation, Service Bus topic via Transport, Event Grid system topic). Mirror the row into `repos/HoneyDrunk.Transport/integration-points.md` per ADR-0028's existing reference-doc convention. Docs-only packet.

## Context
ADR-0058 D7 names three mutually-exclusive lanes for cache invalidation crossing a Node boundary:

1. **In-process direct invocation** — same-process writer and reader; invalidation is a direct call on `ICacheStore<T>.RemoveAsync` (or `RemoveByTagAsync`) at the write site.
2. **In-Grid domain events via Service Bus topic through Transport** — writer publishes a domain event over the default Service Bus topic per ADR-0028 D2; subscribers in other Nodes receive the event and invalidate their own caches. Carries an `IdempotencyKey` per ADR-0042 D1 so re-delivered invalidations dedup at the consumer.
3. **Infrastructure-emitted events via Event Grid system topic** — trigger is an Azure-managed resource event (secret rotated, blob written, configuration value changed) per ADR-0028 D6. The Vault rotation cache-invalidation flow is the canonical, already-live example.

ADR-0058 D7 explicitly states: "A follow-up update to ADR-0028 adds a 'Cache Invalidation' row to its use-case → backing matrix, calling out these three lanes explicitly. The update lands as a packet against the Architecture repo when this ADR flips to Accepted." This packet lands that update — it does not wait for the ADR-0058 status flip, because the three lanes are operational discipline that the next cross-Node cache adopter will need before the status flip lands.

ADR-0028 D2 also has an existing acceptance obligation (line 12 of that ADR): "Add the use-case → backing matrix (D2 below) to `repos/HoneyDrunk.Transport/integration-points.md` so the Transport repo is the authoritative reference for 'which backing for which use case'." This packet mirrors the new row into that file as well, consistent with the existing pattern.

This is a docs/governance packet. No code, no .NET project.

## Scope
- `adrs/ADR-0028-event-driven-architecture-and-messaging.md` — add a new row to the D2 use-case → backing matrix table (currently rows 1–8). The new row is "Cache Invalidation" with the three lanes enumerated.
- `repos/HoneyDrunk.Transport/integration-points.md` — mirror the new row if the existing matrix-mirror is in place; if the mirror is not in place yet (ADR-0028 acceptance obligation may still be open), add a brief note that the lanes apply and reference ADR-0058 D7 by name in the integration-points doc's heading metadata (the user's "no ADR numbers in docs" preference applies to in-body prose; metadata/heading refs in architecture-internal docs are acceptable — match the surrounding convention).

## Proposed Implementation
1. **`adrs/ADR-0028-event-driven-architecture-and-messaging.md`** — locate the D2 use-case → backing matrix table (the one starting with `| # | Use Case | Primary Backing | Ordering | Durability | Idle Cost | Why this backing |`). Add a new row 9 after row 8 (dead-letter handling):

   ```
   | 9 | Cache invalidation (cross-Node — a Node owning a cache must drop entries because the underlying data changed elsewhere; per ADR-0058 D7) | **Three named lanes, mutually exclusive per cache**: (a) **in-process direct invocation** when reader and writer co-locate (e.g. Communications preference-write + preference-cache invalidation share a process); (b) **Service Bus topic via Transport** for in-Grid cross-Node invalidations carrying an `IdempotencyKey` per ADR-0042 D1 (e.g. Notify Cloud publishes `TenantTierChanged`, Communications drops cached tenant-tier descriptors); (c) **Event Grid system topic** for Azure-emitted resource events (e.g. Vault's `Microsoft.KeyVault.SecretNewVersionCreated` invalidation flow per ADR-0006 Tier 3) | Per-lane: in-process is synchronous; Service Bus topic is per-subscription FIFO with sessions; Event Grid is best-effort at-least-once | Per-lane: in-process throws on failure (no durability); Service Bus per-subscription DLQ; Event Grid 24h retry then dead-letter to Storage | Per-lane: in-process is zero; Service Bus shares the namespace cost from row #2; Event Grid is pay-per-event at $0.60/M | The lane choice is per cache, by the owning Node. Each cache picks one as its primary lane; mixing lanes per cache is forbidden. The contract surface (`ICacheStore<T>.RemoveAsync` / `RemoveByTagAsync`) is uniform; the *trigger* mechanism varies. |
   ```

   Adjust the column count/exact prose to match the table's existing style — the surrounding rows give the canonical voice. Keep the row narratively dense per the surrounding pattern (the existing rows are descriptive, not terse).

2. Add a brief sentence below the table noting the new row's per-cache exclusivity, if the table already has trailing prose explaining the matrix as a whole. Check the file for the existing trailing sentence ("Use cases #5 (cron) and #7 (in-process) do not use Transport.") and extend it naturally:

   > Use case #9 (cache invalidation) uses one of three lanes per cache, chosen by the owning Node. The lanes are mutually exclusive per cache; a cache reacting to both in-Grid and Azure-resource triggers picks one as primary and implements the other as a same-process Lane-1 call internally.

3. **`repos/HoneyDrunk.Transport/integration-points.md`** — check the file's current state. If the D2 matrix is already mirrored there, append the new "Cache Invalidation" row in the same format. If the matrix is not yet mirrored (ADR-0028's acceptance obligation may still be open), do not silently land the full matrix here — instead add a brief paragraph at the end of the file noting the three cache-invalidation lanes per ADR-0058 D7, and flag in the PR description that ADR-0028's "mirror the D2 matrix" obligation is still open and should be picked up separately. **Do not bundle the full ADR-0028 matrix mirror into this packet** — that is ADR-0028's own acceptance work, not ADR-0058's.

## Affected Files
- `adrs/ADR-0028-event-driven-architecture-and-messaging.md` — new row in the D2 table; optional brief trailing sentence.
- `repos/HoneyDrunk.Transport/integration-points.md` — new row in the mirrored table if already present; otherwise brief paragraph + PR-description flag.

## NuGet Dependencies
None. Markdown-only packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No runtime impact; docs only.

## Acceptance Criteria
- [ ] ADR-0028's D2 use-case → backing matrix carries a new row 9 for "Cache Invalidation" enumerating the three lanes (in-process, Service Bus topic via Transport, Event Grid system topic)
- [ ] The new row carries per-lane ordering, durability, and idle-cost properties consistent with the surrounding rows' style
- [ ] The matrix's trailing prose acknowledges the new row's per-cache exclusivity if such trailing prose exists
- [ ] `repos/HoneyDrunk.Transport/integration-points.md` mirrors the row if the matrix-mirror is already present, OR carries a brief paragraph noting the three lanes if the mirror is not yet in place
- [ ] If the Transport `integration-points.md` matrix-mirror is not yet present, the PR description flags that ADR-0028's "mirror D2 to integration-points.md" obligation is still open and should be picked up separately
- [ ] No ADR status edit in this packet

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0058 D7 — Three named cache-invalidation lanes.** Invalidation crosses a Node boundary by exactly one of three named lanes per cache. Lane 1: in-process direct invocation. Lane 2: in-Grid domain events via Service Bus topic through Transport (carrying an `IdempotencyKey` per ADR-0042 D1). Lane 3: infrastructure-emitted events via Event Grid system topic. The lanes are mutually exclusive per cache, by design — a cache reacting to both an in-Grid event and an Azure event picks one as primary and implements the other as a same-process Lane-1 call internally.

**ADR-0058 D7 — Explicit follow-up.** "A follow-up update to ADR-0028 adds a 'Cache Invalidation' row to its use-case → backing matrix, calling out these three lanes explicitly. The update lands as a packet against the Architecture repo when this ADR flips to Accepted."

**ADR-0028 D2 — Use-case → backing matrix.** The matrix is the load-bearing table that names each Grid use case, its primary backing, ordering/durability properties, cost posture, and a one-sentence justification. Existing rows are 1–8. The new "Cache Invalidation" row is row 9.

**ADR-0028 D6 — Event Grid custom topics deferred.** Event Grid system topics are the canonical surface for Azure-emitted reactive events (secret rotated, blob written, image pushed). The Vault rotation cache-invalidation flow already relies on system topics — Lane 3 above is built on this existing mechanism.

**ADR-0042 D1 — `IdempotencyKey` on every async domain-event message.** Lane-2 cache-invalidation events ride the default Service Bus topic and carry the `IdempotencyKey` like any other async domain event; re-delivered invalidations dedup at the consumer's `IdempotentMessageHandler<T>` boundary.

## Constraints
- **The row is `Cache Invalidation`, not a new contract.** This packet does not create new types or interfaces; it documents the three lanes that the existing surfaces (`ICacheStore<T>.RemoveAsync` / `RemoveByTagAsync`, `ITransportPublisher`, Event Grid system topic webhooks) already support.
- **Do not bundle ADR-0028's own matrix-mirror obligation.** If `repos/HoneyDrunk.Transport/integration-points.md` does not yet carry the full D2 matrix, this packet does not land it — that is ADR-0028's acceptance work. Flag it in the PR description so it gets picked up separately.
- **Mutual exclusivity is documented, not enforced.** No code or canary in this packet checks that a cache picks exactly one lane; that discipline lands per-cache when each first real cache is wired (Communications preference, Notify Cloud API-key, etc.) in their own follow-up initiatives.
- **No ADR status edit.** ADR-0028 stays at whatever Status it currently carries (Proposed at the time of ADR-0058's authoring); this packet adds a row but does not flip Status. ADR-0058's Status flip is also out of scope here (separate housekeeping step).

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0058`, `adr-0028`, `wave-2`

## Agent Handoff

**Objective:** Add the "Cache Invalidation" row to ADR-0028's D2 use-case → backing matrix per ADR-0058 D7's explicit follow-up.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the three cache-invalidation lanes canonically documented in the use-case → backing matrix before the first real cross-Node cache adopter (Communications preference / Notify Cloud API-key) needs to choose a lane.
- Feature: ADR-0058 Grid-Wide Caching Strategy rollout, Wave 2.
- ADRs: ADR-0058 D7 (primary), ADR-0028 D2/D6 (the table being updated), ADR-0042 D1 (the `IdempotencyKey` Lane 2 carries), ADR-0006 (Lane 3's existing Vault flow).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — initiative registered so this packet has a known initiative anchor.

**Constraints:**
- Match the existing table row style — descriptive, narratively dense, one-sentence justification.
- Do not bundle ADR-0028's own matrix-mirror obligation if the Transport `integration-points.md` mirror is not yet in place; flag it in the PR description instead.
- No code, no contract change — docs only.

**Key Files:**
- `adrs/ADR-0028-event-driven-architecture-and-messaging.md` — D2 matrix new row.
- `repos/HoneyDrunk.Transport/integration-points.md` — mirror the row if already in place, else brief paragraph.

**Contracts:** None changed.
