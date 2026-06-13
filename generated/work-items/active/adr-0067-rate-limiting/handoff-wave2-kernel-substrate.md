# Handoff — Wave 2: Kernel Substrate

**Initiative:** `adr-0067-rate-limiting`
**Wave transition:** Wave 1 (governance + catalog) → Wave 2 (Kernel substrate)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 landed

- **Packet 00** — ADR-0067 flipped to **Accepted**. **No invariants added.** ADR-0067 §Consequences/Invariants is explicit: "No new invariants are introduced by this ADR. The existing invariants that the rate limiter is required to honor: Invariant 8 (secret values never appear in logs or traces); Invariant 5 / 6 (GridContext present and populated)." Packet 00 did not edit `constitution/invariants.md` and did not reserve a batch-block number for ADR-0067.
- **Packet 01** — The Rate Limiting section was appended to `infrastructure/reference/tech-stack.md` (substrate = ASP.NET Core `RateLimiter` middleware; edge complement = Cloudflare; rejected = APIM, Phase-1 distributed Redis, Cloudflare-only). The Kernel extension surface was registered in `catalogs/contracts.json` under `honeydrunk-kernel`'s `interfaces` array (`AddGridRateLimiting`, `UseGridRateLimiting`, the named-policy constants). **No new abstractions** — `ITenantRateLimitPolicy` was already in the catalog from ADR-0026's catalog packet. **No `relationships.json` edits** — no new Node-to-Node edge.

ADR-0067's decisions are now live rules. Packet 02 ships the substrate the catalog already advertises.

## What Wave 2 must deliver (packet 02)

Ship the substrate in **`HoneyDrunk.Kernel`** (live Node; currently `0.7.0`; .NET 10.0; two packages — `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel` runtime):

- **`HoneyDrunk.Kernel` runtime** — new types:
  - `AddGridRateLimiting(this IServiceCollection, Action<GridRateLimitOptions>?)` — wires ASP.NET Core `RateLimiter` services, the partition factory keyed on `IGridContext.TenantId`, the RFC 7807 `OnRejected` delegate, and the three default-named policies.
  - `UseGridRateLimiting(this IApplicationBuilder)` — registers the rate-limiter middleware + the small response-decorating middleware that emits the IETF `RateLimit-*` success-side headers. Documented ordering: **after** `UseRouting` / `UseAuthentication` / `UseGridContext`; **before** endpoint dispatch.
  - `GridRateLimitOptions` — options class. Defaults match ADR-0067 D5 anonymous (60/min, 10/sec burst). Hooks: API-key-prefix extractor (default null; Notify Cloud will fill in), per-endpoint `operationKey` (default null → endpoint route name).
  - `GridRateLimitPolicies` — `public static class` with three `public const string`: `Tier = "tier"`, `Anonymous = "anon"`, `QuotaBillable = "quota-billable"`.
- **`HoneyDrunk.Kernel.Abstractions`** — **no changes.** The contract `ITenantRateLimitPolicy` is unchanged (ADR-0026 D4). Per invariant 1, Abstractions has zero HoneyDrunk runtime dependencies; the new code is wiring, not contract.

## Version-coordination with `adr-0042-idempotency` — load-bearing

Both this initiative and `adr-0042-idempotency` bump `HoneyDrunk.Kernel` from `0.7.0` to `0.8.0`. Per invariant 27 ("all projects in a solution share one version"), the **first packet on the solution bumps**; subsequent packets append to the in-progress `[0.8.0]` CHANGELOG. Two cases at execution time:

1. **ADR-0042 packet 02 lands first.** The Kernel solution is already at `0.8.0` when this packet 02 starts. This packet does NOT bump again — it appends to the in-progress repo-level `[0.8.0]` CHANGELOG entry and adds its per-package `HoneyDrunk.Kernel/CHANGELOG.md` entry for the rate-limiting wiring.
2. **This packet 02 lands first.** It bumps the Kernel solution `0.7.0` → `0.8.0` (every non-test `.csproj` in one commit). ADR-0042 packet 02 then appends.

Either ordering works. State the chosen case explicitly in the PR. File paths do not conflict: idempotency code is under (e.g.) `HoneyDrunk.Kernel/Idempotency/`; rate-limiting code is under (e.g.) `HoneyDrunk.Kernel/RateLimiting/`. The two packets share `CHANGELOG.md` and `README.md` only — a rebase resolves cleanly.

The human NuGet-release of `HoneyDrunk.Kernel` `0.8.0` happens *once* after both packets are merged (or once after the first packet, with a follow-up `0.8.0` re-push including the second — coordinate with the publisher). Agents never tag or publish.

## Interface signatures and behavior packet 02 must produce

`AddGridRateLimiting` configures `services.AddRateLimiter(...)` with:
- `RejectionStatusCode = 429`.
- `OnRejected` delegate emitting `application/problem+json` (RFC 7807) body with fields: `type` = `https://docs.honeydrunkstudios.com/errors/rate-limited`, `title` = `Rate limit exceeded`, `status` = 429, `detail`, `instance` (request path), `tier` (lower-cased — **omitted for anonymous**), `retry_after_seconds`, `correlation_id` (from `IGridContext.CorrelationId`). **`tenant_id` is deliberately NOT in the body.** `Retry-After` header in seconds, not HTTP-date.
- A `PartitionedRateLimiter` whose partition factory chooses:
  - `TenantId.Value` for authenticated requests with a non-internal `TenantId`. Calls `ITenantRateLimitPolicy.EvaluateAsync(...)` and builds a `TokenBucketRateLimiter` from the returned `TenantRateLimitDecision`.
  - **No limiter** for `TenantId.Internal` (ADR-0026 D4 short-circuit).
  - `CF-Connecting-IP` for anonymous (with `HttpContext.Connection.RemoteIpAddress` fallback when the header is absent). Anonymous defaults: 60/min, 10/sec burst.
  - The 8-character API-key display prefix for API-key-validation pre-auth endpoints (the host provides the extraction hook via `GridRateLimitOptions`).
- Three named policies: `"tier"`, `"anon"`, `"quota-billable"`. The `"quota-billable"` policy is a **marker** at the Kernel level — endpoints attributed with it inherit the `"tier"` partition; the actual quota enforcement (calendar-anchored counter) is the consuming Node's policy responsibility per ADR-0067 D8. **Kernel does not ship a quota counter store.**

`UseGridRateLimiting` calls `app.UseRateLimiter()` and inserts the response-decorating middleware that emits IETF `RateLimit-*` headers on every response from a rate-limited endpoint (200, 4xx, 5xx, 429). Headers: `RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`. **Legacy `X-RateLimit-*` mirrors are NOT emitted.** When multiple limits apply, the most-restrictive limit currently in effect is reported.

## Frozen / do-not-touch

- **`ITenantRateLimitPolicy`** (in `HoneyDrunk.Kernel.Abstractions`, from ADR-0026 D4) — consumed, NOT changed. Signature stays `ValueTask<TenantRateLimitDecision> EvaluateAsync(TenantId, string operationKey, CancellationToken)`.
- **`TenantRateLimitDecision`** (record, in `HoneyDrunk.Kernel.Abstractions`) — consumed, NOT changed.
- **`NoopTenantRateLimitPolicy`** (in `HoneyDrunk.Kernel`) — preserved. Nodes that have not opted into a real policy continue to see `Allow` for every decision.
- **`UseGridContext`** (existing) — its ordering relative to `UseGridRateLimiting` is documented (UseGridContext first), but `UseGridContext` itself is not modified.
- **`HoneyDrunk.Kernel.Abstractions`** — no new types in this packet (invariant 1).

## Invariants binding Wave 2

- **Invariant 1** — `HoneyDrunk.Kernel.Abstractions` has zero HoneyDrunk runtime dependencies. Nothing in this packet lands in Abstractions.
- **Invariant 4** — DAG; Kernel is at the root. NO `PackageReference` on `HoneyDrunk.Transport` or any other HoneyDrunk runtime package. ASP.NET Core's `Microsoft.AspNetCore.RateLimiting` is a Microsoft framework package, not a HoneyDrunk dependency.
- **Invariant 5 / 6** — GridContext present and populated. Middleware ordering — `UseGridContext` before `UseGridRateLimiting` — is documented at the `UseGridRateLimiting` extension method's XML doc-comment.
- **Invariant 8** — secret values never in logs or traces. Full API keys never appear in any partition key, log, header, or body. The 8-character display prefix is permitted and is the only key-related material that may surface. A test asserts a request with a full API key in the payload sees the full key absent from the partition-key trace, any header, and any body.
- **Invariant 12 / 27** — solution version bump. Both non-test `.csproj` files go to `0.8.0` in one commit if this packet is the bumper; per-package CHANGELOG only for packages with functional change (`HoneyDrunk.Kernel` gets an entry; `HoneyDrunk.Kernel.Abstractions` gets the alignment bump only, no noise entry).
- **Invariant 13** — all public APIs have XML documentation. `AddGridRateLimiting`, `UseGridRateLimiting`, `GridRateLimitOptions`, `GridRateLimitPolicies` and the three constants all carry XML doc-comments. The middleware-ordering note is on `UseGridRateLimiting`.
- **Invariant 51** — no `Thread.Sleep` in test code. Token-bucket timing driven by `TimeProvider` or the rate-limiting test hooks.

## Acceptance gate for the wave

Packet 02's PR passes the `pr-core.yml` tier-1 gate and the Kernel contract-shape canary (the additions are runtime-only; no Abstractions surface change; the canary is undisturbed). `HoneyDrunk.Kernel` is at `0.8.0` (bumped by this packet OR aligned with `adr-0042-idempotency` packet 02 having bumped first) and ships `AddGridRateLimiting`, `UseGridRateLimiting`, `GridRateLimitOptions`, `GridRateLimitPolicies`. Wave 3 (packets 03, 04, 05 — docs-only registrations in Audit, Pulse, and Architecture respectively) is **not** blocked by Wave 2 — those packets depend only on packet 00 and unblocked when 00 merges. They are grouped as Wave 3 for tidy filing.

**Human package release at the Wave 2→3 boundary — agents never tag.** After packet 02 merges, a human pushes a git release tag on `HoneyDrunk.Kernel` for `0.8.0` so consuming Nodes can compile against it. If `adr-0042-idempotency` packet 02 has also merged by then, the same `0.8.0` release carries both feature sets. Coordinate the tag-push with the operator.

## Deferred follow-ups carried forward

- **Notify Cloud production `ITenantRateLimitPolicy` + quota counter store** — specified in packet 05 of this initiative; filed as a new packet against `HoneyDrunk.Notify.Cloud` after `adr-0027-notify-cloud-standup` packet 06 lands.
- **`docs.honeydrunkstudios.com/errors/rate-limited` page** — Studios-website follow-up. The 429 `type` URI is stable in code; the docs page authoring is separate.
- **Per-tenant override store** (ADR-0067 D2 layer 1) — deferred to first concrete need.
- **Distributed limiter** (ADR-0067 D5b) — triggers named; future ADR if and when a trigger fires.
