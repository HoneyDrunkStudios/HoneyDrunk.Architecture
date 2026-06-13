# ADR-0031: Stand Up the HoneyDrunk.Audit Node — Grid-Wide Durable Security and Action Record

**Status:** Accepted
**Date:** 2026-05-16
**Deciders:** HoneyDrunk Studios
**Sector:** Core

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up work items (do not accept and leave the catalogs stale):

- [x] Create the `HoneyDrunk.Audit` GitHub repo as **public** (Grid default; no revenue/compliance/experiment carve-out applies — audit substrate is a reusable Core primitive)
- [x] Add `honeydrunk-audit` Node entry to `catalogs/nodes.json` (Core sector, `signal: "seed"`)
- [x] Add `honeydrunk-audit` entries and the new edges to `catalogs/relationships.json`: `honeydrunk-audit` → `honeydrunk-data` (consumes; `IRepository`, `IUnitOfWork`), `honeydrunk-audit` → `honeydrunk-kernel` (consumes; `IGridContext`, lifecycle, telemetry), `honeydrunk-auth` → `honeydrunk-audit` (consumes; `IAuditLog`), `honeydrunk-operator` → `honeydrunk-audit` (consumes; `IAuditLog`, `IAuditQuery` — reconciled per ADR-0030 D5), and a `consumed_by_planned` list on `honeydrunk-audit` seeded with Auth and Operator
- [x] Add `IAuditLog`, `IAuditQuery`, and `AuditEntry` entries to `catalogs/contracts.json` under `honeydrunk-audit`; mark the existing `honeydrunk-operator` `IAuditLog`/`AuditEntry` entries as relocated to `honeydrunk-audit`
- [x] Add the `honeydrunk-audit` row to `catalogs/grid-health.json` reflecting the stood-up contract surface and the contract-shape canary expectation
- [x] Add `honeydrunk-audit` entries to `catalogs/modules.json` for `HoneyDrunk.Audit.Abstractions` and `HoneyDrunk.Audit.Data`
- [x] Update `constitution/sectors.md` Core-sector table to add the **Audit** row (`Signal: Seed`, `Responsibility: Grid-wide durable, attributable security and action record`)
- [x] Append the additive amendment note to `adrs/ADR-0018-stand-up-honeydrunk-operator-node.md` per ADR-0030 D5 (additive only; do not change ADR-0018 Status or decision content)
- [x] Wire the contract-shape canary into Actions for the three frozen contracts (`IAuditLog`, `IAuditQuery`, `AuditEntry`)
- [x] Create `repos/HoneyDrunk.Audit/` context folder in the Architecture repo (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) — matching the template used by `repos/HoneyDrunk.Operator/`
- [x] File the HoneyDrunk.Audit scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline via HoneyDrunk.Actions shared workflows, Data-backed append-only store, the Node's own managed identity, in-memory `IAuditLog`/`IAuditQuery` test fixture)
- [x] Reference ADR-0030 (Grid-Wide Audit Substrate) as the driving decision — this stand-up does not flip Accepted until ADR-0030 is Accepted
- [x] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

ADR-0030 decided that durable, attributable Grid-wide security and action audit is a first-class concern homed in a **new dedicated `HoneyDrunk.Audit` Node** — not Operator (the recorder must not be the actor), not Kernel (audit is a domain substrate, not a Kernel primitive, and a Data-backed Kernel impl would introduce a DAG cycle). That ADR is the capability/decision record. This ADR is the **stand-up decision** for the Audit Node itself.

`HoneyDrunk.Audit` does not exist on disk and is not yet cataloged. There is no repo, no packages, no contracts, no store, no CI. Auth has durable attributable security events (login attempts, authz denials) that are emitted nowhere durable today, and Operator's `IAuditLog`/`AuditEntry` pair (ADR-0018) is being generalized out of `HoneyDrunk.Operator.Abstractions` into this Node per ADR-0030 D5. Before the Node scaffolds, the package layout, the exposed contract surface, the downstream coupling rule, the contract-shape canary, and the catalog registration targets need to be settled, because the first consumers (Auth, then Operator) will compile against whatever ships first and lock it in.

This ADR follows the standup-ADR convention set 2026-04-19 (memory rule: every empty cataloged Node — and, by extension, every Node ADR-0030 newly introduces — gets its own stand-up ADR before scaffolding lands). It mirrors the stand-up shape used by ADR-0016 (AI), ADR-0017 (Capabilities), and ADR-0018 (Operator): contracts live in an `Abstractions` package, runtime composition is a separate package, downstream Nodes compile against `Abstractions` only, and a contract-shape canary freezes the hot contracts from the first scaffold.

This ADR is the **stand-up decision** for the Audit Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes couple to it, and what scaffolds in the first PR. It is not a scaffolding packet. Filing the repo, adding CI, wiring the in-memory fixture, and producing the first shippable packages all follow as separate work items once this ADR is accepted. The capability rationale (why a Node, why not Operator, why not Kernel, the phased-integrity scope discipline, the honest tamper-evidence limitation) lives in ADR-0030 and is not re-litigated here.

## Decision

### D1. HoneyDrunk.Audit is the Core sector's Grid-wide durable security and action record

`HoneyDrunk.Audit` is the single Node in the Core sector that owns the Grid's **durable, attributable security, action, and data-change record** — the contract and runtime machinery that durably records "actor X attempted or executed action Y" and "actor X changed record Y" (login attempts, authorization grants and denials, privileged-action execution, purchases, workflow starts, integration callbacks, and entity create/update/delete records) and serves that record back for incident reconstruction and forensics.

It is a record substrate, not a control plane and not an observability pipeline. It does not decide whether an action is allowed (that is Auth and Operator). It does not sample, aggregate, or surface health signal (that is Pulse). It owns the durable write, the append-only guarantee, the audit-class retention, and the forensic read surface. The boundary against Operator (recorder ≠ actor) and against Pulse (durable attributable record ≠ sampled observability) is pinned by ADR-0030 D1/D2 and is not re-opened here.

### D2. Package families

The Audit Node ships the following package families, mirroring the stand-up shape used by ADR-0016 (AI), ADR-0017 (Capabilities), and ADR-0018 (Operator):

- `HoneyDrunk.Audit.Abstractions` — all interfaces and the one audit record (`IAuditLog`, `IAuditQuery`, `AuditEntry`). Zero runtime dependencies beyond `HoneyDrunk.Kernel` abstractions, per repo-invariant 1.
- `HoneyDrunk.Audit.Data` — the Data-backed runtime composition: the append-only `IAuditLog` writer and `IAuditQuery` reader implemented over `HoneyDrunk.Data`'s `IRepository`/`IUnitOfWork`, the audit-class retention policy wiring, DI wiring.

The implementation package is named `HoneyDrunk.Audit.Data` — a backing-slot suffix consistent with the established convention for a Node whose runtime is defined by its storage backing (parallel to `HoneyDrunk.Data.*` and the `HoneyDrunk.Vault.Providers.*` provider-slot precedent). It is named for its backing, not as a bare `HoneyDrunk.Audit` runtime package, because the store *is* the runtime concern here and a future alternative backing would be a sibling slot, not a replacement.

An in-memory `IAuditLog`/`IAuditQuery` fixture for deterministic downstream tests ships as part of the scaffold. Following the precedent set by ADR-0027 D3 (no speculative `Testing` package when the consumer set is small and known), the in-memory fixture lives `internal` to the runtime package's test project at stand-up. When a second downstream consumer beyond Auth and Operator needs it, it is cut into a `HoneyDrunk.Audit.Testing` package as a non-breaking change. This is a deliberate departure from ADR-0017's ship-`Testing`-at-stand-up pattern, justified by the same reasoning ADR-0027 used: the consumer set (Auth, Operator) is small and known.

### D3. Exposed contracts

Three primary surfaces form the Audit Node's public boundary — **two interfaces and one canonical record envelope** — plus supporting value types/enums required by that envelope. These are the surfaces downstream Nodes are allowed to compile against:

| Contract | Kind | Purpose |
|---|---|---|
| `IAuditLog` | interface | Append-only write of an `AuditEntry`. No update method. No delete method. Append-only is enforced at the interface surface, not only at storage (ADR-0030 D4). |
| `IAuditQuery` | interface | Time-ordered and filtered read/forensic retrieval over the durable record. Net-new contract (ADR-0030 D3); has no Operator precedent. Satisfies ADR-0018 D9's "work off the read surface" commitment. |
| `AuditEntry` | record | Canonical append-only audit record envelope — category, event name/action, actor, target/resource, outcome, correlation id, tenant, structured metadata, and optional data-change details. Generalized Grid-wide from the Operator-scoped shape. Drops the `I` prefix per the grid-wide naming rule; `IAuditLog` and `IAuditQuery` retain it. |

`AuditEntry` explicitly supports both major audit families from v0.1.0:

1. **Activity/security/system audit** — what an actor attempted or did: login attempts, authorization grants/denials, purchases, workflow starts, integration callbacks, agent/operator decisions, and privileged actions.
2. **Data-change audit** — what durable record changed: entity created/updated/deleted, entity/resource type, entity/resource id, changed fields, and optional before/after values.

The supporting shape includes `AuditCategory`, `AuditOutcome`, `AuditTarget`, and `AuditChange` so data-change audit is first-class and queryable instead of buried in an opaque context string. `AuditChange` values may carry before/after values, but sensitive fields must be redacted before append. The Audit substrate is durable and queryable; it must not become a secret/PII leak path.

`IAuditLog` and `AuditEntry` are **relocated** from `HoneyDrunk.Operator.Abstractions` to `HoneyDrunk.Audit.Abstractions` and generalized Grid-wide per ADR-0030 D5. The existing `honeydrunk-operator` catalog entries for these two are marked relocated as part of the follow-up work. `IAuditQuery` is added new here. This mirrors the contract-reconciliation pattern ADR-0017 used (`ICapability`/`ICapabilityPermission` superseded by a corrected surface) and ADR-0018 used (`ICostController` → `ICostGuard`).

### D4. Storage is Data-backed; append-only enforced at the interface

`HoneyDrunk.Audit.Data` implements the store over `HoneyDrunk.Data`'s `IRepository` and `IUnitOfWork` — the same transactional surface Operator's audit log already sat on (ADR-0018 D9). The append-only guarantee is enforced at the interface surface: `IAuditLog` exposes no update and no delete method (ADR-0030 D4). Audit data carries an audit-class retention policy **distinct from Pulse/observability retention** (ADR-0030 D4); the retention value is sourced via the App-Configuration-via-Vault pattern (ADR-0005), not hardcoded. **Phase-1 integrity is append-only-by-interface, not tamper-evident** (ADR-0030 D9) — this is the stated, accepted limitation and the standup must not document or describe the store as tamper-evident.

### D5. The Audit Node has its own managed identity

The Audit Node runs under its **own dedicated managed identity**, distinct from Auth's and Operator's. The recorder authenticating as itself — not borrowing an emitter's identity — is what keeps the audit write path attributable and keeps the recorder/actor trust boundary (ADR-0030 D2) intact at the infrastructure layer, not only at the contract layer. Per-Node identity isolation is the Grid's established posture (memory: Azure per-service isolation). Key Vault and App Configuration access for the audit-class retention configuration is scoped to this identity per ADR-0005.

### D6. First emitter is HoneyDrunk.Auth; Operator is reconciled as a consumer

The first real emitter wired at stand-up is `HoneyDrunk.Auth`, recording durable attributable security events additively to its existing OTel traces, on a separate durable channel, with Auth's identity-out-of-traces invariant untouched (ADR-0030 D6). `HoneyDrunk.Operator` is reconciled from owner to consumer/emitter of the generalized contracts (ADR-0030 D5): it continues recording its AI-runtime decisions, now by emitting `AuditEntry` against the `IAuditLog` it consumes from `HoneyDrunk.Audit.Abstractions`. ADR-0018 receives an additive amendment note recording the relocation and reclassification (additive only; ADR-0018 Status and decision content unchanged).

Data-change emitters are also first-class consumers of the same `IAuditLog` surface. Automatic Data-layer interception can emit `AuditCategory.DataChange` events only when a redaction policy is explicit; application/domain code remains responsible for business-intent activity events so the Grid can distinguish "row changed" from "purchase completed" or "workflow started."

### D7. Telemetry emission — Pulse consumes, Audit does not depend

Audit emits its own operational telemetry (write latency, query latency, append throughput) via Kernel's `ITelemetryActivityFactory`; Pulse consumes it downstream. **Audit has no runtime dependency on Pulse.** The direction is one-way by contract: Audit emits operational telemetry, Pulse observes. Same rule as ADR-0016 D7 (AI), ADR-0017 D7 (Capabilities), and ADR-0018 D7 (Operator). Audit *records* are not telemetry and never flow to Pulse — the durable audit channel and the observability channel stay separate (ADR-0030 D1).

### D8. Contract-shape canary

A contract-shape canary is added to the Audit Node's CI: it fails the build if the `HoneyDrunk.Audit.Abstractions` public surface changes shape (method signatures, parameter shapes, record members, enum members, supporting value types) without a corresponding version bump. The protected surface includes:

- `IAuditLog`
- `IAuditQuery`
- `AuditEntry`
- `AuditEntryId`
- `AuditQueryFilter`
- `AuditCategory`
- `AuditOutcome`
- `AuditTarget`
- `AuditChange`

These are the hot path for every emitter and reader. `IAuditLog` is on the write path of every security, activity, privileged-action, and data-change event in the Grid; `AuditEntry` and its supporting value types are the payload; `IAuditQuery`/`AuditQueryFilter` are the contracts every forensic reader (and the future tenant-facing forensics Service, ADR-0030 D8b) compiles against. Accidental shape drift breaks emitters/readers simultaneously. The canary makes this a compile-time failure at Audit's own CI, not a discovery at consumer sites.

### D9. Downstream coupling rule

Emitters and readers (Auth and Operator first; any Node recording a security, privileged-action, activity, system, integration, or data-change event later) compile **only** against `HoneyDrunk.Audit.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.Audit.Data` in production composition. Composition — which store backing is active, which retention policy is loaded — is a host-time concern, resolved at application startup from App Configuration. This is the same abstraction/runtime split applied for AI, Capabilities, Operator, Vault, and Transport, restated here because it is the rule that lets Auth and Operator proceed against `Abstractions` alone without waiting for the Data-backed runtime.

### D10. Dependencies on Kernel and Data are first-class

Audit takes first-class runtime dependencies on two Nodes:

- **HoneyDrunk.Kernel** — for `IGridContext`, lifecycle hooks, health and readiness, telemetry. Every audit write is context-aware; an audit entry without correlation and tenant is an unattributable audit entry, which defeats the substrate's purpose.
- **HoneyDrunk.Data** — for `IRepository`, `IUnitOfWork`, and the append-only write/read path. The append-only guarantee and the audit-class retention both sit on Data's transactional surface (D4).

These two edges are new in `catalogs/relationships.json` and are added as part of the follow-up work. The new edges introduced by this stand-up are: `honeydrunk-audit` → `honeydrunk-data`, `honeydrunk-audit` → `honeydrunk-kernel`, `honeydrunk-auth` → `honeydrunk-audit`, and `honeydrunk-operator` → `honeydrunk-audit`. No cycle is introduced: Audit → Data → Kernel and Audit → Kernel are all DAG-consistent (invariant 4); the rejected Kernel-hosted alternative (ADR-0030) was rejected precisely because it *would* have created a Kernel → Data → Kernel cycle, which this placement avoids.

Downstream Nodes are not transitively required to reference Kernel or Data to *use* Audit — they reference `HoneyDrunk.Audit.Abstractions` only. The two runtime dependencies are composed in at the host, not at the consumer.

### D11. Standup checklist — what scaffolds in the first PR

Per the standup-ADR convention, the scaffolding work is a follow-up packet, not part of this ADR's text. But the first PR must produce a known, audited shape so the scaffold is reviewable. The first PR contains:

- **Solution layout:** `HoneyDrunk.Audit.slnx` with two projects (`HoneyDrunk.Audit.Abstractions`, `HoneyDrunk.Audit.Data`) and matching `.Tests` projects per the testing-invariant pattern.
- **HoneyDrunk.Standards wiring** on every project (analyzers, EditorConfig, `PrivateAssets: all`).
- **CI pipeline** consuming HoneyDrunk.Actions shared workflows — build, test, security scan, contract-shape canary (D8), package scan.
- **`README.md` per package** describing purpose, installation, and public API surface, committed in the first commit (invariant 12).
- **`CHANGELOG.md`** at solution and per-package level, committed in the first commit (invariant 12).
- **`LICENSE` file** — Grid public default; no carve-out applies.
- **Data-backed append-only store**: the `HoneyDrunk.Audit.Data` `IAuditLog` writer and `IAuditQuery` reader over `IRepository`/`IUnitOfWork`, with no update/delete path on the `IAuditLog` surface, and the audit-class retention policy hook (value sourced from App Configuration, not hardcoded).
- **The Node's own managed identity** provisioned per D5 (per-Node isolation, ADR-0005-scoped Vault/App Configuration access).
- **In-memory `IAuditLog`/`IAuditQuery` fixture** living `internal` to the runtime package's test project (D2).
- **End-to-end smoke test** in CI: an `AuditEntry` written through `IAuditLog` is read back through `IAuditQuery` against the in-memory fixture.

The scaffold packet does **not** include: hash-chain / WORM tamper-evidence (deferred behind the boundary per ADR-0030 D8a), the deployable tenant-facing forensics read Service (deferred per ADR-0030 D8b, built later over the existing `IAuditQuery` with no contract change), the Auth emitter wiring (a separate packet against the stood-up `Abstractions`), or the Operator reconciliation (a separate packet). The scaffold proves the contract surface compiles, the canary catches drift, append-only holds at the interface, and the in-memory composition round-trips a write through a read. Production-shape work and emitter wiring follow.

## Consequences

## ADR-0031 sync completion note (2026-05-21)

- Architecture packets 01/02 closed: invariants 47/48/49 assigned, catalogs/context registered, and stale repo-creation scope reconciled.
- `HoneyDrunk.Audit` packet 03 closed via Audit PR #2; `v0.1.0` packages were tagged, released, and published.
- `HoneyDrunk.Auth` packet 04 closed via Auth PR #24; Auth now emits token-validation and authorization decisions through `HoneyDrunk.Audit.Abstractions` only.
- Remaining downstream reconciliation is Operator as a future emitter/reader; that is follow-up work beyond the initial Audit stand-up and Auth first-emitter baseline.

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [x] ADR-0030 (Grid-Wide Audit Substrate) is Accepted (driving decision; this stand-up does not flip Accepted before it).
- [x] `HoneyDrunk.Audit` public repo created with the structure described in D11.
- [x] `HoneyDrunk.Audit.Abstractions 0.1.0` published with the D3 public surface and supporting value types.
- [x] `HoneyDrunk.Audit.Data 0.1.0` ships with the Data-backed append-only composition and the in-memory test fixture.
- [x] Audit's CI includes the D8 contract-shape canary and it is green.
- [ ] The Node's own managed identity is provisioned per D5.
- [x] `repos/HoneyDrunk.Audit/` context folder exists in the Architecture repo with the standard five files.
- [x] `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/contracts.json`, `catalogs/grid-health.json`, and `catalogs/modules.json` reflect the stand-up and the contract relocation.
- [x] `constitution/sectors.md` Core-sector table includes the Audit row.
- [x] ADR-0018 carries the additive amendment note per ADR-0030 D5.
- [x] Scope agent flips Status → Accepted and assigns final invariant numbers.

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet that produces a first `Abstractions` release — unblocks:

- **HoneyDrunk.Auth** — can wire the first durable attributable security-event emitter against `IAuditLog`, additively, without touching its identity-out-of-traces invariant.
- **HoneyDrunk.Operator** — can be reconciled from owner to consumer of `IAuditLog`/`AuditEntry`, shedding the recorder-is-also-the-actor structural problem (ADR-0030 D2/D5).
- **Any Node recording security, activity, system, integration, privileged-action, or data-change events** — has a durable, attributable target instead of a lossy log, sampled trace, or ad-hoc table.
- **The future tenant-facing forensics Service** — has `IAuditQuery` to build against the moment its trigger fires (ADR-0030 D8b), with no extraction and no contract migration.

### New invariant (`constitution/invariants.md`)

Assigned invariant numbers: **48** (downstream Abstractions-only coupling, ADR-0031 D9) and **49** (contract-shape canary, ADR-0031 D8). See `constitution/invariants.md`, `## Audit Invariants`. The substrate-level audit-emission boundary invariant is **47**, landed by ADR-0030.

- **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`.** Composition against `HoneyDrunk.Audit.Data` is a host-time concern. See D9.
- **The Audit Node CI must include a contract-shape canary for the `HoneyDrunk.Audit.Abstractions` public surface.** Shape drift on `IAuditLog`, `IAuditQuery`, `AuditEntry`, or the supporting query/category/outcome/target/change value types is a build failure, not a downstream discovery. See D8.

(The audit-emission boundary invariant — auditable security, action, and data-change events must be emitted to the Audit substrate on a durable channel separate from observability — is invariant 47 from ADR-0030 and is not restated here to avoid double-numbering.)

### Contract-shape canary becomes a requirement

The contract-shape canary in D8 is a gating requirement on the Audit Node's CI from the first scaffold. It is not a later hardening pass — the three frozen contracts are the write and read path for every security and privileged-action event in the Grid and the surface the future forensics Service compiles against; they must be protected from day one.

### Catalog obligations

`catalogs/nodes.json` does not currently carry an entry for `honeydrunk-audit`. `catalogs/relationships.json` does not carry the four new edges (D10). `catalogs/contracts.json` carries `IAuditLog`/`AuditEntry` under `honeydrunk-operator` and must mark them relocated to `honeydrunk-audit` and add `IAuditQuery`. `catalogs/grid-health.json` and `catalogs/modules.json` gain the new Node rows. `constitution/sectors.md` gains an Audit row in the Core-sector table. These reconciliations are tracked in the follow-up checklist at the top of this ADR. This ADR does not modify catalogs.

### Negative

- **A new repo, CI pipeline, managed identity, and catalog footprint.** The trade is a correct trust boundary and a convention-consistent home (ADR-0030 D2), against the maintenance cost of one more Node. Accepted as the deliberate permanent-boundary investment ADR-0030 records.
- **The implementation package is `HoneyDrunk.Audit.Data`, a backing-named slot rather than a bare runtime package.** This is a small departure from the `HoneyDrunk.Operator` / `HoneyDrunk.AI` bare-runtime naming. It is deliberate: the store *is* the runtime concern, and a future alternative backing should be a sibling slot, not a replacement of a bare runtime. The cost is one naming inconsistency against the AI/Operator pattern; the benefit is the package name states the backing honestly and leaves room for a sibling slot without a rename.
- **No `Testing` package at stand-up.** The in-memory fixture is reusable only by Audit's own tests until a third consumer (beyond Auth and Operator) emerges. Deliberate scope cut following ADR-0027's precedent; cutting the package later is non-breaking.
- **Phase-1 store is append-only, not tamper-evident.** Restated from ADR-0030 D9 so it is not lost at the scaffold: the scaffold must not document the store as tamper-evident. Hash-chain/WORM is deferred behind the boundary per ADR-0030 D8a.
- **The relocation of `IAuditLog`/`AuditEntry` touches Operator's package surface.** Mitigation per ADR-0030 D5: Operator becomes a consumer of the same-named generalized contracts and ADR-0018 is amended additively, not rewritten.

## Alternatives Considered

The capability-level alternatives (hybrid-in-Kernel, generalize-in-Operator, do-nothing, dedicated-Node, build-the-platform-now) are recorded in ADR-0030 and are **not** re-litigated here. This section covers only the stand-up-shape alternatives specific to this ADR.

### Bare `HoneyDrunk.Audit` runtime package instead of `HoneyDrunk.Audit.Data`

Rejected. The Audit runtime concern *is* the durable store — there is no router, policy evaluator, or provider-axis runtime as Operator and AI have. Naming the package `HoneyDrunk.Audit.Data` states the backing honestly and leaves a sibling-slot path open if an alternative backing is ever needed, the same way `HoneyDrunk.Vault.Providers.*` and `HoneyDrunk.Data.*` name their backing. A bare runtime package would obscure that the backing is the runtime and would force a rename if a second backing slot were ever added.

### Ship a `HoneyDrunk.Audit.Testing` package at stand-up (ADR-0017 pattern)

Rejected for this Node. ADR-0017 ships `Testing` at stand-up because Capabilities had multiple immediate downstream consumers (Agents, Operator, Evals) needing deterministic fixtures. Audit's consumer set at stand-up is small and known (Auth, Operator). ADR-0027 D3 established the precedent that a speculative `Testing` package is not shipped when the consumer set is small and known; the fixture lives `internal` to the test project and is cut into a package as a non-breaking change when a third consumer emerges. The same reasoning applies here.

### Freeze only a hot subset of contracts in the canary (ADR-0016/0018 four-of-N pattern)

Rejected. ADR-0016 and ADR-0018 freeze four of a larger surface because the hot subset is a fraction of the public contracts. The Audit public surface is still intentionally small, but data-change support adds supporting value types that are every bit as load-bearing as the primary `AuditEntry` envelope. Freezing the whole `HoneyDrunk.Audit.Abstractions` public surface from the first scaffold costs little and removes the "which one slipped through" failure mode entirely.

### Defer the Auth emitter and Operator reconciliation into this stand-up

Rejected. Per the standup-ADR convention, the stand-up produces the boundary, the contracts, and a round-trip-proving scaffold. Wiring the Auth emitter and reconciling Operator are separate packets against the stood-up `Abstractions` — bundling them into the scaffold would conflate "the substrate exists and compiles" with "two specific Nodes are migrated onto it," which is exactly the bundling the convention exists to prevent (and which ADR-0030's scope discipline reinforces). They follow as distinct follow-up packets.
