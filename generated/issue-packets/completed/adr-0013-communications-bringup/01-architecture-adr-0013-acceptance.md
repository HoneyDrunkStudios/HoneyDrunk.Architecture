---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "catalog", "adr-0013", "adr-0026", "wave-1"]
dependencies: []
adrs: ["ADR-0013", "ADR-0026"]
wave: 1
initiative: adr-0013-communications-bringup
node: honeydrunk-architecture
---

# Feature: Accept ADR-0013 — Communications context folder, ADR index, initiative + roadmap, Notify boundary refresh

## Summary
Land the Architecture-side standup work for ADR-0013 in one PR: create the `repos/HoneyDrunk.Communications/` context folder, flip the ADR-0013 index row to `Accepted` (verify the ADR header matches), register the bring-up initiative in `active-initiatives.md`, add Q2/Q3 2026 roadmap bullets that surface Phase 1/2 (now) and Phase 3 (deferred), and refresh `repos/HoneyDrunk.Notify/boundaries.md` and `integration-points.md` so Notify's context acknowledges Communications as a downstream consumer. Catalog files were updated at ADR drafting time — this packet only verifies them in passing.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0013 was Accepted. Catalog registration shipped with the ADR (`nodes.json`, `relationships.json`, `contracts.json`, `grid-health.json`, `modules.json`, `sector-interaction-map.md`, `feature-flow-catalog.md`). What is still missing:

- `repos/HoneyDrunk.Communications/` context folder (the standard five files every cataloged Node has)
- The ADR index row in `adrs/README.md` may still read `Proposed` (verify; flip if not)
- No initiative entry exists for the bring-up — without it, the Phase 3 deferral risks getting lost
- The roadmap does not mention Communications anywhere
- Notify's repo context (`boundaries.md` and `integration-points.md`) does not yet acknowledge that Communications is a downstream consumer of `INotificationSender` — leaving Notify's context out of date with the relationships graph

This packet fixes all of the above in one PR so subsequent packets (repo creation, scaffold, Phase 1, Phase 2) have complete Architecture-side context to anchor against.

## Scope

All edits are in the `HoneyDrunk.Architecture` repo. No code. No secrets. No new ADR.

### Part A — Verify catalogs already done (no edit unless drift detected)

Catalogs were updated at ADR-0013 drafting. This packet verifies they are intact and only edits if drift is found:

- `catalogs/nodes.json` — confirm `honeydrunk-communications` entry exists (sector Ops, signal Seed, cluster `orchestration`)
- `catalogs/relationships.json` — confirm `honeydrunk-communications` entry exists with `consumes: ["honeydrunk-kernel", "honeydrunk-notify"]`, `consumed_by_planned: ["honeydrunk-flow"]`; confirm `honeydrunk-notify.consumed_by` includes `honeydrunk-communications`
- `catalogs/contracts.json` — confirm `honeydrunk-communications` entry exists with the five interfaces (`ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`)
- `catalogs/grid-health.json` — confirm `honeydrunk-communications` entry exists with `signal: "Seed"`, `version: "0.0.0"`, `active_blockers: ["Repo not yet scaffolded"]`
- `catalogs/modules.json` — confirm `communications-abstractions` and `communications-runtime` entries exist
- `constitution/sector-interaction-map.md` — confirm Ops section diagram lists Communications above Notify with the delivery-delegation arrow, and the "Communications ↔ Notify split" callout paragraph is present
- `constitution/feature-flow-catalog.md` — confirm Flow 2 was renamed and Flow 2b was added per the ADR's Catalog Changes section

If any of these are missing or have drifted, fix them as part of this PR. Document the audit outcome (drift found vs. clean) in the PR description.

### Part B — Repo context folder (new — five files)

Create `repos/HoneyDrunk.Communications/` with the standard file set, matching the structure used in `repos/HoneyDrunk.AI/` and `repos/HoneyDrunk.Vault.Rotation/`:

#### `repos/HoneyDrunk.Communications/overview.md`

```markdown
# HoneyDrunk.Communications — Overview

**Sector:** Ops
**Version:** TBD (initial release planned 0.1.0 → 0.2.0 with Phase 1 contracts → 0.3.0 with Phase 2 welcome flow)
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Communications`
**Status:** Standup in progress (Phase 1 + Phase 2 scoped; Phase 3 deferred)

## Purpose

Decision and orchestration layer for outbound communications. Determines why, when, and to whom messages are sent. Manages multi-step flows, campaigns, user preferences, suppression, cadence rules, and business-event-to-message-intent mapping. Delegates all delivery mechanics to Notify.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Communications.Abstractions` | Abstractions | Orchestration contracts — `ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy` |
| `HoneyDrunk.Communications` | Runtime | Orchestrator implementation, in-memory stores (Phase 2), Kernel integration |

## Key Interfaces

- `ICommunicationOrchestrator` — entry point for business events → message decisions → delivery delegation to Notify
- `IMessageIntent` — maps a business event (UserSignedUp, SubscriptionExpiring, AgentTaskCompleted, ...) to a message-intent shape
- `IRecipientResolver` — resolves the target audience for a message intent
- `IPreferenceStore` — user opt-in/out, channel preferences, quiet hours, suppression lists
- `ICadencePolicy` — frequency and spacing rules per recipient

## Design Notes

The boundary rule is sharp: **if the concern is delivery mechanics, it belongs in Notify; if the concern is message logic or workflow, it belongs in Communications.** Communications never touches SMTP, Twilio, Resend, templates, or queues. Notify never reasons about preferences, cadence, or workflows.

The Pulse ↔ Operator split (data pipeline vs. meaning layer) is the architectural mirror — Communications is to Notify what Operator is to Pulse.
```

#### `repos/HoneyDrunk.Communications/boundaries.md`

```markdown
# HoneyDrunk.Communications — Boundaries

## What Communications Owns

- Business-event-to-message-intent mapping (declare what happened; Communications decides what to send)
- Recipient resolution — who should receive based on context, roles, relationships
- User preference enforcement — opt-in/out, channel preferences, quiet hours, suppression — **scoped per `(TenantId, recipient)`** so the same human user across two tenants has independent preference state
- Cadence policy — frequency and spacing rules per recipient to prevent notification fatigue — **scoped per `(TenantId, recipient, intent kind)`** so cross-tenant traffic does not poison cadence state for any single tenant
- Multi-step communication flows — welcome sequences, drip campaigns, escalation chains
- Decision audit log — every send-or-suppress decision recorded with reasoning, **stamped with `TenantId` from day one**

## Multi-Tenant Conformance

Communications is tenant-aware from day one. Tenancy primitives are owned by Kernel (the strongly-typed `TenantId` ULID record struct in `HoneyDrunk.Kernel.Abstractions.Identity`, the well-known `TenantId.Internal` sentinel, and the non-nullable `IGridContext.TenantId` property). Communications consumes these primitives without inventing parallel ones.

- Every store interface (`IPreferenceStore`, `ICadencePolicy`) takes `TenantId` as an explicit parameter — never a string, never read from an AsyncLocal.
- Internal Grid traffic — system messages between Nodes that have no commercial tenant — flows through Communications with `TenantId.Internal` and short-circuits past preference and cadence checks.
- Communications does NOT enforce per-tenant rate limits or emit billing events. Those are Notify (and Notify Cloud) concerns, enforced at Notify's intake gateway. Communications operates above Notify and inherits whatever rate-limit / billing posture Notify enforces.

## What Communications Does NOT Own

- **Template rendering** — Notify's `IEmailTemplateRenderer`/`ITemplateRenderer`
- **Provider adapters** — SMTP, Resend, Twilio (Notify provider packages)
- **Retry logic and dead-letter handling** — Notify
- **Queue-backed delivery and worker processing** — Notify
- **Delivery outcome tracking** — Notify
- **Channel routing mechanics** — Notify

## Boundary Decision Tests

- Is this **delivery mechanics** (rendering, sending, retrying, queueing)? → Notify.
- Is this **message logic or workflow** (when to send, who to send to, what suppression applies)? → Communications.
- Is this an **inference call** (LLM-generated content)? → HoneyDrunk.AI (Communications may call AI to draft content; AI is not in Communications' boundary).
- Is this **persistence** (preferences, flow state)? → HoneyDrunk.Data (Phase 3 — Communications calls Data via repository contracts).
```

#### `repos/HoneyDrunk.Communications/invariants.md`

```markdown
# HoneyDrunk.Communications — Invariants

ADR-0013 introduces no new Grid-level invariants. Communications operates within the existing Grid invariants (see `constitution/invariants.md`) and conforms to ADR-0026's Grid-wide multi-tenant primitives (the typed `TenantId`, the `Internal` sentinel, and the non-nullable `IGridContext.TenantId`). Repo-local restatement of the rules that most directly govern this Node:

1. **Communications is a runtime Node, not a delivery engine.** It calls `INotificationSender` (Notify) for every outbound message — never sends directly. (Reinforces invariant 2: runtime packages depend on Abstractions, never on other runtime packages at the same layer; Communications consumes only `HoneyDrunk.Notify.Abstractions`, never `HoneyDrunk.Notify` runtime.)
2. **No provider knowledge.** Communications has zero awareness of SMTP, Resend, Twilio, or any provider package. The boundary check on every PR: if a provider name appears in Communications source, the PR is rejected.
3. **Decision audit log is append-only AND tenant-stamped.** Every send-or-suppress decision is recorded with reasoning and `TenantId`; entries are never modified or deleted (Phase 2 in-memory store; Phase 3 persistent store via Data — both honor append-only semantics). `TenantId` is a first-class field on `DecisionLogEntry` from day one — adding it later means migrating a table that barely exists.
4. **Preference + cadence stores are scoped per `(TenantId, recipient)`, not global, not per-recipient-only.** All decisions made on behalf of a recipient flow through `IPreferenceStore` and `ICadencePolicy` keyed by the tenant-and-recipient pair. The same human user across two tenants has independent preference and cadence state. No cross-tenant leakage; no cross-recipient leakage within a tenant.
5. **Tenancy comes from `IGridContext.TenantId`, never from a string.** The orchestrator and any future tenant-aware logic read the typed `TenantId` from `IGridContext` (per ADR-0026 D2 — the property is non-nullable, with `TenantId.Internal` defaulted at Grid entry by `GridContextMiddleware`). Communications never accepts `string` tenant identifiers, never parses them itself, never threads them through AsyncLocal.
6. **Internal traffic short-circuits.** When `gridContext.TenantId.IsInternal` is true (the Internal sentinel from ADR-0026 D1), preference and cadence checks short-circuit gracefully — preferences return opted-in, cadence returns Allow — without consulting either store. The decision log still records the entry stamped with the Internal sentinel so the audit trail reflects every decision the orchestrator made. This matches the pattern ADR-0026 D4 / D6 require of `ITenantRateLimitPolicy` and `IBillingEventEmitter` implementations.

## Status

Phase 1 + Phase 2 of standup in progress. Phase 3 (persistent stores via Data, production deployment, Pulse telemetry) deferred to a follow-up initiative.
```

#### `repos/HoneyDrunk.Communications/active-work.md`

```markdown
# HoneyDrunk.Communications — Active Work

**Last Updated:** 2026-05-02
**Status:** Standup in progress

## Current

- Architecture-side standup (this PR — context folder, ADR index, initiative + roadmap, Notify boundary refresh)
- Repo creation queued (human-only chore — Wave 1 of `adr-0013-communications-bringup`)

## Next (Phase 1 — Wave 3 of bring-up)

- Scaffold solution + project skeletons + validate-pr workflow (Wave 2)
- Define five seed contracts in `HoneyDrunk.Communications.Abstractions` (Wave 3)
- Wire Kernel integration in runtime; add publish workflow (Wave 3)

## Next (Phase 2 — Wave 4 of bring-up)

- Implement welcome email flow: UserSignedUp → welcome → 2-day follow-up
- In-memory `IPreferenceStore`, `ICadencePolicy`, decision log
- Integrate `INotificationSender` for delivery delegation
- Unit + Canary test coverage

## Deferred (Phase 3 — separate initiative)

- Persistent preference + flow state via `HoneyDrunk.Data` repositories
- Production deployment alongside Notify on Container Apps (per ADR-0015)
- Pulse telemetry on communication decision metrics
```

#### `repos/HoneyDrunk.Communications/integration-points.md`

```markdown
# HoneyDrunk.Communications — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **HoneyDrunk.Kernel** | `IGridContext`, `HoneyDrunk.Kernel.Abstractions` | Context propagation through orchestration; correlation across decisions and downstream `INotificationSender` calls. Communications reads `gridContext.TenantId` (typed `HoneyDrunk.Kernel.Abstractions.Identity.TenantId`, non-nullable per ADR-0026 D2) and threads it into every `IPreferenceStore`, `ICadencePolicy`, and `DecisionLogEntry` call. When `gridContext.TenantId.IsInternal` is true (Internal sentinel from ADR-0026 D1), Communications short-circuits preference + cadence checks. |
| **HoneyDrunk.Notify** | `INotificationSender` (`HoneyDrunk.Notify.Abstractions`) | Delivery delegation — every outbound message Communications decides to send goes through this contract |

## IGridContext Tenancy Contract

Per ADR-0026, `IGridContext.TenantId` is a non-nullable `TenantId` (`HoneyDrunk.Kernel.Abstractions.Identity.TenantId`, ULID-backed `readonly record struct`). `GridContextMiddleware` is the single point that parses the `X-Tenant-Id` header and applies the `TenantId.Internal` default at Grid entry; consumers never write `?? TenantId.Internal` at the use site. Communications reads the typed value directly:

```csharp
var tenantId = gridContext.TenantId;
if (tenantId.IsInternal)
{
    // Short-circuit: internal Grid traffic skips preference + cadence enforcement.
    // Decision log still records the entry stamped with TenantId.Internal.
}
else
{
    var prefs = await preferenceStore.GetAsync(tenantId, recipient, ct);
    var verdict = await cadencePolicy.CheckAsync(tenantId, recipient, intent, ct);
    // ...
}
```

Communications does NOT define its own tenancy primitive, does NOT accept string tenant identifiers anywhere on its public contract surface, and does NOT use AsyncLocal for tenancy. All tenancy flows through `IGridContext` per ADR-0026 D3.

## Planned Upstream (Phase 3)

| Node | Contract | Usage |
|------|----------|-------|
| **HoneyDrunk.Data** | `IRepository<T>`, `IUnitOfWork` (`HoneyDrunk.Data.Abstractions`) | Persistent preference store, persistent flow state, persistent decision log |
| **HoneyDrunk.Pulse** | Telemetry sinks via Kernel's `ITelemetryActivityFactory` | Decision metrics — sent/suppressed counts, decision latency, cadence rejection rates |

## Downstream Touchpoints

| Node | Contract | Status |
|------|----------|--------|
| **HoneyDrunk.Flow** (planned) | `ICommunicationOrchestrator` | Future multi-step workflow engine may compose Communications as one workflow primitive |

## Boundary Notes

- Communications consumes `HoneyDrunk.Notify.Abstractions` only — **never** the runtime, **never** a provider package. This is invariant 2 enforced at the consumption boundary.
- Communications never writes secrets and never reads them directly. Provider credentials live in Notify's vault (`kv-hd-notify-{env}`), not in Communications' vault.
- Communications has its own per-Node Key Vault (`kv-hd-communications-{env}`) provisioned only when Phase 3 lands and Communications has runtime secrets to manage (e.g., persistent-store connection strings via Data). Until then, Communications has no Azure-native secret state.
```

### Part C — ADR index and ADR header

- `adrs/README.md` — confirm ADR-0013 row Status reads `Accepted`. If still `Proposed`, flip to `Accepted` and refresh the Impact text. Suggested Impact text:
  > Establishes HoneyDrunk.Communications (Ops) as the decision and orchestration layer above Notify. Phase 1 + 2 scoped; Phase 3 (persistence + production) deferred. No new invariants.
- `adrs/ADR-0013-communications-orchestration-layer.md` — confirm `**Status:** Accepted`. If still `Proposed`, flip.

### Part D — Initiative + roadmap trackers

#### `initiatives/active-initiatives.md`

Add a new **In Progress** entry below the existing "ADR-0010 Observation Layer & AI Routing — Phase 1" entry:

```markdown
### ADR-0013 Communications Bring-Up
**Status:** In Progress
**Scope:** Architecture, Communications (new)
**Initiative:** `adr-0013-communications-bringup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up HoneyDrunk.Communications as a new Ops-sector Node above Notify. Catalog registration shipped at ADR drafting. This initiative ships Phase 1 (5 seed contracts in Abstractions, Kernel integration) and Phase 2 (welcome email flow with in-memory stores, Notify integration). Phase 3 (persistence via Data, production deployment on Container Apps, Pulse telemetry) is deferred to a follow-up initiative once Phase 2 ships and ADR-0015 has landed at least one peer Container App.

**Tracking (Wave 1 — Architecture + repo creation):**
- [ ] Architecture#NN: Accept ADR-0013 — context folder, ADR index, trackers, Notify boundary refresh (this packet)
- [ ] Architecture#NN: Create HoneyDrunk.Communications GitHub repo (human-only chore)

**Tracking (Wave 2 — Scaffold):**
- [ ] Communications#1: Scaffold solution + project skeletons + pr-core.yml

**Tracking (Wave 3 — Phase 1 contracts):**
- [ ] Communications#NN: Define 5 seed contracts in Abstractions, wire Kernel integration, add publish workflow

**Tracking (Wave 4 — Phase 2 welcome flow):**
- [ ] Communications#NN: Welcome email flow with in-memory stores and Notify integration

**Next (Phase 3 — not yet scoped):**
- Persistent preference + flow state via HoneyDrunk.Data repositories
- Production deployment on Azure Container Apps (per ADR-0015) — `ca-hd-communications-{env}`
- Pulse telemetry on decision metrics (sent/suppressed counts, latency, cadence rejection rate)
- **Scope trigger:** Phase 1 + Phase 2 packets all merged + ADR-0015 has shipped Notify.Worker (proven Container App pattern) + a real product surface needs persistent communication state
```

#### `initiatives/roadmap.md`

Under **Q2 2026 (Apr–Jun)**, add a new bullet near the other ADR-driven items:

```markdown
- [ ] **ADR-0013 Communications Bring-Up — Phase 1 + 2** *(0/5 packets filed at scoping; 5 packets total — Architecture context + repo creation + scaffold + Phase 1 contracts + Phase 2 welcome flow)*
```

Under **Q3 2026 (Jul–Sep)**, add:

```markdown
- [ ] **ADR-0013 Communications Phase 3** — persistent preference + flow state via HoneyDrunk.Data, production deployment on Azure Container Apps (`ca-hd-communications-{env}`), Pulse telemetry on decision metrics. Gated on Phase 1 + 2 merge and ADR-0015 having shipped at least one peer Container App.
```

### Part E — Notify boundary refresh

#### `repos/HoneyDrunk.Notify/boundaries.md`

The current file states Notify "does not own user preferences." That remains true and accurate. Add a new sub-section under "What Notify Does NOT Own" pointing the reader at Communications for the orchestration concerns Notify intentionally does not handle. Suggested edit:

```markdown
## What Notify Does NOT Own
- **User preferences** — Applications manage notification preferences. From 2026-05 onward, the canonical home for preference enforcement, cadence rules, and message orchestration is **HoneyDrunk.Communications** (see `repos/HoneyDrunk.Communications/`). Applications should call `ICommunicationOrchestrator` instead of `INotificationSender` directly when they want preference + cadence enforcement.
- **Transport messaging** — Notify uses its own queue system, not Transport
- **Push notifications** — Not yet supported (future provider slot)
- **Multi-step flows** — Welcome sequences, drip campaigns, escalation chains are owned by Communications. Notify executes a single delivery action per `INotificationSender` call.
```

#### `repos/HoneyDrunk.Notify/integration-points.md`

Append a "Downstream Consumers" section (Notify's current file does not have one):

```markdown
## Downstream Consumers

| Node | Contract Used | Purpose |
|------|---------------|---------|
| **HoneyDrunk.Communications** | `INotificationSender` (`HoneyDrunk.Notify.Abstractions`) | Delivery delegation — Communications decides what/whom/when, calls `INotificationSender` for the send itself |
```

These are read-only awareness updates to Notify's repo context. They do **not** trigger any Notify code changes and Notify's CI does not run as a result.

## Acceptance Criteria

### Catalog audit (no edits expected)
- [ ] `catalogs/nodes.json` `honeydrunk-communications` entry verified intact
- [ ] `catalogs/relationships.json` `honeydrunk-communications` consumes `["honeydrunk-kernel", "honeydrunk-notify"]`; `honeydrunk-notify.consumed_by` includes `honeydrunk-communications`
- [ ] `catalogs/contracts.json` `honeydrunk-communications` lists all five interfaces
- [ ] `catalogs/grid-health.json` `honeydrunk-communications` entry verified
- [ ] `catalogs/modules.json` `communications-abstractions` and `communications-runtime` entries verified
- [ ] `constitution/sector-interaction-map.md` Ops section diagram and "Communications ↔ Notify split" paragraph verified
- [ ] `constitution/feature-flow-catalog.md` Flow 2 rename and Flow 2b addition verified
- [ ] Audit outcome (clean vs. drift fixed) documented in PR description

### Repo context folder (new)
- [ ] `repos/HoneyDrunk.Communications/overview.md` created
- [ ] `repos/HoneyDrunk.Communications/boundaries.md` created (includes Multi-Tenant Conformance section per ADR-0026)
- [ ] `repos/HoneyDrunk.Communications/invariants.md` created (includes the tenant-scoped store, IGridContext-as-tenancy-source, and Internal-short-circuit rules)
- [ ] `repos/HoneyDrunk.Communications/active-work.md` created
- [ ] `repos/HoneyDrunk.Communications/integration-points.md` created (includes the IGridContext Tenancy Contract section with code example)
- [ ] None of the five files contain ADR ID strings in narrative prose body (ADR IDs allowed in metadata/tables, in invariants restatement of ADR-0026 D-numbers, and in the IGridContext Tenancy Contract section where ADR cross-references are load-bearing) — per user preference, narrative prose stays free of bare ADR IDs where the decision text alone would do

### ADR index
- [ ] `adrs/README.md` ADR-0013 row Status reads `Accepted` (verify; flip if still `Proposed`)
- [ ] `adrs/ADR-0013-communications-orchestration-layer.md` header `**Status:** Accepted` (verify; flip if still `Proposed`)
- [ ] ADR-0013 row Impact text reflects "Phase 1+2 scoped; Phase 3 deferred"

### Trackers
- [ ] `initiatives/active-initiatives.md` has new "ADR-0013 Communications Bring-Up" entry with Wave 1–4 tracking and Next (Phase 3) section
- [ ] `initiatives/roadmap.md` Q2 2026 has Phase 1+2 bullet
- [ ] `initiatives/roadmap.md` Q3 2026 has Phase 3 bullet

### Notify boundary refresh
- [ ] `repos/HoneyDrunk.Notify/boundaries.md` "What Notify Does NOT Own" section refreshed to point at Communications and to add "Multi-step flows" line
- [ ] `repos/HoneyDrunk.Notify/integration-points.md` has new "Downstream Consumers" section listing Communications

### General
- [ ] No new ADR file created (ADR-0013 is the standup ADR for Communications per the "New-Node scaffolding needs its own ADR" convention; do not draft a separate scaffolding ADR)
- [ ] No `constitution/invariants.md` edits (ADR-0013 introduces no new invariants)
- [ ] PR body summarizes catalog audit outcome and lists all touched files

## Affected Packages
None. Docs and JSON only.

## NuGet Dependencies
None. No .NET changes in this packet.

## Boundary Check
- [x] Catalog verification, repo context folder creation, ADR index, trackers, and Notify-context refresh all live in `HoneyDrunk.Architecture` — correct repo per routing rules
- [x] No code changes to any other repo
- [x] Notify-context edits are read-only awareness updates that do not trigger Notify CI
- [x] Communications sector assignment (Ops) matches the ADR's explicit decision

## Human Prerequisites

None. This packet is a pure Architecture-repo edit and does not require any portal or GitHub org actions. The separate `02-architecture-create-communications-repo.md` chore handles the human-only repo-creation step.

## Dependencies

None. This is the Wave-1 foundation packet.

## Downstream Unblocks

- `02-architecture-create-communications-repo.md` — human-only repo creation can proceed in parallel
- `03-communications-scaffold.md` — Communications scaffold consumes the `repos/HoneyDrunk.Communications/` context folder produced here
- `04-communications-phase1-contracts.md` and `05-communications-phase2-welcome-flow.md` — both rely on the boundaries/invariants/integration-points docs produced here as scope anchors for the review agent

## Referenced ADR Decisions

**ADR-0013 (Communications Orchestration Layer — HoneyDrunk.Communications):**
- **§Decision / New Node:** HoneyDrunk.Communications, Ops sector, sits above Notify. Decision and orchestration layer that delegates all delivery mechanics to Notify.
- **§Communications owns:** business-event-to-message-intent mapping, recipient resolution, user preference enforcement, cadence policy, multi-step flows, decision audit log.
- **§Communications does NOT own:** template rendering, provider adapters, retry logic, queue-backed delivery, delivery outcome tracking, channel routing mechanics — all those stay in Notify.
- **§Boundary rule:** "If the concern is delivery mechanics, it belongs in Notify. If the concern is message logic or workflow, it belongs in Communications."
- **§Contracts:** `ICommunicationOrchestrator`, `IMessageIntent`, `IRecipientResolver`, `IPreferenceStore`, `ICadencePolicy`. Subject to refinement during Phase 1 implementation.
- **§Dependency Graph:** consumes Kernel + Notify; consumed_by_planned: Flow.
- **§Phase Plan:** Phase 1 — contracts and scaffold. Phase 2 — welcome sequence (first useful increment). Phase 3 — persistence and production.

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **§D1:** `TenantId` (`HoneyDrunk.Kernel.Abstractions.Identity.TenantId`, ULID-backed `readonly record struct`) is the canonical tenant identifier Grid-wide. Adds a `TenantId.Internal` static sentinel and `IsInternal` predicate. Communications consumes this primitive without inventing a parallel one.
- **§D2:** `IGridContext.TenantId` is non-nullable `TenantId`. `GridContextMiddleware` parses the `X-Tenant-Id` header at Grid entry and applies `TenantId.Internal` as the default when absent. Communications reads the typed value directly — no `string` parsing, no null-handling at the use site.
- **§D3:** Tenancy flows via `IGridContext`, never via AsyncLocal. Communications honors this — no `TenantContext.Current` or static accessor.
- **§D7 (boundary invariant):** Tenant resolution, rate-limit enforcement, billing-event emission, and tenant-scoped secret resolution live in gateway-layer middleware and post-dispatch tails, never in core dispatch paths. Communications operates above Notify; rate-limit and billing are enforced at Notify's intake gateway, not in Communications. Communications' own concerns (preference enforcement, cadence) ARE tenant-aware and live in the orchestrator's evaluation path — which is the analog of "intake" for Communications.
- **§Internal short-circuit pattern:** ADR-0026 D4 / D6 require `ITenantRateLimitPolicy` and `IBillingEventEmitter` implementations to short-circuit on `tenantId.IsInternal`. Communications applies the same pattern to its own preference + cadence stores: Internal traffic skips both checks. The decision log still records every entry so the audit trail is complete.

**ADR-0008 (Issue packet conventions):**
- **§D10:** Generated artifacts under `/generated/issue-packets/active/{initiative-slug}/` co-located with dispatch plan and handoffs. Archived as a single folder move when Done.

## Referenced Invariants

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root.
> *(Verify after this PR: Communications → Kernel and Communications → Notify are both edges to existing roots/leaves. No cycle introduced. The relationships graph already encodes this.)*

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.
> *(Communications gets its own repo, scaffolded by packet 03 after the human chore in packet 02 creates it.)*

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools.
> *(This packet is filed as an issue against `HoneyDrunkStudios/HoneyDrunk.Architecture`. The four downstream packets are filed against the appropriate target repos when their waves are ready.)*

> **Invariant 25:** Dispatch plans are initiative narratives, not live state. The org Project board is the source of truth for in-flight work.
> *(The initiative entry in `active-initiatives.md` and roadmap bullets created here are narratives; the Hive board is the live tracker.)*

## Constraints

- **No ADR IDs in narrative body of new context files.** Per user preference, ADR IDs stay in frontmatter/metadata/tables. Body prose uses the decision text, not its ID. The `overview.md` / `boundaries.md` / `invariants.md` / `active-work.md` / `integration-points.md` files must not carry "ADR-0013" inside paragraphs. (Frontmatter, version-status tables, and the active-work tracking lines that point at this initiative are fine — those are metadata or tracking, not narrative.)
- **Catalog audit is read-only by default.** Only edit catalog files if the audit finds drift from the ADR's `Catalog Changes` checklist. If everything is intact, the audit checkboxes get checked without touching any catalog file.
- **No new ADR.** ADR-0013 itself is the standup ADR. Do not draft a separate `ADR-NNNN-stand-up-honeydrunk-communications`.
- **No invariant additions.** The ADR explicitly does not introduce new invariants. Do not invent any.
- **Notify-context updates are minimal.** The two Notify edits acknowledge Communications as a downstream consumer. Do not refactor Notify's docs beyond what is specified.
- **Verify ADR status before flipping.** The user reports ADR-0013 is Accepted. Re-confirm `adrs/README.md` and `ADR-0013-...md` reflect that. If they already do, do not redundant-flip.
- **DAG discipline (invariant 4):** the new Communications edges are to Kernel (root) and Notify (existing leaf). No cycle is structurally possible. Confirm anyway by walking the graph after edits.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `catalog`, `adr-0013`, `adr-0026`, `wave-1`

## Agent Handoff

**Objective:** Land the Architecture-side standup work for ADR-0013 in one PR — context folder, ADR index status, initiative + roadmap trackers, Notify boundary refresh — so subsequent packets in this initiative have complete Architecture context to anchor against.

**Target:** HoneyDrunk.Architecture, branch from `main`

**Context:**
- Goal: Make ADR-0013 a fully accepted, fully tracked decision with downstream packets unblocked, and ensure the new Communications context folder reflects ADR-0026 multi-tenant conformance from the very first commit
- Feature: ADR-0013 Communications Orchestration Layer
- ADRs: ADR-0013 (primary), ADR-0026 (cross-cutting tenancy requirement applied to the new context folder's boundaries / invariants / integration-points), ADR-0008 (initiative/packet conventions), ADR-0005 (referenced by future Phase 3 for vault and config provisioning), ADR-0015 (referenced by future Phase 3 for Container Apps deployment)

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. Verify after edits — Communications edges are Kernel (root) and Notify (existing leaf), so no cycle is possible. Confirm anyway.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. Communications gets its own repo (created by packet 02).

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools.

> **Invariant 25:** Dispatch plans are initiative narratives, not live state. The org Project board is the source of truth for in-flight work.

- No ADR IDs in narrative body of new `repos/HoneyDrunk.Communications/*.md` files (user preference)
- Catalog edits only if drift detected
- No new ADR draft
- No invariant additions
- Notify-context updates minimal — just acknowledge the downstream consumer relationship

**Key Files:**
- `repos/HoneyDrunk.Communications/overview.md` (new)
- `repos/HoneyDrunk.Communications/boundaries.md` (new)
- `repos/HoneyDrunk.Communications/invariants.md` (new)
- `repos/HoneyDrunk.Communications/active-work.md` (new)
- `repos/HoneyDrunk.Communications/integration-points.md` (new)
- `repos/HoneyDrunk.Notify/boundaries.md` (refresh)
- `repos/HoneyDrunk.Notify/integration-points.md` (append Downstream Consumers section)
- `adrs/README.md` (verify ADR-0013 row; flip status / refresh Impact if needed)
- `adrs/ADR-0013-communications-orchestration-layer.md` (verify `**Status:** Accepted`; flip if needed)
- `initiatives/active-initiatives.md` (append new initiative entry)
- `initiatives/roadmap.md` (Q2 + Q3 2026 bullets)
- `catalogs/nodes.json` (audit only)
- `catalogs/relationships.json` (audit only)
- `catalogs/contracts.json` (audit only)
- `catalogs/grid-health.json` (audit only)
- `catalogs/modules.json` (audit only)
- `constitution/sector-interaction-map.md` (audit only)
- `constitution/feature-flow-catalog.md` (audit only)

**Contracts:** None directly created in this packet — the five Communications contracts are catalog-registered (already done at ADR drafting) and will be implemented in packet 04.
