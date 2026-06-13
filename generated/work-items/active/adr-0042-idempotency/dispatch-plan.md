# Dispatch Plan — ADR-0042: Idempotency Contract for Async Boundaries

**Initiative:** `adr-0042-idempotency`
**ADR:** ADR-0042 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-22

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0042 decides the Grid's response to Azure Service Bus's at-least-once delivery (ADR-0028's default broker): a **Grid-wide idempotency contract** for every async domain-event boundary. The contract has five moving parts — a mandatory `IdempotencyKey` on every async domain-event message, a consumer-side per-consumer-group dedup store, a shared claim/process/complete consumer base, a retry-safe publisher, and a canary that enforces it.

This initiative delivers: ADR acceptance + the three new idempotency invariants + catalog registration (Architecture); the contract surface in `HoneyDrunk.Kernel.Abstractions` and the runtime base handler + publisher in `HoneyDrunk.Kernel`; the default Cosmos-backed `IIdempotencyStore` plus an InMemory test store in `HoneyDrunk.Data`; the producer/consumer rollout to the two existing async producers (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`); and the D9 canary that flips the mandatory-key check to strict once the rollout closes.

**8 packets across 5 waves**, targeting **5 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.Data`, `HoneyDrunk.Notify`, `HoneyDrunk.Communications`). All 8 are `Actor=Agent`, 0 `Actor=Human`. Three packets (03, 05, 06) carry Human Prerequisites — Cosmos account provisioning per environment, connection-secret seeding into Key Vault, Managed Identity RBAC, and (05/06) the human git-tag/release of the upstream Kernel and Data NuGet packages — but the *code* work is fully delegable (tests run against the InMemory store), so they stay `Actor=Agent`.

## Trigger

ADR-0042 is Proposed with no scope. The forcing functions from the ADR's Context: **ADR-0037 (Payment)** requires end-to-end idempotency into Stripe Meter Events and cites this ADR as a prerequisite; **ADR-0036 (DR)** depends on this ADR for the "T2 message loss on Service Bus forced failover is recoverable via consumer idempotency" claim; the **AI-sector standup wave** introduces tool-call dispatch where reissuing an agent step on retry must not double-execute side-effecting tools; **ADR-0030 Audit** double-emits on retry produce double-audit entries. Every consumer of the default broker has to solve duplicate-handling the same way — the absence of a Grid-level contract guarantees per-Node drift. The ADR needs decomposition into actionable packets.

## Scope Detection

**Multi-repo, multi-Node.** The contract lands in `HoneyDrunk.Kernel.Abstractions` (the zero-dependency contract layer every Node already consumes — same precedent as `IGridContext` and `TenantId`), the runtime base in `HoneyDrunk.Kernel`, the default backing in `HoneyDrunk.Data`, and the rollout fans out to the two existing async producers `HoneyDrunk.Notify` and `HoneyDrunk.Communications`. `HoneyDrunk.Architecture` carries the governance (acceptance, three invariants) and catalog packets.

**Contract is additive — no forced downstream cascade.** The new contracts (`IGridMessageEnvelope`, `IIdempotencyStore`, `IdempotentMessageHandler<T>`, `IGridMessagePublisher`, `IPulseSignalEnvelope`, and the records) are *additive* to `HoneyDrunk.Kernel.Abstractions`. Per ADR-0042's own Operational Consequences and ADR-0035, this is an additive minor bump (`HoneyDrunk.Kernel` `0.7.0` → `0.8.0`), not a breaking change. Downstream Nodes that consume `HoneyDrunk.Kernel.Abstractions` are not *forced* to update — they adopt the contract when their own async boundaries are amended. This initiative amends only the **two existing async producers** the ADR D10 names (Notify, Communications). Audit, Billing, and the AI-sector async handlers are deliberately **out of scope** (see Cross-Cutting Concerns).

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node. No empty cataloged repo is touched; no standup ADR is needed.

## Cross-Dependency with ADR-0028

ADR-0028 (Event-Driven Architecture and Messaging) is **Proposed**, not Accepted — and ADR-0042 builds directly on it. The relationship:

- ADR-0042 D1's "default Service Bus topic / queue" **is** ADR-0028 D5's `sbns-hd-shared-{env}` shared Service Bus namespace and D2's use-case matrix rows 1–2. ADR-0042's mandatory-key rule binds the messages that ride those backings.
- ADR-0042 D7's "Pulse signals are not domain events" carve-out **restates** ADR-0028 D3's signals-vs-events disambiguation, and `IPulseSignalEnvelope` is the type-level enforcement of it.
- ADR-0042 D8's in-process exemption **aligns with** ADR-0028 D7's in-process MediatR-style use case #7 — and packet 06's Communications scoping turns directly on ADR-0028 D4 (Communications → Notify is in-process at v1).

**This is a soft dependency, not a hard blocker.** ADR-0042 can be scoped, accepted, and implemented while ADR-0028 is still Proposed, because:
1. The `IdempotencyKey` contract and the dedup store are **backing-agnostic** — they ride the message body/user-properties regardless of whether the broker is Service Bus, Storage Queue, or the InMemory test provider. ADR-0028 picks backings; ADR-0042 makes the messages on those backings idempotent. They are orthogonal layers.
2. The Kernel/Data implementation (packets 02–04) has no Service Bus dependency at all — `IGridMessagePublisher` takes the broker send as an injected seam.
3. The producer rollout (packets 05, 06) audits each Node's *actual* async hops as they exist today; it does not require ADR-0028's namespace to be provisioned.

**Flagged for the operator:** ADR-0042 cites ADR-0028 as live context but ADR-0028 is still Proposed. ADR-0042's acceptance does not depend on ADR-0028's acceptance — but the two ADRs reference each other and should be kept consistent. If ADR-0028 is accepted later and its decisions shift (e.g. a different default broker), ADR-0042's "default Service Bus" framing would need a consistency pass. No packet here blocks on ADR-0028; this is a documentation-coherence note, not a sequencing constraint.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0042, add the three idempotency invariants (numbers **75, 76, 77**), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the idempotency contract surface in the Grid catalogs. `Actor=Agent`. Blocked by: 00.

> **Invariant numbering.** The current verified maximum in `constitution/invariants.md` is **51**. Invariant numbers **75, 76, 77** are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before packet 00 merges, shift this block upward, never reuse a number.

### Wave 2 (Depends on Wave 1 — the contract foundation)
- [ ] **02** — Kernel: add `IGridMessageEnvelope`, `IIdempotencyStore`, `IPulseSignalEnvelope`, and the idempotency records to `HoneyDrunk.Kernel.Abstractions`. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Kernel` (`0.7.0` → `0.8.0`).**

### Wave 3 (Depends on Wave 2 — backing + runtime, parallel)
- [ ] **03** — Data: implement the default Cosmos-backed `IIdempotencyStore` + an InMemory test store. `Actor=Agent`. Blocked by: 02. **Version-bumping packet for `HoneyDrunk.Data`.**
- [ ] **04** — Kernel: add `IdempotentMessageHandler<T>` and `IGridMessagePublisher` to the `HoneyDrunk.Kernel` runtime. `Actor=Agent`. Blocked by: 02.

### Wave 4 (Depends on Wave 3 — producer rollout, parallel)
- [ ] **05** — Notify: roll out the idempotency envelope to Notify async producers/consumers. `Actor=Agent`. Blocked by: 04.
- [ ] **06** — Communications: roll out the idempotency envelope to Communications async boundaries. `Actor=Agent`. Blocked by: 04.

### Wave 5 (Depends on Wave 4 — canary + strict enforcement)
- [ ] **07** — Kernel: add the ADR-0042 D9 canary and flip the mandatory-key check to strict. `Actor=Agent`. Blocked by: 04, 05, 06.

Packets within a wave run in parallel. **Wave-3 packets 03 and 04 are independent** — 03 implements a backing in `HoneyDrunk.Data`; 04 implements the runtime base in `HoneyDrunk.Kernel` — different repos, no shared solution. **Wave-4 packets 05 and 06 are independent** — different repos. Packet 04 shares the `HoneyDrunk.Kernel` solution with packet 02 and packet 07: 02 is the version-bumping packet (`0.8.0`); 04 and 07 append to the in-progress `[0.8.0]` CHANGELOG (invariant 27). Land 02 first, then rebase 04/07 onto its merge so the `0.8.0` line is consistent. Packet 07 is alone in Wave 5 because it flips strict enforcement on and must land only after both producer rollouts (05, 06) have closed — see the Cross-Cutting note on rollout sequencing.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0042](./00-architecture-adr-0042-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Idempotency contract catalog](./01-architecture-idempotency-contract-catalog.md) | Architecture | Agent | 1 | 00 |
| 02 | [Kernel idempotency contracts + envelope](./02-kernel-idempotency-contracts-and-envelope.md) | Kernel | Agent | 2 | 00 |
| 03 | [Cosmos `IIdempotencyStore` backing](./03-data-cosmos-idempotency-store-backing.md) | Data | Agent | 3 | 02 |
| 04 | [`IdempotentMessageHandler<T>` + publisher](./04-kernel-message-handler-base-and-publisher.md) | Kernel | Agent | 3 | 02 |
| 05 | [Notify idempotency rollout](./05-notify-idempotency-envelope-rollout.md) | Notify | Agent | 4 | 04 |
| 06 | [Communications idempotency rollout](./06-communications-idempotency-envelope-rollout.md) | Communications | Agent | 4 | 04 |
| 07 | [Idempotency canary + strict enforcement](./07-kernel-idempotency-canary-and-strict-enforcement.md) | Kernel | Agent | 5 | 04, 05, 06 |

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 02 is the first packet on the solution; it bumps every non-test `.csproj` to the same new **minor** version `0.7.0` → `0.8.0` (new feature: the idempotency contract surface; additive, no break). Packets 04 and 07 append to the in-progress `[0.8.0]` CHANGELOG only (invariant 27). Per-package CHANGELOGs: `HoneyDrunk.Kernel.Abstractions` gets an entry from packet 02; `HoneyDrunk.Kernel` gets an entry from packet 04 (runtime types) and 07 (canary + strict-enforcement behaviour change).
- **`HoneyDrunk.Data`** — packet 03 bumps the whole solution one minor version (new provider packages). Confirm the current version at execution time (the v0.4 tracker shows Data at `0.3.0`; it may have moved since).
- **`HoneyDrunk.Notify`** — packet 05 bumps the whole solution one minor version (Notify v0.2.0 per the launch tracker — confirm current at execution time).
- **`HoneyDrunk.Communications`** — packet 06 bumps the whole solution one minor version. Confirm current version at execution time.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog edits only.

## Cross-Cutting Concerns

### Cosmos package placement — pinned

ADR-0042 D2's prose floats the name `HoneyDrunk.Kernel.Idempotency.Cosmos` but in the same sentence says the implementation "lives in `HoneyDrunk.Data`." A `HoneyDrunk.Kernel.*`-named package shipped from the `HoneyDrunk.Data` repo crosses the one-repo-per-Node naming convention (invariant 11). This is **decided, not deferred**: the packages are `HoneyDrunk.Data.Idempotency.Cosmos` and `HoneyDrunk.Data.Idempotency.InMemory` — a new provider package family in the `HoneyDrunk.Data` repo, consistent with the existing `HoneyDrunk.Data.*` provider naming and the one-repo-per-Node convention. The contract (`IIdempotencyStore`) stays in `HoneyDrunk.Kernel.Abstractions`; only the *backing* lives in Data. Packet 03 ships these names and registers both packages under `honeydrunk-data` in the catalogs. There is no operator decision pending and no A/B choice for the executor.

### Audit, Billing, and the AI-sector are out of scope — deliberate deferral

ADR-0042's Affected Nodes list names `HoneyDrunk.Audit`, `HoneyDrunk.Billing`, and `HoneyDrunk.AI / Agents / Flow` as consumers of the contract. This initiative does **not** wire them, by design:

- **`HoneyDrunk.Audit`** — ADR-0042 says Audit "at standup wires `IdempotentMessageHandler<AuditEmit>`; TTL = 30 days" and that "Audit's standup canary (per ADR-0031) wires the same shape." ADR-0031's Audit standup is its **own initiative** — and per the memory note "New-Node / standup work gets its own ADR; don't bundle into feature packets." The Audit→idempotency wiring belongs in the ADR-0031 standup track (or an Audit follow-up), consuming the `HoneyDrunk.Kernel` `0.8.0` contract this initiative ships. ADR-0047 parks an `IIdempotencyStore` Cosmos contract-test (its packet 12) "until ADR-0042 is Accepted and the Cosmos backing exists." Packet 03 here makes that contract-test target **buildable** by shipping the `HoneyDrunk.Data.Idempotency.Cosmos` package — so the unpark trigger for ADR-0047 packet 12 is "**ADR-0042 Accepted (packet 00) + the Cosmos backing package exists (packet 03 merged)**," not "the contract test is written." Writing the test is ADR-0047 packet 12's own job.
- **`HoneyDrunk.Billing`** — a future Node (ADR-0037). ADR-0037 explicitly cites ADR-0042 as a prerequisite. The Billing pipe's 30-day-TTL idempotency wiring is ADR-0037's scope, built on top of what this initiative ships.
- **`HoneyDrunk.AI / Agents / Flow`** — the tool-dispatch / agent-step idempotency wiring is part of those Nodes' own async-handler work, adopting the `IdempotentMessageHandler<T>` base this initiative ships. Not in scope here.

This initiative ships the **contract, the backing, the runtime base, and conforms the two async producers that exist today** (Notify, Communications). Every other consumer adopts the shipped contract in its own track. This keeps the initiative bounded and consistent with the Grid's standup-gets-its-own-ADR rule.

### Human package release at wave boundaries — agents never tag

Wave 4 (packets 05, 06) compiles against `HoneyDrunk.Kernel` / `HoneyDrunk.Kernel.Abstractions` `0.8.0` (packets 02 + 04) and `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory` (packet 03). Those NuGet artifacts exist on the package feed **only after a human pushes a git release tag** in each repo — agents merge code but never tag or publish. Two human release steps gate this initiative:

- **Wave 2→3 boundary** — after packets 02 and 04 have both merged, a human tags/releases `HoneyDrunk.Kernel` `0.8.0` (the tag carries `HoneyDrunk.Kernel.Abstractions` `0.8.0` from packet 02 and the runtime types from packet 04). Note: packet 03 also consumes `HoneyDrunk.Kernel.Abstractions` `0.8.0` — so in practice the Abstractions package must be published before packet 03 builds; release Kernel once packet 02 has merged, then again (or as a single `0.8.0` release after 04) so the runtime package is on the feed before Wave 4.
- **Wave 3→4 boundary** — after packet 03 merges, a human tags/releases the `HoneyDrunk.Data` solution version that ships `HoneyDrunk.Data.Idempotency.Cosmos` / `.InMemory`.

Wave 4 cannot build against unpublished packages. This is surfaced in packets 05 and 06's Human Prerequisites and in the Wave-2 and Wave-4 handoffs.

### Rollout sequencing — strict enforcement lands last

ADR-0042 D10's transitional accommodation: consumers tolerate keyless messages during the producer rollout; the canary's mandatory-key check flips on "after the rollout completes." Packet 04 ships `IdempotentMessageHandler<T>` with keyless-tolerant behaviour; packets 05 and 06 amend the producers to emit keys; packet 07 (Wave 5, hard-blocked behind 05 and 06) flips the check to strict. **Filing is not deploying** — packet 07's strict flip should reach *production* only after the Notify and Communications producer rollouts are deployed in every environment. Packet 07 gates the flip behind a config switch if any rollout is mid-deploy. This is a deploy-sequencing judgment surfaced in packet 07's Human Prerequisites.

### The two-envelope question — `IGridMessageEnvelope` vs `ITransportEnvelope` — noted, not resolved

`HoneyDrunk.Transport` already ships `ITransportEnvelope` (the immutable transport wire wrapper). ADR-0042 D1 places `IGridMessageEnvelope` (the domain-event envelope carrying the `IdempotencyKey`) in `HoneyDrunk.Kernel.Abstractions`. These are two envelopes at two layers — Kernel-level domain envelope vs Transport-level wire wrapper. ADR-0042 is the authority and packet 02 builds `IGridMessageEnvelope` in Kernel as the ADR states, without touching `ITransportEnvelope` and without inverting the Kernel↔Transport dependency direction (Transport depends on Kernel, never the reverse — invariant 4). **Flagged for the operator:** if the relationship between the two envelopes warrants reconciliation (e.g. `ITransportEnvelope` composing or wrapping `IGridMessageEnvelope`), that is a Transport follow-up, not in this initiative's scope. ADR-0042 did not decide it; this initiative does not either.

### Deferred follow-ups (explicitly out of scope)

- **Pulse's adoption of `IPulseSignalEnvelope`.** Packet 02 ships `IPulseSignalEnvelope` in `HoneyDrunk.Kernel.Abstractions` as the type-level carve-out (ADR-0042 D7). No packet in this initiative wires `HoneyDrunk.Pulse` to actually adopt the new envelope type for its signals — that is a deferred Pulse follow-up. Until Pulse adopts it, ADR-0042 D7's "the carve-out is enforced at the type level" is delivered at the *contract* level (the type exists and is distinct) but not yet *enforced in Pulse itself*. Do not read D7 as fully delivered by this initiative.
- Audit Node's `IdempotentMessageHandler<AuditEmit>` wiring + 30-day TTL — ADR-0031 standup track.
- Billing pipe's end-to-end idempotency into Stripe — ADR-0037.
- AI-sector tool-dispatch / agent-step idempotency — those Nodes' own async-handler work.
- Redis-class or Postgres `IIdempotencyStore` backings — ADR-0042 D2 says they are "acceptable" and "pluggable"; only the Cosmos default + InMemory test store ship here. A future backing is a small follow-up packet against the contract.
- `ITransportEnvelope` ↔ `IGridMessageEnvelope` reconciliation — a Transport follow-up if warranted.
- ADR-0028 consistency pass — if ADR-0028 is accepted with changed decisions, ADR-0042's "default Service Bus" framing gets a documentation-coherence review.

### Site sync

No site-sync flag. ADR-0042 is internal Core-sector infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the three invariants and the catalog entries are removed. No runtime impact.
- **Packet 02 (Kernel contracts):** revert the PR; the `HoneyDrunk.Kernel` solution rolls back `0.8.0` → `0.7.0`. The contracts are additive — no consuming Node depends on them at runtime until it composes them, so the revert is contained to `HoneyDrunk.Kernel`.
- **Packet 03 (Cosmos backing):** revert the PR; the new `HoneyDrunk.Data.Idempotency.*` packages leave the solution; the version rolls back. No runtime consumer is affected until a host composes the store.
- **Packet 04 (runtime base + publisher):** revert the PR; `IdempotentMessageHandler<T>` and `IGridMessagePublisher` leave the `HoneyDrunk.Kernel` runtime. Additive — the revert is contained to `HoneyDrunk.Kernel`.
- **Packet 05 (Notify rollout):** revert the PR; Notify's producers stop attaching keys and its consumers return to their pre-rollout handlers. Notify's pre-existing provider-side dedup (ESP `Message-ID` rejection, per the ADR Context) still tolerates duplicates — no regression below today's behaviour. The Notify solution version rolls back.
- **Packet 06 (Communications rollout):** revert the PR; Communications returns to its pre-rollout async handling. Per ADR-0028 D4 the Communications→Notify hop is in-process and was never given the contract, so the revert's blast radius is small. The Communications solution version rolls back.
- **Packet 07 (canary + strict enforcement):** revert the PR; the canary leaves `HoneyDrunk.Kernel.Tests.Canaries` and `IdempotentMessageHandler<T>` returns to keyless-tolerant behaviour (the D10 transitional path). The third ADR-0042 invariant (the canary-enforced mandatory key) is then unmet until re-applied — note this in the revert.
- **Operational escape hatch:** if strict enforcement (packet 07) poison-letters a producer that is still mid-rollout, flip the config switch back to keyless-tolerant rather than reverting — a one-config-value change, no redeploy of code.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
