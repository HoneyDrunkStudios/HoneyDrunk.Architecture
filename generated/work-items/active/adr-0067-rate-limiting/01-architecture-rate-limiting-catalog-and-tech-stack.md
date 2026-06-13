---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0067", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0067"]
wave: 1
initiative: adr-0067-rate-limiting
node: honeydrunk-architecture
---

# Record the rate-limiting substrate in tech-stack.md and the Kernel extension surface in contracts.json

## Summary
Record ADR-0067's substrate choice and Kernel extension surface as catalog and reference data: append a Rate Limiting section to `infrastructure/reference/tech-stack.md` capturing the ASP.NET Core `RateLimiter` middleware choice + the Cloudflare edge complement + the explicitly-rejected alternatives (APIM, distributed Redis at Phase 1, Cloudflare-only); and register the new Kernel extension surface (`AddGridRateLimiting`, `UseGridRateLimiting`, the three named policies `"tier"` / `"anon"` / `"quota-billable"`) in `catalogs/contracts.json` under the `honeydrunk-kernel` Node block. No new abstractions — the primitive (`ITenantRateLimitPolicy`) is ADR-0026's, registered there already.

## Context
ADR-0067 D1 commits the substrate (ASP.NET Core `RateLimiter` middleware + Cloudflare at the edge). The `infrastructure/reference/tech-stack.md` document is the Grid's single source of truth for cross-cutting platform choices — recording this here means future ADRs and reviewers see "rate limiting = ASP.NET Core RateLimiter" without having to read ADR-0067 to discover it.

ADR-0067 D9 commits the Kernel extension method surface (`AddGridRateLimiting`, `UseGridRateLimiting`) and the three default-named policies (`"tier"`, `"anon"`, `"quota-billable"`). These are **runtime extension methods**, not new abstractions: the primitive `ITenantRateLimitPolicy` already exists in `HoneyDrunk.Kernel.Abstractions` per ADR-0026 D4 (and is already registered in `catalogs/contracts.json` under `honeydrunk-kernel`). ADR-0067 adds the *wiring* in the Kernel runtime, not a new contract. The catalog entries here register the new extension surface so the Grid's contract/dependency graph stays accurate.

The Notify Cloud production `ITenantRateLimitPolicy` implementation is **not** registered here — Notify Cloud is not yet stood up (ADR-0027 is Proposed) and its catalog entry does not exist. When the ADR-0027 standup initiative completes (packet 06 of `adr-0027-notify-cloud-standup`), Notify Cloud's catalog row is created and its consumption of `ITenantRateLimitPolicy` is recorded there.

This is a docs/catalog packet. No code, no .NET project.

## Scope
- `infrastructure/reference/tech-stack.md` — append a new section recording ASP.NET Core `RateLimiter` middleware as the primary in-process rate-limit substrate, Cloudflare edge rate limiting as the edge complement (per ADR-0029), and the explicitly-rejected alternatives. Match the document's existing entry shape.
- `catalogs/contracts.json` — append entries to the `honeydrunk-kernel` node block's `interfaces` array for the new Kernel extension surface: `AddGridRateLimiting` (DI registration extension), `UseGridRateLimiting` (middleware extension), and the three named-policy constants (`"tier"`, `"anon"`, `"quota-billable"`). Do **not** add a new `ITenantRateLimitPolicy` entry — it is already there from ADR-0026.
- `catalogs/relationships.json` — **NOT modified** in this packet. No new Node-to-Node edge is created; Notify Cloud's consumption of `ITenantRateLimitPolicy` is registered at Notify Cloud standup time, not now.

## Proposed Implementation
1. **`infrastructure/reference/tech-stack.md`** — open the file and locate the appropriate section (look for an existing "Cross-cutting" / "Platform Services" / "Hosting" grouping; if none fits exactly, append a new `## Rate Limiting` section in the order the rest of the doc uses). Add the new entry matching the document's existing shape — at minimum:
   - **Substrate:** ASP.NET Core `RateLimiter` middleware (`Microsoft.AspNetCore.RateLimiting`, first-party, .NET 8+; partition-keyed limiter with `TenantId` as the partition).
   - **Algorithms:** Token bucket (burst/sustained, per-second and per-minute); fixed window with calendar-anchored reset (daily/monthly quotas; computed against a per-tenant counter store, not via ASP.NET's in-process `FixedWindowRateLimiter`).
   - **Edge complement:** Cloudflare (per ADR-0029) — DDoS, gross-IP-floods, credential-stuffing handled at the edge before traffic reaches the Container App; the application limiter is for tier enforcement and per-tenant fairness.
   - **Rejected alternatives:** Azure API Management (cost — APIM Consumption per-request pricing compounds with paid-tenant volume; Developer/Basic per-hour base cost hard to justify at current scale); distributed Redis-class limiter at Phase 1 (premature — Notify Cloud at GA runs as a single Container App replica; migration trigger named in ADR-0067 D5b); Cloudflare-only (no `TenantId` at the edge without standing up Workers + Workers KV sync against the tenant store).
   - **Cross-link:** ADR-0067 (substrate + policy), ADR-0026 D4 (`ITenantRateLimitPolicy` contract), ADR-0029 (Cloudflare edge), ADR-0015 (Container Apps hosting).
2. **`catalogs/contracts.json`** — locate the node block whose `node` value is `honeydrunk-kernel` (do not rely on line numbers). Append entries to that block's `interfaces` array, matching the existing `{ "name", "kind", "description" }` shape:
   - `AddGridRateLimiting` — `kind: extension-method` — "DI registration extension on `IServiceCollection` that wires ASP.NET Core `RateLimiter` services, the partition factory reading `IGridContext.TenantId`, the RFC 7807 429 response convention (ADR-0067 D6), the IETF `RateLimit-*` success-side headers (ADR-0067 D7), and the three default-named policies. Consumes `ITenantRateLimitPolicy` (per ADR-0026 D4) for the per-tenant evaluation. Per-Node opt-in."
   - `UseGridRateLimiting` — `kind: extension-method` — "ASP.NET Core middleware registration extension on `IApplicationBuilder`. Registers the rate-limiter middleware in the pipeline. Must run after `UseRouting` and `UseAuthentication` and after `UseGridContext` (so `TenantId` is resolved before partition-key computation), and before endpoint dispatch."
   - `GridRateLimitPolicies` (or the equivalent constants holder packet 02 names) — `kind: constants` — "The three default-named partition policies: `\"tier\"` (per-tenant tier-driven token bucket), `\"anon\"` (per-IP token bucket for unauthenticated endpoints), `\"quota-billable\"` (composed with `\"tier\"` on endpoints that count toward daily/monthly quota). Endpoints select via `[EnableRateLimiting(\"policy-name\")]`."
   - Match the JSON formatting (indent, trailing commas, key order) used by the existing entries — do not reformat the file.
3. Do **NOT** edit `catalogs/relationships.json`. No new Node-to-Node edge is created. `ITenantRateLimitPolicy` is already registered as exposed by `honeydrunk-kernel` from ADR-0026's catalog packet.
4. Do **NOT** edit `catalogs/nodes.json`. nodes.json has no `interfaces` or `exposes` field — the contract surface lives in contracts.json.

## Affected Files
- `infrastructure/reference/tech-stack.md`
- `catalogs/contracts.json`

## NuGet Dependencies
None. This packet touches only Markdown and catalog JSON; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new abstractions or contracts — the primitive `ITenantRateLimitPolicy` is ADR-0026's and already cataloged.
- [x] No new Node-to-Node edge; Notify Cloud's consumption of `ITenantRateLimitPolicy` is registered at Notify Cloud standup time.

## Acceptance Criteria
- [ ] `infrastructure/reference/tech-stack.md` records ASP.NET Core `RateLimiter` middleware as the rate-limit substrate, with Cloudflare edge as the documented complement, the algorithm choices (token bucket + fixed-window-with-calendar-anchor for quotas), and the explicitly-rejected alternatives (APIM, Phase-1 distributed Redis, Cloudflare-only) with their stated rejection reasons
- [ ] `catalogs/contracts.json` `honeydrunk-kernel` block lists `AddGridRateLimiting`, `UseGridRateLimiting`, and the named-policies constants entry in the `interfaces` array
- [ ] `catalogs/relationships.json` is **NOT** modified (no new edge; Notify Cloud's catalog wiring lands with Notify Cloud standup)
- [ ] `catalogs/nodes.json` is **NOT** modified
- [ ] JSON formatting matches surrounding entries (no whitespace drift, no trailing-comma drift)
- [ ] No invariant change in this packet

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0067 D1 — Primary substrate.** ASP.NET Core `RateLimiter` middleware (`Microsoft.AspNetCore.RateLimiting`), partition-keyed on `TenantId` via `PartitionedRateLimiter.Create<TResource, TPartitionKey>`. First-party, in-process, free; no Azure resource. Algorithms covered: token bucket, sliding window, fixed window, concurrency limiter. Cloudflare edge rate limiting (per ADR-0029) absorbs gross abuse before traffic reaches the application limiter — the two do not overlap by design. Explicitly rejected: APIM (cost), distributed Redis at Phase 1 (premature; migration trigger in D5b), Cloudflare-only (no `TenantId` at the edge).

**ADR-0067 D9 — Kernel extension surface.** `AddGridRateLimiting(this IServiceCollection, Action<GridRateLimitOptions>?)` and `UseGridRateLimiting(this IApplicationBuilder)` extension methods live in `HoneyDrunk.Kernel`. Three default-named policies: `"tier"`, `"anon"`, `"quota-billable"`. Per-endpoint via `[EnableRateLimiting("policy-name")]`. Per-Node opt-in. Why Kernel and not a gateway Node: no Gateway Node exists today and pushing the wiring into Kernel means every Node that exposes HTTP gets the same shape; a future Gateway Node reuses the Kernel extension.

**ADR-0026 D4 (referenced, not changed) — `ITenantRateLimitPolicy`.** Already in `HoneyDrunk.Kernel.Abstractions`; already registered in `catalogs/contracts.json` under `honeydrunk-kernel`. The `EvaluateAsync(TenantId, operationKey, CancellationToken)` signature is unchanged. ADR-0067 adds *wiring* in the Kernel runtime that consumes this contract; it does not add a new abstraction.

## Constraints
- **No new abstractions in this packet.** `ITenantRateLimitPolicy` is ADR-0026's primitive — registered there. ADR-0067 D9's extension methods are runtime wiring, not new contracts.
- **No `catalogs/relationships.json` edits.** `ITenantRateLimitPolicy` is already in `honeydrunk-kernel`'s `exposes.contracts` from ADR-0026's catalog packet. No new edge is created — Notify Cloud's consumption lands when Notify Cloud is stood up (ADR-0027 initiative), not here.
- **No `catalogs/nodes.json` edits.** nodes.json has no `interfaces` / `exposes` field.
- **Match JSON formatting precisely.** No whitespace or trailing-comma drift. The repo's `pr-core.yml` includes a JSON-formatting gate.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0067`, `wave-1`

## Agent Handoff

**Objective:** Record the ASP.NET Core `RateLimiter` + Cloudflare substrate choice in `infrastructure/reference/tech-stack.md` and register the new Kernel extension surface in `catalogs/contracts.json`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Keep the Grid's substrate documentation and contract catalog accurate so implementation packet 02 reads a correct graph.
- Feature: ADR-0067 Inbound Rate Limiting and Quota Enforcement rollout, Wave 1.
- ADRs: ADR-0067 D1 / D9 (primary); ADR-0026 D4 (`ITenantRateLimitPolicy` already exists, not re-registered); ADR-0029 (Cloudflare edge cross-link).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0067 should be Accepted before its substrate is recorded as catalog data.

**Constraints:**
- No new abstractions registered. `ITenantRateLimitPolicy` stays as ADR-0026's; only the new Kernel *extension surface* is added.
- `relationships.json` and `nodes.json` are NOT touched.
- Match JSON formatting precisely.

**Key Files:**
- `infrastructure/reference/tech-stack.md` — new Rate Limiting section.
- `catalogs/contracts.json` — three new entries in the `honeydrunk-kernel` block's `interfaces` array.

**Contracts:** None changed. This packet only records catalog metadata for the extension surface packet 02 implements.
