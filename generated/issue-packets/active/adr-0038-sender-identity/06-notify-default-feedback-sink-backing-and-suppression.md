---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0038", "wave-3"]
dependencies: ["packet:05"]
adrs: ["ADR-0038"]
accepts: ["ADR-0038"]
wave: 3
initiative: adr-0038-sender-identity
node: honeydrunk-notify
---

# Implement the default IDeliverabilityFeedbackSink backing — deliverability-feedback persistence and per-tenant suppression

## Summary
Implement the default `IDeliverabilityFeedbackSink` backing in the `HoneyDrunk.Notify` runtime per ADR-0038 D6: persist normalized `DeliverabilityEvent` records to the Notify durable store and apply suppression — hard bounces and complaints suppress the recipient **per-tenant**, with a platform-wide override list for known abuse traps. The contract itself landed in packet 05.

## Context
ADR-0038 D6 makes bounce/complaint/unsubscribe handling a Notify primitive. This packet builds the runtime backing for the `IDeliverabilityFeedbackSink` contract added in packet 05. It is two concerns: **deliverability-feedback persistence** and **per-tenant suppression**.

**Per-tenant suppression** is the load-bearing multi-tenant rule. A bounce or complaint recorded against `(TenantId, RecipientAddress)` suppresses future sends only for that tenant — another tenant sending to the same recipient address is unaffected. This aligns with the Grid's multi-tenant boundary posture (invariant 39: tenant mechanics at intake/post-dispatch boundaries; `TenantId.Internal` is the default for internal Grid callers). The **platform-wide override list** is the one exception — known abuse-trap and honeypot addresses are suppressed across all tenants regardless.

The suppression key is the recipient **address string** — the `Address` value of the `Recipient` record, the same field `DeliverabilityEvent.RecipientAddress` carries (packet 05). There is no `PrincipalId` type in Notify.Abstractions or Kernel.Abstractions; do not invent one.

The durable store is **Tier 1** per ADR-0036 — suppression and deliverability state survive a recovery with RPO ≤ 1 hr. The Notify T1 `dr-runbook.md` (ADR-0036 packet 08) already documents Notify's durable backing; this packet's suppression store is a member of that T1 state.

> **Deferred — no message-bus broadcast in this packet.** ADR-0038 D6's prose describes the eventual default sink also emitting a domain event onto a message bus so Communications can subscribe. That is **not** in scope here: the `HoneyDrunk.Notify` runtime csproj references only `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Standards`, and `Microsoft.Extensions.*` — it has **no** transport or Service Bus dependency, and adding one is out of scope for a feedback-persistence packet. Broadcasting deliverability events onto a message bus waits until Notify takes a transport dependency; cross-reference ADR-0042's idempotency/transport work, which is the natural home for that dependency. This packet persists feedback and maintains the suppression list; Communications, until the bus path exists, reads suppression state through whatever query surface this packet exposes, not through a bus subscription.

## Scope
- `HoneyDrunk.Notify` runtime — the default `IDeliverabilityFeedbackSink` implementation, the suppression store and its query path, and the platform-wide override list.
- The Notify durable storage area (`HoneyDrunk.Notify/Storage/`) — the deliverability-event and suppression persistence.

## Proposed Implementation
1. **Default sink implementation** — a class implementing `IDeliverabilityFeedbackSink.ReceiveAsync`. On each `DeliverabilityEvent`:
   - Persist the event to the Notify durable store (append — deliverability outcomes accrue over time).
   - If `Outcome` is `HardBounced` or `Complained`, record a suppression entry keyed by `(TenantId, RecipientAddress)`.
2. **Suppression store** — persistence for `(TenantId, RecipientAddress) → suppressed` plus the reason (hard-bounce vs complaint vs unsubscribe). A query method the Notify send path consults before dispatch: "is `(TenantId, RecipientAddress)` suppressed?" Per-tenant — a lookup for tenant A must not return tenant B's suppressions. The key is the recipient address string (`Recipient.Address`); there is no `PrincipalId` type.
3. **Platform-wide override list** — a separate suppression set not keyed by tenant; any recipient address on it is suppressed for every tenant. Seed it empty (or with a documented initial honeypot set if one is known); the list is operator-maintainable. The send-path suppression check is: suppressed if `(TenantId, RecipientAddress)` is suppressed **or** the address is on the platform-wide override list.
4. **Wire the suppression check into the send path** — Notify's dispatch path consults the suppression store before sending. A suppressed `(TenantId, RecipientAddress)` send is short-circuited with a deliverability outcome reflecting suppression, not silently dropped.
5. **Unsubscribe as suppression** — D6 says unsubscribes are part of suppression. An `Unsubscribed` outcome records a suppression entry the same way a hard bounce does. (The List-Unsubscribe *header* that produces unsubscribe events is packet 07.)
6. **DI registration** — register the default sink, suppression store, and override list in Notify's `DependencyInjection`. The sink is the default `IDeliverabilityFeedbackSink` binding; a host can override it.
7. **Tests** — unit tests in `HoneyDrunk.Notify.Tests` for the suppression logic (per-tenant isolation: tenant A's bounce does not suppress tenant B; platform-wide override suppresses all); a test that hard-bounce and complaint outcomes suppress but `Deferred`/`SoftBounced` do not; an integration test in `HoneyDrunk.Notify.IntegrationTests` covering the round-trip from `ReceiveAsync` → durable store → suppression query, per ADR-0038's Follow-up Work ("the round-trip from send to suppression" is covered). Per invariant 51, no `Thread.Sleep` in test code.
8. **Version + CHANGELOG.** Packet 05 already bumped the solution version for this initiative. Per invariant 27, this packet appends to the existing in-progress version's `CHANGELOG.md` entry — repo-level and the `HoneyDrunk.Notify` runtime package's per-package `CHANGELOG.md` (the runtime package has an actual change). Do not bump the version again.

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify/Diagnostics/` or a new area — the default sink implementation.
- `HoneyDrunk.Notify/HoneyDrunk.Notify/Storage/` — deliverability-event and suppression persistence.
- `HoneyDrunk.Notify/HoneyDrunk.Notify/Intake/` or `Routing/` — the send-path suppression check.
- `HoneyDrunk.Notify/HoneyDrunk.Notify/DependencyInjection/` — registrations.
- `HoneyDrunk.Notify.Tests` and `HoneyDrunk.Notify.IntegrationTests` — suppression and round-trip tests.
- Repo-level `CHANGELOG.md` (append to the in-progress entry) and `HoneyDrunk.Notify` runtime package `CHANGELOG.md`.

## NuGet Dependencies
No new `PackageReference` entries. The implementation uses the `HoneyDrunk.Notify` runtime's existing references only — the runtime csproj references `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Standards`, and `Microsoft.Extensions.*` (DI.Abstractions, Logging.Abstractions, Options). Persistence reuses the existing `Storage/` area pattern (`IIdempotencyStore` / `InMemoryIdempotencyStore` are the model — the suppression store follows the same interface-plus-in-memory shape). **No Service Bus or transport package is added** — see the Deferred note in Context; the message-bus broadcast is out of scope. `HoneyDrunk.Standards` is already on every project. `HoneyDrunk.Notify.Tests` and `HoneyDrunk.Notify.IntegrationTests` use the ADR-0047 stack (xUnit + NSubstitute + AwesomeAssertions); add no test packages beyond what those projects already reference.

## Boundary Check
- [x] `HoneyDrunk.Notify` runtime is the correct home — ADR-0038 D6 places bounce/complaint/suppression "at the Notify level." Notify owns delivery mechanics.
- [x] Suppression *state* lives in Notify. Preference/cadence *decision logic* stays in Communications (invariant 41) — this packet stores and exposes suppression state; it does not make orchestration decisions.
- [x] Per-tenant suppression keying respects invariant 39 — tenant mechanics at the post-dispatch (feedback) and intake (send-path check) boundaries.
- [x] No transport/Service Bus dependency added — the Notify runtime has none and this packet does not introduce one (Deferred note). Communications consumes suppression state through this packet's query surface, not a bus subscription, until the deferred bus path lands.

## Acceptance Criteria
- [ ] A default `IDeliverabilityFeedbackSink` implementation persists each `DeliverabilityEvent` to the Notify durable store
- [ ] Hard-bounce and complaint outcomes record a suppression entry keyed by `(TenantId, RecipientAddress)`; `Deferred` and `SoftBounced` do not suppress
- [ ] `Unsubscribed` outcomes record a suppression entry
- [ ] A platform-wide override list suppresses listed recipient addresses for every tenant, independent of per-tenant suppression
- [ ] Suppression is per-tenant: a unit test in `HoneyDrunk.Notify.Tests` proves tenant A's bounce on a recipient address does not suppress tenant B's send to that address
- [ ] Notify's send path consults the suppression store before dispatch; a suppressed send is short-circuited with a suppression outcome, not silently dropped
- [ ] An integration test in `HoneyDrunk.Notify.IntegrationTests` covers the round-trip: `ReceiveAsync` → durable store → suppression query
- [ ] No transport/Service Bus dependency is added to the `HoneyDrunk.Notify` runtime; the message-bus broadcast is explicitly out of scope (Deferred note)
- [ ] Test code contains no `Thread.Sleep` (invariant 51)
- [ ] The solution builds; all tests in `HoneyDrunk.Notify.Tests` and `HoneyDrunk.Notify.IntegrationTests` pass
- [ ] Repo-level `CHANGELOG.md` and the `HoneyDrunk.Notify` runtime package `CHANGELOG.md` append to the in-progress version entry; no new version bump (packet 05 bumped it)

## Human Prerequisites
None for the code work. Note: the sink's behavior is exercised against a real ESP only once the ESP account exists (packet 09) — the round-trip integration test uses an in-memory / fake ESP feedback source per invariant 15, so it does not block on packet 09.

## Referenced ADR Decisions
**ADR-0038 D6 — Bounce, complaint, and unsubscribe handling: a Notify primitive.** The default sink writes to the Notify durable store (Tier 1 per ADR-0036). Hard bounces and complaints suppress the recipient at the Notify level. Suppression is per-tenant — a tenant's bounce on a recipient does not suppress another tenant's send to that recipient — with a platform-wide override list for known abuse traps and complaint-honeypot addresses. Unsubscribes are part of suppression. (D6's prose also describes the sink eventually emitting a domain event onto a message bus for Communications to subscribe to; that broadcast is **deferred** — see the Deferred note in Context — because the Notify runtime currently has no transport dependency.)

**ADR-0038 Follow-up Work.** "Wire `IDeliverabilityFeedbackSink` and one default backing in Notify; the round-trip from send to suppression is covered by an integration test."

**ADR-0036 — DR tiers.** The Notify durable store (which now includes deliverability/suppression state) is Tier 1: RPO ≤ 1 hr, RTO ≤ 8 hr, geo-redundant storage with a passive secondary, semiannual restore drill.

**ADR-0042 — Idempotency / transport (cross-reference).** Notify taking a transport (message-bus) dependency is the natural home for the deferred deliverability-event broadcast. The bus-broadcast deliverable rejoins scope once that transport dependency lands.

## Constraints
> **Invariant 39 — Tenant mechanics stay at intake and post-dispatch boundaries.** The per-tenant suppression keying happens at the feedback-ingest (post-dispatch) boundary and the send-path check (intake) boundary. Internal Grid callers default to `TenantId.Internal`; do not branch core dispatch on caller-specific tenant logic.

> **Invariant 41 — Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify. Notify owns delivery mechanics; Communications owns decision logic.** This packet stores deliverability-derived suppression *state* and exposes it — that is delivery mechanics (a hard bounce is a delivery fact, not a cadence decision). ADR-0038 D6 explicitly places bounce/complaint suppression "at the Notify level." Do not move preference/cadence decision logic into Notify; do keep the deliverability-fact-driven suppression store in Notify per D6.

> **Invariant 51 — Test code contains no `Thread.Sleep`.** Async work waits via `await`, polling primitives with explicit timeouts, or synchronously-completing fakes. `Thread.Sleep` is a CI flakiness multiplier.

> **Invariant 15 — Unit and in-process integration tests never depend on external services.** The round-trip integration test uses an in-memory ESP feedback source — it does not require the real ESP from packet 09.

- **No transport dependency, no message-bus broadcast.** The `HoneyDrunk.Notify` runtime references only `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Standards`, and `Microsoft.Extensions.*` — it has no Service Bus / transport client. Do not add one. The bus-broadcast deliverable is deferred (see the Deferred note in Context and the ADR-0042 cross-reference).
- **No new version bump.** Packet 05 bumped the solution version. Append to the in-progress CHANGELOG entry.
- **Suppression is short-circuit, not silent-drop.** A suppressed send produces an observable suppression outcome.

## Labels
`feature`, `tier-2`, `ops`, `adr-0038`, `wave-3`

## Agent Handoff

**Objective:** Implement the default `IDeliverabilityFeedbackSink` backing — deliverability-feedback persistence, per-tenant suppression with a platform-wide override list, and the send-path suppression check. No message-bus broadcast (deferred).

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Build the runtime backing for the packet-05 contract so deliverability outcomes persist and suppress recipients per ADR-0038 D6.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 3.
- ADRs: ADR-0038 D6 (primary), ADR-0036 (Notify durable store is T1), ADR-0042 (cross-reference — the deferred bus broadcast's eventual home).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:05` — hard. The `IDeliverabilityFeedbackSink` interface and `DeliverabilityEvent` record must exist; this packet implements the backing.

**Constraints:**
- Per-tenant suppression keyed by `(TenantId, RecipientAddress)` (invariant 39); platform-wide override list is the one cross-tenant exception. The key is the recipient address string — no `PrincipalId` type exists.
- Suppression *state* in Notify (D6); decision *logic* stays in Communications (invariant 41).
- No `Thread.Sleep` in tests (invariant 51); round-trip integration test uses an in-memory ESP source (invariant 15).
- **No transport/Service Bus dependency** — the Notify runtime has none; do not add one. The message-bus broadcast is deferred (see the Deferred note).
- No new version bump — append to packet 05's in-progress CHANGELOG entry.

**Key Files:**
- `HoneyDrunk.Notify/HoneyDrunk.Notify/Storage/`, `Diagnostics/`, `Intake/` or `Routing/`, `DependencyInjection/`
- `HoneyDrunk.Notify.Tests` / `HoneyDrunk.Notify.IntegrationTests` projects
- Repo-level + `HoneyDrunk.Notify` runtime `CHANGELOG.md`

**Contracts:**
- Implements `IDeliverabilityFeedbackSink` (from packet 05). No new contract type emitted.
