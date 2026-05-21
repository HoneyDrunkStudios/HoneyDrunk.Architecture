# ADR-0030: Grid-Wide Security and Action Audit is a First-Class Concern Homed in a Dedicated HoneyDrunk.Audit Node

**Status:** Accepted
**Date:** 2026-05-16
**Deciders:** HoneyDrunk Studios
**Sector:** Core

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Add `honeydrunk-audit` Node entry to `catalogs/nodes.json` (Core sector, `signal: "seed"`, contract surface per D3)
- [ ] Add `honeydrunk-audit` entries and the new edges to `catalogs/relationships.json` — `honeydrunk-audit` → `honeydrunk-data` (consumes), `honeydrunk-auth` → `honeydrunk-audit` (consumes, first emitter), `honeydrunk-operator` → `honeydrunk-audit` (consumes, reconciled per 2a)
- [ ] Add `IAuditLog`, `IAuditQuery`, and `AuditEntry` entries to `catalogs/contracts.json` under `honeydrunk-audit`; mark the `honeydrunk-operator` entries for `IAuditLog`/`AuditEntry` as relocated to `honeydrunk-audit`
- [ ] Add the `honeydrunk-audit` row to `catalogs/grid-health.json` reflecting the stood-up contract surface and the contract-shape canary expectation
- [ ] Add `honeydrunk-audit` to `catalogs/modules.json` for the two stand-up package families (D2)
- [ ] Update `constitution/sectors.md` Core-sector table to add the **Audit** row
- [ ] Add the audit-emission boundary invariant to `constitution/invariants.md` (proposed text in Consequences; scope agent assigns the final number at acceptance)
- [ ] Append the additive amendment note to `adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` recording the `IAuditLog`/`AuditEntry` relocation and Operator's reclassification to consumer-not-owner (tracked under this ADR; the amendment is additive only and does not change ADR-0018's Status or decision content)
- [ ] The HoneyDrunk.Audit Node scaffold is governed by the separate **standup ADR (ADR-0031)** — do not bundle scaffold detail into this ADR's acceptance
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

The Grid has no durable, attributable system of record for "actor X attempted or executed action Y." Today:

- **Pulse is OTel-only and explicitly disclaims being a system of record.** It is an observation layer (ADR-0010) — sampled, retention-bounded, optimized for aggregate signal, not for per-event forensic recall. Asking Pulse "did this principal attempt to delete this resource at this time, and was it denied" is asking the wrong substrate.
- **Auth deliberately keeps subject, tenant, and resource identifiers out of traces.** Auth's invariant is that telemetry stays observational and identity stays out of traces; the "who" of an authorization event is routed to lossy Loki logs, which are retention-bounded and not query-addressable as an audit record.
- **No Node owns Grid-wide security and action audit.** Login attempts, authorization denials, and privileged-action execution are emitted nowhere durable and attributable. Each Node that has wanted this has either skipped it or invented an ad-hoc local log.

This is a real boundary gap, not a missing feature on an existing Node. Login attempts, authz denials, and privileged actions are exactly the events a security review, an incident reconstruction, or a future tenant-facing forensics surface needs — and they currently evaporate.

`HoneyDrunk.Operator` (ADR-0018) carries an `IAuditLog`/`AuditEntry` pair, but that pair was scoped to Operator auditing its **own AI-runtime decisions** (gate outcomes, breaker transitions, cost events, approval decisions) — never as a Grid-wide system of record. Operator is the wrong long-term home for Grid-wide audit for a structural reason developed below (D2). The decision to address the gap with a dedicated `HoneyDrunk.Audit` Node — built now, before production, as a permanent-boundary investment — was reached over a prior analysis pass and is treated as settled here. The user (solo developer) has made the node-vs-hybrid call; this ADR records it, the boundary, the contract reconciliation, and the scope discipline that keeps the investment from becoming gold-plating.

This ADR is the **capability/decision ADR**. It records what Grid-wide audit is, where it lives, why not Operator and why not Kernel, how the Operator contracts are reconciled, and the explicit deferral triggers that bound Phase 1. The Node scaffold itself — repo creation, package layout, CI, catalog registration, relationship edges — is governed by the separate standup ADR (ADR-0031) and is **not** detailed here.

## Decision

### D1. Grid-wide security and action audit is a first-class Grid concern

Durable, attributable recording of "actor X attempted or executed action Y" — login attempts, authorization grants and denials, and privileged-action execution — is a first-class Grid concern with its own substrate. It is **distinct from observability**. Observability (Pulse) answers "is the system healthy and what is it doing in aggregate." Audit answers "who did what, when, against what, and was it allowed" — durably, attributably, and queryable after the fact. The two are not the same channel and conflating them was the latent bug.

### D2. The substrate is a new dedicated HoneyDrunk.Audit Node — not Operator, not Kernel

Grid-wide audit is homed in a **new dedicated `HoneyDrunk.Audit` Node** in the Core sector. It is the single Node that owns the Grid's durable, attributable security, action, and data-change record.

**Why not Operator (ADR-0018):**

Operator is a *control plane that decides and acts* — it owns approval gates, circuit breakers, cost guards, safety filters, and kill authority over other AI-sector Nodes. ADR-0018's anchoring principle (repo-invariant 5) is "the system that decides what to do must never be the system that decides whether it is allowed." That principle has a direct sibling that this ADR makes explicit: **the recorder must not be the actor.** A control plane that can halt, gate, and kill must not also be the authoritative ledger that records whether it was right to do so — that co-locates the actor and the witness in one trust boundary. ADR-0018's `IAuditLog` was scoped, by its own text (D9), to Operator auditing its own AI-runtime decisions only; it was never a Grid-wide system of record, and stretching it into one would silently expand Operator's trust boundary to cover Auth's security events, every privileged action in the Grid, and a future tenant-facing forensics surface. That is the wrong home.

**Why not Kernel:**

Two reasons, both structural:

1. **Audit is a domain concern, not a Kernel primitive.** Kernel owns context propagation, lifecycle, configuration, and identity primitives — the cross-cutting machinery every Node needs to *be a Node*. A durable, query-addressable, retention-policied security ledger is a domain substrate with its own storage, its own retention class, and its own forensic read surface. It is not in the same category as `IGridContext`. Kernel is the only cross-cutting precedent in the Grid for a contract that lives outside its owning Node's repo, and that precedent is explicitly rejected here because audit is not a Kernel-class primitive.
2. **A Kernel-hosted, Data-backed audit implementation introduces a cycle.** Kernel is at the root of the dependency DAG (invariant 4) and is consumed by Data. An audit store backed by `HoneyDrunk.Data` (D4) cannot live in Kernel without Kernel transitively depending on Data, which depends on Kernel. The DAG forbids it.

**Why a dedicated repo is the convention-consistent answer:**

Every `*.Abstractions` package in the Grid is co-located inside its owning Node's repo (verified across the stand-up ADRs — AI, Capabilities, Operator, Communications, Notify Cloud all follow this). There is no free-floating contract slot, and Kernel — the only cross-cutting exception — is rejected above. Therefore the convention-consistent home for a generalized, Grid-wide audit contract and its Data-backed implementation is a dedicated `HoneyDrunk.Audit` repo that owns its own `Abstractions` package. This is not a new pattern; it is the existing pattern applied to a concern that previously had no Node.

### D3. Exposed contracts

The Audit Node's public boundary at stand-up is three primary surfaces — **two interfaces and one canonical record envelope** — plus small supporting value types/enums needed to keep the envelope explicit:

| Contract | Kind | Purpose |
|---|---|---|
| `IAuditLog` | interface | Append-only write of an `AuditEntry`. No update method. No delete method. Append-only is enforced **at the interface surface**, not only at the storage layer. |
| `IAuditQuery` | interface | Read and forensic-retrieval surface over the durable audit record — time-ordered and filtered reads for incident reconstruction and (later) tenant-facing forensics. New contract introduced by this ADR; has no precedent on Operator. |
| `AuditEntry` | record | Canonical append-only audit record envelope — category, event name/action, actor, target/resource, outcome, correlation id, tenant, metadata, and optional data-change details. Generalized Grid-wide from the Operator-scoped shape. Drops the `I` prefix per the grid-wide naming rule (records drop `I`, interfaces keep it). |

`AuditEntry` supports two first-class audit families from v0.1.0:

1. **Activity/security/system audit** — what an actor attempted or did in the system: login attempts, authorization grants/denials, purchases, workflow starts, agent/operator decisions, privileged actions, integration callbacks.
2. **Data-change audit** — what durable record changed: entity created/updated/deleted, entity/resource type, entity/resource id, changed fields, and optional before/after values.

The supporting contract shape includes category/outcome/target/change metadata so data-change audit is not bolted on later as an unstructured string. Sensitive before/after values must be redacted by policy before append; the Audit substrate stores the record it is given and must not become a secret/PII leak path.

`IAuditLog` and `AuditEntry` are **generalizations of** the Operator-scoped contracts of the same names — promoted out of `HoneyDrunk.Operator.Abstractions` and into `HoneyDrunk.Audit.Abstractions` (D5). `IAuditQuery` is net-new: Operator's stand-up never carried a read/forensics contract because Operator's audit was write-one-shape self-recording.

### D4. Storage is Data-backed and append-only-by-interface

The Audit Node's default store consumes `HoneyDrunk.Data`'s `IRepository` and `IUnitOfWork` — the same transactional surface Operator's audit log already sat on (ADR-0018 D9). The append-only guarantee is enforced **at the interface surface**: `IAuditLog` exposes no update and no delete method. Consumers that need retention or archival work off `IAuditQuery`, never by mutating entries.

Audit data carries an **audit-class retention policy distinct from Pulse/observability retention**. Observability retention is short and sampling-tolerant; audit retention is long, lossless, and policy-governed (incident, security-review, and compliance horizons). The two retention regimes are not shared and not interchangeable. The specific retention duration and archival mechanism are a configuration concern sourced per the Grid's existing App-Configuration-via-Vault pattern (ADR-0005); the stand-up commitment is the *separation* of the retention class, not the numeric value.

### D5. Contract reconciliation — `IAuditLog`/`AuditEntry` are promoted; Operator becomes a consumer

This is the user's settled "2a" reconciliation:

- `IAuditLog` and `AuditEntry` are **promoted out of `HoneyDrunk.Operator.Abstractions`** and into the new `HoneyDrunk.Audit.Abstractions` package, generalized from Operator-runtime-scoped to Grid-wide.
- A new `IAuditQuery` read/forensics contract is added in `HoneyDrunk.Audit.Abstractions`.
- **Operator is reclassified from owner to consumer/emitter.** Operator continues to record its own AI-runtime decisions (gate outcomes, breaker transitions, cost events, approval decisions) — but it does so by emitting `AuditEntry` against the generalized `IAuditLog` it now *consumes* from `HoneyDrunk.Audit.Abstractions`, not against a contract it owns. ADR-0018 D9's commitment that consumers "work off the read surface, not by mutating entries" is satisfied by `IAuditQuery`.
- ADR-0018 receives an **additive amendment note** (tracked in the follow-up checklist and recorded in ADR-0031) recording the relocation and the consumer reclassification. The amendment is additive only; ADR-0018's Status and decision content are not rewritten.

This keeps the trust boundary correct: Operator decides and acts; Audit records. Operator is one emitter among several, not the ledger.

### D6. First emitter is HoneyDrunk.Auth, additively

The first real emitter into the Audit substrate is `HoneyDrunk.Auth`, recording durable attributable security events — login attempts, authorization grants, authorization denials. This is **additive to Auth's existing OTel traces** and does **not** change Auth's rule that telemetry stays observational and identity stays out of traces. The audit path is a *separate durable channel*: Auth continues to emit identity-free observational telemetry to Pulse exactly as before, and additionally emits attributable `AuditEntry` records to the Audit substrate. The two channels do not merge; the Auth-traces invariant is untouched.

Data-change emitters are additive and follow the same durable channel: persistence/domain code records create/update/delete events through `IAuditLog` with category `DataChange`, target entity identity, and redacted changed-field details. Automatic Data-layer interception is allowed only when the redaction policy is explicit; business-intent events still belong in application/domain code so the record explains *why* the mutation occurred, not only that a row changed.

### D7. Telemetry emission — Pulse consumes, Audit does not depend

The Audit Node emits its own operational telemetry (write latency, query latency, append throughput) via Kernel's `ITelemetryActivityFactory`; Pulse consumes it downstream. **Audit has no runtime dependency on Pulse.** The direction is one-way by contract: Audit emits operational telemetry, Pulse observes. Same rule as ADR-0016 D7 (AI), ADR-0017 D7 (Capabilities), ADR-0018 D7 (Operator). Audit's *records* are not telemetry and do not flow to Pulse; the durable audit channel and the observability channel stay separate (D1).

### D8. Phased integrity — the scope-discipline control

The **investment is the Node boundary and the contract**, not gold-plating behind it. Because the boundary exists from Phase 1, every deferred capability can be added later without an extraction or a breaking move — the contract is already the seam.

**Phase 1 builds (this initiative):**

- The `HoneyDrunk.Audit` Node and repo (governed by ADR-0031).
- `HoneyDrunk.Audit.Abstractions` (`IAuditLog`, `IAuditQuery`, `AuditEntry`).
- The Data-backed append-only store (D4).
- The Node's own managed identity.
- `HoneyDrunk.Auth` wired as the first emitter (D6).
- `HoneyDrunk.Operator` reconciled as a consumer/emitter (D5).

**Explicitly deferred behind the now-existing boundary — each gated on a stated trigger, no extraction required:**

- **(a) Hash-chain / WORM tamper-evidence.** *Trigger:* a compliance, customer-contract, or incident-class requirement that the audit record be provably tamper-evident (not merely append-only). Until that trigger fires, Phase-1 integrity is **append-only-by-interface only**.
- **(b) The deployable tenant-facing forensics read Service.** *Trigger:* a concrete tenant-facing requirement to expose forensic audit reads externally. When triggered, it is built as an ADR-0015-hosted deployable Service over the already-existing `IAuditQuery` surface — no contract change, no extraction.

### D9. Honest limitation statement — Phase 1 is append-only, NOT tamper-evident

Stated plainly so it is not oversold: **Phase-1 audit integrity is append-only-by-interface. It is not tamper-evident.** The `IAuditLog` surface exposes no update or delete method, and consumers cannot mutate entries through the contract — but a sufficiently privileged actor with direct store access is not cryptographically prevented from altering history at the storage layer. Hash-chaining / WORM (D8a) is the control that would make the record tamper-*evident*, and it is deliberately deferred behind the boundary until a stated trigger fires. Phase 1 closes the "emitted nowhere durable and attributable" gap; it does not claim to close the "provably unaltered" gap. Do not market or document Phase 1 as tamper-evident.

### D10. Downstream coupling rule

Emitters and readers (Auth, Operator first; any Node recording a security, privileged-action, activity, system, integration, or data-change event later) compile **only** against `HoneyDrunk.Audit.Abstractions`. They do not take a runtime dependency on the Audit runtime package or its Data-backed store in production composition. Composition — which store backend is active, which retention policy is loaded — is a host-time concern. This is the same abstraction/runtime split applied for AI, Capabilities, Operator, Vault, and Transport, restated here because it is the rule that lets Auth and Operator proceed against `Abstractions` alone.

## Consequences

### Unblocks

- **The Grid gains a durable, attributable security, action, and data-change record** — login attempts, authz denials, privileged actions, and record create/update/delete events are recorded somewhere addressable for the first time.
- **HoneyDrunk.Auth** can emit durable attributable security events without violating its identity-out-of-traces invariant (separate durable channel, D6).
- **HoneyDrunk.Operator** keeps recording its AI-runtime decisions, now against a generalized contract it consumes — and sheds the structural problem of being both the actor and the ledger (D2, D5).
- **A future tenant-facing forensics Service** has a contract (`IAuditQuery`) to build against the moment its trigger fires — no extraction, no contract migration (D8b).

### Contract reconciliation obligations

`IAuditLog` and `AuditEntry` move out of `HoneyDrunk.Operator.Abstractions` into `HoneyDrunk.Audit.Abstractions`. `catalogs/contracts.json` must reflect the relocation; ADR-0018 receives an additive amendment note. Operator's downstream consumers that referenced Operator's audit pair re-target the Audit package. These reconciliations are tracked in the follow-up checklist and detailed in ADR-0031.

### New invariant (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Durable, attributable security, action, and data-change events (login attempts, authorization denials, privileged actions, record create/update/delete events) are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry.** Auditable events routed only to sampled/retention-bounded observability (Pulse/Loki) are a boundary violation. Data-change details that include sensitive fields must be redacted before append. The audit channel and the telemetry channel are never merged. See D1, D3, D6.

### Negative

- **A new Node is more surface than reusing Operator's existing pair.** The trade is a correct trust boundary (recorder ≠ actor) and a convention-consistent home, against one more repo, one more CI pipeline, and one more catalog row to maintain. The cost is accepted as a deliberate permanent-boundary investment; the alternative (Operator-owned Grid audit) silently expands Operator's trust boundary, which is the more expensive long-term failure.
- **Phase 1 is append-only, not tamper-evident (D9).** A privileged actor with direct store access is not cryptographically prevented from altering history. This is a stated, accepted Phase-1 limitation with a defined deferral trigger (D8a), not an oversight. It must not be marketed or documented as tamper-evident.
- **The deferred forensics Service means there is no external read path at Phase 1.** Incident reconstruction at Phase 1 is internal (`IAuditQuery` from inside the Grid). External/tenant-facing forensic reads wait for the D8b trigger. Accepted: the gap being closed now is "nowhere durable," not "no external surface."
- **Promoting `IAuditLog`/`AuditEntry` out of Operator is a contract relocation that touches Operator's package surface.** Mitigation: Operator becomes a consumer of the same-named generalized contracts; the relocation is additive at the call site (Operator emits instead of owning) and ADR-0018 is amended additively, not rewritten.

### Catalog obligations

`catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json`, `catalogs/grid-health.json`, and `catalogs/modules.json` do not currently carry a `honeydrunk-audit` Node or its edges. `constitution/sectors.md` does not carry an Audit row. These reconciliations are tracked in the follow-up checklist at the top of this ADR and detailed in ADR-0031 (the standup ADR). This ADR does not modify catalogs.

## Alternatives Considered

### Hybrid — put generalized audit contracts in HoneyDrunk.Kernel

Rejected. Two structural failures. (1) Audit is a domain substrate with its own storage, retention class, and forensic read surface — not a Kernel-class cross-cutting primitive like `IGridContext`. Kernel is the Grid's *only* precedent for an out-of-Node contract, and that precedent is reserved for context/lifecycle/identity primitives, not domain ledgers. (2) The default store is Data-backed (D4); Kernel is at the DAG root and is consumed by Data, so a Kernel-hosted Data-backed implementation introduces a Kernel → Data → Kernel cycle, which invariant 4 forbids. A Kernel-Abstractions-only split that pushed the impl elsewhere would still be the wrong categorization and would have no convention-consistent home for the impl anyway (every impl is co-located with its Node's Abstractions; there is no free-floating slot).

### Generalize the audit contracts in place inside HoneyDrunk.Operator

Rejected. This co-locates the actor and the witness. Operator is a control plane with kill authority; making it the authoritative Grid-wide ledger means the Node that can halt, gate, and trip breakers is also the Node that records whether it was right to. ADR-0018's own anchoring principle ("the system that decides what to do must never be the system that decides whether it is allowed") has the direct sibling "the recorder must not be the actor." ADR-0018 D9 explicitly scoped Operator's audit to its own AI-runtime decisions; stretching it Grid-wide silently expands Operator's trust boundary to cover Auth's security events and every privileged action in the Grid. The contracts are generalized *out* of Operator, not *in place within* it.

### Do nothing — accept that durable attributable audit is emitted nowhere

Rejected. This is the current state and it is the gap. Login attempts, authz denials, and privileged actions evaporate into sampled telemetry and lossy Loki logs. A security review or incident reconstruction has nothing addressable to work from, and a future tenant-facing forensics surface has no substrate to build on. The cost of doing nothing is paid at the worst possible time (during an incident). Building the boundary before production, while it is cheap, is the deliberate investment.

### Dedicated HoneyDrunk.Audit Node — CHOSEN

Chosen. It is the only option that (a) keeps the trust boundary correct (recorder ≠ actor), (b) is convention-consistent (a Node owning its own `Abstractions`, the established Grid pattern; Kernel is the only exception and is correctly rejected), (c) avoids the DAG cycle a Data-backed Kernel impl would create, and (d) creates the boundary once, before production, so every deferred capability (tamper-evidence, the forensics Service) is an additive build behind an existing seam rather than a future extraction. The accepted costs (one more repo/CI/catalog row; Phase 1 is append-only not tamper-evident) are bounded and stated; the scope-discipline control (D8) keeps the investment to the boundary plus contract, not gold-plating.

### Build the tamper-evident, tenant-facing forensics platform now

Rejected as scope creep. The investment is the *boundary and the contract*, not a gold-plated platform. Hash-chain/WORM tamper-evidence and the deployable tenant-facing forensics Service are real future needs, but each has a concrete trigger (D8) and, because the boundary exists from Phase 1, each can be added later with no extraction and no contract change. Building them speculatively now spends effort on capabilities with no current trigger and risks the over-engineering failure this scope discipline exists to prevent.
