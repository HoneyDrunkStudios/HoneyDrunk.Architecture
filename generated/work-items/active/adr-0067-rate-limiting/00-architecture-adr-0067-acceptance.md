---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0067", "wave-1"]
dependencies: []
adrs: ["ADR-0067"]
accepts: ["ADR-0067"]
wave: 1
initiative: adr-0067-rate-limiting
node: honeydrunk-architecture
---

# Accept ADR-0067 — flip status, register the initiative

## Summary
Flip ADR-0067 (Inbound Rate Limiting and Quota Enforcement) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, and register the `adr-0067-rate-limiting` initiative in `initiatives/active-initiatives.md`. ADR-0067 adds **no new invariants** (its Consequences/Invariants section is explicit on that point) — the rate limiter is required to honor the existing invariants 5/6 (GridContext present in every scoped operation) and invariant 8 (secret values never appear in logs or traces); no append to `constitution/invariants.md` is required.

## Context
ADR-0067 commits the Grid's substrate, response shape, tier defaults, and deferral triggers for inbound rate limiting and quota enforcement. ADR-0026 D4 placed `ITenantRateLimitPolicy` / `TenantRateLimitDecision` in `HoneyDrunk.Kernel.Abstractions` as primitives but explicitly deferred the storage and substrate to consumer Nodes. ADR-0027 D6 names Notify Cloud as the first non-noop policy implementation but does not pin the substrate, the response shape, the success-side headers, or the tier-to-limits mapping. ADR-0067 closes that gap: it picks ASP.NET Core's built-in `RateLimiter` middleware (with Cloudflare as the edge complement) as the Grid-wide substrate, pins the RFC 7807 `application/problem+json` 429 envelope, pins the IETF draft `RateLimit-*` success-side header convention, and decides the Notify-Cloud-at-GA tier-to-limits defaults plus the distributed-limiter migration trigger.

The ADR decides:
- **D1** — primary substrate is ASP.NET Core `RateLimiter` middleware (`Microsoft.AspNetCore.RateLimiting`); Cloudflare edge rate limiting is the complement above it. Azure API Management, distributed Redis-class limiters, and Cloudflare-only options are explicitly rejected with reasons (cost, premature provisioning, and edge-doesn't-know-`TenantId` respectively).
- **D2** — three-layer configuration source with one-way precedence: per-tenant override (deferred to first concrete need) > per-tier App Configuration override > code-baked default. Per-tier overrides are gated behind a feature flag per ADR-0055.
- **D3** — Notify Cloud tier-to-limits defaults at GA: Free (10/sec burst, 100/min sustained, 1K/day, 10K/month, hard 429 on overage); Pro (50/sec, 1000/min, 50K/day, 500K/month, hard 429 on burst, billable Stripe-meter overage on quota); Scale (500/sec, 10000/min, 1M/day, 10M/month, billable overage on quota). `TenantId.Internal` always bypasses. Tier naming reconciles ADR-0027 D3 (`Free / Starter / Pro`) to ADR-0037 D3 (`Free / Pro / Scale`) — ADR-0067 adopts ADR-0037's naming.
- **D4** — token bucket for burst/sustained limits; fixed-window calendar-anchored counter for daily/monthly quotas. Sliding-window and concurrency limiter are explicitly not used at Phase 1.
- **D5** — limiter key resolution: `TenantId` from `IGridContext.TenantId` for authenticated requests (`TenantId.Internal` bypasses); `CF-Connecting-IP` (Cloudflare's header) with connection-IP fallback for anonymous endpoints; the API-key prefix (first 8 characters of the key) for pre-auth API-key-validation endpoints.
- **D5b** — named distributed-limiter migration trigger: Notify Cloud >3 Container App replicas, OR a paying tenant complains about non-deterministic rate-limit behavior, OR aggregate per-process limit exceeds 3× the tier ceiling. Whichever fires first triggers a follow-up ADR. The `ITenantRateLimitPolicy` contract does not change at migration time.
- **D6** — 429 response is `application/problem+json` per RFC 7807. Pinned shape: `type` (stable docs URI), `title` ("Rate limit exceeded"), `status` (always 429), `detail`, `instance` (request path), `tier` (omitted for anonymous), `retry_after_seconds` (duplicates `Retry-After` header), `correlation_id` (from `IGridContext.CorrelationId`). `tenant_id` is deliberately NOT in the body. `Retry-After` is in seconds, not HTTP-date.
- **D7** — IETF draft `RateLimit-*` headers (`RateLimit-Limit`, `RateLimit-Remaining`, `RateLimit-Reset`) on every response from a rate-limited endpoint, reporting the most-restrictive limit currently in effect. The legacy `X-RateLimit-*` mirrors are not emitted.
- **D8** — rate limit and quota are distinct concerns with distinct stores: rate limit (short-window, ASP.NET Core RateLimiter, hard 429) vs. quota (long-window, per-tenant counter store keyed on `(TenantId, CounterKey, Window)`, calendar-anchored reset, billable overage via Stripe meter for Pro/Scale). Quota counter store Phase 1 default is Azure Storage Tables.
- **D9** — the rate-limiter wiring lives in `HoneyDrunk.Kernel` as opt-in `AddGridRateLimiting()` / `UseGridRateLimiting()` extension methods with three default-named policies: `"tier"` (per-tenant tier-driven, token bucket), `"anon"` (per-IP, token bucket), `"quota-billable"` (composed with `"tier"` for billable endpoints). Nodes opt in per-host; library-only Nodes do not. Per-endpoint policies via `[EnableRateLimiting("policy-name")]`.
- **D10** — every hard 429 emits a `RateLimitRejected` audit event per ADR-0030; quota-overage-billable events emit `QuotaOverageBilled` instead. A counter metric `rate_limit_rejection_count` with tags `tenant_id`/`endpoint`/`tier`/`outcome` and a gauge `rate_limit_remaining_ratio` per ADR-0010. Alarm threshold: ≥50 rejections for a single `(tenant_id, endpoint)` over a 5-minute window pages on-call.
- **D11** — out of scope: DDoS at the edge (Cloudflare), account-level lockout (Auth), cost-based shedding (ADR-0052), per-tenant override storage, the quota-counter schema details, signup anti-abuse heuristics, and multi-region coordination.

ADR-0067 is a **policy / contract** ADR. The Kernel extension methods and middleware wiring land in `HoneyDrunk.Kernel` (packet 02). The audit-event-shape registration and the Pulse metric-catalog registration are documentation-level confirmations in Audit and Pulse (packets 03, 04). The Notify Cloud production `ITenantRateLimitPolicy` implementation and the quota counter store are **deferred to the Notify Cloud standup** (ADR-0027 initiative) — see Cross-Cutting Concerns in the dispatch plan; ADR-0027 is currently Proposed and the Notify Cloud repo does not yet exist on disk. The Notify Cloud follow-up specification doc lands in this initiative (packet 05) as the design the Notify Cloud standup consumes.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0067-inbound-rate-limiting-and-quota-enforcement.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0067 row Status column to Accepted.
- `initiatives/active-initiatives.md` — register the `adr-0067-rate-limiting` initiative with the packet checklist for this folder.
- `constitution/invariants.md` — **NOT modified.** ADR-0067 adds no new invariants.

## Proposed Implementation
1. Edit the ADR-0067 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0067 index row in `adrs/README.md` to Accepted.
3. Register the initiative in `initiatives/active-initiatives.md` under `## In Progress` with the wave structure and packet checklist for this folder. Match the existing entry-shape used by sibling ADR initiatives (`adr-0042-idempotency`, `adr-0045-grid-wide-error-tracking`): an `### ADR-0067 Inbound Rate Limiting and Quota Enforcement` heading, Status / Scope / Initiative / Board / Description fields, and a Tracking checklist of the six packets in this folder. Use the file naming as the canonical packet references (the GitHub issue numbers will be backfilled by `hive-sync` after filing).
4. Do **NOT** modify `constitution/invariants.md`. ADR-0067 §Consequences/Invariants is explicit: *"No new invariants are introduced by this ADR. The existing invariants that the rate limiter is required to honor: Invariant 8 (secret values never appear in logs or traces); Invariant 5 / 6 (GridContext present and populated)."* The middleware-ordering requirement (`GridContextMiddleware` before the rate-limiter middleware) is documented at the `UseGridRateLimiting` extension method in packet 02, not as a new invariant.

## Affected Files
- `adrs/ADR-0067-inbound-rate-limiting-and-quota-enforcement.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0067 header reads `**Status:** Accepted`
- [ ] The ADR-0067 row in `adrs/README.md` reflects Accepted
- [ ] `initiatives/active-initiatives.md` registers the `adr-0067-rate-limiting` initiative with a packet checklist
- [ ] `constitution/invariants.md` is **NOT** modified (ADR-0067 adds no new invariants)
- [ ] No catalog schema change in this packet (catalog/tech-stack updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0067 §Consequences / Invariants.** "No new invariants are introduced by this ADR. The existing invariants that the rate limiter is required to honor: Invariant 8 (secret values never appear in logs or traces) — the 429 body's `detail` field, the audit emit, and the Pulse metric carry no secret material; API key prefixes (8-character display prefix) are not secret and may appear, the full key never does. Invariant 5 / 6 (GridContext present and populated) — the middleware ordering `GridContextMiddleware` before the rate-limiter middleware is required for `TenantId` to be available at partition-factory time. The composition documented at `UseGridRateLimiting` enforces this."

**ADR-0067 §If Accepted — Required Follow-Up Work.** Eight items: Kernel extension methods + middleware (packet 02); response-shape convention for `ITenantRateLimitPolicy` consumers (rolled into packet 02 since the convention is enforced at the middleware, not the contract); Notify Cloud production `ITenantRateLimitPolicy` implementation (deferred to ADR-0027 standup follow-up; specification in packet 05); Notify Cloud quota counter store (deferred to ADR-0027 standup follow-up; specification in packet 05); Audit `RateLimitRejected` event-shape confirmation (packet 03); Pulse 429-counter and alarm-threshold confirmation (packet 04); tech-stack.md update (packet 01); contracts.json update (packet 01). The eighth item — scope agent flips Status → Accepted after Kernel ships and the first Notify Cloud tier-driven policy lands — is a post-merge housekeeping action, not a packet. The scope-agent flip in *this* packet is for ADR-0067 itself going Proposed → Accepted; the deeper success criterion ("Kernel surface ships + first Notify Cloud policy ships") is the **exit criterion** for the initiative, recorded in `initiatives/active-initiatives.md`.

## Constraints
- **Acceptance precedes implementation.** ADR-0067 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **No invariant edits.** ADR-0067 §Consequences/Invariants is explicit: no new invariants. Do not append placeholder text to `constitution/invariants.md`. Do not reserve a number for ADR-0067 in the pre-reservation batch — ADR-0067 has no claim on the batch's reserved range.
- **Notify Cloud production policy is deferred.** ADR-0027 (Notify Cloud standup) is Proposed; the Notify Cloud repo does not exist on disk and is not yet a target for `file-work-items.yml`. This initiative ships the Kernel substrate and the Notify Cloud *specification*; the production `ITenantRateLimitPolicy` implementation lands as part of (or after) the ADR-0027 standup initiative — see the dispatch plan's Cross-Cutting Concerns section.
- **Exit criterion is conditional on Notify Cloud.** ADR-0067's own exit criterion ("Scope agent flips Status → Accepted after the Kernel extension surface ships at 0.x and the first Notify Cloud tier-driven `ITenantRateLimitPolicy` lands") is satisfied in two phases: (1) this packet flips Status to Accepted now, because the ADR's decisions are needed *as live rules* by packets 02–05; (2) the deeper success criterion "Kernel surface ships + first Notify Cloud policy ships" is the initiative-completion gate recorded in `initiatives/active-initiatives.md`. Splitting the flip from the exit criterion matches the pattern used by other Proposed-but-implemented ADRs (ADR-0042 followed the same shape).

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0067`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0067 to Accepted and register the rate-limiting initiative. No invariant edits.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0067 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0067 Inbound Rate Limiting and Quota Enforcement rollout, Wave 1.
- ADRs: ADR-0067 (primary); ADR-0026 (multi-tenant primitives — provides `ITenantRateLimitPolicy`); ADR-0027 (Notify Cloud standup — provides Notify Cloud's first non-noop implementation; currently Proposed, repo does not yet exist).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- ADR-0067 stays Proposed until this PR merges.
- **No invariant edits** — ADR-0067 adds no new invariants. Do not append placeholder text; do not reserve a batch number for this ADR.
- The exit criterion of the initiative ("first Notify Cloud tier-driven policy ships") is recorded in `initiatives/active-initiatives.md` as a gate, not satisfied by this packet. The flip itself only requires the ADR's decisions to become live so packets 02–05 can reference them.

**Key Files:**
- `adrs/ADR-0067-inbound-rate-limiting-and-quota-enforcement.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
