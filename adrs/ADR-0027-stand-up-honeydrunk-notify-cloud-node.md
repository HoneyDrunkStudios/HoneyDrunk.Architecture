# ADR-0027: Stand Up the HoneyDrunk.Notify.Cloud Node — Multi-Tenant Commercial Wrapper Above Notify

**Status:** Proposed
**Date:** 2026-05-02
**Deciders:** HoneyDrunk Studios
**Sector:** Ops

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Create `HoneyDrunk.Notify.Cloud` GitHub repo as **private** (human-only step — first private repo in the Grid; see D2 for justification)
- [ ] Choose and apply the open-source license decided in D11 to `HoneyDrunk.Notify`, `HoneyDrunk.Notify.Client`, and `HoneyDrunk.Communications` repos (LICENSE file commit + repo description update)
- [ ] Scaffold packet — solution structure with `HoneyDrunk.Notify.Cloud.Abstractions`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Notify.Cloud.Billing.Stripe`, `HoneyDrunk.Notify.Cloud.Web`; HoneyDrunk.Standards wiring; CI pipeline via HoneyDrunk.Actions shared workflows; in-memory fixtures for the API key store and rate-limit policy
- [ ] Create `repos/HoneyDrunk.Notify.Cloud/` context folder in the Architecture repo (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) — matching the template used by `repos/HoneyDrunk.Communications/`
- [ ] Add `honeydrunk-notify-cloud` Node entry to `catalogs/nodes.json` with a `visibility: private` field (catalog schema gains a new field — first use; document in the catalog README)
- [ ] Add `honeydrunk-notify-cloud` entries to `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/contracts.json`, and `catalogs/modules.json`
- [ ] Update sector map (`constitution/sectors.md`) Ops-sector entry to include Notify Cloud as the commercial wrapper above Notify and Communications
- [ ] Wire the contract-shape canary into Actions for the four frozen Notify Cloud contracts (`INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance`); the Kernel multi-tenant primitives are guarded by Kernel's canary per ADR-0026
- [ ] Reference ADR-0026 (Grid Multi-Tenant Primitives) as a hard prerequisite — Notify Cloud is its first real (non-noop) consumer of `ITenantRateLimitPolicy` and `IBillingEventEmitter`; this stand-up does not flip Accepted until ADR-0026 is Accepted
- [ ] Scope agent assigns final invariant numbers when flipping Status → Accepted

## Context

PDR-0002 commits HoneyDrunk Notify as the Grid's first commercial product. The PDR specifies a multi-tenant commercial wrapper around the live Notify engine, sold to indie .NET developers as a hosted notification service at `notify.honeydrunkstudios.com`. The wrapper Node is named `HoneyDrunk.Notify.Cloud` (per PDR-0002's resolved-questions table).

This Node does not exist on disk and is not yet cataloged. PDR-0002's Architecture Implications section sketches the package families and dependency surface but defers the formal stand-up — package families, downstream coupling rule, contract-shape canary, OSS license choice, repo visibility, scaffold scope — to this ADR. That deferral is consistent with the standup-ADR convention (set 2026-04-19 per memory): every empty cataloged Node gets its own stand-up ADR before scaffolding lands.

`HoneyDrunk.Notify.Cloud` is the first commercial-revenue-bearing Node in the Grid. Three things follow from that:

1. **Repo visibility departs from the studio's public-by-default posture.** The Grid's repo policy (memory: "new HoneyDrunk repos are public unless revenue/compliance/experiment") admits a revenue carve-out, and this Node sits squarely in it. The wrapper carries multi-tenant boundary code, billing logic, abuse heuristics, and customer-data-adjacent infrastructure that have zero educational value as OSS and would invite a hyperscaler-style "host this for cheaper" competitor against a solo dev who cannot match infra economics. PDR-0002 §M makes the call; this ADR makes the visibility decision explicit and justifies it on the record.
2. **The OSS license question for the engine is no longer deferrable.** PDR-0002 §M lists FSL or BSL as the candidates and defers final choice to "the standup ADR for `HoneyDrunk.Notify.Cloud`" — i.e., this ADR. The license affects three repos (`HoneyDrunk.Notify`, `HoneyDrunk.Notify.Client`, `HoneyDrunk.Communications`), all open. Picking now means the first commercial customer reads a stable license; deferring means relicensing later, which is hostile to early contributors.
3. **The Node depends on Grid-wide multi-tenant primitives that do not exist yet.** PDR-0002 §F and the Architecture Implications section make `TenantId`, per-tenant rate-limit policy, per-tenant Vault scoping, and tenant-scoped billing events Grid-wide concerns — designed in Kernel and shared infrastructure, not Notify-specific. A parallel ADR (Grid Multi-Tenant Primitives) is being drafted at the same time as this one and is a hard prerequisite. This ADR depends on that ADR being Accepted before Notify Cloud's scaffold packet runs; it does not redefine those primitives.

This ADR is the **stand-up decision** for the Notify Cloud Node — what it owns, what it does not own, which contracts it exposes, how downstream Nodes (and external customers) couple to it, and what license posture the surrounding open-source repos take. It is not a scaffolding packet. Filing the repo, adding CI, wiring the InMemory fixtures, and producing the first shippable packages all follow as separate issue packets once this ADR is accepted.

## Decision

### D1. HoneyDrunk.Notify.Cloud is the Ops sector's multi-tenant commercial wrapper above Notify

`HoneyDrunk.Notify.Cloud` is the single Node in the Ops sector that owns **multi-tenant commercial-product primitives** for the Notify engine — the API gateway, API key issuance and validation, per-tenant rate-limit enforcement, tenant-scoped billing event emission, and the tenant management website that together turn the open-source Notify engine into a hosted service customers can sign up for and pay for.

It is a commercial wrapper, not a delivery engine. It does not call provider SDKs, render templates, manage queues, retry sends, or decide which user receives which message. Those mechanics stay in Notify and Communications. Notify Cloud sits above both: it accepts external API requests, authenticates them by API key, applies per-tenant rate limits and quota checks, attaches the resolved `TenantId` to the request, delegates orchestration to `ICommunicationOrchestrator`, and emits a `BillingEvent` on each successful delivery for Stripe to consume.

The Grid's internal callers continue to use Notify (and Communications) directly. Notify Cloud does not interpose on the internal path. The internal callers acquire their `TenantId` (defaulting to `internal`) through the Grid's existing `IGridContext` and never traverse a Notify Cloud surface.

### D2. Repo visibility — private, with explicit justification

`HoneyDrunk.Notify.Cloud` is the **first private repo in the HoneyDrunk Grid**. The Grid's default posture is public; this Node is a deliberate, justified exception under the revenue carve-out.

The justification, on the record:

- **Customer-data-adjacent infrastructure.** Tenant isolation enforcement, abuse heuristics, billing-fraud detection, and per-tenant Vault path resolution are concerns where public scrutiny of half-baked states actively harms customers. These are not educational primitives that benefit from community contribution — they are studio-specific glue that other consumers cannot meaningfully reuse.
- **Hyperscaler defense.** Open-sourcing the multi-tenant gateway produces an AWS-style "host Notify Cloud for cheaper" competitor against a solo developer who cannot match infra economics. The OSS-engine + private-wrapper split (D11) puts the moat in the right place — operational reliability and economy-of-scale infrastructure, not closed-source secrets.
- **Billing-system integrity.** Stripe webhook signing keys, internal billing-event shapes, and abuse-rate thresholds are the kinds of values that lose value the moment they go public.

The Grid's repo catalog gains a `visibility` field on this Node (`visibility: "private"`). All other Nodes default to `visibility: "public"` (or omit the field, treating absence as public). The catalog README documents the field's introduction.

The customer-facing SDK (`HoneyDrunk.Notify.Client`) **stays in the open `HoneyDrunk.Notify` repo**, not in this private repo. Customers install the SDK from NuGet without ever needing access to the wrapper's source. See D6.

### D3. Package families

The Notify Cloud Node ships the following package families, mirroring the package-family pattern used by ADR-0019 (Communications) and ADR-0017 (Capabilities):

- `HoneyDrunk.Notify.Cloud.Abstractions` — all Notify-Cloud-specific interfaces and records (`INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance`). Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Notify.Abstractions`, and `HoneyDrunk.Communications.Abstractions`. **Does not** declare `TenantId`, `BillingEvent`, `IBillingEventEmitter`, `ITenantRateLimitPolicy`, or `TenantRateLimitDecision` — those primitives live in `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026.
- `HoneyDrunk.Notify.Cloud` — runtime composition: default `INotifyCloudGateway` implementation, API key validation middleware, the Notify Cloud-specific `ITenantRateLimitPolicy` implementation (replacing Kernel's `NoopTenantRateLimitPolicy`), the billing-event-emission tail wired into the worker pipeline, DI wiring.
- `HoneyDrunk.Notify.Cloud.Billing.Stripe` — Stripe-specific billing adapter implementing `IBillingEventEmitter` (the Kernel.Abstractions interface) for the Stripe metered-billing webhook bridge. Provider-slot pattern; alternative billing providers (Paddle, LemonSqueezy) can be added as additional `Billing.*` packages later without touching the core.
- `HoneyDrunk.Notify.Cloud.Web` — multi-tenant management website (signup, billing, API key issuance, basic delivery logs). The web stack choice (Blazor Server vs. Astro + minimal API) is **deferred to the scaffold packet**, which produces a sub-ADR if the trade-off is non-obvious; default proposed is Blazor Server for tighter alignment with the rest of the .NET-native stack and lower context-switch cost for the solo dev.

No `Testing` package is shipped at stand-up. The runtime composition uses `HoneyDrunk.Notify.Testing` and `HoneyDrunk.Communications.Testing` for end-to-end tests; the Notify Cloud-specific in-memory fixtures (in-memory API key store, in-memory tenant rate-limit policy) live as `internal` test helpers in the runtime package's test project until a downstream consumer needs them. If and when a second consumer emerges, a `HoneyDrunk.Notify.Cloud.Testing` package can be cut from those internals.

### D4. Exposed contracts

Two contracts form the Notify Cloud Node's public boundary inside the Grid, plus one supporting record. These are the surfaces that the Notify Cloud runtime is *internally* composed against; external customers do not compile against them — they consume the REST API and the SDK.

| Contract | Kind | Purpose |
|---|---|---|
| `INotifyCloudGateway` | interface | Top-level entry point — given an API-key-authenticated external request, resolves the tenant context, consults `ITenantRateLimitPolicy` (from Kernel), delegates orchestration to `ICommunicationOrchestrator`, and emits a `BillingEvent` (Kernel record) on successful delivery via `IBillingEventEmitter` (Kernel interface). |
| `INotifyCloudApiKeyStore` | interface | Issuance and validation of per-tenant API keys. Issued keys are returned in plaintext exactly once at issuance time; stored only as salted hashes. Validation is a hash-compare lookup; raw keys are never stored, never logged, never traced. |
| `NotifyCloudTenantTier` | record | Notify Cloud-specific tenant-tier descriptor — tier name (`Free`, `Starter`, `Pro`), events-per-month ceiling, channels enabled, BYO-provider-key allowance. Value type, no `I` prefix per the grid-wide naming rule. Consumed by the Notify Cloud `ITenantRateLimitPolicy` implementation to derive tenant-specific limits from tier. |
| `ApiKeyIssuance` | record | Returned exactly once at API key issuance — carries the plaintext key (only at this moment), the key's id, the tenant it binds to, and the issued-at timestamp. Never persisted in this shape; the runtime persists only the salted hash and the metadata. |

**Primitives consumed from Kernel (per ADR-0026), not redefined here:**

- `TenantId` (and `TenantId.Internal` sentinel)
- `ITenantRateLimitPolicy` and `TenantRateLimitDecision` — Notify Cloud ships a tier-driven implementation that replaces the `NoopTenantRateLimitPolicy` registration at host time
- `IBillingEventEmitter` and `BillingEvent` — Notify Cloud ships the Stripe implementation in `HoneyDrunk.Notify.Cloud.Billing.Stripe`

This is the single most important boundary call in this stand-up: the multi-tenant primitives are Grid-wide, not Notify-Cloud-specific. Notify Cloud is the first *real* (non-noop) implementation of `ITenantRateLimitPolicy` and the first *real* implementation of `IBillingEventEmitter` in the Grid, but it does not own those contracts.

### D5. Boundary rule with Notify and Communications

The dependency direction is strict and one-way:

```
Notify Cloud
  ├─ consumes ──► Communications (ICommunicationOrchestrator) — orchestration delegate
  ├─ consumes ──► Notify (INotificationSender) — never directly; always via Communications
  ├─ consumes ──► Auth (IApiKeyAuthenticator middleware path — new)
  ├─ consumes ──► Vault (per-tenant secret scoping)
  ├─ consumes ──► Web.Rest (response envelopes, correlation IDs)
  ├─ consumes ──► Kernel (IGridContext, lifecycle, telemetry, TenantId)
  └─ emits telemetry ──► Pulse
```

**Decision test — for any concern in the Notify Cloud path, ask:**

1. Is it tenant-context resolution, API key authentication, per-tenant rate-limit enforcement, billing-event emission, or external-API surface shape? → **Notify Cloud**.
2. Is it a decision about *whether* a given user should receive a given message, or *when*, or as part of *what sequence*? → **Communications**.
3. Is it provider-side delivery (calling Resend, calling Twilio, retrying a transient failure)? → **Notify**.
4. Is it tenant-aware, but Grid-wide (not commercial-wrapper-specific)? → **Kernel** (the multi-tenant primitives).

Notify Cloud does **not** import Notify directly except through `INotificationSender` for diagnostic / smoke-test paths. The hot path is Notify Cloud → Communications → Notify. This preserves Notify's invariant that delivery decisions are made by Communications, and it keeps Notify Cloud's view of tenancy at the orchestration boundary, not at the dispatch boundary.

Notify Cloud does **not** consume HoneyHub, any AI-sector Node, or any package outside the Ops/Core/Infrastructure sectors at v1. Phase 4+ may add AI-driven preference learning (Pro tier feature); that is a separate ADR when it lands.

### D6. The HoneyDrunk.Notify.Client SDK lives in the open Notify repo, not here

The customer-facing SDK is `HoneyDrunk.Notify.Client`. It is the wedge — the NuGet package indie .NET devs install in 30 seconds. **It lives in the public `HoneyDrunk.Notify` repo, not in `HoneyDrunk.Notify.Cloud`.**

This is a deliberate split confirmed here so future contributors do not accidentally relocate it:

- The SDK is identical for self-hosters and hosted-service customers. Both groups call the same engine endpoints with the same request shapes; only the base URL and the API key change.
- Putting the SDK in the open repo lets self-hosters consume it without a license seam and lets the SDK be reviewed, audited, and contributed to by the .NET community. That is the marketing wedge — buyers can read the code they're paying for.
- Putting the SDK in the private wrapper repo would force every public-engine release to coordinate a private-repo SDK release, breaking the engine's self-contained release shape.

The wrapper repo (`HoneyDrunk.Notify.Cloud`) is private; the SDK repo (`HoneyDrunk.Notify`, where the SDK package lives alongside the engine) stays public. The boundary between them is the network — the SDK speaks REST to whatever endpoint it's pointed at, and Notify Cloud's gateway is one of those endpoints.

### D7. Telemetry emission — Pulse consumes, Notify Cloud does not depend

Notify Cloud emits telemetry for every gateway entry, API key validation, rate-limit check, send delegation, and billing event via Kernel's `ITelemetryActivityFactory`. Pulse consumes that telemetry downstream. **Notify Cloud has no runtime dependency on Pulse.** The direction is one-way by contract: Notify Cloud emits, Pulse observes. Same rule as ADR-0016 D7 (AI), ADR-0017 D7 (Capabilities), and ADR-0019 D7 (Communications).

**Per-tenant telemetry tag discipline (low-cardinality bound).** Tenant identifiers attached to telemetry are bounded by the kill criteria in PDR-0002 §K — tens of paying customers at v1, low hundreds at the Pro ceiling. `tenant_id` is therefore a low-cardinality label safe for direct emission. If Notify Cloud crosses into thousands of paying tenants, this discipline is revisited as a follow-up ADR (cardinality bucketing or tag rollup). The current call: emit `tenant_id` directly.

API keys, raw secrets, message payloads, and recipient PII are **never** emitted — only metadata (tenant id, channel, provider, outcome, timing). Invariant 8 (secret values never appear in logs or traces) extends naturally to API keys.

### D8. Contract-shape canary

A contract-shape canary is added to the Notify Cloud Node's CI: it fails the build if any of the following four frozen contracts change shape (method signatures, parameter shapes, record members) without a corresponding version bump:

- `INotifyCloudGateway`
- `INotifyCloudApiKeyStore`
- `NotifyCloudTenantTier`
- `ApiKeyIssuance`

These four are the hot path for every Notify Cloud composition (the runtime, the Stripe billing adapter, the management web app, and any future billing-provider package). Accidental shape drift on any of them breaks the wrapper's internal composition simultaneously. The canary makes this a compile-time failure at Notify Cloud's own CI, not a discovery at runtime in production. This matches ADR-0016 D8, ADR-0017 D8, and ADR-0019 D8.

The Kernel-owned primitives consumed by Notify Cloud (`TenantId`, `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`) are guarded by **Kernel's** contract-shape canary per ADR-0026, not by this Node's canary. Drift on a Kernel primitive surfaces as a Kernel CI failure first; Notify Cloud's CI catches it as a downstream consumer-side break.

### D9. Downstream coupling rule

`HoneyDrunk.Notify.Cloud` has no Grid-internal downstream consumers — it is a leaf Node in the dependency graph from the Grid's side. Its consumers are external customers who hit the REST API or use the `HoneyDrunk.Notify.Client` SDK.

Internally, the wrapper itself composes against:

- `HoneyDrunk.Notify.Cloud.Abstractions` for its own contract surface.
- `HoneyDrunk.Communications.Abstractions` for orchestration delegation.
- `HoneyDrunk.Notify.Abstractions` for diagnostic / smoke-test paths only.
- `HoneyDrunk.Kernel.Abstractions` for tenant context, lifecycle, telemetry.
- Provider packages composed at host time (`HoneyDrunk.Notify.Cloud.Billing.Stripe`, etc.).

Production composition is a **host-time concern** in the Notify Cloud Container App: which billing provider is active, which API key store backend is wired (default: a hashed table in `HoneyDrunk.Data` per the Grid Multi-Tenant Primitives ADR), which rate-limit policy backend is in force.

### D10. Grid Multi-Tenant Primitives ADR is a hard prerequisite

This stand-up does not flip Status → Accepted until the parallel-drafted Grid Multi-Tenant Primitives ADR is Accepted. The reason: Notify Cloud is its first consumer, and the primitives' final shape (the exact `TenantId` type, the `IGridContext` propagation rule, the per-tenant Vault scoping pattern, the billing-event base shape) determines what Notify Cloud's Abstractions package compiles against.

The two ADRs are sequenced, not parallel for acceptance:

```
Grid Multi-Tenant Primitives ADR Accepted
  → Notify Cloud Abstractions 0.1.0 publishable
    → Notify Cloud scaffold packet runs
      → ADR-0027 flips Accepted
```

If the multi-tenant primitives ADR is rejected or substantially reshaped, this ADR is re-evaluated, not silently re-derived against a moving target.

### D11. Open-source license — Functional Source License (FSL) for the Notify engine

PDR-0002 §M deferred the FSL-vs-BSL choice to this ADR. The decision: **Functional Source License (FSL)** for the open-source repos that pair with this commercial wrapper:

- `HoneyDrunk.Notify` (the engine + the SDK)
- `HoneyDrunk.Notify.Client` (lives inside `HoneyDrunk.Notify` per D6, but covered explicitly)
- `HoneyDrunk.Communications` (the orchestration layer)

**Why FSL over BSL:**

- **Solo-dev defaults beat configuration.** FSL is a single license file with a fixed two-year auto-conversion to Apache 2.0. BSL requires the licensor to specify a "Change Date" and a "Change License" per release; the default Change Date is four years out (HashiCorp uses four). For a solo dev with no legal counsel, the simpler default wins. FSL's Sentry-style "two years, then Apache" is one decision made forever, not a per-release configuration.
- **Two-year conversion matches the kill clock cadence.** PDR-0002's kill clock runs ninety days from public launch; the longer-arc product clock is "is Notify Cloud sustained at twenty-four months." If Notify Cloud is alive at month twenty-four, the engine code from launch is two-plus years old and the competitive advantage has rotated to operational reliability, billing systems, and customer relationships — not to closed-source code. Auto-converting to Apache at that horizon costs nothing and produces goodwill.
- **The competitor restriction is the only commercially load-bearing clause.** Both FSL and BSL block "host this as a competing commercial service." That is the only protection the open core needs. FSL packages it in fewer paragraphs.
- **Sentry's precedent is closer than HashiCorp's.** Sentry is a developer-tooling SaaS sold to indie and small-team developers — same buyer profile as Notify Cloud. HashiCorp and MariaDB serve enterprise infrastructure. The buyer profile match makes Sentry's choice the directly applicable precedent.
- **Build-in-public alignment.** The FSL text is short, plain-language, and easy for an indie developer to read on a marketing site and trust. BSL's parameterization invites questions ("what's their Change Date? what license do they convert to?") that FSL pre-answers.

**The wrapper repo (`HoneyDrunk.Notify.Cloud`) is not licensed publicly.** It is private; access is granted only to the studio. License is "All rights reserved" by default of being private. If the repo is ever made public (unlikely under D2), a separate license decision is required.

**The marketing-site framing** (PDR-0002 §H, deferred to the marketing-site copy doc) says: *"The Notify engine is open source under FSL — read it, modify it, self-host it, redistribute it. The hosted service is what we sell."* This framing carries no legal weight on its own; the LICENSE files in the repos do.

### D12. API key authentication — handled by Auth, not by Notify Cloud directly

Notify Cloud's gateway authenticates external requests by API key, but the *validation primitive* lives in `HoneyDrunk.Auth` as a new `IApiKeyAuthenticator` middleware path (parallel to the existing JWT validation path). This preserves Invariant 10 — Auth tokens are validated, never issued — by treating API key validation as validation, not issuance. Issuance lives in Notify Cloud (it is a per-tenant lifecycle event), but validation is delegated to Auth so the trust boundary stays in one place.

This is the same pattern ADR-0017 D5 used for Capabilities → Auth (`ICapabilityGuard` projects Auth's policy into a tool-scoped form). Here, `INotifyCloudApiKeyStore` projects Auth's API key validation into a tenant-scoped form. The Auth Node gains a new middleware surface; Notify Cloud composes it at host time.

The detailed API key authentication pattern — middleware shape, hashing scheme, rotation flow — is a follow-up ADR (per PDR-0002's Recommended Follow-Up Artifacts). This stand-up commits to the boundary; the mechanism is settled later.

### D13. Standup checklist — what scaffolds in the first PR

Per the standup-ADR convention, the scaffolding work is a follow-up packet, not part of this ADR's text. But the first PR must produce a known, audited shape so the scaffold is reviewable. The first PR contains:

- **Solution layout:** `HoneyDrunk.Notify.Cloud.slnx` with four projects (`HoneyDrunk.Notify.Cloud.Abstractions`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Notify.Cloud.Billing.Stripe`, `HoneyDrunk.Notify.Cloud.Web`) and matching `.Tests` projects per the testing-invariant pattern.
- **HoneyDrunk.Standards wiring** on every project (analyzers, EditorConfig, `PrivateAssets: all`).
- **CI pipeline** consuming HoneyDrunk.Actions shared workflows — build, test, security scan, contract-shape canary (D8), provider-contract canary, package scan.
- **`README.md` per package** describing purpose, installation, public API surface (Invariant 12).
- **`CHANGELOG.md`** at solution and per-package level (Invariant 12).
- **`LICENSE` file** — `LicenseRef-Proprietary` reference (private repo, all rights reserved). The open-source FSL license per D11 is applied to the *other three* repos (`HoneyDrunk.Notify`, `HoneyDrunk.Notify.Client`'s home in that repo, `HoneyDrunk.Communications`) in a separate follow-up packet, not in this scaffold.
- **In-memory `INotifyCloudApiKeyStore`** for tests (lives `internal` in the runtime project's test project until a second consumer needs it per D3).
- **Default `INotifyCloudGateway` implementation** that wires API key validation, rate limiting, orchestration delegation to Communications, and billing event emission. End-to-end smoke test runs in CI against in-memory fixtures.
- **Container Apps deployment configuration** referencing ADR-0015's reusable `job-deploy-container-app.yml` workflow. The first deploy target is `ca-hd-notify-cloud-stg` in East US (matching PDR-0002's single-region commitment).

The scaffold packet does **not** include: the Stripe billing adapter implementation (a separate packet — that is its own ADR per PDR-0002's follow-up artifacts), the Web project's full surface (signup flow, billing dashboard — separate packets), the API key authentication middleware in Auth (separate ADR per D12), or any production tenant data. The scaffold proves the contract surface compiles, the canary catches drift, and the in-memory composition runs end-to-end. Production-shape work follows.

## Consequences

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] Grid Multi-Tenant Primitives ADR is Accepted (hard prerequisite per D10).
- [ ] `HoneyDrunk.Notify.Cloud` private repo created with the structure described in D13.
- [ ] `HoneyDrunk.Notify.Cloud.Abstractions 0.1.0` is published (private feed, not public NuGet) with the contracts in D4.
- [ ] `HoneyDrunk.Notify.Cloud 0.1.0` runtime ships with default in-memory composition.
- [ ] `HoneyDrunk.Notify.Cloud.Billing.Stripe 0.1.0` ships as a stub adapter (interface implemented, runtime wiring deferred to its own ADR).
- [ ] `HoneyDrunk.Notify.Cloud.Web 0.1.0` ships as a placeholder web app (health endpoint + signup form scaffold; full surface deferred).
- [ ] Notify Cloud's CI includes the D8 contract-shape canary and it is green.
- [ ] FSL LICENSE files committed to `HoneyDrunk.Notify`, `HoneyDrunk.Notify.Client`'s NuGet metadata, and `HoneyDrunk.Communications`.
- [ ] `repos/HoneyDrunk.Notify.Cloud/` context folder exists in the Architecture repo with the standard five files.
- [ ] `catalogs/nodes.json` carries the new Node entry with `visibility: "private"`; `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/contracts.json`, and `catalogs/modules.json` reflect the stand-up.
- [ ] `constitution/sectors.md` Ops-sector entry includes Notify Cloud.
- [ ] Scope agent flips Status → Accepted and assigns final invariant numbers.

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet — unblocks the following:

- **PDR-0002's Phase 3 (Notify Cloud scaffold, weeks 10–14)** — the package families, contracts, and CI shape are all settled, so the scaffold packet is purely mechanical work.
- **API key authentication pattern ADR** — has a concrete consumer (`INotifyCloudApiKeyStore`) to design against rather than a hypothetical one.
- **Stripe billing integration ADR** — has the `IBillingEventEmitter` provider-slot shape and the `BillingEvent` record to wire against.
- **Communications decision-log persistence ADR** — gains a real production consumer (Notify Cloud Pro tier exposes the decision log) that tightens the requirements on persistence backend choice.
- **Tenant onboarding and provisioning workflow design doc** — has a concrete `INotifyCloudApiKeyStore` and tenant-context model to design the signup-to-API-key flow against.
- **Notify Cloud public launch (PDR-0002 Phase 5, week 16, ~2026-09-15)** — the architectural clearance is complete; remaining work is Stripe integration, marketing site, and beta-tenant onboarding, all of which slot into the architecture this ADR settles.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **The HoneyDrunk Grid's repo default is public; private repos require an explicit ADR-recorded justification under the revenue/compliance/experiment carve-out.** `HoneyDrunk.Notify.Cloud` is the first private repo; its justification is recorded in this ADR D2.
- **Notify Cloud composes Communications, not Notify, for the hot delivery path.** The dependency graph is `Notify Cloud → Communications → Notify`. Direct `Notify Cloud → Notify` calls are restricted to diagnostic and smoke-test paths only. See D5.
- **The `HoneyDrunk.Notify.Client` SDK lives in the open `HoneyDrunk.Notify` repo, not in `HoneyDrunk.Notify.Cloud`.** Customer SDKs covering both self-host and hosted-service consumers ship from the open engine repo regardless of the wrapper's visibility. See D6.
- **API keys are stored only as salted hashes; raw key material is returned to the caller exactly once at issuance time and is never logged, traced, or persisted.** Extension of Invariant 8 to API key material. See D4 and D12.
- **The Notify Cloud Node CI must include a contract-shape canary for `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, and `ApiKeyIssuance`.** Shape drift on any of the four is a build failure. The Kernel multi-tenant primitives consumed by Notify Cloud are guarded by Kernel's canary per ADR-0026. See D8.
- **The open-source repos paired with Notify Cloud (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`) ship under the Functional Source License with two-year auto-conversion to Apache 2.0.** See D11.

### Catalog obligations

`catalogs/nodes.json` does not currently carry an entry for `honeydrunk-notify-cloud`. Adding one introduces the catalog's first `visibility: "private"` Node, which adds a new schema field — the catalog README documents the field's introduction in the same packet. `catalogs/relationships.json` gains the dependency edges in D5; `catalogs/grid-health.json` gains the per-Node row; `catalogs/contracts.json` gains the four contracts (plus `IBillingEventEmitter`); `catalogs/modules.json` gains the four package entries. `constitution/sectors.md` gains a Notify Cloud row in the Ops-sector table.

These reconciliations are tracked in the follow-up work checklist at the top of this ADR.

### Negative

- **Private repo means lower visibility for the wrapper's evolution.** The studio loses the build-in-public marketing surface for half the Notify-Cloud-related work. Mitigation: the engine and Communications repos remain public and carry the architecturally interesting decisions; the wrapper's evolution is reflected in PDRs and ADRs (which are public in `HoneyDrunk.Architecture`) without exposing the implementation.
- **FSL prevents hyperscaler rehosting but also prevents some legitimate use cases.** A consultancy that wants to host Notify for a single client on the client's own infrastructure is technically fine under FSL's "internal use" carve-out, but the boundary cases (an internal Notify deployment offered as a free service inside a larger paid product) require legal interpretation. Mitigation: FSL's two-year Apache conversion neutralizes this concern at the long horizon; for the first two years, the studio handles ambiguous cases on a per-case basis.
- **Adding a new visibility field to `catalogs/nodes.json` is a schema change that ripples to the agents that consume the catalog.** The Hive sync agents, the strategist, and the architect all read `nodes.json`. Mitigation: the new field defaults to `"public"` when absent, so existing agents continue to work without code changes; agents that care about visibility (the human-only labeller, repo-creation automation) read it explicitly.
- **The wrapper depends on the Grid Multi-Tenant Primitives ADR being Accepted first.** If that ADR slips, this one slips with it. Mitigation: the two ADRs are drafted in parallel and reviewed together; the multi-tenant primitives are sized as a Grid-wide decision rather than a Notify-Cloud-only decision precisely because the parallel-drafting pressure caught the boundary call early.
- **No `Testing` package at stand-up means the in-memory fixtures are reusable only by Notify Cloud's own tests until a second consumer emerges.** This is a deliberate scope cut (D3) — the Grid does not have a known second consumer of Notify Cloud's contracts, so shipping a separate `Testing` package now is speculative. If a second consumer materializes, the fixtures get cut into a `HoneyDrunk.Notify.Cloud.Testing` package without breaking changes.
- **Choosing FSL forecloses (for two years) some open-source-purist contributors who require Apache or MIT.** Mitigation: the buyer profile in PDR-0002 §B is not OSS-purist; it is "indie .NET dev who wants to ship." The OSS audience that cares about license purity is a smaller subset than the audience that cares about whether the engine is readable and self-hostable, and FSL satisfies the latter.

## Alternatives Considered

### Make `HoneyDrunk.Notify.Cloud` public like every other Grid repo

Rejected. The repo carries customer-data-adjacent infrastructure (tenant isolation enforcement, abuse heuristics, billing logic) that has zero educational value as OSS and would invite a hyperscaler-style rehosting competitor. The studio's repo posture has an explicit revenue/compliance/experiment carve-out (memory rule), and Notify Cloud sits squarely in it. The open-engine + private-wrapper split (D11's open core stance, plus this ADR's D2 visibility decision) puts the moat in operational economics, not in source-code secrecy. Making the wrapper public would surrender that moat without producing any meaningful community-contribution upside.

### Bundle the wrapper into the existing `HoneyDrunk.Notify` repo as a `HoneyDrunk.Notify.Cloud` sub-package

Rejected. Multiple reasons: (a) the wrapper is private and the engine is public, so combining them into one repo forces the entire repo private and surrenders the open-engine wedge; (b) release cadences differ — the wrapper iterates on pricing, billing, and tenant management on a much higher tempo than the engine's delivery pipeline (PDR-0002 §M); (c) the boundary integrity argument that ADR-0019 made for separating Communications from Notify applies again here — the wrapper's commercial concerns and the engine's delivery concerns should not co-mingle in one solution.

### Choose Business Source License (BSL) instead of Functional Source License (FSL)

Rejected after evaluation. Both licenses produce the same commercially load-bearing protection (block hyperscaler rehosting). The trade is configurability vs. simplicity: BSL is per-release configurable (Change Date, Change License), FSL is a single global default (two years, Apache). For a solo developer with no legal counsel, the simpler default wins. Sentry's precedent is also closer to Notify Cloud's buyer profile than HashiCorp's. The decision is reversible if FSL produces a concrete friction during the v1 launch — relicensing FSL → BSL is mechanical (it's the same competitor restriction repackaged), while relicensing FSL → MIT or MIT → FSL is the difficult direction (forward-only).

### Defer the OSS license decision to a separate ADR after Notify Cloud launch

Rejected. PDR-0002 §M explicitly puts the license decision in the Notify Cloud standup ADR (this one). Deferring beyond stand-up means the engine repos carry no LICENSE file at the moment Notify Cloud customers first read the marketing site, which makes "Notify is open source" an unsupported claim. Picking now (FSL, per D11) means the first commercial customer reads a stable license. Later relicensing is hostile to early contributors who reasonably expected the license to remain stable.

### Ship a `HoneyDrunk.Notify.Cloud.Testing` package at stand-up

Rejected. No second consumer of Notify Cloud's contracts exists in the Grid (it is a leaf Node — D9). A speculative `Testing` package adds a release artifact and a versioning surface for fixtures that today only Notify Cloud's own test project consumes. The fixtures live `internal` to the runtime project's test project until a real second consumer emerges, at which point cutting the package is a non-breaking change. This is a deliberate departure from ADR-0017's pattern (Capabilities ships `Testing` at stand-up) — the difference is that Capabilities had immediate downstream consumers (Agents, Operator, Evals) who needed deterministic fixtures, while Notify Cloud has none.

### Define `TenantId`, `BillingEvent`, and `IBillingEventEmitter` in `HoneyDrunk.Notify.Cloud.Abstractions`

Rejected. These are Grid-wide primitives consumed by Notify, Communications, Vault, Pulse, and any future commercial wrapper. Putting them in the Cloud Abstractions package would force every other Node that participates in tenancy or billing to take a runtime dependency on the Cloud Abstractions package, which is a private-repo package and an inversion of the dependency direction (the Cloud Node sits *above* Notify and Communications, so Notify cannot transitively reference it). ADR-0026 (Grid Multi-Tenant Primitives) puts `TenantId`, `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, and `BillingEvent` in `HoneyDrunk.Kernel.Abstractions.Tenancy`, where they belong as foundational primitives. Notify Cloud is the first real consumer; future commercial wrappers (if any) inherit the same primitives.

### Have Notify Cloud call Notify directly, bypassing Communications

Rejected. PDR-0002 §D names the Pro-tier wedge as Communications's preference / cadence / decision-log surface. Bypassing Communications turns Notify Cloud into "SendGrid + Twilio repackaged" (PDR-0002 Option 6, also rejected at the PDR level). The dependency graph `Notify Cloud → Communications → Notify` is the architectural commitment that makes the Pro tier coherent. Diagnostic and smoke-test paths may call Notify directly; the hot path goes through Communications (D5).

### Skip the contract-shape canary at stand-up

Rejected. The four frozen contracts are the hot path for Notify Cloud's internal composition (runtime + Stripe billing + web app + future billing providers). ADR-0016 D8, ADR-0017 D8, and ADR-0019 D8 established contract-shape canaries as a stand-up-time gating requirement; the same reasoning applies here. Skipping it means the first breaking change on `INotifyCloudGateway` or `INotifyCloudApiKeyStore` is discovered in a production failure, not at Notify Cloud's CI.
