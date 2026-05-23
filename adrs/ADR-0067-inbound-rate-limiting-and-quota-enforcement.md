# ADR-0067: Inbound Rate Limiting and Quota Enforcement

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates Kernel, Notify Cloud, and cross-Node obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Kernel packet — ship `AddGridRateLimiting()` and `UseGridRateLimiting()` extension methods on `HoneyDrunk.Kernel` that wire the ASP.NET Core `RateLimiter` middleware to read `IGridContext.TenantId` (per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D2), apply the partitioned limiter from D9, and emit the success-side headers from D7
- [ ] Kernel packet — extend `ITenantRateLimitPolicy` consumers (already a [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D4 primitive) with the response-shape convention from D6 so every Node that returns 429 returns the same envelope
- [ ] Notify Cloud packet — ship the production `ITenantRateLimitPolicy` implementation that consults `NotifyCloudTenantTier` (per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D3) and applies the per-tier limits in D3 of this ADR
- [ ] Notify Cloud packet — wire the daily quota counter store (the per-tenant counters that back D8's quota enforcement); storage choice is deferred to that packet but expected to be Azure Storage Tables or the Cache Node ([ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) / [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) once a distributed backing exists
- [ ] Audit packet — confirm the `RateLimitRejected` audit-event shape per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md); Notify Cloud emits when D10's trigger fires
- [ ] Pulse packet — confirm the `429` counter metric with tags `tenant_id`, `endpoint`, `tier`, `outcome` per [ADR-0010](./ADR-0010-observation-layer.md); document the spike-by-tenant alarm threshold from D10
- [ ] Architecture packet — update [`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) to record the ASP.NET Core `RateLimiter` choice with Cloudflare edge complement
- [ ] Architecture packet — update [`catalogs/contracts.json`](../catalogs/contracts.json) for the new Kernel extension surface (no new abstractions; the primitive is [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md)'s `ITenantRateLimitPolicy`)
- [ ] Scope agent flips Status → Accepted after the Kernel extension surface ships at 0.x and the first Notify Cloud tier-driven `ITenantRateLimitPolicy` lands

## Context

[ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D4 committed `ITenantRateLimitPolicy` and `TenantRateLimitDecision` as Kernel.Abstractions primitives — a contract that *describes* a rate-limit decision but does not commit a *substrate* for computing one. The ADR's own text is explicit: "Storage: deferred to consumer Nodes. This ADR does not name Redis, Azure Storage Tables, or anything else as the rate-limit backend." That deferral was correct at the time; the storage shape genuinely depends on the first real consumer's access pattern.

[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D6 names Notify Cloud as the first non-noop `ITenantRateLimitPolicy` implementation and declares that the implementation derives limits from `NotifyCloudTenantTier`. It does **not** pin the tier-to-limits mapping, the algorithm, the response shape, the success-side header convention, or where the limiter sits in the request pipeline.

[ADR-0037](./ADR-0037-payment-and-billing-integration.md) D3 names three Notify Cloud tiers (Free / Pro / Scale) with "monthly base fees and per-meter overage." Tiers are configured in Stripe. ADR-0037 does not pin per-tier rate limits — the assumption is that the rate-limit story lives elsewhere.

[ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) covers cost governance through downstream kill switches and budget alerts. ADR-0052's kill switches are a separate concern from the rate limiter — they shed load when cost ceilings are hit, not when a tenant's tier ceiling is hit. The two surfaces complement each other but do not overlap.

What is missing from the substrate:

- **Primary substrate.** Which ASP.NET Core / .NET 8+ rate-limiter primitive backs the policy. There are four-plus viable choices and no Node has committed.
- **Tier-to-limits mapping.** Notify Cloud's Free tier needs concrete numbers — without them the first paying tenant cannot be onboarded with a defensible "is this within your tier?" answer.
- **Response shape.** The 429 envelope. The `Retry-After` header. The `application/problem+json` body fields. Without convention every Node invents its own.
- **Success-side headers.** `RateLimit-*` headers on every response so clients can throttle themselves. Without convention clients cannot self-throttle and bursts pile against the limiter.
- **Distributed posture.** Container Apps multi-replica scale-out (per [ADR-0015](./ADR-0015-container-hosting-platform.md)) makes per-process limits insufficient at scale. The trigger for migrating to a coordinated limiter must be named, not discovered in incident.
- **Quota vs. rate limit.** "100 requests per second" and "100,000 requests per month" are different shapes computed against different stores with different overage semantics. The Grid has no convention for the second one.
- **Audit and observability.** [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) committed the audit substrate but the rate-limiter rejection event is not yet a named emitter. [ADR-0010](./ADR-0010-observation-layer.md) makes 429s observable in principle but does not commit a tag convention.

The forcing function: Notify Cloud GA is the first commercial API consumer. ADR-0027 D6 names Notify Cloud as the first non-noop policy implementation. Without this ADR, Notify Cloud will hard-code its own limiter and the next public API (Web.Rest endpoints onboarding their first commercial tenant, Communications opening a public surface, any future Billing surface) will hard-code a different one. The cost of letting the convention drift across N Nodes is N rewrites later when the first inconsistency surfaces in a customer outage.

This ADR commits the substrate, the response shape, the tier-to-limits defaults for Notify Cloud at GA, and the deferral triggers that bound Phase 1.

## Decision

### D1. Primary substrate is ASP.NET Core RateLimiter, complemented by Cloudflare at the edge

The primary in-process rate-limit substrate is **ASP.NET Core `RateLimiter` middleware** (the .NET 8+ built-in `Microsoft.AspNetCore.RateLimiting`). It is the default for every Grid Node that exposes an HTTP surface.

**Why ASP.NET Core RateLimiter:**

- **First-party, in-process, free.** No Azure resource, no NuGet third-party, no operational surface beyond the host. The cheapest viable tier in the spirit of `feedback_default_cheapest_azure_tier`.
- **Algorithms covered.** Token bucket, sliding window, fixed window, and concurrency limiter are all built-in. D4 picks per-shape.
- **Partition-keyed natively.** `PartitionedRateLimiter.Create<TResource, TPartitionKey>` supports keying on `TenantId` (the Kernel context primitive per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D1) directly — no shim needed.
- **OnRejected hook.** Customizing the 429 response envelope per D6 is a single delegate.
- **Compatible with `ITenantRateLimitPolicy`.** The Kernel.Abstractions contract per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D4 returns a `TenantRateLimitDecision` — the consuming Node calls the policy from the ASP.NET Core middleware's partition factory, the policy reads the tenant tier, and the partition limiter is built from the tier's configured limits. The substrate carries the partitioning; the policy carries the per-tenant input.

**Edge complement — Cloudflare:**

Cloudflare's edge rate limiting (per [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md)) is the layer above the application limiter. Cloudflare absorbs crude abuse — DDoS, bad-actor IP floods, single-IP credential-stuffing — before traffic reaches the Container App. The application limiter is for **tier enforcement, billing fairness, and per-tenant fairness**; Cloudflare is for **infrastructure protection**. The two do not overlap by design — Cloudflare does not know about `TenantId`, and the application limiter does not see the IPs Cloudflare is already dropping.

**Explicitly rejected as primary substrate:**

- **Azure API Management.** Considered. APIM's per-key rate-limit policy is a first-class feature and would let the rate-limit decision live entirely at the gateway. Rejected on cost grounds — APIM Consumption tier has per-request pricing that compounds with paid-tenant volume, and the Developer/Basic tiers carry a per-hour base cost that is hard to justify for the Grid's current scale. APIM may be revisited if and when a Notify Cloud or Web.Rest surface specifically needs APIM's other features (developer portal, OAuth2 token issuance, transformation policies) — at that point the rate-limit substrate question is re-litigated as a single-Node choice, not a Grid-wide one.
- **Distributed Redis token bucket (or equivalent against the Cache Node per [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)).** Considered. A coordinated limiter across replicas is the right shape *when* per-process limits become insufficient. Rejected as primary substrate at Phase 1 — Notify Cloud at GA runs as a single Container App replica or a small replica count whose aggregate per-process limit is generous enough to be safe. The migration trigger is named in D5b below.
- **Cloudflare-only.** Considered. Move the entire rate-limit story to the edge. Rejected because Cloudflare does not know about `TenantId`; mapping API keys to tiers at the edge would require Cloudflare Workers or Workers KV synchronization with the Grid's tenant store, which is a substantial commitment for the wrong layer.

### D2. Policy configuration source — tier defaults in code, tier overrides in App Configuration, per-tenant overrides in a database table (deferred to first need)

The rate-limit policy configuration source is layered, with explicit precedence:

1. **Per-tenant override (highest precedence).** A row in a per-tenant rate-limit override table — used for VIP customers ("our largest paying tenant needs 5× the Scale-tier ceiling for the next 30 days"), troublemakers ("this tenant has tripped the abuse heuristic; rate-limit them at 10% of Free until the incident is resolved"), and contractual carve-outs. **Deferred to first concrete need.** Not implemented at Phase 1; the table shape and storage choice are settled when the first override is required, not speculatively.

2. **Per-tier override (middle precedence).** An App Configuration key per tier (e.g., `RateLimit:Notify:Free:RequestsPerMinute = 200`) read via the existing App Configuration plumbing (per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) and the feature-flag plumbing in [ADR-0055](./ADR-0055-feature-flag-and-progressive-rollout-strategy.md)). Lets the operator tune tier ceilings without a code change. Behind a feature flag per [ADR-0055](./ADR-0055-feature-flag-and-progressive-rollout-strategy.md) so the override can be toggled off in incident.

3. **Default tier limits (lowest precedence, baked in code).** The numbers in D3. These are the Notify Cloud-at-GA defaults; if App Configuration has no override, the code default applies. Read by the Notify Cloud `ITenantRateLimitPolicy` implementation from a static configuration record.

Precedence order is **explicit and one-way** — a per-tenant override always wins over a per-tier override always wins over a code default. The policy consults them in that order on every `EvaluateAsync` call. The lookup is cached against the tenant's `IGridContext.TenantId` per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) (InMemory backing at Phase 1; distributed backing if and when Notify Cloud scales out per D5b).

Tiers themselves are configured in Stripe per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D3 — the *price* is in Stripe; the *limits* are in the Grid. The two surfaces are deliberately separated: Stripe is the billing surface; the limiter is the enforcement surface.

### D3. Notify Cloud tier-to-limits mapping at GA

Defaults baked into the Notify Cloud `ITenantRateLimitPolicy` implementation. These are illustrative-but-committed numbers for Notify Cloud at GA. Other Nodes that introduce tier-driven rate limits in the future commit their own defaults in their own ADRs against the same convention.

**Tier naming reconciliation:** [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D3 names Notify Cloud tiers as `Free / Starter / Pro`; [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D3 names them as `Free / Pro / Scale`. This ADR adopts the **Free / Pro / Scale** naming from the more recent billing-authoritative ADR-0037. ADR-0027's mention is amended additively to align (the `Starter` tier in ADR-0027 D3 reads as `Pro`, and ADR-0027's `Pro` reads as `Scale`); the reconciliation is recorded under §Consequences.

| Tier | Per-second burst | Per-minute sustained | Per-day quota | Per-month quota | Overage behavior |
|------|------------------|----------------------|---------------|-----------------|------------------|
| **Free** | 10 | 100 | 1,000 | 10,000 | Hard 429 — no overage allowed |
| **Pro** | 50 | 1,000 | 50,000 | 500,000 | Hard 429 on burst; quota overage allowed via Stripe meter overage per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D2 |
| **Scale** | 500 | 10,000 | 1,000,000 | 10,000,000 | Hard 429 on burst; quota overage allowed via Stripe meter overage |

**Per-tier semantics:**

- **Burst** is the maximum requests in any 1-second window — protects against single-source bursts that would saturate downstream Notify dispatch.
- **Sustained** is the maximum requests in any 60-second window — the dominant fairness limit.
- **Daily / monthly quotas** are the billing-relevant ceilings. See D8 for how quota differs from rate limit.
- **Overage** distinguishes Free (hard ceiling — abuse risk too high) from Pro/Scale (soft ceiling — billable via Stripe meter overage per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D2; the rate limit is at the *burst/sustained* level only, not at the *daily/monthly* level).

**Internal tenant:** `TenantId.Internal` (per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D1) is always `Allow` per ADR-0026 D4 — the policy short-circuits on `IsInternal` without consulting any store. The numbers above do not apply to internal callers.

**Numbers are tunable.** App Configuration overrides per D2 let the operator adjust without a code change. The defaults above are reviewed at Notify Cloud GA + 90 days and at every subsequent quarterly cost review.

### D4. Algorithm — token bucket for burst/sustained, fixed window for daily/monthly quota

Algorithm choice by limit shape:

- **Burst / sustained limits (per-second, per-minute):** **Token bucket** via ASP.NET Core's `TokenBucketRateLimiter`. Allows short bursts within the bucket capacity and refills at the sustained rate. Burst-tolerant by design — a tenant that wants to send 20 notifications in one second is allowed if the bucket has 20 tokens (under the Pro tier's 50/sec burst); a tenant that wants to send 200 in one second is rejected once the bucket is empty. Matches Stripe's own rate-limit shape and is the operator-legible default.
- **Daily / monthly quotas (per-day, per-month):** **Fixed window** computed against a per-tenant counter. Clean per-day reset at UTC 00:00; clean per-month reset at the first of each month UTC. Not implemented via ASP.NET Core's `FixedWindowRateLimiter` (which is in-process and resets on a sliding wall-clock, not a calendar boundary) — the quota counter is an explicit per-tenant store (D8) with a calendar-anchored reset.

**Sliding window** and **concurrency limiter** are not used at Phase 1. Sliding window has higher computational cost than token bucket without a corresponding correctness improvement for the Grid's burst-tolerant shape. Concurrency limiter (max in-flight requests) is a different concern — useful as a defense against runaway-client connection exhaustion, but the burst/sustained limit already bounds the request rate that produces concurrent connections.

### D5. Identity resolution and limiter key

**Authenticated requests:** the limiter key is `TenantId` from `IGridContext.TenantId` per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D2. The `GridContextMiddleware` is the source of truth — the rate-limiter middleware runs **after** `GridContextMiddleware` in the ASP.NET Core pipeline so the tenant is already resolved when the partition key is computed. `TenantId.Internal` requests bypass the limiter per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D4.

**Anonymous endpoints (signup, public docs, status):** the limiter key is **`CF-Connecting-IP`** — Cloudflare's documented header for the original client IP per [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md). The fallback for non-Cloudflare-routed traffic (dev/staging where Cloudflare is bypassed) is `HttpContext.Connection.RemoteIpAddress`; the partition factory checks `CF-Connecting-IP` first and falls back to the connection IP if the header is absent. Anonymous limits are stricter than the Free tier — 60 requests/minute, 10 requests/second burst — and exist primarily as the application-layer complement to Cloudflare's edge protection.

**API key validation endpoints (the pre-auth-context request that resolves a key to a tenant):** keyed on the API key prefix (the first 8 characters of the key, which is a non-secret display value per the API-key-store contract that Notify Cloud commits in ADR-0027). The post-resolution request lands a `TenantId` in context and the per-tenant limiter takes over on subsequent endpoints. This avoids the chicken-and-egg of "I need to know the tenant to apply the tenant's rate limit, but I'm resolving the API key right now."

### D5b. Distributed-limiter migration trigger (named, not discovered)

The in-process limiter per D1 holds while every Node that uses it runs as **a single Container App replica** or as a small replica count whose **aggregate** per-process limit is acceptable (e.g., 2 replicas × Free tier's 10/sec = 20/sec aggregate, which is still a reasonable Free-tier ceiling).

The migration trigger to a coordinated, distributed limiter (Redis-class backing via the Cache Node per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) and [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) is:

- **Notify Cloud crosses 3 Container App replicas** (the point at which per-replica drift becomes operationally confusing), OR
- **A paying tenant complains about non-deterministic rate-limit behavior** (the symptom of per-replica drift), OR
- **The aggregate per-process limit exceeds 3× the tier ceiling** (the point at which the discrepancy is large enough to be billable-event-relevant).

Whichever fires first triggers a follow-up ADR ("Distributed Rate-Limiter Backing for Notify Cloud") that picks the backing (Cache Node Redis adapter is the leaning choice) and commits the migration path. The contract — `ITenantRateLimitPolicy` per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D4 — does not change at migration time; only the implementation behind it changes.

### D6. 429 response shape — `application/problem+json` per RFC 7807

Every rate-limit rejection across the Grid returns the same envelope. Pinned shape:

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 30
Content-Type: application/problem+json

{
  "type": "https://docs.honeydrunkstudios.com/errors/rate-limited",
  "title": "Rate limit exceeded",
  "status": 429,
  "detail": "You have exceeded your tier's per-minute request limit. Retry after 30 seconds.",
  "instance": "/v1/notify/send",
  "tier": "free",
  "retry_after_seconds": 30,
  "correlation_id": "01HXXXXXXXXX..."
}
```

Field discipline:

- **`type`** — stable URI; the docs site at `docs.honeydrunkstudios.com/errors/rate-limited` carries the canonical human-readable explanation. Per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md), the docs site is per-API-version; the error type is shared across versions (the meaning of "rate limited" does not version with the API).
- **`title`** — fixed string "Rate limit exceeded" for machine-readable matching.
- **`status`** — always 429 in this envelope.
- **`detail`** — operator-and-developer-friendly explanation. Includes the retry advisory in seconds.
- **`instance`** — the request path.
- **`tier`** — the tenant's current tier (lower-cased — `"free"`, `"pro"`, `"scale"`). **Omitted for anonymous requests** to avoid leaking that there is or is not a tier system to a caller who has not authenticated; the response for anonymous rate-limit rejection omits `tier`, `tenant_id`, and any tenant-identifying field.
- **`retry_after_seconds`** — duplicates the `Retry-After` header in the body for clients that prefer reading from the body.
- **`correlation_id`** — the `IGridContext.CorrelationId` (per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) Invariant 6) so a customer reporting a 429 can quote the correlation ID and the operator can find the request in logs.

**`tenant_id` is deliberately not in the response body.** Authenticated clients already know their tenant ID; anonymous clients must not learn it from the rate-limit response (per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) — tenant identity is a non-public attribute and the rate-limit response is the wrong channel to surface it). The `correlation_id` is sufficient for the operator-side lookup.

**`Retry-After` is in seconds, not HTTP-date.** HTTP-date format is permitted by the RFC but less common in modern API clients; seconds is the operator-legible default.

### D7. Success-side `RateLimit-*` headers on every response

Every response from a rate-limited endpoint — 200, 4xx, 5xx, and 429 alike — carries the IETF draft `RateLimit-*` header set:

```http
RateLimit-Limit: 100
RateLimit-Remaining: 47
RateLimit-Reset: 23
```

- **`RateLimit-Limit`** — the current window's maximum (e.g., 100 for the per-minute sustained limit on the Free tier).
- **`RateLimit-Remaining`** — tokens left in the current window. Decreases on each request; refills at the algorithm's rate.
- **`RateLimit-Reset`** — seconds until the current window resets.

The Grid emits the IETF `RateLimit-*` headers (per the draft `draft-ietf-httpapi-ratelimit-headers`). The legacy `X-RateLimit-*` mirrors are **not** emitted; the canonical form is the draft IETF form. SDK clients per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D8 parse `RateLimit-*` directly.

When multiple limits apply (per-second burst, per-minute sustained, daily quota), the headers report **the most-restrictive limit currently in effect** — the limit closest to firing. The behavior matches the IETF draft's "policy" parameterization but the Grid does not currently emit a `RateLimit-Policy` header (deferred until a customer requests it; the docs site explains the policy structure).

### D8. Rate limit vs. quota — distinct concerns, distinct stores

The Grid distinguishes **rate limits** (short-window, burst-tolerant, ASP.NET Core RateLimiter) from **quotas** (long-window, billing-relevant, calendar-anchored counter store).

**Rate limit (per-second, per-minute):**

- Computed in the ASP.NET Core `RateLimiter` middleware.
- Storage: in-process token bucket (or distributed if D5b triggers).
- Reset: continuous (token bucket refills) or wall-clock window (sliding/fixed).
- Overage: hard 429.
- Audit: emitted per D10.

**Quota (per-day, per-month):**

- Computed against a **per-tenant counter store** — the counter increments on every billable operation (e.g., every `notify/send` call), and the policy consults the counter against the tier's daily/monthly ceiling.
- Storage: a counter store keyed on `(TenantId, CounterKey, Window)`. The Phase 1 default is **Azure Storage Tables** (cheap, sufficient at the v1 tenant-count ceiling, no extra Azure resource provisioning beyond what Notify Cloud already owns per `feedback_provision_when_needed`). Distributed cache backing per [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) is a deferred consideration if read latency on the counter becomes a hot path.
- Reset: calendar-anchored — UTC 00:00 for daily, first-of-month UTC for monthly.
- Overage: tier-dependent per D3. Free tier overage = hard 429. Pro/Scale quota overage = **billable** via the Stripe meter overage pipe per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D2; the request proceeds, a `BillingEvent` is emitted with the overage marker, and Stripe handles the metered pricing. The Grid does not refuse Pro/Scale tenants on quota overage; it bills them.
- Audit: every overage-billable event is emitted to [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) substrate as `QuotaOverageBilled`.

**Why split:** rate limit is a fairness primitive (no single tenant should burst-flood the dispatch path); quota is a billing primitive (the tier the customer pays for has a ceiling that maps to invoice). Conflating them either gives away free rate-limit slack against Pro/Scale customers' burstiness (because the per-minute limiter has no concept of "this tenant is at 99% of their monthly quota — be stingy") or wrongly hard-429s a Pro tenant who pays for overage. The two stores compute different things at different cadences against different ceilings.

### D9. The limiter lives in Kernel as an opt-in extension, configured per-Node

The rate-limiter middleware wiring lives in `HoneyDrunk.Kernel` as an extension method:

```csharp
public static IServiceCollection AddGridRateLimiting(
    this IServiceCollection services,
    Action<GridRateLimitOptions>? configure = null);

public static IApplicationBuilder UseGridRateLimiting(
    this IApplicationBuilder app);
```

`AddGridRateLimiting` registers the ASP.NET Core `RateLimiter` services, wires the partition factory to read `IGridContext.TenantId`, applies the D6 / D7 response conventions, and connects to the `ITenantRateLimitPolicy` per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D4. `UseGridRateLimiting` registers the middleware in the pipeline (after `UseRouting` and `UseAuthentication` but before endpoint dispatch — the middleware ordering is documented at the extension method).

**Per-Node opt-in.** Every Node that exposes an HTTP surface composes `AddGridRateLimiting` / `UseGridRateLimiting` at host time. Library-only Nodes (Kernel, Vault, Transport) do not. The composition is explicit, not implicit — a Node that does not want rate limiting (internal tools, dev-only utilities) simply does not compose it.

**Per-endpoint policies via attribute.** The middleware reads `[EnableRateLimiting("policy-name")]` from each endpoint and applies the corresponding partition limiter. The default-named policies committed by the Kernel extension:

- `"tier"` — the per-tenant tier-driven limiter (token bucket). The default for tenant-authenticated endpoints.
- `"anon"` — the per-IP anonymous limiter (token bucket). The default for unauthenticated endpoints.
- `"quota-billable"` — composed with `"tier"` on endpoints that count toward daily/monthly quota (the calendar-anchored counter increment per D8).

Nodes can register Node-specific policies on top of the Kernel defaults (e.g., Notify Cloud's `INotifyCloudGateway` endpoints compose `"tier"` + `"quota-billable"`).

**Why Kernel and not a gateway Node:** the [PDR-0008 / ADR-XXXX gateway standup is deferred](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) and there is no committed Gateway Node today. Pushing the rate-limit wiring into Kernel means every Node that exposes HTTP gets the same shape, and a future Gateway Node — when it lands — reuses the Kernel extension without re-litigating the conventions in D6 / D7. If and when a Gateway Node is stood up, the rate-limit middleware moves up one layer (or composes at both layers if endpoint-level enforcement remains desirable); the Kernel extension stays as the per-Node primitive.

### D10. Audit and observability — every 429 is an Audit emit and a Pulse metric

**Audit emission** (per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) substrate):

- Every **hard** 429 (rate limit or hard-quota overage) emits a `RateLimitRejected` audit event with fields: `tenant_id` (or `null` for anonymous), `endpoint`, `limit_type` (`burst` / `sustained` / `daily-quota` / `monthly-quota`), `tier`, `retry_after_seconds`, `correlation_id`. Captured durably per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)'s WORM-by-interface stance.
- Quota-overage **billable** events (Pro/Scale tenants over their monthly quota) emit `QuotaOverageBilled` instead of `RateLimitRejected` — the request proceeded, the billing meter was incremented, and the audit record captures the transition.

Audit is emitted via the Notify Cloud `ITenantRateLimitPolicy` implementation (or the equivalent per-Node implementation in other rate-limited Nodes). The middleware does not emit Audit directly — the policy is the auditor, the middleware is the enforcer.

**Observability** (per [ADR-0010](./ADR-0010-observation-layer.md)):

- A counter metric `rate_limit_rejection_count` with tags `tenant_id`, `endpoint`, `tier`, `outcome` (the `outcome` distinguishes `rate-limit` from `quota-overage-billed`). `tenant_id` is a low-cardinality tag bounded by the [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D7 paying-tenant ceiling (tens at v1).
- A gauge `rate_limit_remaining_ratio` per tenant per endpoint — the current `RateLimit-Remaining / RateLimit-Limit` ratio. Useful for surfacing "tenant X consistently runs at 95% of their tier ceiling" before they complain.
- **Alarm threshold:** a spike in `rate_limit_rejection_count` for a single `(tenant_id, endpoint)` pair over a 5-minute window (≥ 50 rejections) is a paging signal. The interpretation: either the tenant is being abused, the tenant is mis-sized for their tier, or there is a misconfigured client. The on-call surface (per [ADR-0054](./ADR-0054-incident-response-and-on-call-model-for-a-one-person-studio.md)) decides which.

### D11. Out of scope

The following are explicitly **not** decided by this ADR:

- **DDoS mitigation and abuse heuristics at the edge** — Cloudflare's job per [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md). The application limiter assumes the edge has already absorbed gross abuse.
- **Account-level lockout for failed authentication.** Auth's concern per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)'s API-key-store contract and [ADR-0056](./ADR-0056-threat-model-and-security-review-cadence.md). A failed-auth lockout is not a rate limit — it is a credential-abuse defense and lives at a different layer with different state (per-key, not per-tenant).
- **Cost-based shedding and kill switches.** [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)'s concern. The rate limiter does not shed load on cost ceilings; the cost kill switch does. The two surfaces complement each other; neither subsumes the other.
- **Per-tenant rate-limit override storage and shape.** Per D2, the override table is deferred to first concrete need. The storage choice (a row in the Notify Cloud tenant store, a separate per-tenant-override table, a feature-flag-style override) is settled when the first VIP or troublemaker drives the requirement.
- **The per-tenant counter store's exact schema for daily/monthly quotas.** Per D8, the Phase 1 default is Azure Storage Tables with a `(TenantId, CounterKey, Window)` row shape; the schema is settled in the implementation packet.
- **Anti-abuse heuristics specific to signup flows (e.g., disposable-email detection, IP reputation).** A separate concern from rate limiting; lives in the signup-hardening ADR if and when it is written.
- **Cross-cluster (multi-region) coordination of the limiter.** The Grid is single-region today per [ADR-0015](./ADR-0015-container-hosting-platform.md); multi-region rate-limit coordination is a future-state concern.

## Consequences

### Affected Nodes

- **HoneyDrunk.Kernel** — gains `AddGridRateLimiting` / `UseGridRateLimiting` extension methods and the ASP.NET Core `RateLimiter` wiring. No new abstractions (the contract is [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md)'s `ITenantRateLimitPolicy`). The Kernel package's surface grows additively; per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) D1 this is a minor bump.
- **HoneyDrunk.Notify.Cloud** — ships the production `ITenantRateLimitPolicy` implementation, the per-tenant counter store wiring for D8 quotas, and composes the Kernel extension at host time. Tier-to-limits defaults from D3 are baked into the implementation; App Configuration overrides per D2 are read at host startup.
- **HoneyDrunk.Web.Rest** — composes the Kernel extension on its tenant-facing endpoints. The default-tier anonymous limiter per D5 applies to its anonymous endpoints; the per-tenant limiter applies to authenticated endpoints. No code change to Web.Rest beyond the host-level composition.
- **HoneyDrunk.Communications** — when its public surface activates (per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md)), it composes the Kernel extension on the same terms.
- **HoneyDrunk.Audit** — gains a new emit-path consumer; `RateLimitRejected` and `QuotaOverageBilled` join the catalog of audit event types per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md).
- **HoneyDrunk.Pulse** — gains the new `rate_limit_rejection_count` counter and `rate_limit_remaining_ratio` gauge per D10. No package change; this is operational telemetry configuration.

### Invariants

No new invariants are introduced by this ADR. The existing invariants that the rate limiter is required to honor:

- **Invariant 8 (secret values never appear in logs or traces).** The 429 response body's `detail` field, the audit emit, and the Pulse metric all carry no secret material. API key prefixes (the 8-character display prefix per the Notify Cloud API-key-store contract) are not secret and may appear; the full key never does.
- **Invariant 5 / 6 (GridContext present and populated).** The middleware ordering — `GridContextMiddleware` before the rate-limiter middleware — is required for `TenantId` to be available at partition-factory time. The middleware composition documented at `UseGridRateLimiting` enforces this.

### Reconciliation with prior ADRs

- **[ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D3 tier naming.** ADR-0027 lists Notify Cloud tiers as `Free / Starter / Pro`; [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D3 lists them as `Free / Pro / Scale`. This ADR adopts the ADR-0037 naming. ADR-0027 should receive an additive amendment (footnote or D3 amendment block) recording the tier-naming alignment with ADR-0037 and this ADR. The amendment is editorial — no contract change, no behavior change — but the catalog and any code that has already started referencing `NotifyCloudTenantTier.Starter` needs to be updated to `NotifyCloudTenantTier.Pro` (and the original `Pro` to `Scale`). Tracked in the follow-up checklist.
- **[ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) deferred storage.** ADR-0026 D4 explicitly deferred the rate-limit backend choice to "consumer Nodes." This ADR is the consumer-Node-level decision (specifically Notify Cloud's first concrete implementation, generalized to a Grid-wide convention at the Kernel extension layer). No ADR-0026 amendment is required — the deferral is resolved within ADR-0026's own permission.

### Operational Consequences

- **In-process limiter has per-replica drift.** Until D5b's distributed-limiter migration trigger fires, a Notify Cloud tenant whose traffic lands on different replicas can in principle observe slightly higher aggregate limits than their tier nominally allows (each replica grants the per-process bucket independently). The drift is bounded — at 2 replicas the maximum drift is 2× — and is acceptable at the v1 paying-tenant ceiling. The trigger to migrate is named, not discovered.
- **Quota counter store introduces a new per-tenant write per request.** Azure Storage Tables is cheap (sub-cent per 10K transactions) but the write is on the hot path. Mitigation: the counter increment is batched (per-replica batch flush every 5 seconds or 100 requests, whichever comes first) and the per-replica buffer is reconciled to the table on flush. The discipline matches the [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md) outbox pattern.
- **App Configuration override propagation latency.** The per-tier override (D2 layer 2) is read from App Configuration with a cache TTL of 60 seconds (per the App Configuration default). Operator changes to a tier ceiling take up to 60 seconds to propagate. Acceptable; operator-side ceiling changes are infrequent and not incident-critical.
- **The 429 response shape is committed across the Grid.** Future Nodes that expose HTTP surfaces inherit the shape automatically by composing the Kernel extension. Bespoke 429 shapes are forbidden — drift on the response shape would break SDK-side rate-limit parsing per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D8.

### Follow-up Work

- Kernel ships `AddGridRateLimiting` / `UseGridRateLimiting` extension methods, D6 response shape, D7 success-side headers, D9 named policies.
- Notify Cloud ships the production `ITenantRateLimitPolicy` implementation with D3 defaults and D8 quota counter.
- Audit catalog gains `RateLimitRejected` and `QuotaOverageBilled` event types per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md).
- Pulse dashboards gain the D10 counter and gauge.
- [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D3 tier-naming additive amendment (Starter → Pro, Pro → Scale to align with [ADR-0037](./ADR-0037-payment-and-billing-integration.md)).
- Docs site at `docs.honeydrunkstudios.com/errors/rate-limited` is authored as the canonical RFC 7807 `type` URI target.
- Watch list: D5b distributed-limiter migration trigger; quota counter store schema evaluation against [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) once a backing exists.

## Alternatives Considered

### Azure API Management as the primary rate-limit substrate

Considered. APIM's per-key rate-limit policy is a first-class feature; the rate-limit decision could live entirely at the gateway, with no Container App middleware required. Authentication, rate limiting, and key issuance would compose as a single APIM surface.

Rejected on cost grounds. APIM Consumption tier has per-request pricing that compounds with paid-tenant volume — at the Notify Cloud GA scale (tens of paying tenants × Pro-tier sustained 1000/min) the bill is non-trivial and grows with success. The Developer tier is too small for production; the Basic and Standard tiers carry a per-hour base cost (USD $30–$700/month) that is hard to justify for a Phase-1 substrate when ASP.NET Core RateLimiter is free and sufficient. APIM is reconsidered when a specific Node needs APIM's other features (developer portal, OAuth2 token issuance, request/response transformation) at a level that justifies the line item.

### Distributed Redis-class limiter from day one

Considered. Stand up the Cache Node ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) with a Redis adapter and a token-bucket implementation against it; coordinate across replicas from Phase 1.

Rejected. The Grid is single-replica or low-replica at GA; the per-process limiter's drift is small and bounded. Pre-provisioning a Redis-class backing and the operational surface that goes with it (a managed Redis instance, the Cache Node's first implementation, the migration path from in-memory to distributed) is real work that does not pay off at GA scale. The trigger to migrate is named in D5b; deferring until the trigger fires is the cheaper path. This matches the `feedback_provision_when_needed` discipline.

### Cloudflare-only rate limiting (move everything to the edge)

Considered. Cloudflare's rate-limit rules are mature and can match on path, header, IP, and country. Pushing the entire rate-limit decision to the edge means the Container App never sees the rate-limited request.

Rejected. Cloudflare's rate-limit rules do not see `IGridContext.TenantId`. Tier-to-limits mapping requires the rate-limit decision to know the tenant's tier, which requires API key resolution, which requires database access — none of which Cloudflare has at the edge without standing up Workers + Workers KV with periodic sync from the Grid's tenant store. The cost of building and operating that sync (and reconciling its eventual-consistency staleness against billing accuracy) is substantially higher than running ASP.NET Core RateLimiter inside the Container App with the tenant context already resolved. Cloudflare stays as the edge complement per D1 for abuse mitigation; it does not subsume the application limiter.

### Sliding window algorithm

Considered. Sliding window is more accurate than fixed window (no end-of-window burst) and arguably more accurate than token bucket (smoother enforcement of average rate).

Rejected for burst/sustained. Token bucket is sufficient for the burst-tolerant shape and is cheaper to compute (O(1) vs. sliding window's O(log N) or O(N) depending on implementation). Token bucket also maps better to operator intuition ("you have 50 tokens; they refill at 1000/minute") than sliding window's "you can do at most N in any rolling 60-second period." Sliding window may be revisited if a specific endpoint demonstrates that token bucket's burst tolerance is being abused; no current evidence supports that.

### Endpoint-level (not surface-level) rate-limit policies

Considered. Per-endpoint rate-limit attributes that allow different policies on different endpoints — e.g., `/notify/send` at 1000/min, `/notify/preferences` at 100/min, `/notify/status` at 10000/min.

Partially adopted, partially deferred. The Kernel extension supports per-endpoint policies via the `[EnableRateLimiting("policy-name")]` attribute (D9). The Phase-1 defaults bake just three named policies — `"tier"`, `"anon"`, `"quota-billable"`. Endpoint-specific named policies (e.g., a stricter `"tier-strict-write"`) are introduced only when a specific endpoint demonstrates that the default tier policy is wrong-sized. Premature endpoint-level tuning is a known anti-pattern; the discipline matches `feedback_provision_when_needed`.

### Bake the tier limits into the Stripe price configuration

Considered. The tier-to-limits mapping is fundamentally a tier-pricing concern; conceptually it could live in Stripe alongside the tier price. The rate-limit policy would consume the limits from Stripe metadata on the subscription.

Rejected. Stripe is the billing surface, not the configuration surface. Coupling rate limits to Stripe data means a Stripe outage degrades the rate-limit decision (or stales the cached limits to dangerous values). It also means tuning a tier ceiling requires a Stripe metadata update, which is an awkward operator surface for a runtime concern. The split — Stripe owns price, the Grid owns enforcement — is the right boundary per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D3's "tier and overage prices are configured in Stripe, not in the Grid."

### Conflate rate limit and quota into a single surface

Considered. Treat the daily/monthly quota as just a "longer rate-limit window" — a 100,000-request bucket that refills at 1/0.864-seconds-per-token over the course of a day.

Rejected. The two concerns have different shapes (token bucket vs. calendar-anchored counter), different overage semantics (hard 429 vs. billable meter), different storage (in-process bucket vs. per-tenant durable counter), and different audit treatments (`RateLimitRejected` vs. `QuotaOverageBilled`). Forcing them through one surface either loses the calendar-reset semantics or loses the burst-tolerance semantics. The split in D8 keeps both clean.
