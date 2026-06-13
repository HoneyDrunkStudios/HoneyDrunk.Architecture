---
name: Routing Engine — Synced Cost/Policy Snapshot
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["feature", "tier-2", "honeyhub", "adr-0092", "wave-7"]
dependencies: ["work-item:08"]
adrs: ["ADR-0092", "ADR-0090", "ADR-0091", "ADR-0010", "ADR-0016", "ADR-0052"]
source: human
generator: scope
wave: 7
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Feature: App-tier routing engine consuming a synced cost/policy snapshot (cut from packet 09 §3d)

## Summary
The first concretely-scoped child packet cut from the packet 09 §3d Phase 3+ outline (the routing engine). It builds the **app-tier routing engine** for HoneyHub — route for capability/cost fit + subscription-aware load-balancing ("optimize your own subscriptions") — and resolves the packet 09 §3d / ADR-0092 D3 open seam in favor of a **synced static snapshot**: HoneyHub consumes HoneyDrunk.AI's routing policy **and** the per-model cost rates as a serialized data artifact (a JSON snapshot), **not** a live per-call `IModelRouter` request.

This is the consumption shape the **2026-06-08 ADR-0092 amendment** committed (operator-confirmed): HoneyDrunk.AI's `IRoutingPolicy` stays the canonical routing-policy contract; HoneyHub consumes a build/publish-time snapshot **derived** from the Grid's operator-configurable cost-rate table (ADR-0052 D2 / ADR-0016 D5) and routing policy, and either bundles it or fetches-once-and-caches it. HoneyDrunk.AI only **produces** the snapshot; it does **not** run as an always-on service HoneyHub calls at runtime. This preserves the `[Firm]` local-first / offline-capable v1 posture (ADR-0090 / ADR-0091 D4 / PDR-0011 §G).

This packet also **wires the `HoneyDrunk.HoneyHub → HoneyDrunk.AI` consume edge** in the Architecture catalogs (named in ADR-0091 D6, deferred from packet 01) — as a **"consumes synced snapshot (data)"** relationship, **not** a runtime RPC edge.

**Multi-repo:** the router + snapshot-consumer lands in `HoneyDrunk.HoneyHub`; the catalog edge lands in `HoneyDrunk.Architecture`. Per the operator's "one PR per repo per initiative" rule these are two PRs; the refine pass may split this packet into a HoneyHub feature packet + an Architecture catalog packet if cleaner.

This packet does **NOT**: build the Codex/Copilot adapters (§3a/§3b — their own packets), the rules-based coach (§3e — its own packet), or design the snapshot *producer* if open seam 3 concludes one is needed in HoneyDrunk.AI (that is a HoneyDrunk.AI-side packet, flagged below).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub` (the app-tier router module + snapshot loader) **and** `HoneyDrunkStudios/HoneyDrunk.Architecture` (`catalogs/relationships.json` — the AI consume edge as a data relationship).

## Motivation
ADR-0092 D3 made the routing engine the headline feature and left the placement (`live IModelRouter` call vs. app-side evaluation of a synced policy copy) as a `[Provisional]` open seam — the one D3 Open Question. The 2026-06-08 amendment resolved it: a **synced static snapshot**, because a live call would require a hosted HoneyDrunk.AI endpoint or an online dependency on every routing decision, both of which contradict the v1 local-first `[Firm]` shape (ADR-0091 D4: "no hosted backend at v1"; ADR-0090 / PDR-0011 §G local-first default).

The cross-language boundary (.NET producer / Rust + TypeScript consumer) is therefore a **serialized data contract — a JSON snapshot** — not code interop and not a live RPC. This is the same logic ADR-0091 D3's note already gestured at ("reimplement the cost-first policy shape app-side and treat HoneyDrunk.AI as the canonical policy source"); the amendment makes it concrete and `[Firm]` for the *consumption shape* while keeping the heuristics `[Provisional]`.

The `derived` fidelity tag (ADR-0092 D2) already makes a stale snapshot diagnosable — a HoneyHub USD figure computed from a stale snapshot drifts visibly against a backend's `exact` figure (Claude Code). The snapshot inherits D2's honesty discipline.

## Proposed Implementation

### Consume the routing policy + cost rates as a synced static snapshot (the resolved `[Firm]` shape)
- The router reads a **local snapshot artifact** — a JSON document carrying (a) the per-model cost rates and (b) the routing-policy fields (the `IRoutingPolicy`-shaped policy projection). It does **not** make a network call to a HoneyDrunk.AI service on the routing hot path.
- The snapshot is **generated from the Grid's operator-configurable cost-rate table + routing policy** (ADR-0016 D5 / ADR-0052 D2 — the App-Configuration-sourced surface) at **build/publish time**. HoneyHub treats it as a frozen, read-only projection of the canonical source; it does **not** coin its own rates or fork a parallel routing abstraction (ADR-0092 D3 `[Firm]`).
- USD values computed from snapshot rates (the Codex `derived` path, ADR-0092 D2) are tagged `fidelity: derived` — never `exact`. A stale snapshot is therefore visible, not silent.

### The app-tier router (ADR-0092 D3)
- Runs in the **HoneyHub app/UI tier** (where session + usage + quota data aggregate per device/user), **not inside the local bridge** (the bridge's job stays narrow — drive one CLI — per ADR-0090 / ADR-0091 D3).
- **(a) Route for capability + cost fit:** given a task's declared/inferred requirements (type, repo, risk, context size), pick the backend whose capability profile fits and whose cost profile is appropriate, evaluated against the snapshot's `IRoutingPolicy`-shaped policy.
- **(b) Subscription/quota-aware load-balancing — "optimize your own subscriptions":** track per-provider consumption of the **user's own** subscription/quota and prefer a backend with headroom when capability/cost fit is otherwise comparable. Read quota where the backend exposes it; estimate otherwise (same fidelity discipline as D2). A `derived`/`estimated` quota figure only drives a **soft** routing preference, never a hard action.
- **`[Firm]` boundary:** this is **"optimize your own subscriptions,"** **NEVER** cap-dodging / rate-limit evasion / account multiplexing / credential rotation (ADR-0092 D3 / PDR-0011 Amendment §1/§8). The router load-balances the user's own legitimately-held subscriptions only.
- **Heuristics stay `[Provisional]`** (ADR-0092 D3 ledger): the fit/cost/headroom weighting is a tunable working assumption. This packet ships a concrete weighting behind a clean boundary; refine/dogfood tunes it without a new ADR.

### Wire the `HoneyDrunk.HoneyHub → HoneyDrunk.AI` consume edge (Architecture-side)
- Edit `catalogs/relationships.json`: move `honeydrunk-honeyhub` from the `consumed_by_planned` list on `honeydrunk-ai` into a **realized** consume relationship, and add the reciprocal entry on `honeydrunk-honeyhub`.
- The edge MUST be explicitly typed as a **data / synced-snapshot** relationship, **not** an RPC / package-compile edge. The catalog representation must not imply a live runtime dependency that does not exist (e.g. annotate it as `consumes (synced snapshot — data)` in whatever the catalog's relationship-kind convention is, and keep it out of any "runtime dependency" / `blocked_by` semantics). Mirror the existing data-vs-runtime distinctions already in the catalog; if the schema has no kind field, carry the distinction in the `consumes_detail` description string.
- This is the ADR-0091 D6 deferred edge; the 2026-06-08 ADR-0092 amendment reassigns it from "the ADR-0091 standup packet" to this packet.

### Honest degradation
- If no snapshot is present (e.g. a fetched-and-cached delivery on first run with no network), the router degrades honestly: it routes on the backends' own `exact`/`estimated` signals and the UI surfaces that cost-fit routing is operating without a current rate snapshot — it never fabricates rates or presents a guessed USD as `derived`/`exact`.

## Open seams (refine pass MUST resolve before execution — do NOT decide in this packet)
These are surfaced by the 2026-06-08 ADR-0092 amendment and inherited here. The refine pass resolves each; this packet deliberately does not pre-commit them.

1. **Delivery — bundled-into-HoneyHub vs. fetched-from-a-static-location-and-cached.** And, if fetched, **where the static artifact is published** (candidates to weigh: the Cloudflare-Pages static surface per ADR-0091 D4; a GitHub Release asset; alongside the Architecture-repo cost surface). Bundling is simplest + fully offline but couples rate freshness to a HoneyHub release; fetch-and-cache decouples freshness but needs a publish location and a first-run network path. Refine picks one.
2. **Refresh cadence + stale-snapshot surfacing.** How often the snapshot regenerates, and how a stale snapshot is surfaced to the user. Note: the `derived` fidelity tag (ADR-0092 D2) already makes stale rates *diagnosable* — refine decides whether to add an explicit snapshot-age indicator on top.
3. **Snapshot schema/format + producing surface.** The exact JSON schema (per-model rates + which routing-policy fields), and **which Grid surface generates it**: HoneyDrunk.AI directly (a serialized projection of `IRoutingPolicy` + the cost-rate config) vs. the ADR-0052 cost-governance surface (`business/context/cost-budgets.json` / the cost-report aggregator). I.e. **does HoneyDrunk.AI already expose this, or does a small publish step need adding** — and if a publish step is needed in HoneyDrunk.AI, that is a **separate HoneyDrunk.AI-side packet** (a .NET repo, different node-class), not in-scope for this HoneyHub/Architecture packet. Refine must determine the producer before this packet's consumer work can assume a concrete schema.

## Acceptance Criteria
- [ ] The app-tier router consumes a **local snapshot** of routing policy + per-model cost rates; it makes **no** live per-call network request to a HoneyDrunk.AI service (the resolved `[Firm]` synced-snapshot shape, ADR-0092 2026-06-08 amendment).
- [ ] The router implements (a) capability/cost-fit routing and (b) subscription/quota-aware load-balancing, evaluated against the snapshot's `IRoutingPolicy`-shaped policy — HoneyHub does **not** fork a parallel routing abstraction (ADR-0092 D3 `[Firm]`).
- [ ] Routing is **"optimize your own subscriptions"** only; there is no account-multiplexing / credential-rotation / rate-limit-evasion path anywhere in the router (ADR-0092 D3 / PDR-0011 Amendment §1 `[Firm]`).
- [ ] USD computed from snapshot rates is tagged `fidelity: derived` (never `exact`); a `derived`/`estimated` quota figure drives only a soft preference, never a hard action (ADR-0092 D2/D3).
- [ ] No-snapshot degradation is honest: routing operates on backend-native signals and the UI surfaces the missing snapshot; no fabricated/guessed rates.
- [ ] **Architecture-side:** `catalogs/relationships.json` realizes the `honeydrunk-honeyhub → honeydrunk-ai` edge as a **data / synced-snapshot** relationship (HoneyHub removed from `honeydrunk-ai`'s `consumed_by_planned`, added as a realized consumer with the data-vs-RPC distinction explicit); the catalog does not imply a live runtime dependency. Catalog validation passes.
- [ ] The three open seams (delivery, refresh/staleness, schema+producer) are resolved in the PR description (or by a preceding refine note), and any HoneyDrunk.AI-side producer work is split into its own packet rather than absorbed here.
- [ ] Tests: the router selects the expected backend for representative (capability-fit, cost-fit, headroom-tiebreak) cases against a fixture snapshot; a stale/missing-snapshot test asserts honest degradation and correct `derived` tagging; a contract test asserts the snapshot loader rejects a malformed snapshot rather than silently routing on garbage.
- [ ] CHANGELOG(s) updated (invariants 12, 27): HoneyHub repo-level + the router module; the Architecture catalog edit noted. PR bodies link this packet (invariant 32) and the metadata fields (`Authorship:` + `Work Item:`).

## Human Prerequisites
- [ ] **Refine-pass decisions (operator):** resolve the three open seams above (delivery, refresh/staleness, schema+producer) before execution — in particular open seam 3 determines whether a HoneyDrunk.AI-side snapshot-publish packet must be cut first.
- [ ] (If open seam 1 = fetch-and-cache) the chosen static publish location exists / is provisioned.

## Dependencies
- `work-item:08` — the Phase 2 first-shippable slice (session + usage + the one backend + run screen) must exist before the routing engine has real signal to route over.
- (Conditional) a HoneyDrunk.AI-side snapshot-producer packet, **if** open seam 3 concludes HoneyDrunk.AI must add a publish step (cut during refine; this packet's consumer work depends on the snapshot schema it produces).

## Agent Handoff
**Objective:** Build the app-tier routing engine consuming a synced static cost/policy snapshot (not a live `IModelRouter` call), and wire the `HoneyHub → AI` consume edge as a data relationship.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub` (router + snapshot loader) and `HoneyDrunkStudios/HoneyDrunk.Architecture` (`catalogs/relationships.json`), branch from `main` in each (two PRs per the one-PR-per-repo rule).
**Context:**
- Cut from packet 09 §3d (the routing-engine outline bullet); resolves the ADR-0092 D3 open seam per the **2026-06-08 ADR-0092 amendment**.
- ADRs: ADR-0092 (D3 routing + the 2026-06-08 synced-snapshot amendment, D2 fidelity), ADR-0010/ADR-0016 (`IRoutingPolicy` is canonical, cost-rate config via App Configuration), ADR-0052 (D2 operator-configurable rate table), ADR-0091 (D3 router lives app-tier not in the bridge, D4 local-first/no-hosted-backend, D6 the deferred AI edge), ADR-0090 (local-first / BYOK).

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 08 (Phase 2 complete); conditionally a HoneyDrunk.AI producer packet (per open seam 3 refine outcome).

**Constraints (full text inlined):**
- ADR-0092 D3 `[Firm]` (reaffirmed by the 2026-06-08 amendment): HoneyDrunk.AI's `IRoutingPolicy` is the canonical routing-policy contract; HoneyHub **consumes** it (via the snapshot) and does **not** fork a parallel routing abstraction. Routing = "optimize your own subscriptions" (capability/cost fit + the user's own subscription headroom), **NEVER** cap-dodging / rate-limit evasion / account multiplexing / credential rotation.
- ADR-0092 2026-06-08 amendment `[Firm]` (consumption shape): the routing policy AND per-model cost rates are consumed as a **synced static snapshot** (a serialized JSON data contract) generated at build/publish time from the operator-configurable cost-rate table + routing policy — **not** a live per-call `IModelRouter` request. HoneyDrunk.AI only **produces** the snapshot; it is not an always-on service HoneyHub calls at runtime.
- ADR-0092 D2 `[Firm]`: usage/cost fidelity always tagged exact/derived/estimated; the UI never renders an estimate (or a snapshot-derived figure) as `exact`. Snapshot-computed USD is `derived`.
- ADR-0091 D4 `[Firm]`: local-first, no hosted backend at v1 — the router must work offline-capably; no Azure Container App / Function tier for the cockpit.
- ADR-0091 D3: the routing brain runs in the app/UI tier, NOT inside the local bridge (the bridge drives one CLI; the router lives a layer up).
- The `HoneyHub → AI` catalog edge is a **data (synced snapshot)** relationship, not a runtime RPC / package-compile dependency — the catalog must not imply a live dependency that does not exist.

**Key Files:**
- HoneyHub: the app-tier router module + a snapshot-loader module (consuming the snapshot per the refine-chosen delivery shape); `shared-types` for the snapshot schema once open seam 3 is resolved. CHANGELOG(s).
- Architecture: `catalogs/relationships.json` (the `honeydrunk-honeyhub` / `honeydrunk-ai` edge), and any catalog relationship-kind/validation surface that distinguishes data vs runtime edges.

**Contracts:**
- The router evaluates an ADR-0010 `IRoutingPolicy`-shaped policy projected into the snapshot (HoneyDrunk.AI remains the canonical source). The snapshot schema (per-model rates + routing-policy fields) is finalized by open seam 3's refine outcome.
