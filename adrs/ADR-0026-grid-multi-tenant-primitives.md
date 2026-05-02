# ADR-0026: Grid Multi-Tenant Primitives — TenantId, Propagation, Rate-Limit Policy, Vault Scoping, Billing Events

**Status:** Proposed
**Date:** 2026-05-02
**Deciders:** HoneyDrunk Studios
**Sector:** Core (Kernel) · Ops (first consumers: Notify, Communications) · Infrastructure (Vault scoping pattern)
**Follows from:** [PDR-0002](../pdrs/PDR-0002-notify-as-a-service-first-commercial-product.md) §F, §I, §K — multi-tenant changes that PDR-0002 listed as Notify-specific are formalized here as **Grid-wide primitives**.

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates Kernel and cross-Node obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Kernel packet — promote `IGridContext.TenantId` from `string?` to `TenantId?` (the existing `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` ULID record struct), update `GridContextMiddleware`, mappers, and `GridContextSerializer` to parse the `X-Tenant-Id` header into the strong type, and apply the `TenantId.Internal` default at request entry when no header is present
- [ ] Kernel packet — add `TenantId.Internal` static (well-known sentinel ULID for non-multi-tenant Grid usage) and `TenantId.IsInternal` predicate; add canary tests pinning the sentinel value
- [ ] Kernel packet — add `ITenantRateLimitPolicy` and `TenantRateLimitDecision` (record) to `HoneyDrunk.Kernel.Abstractions/Tenancy/`; add `IBillingEventEmitter` and `BillingEvent` (record) to the same namespace; default `NoopTenantRateLimitPolicy` and `NoopBillingEventEmitter` in `HoneyDrunk.Kernel`
- [ ] Vault packet — document the per-tenant secret scoping pattern (`tenant-{tenantId}-{secretName}`) in `HoneyDrunk.Vault/docs/Tenancy.md`; add a `TenantScopedSecretResolver` extension in `HoneyDrunk.Vault` that wraps `ISecretStore` with tenant-aware lookup and falls back to the Node's standard path when `TenantId.IsInternal` is true. **No contract change to `ISecretStore`** — tenancy is a usage pattern.
- [ ] Pulse packet — add `tenant_id` as a low-cardinality telemetry tag with the discipline rule documented (paying customers measured in tens at v1; cardinality bound by Notify Cloud kill criteria — see PDR-0002 §K)
- [ ] Architecture packet — update `constitution/invariants.md` to add the multi-tenant boundary invariant (provisional number 37 — final number assigned by scope agent at acceptance); update `catalogs/contracts.json` with the new Kernel surfaces; update `repos/HoneyDrunk.Kernel/boundaries.md` and `invariants.md` to reflect the tenancy primitives
- [ ] Scope agent flips Status → Accepted and assigns final invariant number when both Kernel surfaces ship at 0.x and the Vault docs land

## Context

PDR-0002 (Notify Cloud as the Grid's first commercial product) lists in §F six architectural changes the internal Notify Node needs to absorb to become multi-tenant: `TenantId` on every request, per-tenant API keys, per-tenant rate limits, per-tenant Vault scoping, tenant-scoped billing events, and a multi-tenant Web.Rest auth path. PDR-0002 §K names a hard kill condition: if any of those changes bleed into the core Notify dispatch path in a way that internal callers must know about tenancy, Notify Cloud is killed.

Today, when this ADR was scoped, the question was: should those primitives ship as Notify-specific types in `HoneyDrunk.Notify` and `HoneyDrunk.Notify.Cloud`, or as Grid-wide primitives in `HoneyDrunk.Kernel.Abstractions` and shared infrastructure? The user's answer is **Grid-wide**, with the explicit rationale that retrofitting tenancy primitives later — when a second Node (Communications-as-a-Service, AI-as-a-Service, anything else) commercializes — is more expensive than designing them once now and giving Notify Cloud the privilege of being the first consumer.

The current Grid state, audited at the time of this ADR, is:

- `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` already exists as a `readonly record struct` wrapping a ULID, with `NewId`, `TryParse`, and implicit conversions to `string` and `Ulid`. This was landed by an earlier scaffold and is the right shape — no new type needed, just promotion to first-class status across the Grid.
- `IGridContext.TenantId` is exposed as `string?`. The XML doc explicitly says *"This is an identity attribute ONLY - Kernel does not interpret, authorize, or enforce it"* and *"Used for propagation across nodes, logs, telemetry, and tracing."* Today's design preserves that stance (Kernel stays interpretation-free) but tightens the type from `string?` to `TenantId?` so callers cannot stringly-type a malformed identifier into context.
- `GridHeaderNames.TenantId = "X-Tenant-Id"` is already the canonical wire format. `GridContextMiddleware` already reads it. No new header is introduced.
- `MultiTenancyMode` enum (`SingleTenant`, `PerRequest`, `ProjectSegmented`) exists in `HoneyDrunk.Kernel.Abstractions.Hosting`. This ADR does not touch the enum; it adds the runtime primitives the `PerRequest` mode needs to be useful.
- `HoneyDrunk.Vault` has no first-class tenant scoping pattern — the docs mention multi-tenant cache key isolation, but there is no documented convention for "where does a per-tenant Resend key live in `kv-hd-notify-cloud-{env}`."
- No rate-limit primitive exists anywhere in the Grid. No billing-event primitive exists anywhere in the Grid.
- ADR-0019 (Communications standup + Notify refactor, Proposed) renamed Notify's `Orchestration/` folder to `Intake/`, which is exactly the layer this ADR's rate-limit and billing primitives need to land in.

The remaining design choices — `TenantId.Internal` shape, propagation semantics, where rate-limit enforcement lives, Vault naming convention, billing event provider-slot pattern, and the boundary invariant — are settled below. The two changes from PDR-0002 §F that are **not** primitive-shaped (per-tenant API keys, multi-tenant Web.Rest auth path) stay as Notify Cloud / Auth concerns and are scoped by the recommended follow-up ADRs in PDR-0002, not by this one. This ADR's scope is the four changes that benefit from being Grid-wide: `TenantId` propagation, rate-limit policy, Vault scoping, and billing events.

## Decision

### D1. `TenantId` is a Kernel-Abstractions primitive, ULID-backed, with a well-known `Internal` sentinel

`HoneyDrunk.Kernel.Abstractions.Identity.TenantId` (already exists, ULID-backed `readonly record struct`) is the canonical tenant identifier for the Grid. No new type is introduced. The grid-wide naming rule (records drop `I`) holds: it is `TenantId`, not `ITenantId`.

Two additions to the existing type:

- `public static TenantId Internal { get; }` — a stable, well-known ULID sentinel used by the Grid for non-multi-tenant operations. The exact value is fixed at type definition time, not generated per process. Pinned by canary test so it cannot drift across Kernel versions. The chosen ULID is recorded in the Kernel packet that lands this work.
- `public bool IsInternal => this == Internal;` — predicate for downstream Nodes (rate limiter, billing emitter, Vault resolver) to short-circuit on internal callers without string compares.

`TenantId.Internal` is the default value `IGridContext.TenantId` carries when a request entered the Grid without an `X-Tenant-Id` header. This is the contract that lets internal Nodes call Notify, Communications, AI, Operator, etc. with no callsite changes after the multi-tenant primitives land. It is also the value tests should assert on when verifying internal-vs-tenant code paths.

`TenantId.NewId()` continues to mint random ULIDs for newly provisioned tenants. The `Internal` sentinel is **not** mintable — there is exactly one internal tenant Grid-wide, by definition.

### D2. `IGridContext.TenantId` is promoted from `string?` to `TenantId?`

The current shape is `string? TenantId { get; }`. This shape was acceptable when Kernel's role was strictly propagation-without-interpretation, but PDR-0002's §F change set requires every consumer of `IGridContext` (rate limiter, billing emitter, Vault resolver, downstream Nodes) to parse the string into `TenantId` at use site. That is wasteful, error-prone, and silently swallows malformed values.

The new shape is `TenantId? TenantId { get; }`. The header parsing happens once, in `GridContextMiddleware` (and the messaging/job mappers), at Grid entry. If the `X-Tenant-Id` header is present and parses, the strong type lands in context. If the header is absent, `TenantId` is `null` and downstream resolution layers (D3) apply the `Internal` default. If the header is present but malformed, the request is rejected at the gateway with a 400 — this matches the existing defensive-truncation behavior in the middleware and surfaces malformed tenancy as a client error, not a silent default.

Kernel's stance on tenancy stays interpretation-free: Kernel parses, propagates, and exposes. It does not authorize, rate-limit, or bill. Those concerns live in the layers introduced by D4–D6 below.

### D3. Tenant resolution is explicit threading via `IGridContext`, never AsyncLocal

`TenantId` flows through the Grid via the same `IGridContext` instance every other context value rides on. There is no `TenantContext.Current` AsyncLocal, no `TenantId.Ambient`, no static accessor. This rules out two failure modes:

1. AsyncLocal gets lost across thread-pool boundaries when code is poorly written. A solo dev plus AI agents cannot afford the debug surface that hidden context loss creates.
2. AsyncLocal undermines test isolation — tests running in parallel in the same process leak tenancy.

The default resolution rule, applied at the Node-runtime layer (not in Kernel itself):

- If `IGridContext.TenantId` is non-null, use it.
- If `IGridContext.TenantId` is null, treat the operation as tenant `Internal`. This is the rule a tenancy-aware Node applies at the start of every operation that needs a `TenantId`. It is **not** a property on `IGridContext` because Kernel does not interpret tenancy. The rule is implemented as a tiny helper in `HoneyDrunk.Kernel` (`gridContext.TenantId ?? TenantId.Internal`) so every Node applies it identically.

Propagation across Node boundaries:

- HTTP edge → `X-Tenant-Id` header → `GridContextMiddleware` parses → `IGridContext.TenantId` populated (or null).
- Messaging hop → `MessagingContextMapper` round-trips `TenantId` via the existing baggage / message-properties channel (already wired for the `string?` shape; updated to `TenantId?`).
- Job hop → `JobContextMapper` — same as messaging.
- HTTP outbound from a Node — Node-level `HttpClient` configurations that emit `X-Correlation-Id` already exist; tenancy is added to that emission path so downstream Nodes receive the tenant on their own `GridContextMiddleware` parse.

This is the same mechanism every other context value already uses. No new propagation channel is introduced.

### D4. Per-tenant rate-limit policy is a Kernel-Abstractions contract, enforced at gateway-layer middleware

The rate-limit primitive is split into two pieces, in two packages:

**`HoneyDrunk.Kernel.Abstractions.Tenancy.ITenantRateLimitPolicy`** — the contract a tenancy-aware Node consults before doing tenant-billable work:

```csharp
public interface ITenantRateLimitPolicy
{
    ValueTask<TenantRateLimitDecision> EvaluateAsync(
        TenantId tenantId,
        string operationKey,
        CancellationToken cancellationToken);
}
```

**`HoneyDrunk.Kernel.Abstractions.Tenancy.TenantRateLimitDecision`** — the record the policy returns:

```csharp
public sealed record TenantRateLimitDecision(
    TenantRateLimitOutcome Outcome,
    TimeSpan? RetryAfter,
    string? Reason);

public enum TenantRateLimitOutcome { Allow, Throttle, Reject }
```

`Outcome.Allow` proceeds. `Outcome.Throttle` returns a `RetryAfter` advisory the caller may honor (used for soft limits — "you're approaching your tier ceiling"). `Outcome.Reject` returns a hard refusal with a `RetryAfter` for the 429 response and a non-PII `Reason` suitable for inclusion in an error envelope. **The reason string never includes secret material** (Invariant 8).

**Default implementation: `NoopTenantRateLimitPolicy`** in `HoneyDrunk.Kernel`. Returns `Allow` for every tenant. This is the implementation registered for internal Grid usage and during tests. Production multi-tenant Nodes (Notify Cloud) replace this registration with their own `ITenantRateLimitPolicy` backed by a real store.

**Storage: deferred to consumer Nodes.** This ADR does not name Redis, Azure Storage Tables, or anything else as the rate-limit backend. The contract returns a decision; the storage shape is an implementation detail of the registered policy. Notify Cloud's first implementation will likely use Azure Storage Tables (cheap, sufficient for the v1 customer-count ceiling, no extra resource provisioning beyond what Notify Cloud already owns); that decision belongs in the `HoneyDrunk.Notify.Cloud` standup ADR or the rate-limit implementation packet, not here.

**Default policy for `TenantId.Internal`: always `Allow`.** Implementations of `ITenantRateLimitPolicy` are required to short-circuit on `tenantId.IsInternal` and return `Allow` without consulting any store. This is enforceable as a canary test on every implementation that ships in the Grid, and is the technical mechanism that prevents PDR-0002 §K kill condition 2 (internal callers must not hit rate limits they did not ask for).

**Enforcement location: gateway-layer middleware in the consumer Node.** This is the critical point. The rate-limit check lives at the Node's intake layer (post-ADR-0019 in Notify, this is `HoneyDrunk.Notify/Intake/`), **never** in core dispatch (`HoneyDrunk.Notify/Routing/`, `HoneyDrunk.Notify/Worker/`, `HoneyDrunk.Notify/Providers/`). Internal callers that bypass intake (a Notify-internal job that goes directly to the dispatcher, for example) do not see the rate-limit check at all — which is exactly the desired behavior. The boundary is enforced architecturally by D7's invariant.

### D5. Per-tenant Vault scoping is a usage pattern, not a contract change

`HoneyDrunk.Vault` is the only source of secrets per Invariant 9. PDR-0002 §F asks for per-tenant secret scoping (a Pro-tier Notify Cloud customer can BYO a Resend key, stored in a tenant-scoped slot). This ADR commits to a **naming convention plus a thin resolver wrapper**, not a change to `ISecretStore`'s contract.

**Naming convention:** within a Node's vault `kv-hd-{service}-{env}` (Invariant 17), per-tenant secrets are named `tenant-{tenantId}-{secretName}`. Examples:

- `tenant-01H2X3Y4Z5...XYZ-resend-api-key` — Pro-tier tenant's BYO Resend key in `kv-hd-notify-cloud-{env}`.
- `tenant-01H2X3Y4Z5...XYZ-twilio-auth-token` — same tenant's BYO Twilio token.
- `resend-api-key` (no `tenant-` prefix) — the Notify Cloud-managed shared Resend key used by `Internal`-tenant traffic and by Free/Starter tenants who haven't set their own.

The `tenant-{tenantId}` prefix uses the ULID string form of `TenantId`. ULIDs are 26 characters; combined with the secret-name suffix, they fit within Azure Key Vault's 127-character secret-name limit comfortably.

**Thin resolver: `TenantScopedSecretResolver`** in `HoneyDrunk.Vault` (the runtime package, not Abstractions, because it composes `ISecretStore`). Pseudocode:

```csharp
public sealed class TenantScopedSecretResolver(ISecretStore secretStore)
{
    public ValueTask<string> ResolveAsync(
        TenantId tenantId,
        string secretName,
        CancellationToken cancellationToken)
    {
        if (tenantId.IsInternal)
        {
            return secretStore.GetSecretAsync(secretName, cancellationToken);
        }

        // Try tenant-scoped first; fall back to shared if absent.
        // Fallback is the explicit behavior — Free/Starter tenants share keys.
        return secretStore.TryGetSecretAsync(
            $"tenant-{tenantId}-{secretName}",
            fallback: secretName,
            cancellationToken);
    }
}
```

Tenant-scoped secrets honor every existing Vault invariant: never logged (Invariant 8), only ever resolved via `ISecretStore` (Invariant 9), never version-pinned (Invariant 21), with diagnostic settings already routed to Log Analytics (Invariant 22). The rotation tier (Invariant 20) applies per secret as today — a tenant-scoped Resend key is a Tier 2 third-party secret with the same ≤90-day rotation SLA.

**Default behavior for `TenantId.Internal`:** the resolver short-circuits to the shared secret name (`secretName`, no `tenant-` prefix), which is the existing path internal Nodes already use. No Node operating internally sees a behavior change.

**No contract surface change to `ISecretStore`.** This is deliberate. `ISecretStore` stays a primitive. The tenant scoping is a pattern Nodes opt into by composing `TenantScopedSecretResolver`; Nodes that have no per-tenant secrets ignore the resolver entirely. This is symmetric with how Vault treats environment scoping (a usage pattern, not a contract change).

### D6. Tenant-scoped billing events are a Kernel-Abstractions contract with a provider-slot pattern

The billing primitive mirrors the rate-limit primitive in shape — a contract in Kernel.Abstractions, a noop default in Kernel, real implementations live in consumer Nodes.

**`HoneyDrunk.Kernel.Abstractions.Tenancy.IBillingEventEmitter`**:

```csharp
public interface IBillingEventEmitter
{
    ValueTask EmitAsync(BillingEvent billingEvent, CancellationToken cancellationToken);
}
```

**`HoneyDrunk.Kernel.Abstractions.Tenancy.BillingEvent`** — the record:

```csharp
public sealed record BillingEvent(
    TenantId TenantId,
    string EventType,        // e.g. "notify.delivery.success"
    string OperationKey,     // e.g. "email", "sms"
    long Units,              // e.g. 1 for a single send
    DateTimeOffset OccurredAtUtc,
    string CorrelationId,
    IReadOnlyDictionary<string, string> Attributes);
```

`Attributes` carries provider-relevant metadata (Stripe price ID, channel, idempotency key for the underlying delivery). It is bounded — implementations should reject events with more than ~16 attributes to prevent unbounded growth — and it never carries PII or secret material (Invariant 8 applies).

**Default implementation: `NoopBillingEventEmitter`** in `HoneyDrunk.Kernel`. Drops every event silently. Used for internal Grid traffic and tests.

**Provider-slot pattern.** Real emitters live in consumer-Node packages following the same convention as Notify's provider slots (`HoneyDrunk.Notify.Providers.Email.Resend` etc.). Notify Cloud's Stripe-bound emitter lives in `HoneyDrunk.Notify.Cloud.Billing.Stripe`. Future emitters (Paddle, LemonSqueezy, internal Grid metering) implement the same `IBillingEventEmitter` interface and ship in their own provider packages. Stripe is the first consumer; the contract is provider-agnostic.

**Where the event is emitted: post-dispatch, not at intake.** A billing event represents *consumed* tenant capacity, not *requested* tenant capacity. If a request is rate-limit rejected at intake, no billing event fires — the tenant did not consume the capacity. If a request is enqueued at intake but fails permanently at dispatch (e.g. a hard bounce from Resend), the consumer Node decides whether to bill the attempt — Notify Cloud's call is "successful delivery only," and that policy lives in the Notify Cloud emitter, not in the contract. This means **the billing emitter is invoked from the worker / dispatch tail**, not from intake middleware. The contract does not constrain this; the consumer Node constrains it.

**Queue shape: implementation detail of the emitter.** The contract is fire-and-forget. The Stripe emitter writes to an Azure Storage queue that a Stripe webhook bridge consumes; another emitter could write to Service Bus, to a database, or directly to a third-party API. The contract does not name a queue; the consumer Node does, in its own composition.

**Default behavior for `TenantId.Internal`: no event emitted.** Implementations of `IBillingEventEmitter` are required to short-circuit on `billingEvent.TenantId.IsInternal` and return without emitting. Symmetric with the rate-limit `Internal` short-circuit, and verifiable by canary test on every implementation.

### D7. Multi-tenant boundary invariant — tenant concerns live in gateway-layer middleware, never in core dispatch paths

A new Grid invariant is added to `constitution/invariants.md`. Provisional number 37 — final number assigned by scope agent at acceptance.

> **Tenant resolution, rate-limit enforcement, billing-event emission, and tenant-scoped secret resolution live in gateway-layer middleware (Node intake) and post-dispatch tails, never in core dispatch paths.** Core dispatch — the routing, retry, worker, and provider layers of any Node — receives requests with tenancy already resolved (or `TenantId.Internal` defaulted) and emits no tenant-aware concerns of its own. Internal callers that bypass gateway middleware (in-process direct dispatch from the same Node, internal job-to-job hops within a worker) are unaffected by tenancy enforcement and continue to operate as `TenantId.Internal`. Violations are caught at architecture review and at PR review per ADR-0011.

The invariant turns PDR-0002 §K kill condition 2 (`Multi-tenanting forces architectural changes that compromise internal Grid use`) from a Notify-specific code-review preference into a Grid-level rule any tenancy-aware Node is held to. This is the architectural tripwire that catches the failure mode early.

**Examples of compliant patterns:**

- Notify's intake gateway (`HoneyDrunk.Notify/Intake/NotificationGateway`) consults `ITenantRateLimitPolicy` before enqueueing. Compliant — intake is gateway-layer.
- Notify Cloud's worker tail emits a `BillingEvent` after a successful delivery. Compliant — post-dispatch tail.
- A Notify Cloud-specific `IApiKeyAuthenticator` middleware in Notify Cloud's web pipeline resolves `TenantId` from an API key and stamps it on `IGridContext`. Compliant — gateway-layer middleware.

**Examples of violations:**

- `NotificationDispatcher.SendAsync` calls `ITenantRateLimitPolicy.EvaluateAsync` and refuses to dispatch on throttle. **Violation** — dispatch is core, not gateway.
- A provider adapter (`ResendEmailSender`) reads `TenantId` from `IGridContext` and decides which Resend key to use based on the value. **Violation** — providers are core; the tenant-scoped key resolution happens in the intake or worker setup layer, and the adapter receives an already-resolved key.
- A retry strategy decides retry count based on tenant tier. **Violation** — retry is core dispatch, not gateway.

The boundary is the same shape as ADR-0019 D4's Notify-vs-Communications decision test. Apply the question: *is this concern about how the request gets delivered, or about whether/when the request should be admitted into the dispatch pipeline at all?* If the former, it is core. If the latter, it is gateway.

### D8. Where these primitives live — packages and dependency rule

| Surface | Package | Purpose |
|---|---|---|
| `TenantId` (record struct) | `HoneyDrunk.Kernel.Abstractions.Identity` (already exists) | Strongly-typed ULID-backed tenant identifier. D1 adds `Internal` sentinel and `IsInternal` predicate. |
| `IGridContext.TenantId` (typed) | `HoneyDrunk.Kernel.Abstractions.Context` (existing interface) | Promoted from `string?` to `TenantId?` per D2. |
| `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `TenantRateLimitOutcome` | `HoneyDrunk.Kernel.Abstractions.Tenancy` (new namespace) | Rate-limit contract per D4. |
| `IBillingEventEmitter`, `BillingEvent` | `HoneyDrunk.Kernel.Abstractions.Tenancy` | Billing-event contract per D6. |
| `NoopTenantRateLimitPolicy`, `NoopBillingEventEmitter` | `HoneyDrunk.Kernel` | Default implementations registered for internal Grid usage and tests. |
| `TenantScopedSecretResolver` | `HoneyDrunk.Vault` (runtime package) | Composes `ISecretStore` per D5. No Abstractions surface change. |
| `tenant-{tenantId}-{secretName}` naming convention | `HoneyDrunk.Vault/docs/Tenancy.md` | Documentation, not a contract. |

The four contract surfaces (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`) are the hot path for every tenancy-aware Node. They get a contract-shape canary in `HoneyDrunk.Kernel`'s CI, same shape as ADR-0016 / 0017 / 0019 used. Shape drift on any of the four is a build failure.

The dependency rule:

- `HoneyDrunk.Kernel.Abstractions` carries the four interfaces and two records. Zero new runtime dependencies (Invariant 1 holds — only `Microsoft.Extensions.*` abstractions are permitted).
- `HoneyDrunk.Kernel` carries the noop defaults. Already depends on `HoneyDrunk.Kernel.Abstractions`. No new package references.
- `HoneyDrunk.Vault` carries `TenantScopedSecretResolver`. Already depends on `HoneyDrunk.Kernel.Abstractions`. No new package references.
- Consumer Nodes (Notify, Communications, Notify Cloud) reference `HoneyDrunk.Kernel.Abstractions` for the contracts and bring their own implementations. No transitive runtime dependency on `HoneyDrunk.Kernel` is forced on consumers (Invariant 2 holds).

### D9. Ordering — Kernel ships first, then Vault docs, then consumer Nodes

The order is sequenced, not parallel:

1. **Kernel packets land first.** `TenantId.Internal` + `IsInternal` + `IGridContext.TenantId` type promotion + `ITenantRateLimitPolicy` + `TenantRateLimitDecision` + `IBillingEventEmitter` + `BillingEvent` + noop defaults + canary tests + version bump on `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel`. Both packages move together per Invariant 27.
2. **Vault docs and `TenantScopedSecretResolver` land second.** `HoneyDrunk.Vault/docs/Tenancy.md` plus the resolver in the runtime package. Vault version bump.
3. **Consumer Nodes land third.** Notify intake adopts `ITenantRateLimitPolicy` (registered as noop in internal composition, real implementation in Notify Cloud composition). Notify Cloud's Stripe billing emitter is the first real `IBillingEventEmitter`. Communications inherits the strong-typed `IGridContext.TenantId` automatically.

This ADR flips Status → Accepted when steps 1 and 2 are landed. Step 3 is consumer-Node work that proceeds under its own ADRs and packets — Notify Cloud standup ADR, Notify multi-tenant primitives packet (which becomes a thin "wire up the consumer side of D8" packet now that the primitives themselves are Kernel-owned), and ADR-0019's Notify refactor.

### D10. What this ADR explicitly does **not** decide

To keep the scope tight and avoid the trap of bundling everything PDR-0002 §F mentioned into one ADR:

- **Per-tenant API key issuance, validation, and storage.** Lives in Notify Cloud and Auth, scoped by the "API key authentication pattern ADR" that PDR-0002 already lists as a follow-up. This ADR's primitives are below the API key layer — once a key is validated and resolved to a `TenantId`, the request enters Grid-wide tenancy; before that, it is Notify Cloud's concern.
- **Multi-tenant Web.Rest auth path.** Same as above — Auth-and-Notify-Cloud concern, separate ADR.
- **Rate-limit storage backend.** Implementation detail of consumer Nodes per D4. Notify Cloud picks; this ADR doesn't.
- **Billing-event queue topology, Stripe webhook bridge wiring.** Implementation detail of `HoneyDrunk.Notify.Cloud.Billing.Stripe` per D6. Separate ADR ("Stripe billing integration ADR" in PDR-0002 §Recommended Follow-Up Artifacts) or a packet.
- **Project-scoped tenancy (`ProjectId` enforcement).** `ProjectId` already exists on `IGridContext` as `string?` and `MultiTenancyMode.ProjectSegmented` already exists in Hosting. Promoting `ProjectId` to a strong type (parallel to `TenantId`) and threading project-scoped rate limits / billing through the same primitives is a future ADR — Notify Cloud v1's tier model is per-tenant, not per-project, so the promotion does not block public launch.
- **Tenant abuse detection, fraud signals, automatic-pause thresholds.** Operations concerns, not primitives. Live in Notify Cloud and surfaced via the existing Pulse telemetry channel.
- **Multi-region tenancy.** Notify Cloud v1 is single-region per PDR-0002 §B. The primitives in this ADR are region-agnostic; multi-region scoping is a future-ADR concern.

## Consequences

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] `HoneyDrunk.Kernel.Abstractions.Identity.TenantId` ships `Internal` sentinel and `IsInternal` predicate, with the sentinel ULID pinned by canary test.
- [ ] `IGridContext.TenantId` is `TenantId?`, with `GridContextMiddleware`, `MessagingContextMapper`, `JobContextMapper`, and `GridContextSerializer` updated to parse / round-trip the strong type.
- [ ] `HoneyDrunk.Kernel.Abstractions.Tenancy` namespace exists and exports `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `TenantRateLimitOutcome`, `IBillingEventEmitter`, `BillingEvent`.
- [ ] `HoneyDrunk.Kernel` ships `NoopTenantRateLimitPolicy` and `NoopBillingEventEmitter` registered in the default DI extensions.
- [ ] Contract-shape canary covers all four interfaces and is green.
- [ ] `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` ship a coordinated minor version bump per Invariant 27, with changelog entries.
- [ ] `HoneyDrunk.Vault/docs/Tenancy.md` exists and documents the `tenant-{tenantId}-{secretName}` convention with worked examples.
- [ ] `TenantScopedSecretResolver` ships in `HoneyDrunk.Vault` runtime package, with tests covering the `Internal` short-circuit and the tenant-scoped fallback path.
- [ ] `constitution/invariants.md` adds the multi-tenant boundary invariant (final number assigned by scope agent).
- [ ] `catalogs/contracts.json` carries entries for the four new Kernel surfaces.
- [ ] `repos/HoneyDrunk.Kernel/boundaries.md` and `invariants.md` are updated to reflect the tenancy primitives.
- [ ] Scope agent flips Status → Accepted.

### New invariants (proposed for `constitution/invariants.md`)

Numbering is tentative — scope agent finalizes at acceptance.

- **Tenant resolution, rate-limit enforcement, billing-event emission, and tenant-scoped secret resolution live in gateway-layer middleware (Node intake) and post-dispatch tails, never in core dispatch paths.** Core dispatch — the routing, retry, worker, and provider layers of any Node — receives requests with tenancy already resolved (or `TenantId.Internal` defaulted) and emits no tenant-aware concerns of its own. Internal callers that bypass gateway middleware are unaffected by tenancy enforcement and continue to operate as `TenantId.Internal`. (See D7.)

### Unblocks

Accepting this ADR — and landing the Kernel and Vault halves — unblocks the following:

- **Notify Cloud (PDR-0002).** The primitives the multi-tenant intake layer needs are off the critical path. Notify Cloud's standup ADR (PDR-0002 §Recommended Follow-Up Artifacts) wires up the consumer side instead of inventing the contracts.
- **Communications (ADR-0019).** Inherits the strongly-typed `IGridContext.TenantId` automatically. Decision-log entries become tenant-scoped without a Communications-specific tenancy primitive.
- **Future commercial Nodes.** Any Node that gets commercialized later (Communications-as-a-Service, AI-as-a-Service, Vault-as-a-Service) inherits the same primitives. The cost of going multi-tenant for a second Node is the gateway-layer wiring (rate-limit policy registration, billing emitter registration, API key auth), not the primitives themselves.
- **Pulse tenant-scoped telemetry.** The `tenant_id` tag on Pulse telemetry has a single canonical source — `IGridContext.TenantId.ToString()` — so cardinality discipline is uniform across emitters.

### Negative

- **Promoting `IGridContext.TenantId` from `string?` to `TenantId?` is a minor breaking change on `HoneyDrunk.Kernel.Abstractions`.** Every Node that reads the property today (and reads it as a string) will need a one-line update at the use site. Mitigation: the audit at the time of this ADR shows zero non-Kernel callsites that read `IGridContext.TenantId` — the property exists on the contract but is consumed only by Kernel's own serializers and middleware. The break is real on paper; the blast radius is empty in practice. Notify Cloud, Communications, and any future consumer pick up the strong type from the start.
- **Adding `Internal` sentinel + `IsInternal` predicate to `TenantId` is a minor surface addition.** Backward-compatible; no existing callsite breaks.
- **Four new contracts in Kernel.Abstractions (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`) widen Kernel's surface area.** Each is small, the namespace is dedicated (`Tenancy`), and the canary protects shape from drift. The cost is one more thing to maintain in Kernel; the benefit is one place to maintain it instead of N.
- **`TenantScopedSecretResolver` in Vault runtime introduces a composition layer over `ISecretStore`.** Nodes that have no per-tenant secrets ignore it; Nodes that do, opt in by composing it. The composition shape is documented but is not enforced by canary — it cannot be, because it is a usage pattern. The risk is Notify Cloud or a future Node forgetting to compose it and hard-coding tenant-scoped key resolution. Mitigation: the consumer-Node ADR for any commercial Node references this ADR's D5 explicitly and includes a packet checklist item.
- **The boundary invariant (D7) adds a code-review concern.** PR reviews on tenancy-aware Nodes have a new question to ask. Mitigation: the invariant is precise enough to be machine-checkable in the long run (a static analyzer that flags `ITenantRateLimitPolicy` references inside `Routing/`, `Worker/`, or `Providers/` folders is a future packet); the short-term enforcement is human review per ADR-0011.
- **`Internal` ULID is a magic value.** Pinning it by canary mitigates drift but does not eliminate the smell. The alternative — a `TenantId? Internal` represented as null — was rejected because it forces every consumer to write `tenantId ?? null-handling` and loses the `IsInternal` predicate. The chosen shape trades a small amount of magic for clearer call sites.

### Catalog obligations

`catalogs/contracts.json` gains four entries (the four Kernel.Abstractions interfaces / records). `catalogs/grid-health.json` Kernel entry is updated to reflect the new Tenancy namespace. `catalogs/relationships.json` is unchanged — these primitives are Kernel-owned and don't introduce new Node-to-Node edges; consumer Nodes already declare a Kernel.Abstractions edge.

`constitution/invariants.md` adds one invariant (D7). `constitution/sectors.md` is unchanged.

`repos/HoneyDrunk.Kernel/boundaries.md` is updated to reflect the new `Tenancy` namespace and the strongly-typed `TenantId` on `IGridContext`. `repos/HoneyDrunk.Kernel/invariants.md` is updated to mention the boundary rule. `repos/HoneyDrunk.Vault/boundaries.md` adds the `TenantScopedSecretResolver` composition pattern and links to `docs/Tenancy.md`.

## Alternatives Considered

### Notify-specific primitives in `HoneyDrunk.Notify` and `HoneyDrunk.Notify.Cloud`

**Description:** Put `TenantRateLimitPolicy`, `BillingEvent`, etc. in the Notify or Notify Cloud package. `IGridContext.TenantId` stays `string?`. Vault scoping pattern documented only in Notify Cloud's docs.

**Why rejected:** This is the framing the user explicitly turned down. The cost of retrofitting tenancy primitives later, when a second Node commercializes, exceeds the cost of designing them once now. The Notify-specific framing also forces every other Node that reads tenancy from `IGridContext` to handle a stringly-typed value, when the strong type already exists in Kernel. And it creates a contract-shape divergence: Notify Cloud invents `BillingEvent`, then the next commercial Node either takes a runtime dependency on Notify Cloud (architecturally wrong) or invents its own incompatible `BillingEvent`. The Grid-wide framing avoids both failure modes.

### Tenancy primitives in a new `HoneyDrunk.Tenancy` Node

**Description:** Stand up `HoneyDrunk.Tenancy` as a new Core-sector Node that owns `ITenantRateLimitPolicy`, `IBillingEventEmitter`, the strong-typed `TenantId`, etc. Kernel stays out of tenancy entirely.

**Why rejected:** Tenancy is so deeply wired into context propagation that splitting it from Kernel would force every Node that reads `IGridContext` to take a transitive runtime dependency on `HoneyDrunk.Tenancy.Abstractions` — which means every Node that already depends on `HoneyDrunk.Kernel.Abstractions` would gain a parallel dependency. The two abstractions packages would always be referenced together. That's a strong signal they belong in the same package, not adjacent packages. Kernel's existing stance (interpretation-free propagation) is preserved by adding the four contracts as `Abstractions` definitions only and keeping all interpretation in consumer Nodes — no actual interpretation logic enters Kernel. The naming-rule scope (Kernel owns identity primitives like `TenantId`, `ProjectId`, `StudioId`) already aligns with this placement; adding rate-limit and billing surfaces continues that pattern.

### Keep `IGridContext.TenantId` as `string?` and require consumers to parse

**Description:** Don't promote the type. The four new contracts live in Kernel.Abstractions, but consumers parse `string?` into `TenantId` themselves at use site.

**Why rejected:** Every consumer of tenancy parses identically. Centralizing the parse at Grid entry (in `GridContextMiddleware` and the messaging/job mappers) is the only place malformed values can be defensively rejected. Pushing the parse to N consumer sites means any one of them can silently swallow a malformed value, hand `TenantId.NewId()` accidentally, or carry a stringly-typed value into a `BillingEvent` and emit a meaningless event. The strong type at the context layer is the right place. The migration cost is empty in practice (no non-Kernel callsites read the property today).

### AsyncLocal-based tenant context (`TenantContext.Current`)

**Description:** Add a static `TenantContext.Current` AsyncLocal alongside `IGridContext`. Consumers read tenancy from the AsyncLocal without going through `IGridContext`.

**Why rejected:** AsyncLocal as ambient context is the failure mode `IGridContext` already exists to prevent. The Grid has one context primitive; adding a parallel one for tenancy would create exactly the inconsistency that scoped-DI-with-mappers was designed to eliminate. AsyncLocal also undermines test isolation in parallel test runs and is a debug-surface tax a solo dev cannot afford. The explicit-threading-via-`IGridContext` model is already in use everywhere else; tenancy fits.

### Add tenancy to `IGridContext` interpretation, with rate-limit / billing logic in Kernel

**Description:** Move `ITenantRateLimitPolicy.EvaluateAsync` invocation directly into Kernel's `GridContextMiddleware`. Kernel becomes a tenancy enforcement point.

**Why rejected:** Kernel's stance is interpretation-free propagation. The XML doc on `IGridContext.TenantId` says so explicitly: *"This is an identity attribute ONLY - Kernel does not interpret, authorize, or enforce it."* Putting rate-limit enforcement in Kernel violates that stance and turns Kernel into a multi-tenant runtime instead of a context primitive. Worse, it forces every Node — including Nodes that have no tenancy concerns at all — to compose against a tenancy-aware Kernel pipeline. The chosen shape (contracts in Kernel.Abstractions, noop defaults in Kernel, real enforcement at consumer-Node intake) keeps Kernel clean and lets each Node opt in at its own gateway layer.

### Defer the boundary invariant (D7) until the second commercial Node ships

**Description:** Add the rate-limit and billing primitives, but don't add the boundary invariant until there's evidence we need it.

**Why rejected:** PDR-0002 §K kill condition 2 already names the failure mode the invariant prevents. Without the invariant, the failure mode is a code-review preference enforceable only on Notify-aware reviewers. With the invariant, it's a Grid-level rule any reviewer can check. The cost of adding the invariant is one paragraph in `constitution/invariants.md`; the cost of waiting is a hard kill condition that lacks a written rule to enforce. Add the invariant now.

## Open Questions

Items that should become their own ADRs or packets later:

- **Promoting `IGridContext.ProjectId` from `string?` to `ProjectId?`.** Parallel to D2. Out of scope for this ADR — Notify Cloud v1 is per-tenant, not per-project. When the first commercial Node needs project-scoped tenancy, a small follow-up ADR adds `ProjectId.Internal` and tightens the type. Likely lands without controversy; deferred only because v1 doesn't need it.
- **A static analyzer that enforces D7 mechanically.** A `HoneyDrunk.Standards` analyzer that flags references to `ITenantRateLimitPolicy` or `IBillingEventEmitter` from inside `Routing/`, `Worker/`, or `Providers/` folders. Useful but not gating. Future packet.
- **`TenantId.Internal` ULID value selection.** The Kernel packet that lands D1 picks the specific ULID. Conventionally a low-bit ULID (`00000000000000000000000000`) is reserved or rejected by the type's constructor; the chosen value should be documented in the packet and pinned by canary. Bikeshed-shaped — not blocking.
- **Per-tenant feature flags as a tenancy primitive.** PDR-0002 §Open Questions defers this. If it lands, it likely lives in Kernel.Abstractions.Tenancy alongside the four interfaces here; the contract shape (`ITenantFeatureFlags`?) is sketchable but premature.
- **Decision-log integration.** Communications's `ICommunicationDecisionLog` (ADR-0019 D3) is tenant-scoped automatically once `TenantId` is strongly typed on `IGridContext`. Whether the decision log emits `BillingEvent`s for "suppressed by Communications" cases is a Communications/Notify Cloud question, not a primitives question. Defer to the Communications decision-log persistence ADR.
- **Test fixtures for tenancy.** A `HoneyDrunk.Kernel.Testing` companion (parallel to `HoneyDrunk.Communications.Testing`) carrying a `RecordingTenantRateLimitPolicy` and `RecordingBillingEventEmitter` for deterministic test assertions. Likely a small follow-up packet, not a separate ADR. Defer until the first consumer asks for it.
