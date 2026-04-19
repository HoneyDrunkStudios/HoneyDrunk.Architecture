# ADR-0019: Stand Up the HoneyDrunk.Communications Node — Orchestration Substrate Above Notify

**Status:** Proposed
**Date:** 2026-04-19
**Deciders:** HoneyDrunk Studios
**Sector:** Ops

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Create `HoneyDrunk.Communications` GitHub repo (human-only step — public default per Grid posture)
- [ ] Scaffold packet — solution structure with `HoneyDrunk.Communications.Abstractions` and `HoneyDrunk.Communications`, HoneyDrunk.Standards wiring, CI pipeline via HoneyDrunk.Actions shared workflows, InMemory fixtures for preference store and cadence policy
- [ ] Create `repos/HoneyDrunk.Communications/` context folder in the Architecture repo (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) — matching the template used by `repos/HoneyDrunk.Agents/`
- [ ] Reconcile `catalogs/contracts.json`: confirm the cataloged contracts (`ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`) against the final contract shape, and add any additional records introduced by this stand-up (`MessageIntent` if promoted to a value type — see D3) plus the `ICommunicationDecisionLog` surface added in D3
- [ ] Update `catalogs/grid-health.json` Communications entry to reflect the stood-up contract surface and scaffold expectations
- [ ] Wire the contract-shape canary into Actions for the frozen contracts named in D8
- [ ] **Notify refactor packet** — migrate `INotificationPolicy` conceptually into `IPreferenceStore` + `ICadencePolicy`, remove `INotificationPolicy` / `PolicyEvaluationResult` / `RejectionReason.PolicyDenied` from `HoneyDrunk.Notify.Abstractions`, delete `AllowAllPolicy` and `CompositePolicyPipeline`, remove the policy-evaluation step from `NotificationGateway.EnqueueAsync`, rename Notify's `Orchestration/` folder to `Intake/`, and update Notify's `boundaries.md`. This is part of acceptance, not a follow-up — see D11 and Consequences.
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

`HoneyDrunk.Communications` is cataloged in `catalogs/nodes.json` as the Grid's message orchestration and workflow layer above Notify, but the repo does not exist on disk and has no packages, no contracts, no scaffold, no CI. The *existence* of this Node was decided in a prior Proposed ADR (the orchestration-layer ADR that separated Notify's delivery mechanics from the decision layer). That ADR named the Node and sketched its five seed contracts. It did not resolve the boundary audit question — *which concerns already present in Notify actually belong to Communications* — and it did not settle the stand-up shape (package families, downstream coupling rule, canary requirements).

This ADR is the **stand-up decision** for the Communications Node. It does three things the prior orchestration-layer ADR deferred:

1. Names the package families, the downstream coupling rule, and the contract-shape canary requirement — the same shape ADR-0016 used for AI and ADR-0017 used for Capabilities, applied here for consistency.
2. Audits Notify's current surface (`INotificationPolicy`, `RejectionReason.PolicyDenied`, `AllowAllPolicy`, `CompositePolicyPipeline`, `NotificationRequest.Tags`) and flags specific types that are orchestration concerns leaking into the delivery Node.
3. **Bundles the Notify refactor into this ADR's scope.** Standing up Communications without pulling orchestration concerns out of Notify would leave the boundary blurred on day one — `INotificationPolicy`'s XML-doc-stated use cases (rate limits, opt-out lists, suppression rules) are the exact concerns Communications now owns, and leaving them in Notify forces consumers to choose between two competing decision-layer surfaces. Communications and the Notify refactor are therefore treated as **one architectural move**, not a stand-up followed by a separate cleanup initiative.

This deliberately **overrides the lean-standup convention** (set 2026-04-19) that standup ADRs stay scoped to the empty cataloged repo. The justification is boundary integrity from day one: Communications's public contract cannot co-exist with `INotificationPolicy` on Notify's public surface without producing exactly the "two competing decision layers" outcome the Node is being created to prevent. No other standup ADR carries this entanglement; the exception is scoped to this one move.

Notify today ships a live Ops-sector Node with a working delivery pipeline. The boundary smell is concentrated in two places on the Abstractions surface — `INotificationPolicy` and `RejectionReason.PolicyDenied` — and in two internal implementations — `AllowAllPolicy` and `CompositePolicyPipeline` under `HoneyDrunk.Notify/Policies/`. The XML docs on `INotificationPolicy` explicitly name "rate limits, opt-out lists, suppression rules" as the policy hook's use cases. Those are the exact concerns the Communications Node now owns. Keeping them in Notify blurs the boundary the moment Communications ships its first policy.

## Decision

### D1. HoneyDrunk.Communications is the Ops sector's outbound-messaging orchestration substrate

`HoneyDrunk.Communications` is the single Node in the Ops sector that owns **outbound-messaging orchestration primitives** — the contracts and runtime machinery that decide *why* a message should be sent, *to whom*, *when*, and *as part of what workflow*. It is a decision substrate, not a delivery engine. It does not render templates, call provider SDKs, manage queues, or retry sends; those mechanics stay in Notify.

Communications sits above Notify in the dependency graph and delegates all delivery through `INotificationSender`. Downstream Nodes that need to trigger user-facing communications from business events call Communications, not Notify directly. Nodes that bypass Communications and go straight to Notify are sending one-shot transactional messages with no preference, cadence, or workflow requirements — that path remains legal but is the exception, not the norm.

### D2. Package families

The Communications Node ships the following package families, mirroring ADR-0016 (AI) and ADR-0017 (Capabilities) for consistency:

- `HoneyDrunk.Communications.Abstractions` — all interfaces, records, request/response shapes, decision-log entry shapes. Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions and `HoneyDrunk.Notify.Abstractions`.
- `HoneyDrunk.Communications` — runtime composition: default `ICommunicationOrchestrator`, default `ICadencePolicy`, default decision logger, DI wiring.
- `HoneyDrunk.Communications.Testing` — opt-in testing fixture package carrying in-memory `IPreferenceStore` and `ICadencePolicy` implementations, a deterministic clock hook for cadence tests, and a recording decision logger for assertion-based tests. Consumed by downstream Nodes in test projects, never in production composition.

No `Providers.*` slot is introduced at stand-up. Preference storage backends (SQL, Cosmos, etc.) are deferred to a later ADR — see Open Questions.

### D3. Exposed contracts

The Communications Node's public boundary is the set of surfaces downstream Nodes may compile against. The prior orchestration-layer ADR seeded five. This stand-up confirms those, applies the grid-wide naming rule (records drop `I`, interfaces keep it, set 2026-04-19), and adds the decision-log surface:

| Contract | Kind | Purpose |
|---|---|---|
| `ICommunicationOrchestrator` | interface | Top-level entry point — given a business event, decides what messages to send, to whom, and when. Delegates delivery to Notify's `INotificationSender`. |
| `IMessageIntent` | interface | Business-event-to-message-intent mapping — captures the *why* and *what* of a communication decision. |
| `MessageIntent` | record | Value-type descriptor of a resolved intent — intent key, recipient scope, channel preference, template reference, model payload shape. (Promoted from prior ADR's interface-only framing to match the `CapabilityDescriptor` / `ModelCapabilityDeclaration` precedent for value-type descriptors.) |
| `IRecipientResolver` | interface | Resolves the target audience (one or many) for a message intent given Grid context. |
| `IPreferenceStore` | interface | User communication preferences — opt-in/out, channel preferences, quiet hours, suppression lists. |
| `ICadencePolicy` | interface | Enforces message frequency and spacing rules per user per intent. |
| `ICommunicationDecisionLog` | interface | Records every send-or-suppress decision with reasoning. Audit trail surface. |

Records drop the `I` prefix per the grid-wide naming rule. Interfaces retain it. `MessageIntent` is the only record introduced at stand-up; the other six contracts are interfaces.

If the scaffold packet finds that `IMessageIntent` as an interface is redundant with `MessageIntent` as a record (i.e., mappings are always value-shaped), the interface can be dropped before first release. The stand-up commits to the six surfaces the canary guards; the interface-vs-record split on the intent surface is allowed one round of refinement before the Abstractions package ships a 0.1.0 tag.

### D4. Boundary rule with Notify (definitive)

The existing orchestration-layer ADR stated the rule informally: *"delivery mechanics stay in Notify, decision logic moves to Communications."* This ADR makes the rule definitive with a decision test, because the audit (below) found Notify already contains types that violate it.

**Decision test — for any concern in the outbound-messaging path, ask:**

1. Does it touch a provider SDK, render a template, manage a queue, or classify transient vs. permanent failure? → **Notify**.
2. Does it decide whether a given user should receive a given message, or when, or as part of what sequence? → **Communications**.
3. Is it validation of the message shape itself (is the address well-formed, is the template key present)? → **Notify** (structural validation is delivery-side).
4. Is it validation of the message *decision* (should this user get this message right now)? → **Communications**.

Under this test, Notify's current `INotificationPolicy` and the `RejectionReason.PolicyDenied` enum case are category 2/4 concerns that were landed in Notify because Communications did not exist yet. D11 below names these — plus `PolicyEvaluationResult`, `AllowAllPolicy`, `CompositePolicyPipeline`, the policy-evaluation step in `NotificationGateway.EnqueueAsync`, and the `Orchestration/` folder rename — as **part of this ADR's acceptance**, not a follow-up.

### D5. Coupling to Notify is first-class, not optional

Communications takes a first-class runtime dependency on `HoneyDrunk.Notify.Abstractions`. There is no default orchestrator implementation that can produce a send without calling `INotificationSender`. Downstream Nodes consume Communications through `HoneyDrunk.Communications.Abstractions` only; the Notify dependency is composed in at the host, not transitively required at every consumer.

This is the same pattern ADR-0017 D10 applied for Capabilities → Auth: the dependency is real at the default-implementation layer, but consumers of the abstractions surface don't inherit it.

### D6. Preferences and decision log — default implementations are in-memory at stand-up

The stand-up does not commit to a persistence backend for `IPreferenceStore` or `ICommunicationDecisionLog`. Default implementations in `HoneyDrunk.Communications` are in-process (per-host dictionaries with reasonable defaults: everything allowed, no quiet hours, no suppression). The `HoneyDrunk.Communications.Testing` package supplies deterministic fixtures for tests.

Persistent implementations are a later ADR (see Open Questions). The stand-up's job is to ship the contract surface and the in-memory defaults so downstream Nodes can compile and run end-to-end in development. Production deployment will not happen on in-memory preferences — that's a production-readiness gate, not a stand-up gate.

### D7. Telemetry emission — Pulse consumes, Communications does not depend

Communications emits telemetry for every decision (resolved intent, preference check, cadence check, send delegation, decision logged) via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Communications has no runtime dependency on Pulse.** The direction is one-way by contract: Communications emits, Pulse observes. Same rule ADR-0016 D7 and ADR-0017 D7 applied for AI and Capabilities.

### D8. Contract-shape canary

A contract-shape canary is added to the Communications Node's CI: it fails the build if any of the four frozen contracts change shape (method signatures, parameter shapes, record members) without a corresponding version bump:

- `ICommunicationOrchestrator`
- `IMessageIntent` (or `MessageIntent` if the interface is collapsed per D3's allowed refinement)
- `IPreferenceStore`
- `ICadencePolicy`

These four are the hot path for every downstream consumer. `IRecipientResolver` and `ICommunicationDecisionLog` are guarded too but are lower-churn surfaces; they are included in the canary but flagged as non-blocking for the initial scaffold — the canary enforces all six on release candidates, not on every PR. This matches ADR-0016 D8 and ADR-0017 D8's rationale for hot-path protection.

### D9. Downstream coupling rule

Downstream Nodes that trigger communications (any Grid Node with a business event that should surface to a user) compile **only** against `HoneyDrunk.Communications.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.Communications` or on `HoneyDrunk.Communications.Testing` in production composition. Composition — which preference store is active, which cadence policy is in force, which decision log backend is wired — is a host-time concern, resolved at application startup.

Test projects may reference `HoneyDrunk.Communications.Testing` to pick up the in-memory fixtures. Production projects must not.

This is the same abstraction/runtime split already applied for AI, Capabilities, Vault, and Transport.

### D10. Flow consumes Communications, not the other way around

`catalogs/relationships.json` already lists `honeydrunk-flow` in Communications's `consumed_by_planned`. This ADR confirms the direction: when AI-sector Flow ships, it *may* drive multi-step communication campaigns by invoking `ICommunicationOrchestrator`, but Communications does not take a runtime dependency on Flow. Domain-specific orchestration for outbound messaging lives in Communications; general-purpose workflow execution lives in Flow. The two Nodes coexist with Communications as the caller-facing surface for anything communication-shaped.

### D11. The Notify refactor is part of this ADR's acceptance, not a follow-up

The boundary audit in the Context section identified types currently living in Notify that are category 2/4 concerns under D4's decision test. Because Communications's reason for existing is to own those concerns, shipping Communications while leaving them in Notify would produce two competing decision-layer surfaces on day one. This ADR therefore **folds the Notify refactor into acceptance**, overriding the standup-ADRs-stay-lean convention for this specific move. The refactor is not a separate initiative.

The refactor scope, as of this ADR, is exactly:

1. **Remove from `HoneyDrunk.Notify.Abstractions`:** `INotificationPolicy`, `PolicyEvaluationResult`, and the `RejectionReason.PolicyDenied` enum value. The remaining `RejectionReason` values (`ValidationFailed`, `DuplicateIdempotencyKey`, `ChannelUnavailable`, `TemplateNotFound`) stay — they are delivery-shaped.
2. **Migrate the concepts to Communications:** `INotificationPolicy`'s responsibilities are absorbed by `IPreferenceStore` + `ICadencePolicy`; `PolicyEvaluationResult` has no analogue on the Communications side (the decision is carried by `ICommunicationDecisionLog` entries and send vs. suppress is modeled as orchestrator return shape, not a transformed request); the `PolicyDenied` rejection concept becomes a decision-log entry in Communications rather than a Notify-surface rejection.
3. **Delete from `HoneyDrunk.Notify`:** `Policies/AllowAllPolicy.cs` and `Policies/CompositePolicyPipeline.cs`. The `Policies/` folder is removed if empty after these deletions.
4. **Remove the policy-evaluation step from `NotificationGateway.EnqueueAsync`** (lines ~69–81 at the time of this ADR). The gateway becomes strictly "validate shape, dedupe, render, enqueue." The XML doc on `EnqueueAsync` tightens to match — drop any "evaluates policies" language.
5. **Rename `HoneyDrunk.Notify/Orchestration/` to `HoneyDrunk.Notify/Intake/`.** "Orchestration" is the word Communications is claiming; Notify's gateway-and-enqueuer pair is an intake pipeline, not orchestration. This is a non-breaking internal rename.
6. **Update `repos/HoneyDrunk.Notify/boundaries.md`** to move "User preferences" from a bare "Notify does NOT own" bullet to an explicit "Owned by HoneyDrunk.Communications" callout with the D4 decision test inlined.

Notify ships a minor version bump with these removals (the Abstractions surface loses public types). Known consumers of the removed types: Notify's own `AllowAllPolicy` (deleted as part of this ADR) and Notify's own `CompositePolicyPipeline` (deleted as part of this ADR). No external consumers are known at the time of this ADR — this is why the refactor is low-risk despite the public-surface removal.

Ordering: Communications ships `Abstractions 0.1.0` first (so Notify's refactor has a concrete migration target to reference in release notes), then Notify's refactor ships in the same acceptance window. Both must be complete before this ADR flips Status → Accepted.

## Consequences

### Scope of this ADR — Communications standup plus Notify refactor, treated as one move

Acceptance of this ADR requires both halves of the move:

**Half 1 — Communications standup (new Node):**

- `HoneyDrunk.Communications` repo created.
- `HoneyDrunk.Communications.Abstractions`, `HoneyDrunk.Communications`, and `HoneyDrunk.Communications.Testing` packages scaffolded per D2.
- Seven contracts per D3 land on the Abstractions surface (six interfaces + `MessageIntent` record), with the D3-allowed one-round refinement on the intent surface permitted before 0.1.0.
- Default in-memory implementations of `IPreferenceStore`, `ICadencePolicy`, `ICommunicationDecisionLog`, and `ICommunicationOrchestrator` ship in `HoneyDrunk.Communications`.
- Contract-shape canary per D8 wired into Communications's CI.
- Downstream coupling rule per D9 documented.
- `repos/HoneyDrunk.Communications/` context folder created in Architecture repo.
- Catalog reconciliations per the follow-up checklist at the top of this ADR.

**Half 2 — Notify refactor (live Node):**

- All six items in D11 completed.
- Notify minor version bump published with the Abstractions surface changes in the changelog.
- `repos/HoneyDrunk.Notify/boundaries.md` updated to reflect the new boundary.

Both halves are gating. This ADR does not flip Status → Accepted until the Communications standup and the Notify refactor are both landed and the catalogs reflect the final state.

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] `HoneyDrunk.Communications.Abstractions 0.1.0` is published with the contracts in D3.
- [ ] `HoneyDrunk.Communications 0.1.0` is published with the D6 in-memory defaults.
- [ ] `HoneyDrunk.Communications.Testing 0.1.0` is published with the fixtures in D2.
- [ ] Communications's CI includes the D8 contract-shape canary and it is green.
- [ ] `HoneyDrunk.Notify.Abstractions` no longer exports `INotificationPolicy`, `PolicyEvaluationResult`, or `RejectionReason.PolicyDenied`.
- [ ] `HoneyDrunk.Notify/Policies/AllowAllPolicy.cs` and `HoneyDrunk.Notify/Policies/CompositePolicyPipeline.cs` are deleted.
- [ ] `NotificationGateway.EnqueueAsync` no longer runs a policy-evaluation step and its XML doc reflects the tightened contract.
- [ ] `HoneyDrunk.Notify/Orchestration/` is renamed to `HoneyDrunk.Notify/Intake/` (non-breaking internal rename).
- [ ] Notify ships a minor version bump with the above changes noted in the changelog.
- [ ] `repos/HoneyDrunk.Notify/boundaries.md` is updated per D11 item 6.
- [ ] `catalogs/contracts.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, and `catalogs/modules.json` reflect both halves of the move.
- [ ] Scope agent flips Status → Accepted and assigns final invariant numbers.

### Refactor Details — Notify (full type-by-type breakdown)

The audit of Notify's current surface (repo at `c:\Users\tatte\source\repos\HoneyDrunkStudios\HoneyDrunk.Notify`, solution `HoneyDrunk.Notify/HoneyDrunk.Notify.slnx`) identified the following items. Classification is **Migrate**, **Stay**, or **Rename**. These items are **part of this ADR's acceptance** per D11.

**Migrate to Communications (boundary violations — these are orchestration concerns currently in Notify):**

| Type / Module | Current Location | Reason |
|---|---|---|
| `INotificationPolicy` | `HoneyDrunk.Notify.Abstractions/INotificationPolicy.cs` | XML doc names its use cases as "rate limits, opt-out lists, suppression rules" — all Communications concerns. Interface should be removed from Notify's public surface and its responsibilities absorbed by `IPreferenceStore` + `ICadencePolicy` in Communications. |
| `PolicyEvaluationResult` | `HoneyDrunk.Notify.Abstractions/PolicyEvaluationResult.cs` | Coupled to `INotificationPolicy`; carries the `TransformedRequest` path (channel override, tag injection) which is decision-layer behavior. |
| `RejectionReason.PolicyDenied` | `HoneyDrunk.Notify.Abstractions/RejectionReason.cs` | Currently the only orchestration-shaped rejection in an otherwise delivery-shaped enum. Move the concept to Communications's decision log; Notify's enum keeps `ValidationFailed`, `DuplicateIdempotencyKey`, `ChannelUnavailable`, `TemplateNotFound`. |
| `AllowAllPolicy` | `HoneyDrunk.Notify/Policies/AllowAllPolicy.cs` | Default no-op policy; becomes unnecessary once `INotificationPolicy` leaves Notify. |
| `CompositePolicyPipeline` | `HoneyDrunk.Notify/Policies/CompositePolicyPipeline.cs` | Composite policy executor; its role is replaced by Communications's orchestrator calling preference and cadence checks in sequence. |
| Policy evaluation step in `NotificationGateway.EnqueueAsync` | `HoneyDrunk.Notify/Orchestration/NotificationGateway.cs` lines ~69–81 | Policy evaluation happens inside Notify's intake pipeline. That step moves out; the gateway becomes purely "validate, dedupe, render, enqueue." |

**Stay in Notify (true delivery mechanics — do not move):**

| Type / Module | Reason |
|---|---|
| `INotificationSender`, `INotificationGateway`, `INotificationSenderResolver` | Delivery contracts — Communications consumes these. |
| `NotificationRequest`, `NotificationEnvelope`, `NotificationOutcome` | Delivery shapes — Communications produces and consumes these. |
| `NotificationChannel`, `NotificationPriority`, `Recipient`, `TemplateKey`, `IdempotencyKey`, `AttemptId`, `NotificationId` | Delivery-side value types. |
| `DeliveryOutcome`, `DeliveryStatus`, `FailureKind` | Provider-layer classification — strictly delivery mechanics. |
| `IEmailTemplateRenderer`, `ITemplateRenderer`, `Templates/` | Rendering is delivery mechanics. |
| `Providers.Email.Smtp`, `Providers.Email.Resend`, `Providers.Sms.Twilio` | Provider adapters — delivery mechanics. |
| `Routing/NotificationDispatcher`, `Routing/NotificationSenderResolver`, `Routing/ExponentialBackoffStrategy`, `IBackoffStrategy` | Retry and channel routing — delivery mechanics. |
| `Queue.Abstractions`, `Queue.AzureStorage`, `Queue.InMemory`, `Worker` | Async delivery pipeline — delivery mechanics. |
| `Storage/IIdempotencyStore`, `InMemoryIdempotencyStore` | Deduplication at delivery time — delivery mechanics (not to be confused with cadence, which is decision-layer). |
| Structural validation in `NotificationGateway.ValidateRequest` | Validates envelope shape (address well-formed, template key present) — delivery mechanics. |

**Rename or narrow:**

| Type / Module | Recommendation | Reason |
|---|---|---|
| `Orchestration/` folder in `HoneyDrunk.Notify` runtime project | Rename to `Intake/` or `Pipeline/` | "Orchestration" is the word Communications is claiming. Notify's gateway-and-enqueuer pair is an intake pipeline, not orchestration. |
| `NotificationGateway.EnqueueAsync` XML doc | Tighten to "validates structural shape, applies dedupe, renders, enqueues" | Current doc says "evaluates policies" — drop that after the migration. |
| `boundaries.md` at `c:\Users\tatte\source\repos\HoneyDrunkStudios\HoneyDrunk.Architecture\repos\HoneyDrunk.Notify\boundaries.md` | Update to move "User preferences" from a bare "Notify does NOT own" bullet to an explicit "Owned by HoneyDrunk.Communications" callout with the boundary rule from D4. | The current boundaries doc is out of date with the decision layer that Communications now owns. |

The refactor execution order (now inside this ADR's scope per D11): (a) add the new Communications contracts and publish `Abstractions 0.1.0` so Notify's refactor has a concrete migration target to cite, (b) migrate `INotificationPolicy` / `PolicyEvaluationResult` conceptually into `IPreferenceStore` + `ICadencePolicy` on the Communications side, (c) remove the policy step from Notify's gateway in a Notify minor version bump (breaking for consumers that registered custom `INotificationPolicy` implementations — currently none known, which is why the refactor is low-risk), (d) update Notify's Abstractions by removing `INotificationPolicy`, `PolicyEvaluationResult`, and the `PolicyDenied` enum value, (e) rename Notify's `Orchestration/` folder to `Intake/` as a non-breaking internal change.

### Unblocks

Accepting this ADR — and landing both halves of the move (scaffold + Notify refactor) — unblocks the following:

- **Any Grid Node that triggers user-facing communications** — can compile against `HoneyDrunk.Communications.Abstractions` for orchestrated sends, instead of reaching directly into Notify for decision-layer logic the caller would otherwise reinvent.
- **HoneyDrunk.Flow (planned)** — gains `ICommunicationOrchestrator` as a callable surface for campaign and lifecycle workflows.
- **Notify's public surface** — tightens to delivery-only, matching its charter. No consumer of Notify can accidentally take a dependency on an orchestration concern because those types are removed from the Abstractions package.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`.** Composition against `HoneyDrunk.Communications` and `HoneyDrunk.Communications.Testing` is a host-time (and test-time) concern.
- **Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify.** Notify owns delivery mechanics; Communications owns decision logic. See D4's decision test.
- **Every orchestrated send records a decision-log entry via `ICommunicationDecisionLog`.** A send without a recorded decision is a build or runtime failure, depending on the specific enforcement point chosen at scaffold time.
- **The Communications Node CI must include a contract-shape canary for `ICommunicationOrchestrator`, `IMessageIntent` / `MessageIntent`, `IPreferenceStore`, and `ICadencePolicy`.** Shape drift on any of the four is a build failure.

### Contract-shape canary becomes a requirement

The contract-shape canary in D8 is a gating requirement on the Communications Node's CI from the first scaffold. It is not a later hardening pass — the frozen contracts are the hot path for every consumer and must be protected from day one.

### Catalog obligations

`catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json`, `catalogs/grid-health.json`, and `catalogs/modules.json` already carry Communications entries seeded by the prior orchestration-layer ADR. The follow-up work list above names the specific reconciliations required so the catalogs do not go stale against the final contract shape.

### Negative

- **Acceptance gate is wider than a typical standup ADR.** Bundling the Notify refactor into acceptance means this ADR does not flip Accepted on Communications scaffold alone — both halves must ship. This is the deliberate exception called out in Context; the cost is a slower path to Accepted status, the benefit is no day-one boundary blur.
- The Notify refactor introduces a minor breaking change on Notify's Abstractions surface (removal of `INotificationPolicy`, `PolicyEvaluationResult`, and `RejectionReason.PolicyDenied`). Mitigation: the only known consumers are Notify's own `AllowAllPolicy` and `CompositePolicyPipeline`, both deleted as part of this ADR; Notify ships a minor version bump and notes the break in the changelog.
- Records vs. interfaces on the intent surface carries a one-refinement-allowed caveat (D3). That slightly softens the stand-up's firmness on contract shape, but the canary protects against drift beyond the permitted one-round refinement.
- Standing up another Ops-sector Node for a solo developer adds maintenance surface. Mitigation is the same as the prior orchestration-layer ADR gave: Communications is lightweight — it holds decision logic and delegates all heavy lifting to Notify.
- Communications's in-memory default `IPreferenceStore` is not suitable for production. That is accepted at stand-up; the production-readiness gate is a later ADR that picks a persistence backend.

## Alternatives Considered

### Keep `INotificationPolicy` in Notify and use it as the orchestration seam

Rejected. The audit shows `INotificationPolicy` is doing orchestration work — its documented use cases are rate limits, opt-out lists, and suppression rules, with a transform path that can rewrite channel and inject tags. Leaving it in Notify under the existing name means Communications either duplicates it (drift) or consumes it across the boundary (inverted dependency: Notify would need to know about Communications's decision model). Moving the concept out and replacing it with `IPreferenceStore` + `ICadencePolicy` in Communications puts each concern in its owning Node.

### Ship Communications without a contract-shape canary

Rejected. ADR-0016 D8 and ADR-0017 D8 established contract-shape canaries as a stand-up-time gating requirement for hot-path surfaces. The same reasoning applies here. Skipping the canary at stand-up means the first breaking change on `ICommunicationOrchestrator` or `ICadencePolicy` is discovered at a consumer, not at Communications's own CI.

### Fold Communications into Notify as a "Notify.Orchestration" sub-package

Rejected. Package families inside a Node share a solution, a CI pipeline, and a release cadence. Tying Communications's release cadence to Notify's means every preference or cadence rule change ships behind every delivery-layer fix, and vice versa. The two Nodes have genuinely different change velocities — Notify changes when provider APIs or queue backends change; Communications changes when a new campaign type or preference dimension is introduced. Separate Nodes, separate cadences.

### Treat the Notify refactor as a separate follow-up initiative

Rejected — this was the original framing of this ADR and was reversed on 2026-04-19 before acceptance. The user's lean-standup convention (set 2026-04-19 per memory) says standup ADRs stay scoped to the empty cataloged repo and refactors of existing Nodes are separate initiatives. That convention is preserved as the default; this ADR is a deliberate, scoped exception. The reason the exception is taken here: Communications and Notify's policy surface are the same architectural concern expressed in two places. Standing up Communications while `INotificationPolicy` is still on Notify's public surface would produce two competing decision-layer contracts on day one — exactly the outcome the new Node is being created to prevent. The boundary-integrity gain outweighs the convention cost. No other standup ADR in flight carries this entanglement; the exception does not generalize.

### Defer the stand-up until the Notify refactor is complete (standalone Notify refactor first)

Rejected. Making Notify's refactor a prerequisite inverts the dependency: Notify needs a concrete migration target (`IPreferenceStore` and `ICadencePolicy` on Communications's Abstractions surface) before `INotificationPolicy` can be cleanly removed. The correct order is Communications ships `Abstractions 0.1.0` first, then Notify's refactor references those contracts in its release notes, and both land in the same acceptance window of this ADR. This is not a deferred standup — it is a sequenced bundle.

### Declare `ICommunicationDecisionLog` out of scope for stand-up

Rejected. The decision log is the single most important surface for proving the Node is doing its job — a preference check that went unrecorded is indistinguishable from no preference check at all. Leaving it out would force the first real consumer to invent its own decision record, which would then have to be retrofitted into the Node's contract surface. The decision log stays in at stand-up, with an in-memory default; a persistent backend is a later ADR.

## Open Questions

Items that should become their own ADRs later:

- **Preference storage backend** — when to pick (SQL via HoneyDrunk.Data, Cosmos, per-tenant isolation model) and what the migration story looks like from the in-memory default. Likely converges with Memory Node's tenant-scoped storage patterns.
- **Workflow engine for multi-step campaigns** — at what volume / complexity should Communications start consuming Flow (AI sector) for multi-step campaign execution, versus keeping in-process sequencing in the orchestrator itself. Today the seed answer is "in-process sequencing for now"; the tipping point is an ADR.
- **Cadence model precision** — per-user-per-intent is the default framing. Whether cadence needs to expand to per-user-per-channel, per-user-per-tenant, or per-user-global suppression is deferred. The `ICadencePolicy` contract should accept this expansion without a shape break.
- **Decision-log retention and query shape** — audit trails grow. Retention policy, query surface for "why did this user get this message," and integration with Pulse for decision-log telemetry are deferred to the persistence ADR or its own ADR, whichever comes first.
- **Intent authoring model** — are intents declared as code (`IMessageIntent` implementations), as configuration (App Configuration entries per ADR-0005), or both? This is adjacent to Capabilities's tool-schema versioning question and may resolve similarly.
