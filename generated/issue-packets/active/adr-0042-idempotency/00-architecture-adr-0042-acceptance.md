---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0042", "wave-1"]
dependencies: []
adrs: ["ADR-0042"]
accepts: ["ADR-0042"]
wave: 1
initiative: adr-0042-idempotency
node: honeydrunk-architecture
---

# Accept ADR-0042 — flip status, add the three idempotency invariants, register the initiative

## Summary
Flip ADR-0042 (Idempotency Contract for Async Boundaries) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new idempotency invariants ADR-0042 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0042-idempotency` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0042 decides the Grid's response to Azure Service Bus's at-least-once delivery semantics: a Grid-wide idempotency contract for every async domain-event boundary. It decides the idempotency key shape, where dedup state lives, the dedup-state retention window, the producer/consumer responsibilities, and the canary that enforces the contract. It was authored 2026-05-21 in a batch of cross-cutting Grid-gap ADRs and has had no scope until now.

The ADR decides:
- **D1** — every async domain-event message carries a mandatory string `IdempotencyKey` in its user-properties, generated once at message origination and never regenerated on retry. The key is exposed via `IGridMessageEnvelope.IdempotencyKey` in `HoneyDrunk.Kernel.Abstractions`.
- **D2** — dedup state lives at the consumer, scoped per consumer-group, durable at Tier 1. The interface is `IIdempotencyStore` in `HoneyDrunk.Kernel.Abstractions`; default backing is a small Cosmos container.
- **D3** — every consumer follows claim → process → complete, encoded once in a shared `IdempotentMessageHandler<T>` base. Downstream message keys are deterministically derived from the inbound key (`SHA256(inbound:relationship)`).
- **D4** — dedup-state TTL: 7 days standard, 30 days for billing and audit consumer-groups.
- **D5** — producers generate and attach the key at the message-construction site, never at the broker-publish site; the Kernel ships an `IGridMessagePublisher` helper.
- **D6** — request/reply: the reply message's key is derived from the request's key (`SHA256(request:reply)`).
- **D7** — Pulse signals and telemetry signals are non-domain-event carve-outs, exempt from the mandatory-key rule; Pulse signals use a separate `IPulseSignalEnvelope` type.
- **D8** — in-process events are exempt, but a bridge from in-process to async must attach a key at the bridge point.
- **D9** — a canary in `HoneyDrunk.Kernel.Tests.Canaries` publishes a message twice with the same key and asserts the side effect happened exactly once, the dedup-store recorded the key, and a post-TTL replay re-executes.
- **D10** — backward compatibility: existing async producers (Notify, Communications) are amended to emit the key in a rollout; during the rollout consumers tolerate keyless messages; the canary's mandatory-attribute check flips on after the rollout closes.

ADR-0042 is a **policy / contract** ADR. The concrete code — the Kernel envelope/store/handler/publisher additions, the Cosmos backing, the canary, the producer rollout — lands in `HoneyDrunk.Kernel`, `HoneyDrunk.Data`, `HoneyDrunk.Notify`, and `HoneyDrunk.Communications` in this initiative. Catalog and contract registration land as Architecture packets. Every other packet references ADR-0042's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0042-idempotency-contract-for-async-boundaries.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0042 row Status column to Accepted.
- `constitution/invariants.md` — add the three new idempotency invariants (see Proposed Implementation for exact text), numbered **75, 76, 77** (pre-reserved for ADR-0042; see Constraints).
- `initiatives/active-initiatives.md` — register the `adr-0042-idempotency` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0042 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0042 index row in `adrs/README.md` to Accepted.
3. Add three new invariants to `constitution/invariants.md`, numbered **75, 76, 77** (see Constraints). The text, taken verbatim-in-substance from ADR-0042's Consequences "Invariants" section:
   - **75 — Every async domain-event message carries an `IdempotencyKey`.** Every message published on the default Service Bus topic or queue carries a string `IdempotencyKey` in its user-properties, produced once at message origination and reused unchanged on every retry and redelivery. Messages without a key are rejected at the consumer (canary-enforced once the ADR-0042 producer rollout closes). Pulse signals and telemetry signals are explicit carve-outs — they ride a separate envelope type and are not bound by this rule. See ADR-0042 D1, D7.
   - **76 — Dedup state lives per consumer-group, with a TTL.** Each consumer maintains its own `IdempotencyKey → (FirstSeenAt, Outcome)` store, separate per consumer-group, durable at Tier 1. Service Bus broker-side dedup is not a substitute — it is message-id-scoped, not domain-key-scoped, and does not extend to downstream messages. Standard TTL is 7 days; billing and audit consumer-groups use 30 days. See ADR-0042 D2, D4.
   - **77 — Downstream message keys are deterministically derived from the originating key.** When a consumer's processing emits a downstream message, that message's `IdempotencyKey` is `SHA256(inbound:relationship)` of the inbound key — never a fresh key. Idempotency is end-to-end across a message chain, not per-hop. See ADR-0042 D3, D6.
   - Create a new `## Idempotency Invariants` section (the file's existing sectioning convention groups invariants by topic — Dependency, Context, Secrets, Packaging, Testing, AI, Audit, etc.; idempotency is a new cross-cutting topic and warrants its own section). Place it after the `## Audit Invariants` section.
4. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0042-idempotency-contract-for-async-boundaries.md`
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
- [ ] ADR-0042 header reads `**Status:** Accepted`
- [ ] The ADR-0042 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the three new idempotency invariants (every async domain-event message carries an `IdempotencyKey`; dedup state lives per consumer-group with a TTL; downstream message keys are deterministically derived from the originating key), numbered **75, 76, 77** under a new `## Idempotency Invariants` section, each citing ADR-0042
- [ ] `initiatives/active-initiatives.md` registers the `adr-0042-idempotency` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0042 D1 — Mandatory `IdempotencyKey`.** Every async domain-event message carries a string `IdempotencyKey` in user-properties; produced once at origination, never regenerated on retry; opaque to the broker (separate from Service Bus's own `MessageId`); UUID v4 by default, deterministic keys allowed.

**ADR-0042 D2 — Consumer-side dedup state, per consumer-group.** Each consumer maintains a `IdempotencyKey → (FirstSeenAt, Outcome)` store; separate per consumer-group; durable at Tier 1; default Cosmos backing.

**ADR-0042 Consequences — Invariants.** ADR-0042 adds exactly three invariants: (1) every async domain-event message carries an `IdempotencyKey`, with Pulse/telemetry carve-outs; (2) dedup state lives per consumer-group with a TTL; (3) downstream message keys are deterministically derived from the originating key.

## Constraints
- **Acceptance precedes flip.** ADR-0042 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers are pre-reserved.** The current verified maximum in `constitution/invariants.md` is **51**. Invariant numbers **75, 76, 77** are pre-reserved for ADR-0042 as part of a 12-ADR batch — use those hard numbers. Do not renumber existing invariants. If any invariant above 51 lands from outside this batch before this PR merges, shift this block upward (e.g. 78, 79, 80), never reuse a number that has already been claimed.
- **New section.** The three idempotency invariants are a new cross-cutting topic; create a `## Idempotency Invariants` section after `## Audit Invariants` rather than appending to an unrelated section.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0042`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0042 to Accepted, add the three idempotency invariants to `constitution/invariants.md`, and register the idempotency-contract initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0042 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0042 Idempotency Contract for Async Boundaries rollout, Wave 1.
- ADRs: ADR-0042 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0042 stays Proposed until this PR merges.
- Add the three new invariants as numbers **75, 76, 77** (pre-reserved for ADR-0042) under a new `## Idempotency Invariants` section; do not renumber existing invariants. Current verified max is 51. If any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a claimed number.

**Key Files:**
- `adrs/ADR-0042-idempotency-contract-for-async-boundaries.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
