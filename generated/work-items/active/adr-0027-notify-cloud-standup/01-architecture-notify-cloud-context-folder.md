---
name: Architecture Context Folder Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ops", "adr-0027"]
dependencies: []
adrs: ["ADR-0027"]
accepts: ADR-0027
wave: 1
initiative: adr-0027-notify-cloud-standup
node: honeydrunk-notify-cloud
---

# Chore: Register HoneyDrunk.Notify.Cloud's standup decisions in Architecture context folder

## Summary
Create the standard `repos/HoneyDrunk.Notify.Cloud/` context folder with five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`) matching the template used by `repos/HoneyDrunk.Communications/`. Update `constitution/sectors.md` Ops-sector entry to include Notify Cloud as the commercial wrapper above Notify and Communications. **Do not touch `catalogs/*.json`, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, or `adrs/README.md`** — hive-sync reconciles those shared indexes after the initiative completes.

ADR-0027 stays at `Status: Proposed` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the entire initiative completes, per the user's standing ADR acceptance workflow. This packet's body does not edit the ADR header.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0027 is the standup ADR for `HoneyDrunk.Notify.Cloud` — the Grid's first commercial-revenue-bearing Node, its first private repo, and the first real (non-noop) consumer of ADR-0026's multi-tenant primitives. The ADR has been written but the Architecture repo carries no `repos/HoneyDrunk.Notify.Cloud/` context folder yet. Until that exists, downstream agents scoping their own work against Notify Cloud (the Stripe billing-adapter follow-up, the API key authentication ADR, the Communications decision-log persistence ADR, any future tool-registering domain Node) read incomplete metadata.

This packet creates the standard five-file context folder. The shapes and section headings mirror `repos/HoneyDrunk.Communications/` (the most recent Ops-sector standup) so the two repos diff-read side-by-side. Content is derived directly from ADR-0027's D1–D13 — no new design choices are introduced.

The packet also updates `constitution/sectors.md` so the Ops sector's published members list includes Notify Cloud.

What this packet explicitly does **not** do:

- **Catalog reconciliation.** `catalogs/nodes.json` (introducing the new `visibility: "private"` field), `catalogs/relationships.json` (the dependency edges from ADR-0027 D5), `catalogs/grid-health.json` (the per-Node row), `catalogs/contracts.json` (the four D4 contracts plus the consumed Kernel primitives), and `catalogs/modules.json` (the four package entries) are **deferred to the hive-sync agent's reconciliation pass** after the initiative completes. Per the user's standing instruction, scope agent does not touch shared catalog indexes.
- **Initiative-list / ADR-index reconciliation.** `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, and `adrs/README.md` are also hive-sync-reconciled — this packet does not edit them.
- **ADR Status flip.** ADR-0027 stays at `Status: Proposed`. The flip happens post-merge as a separate housekeeping step.

## Proposed Implementation

### `repos/HoneyDrunk.Notify.Cloud/overview.md` — new file

```markdown
# HoneyDrunk.Notify.Cloud - Overview

**Sector:** Ops
**Version:** 0.0.0 (pre-scaffold)
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud` (**private** — first private repo in the Grid; explicit revenue carve-out per ADR-0027 D2)

## Purpose

Multi-tenant commercial wrapper above the open-source Notify engine and the Communications orchestration layer. Notify Cloud accepts external API requests, authenticates them by API key, applies per-tenant rate limits and quota checks, attaches the resolved `TenantId` to the request, delegates orchestration to `ICommunicationOrchestrator`, and emits a `BillingEvent` on each successful delivery for Stripe to consume.

It is a commercial wrapper, not a delivery engine. It does not call provider SDKs, render templates, manage queues, retry sends, or decide which user receives which message. Those mechanics stay in Notify and Communications.

Grid-internal callers continue to use Notify (and Communications) directly. Notify Cloud does not interpose on the internal path. Internal callers acquire their `TenantId` (defaulting to `TenantId.Internal`) through the Grid's existing `IGridContext` and never traverse a Notify Cloud surface.

## Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Notify.Cloud.Abstractions` | Abstractions | Notify-Cloud-specific contracts only (4 surfaces). Kernel multi-tenant primitives are consumed from `HoneyDrunk.Kernel.Abstractions.Tenancy`, not redeclared here. |
| `HoneyDrunk.Notify.Cloud` | Runtime | Default `INotifyCloudGateway`, API key validation middleware, Notify-Cloud-specific `ITenantRateLimitPolicy` (replaces Kernel's `NoopTenantRateLimitPolicy`), billing-event emission tail, DI wiring. |
| `HoneyDrunk.Notify.Cloud.Billing.Stripe` | Provider | Stripe-specific `IBillingEventEmitter` adapter for metered-billing webhook bridge. Provider-slot pattern. |
| `HoneyDrunk.Notify.Cloud.Web` | Hosting | Multi-tenant management website (signup, billing, API key issuance, basic delivery logs). |

## Key Contracts

- `INotifyCloudGateway` — top-level entry point. Given an API-key-authenticated external request, resolves the tenant context, consults `ITenantRateLimitPolicy` (from Kernel), delegates orchestration to `ICommunicationOrchestrator`, and emits a `BillingEvent` on successful delivery.
- `INotifyCloudApiKeyStore` — issuance and validation of per-tenant API keys. Issued keys returned plaintext exactly once at issuance; stored only as salted hashes; never logged, traced, or persisted in raw form.
- `NotifyCloudTenantTier` — record. Notify-Cloud-specific tenant-tier descriptor (tier name `Free` / `Starter` / `Pro`, events-per-month ceiling, channels enabled, BYO-provider-key allowance). Value type, no `I` prefix per the Grid-wide naming rule.
- `ApiKeyIssuance` — record. Returned exactly once at API key issuance — plaintext key (only at this moment), key id, bound tenant, issued-at timestamp. Never persisted in this shape; the runtime persists only the salted hash and the metadata.

## Primitives Consumed (not redefined)

Per ADR-0026, the following Kernel primitives are consumed by Notify Cloud:

- `TenantId` and `TenantId.Internal` sentinel — live in `HoneyDrunk.Kernel.Abstractions.Identity` (ULID-backed `readonly record struct` per ADR-0026 D1). **Referenced directly by the four D4 contracts** in `HoneyDrunk.Notify.Cloud.Abstractions` — the Abstractions package PackageReferences `HoneyDrunk.Kernel.Abstractions` for this one type per ADR-0027 D3's explicit carve-out.
- `ITenantRateLimitPolicy` and `TenantRateLimitDecision` — live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. Consumed at the runtime layer (`HoneyDrunk.Notify.Cloud`), not in Abstractions. Notify Cloud ships a tier-driven implementation that replaces the `NoopTenantRateLimitPolicy` registration at host time.
- `IBillingEventEmitter` and `BillingEvent` — live in `HoneyDrunk.Kernel.Abstractions.Tenancy`. Consumed at the runtime layer. Notify Cloud ships the Stripe implementation in `HoneyDrunk.Notify.Cloud.Billing.Stripe`.

## Visibility and Licensing

`HoneyDrunk.Notify.Cloud` is **private** — the first private repo in the Grid, justified by ADR-0027 D2's revenue carve-out (customer-data-adjacent infrastructure, hyperscaler defense, billing-system integrity).

The repo's LICENSE is `LicenseRef-Proprietary` (all rights reserved by default of being private). The paired open-source repos (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`) ship under the Functional Source License (FSL) with two-year auto-conversion to Apache 2.0, per ADR-0027 D11.

The customer-facing SDK (`HoneyDrunk.Notify.Client`) lives in the open `HoneyDrunk.Notify` repo per ADR-0027 D6, not in this private repo. Customers install the SDK from NuGet without ever needing access to the wrapper's source.

## Deployment

- **Hosting platform:** Azure Container Apps (`ca-hd-notify-cloud-{env}`), per invariant 34.
- **First deploy target:** `ca-hd-notify-cloud-stg` in East US (PDR-0002's single-region commitment).
- **Container Registry:** the shared `acrhdshared{env}` per invariant 35.
- **Environment:** the shared `cae-hd-{env}` per invariant 35.
```

### `repos/HoneyDrunk.Notify.Cloud/boundaries.md` — new file

```markdown
# HoneyDrunk.Notify.Cloud - Boundaries

What Notify Cloud owns and does not own. Mirrors the boundary-discipline pattern from `repos/HoneyDrunk.Communications/boundaries.md`.

## What Notify Cloud Owns

- Multi-tenant commercial-product primitives for the Notify engine — the API gateway, API key issuance and validation (issuance is here; validation delegates to Auth per ADR-0027 D12), per-tenant rate-limit enforcement, tenant-scoped billing event emission, and the tenant management website.
- The Notify-Cloud-specific `ITenantRateLimitPolicy` implementation (replaces Kernel's `NoopTenantRateLimitPolicy` at host time).
- The Stripe `IBillingEventEmitter` adapter (in `HoneyDrunk.Notify.Cloud.Billing.Stripe`).
- The management web app (signup, billing, API key issuance UI, basic delivery logs) — placeholder shape at v0.1.0; full surface lands in follow-up packets.
- The four frozen contracts in `HoneyDrunk.Notify.Cloud.Abstractions`: `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance`.

## What Notify Cloud Does NOT Own

- **Delivery mechanics.** Provider SDK calls (Resend, Twilio), template rendering, queue management, send retries — all stay in Notify.
- **Decision logic.** Whether a given recipient should receive a given message, when, or as part of what sequence — all in Communications.
- **Multi-tenant primitives.** `TenantId`, `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` — all in `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026.
- **API key validation.** Validation is delegated to `HoneyDrunk.Auth`'s new `IApiKeyAuthenticator` middleware path (per ADR-0027 D12). Notify Cloud issues keys (a tenant lifecycle event); Auth validates them (a trust-boundary concern). The detailed middleware shape, hashing scheme, and rotation flow are a separate follow-up ADR.
- **The customer-facing SDK.** `HoneyDrunk.Notify.Client` lives in the open `HoneyDrunk.Notify` repo per ADR-0027 D6. Customers install it from NuGet without access to Notify Cloud source.
- **Internal Grid messaging.** Grid-internal callers use Notify and Communications directly; they do not traverse Notify Cloud. Internal callers acquire their `TenantId` (defaulting to `TenantId.Internal`) through `IGridContext`.

## Decision Test — For Any Concern in the Notify Cloud Path

1. Is it tenant-context resolution, API key authentication, per-tenant rate-limit enforcement, billing-event emission, or external-API surface shape? → **Notify Cloud**.
2. Is it a decision about *whether* a given user should receive a given message, or *when*, or as part of *what sequence*? → **Communications**.
3. Is it provider-side delivery (calling Resend, calling Twilio, retrying a transient failure)? → **Notify**.
4. Is it tenant-aware, but Grid-wide (not commercial-wrapper-specific)? → **Kernel** (the multi-tenant primitives).
5. Is it API key validation as opposed to issuance? → **Auth** (`IApiKeyAuthenticator` middleware path).

## Dependency Direction (Strict, One-Way)

```
Notify Cloud
  ├─ consumes ──► Communications (ICommunicationOrchestrator) — orchestration delegate (hot path)
  ├─ consumes ──► Notify (INotificationSender) — diagnostic/smoke-test paths only; hot path is Notify Cloud → Communications → Notify
  ├─ consumes ──► Auth (IApiKeyAuthenticator middleware path — new)
  ├─ consumes ──► Vault (per-tenant secret scoping)
  ├─ consumes ──► Web.Rest (response envelopes, correlation IDs)
  ├─ consumes ──► Kernel (IGridContext, lifecycle, telemetry, TenantId)
  └─ emits telemetry ──► Pulse (no runtime dependency; one-way emission per ADR-0027 D7)
```

Notify Cloud does **not** import Notify directly except through `INotificationSender` for diagnostic / smoke-test paths. The hot path is Notify Cloud → Communications → Notify. Notify Cloud does **not** consume HoneyHub, any AI-sector Node, or any package outside the Ops/Core/Infrastructure sectors at v1.

### Invariant-2 exception: `HoneyDrunk.Vault` runtime reference

`HoneyDrunk.Notify.Cloud` (runtime) PackageReferences `HoneyDrunk.Vault` (runtime) for `ISecretStore` and `IConfigProvider`. This is an acknowledged exception to invariant 2 ("Runtime packages depend on Abstractions, never on other runtime packages at the same layer"). The exception is grounded:

- The Vault repo does not currently split a separate `HoneyDrunk.Vault.Abstractions` package — the `ISecretStore` / `IConfigProvider` interfaces live in the runtime `HoneyDrunk.Vault` package per the existing repo shape.
- This is a Grid-wide acknowledged special case (the same exception is documented on every Node that consumes Vault — Auth, Communications, Data, etc.).
- The path-forward is the Vault.Abstractions carve-out (separate follow-up packet, not bundled with this Node's stand-up). When that follow-up lands, every Vault-consuming Node migrates simultaneously.

Until that carve-out lands, Notify Cloud's runtime PackageReference to `HoneyDrunk.Vault` is the established Grid pattern and is **not** an invariant-2 violation.
```

### `repos/HoneyDrunk.Notify.Cloud/invariants.md` — new file

```markdown
# HoneyDrunk.Notify.Cloud - Local Invariants

Repo-scoped invariants supplementing `constitution/invariants.md`. The constitutional invariants from ADR-0027 (assigned numbers locked by packet 02 of the adr-0027-notify-cloud-standup initiative) also apply.

1. **HoneyDrunk.Notify.Cloud.Abstractions runtime dependencies are limited to the three packages ADR-0027 D3 explicitly permits.** Per ADR-0027 D3: "Zero runtime dependencies beyond `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Notify.Abstractions`, and `HoneyDrunk.Communications.Abstractions`." `HoneyDrunk.Kernel.Abstractions` is load-bearing at v0.1.0 — it carries the `TenantId` strong type (record-struct from `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1) that the four frozen contracts (`INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance`) consume as field types. The other two (`HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Communications.Abstractions`) are permitted by D3 but may be omitted at v0.1.0 if no contract consumes them — they stay reserved for future contract surfaces. The strict-Abstractions stance from sibling ADR-0016 / ADR-0017 standup packets does NOT apply here; this Node's contracts deliberately consume Kernel-Abstractions primitives. **`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` are NOT redeclared here** — they live in `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026 and are consumed at the runtime layer, not at the Notify-Cloud-Abstractions layer.

2. **The hot delivery path is Notify Cloud → Communications → Notify.** Direct calls from Notify Cloud to Notify (`INotificationSender`) are restricted to diagnostic and smoke-test paths only — never the customer-facing hot path. The hot path always goes through `ICommunicationOrchestrator`.

3. **API keys are stored only as salted hashes; raw key material is returned exactly once at issuance time.** No raw key is ever logged, traced, persisted in raw form, or returned in any subsequent API call. `ApiKeyIssuance` is the one-time issuance shape; subsequent reads return only the hash and metadata.

4. **Every tool/external invocation passes through `INotifyCloudGateway`.** No bypass surface from external callers exists. The gateway is the single intake point that performs API key validation → rate-limit check → tenant context resolution → orchestration delegation → billing emission. New entry-point surfaces require an ADR.

5. **Token costs, tenant tiers, and abuse heuristics are sourced from configuration (App Configuration via `IConfigProvider` from Vault), never hardcoded.** Hardcoded values in application code are a build failure. Operator-driven config refresh is the rotation path.

6. **GridContext / CorrelationId propagation lives in the runtime package's `NotifyCloudTelemetry`, not in Abstractions.** Per ADR-0026 D1, `TenantId` IS a Kernel-Abstractions primitive and the four D4 contracts use the strong type — but `CorrelationId` stays string-typed at the contract boundary at v0.1.0 because promoting the Kernel `CorrelationId` record-struct into a public Abstractions surface is a Grid-wide decision separate from this Node's stand-up. `INotifyCloudGateway`'s request shape uses string-typed `CallerCorrelationId` (the string mirror); the runtime's `DefaultNotifyCloudGateway` reconciles the string against the ambient `IGridContext.CorrelationId`. `NotifyCloudGatewayRequest.TenantIdHint`, by contrast, uses the strong `TenantId` type per ADR-0026.

7. **Tenant identifiers attached to telemetry are direct (not bucketed) at v1.** Per ADR-0027 D7's low-cardinality bound. Tens of paying customers at v1, low hundreds at the Pro ceiling — `tenant_id` is a safe label for direct emission. If Notify Cloud crosses into thousands of paying tenants, this discipline is revisited as a follow-up ADR (cardinality bucketing or tag rollup).

8. **Cross-Node canaries cover the four frozen contract surfaces.** Contract-shape canary in CI fails the build if `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, or `ApiKeyIssuance` change shape without a version bump. Kernel primitives consumed here are covered by Kernel's own canary per ADR-0026.

_Constitutional invariants from ADR-0027 (assigned numbers locked at packet 02 of adr-0027-notify-cloud-standup) also apply — see `constitution/invariants.md`._
```

### `repos/HoneyDrunk.Notify.Cloud/active-work.md` — new file

```markdown
# HoneyDrunk.Notify.Cloud - Active Work

Tracking surface for in-flight work on the Notify Cloud Node. Mirrors the format used by `repos/HoneyDrunk.Communications/active-work.md`.

## Status

**Pre-scaffold.** The GitHub repo does not exist yet. The local working tree does not exist yet. The packages have not been authored. ADR-0027 (the standup ADR) is Proposed; the scope agent flips Status → Accepted after the entire adr-0027-notify-cloud-standup initiative's PRs merge.

## In Progress

- **adr-0027-notify-cloud-standup initiative** — six packets from the dispatch plan at `generated/work-items/active/adr-0027-notify-cloud-standup/dispatch-plan.md`. Tracks: context-folder registration (this file), constitution invariants, FSL on Notify, FSL on Communications, private repo creation (human-only), repo scaffold.

## Follow-Up Work (post-stand-up)

Each item below is its own future ADR or packet, sized after the stand-up lands:

- **Stripe billing integration.** The `HoneyDrunk.Notify.Cloud.Billing.Stripe 0.1.0` package ships as a stub in the scaffold packet. The actual webhook bridge / metered-billing wiring is a separate ADR per PDR-0002's recommended follow-up artifacts.
- **API key authentication ADR.** Per ADR-0027 D12. Validation is delegated to `HoneyDrunk.Auth`'s new `IApiKeyAuthenticator` middleware path; the detailed middleware shape, hashing scheme, and rotation flow are settled in a separate ADR.
- **Communications decision-log persistence ADR.** Notify Cloud Pro tier exposes the decision log; that tightens the requirements on the persistence backend.
- **Tenant onboarding and provisioning workflow design doc.** Has a concrete `INotifyCloudApiKeyStore` and tenant-context model to design the signup-to-API-key flow against.
- **Full Web project surface.** Signup flow, billing dashboard, delivery logs, tenant management UI.
- **Per-tenant AI cost rollups** (deferred to whichever Node first commercializes inference per ADR-0026 D10 / PDR-0002).
- **Multi-region deployment** (deferred per PDR-0002 Phase 5 commitment to single-region East US at v1).

## Active Blockers

- GitHub repo `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud` does not exist yet (Architecture#NN — packet 05 of the adr-0027-notify-cloud-standup initiative)
- Scaffold packet (NotifyCloud#NN — packet 06 of the adr-0027-notify-cloud-standup initiative) not yet executed
- Constitution invariants for ADR-0027 D2/D5/D6/D4+D12/D8/D11 not yet landed at final numbers (Architecture#NN — packet 02)
```

### `repos/HoneyDrunk.Notify.Cloud/integration-points.md` — new file

```markdown
# HoneyDrunk.Notify.Cloud - Integration Points

How Notify Cloud connects to the rest of the Grid. Every item here represents a cross-Node boundary that requires a canary test or contract-shape discipline.

## Consumes

| Node | Contract | Purpose |
|------|----------|---------|
| **Kernel** | `IGridContext`, `INodeContext`, `IOperationContext` | Every gateway entry, key validation, rate-limit check, send delegation, and billing event runs inside a Grid context. |
| **Kernel** | `TenantId`, `TenantId.Internal` | Tenant-context resolution and propagation. External requests resolve to an external `TenantId` ULID; the internal Grid path defaults to `TenantId.Internal`. |
| **Kernel** | `ITenantRateLimitPolicy`, `TenantRateLimitDecision` | Notify Cloud ships a tier-driven implementation in the runtime package that replaces Kernel's `NoopTenantRateLimitPolicy` at host time. |
| **Kernel** | `IBillingEventEmitter`, `BillingEvent` | Notify Cloud ships the Stripe implementation in `HoneyDrunk.Notify.Cloud.Billing.Stripe`. |
| **Kernel** | `IStartupHook`, `IShutdownHook` | Gateway initialization at startup; graceful drain on shutdown. |
| **Kernel** | `ITelemetryActivityFactory` | Emits per-call activities for gateway entry, key validation, rate-limit check, send delegation, billing event. |
| **Communications** | `ICommunicationOrchestrator`, `IMessageIntent` | The hot path delegate. Notify Cloud resolves tenant context, then hands the orchestration call to Communications. |
| **Notify** | `INotificationSender` | Diagnostic and smoke-test paths only — never the customer-facing hot path. |
| **Auth** | `IApiKeyAuthenticator` (new — added by a follow-up ADR) | Validates inbound API keys. Notify Cloud issues keys; Auth validates them. |
| **Vault** | `ISecretStore` | Per-tenant secret scoping using the `TenantScopedSecretResolver` pattern from invariant 9a. Also sources cost-rate tables, tenant-tier definitions, and abuse heuristics from App Configuration via `IConfigProvider`. |
| **Web.Rest** | Response envelopes, correlation headers | Standard Grid HTTP shape for the external API. |

## Exposes

| Contract | Consumer | Notes |
|----------|---------|-------|
| `INotifyCloudGateway` | Notify Cloud Web (`HoneyDrunk.Notify.Cloud.Web`), future external integrations | Top-level entry — API key auth → rate-limit → tenant context → orchestration delegate → billing emission. |
| `INotifyCloudApiKeyStore` | Notify Cloud Web (issuance flow), Auth (validation lookup) | Salted-hash storage; raw keys returned exactly once via `ApiKeyIssuance` at issuance time. |
| `NotifyCloudTenantTier` | Notify Cloud runtime (rate-limit policy derivation), Notify Cloud Web (tier upgrade flow) | Value-type tier descriptor. |
| `ApiKeyIssuance` | Issuance callers | One-time issuance shape — carries plaintext key only at the moment of issuance. |

## Emits (no runtime dependency)

| Signal | Consumer | Notes |
|--------|----------|-------|
| Gateway / validation / rate-limit / delegation / billing activities | **Pulse** | Emitted via Kernel's `ITelemetryActivityFactory`. `tenant_id` is attached directly as a low-cardinality label per ADR-0027 D7. API keys, raw secrets, message payloads, and recipient PII are **never** emitted (invariant 8 extended to API key material). |
| `BillingEvent` per successful delivery | Stripe (via `HoneyDrunk.Notify.Cloud.Billing.Stripe` adapter implementing the Kernel `IBillingEventEmitter` interface) | Webhook bridge details deferred to the Stripe billing integration ADR. |

## Customer-Facing Surface (External)

The REST API is the public boundary external customers consume. Internally, the wrapper composes against the four exposed contracts; externally, customers see only the REST shape and the `HoneyDrunk.Notify.Client` SDK (which lives in the open `HoneyDrunk.Notify` repo, not here, per ADR-0027 D6).

## Canary Coverage Required

Before any Notify Cloud code can be considered production-ready:

- `NotifyCloud.Canary` → Kernel: verifies `IGridContext` flows through gateway/validation/dispatch, CorrelationId is propagated to delegated orchestration calls, `TenantId` defaults to `TenantId.Internal` when no external tenant is resolved.
- `NotifyCloud.Canary` → Communications: verifies `ICommunicationOrchestrator` is invoked with a populated `MessageIntent`, that the decision-log entry is recorded, and that delegated delivery returns to Notify Cloud for billing emission.
- `NotifyCloud.Canary` → Auth: verifies `IApiKeyAuthenticator` is called with the raw API key from the request header, that an invalid key short-circuits with a 401, and that a valid key produces the bound `TenantId` for downstream resolution.
- `NotifyCloud.Canary` → Kernel multi-tenant primitives: verifies the Notify-Cloud-specific `ITenantRateLimitPolicy` implementation correctly derives limits from `NotifyCloudTenantTier` and that `IBillingEventEmitter` emits a `BillingEvent` exactly once per successful delivery.
- `NotifyCloud.Canary` → contract-shape: contract-shape canary in CI fails the build if `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, or `ApiKeyIssuance` change shape without a version bump (ADR-0027 D8 / contract-shape-canary invariant — number assigned at packet 02 of this initiative).

## Dependency Order for Bring-Up

Notify Cloud cannot be scaffolded until these Nodes have published their Abstractions packages:

1. Kernel (already Live — `HoneyDrunk.Kernel.Abstractions` stable, includes ADR-0026 tenancy primitives)
2. Communications (already Live — `HoneyDrunk.Communications.Abstractions` at 0.2.0)
3. Notify (already Live — `HoneyDrunk.Notify.Abstractions` at 0.3.0)
4. Auth (already Live — `HoneyDrunk.Auth.Abstractions` stable; `IApiKeyAuthenticator` middleware lands in a follow-up ADR, but the Auth Node itself is up)
5. Vault (already Live — `HoneyDrunk.Vault` stable)
6. Web.Rest (already Live — `HoneyDrunk.Web.Rest.AspNetCore` stable)

Notify Cloud is a leaf in the Grid-internal dependency graph per ADR-0027 D9 — no Grid-internal Node consumes it. Its consumers are external customers via REST API or the `HoneyDrunk.Notify.Client` SDK.
```

### `constitution/sectors.md` — Ops-sector entry update

The current Ops-sector entry must include Notify Cloud. Locate the Ops-sector row/block (header text typically reads `## Ops Sector` or similar; the file structure mirrors the AI-sector entry's pattern) and add an entry for HoneyDrunk.Notify.Cloud directly after HoneyDrunk.Communications. Suggested text:

```markdown
| **HoneyDrunk.Notify.Cloud** | private | First commercial Node (PDR-0002 implementation). Multi-tenant commercial wrapper above Notify and Communications — API gateway, API key issuance/validation, per-tenant rate limits, tenant-scoped billing-event emission, management website. Sits above Notify and Communications; does not interpose on Grid-internal callers. ADR-0027. |
```

If the file uses a list rather than a table, adapt the entry shape to match the existing format. The substantive content (commercial wrapper, four primitives owned, sits above Notify and Communications, ADR-0027 reference, private visibility) must be present in some form.

### `CHANGELOG.md` (Architecture repo)

Append to the in-progress version entry (do not start a new `Unreleased` block — per the user's standing rule, no commits land under `Unreleased`; move to a dated versioned section with a SemVer bump before commit):

`Architecture: Register HoneyDrunk.Notify.Cloud standup decisions in the Architecture context folder (new repos/HoneyDrunk.Notify.Cloud/ folder with five files: overview.md, boundaries.md, invariants.md, active-work.md, integration-points.md — all derived from ADR-0027 D1-D13). Update constitution/sectors.md Ops-sector entry to include Notify Cloud as the commercial wrapper above Notify and Communications. Does NOT touch catalogs/*.json, initiatives/*, or adrs/README.md — hive-sync reconciles those after the initiative completes. ADR-0027 stays Proposed in this packet — the Status flip is a separate post-merge housekeeping step.`

## Affected Files
- `repos/HoneyDrunk.Notify.Cloud/overview.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/boundaries.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/invariants.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/active-work.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/integration-points.md` (new file)
- `constitution/sectors.md`
- `CHANGELOG.md`

`adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md` is **not** modified by this packet. Its Status header stays `Proposed`. `adrs/README.md`, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/contracts.json`, `catalogs/modules.json` are all **explicitly NOT** edited by this packet — hive-sync reconciles those.

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits are inside the `HoneyDrunk.Architecture` repo.
- [x] No code changes anywhere; metadata only.
- [x] No contract bodies invented in this packet — content is derived directly from ADR-0027 D1-D13.
- [x] Records lose the `I` prefix (`NotifyCloudTenantTier`, `ApiKeyIssuance`); interfaces keep it (`INotifyCloudGateway`, `INotifyCloudApiKeyStore`) per the Grid-wide naming rule.
- [x] No edits to shared index files (`catalogs/*.json`, `initiatives/*`, `adrs/README.md`) — these are reconciled by hive-sync.
- [x] No edits to `adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md`. The Status flip is a separate post-merge housekeeping step.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Notify.Cloud/overview.md` exists with the structure described above. Visibility is documented as private with explicit reference to ADR-0027 D2 revenue carve-out.
- [ ] `repos/HoneyDrunk.Notify.Cloud/overview.md` Key Contracts section lists exactly four contracts: `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance`. Records have no `I` prefix; interfaces keep it.
- [ ] `repos/HoneyDrunk.Notify.Cloud/overview.md` Primitives Consumed section lists `TenantId` as consumed from `HoneyDrunk.Kernel.Abstractions.Identity` (ADR-0026 D1) and `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` as consumed from `HoneyDrunk.Kernel.Abstractions.Tenancy` per ADR-0026. None of the five are **declared** in Notify Cloud's own Abstractions package; `TenantId` is **referenced** as a field type (the Abstractions package PackageReferences `HoneyDrunk.Kernel.Abstractions` per ADR-0027 D3).
- [ ] `repos/HoneyDrunk.Notify.Cloud/boundaries.md` exists with What Notify Cloud Owns / Does Not Own sections, the five-question Decision Test, and the dependency-direction block matching ADR-0027 D5.
- [ ] `repos/HoneyDrunk.Notify.Cloud/invariants.md` exists with at least eight local invariants covering: zero HoneyDrunk dependencies in Abstractions, hot path through Communications, API key salted-hash storage, gateway as single intake point, config-sourced rates/tiers/heuristics, runtime-localized GridContext propagation, low-cardinality `tenant_id` discipline, contract-shape canary discipline.
- [ ] `repos/HoneyDrunk.Notify.Cloud/active-work.md` exists with Status, In Progress, Follow-Up Work, and Active Blockers sections — substantively matching the template above.
- [ ] `repos/HoneyDrunk.Notify.Cloud/integration-points.md` exists with Consumes / Exposes / Emits / Canary Coverage Required / Dependency Order for Bring-Up sections — substantively matching the template above. Emits section notes that `tenant_id` is a low-cardinality label per ADR-0027 D7, and that API keys / raw secrets / payloads / PII are never emitted (invariant 8 extension).
- [ ] `constitution/sectors.md` Ops-sector entry includes HoneyDrunk.Notify.Cloud. Visibility is documented as private. Description names it as the commercial wrapper above Notify and Communications. ADR-0027 is referenced.
- [ ] `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/contracts.json`, `catalogs/modules.json` are **not** modified by this packet. Confirm in diff. (These reconcile via hive-sync.)
- [ ] `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `adrs/README.md` are **not** modified by this packet. Confirm in diff.
- [ ] `adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md` is **not** modified by this packet. (Verify in diff. The Status flip is deferred to post-merge housekeeping.)
- [ ] `CHANGELOG.md` updated. Per the user's standing rule, the entry lands in the next dated versioned section with a SemVer bump if this is the first commit of that version; otherwise appends to the existing in-progress version entry. No commits land under `## [Unreleased]`.
- [ ] PR body explicitly notes: (a) `repos/HoneyDrunk.Notify.Cloud/` is a new five-file context folder derived from ADR-0027 D1-D13, (b) ADR-0027 stays at `Status: Proposed` — the flip is a separate post-merge housekeeping step, (c) catalog and initiative-index reconciliation are deferred to hive-sync.

## Human Prerequisites
- [ ] None. ADR-0026 prerequisite is satisfied (Status: Accepted as of 2026-05-20). The packet does not require any Azure portal, GitHub UI, or external-system action.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted. — **ADR-0027 D3 carves out three explicit exceptions for `HoneyDrunk.Notify.Cloud.Abstractions`:** `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Communications.Abstractions`. The local invariant 1 in `repos/HoneyDrunk.Notify.Cloud/invariants.md` restates this carve-out; the overview's Primitives Consumed section makes clear that `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` are consumed at the runtime layer (not in Abstractions), while `TenantId` is referenced as a contract field type via the permitted `HoneyDrunk.Kernel.Abstractions` PackageReference per ADR-0026 D1.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. — Extended in `repos/HoneyDrunk.Notify.Cloud/invariants.md` invariant 3 to cover API key material: no raw key is ever logged, traced, persisted in raw form, or returned in any subsequent API call.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Notify Cloud is its own Node, hence its own repo (created by packet 05).

> **Invariant 39:** Tenant mechanics stay at intake and post-dispatch boundaries. Tenant resolution, tenant rate-limit checks, billing-event emission, and tenant-scoped secret lookup must live in intake middleware/orchestration edges or post-dispatch tails. Core dispatch paths for internal Grid callers must remain tenant-agnostic and default to `TenantId.Internal` without caller-specific branches. — Notify Cloud is the first real (non-noop) consumer of this invariant. The boundaries.md decision-test reinforces this; the integration-points.md Consumes/Exposes split reflects it.

> **Invariant 40:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`. Composition against `HoneyDrunk.Communications` is a host-time concern; packaged testing fixtures, when introduced, are test-time only. — Notify Cloud takes the runtime dependency on `HoneyDrunk.Communications.Abstractions`, not on the runtime package directly. Composition happens at host time in the Container App.

> **Invariant 41:** Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify. Notify owns delivery mechanics; Communications owns decision logic. — Extended naturally to Notify Cloud: commercial wrapper concerns (API keys, rate limits, billing) live in Notify Cloud; decision logic (whether/when/which recipient) stays in Communications; delivery mechanics (provider SDK calls, retries) stay in Notify. The boundaries.md decision-test makes this explicit.

## Referenced ADR Decisions

**ADR-0027 D1 (Notify Cloud is the Ops sector's multi-tenant commercial wrapper above Notify):** The Node owns commercial-product primitives (API gateway, API key issuance/validation, per-tenant rate limits, tenant-scoped billing event emission, management web app). It is a wrapper, not a delivery engine. Grid-internal callers continue to use Notify and Communications directly and never traverse a Notify Cloud surface.

**ADR-0027 D2 (Private repo, revenue carve-out):** First private repo in the Grid. Justifications on the record: customer-data-adjacent infrastructure, hyperscaler defense, billing-system integrity. The catalog gains a `visibility` field on this Node (reconciled by hive-sync, not in this packet).

**ADR-0027 D3 (Package families):** Four packages — `HoneyDrunk.Notify.Cloud.Abstractions` (zero runtime HoneyDrunk dependencies), `HoneyDrunk.Notify.Cloud` (runtime composition), `HoneyDrunk.Notify.Cloud.Billing.Stripe` (provider slot), `HoneyDrunk.Notify.Cloud.Web` (management website). No `Testing` package at stand-up — in-memory fixtures live as `internal` test helpers until a second consumer emerges.

**ADR-0027 D4 (Exposed contracts):** Four surfaces — `INotifyCloudGateway` (interface), `INotifyCloudApiKeyStore` (interface), `NotifyCloudTenantTier` (record), `ApiKeyIssuance` (record). Multi-tenant primitives consumed from Kernel per ADR-0026, not redefined here.

**ADR-0027 D5 (Boundary rule):** Strict one-way dependency direction documented in boundaries.md. Hot path is Notify Cloud → Communications → Notify. Direct calls from Notify Cloud to Notify are diagnostic/smoke-test only.

**ADR-0027 D6 (SDK lives in open Notify repo):** Documented in overview.md visibility section. The SDK is identical for self-hosters and hosted-service customers; placing it in the open repo lets self-hosters consume it without a license seam.

**ADR-0027 D7 (Telemetry direction):** Documented in integration-points.md Emits section. One-way emission to Pulse via Kernel's `ITelemetryActivityFactory`. `tenant_id` is a direct low-cardinality label at v1; API keys / raw secrets / payloads / PII are never emitted.

**ADR-0027 D11 (FSL on open engine repos):** Documented in overview.md Visibility and Licensing section. Notify and Communications repos get FSL with two-year auto-conversion to Apache 2.0. The wrapper repo (Notify.Cloud, private) is `LicenseRef-Proprietary`. The FSL application is the substance of packets 03 and 04 of this initiative.

## Dependencies
None. This packet is the foundation of the initiative — it can land before the constitution invariants packet (02) and the FSL packets (03/04), because the content is design-decided already in ADR-0027. Packets 02, 03, 04, 05, and 06 reference this one as `work-item:01`.

## Labels
`chore`, `tier-2`, `architecture`, `ops`, `adr-0027`

## Agent Handoff

**Objective:** Create the standard five-file `repos/HoneyDrunk.Notify.Cloud/` context folder and update `constitution/sectors.md` to reflect ADR-0027's standup decisions. Do **not** edit `catalogs/*.json`, `initiatives/*`, `adrs/README.md`, or the ADR file itself.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: ADR-0027 is the standup ADR for the Grid's first commercial Node and first private repo. Without the context folder, downstream agents scoping their own work against Notify Cloud read no metadata at all — this packet establishes the minimum viable surface.
- Feature: ADR-0027 standup initiative, Wave 1, Packet 01.
- ADRs: ADR-0027 (this packet implements the context-folder half of "If Accepted").
- Prerequisite ADR: ADR-0026 (Accepted as of 2026-05-20).

**Acceptance Criteria:** As listed above.

**Dependencies:** None — this packet runs first.

**Constraints:**

- **Invariant 1 — ADR-0027 D3 carve-out:** Invariant 1 says Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. ADR-0027 D3 explicitly carves out three permitted Abstractions references for `HoneyDrunk.Notify.Cloud.Abstractions`: `HoneyDrunk.Kernel.Abstractions`, `HoneyDrunk.Notify.Abstractions`, `HoneyDrunk.Communications.Abstractions`. The local invariant 1 in `repos/HoneyDrunk.Notify.Cloud/invariants.md` (this packet writes that file) restates the carve-out. `HoneyDrunk.Kernel.Abstractions` is load-bearing at v0.1.0 (for the `TenantId` record-struct per ADR-0026 D1); the other two are reserved by D3 for future contract surfaces. The strict-Abstractions stance from sibling ADR-0016 / ADR-0017 packets does NOT apply here.
- **Invariant 8 extended to API keys:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. — Local invariant 3 in `repos/HoneyDrunk.Notify.Cloud/invariants.md` extends this to API key material: no raw key is ever logged, traced, persisted in raw form, or returned in any subsequent API call. `ApiKeyIssuance` is the one-time issuance shape; subsequent reads return only the hash and metadata.
- **Invariant 11:** One repo per Node. — Notify Cloud is its own Node, hence its own repo (private, created by packet 05).
- **Invariant 39:** Tenant mechanics stay at intake and post-dispatch boundaries. — Notify Cloud is the first real consumer of this invariant. The boundaries.md decision-test enforces it.
- **Invariant 40:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`. Composition against `HoneyDrunk.Communications` is a host-time concern. — Reflected in integration-points.md Consumes section.
- **Records drop `I`; interfaces keep it.** `NotifyCloudTenantTier` (record) and `ApiKeyIssuance` (record) have no prefix; `INotifyCloudGateway` and `INotifyCloudApiKeyStore` (interfaces) keep it. Apply consistently across all five context files.
- **Kernel multi-tenant primitives are CONSUMED, not redefined.** Per ADR-0027 D4 and ADR-0026: `TenantId` (the strong type used as a field type by the four D4 contracts) lives in `HoneyDrunk.Kernel.Abstractions.Identity` per ADR-0026 D1; `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` live in `HoneyDrunk.Kernel.Abstractions.Tenancy` (consumed at the runtime layer, not in Notify Cloud's Abstractions). The overview and integration-points docs must clearly say none of these are declared in Notify Cloud's own Abstractions — `TenantId` is referenced via the permitted `HoneyDrunk.Kernel.Abstractions` PackageReference; the other four are runtime-layer consumption.
- **No catalog edits.** Per the user's standing instruction at the time of this scoping run, do **not** edit `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/contracts.json`, or `catalogs/modules.json`. These are reconciled by the hive-sync agent after the initiative completes. The new `visibility` schema field documented in ADR-0027 D2's catalog README treatment is also hive-sync's concern.
- **No initiative-list / ADR-index edits.** Do **not** edit `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, or `adrs/README.md`. These are hive-sync-reconciled.
- **No ADR Status flip in this packet.** ADR-0027 stays at `Status: Proposed`. The flip is a separate post-merge housekeeping step the scope agent runs after the entire initiative completes, per the user's standing ADR acceptance workflow. Do not edit the ADR header in this PR.
- **No commits under CHANGELOG `Unreleased`.** Per the user's standing rule, move to a dated versioned section with a SemVer bump before commit. The Architecture repo uses the CHANGELOG as a version of record.

**Key Files:**
- `repos/HoneyDrunk.Notify.Cloud/overview.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/boundaries.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/invariants.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/active-work.md` (new file)
- `repos/HoneyDrunk.Notify.Cloud/integration-points.md` (new file)
- `constitution/sectors.md` (Ops-sector row update)
- `CHANGELOG.md` (version entry)

`adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md`, `adrs/README.md`, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, and every file under `catalogs/` are explicitly **not** edited in this packet.

**Contracts:**
- This packet does not author any new contracts. It records ADR-0027 D4's four contracts in the context folder. Authoring of the actual `.cs` files happens in packet 06 (the scaffold).
