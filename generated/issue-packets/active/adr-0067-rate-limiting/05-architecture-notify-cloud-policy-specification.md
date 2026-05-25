---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0067", "adr-0027", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0067", "ADR-0027"]
wave: 3
initiative: adr-0067-rate-limiting
node: honeydrunk-architecture
---

# Author the Notify Cloud rate-limit policy specification — handoff to ADR-0027 standup

## Summary
Author the detailed specification document for the Notify Cloud `ITenantRateLimitPolicy` production implementation and the per-tenant daily/monthly quota counter store. This is the **deferral marker** — the Notify Cloud Node does not yet exist on disk (ADR-0027 is Proposed; the repo will be created in ADR-0027 packet 05 and scaffolded in ADR-0027 packet 06). This packet authors the specification *now* in the Architecture repo so when the ADR-0027 standup completes the executor has a fully-spec'd implementation target. The specification turns into one or more Notify Cloud packets (filed against the new repo) as a follow-up after ADR-0027 packet 06 lands.

## Context
ADR-0067 D3 names Notify Cloud's tier-to-limits defaults (Free / Pro / Scale; per-second burst, per-minute sustained, per-day quota, per-month quota; overage behavior per tier). ADR-0067 D8 names the per-tenant quota counter store (Phase 1 default: Azure Storage Tables; key shape `(TenantId, CounterKey, Window)`; calendar-anchored reset). ADR-0067 D2 layers configuration (per-tenant override deferred; App Configuration per-tier; code default). ADR-0067 D5b names the distributed-limiter migration trigger.

All of that work lands in **`HoneyDrunk.Notify.Cloud`** as the production `ITenantRateLimitPolicy` implementation, plus the quota counter store backing. But:

1. **ADR-0027 (Notify Cloud standup) is Proposed**, not Accepted. The Notify Cloud repo does not exist on disk; `catalogs/nodes.json` has no `honeydrunk-notify-cloud` entry; `file-packets.yml` cannot file an issue against a repo that does not exist.
2. **Per the user's standing convention**, new-Node scaffolding gets its own standup ADR — feature packets do not bundle scaffolding. The Notify Cloud rate-limit-policy implementation packet must therefore be filed *after* ADR-0027 packet 06 (the scaffold) completes.
3. **ADR-0067's own exit criterion** is "the first Notify Cloud tier-driven `ITenantRateLimitPolicy` lands." That criterion is satisfied across the ADR-0027 standup boundary, not within this initiative's filing window.

The clean structure: this packet authors the specification *now* (in the Architecture repo, where it is reviewable and discoverable). When the ADR-0027 standup completes — i.e., when Notify Cloud packet 06 (scaffold) lands on `main` and the Notify Cloud repo exists with its solution structure, four packages, four contracts, and the placeholder `ITenantRateLimitPolicy` implementation — a follow-up packet against `HoneyDrunk.Notify.Cloud` consumes this specification and replaces the placeholder with the production implementation. The follow-up packet is **not** filed by this initiative; it is filed as part of (or after) the `adr-0027-notify-cloud-standup` completion, or as a new initiative `adr-0067-notify-cloud-rate-limit-policy` if the user prefers an explicit follow-up wave.

The specification lives at `infrastructure/walkthroughs/notify-cloud-rate-limit-policy.md` (matching the existing walkthrough/spec doc pattern), or `business/context/notify-cloud-rate-limit-policy-spec.md`, or — whichever directory the executor finds most consistent with the repo's existing convention. Default to `infrastructure/walkthroughs/` since the document is implementation-prescriptive.

This is a docs-only packet. No code, no .NET project, no catalog change.

## Scope
- New document at `infrastructure/walkthroughs/notify-cloud-rate-limit-policy.md` (or the equivalent path matching the repo's convention) authoring the Notify Cloud rate-limit-policy specification.
- Update `initiatives/active-initiatives.md` if needed to reference the deferred follow-up to ADR-0027 standup (cross-link the two initiatives explicitly).

## Proposed Implementation
1. Author the specification document. Required sections (at minimum):

   ### Tier-to-limits defaults (ADR-0067 D3)
   Verbatim reproduction of the D3 table:
   | Tier | Per-second burst | Per-minute sustained | Per-day quota | Per-month quota | Overage |
   |------|------------------|----------------------|---------------|-----------------|---------|
   | Free | 10 | 100 | 1,000 | 10,000 | Hard 429 |
   | Pro | 50 | 1,000 | 50,000 | 500,000 | Hard 429 burst; billable quota |
   | Scale | 500 | 10,000 | 1,000,000 | 10,000,000 | Hard 429 burst; billable quota |

   Plus the per-tier semantics, the `TenantId.Internal` short-circuit, and the "numbers are tunable" disclaimer with the review cadence (90 days post-GA + quarterly cost review).

   ### Configuration source layering (ADR-0067 D2)
   The three-layer precedence and how the production policy reads each:
   - Per-tenant override (layer 1, highest) — **deferred to first concrete need**. The policy reads it from a TBD store (a row in the Notify Cloud tenant store, a separate per-tenant-override table, or a feature-flag-style override; the choice is made when the first VIP or troublemaker drives the requirement). Until that first need, the policy returns the layer-2 result.
   - Per-tier override (layer 2) — read from Azure App Configuration with the key shape `RateLimit:NotifyCloud:{Tier}:{LimitType}` (e.g. `RateLimit:NotifyCloud:Free:RequestsPerMinute = 200`). Cache TTL is 60 seconds (the App Configuration default). Behind a feature flag per ADR-0055 so the override can be toggled off in incident.
   - Default tier limits (layer 3, lowest) — baked into the implementation as a static configuration record matching the D3 table.

   Precedence is one-way; the policy consults them in that order on every `EvaluateAsync` call. The lookup is cached against the tenant's `IGridContext.TenantId` per ADR-0058 (InMemory backing at Phase 1; distributed backing if and when D5b's migration trigger fires).

   ### Algorithm and store split (ADR-0067 D4 + D8)
   - **Burst / sustained** — token bucket, served via the Kernel substrate's `AddGridRateLimiting` partition factory. The policy's `EvaluateAsync` returns a `TenantRateLimitDecision` whose limits drive the token-bucket parameters (capacity = burst, replenishment rate = sustained / 60). At v1 the in-process limiter is sufficient — D5b's migration trigger is named.
   - **Daily / monthly quotas** — **fixed window with calendar-anchored reset**, computed against a per-tenant counter store. The store is **separate from the rate limiter** — D8 is explicit on this. The counter increments on every billable operation (every `notify/send` call); the policy consults the counter against the tier's daily/monthly ceiling before returning the `TenantRateLimitDecision`.
   - **Phase-1 storage choice:** Azure Storage Tables. Cheap (sub-cent per 10K transactions per the user's `feedback_default_cheapest_azure_tier` rule), sufficient at the v1 tenant-count ceiling (ADR-0027 D7 — tens at v1), no extra Azure resource provisioning beyond what Notify Cloud already owns per `feedback_provision_when_needed`. Distributed cache backing per ADR-0059 is a deferred consideration if read latency on the counter becomes a hot path.

   ### Quota counter schema (ADR-0067 D8)
   Suggested Azure Storage Table row shape (the implementation packet may refine — the schema is settled in implementation):
   - `PartitionKey` = `TenantId.Value`
   - `RowKey` = `{CounterKey}:{Window}:{WindowStart}` (e.g. `notify-send:daily:2026-05-24T00:00:00Z`)
   - `Count` (int64) — the current window count
   - `Tier` (string) — the tier at window-open time (for forensic reconciliation if the tenant's tier changed mid-window)

   Reset: calendar-anchored — UTC 00:00 for daily, first-of-month UTC for monthly. Implementation does **not** zero the row; it reads `RowKey` containing the window-start timestamp and treats absent rows as count = 0. New windows write a new row.

   Operational note from ADR-0067 §Operational Consequences: the counter increment is on the hot path. **Batched** — per-replica batch flush every 5 seconds or 100 requests, whichever comes first — matching the ADR-0028 outbox-pattern discipline. The implementation packet authors this batching.

   ### Overage transitions (ADR-0067 D3 + D8 + ADR-0037 D2)
   - Free tier — hard 429 on quota overage. Emit `RateLimitRejected` audit event with `limit_type = "monthly-quota"` (or `"daily-quota"`).
   - Pro/Scale — request proceeds; the policy returns `Allow`; the counter increments; if the post-increment count *crosses* the tier ceiling, emit a `QuotaOverageBilled` audit event (per ADR-0067 D10 + the canonical event-shape in packet 03 of this initiative); the Stripe meter is incremented per ADR-0037 D2's pipe. The transition (in-quota → overage-billed) is a one-time emit per window per tenant; subsequent overage-billable events within the same window do not re-emit `QuotaOverageBilled` (the audit captures the *transition*, not every billable request).

   ### Distributed-limiter migration trigger (ADR-0067 D5b)
   Reproduce the three triggers verbatim:
   - Notify Cloud crosses 3 Container App replicas, OR
   - A paying tenant complains about non-deterministic rate-limit behavior, OR
   - Aggregate per-process limit exceeds 3× the tier ceiling.

   Whichever fires first triggers a follow-up ADR ("Distributed Rate-Limiter Backing for Notify Cloud"). The `ITenantRateLimitPolicy` contract does not change at migration time; only the implementation behind it changes.

   ### Audit emit (ADR-0067 D10 — uses packet 03 canonical shape)
   The policy emits via `IAuditLog` (per ADR-0030 substrate):
   - On hard 429: `RateLimitRejected` with the canonical fields per the Audit packet (03) of this initiative.
   - On Pro/Scale quota-overage transition: `QuotaOverageBilled` with the canonical fields per the Audit packet (03).

   The middleware does NOT emit audit — the policy is the auditor; the middleware is the enforcer. The policy is the natural owner because it has the tier context, the counter context, and the post-increment state needed to identify the transition.

   ### Pulse emit (ADR-0067 D10 — uses packet 04 canonical shape)
   The policy emits the `rate_limit_rejection_count` counter (with `outcome` distinguishing `"rate-limit"` from `"quota-overage-billed"`) and the `rate_limit_remaining_ratio` gauge (per-tenant per-endpoint observation) using `System.Diagnostics.Metrics` instruments. Pulse carries them through OTLP. See the Pulse Metric Catalog (packet 04 of this initiative) for the canonical names, tags, and the alarm threshold.

   ### API-key-validation pre-auth keying (ADR-0067 D5)
   The Notify Cloud `INotifyCloudGateway` exposes the API-key-validation endpoint. For that single endpoint (and only that endpoint), the rate-limit partition key is the 8-character API-key display prefix per ADR-0067 D5 — invoked via the `GridRateLimitOptions` hook the Kernel substrate exposes (packet 02). The policy's `EvaluateAsync` is not called for this pre-auth path because the tenant is not yet resolved; the limit is a coarse Kernel-side `"anon"` policy bumped to a different bucket size by the hook. Once the API key validates and resolves a tenant, subsequent endpoints use the standard `"tier"` policy.

   ### Cross-references and out-of-scope reminders
   - ADR-0067 D11 reminders: this implementation does NOT add DDoS mitigation (Cloudflare), account-level lockout (Auth), cost-based shedding (ADR-0052 kill switches), or signup anti-abuse heuristics.
   - The per-tenant override store (ADR-0067 D2 layer 1) is **deferred** — implement layer 2 + layer 3 first; add layer 1 when the first concrete need arises.

2. Update `initiatives/active-initiatives.md` to record the cross-initiative coupling: this ADR-0067 initiative completes Phase 1 with the Kernel substrate + the Audit/Pulse documentation + this specification; the Notify Cloud production implementation is a deferred follow-up tracked against the `adr-0027-notify-cloud-standup` initiative. Add a Tracking entry note: "The Notify Cloud `ITenantRateLimitPolicy` production implementation per this specification is a deferred follow-up. It is filed as a new packet against `HoneyDrunk.Notify.Cloud` after `adr-0027-notify-cloud-standup` packet 06 (scaffold) lands."

3. Add a "Follow-up Notify Cloud packet" outline at the bottom of the specification document — the executor-ready skeleton (target repo, expected scope, dependencies, version-bump expectation) the future filer uses. This is **not** a filed packet; it is a draft outline that the future filer turns into a real packet. The outline should explicitly state: target repo `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud` (which does not exist at the time of writing this specification); blocked by `adr-0027-notify-cloud-standup` packet 06 (scaffold); version-bumping packet for the `HoneyDrunk.Notify.Cloud` solution (`0.1.0` → `0.2.0` minor — the production policy replacing the scaffold placeholder is additive within the scaffolded surface; confirm at execution time); consumes `HoneyDrunk.Kernel` `0.8.0` (packet 02 of this initiative).

## Affected Files
- New `infrastructure/walkthroughs/notify-cloud-rate-limit-policy.md` (or the path matching the repo's convention).
- `initiatives/active-initiatives.md` — cross-initiative coupling note.

## NuGet Dependencies
None. This packet authors Markdown specification; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Notify Cloud production policy is **explicitly deferred** to the `adr-0027-notify-cloud-standup` initiative — this packet does not file against `HoneyDrunk.Notify.Cloud` (the repo does not exist yet) and does not bundle scaffolding work into a feature packet.

## Acceptance Criteria
- [ ] The specification document exists at `infrastructure/walkthroughs/notify-cloud-rate-limit-policy.md` (or the chosen equivalent path)
- [ ] The document carries the D3 tier-to-limits table verbatim with the per-tier semantics and the review-cadence disclaimer
- [ ] The document carries the D2 three-layer configuration precedence with the App Configuration key shape (`RateLimit:NotifyCloud:{Tier}:{LimitType}`), the 60-second cache TTL, and the ADR-0055 feature-flag gate
- [ ] The document specifies the algorithm split: token bucket (burst/sustained, served via Kernel's `AddGridRateLimiting`) and fixed-window-with-calendar-anchor (daily/monthly quotas, served via Azure Storage Tables counter store)
- [ ] The document records the Phase-1 Azure Storage Tables choice with the suggested row schema (`PartitionKey = TenantId.Value`; `RowKey = {CounterKey}:{Window}:{WindowStart}`; `Count`; `Tier`)
- [ ] The document records the batched-counter-flush operational discipline (5 seconds or 100 requests, whichever first) matching ADR-0028's outbox pattern
- [ ] The document specifies the Free hard-429 / Pro+Scale billable-overage transition semantics including the "emit `QuotaOverageBilled` once per window per tenant on transition" rule
- [ ] The document reproduces the D5b distributed-limiter migration triggers verbatim
- [ ] The document points at the canonical audit-event shapes (packet 03) and Pulse metric catalog (packet 04) rather than duplicating them
- [ ] The document specifies the API-key-prefix pre-auth keying for the `INotifyCloudGateway` validation endpoint (D5)
- [ ] The document records the explicitly-out-of-scope items from D11 (DDoS, account lockout, cost shedding, signup anti-abuse)
- [ ] The document carries a "Follow-up Notify Cloud packet" outline at the bottom (target repo, expected scope, dependencies, version-bump expectation)
- [ ] `initiatives/active-initiatives.md` records the cross-initiative coupling to `adr-0027-notify-cloud-standup`
- [ ] No code, no .NET project, no catalog change

## Human Prerequisites
- [ ] **Acknowledge the deferral.** The Notify Cloud production `ITenantRateLimitPolicy` implementation is filed as a new packet against `HoneyDrunk.Notify.Cloud` *after* the `adr-0027-notify-cloud-standup` initiative's packet 06 (scaffold) lands. This is recorded in the dispatch plan and in this packet. The follow-up filer reads this specification, turns the "Follow-up Notify Cloud packet" outline into a real packet, and files it. No human action is required at the time *this* packet runs — only when the follow-up is filed later.
- [ ] **Confirm `HoneyDrunk.Notify.Cloud` target repo status before the follow-up packet is filed.** `file-packets.yml` cannot file an issue against a repo that does not exist. The follow-up filer confirms the Notify Cloud repo exists (ADR-0027 packet 05 created it; ADR-0027 packet 06 scaffolded it) before pushing the follow-up packet folder.

## Referenced ADR Decisions
**ADR-0067 D2 — Policy configuration source.** Three-layer with one-way precedence: per-tenant override (deferred) > per-tier App Configuration override (behind ADR-0055 feature flag) > code default. Cache per ADR-0058.

**ADR-0067 D3 — Notify Cloud tier-to-limits mapping at GA.** Free (10/sec, 100/min, 1K/day, 10K/month, hard 429); Pro (50/sec, 1000/min, 50K/day, 500K/month, hard 429 burst, billable quota); Scale (500/sec, 10000/min, 1M/day, 10M/month, billable quota). `TenantId.Internal` always bypasses. Numbers tunable; reviewed at GA + 90 days and quarterly cost reviews.

**ADR-0067 D4 — Algorithm.** Token bucket for burst/sustained (via Kernel substrate); fixed window with calendar-anchored reset for daily/monthly quotas (explicit per-tenant counter store, not in-process `FixedWindowRateLimiter`).

**ADR-0067 D5 — Identity resolution.** Authenticated: `TenantId` (internal bypasses). Anonymous: `CF-Connecting-IP`. API-key validation pre-auth: 8-character API-key display prefix.

**ADR-0067 D5b — Distributed-limiter migration trigger.** Three named triggers; whichever fires first triggers a follow-up ADR. The `ITenantRateLimitPolicy` contract does not change at migration.

**ADR-0067 D8 — Rate limit vs. quota.** Quota is computed against a per-tenant counter store keyed on `(TenantId, CounterKey, Window)` with calendar-anchored reset. Phase-1 default: Azure Storage Tables. Pro/Scale overage billable via Stripe meter per ADR-0037 D2; Free hard-429.

**ADR-0067 D10 — Audit and observability.** `RateLimitRejected` audit event on every hard 429 with the canonical shape per Audit packet 03 of this initiative; `QuotaOverageBilled` on the in-quota → overage-billed transition for Pro/Scale. `rate_limit_rejection_count` counter and `rate_limit_remaining_ratio` gauge with the canonical names and tags per Pulse packet 04 of this initiative. The policy is the auditor; the middleware is the enforcer.

**ADR-0067 D11 — Out of scope.** DDoS at the edge (Cloudflare's job per ADR-0029); account-level lockout (Auth per ADR-0056); cost-based shedding (ADR-0052 kill switches); per-tenant override storage (deferred); the exact counter schema (settled in implementation packet); signup anti-abuse (separate ADR if and when written); multi-region coordination (single-region today).

**ADR-0027 (referenced — Proposed) — Notify Cloud standup.** The Notify Cloud Node is stood up via the `adr-0027-notify-cloud-standup` initiative. The scaffold lands in ADR-0027 packet 06; the production `ITenantRateLimitPolicy` implementation per this specification is filed as a new packet against `HoneyDrunk.Notify.Cloud` after that scaffold lands. Note: ADR-0027 D3's tier naming (`Free / Starter / Pro`) was reconciled to ADR-0037 D3's naming (`Free / Pro / Scale`) by ADR-0067 §Consequences — the production implementation uses the `Free / Pro / Scale` naming.

## Constraints
- **No filing against `HoneyDrunk.Notify.Cloud`.** The repo does not exist on disk and is not yet a target for `file-packets.yml`. This packet is purely an Architecture-repo specification document.
- **Notify Cloud follow-up is filed later — not by this initiative.** The follow-up filer (post-`adr-0027-notify-cloud-standup` packet 06) reads this specification and files the production-implementation packet against `HoneyDrunk.Notify.Cloud`.
- **Use the `Free / Pro / Scale` tier naming.** ADR-0067 §Consequences reconciled ADR-0027 D3's `Free / Starter / Pro` to ADR-0037 D3's `Free / Pro / Scale`. The specification uses the reconciled naming.
- **Defer the per-tenant override store.** ADR-0067 D2 layer 1 is deferred to first concrete need; the specification implements layers 2 + 3 only.
- **Defer the distributed limiter.** D5b's triggers are named; the in-process limiter is sufficient at GA. No distributed-backing packet here.
- **Point at canonical shapes, do not duplicate.** Audit event shapes live in packet 03's catalog; Pulse metric shapes live in packet 04's catalog. The specification *references* them rather than restating.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0067`, `adr-0027`, `wave-3`

## Agent Handoff

**Objective:** Author the Notify Cloud rate-limit policy production specification in the Architecture repo, as the handoff document for the future follow-up implementation packet that files against `HoneyDrunk.Notify.Cloud` after the `adr-0027-notify-cloud-standup` initiative completes.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Produce the full implementation specification *now* so the executor of the eventual Notify Cloud follow-up packet has a complete target. Note Notify Cloud does not yet exist on disk — the specification lives in the Architecture repo and is consumed cross-initiatively.
- Feature: ADR-0067 Inbound Rate Limiting and Quota Enforcement rollout, Wave 3.
- ADRs: ADR-0067 D2/D3/D4/D5/D5b/D8/D10/D11 (primary); ADR-0027 (Notify Cloud standup — currently Proposed, cross-referenced); ADR-0037 D2 (Stripe meter overage — the billable-quota path); ADR-0055 (feature flag gating the App Configuration overrides); ADR-0058 (caching for the tier lookup); ADR-0028 (outbox pattern for the batched counter flush); ADR-0030 (audit substrate); ADR-0010 (observation layer).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0067 should be Accepted before its production-implementation specification is authored as canonical.

**Constraints:**
- This packet does NOT file against `HoneyDrunk.Notify.Cloud`. That repo does not exist on disk yet; ADR-0027 packet 05 creates it; ADR-0027 packet 06 scaffolds it. The Notify Cloud production-implementation packet is filed as a separate follow-up after ADR-0027 packet 06 lands.
- Tier naming uses `Free / Pro / Scale` (ADR-0037 D3 / ADR-0067 reconciliation), not `Free / Starter / Pro` (the original ADR-0027 D3 naming).
- The per-tenant override store and the distributed-limiter backing are deferred (ADR-0067 D2 layer 1 and D5b respectively). The specification implements layers 2 + 3 only and names the distributed-migration triggers without pre-committing the backing.
- Point at canonical audit-event shapes (packet 03) and Pulse metric catalog (packet 04); do not duplicate.

**Key Files:**
- New `infrastructure/walkthroughs/notify-cloud-rate-limit-policy.md` (or equivalent path per the repo's convention).
- `initiatives/active-initiatives.md` — cross-initiative coupling note.

**Contracts:** None changed. `ITenantRateLimitPolicy` (ADR-0026 D4) is unchanged. This packet authors the specification of an *implementation* that will land later against the existing contract.
