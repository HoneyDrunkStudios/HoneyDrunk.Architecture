---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["feature", "tier-2", "ops", "adr-0038", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0038"]
accepts: ["ADR-0038"]
wave: 2
initiative: adr-0038-outbound-sender-identity-and-deliverability
node: honeydrunk-notify
---

# Add IDeliverabilityFeedbackSink and the DeliverabilityEvent record to HoneyDrunk.Notify.Abstractions

## Summary
Add the `IDeliverabilityFeedbackSink` interface and the `DeliverabilityEvent` record to `HoneyDrunk.Notify.Abstractions` per ADR-0038 D6 — the normalized contract through which Notify receives bounce, complaint, deferral, and unsubscribe outcomes from any ESP. This is the contract-only packet; the default backing is packet 06.

## Context
ADR-0038 D6 makes bounce/complaint/unsubscribe handling a **Notify primitive**. Every send returns a deliverability outcome over time — accepted, deferred, bounced (hard/soft), complained, unsubscribed. Each ESP exposes this differently; Notify normalizes via an internal contract:

> `IDeliverabilityFeedbackSink` (new Abstractions interface in `HoneyDrunk.Notify.Abstractions`) — receives normalized `DeliverabilityEvent` records (recipient address / `TenantId` / `MessageId` / `Outcome` / `ProviderRawCode`).

This packet adds **only the contract** to the Abstractions package — a new interface and a new record. The default backing (deliverability-feedback persistence and the per-tenant suppression list) is packet 06; the suppression behavior packet 06 also covers. Splitting contract from backing keeps the Abstractions change small, reviewable, and binary-stable, and lets `HoneyDrunk.Communications` (which per ADR-0038's Affected Nodes "consumes the new feedback signal where decision-orchestration depends on suppression state") compile against the contract before the backing exists.

`HoneyDrunk.Notify.Abstractions` is an Abstractions package — invariant 1: it has zero runtime dependencies on other HoneyDrunk packages, only `Microsoft.Extensions.*` abstractions are permitted. The new interface and record must hold to that. The existing Abstractions package already defines `NotificationId`, `DeliveryOutcome`, `DeliveryStatus`, `FailureKind`, `IdempotencyKey`, and tenant-aware models — the new types compose with those (in particular `DeliverabilityEvent` should reuse `NotificationId` / the existing message-id type rather than introduce a parallel one).

## Scope
- `HoneyDrunk.Notify.Abstractions` — add `IDeliverabilityFeedbackSink` and `DeliverabilityEvent` (and a supporting `DeliverabilityOutcome` enum if one does not already exist that fits — reconcile with the existing `DeliveryOutcome` / `DeliveryStatus` / `FailureKind` types before adding a new enum).
- `catalogs/contracts.json` (in `HoneyDrunk.Architecture`) — append the two new public types to the `honeydrunk-notify` block's `interfaces` array. **Note:** this is a cross-repo edit — the agent executes the Notify code change and the `contracts.json` change as two commits, or flags the `contracts.json` update for the Architecture repo. See Proposed Implementation step 7.

## Proposed Implementation
1. **`DeliverabilityOutcome`** — reconcile first: the package already has `DeliveryOutcome`, `DeliveryStatus`, and `FailureKind`. ADR-0038 D6 enumerates the outcomes: `accepted`, `deferred`, `bounced` (hard/soft distinction), `complained`, `unsubscribed`. If an existing type covers this, reuse it. If not, add a `DeliverabilityOutcome` enum with members: `Accepted`, `Deferred`, `SoftBounced`, `HardBounced`, `Complained`, `Unsubscribed`. The hard/soft bounce distinction is load-bearing — D6 says "hard bounces and complaints suppress the recipient."
2. **`DeliverabilityEvent`** — a record carrying the D6-named fields:
   - `TenantId` — the `TenantId` type from `HoneyDrunk.Kernel.Abstractions` (the Abstractions package already references Kernel.Abstractions for tenant-aware models — confirm and reuse).
   - `RecipientAddress` — `string`, the recipient email/SMS address the send was addressed to. **Pinned decision:** use the recipient address string — the `Address` value carried by the existing `Recipient` record (`HoneyDrunk.Notify.Abstractions/Recipient.cs`). There is **no** `PrincipalId` type in `HoneyDrunk.Notify.Abstractions` or `HoneyDrunk.Kernel.Abstractions` — do **not** invent a new strongly-typed `PrincipalId`. The recipient address is also the per-tenant suppression key in packet 06.
   - `MessageId` — reuse `NotificationId` (the existing message identity type) rather than introduce a new id.
   - `Outcome` — the `DeliverabilityOutcome`.
   - `ProviderRawCode` — `string?`, the ESP's raw status code, preserved for support correlation.
   - A timestamp (`OccurredAt`, `DateTimeOffset`) — deliverability outcomes arrive over time, so the event needs its own occurrence time.
   - Per the Grid naming rule (records drop the `I` prefix, interfaces keep it), the type is `DeliverabilityEvent`, not `IDeliverabilityEvent`. Use `init` members, not positional-record syntax, per the Grid abstractions-versioning convention.
3. **`IDeliverabilityFeedbackSink`** — the interface:
   - A single method, e.g. `Task ReceiveAsync(DeliverabilityEvent feedback, CancellationToken cancellationToken)`.
   - Full XML documentation on the interface and the method (invariant 13).
4. **XML documentation** on every public member of all new types (invariant 13 — enforced by `HoneyDrunk.Standards` analyzers).
5. **Version bump.** Per invariant 27, this is the first packet to land on the `HoneyDrunk.Notify` solution in this initiative — it bumps the version. A new public interface and record in an Abstractions package is a **minor** bump (new feature, backward-compatible). Bump every non-test `.csproj` in the solution to the same new minor version in this commit.
6. **CHANGELOG / README.** Add a repo-level `CHANGELOG.md` entry for the new version (invariant 12/27). Add a per-package `CHANGELOG.md` entry for `HoneyDrunk.Notify.Abstractions` (it has an actual change). Update `HoneyDrunk.Notify.Abstractions`'s `README.md` if it documents the public API surface (invariant 12). Do not add per-package CHANGELOG noise entries for packages bumped only for solution alignment.
7. **Update `catalogs/contracts.json` in `HoneyDrunk.Architecture`.** Append the two new public types to the `honeydrunk-notify` block's `interfaces` array (the block already lists `INotificationSender` and `INotificationGateway`):
   - `{ "name": "IDeliverabilityFeedbackSink", "kind": "interface", "description": "Receives normalized DeliverabilityEvent records — bounce, complaint, deferral, and unsubscribe outcomes from any ESP." }`
   - `{ "name": "DeliverabilityEvent", "kind": "type", "description": "Normalized deliverability outcome record: tenant, recipient address, message id, outcome, and provider raw code." }`
   This is a cross-repo edit — `contracts.json` lives in `HoneyDrunk.Architecture`, not Notify. The executing agent files it as a separate Architecture-repo commit/PR or flags it; the Notify code change and the catalog change are not in the same repo.

## Affected Files
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/IDeliverabilityFeedbackSink.cs` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/DeliverabilityEvent.cs` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/DeliverabilityOutcome.cs` (new, only if no existing enum fits)
- Every non-test `.csproj` in the `HoneyDrunk.Notify` solution — version bump (invariant 27).
- Repo-level `CHANGELOG.md`; `HoneyDrunk.Notify.Abstractions/CHANGELOG.md`; `HoneyDrunk.Notify.Abstractions/README.md` (if it lists the API surface).
- `catalogs/contracts.json` (in `HoneyDrunk.Architecture`) — the `honeydrunk-notify` block's `interfaces` array gains the two new types.

## NuGet Dependencies
No new `PackageReference` entries. `HoneyDrunk.Notify.Abstractions` already references `HoneyDrunk.Kernel.Abstractions` (for `TenantId` and tenant-aware models) and `HoneyDrunk.Standards` (analyzers, `PrivateAssets: all`) — confirm both are present and add no others. Per invariant 1, an Abstractions package takes only `Microsoft.Extensions.*` abstractions and the Kernel.Abstractions contract package; do not add a runtime dependency.

## Boundary Check
- [x] `HoneyDrunk.Notify.Abstractions` is the correct package — ADR-0038 D6 names it explicitly. Routing rule "notification, email, SMS, ..., notify, channel → HoneyDrunk.Notify" maps exactly.
- [x] Contract-only — no backing, no durable store, no suppression list. That is packet 06.
- [x] Invariant 1 holds — no new HoneyDrunk runtime dependency in the Abstractions package.
- [x] No Communications change — Communications consumes the contract but its update (if any) is a separate concern; ADR-0038 says Communications has "no contract change."

## Acceptance Criteria
- [ ] `IDeliverabilityFeedbackSink` exists in `HoneyDrunk.Notify.Abstractions` with a single `ReceiveAsync(DeliverabilityEvent, CancellationToken)` method, fully XML-documented
- [ ] `DeliverabilityEvent` is a record (not interface-prefixed) with `init` members carrying `TenantId`, `RecipientAddress` (a `string` — the `Recipient.Address` value, **not** a new `PrincipalId` type), `MessageId` (reusing `NotificationId`), `Outcome`, `ProviderRawCode`, and an occurrence timestamp
- [ ] The deliverability outcome enumeration covers accepted / deferred / soft-bounce / hard-bounce / complained / unsubscribed — either an existing reused type or a new `DeliverabilityOutcome` enum, with the reconciliation decision recorded
- [ ] Every new public member has XML documentation (invariant 13)
- [ ] `HoneyDrunk.Notify.Abstractions` takes no new HoneyDrunk runtime dependency (invariant 1)
- [ ] Every non-test `.csproj` in the solution is bumped to the same new minor version (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has an entry for the new version; `HoneyDrunk.Notify.Abstractions/CHANGELOG.md` has an entry for the new types; no alignment-noise entries in other per-package changelogs
- [ ] `HoneyDrunk.Notify.Abstractions/README.md` reflects the new contract if it documents the API surface
- [ ] `catalogs/contracts.json` (in `HoneyDrunk.Architecture`) — the `honeydrunk-notify` block's `interfaces` array gains `IDeliverabilityFeedbackSink` (`kind: interface`) and `DeliverabilityEvent` (`kind: type`)
- [ ] The solution builds and the existing tests in `HoneyDrunk.Notify.Tests` pass; if the Abstractions package has a contract-shape canary, it is updated for the intentional addition

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0038 D6 — Bounce, complaint, and unsubscribe handling: a Notify primitive.** Every send returns a deliverability outcome over time: accepted, deferred, bounced (hard/soft), complained, unsubscribed. Each ESP exposes this differently; Notify normalizes via `IDeliverabilityFeedbackSink` (new Abstractions interface in `HoneyDrunk.Notify.Abstractions`), receiving normalized `DeliverabilityEvent` records carrying recipient address / `TenantId` / `MessageId` / `Outcome` / `ProviderRawCode`. The default sink (packet 06) persists deliverability feedback to the Notify durable store and maintains a per-tenant suppression list. Hard bounces and complaints suppress the recipient; suppression is per-tenant with a platform-wide override list. Broadcasting deliverability events onto a message bus is deferred — see packet 06's Deferred note.

**ADR-0038 Affected Nodes.** "HoneyDrunk.Notify — gains `IDeliverabilityFeedbackSink` in Abstractions; default backing wires to ESP normalization." "HoneyDrunk.Communications — no contract change; consumes the new feedback signal where decision-orchestration depends on suppression state."

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** Only `Microsoft.Extensions.*` abstractions are permitted (plus the Kernel.Abstractions contract package the Notify Abstractions package already references). `IDeliverabilityFeedbackSink` and `DeliverabilityEvent` must not pull in a runtime dependency — no ESP SDK, no Service Bus client, no durable-store type.

> **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards` analyzers. Every new public member is documented.

> **Invariant 27 — All projects in a solution share one version and move together.** This is the first packet on the `HoneyDrunk.Notify` solution in this initiative; it bumps the version, and every non-test `.csproj` moves to the same new version in one commit. Subsequent packets (06, 07) append to the CHANGELOG only.

- **Grid naming rule:** records drop the `I` prefix (`DeliverabilityEvent`), interfaces keep it (`IDeliverabilityFeedbackSink`). Records use `init` members, not positional syntax.
- **Reconcile before adding an enum.** The package already has `DeliveryOutcome` / `DeliveryStatus` / `FailureKind` — check whether one already covers the D6 outcome set before introducing `DeliverabilityOutcome`. Record the reconciliation decision in the PR.
- **Identity field is the recipient address string.** `DeliverabilityEvent` carries `RecipientAddress` (a `string`, the `Recipient.Address` value). There is no `PrincipalId` type in Notify.Abstractions or Kernel.Abstractions — do not invent one.
- **Contract only.** No backing implementation, no durable store, no suppression list — that is packet 06.

## Labels
`feature`, `tier-2`, `ops`, `adr-0038`, `wave-2`

## Agent Handoff

**Objective:** Add the `IDeliverabilityFeedbackSink` interface and `DeliverabilityEvent` record to `HoneyDrunk.Notify.Abstractions`.

**Target:** `HoneyDrunk.Notify`, branch from `main`.

**Context:**
- Goal: Land the normalized deliverability-feedback contract ADR-0038 D6 mandates, so the default backing (packet 06) and Communications can compile against it.
- Feature: ADR-0038 Outbound Sender Identity and Deliverability rollout, Wave 2.
- ADRs: ADR-0038 D6 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0038 should be Accepted before its D6 contract is added.

**Constraints:**
- Abstractions package — invariant 1, no runtime HoneyDrunk dependency.
- Grid naming rule — `DeliverabilityEvent` record (no `I`), `IDeliverabilityFeedbackSink` interface, `init` members.
- Reconcile with existing `DeliveryOutcome`/`DeliveryStatus`/`FailureKind` before adding a new enum.
- First packet on the solution — bump the version (minor); every non-test `.csproj` moves together (invariant 27).
- Contract only — no backing (packet 06).

**Key Files:**
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/IDeliverabilityFeedbackSink.cs` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/DeliverabilityEvent.cs` (new)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/DeliverabilityOutcome.cs` (new, conditional)
- `HoneyDrunk.Notify/HoneyDrunk.Notify.Abstractions/Recipient.cs` — reference only, for the `Address` field convention
- Repo-level + `HoneyDrunk.Notify.Abstractions` `CHANGELOG.md`; `HoneyDrunk.Notify.Abstractions/README.md`
- `catalogs/contracts.json` (in `HoneyDrunk.Architecture`) — `honeydrunk-notify` block `interfaces` array

**Contracts:**
- `IDeliverabilityFeedbackSink` — new interface, `HoneyDrunk.Notify.Abstractions`.
- `DeliverabilityEvent` — new record, `HoneyDrunk.Notify.Abstractions`. Carries `RecipientAddress` as a `string`.
