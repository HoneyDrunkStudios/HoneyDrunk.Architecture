# ADR-0092: HoneyHub Session, Usage Telemetry, and Routing

**Status:** Accepted
**Date:** 2026-06-06
**Accepted:** 2026-06-09 — HoneyHub v1 has shipped; the session/usage-telemetry + routing decision is realized. Acceptance is operator-confirmed reconciliation (the decision was conceptually accepted with v1; this flips the on-disk status to match).
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform
**Implements:** [PDR-0011](../pdrs/PDR-0011-honeyhub-v1-agent-cockpit-and-usage-governance.md) (HoneyHub v1 — Agent Cockpit) §F (usage governance is product-critical) + §H (data minimization / retention) + Amendment §1/§8 (optimization routing as a FREE-tier "optimize your own subscriptions" feature, explicitly **not** cap-dodging).
**Relationships:** Builds on [ADR-0090](ADR-0090-honeyhub-local-runner-bridge.md) (HoneyHub Local Runner Bridge) — persists and normalizes its D3 session model and D5 estimated-vs-exact usage signals, grounded in its feasibility-spike findings. Plugs into [ADR-0010](ADR-0010-observation-layer.md) (Observation Layer and AI Routing) — HoneyHub is the **first real consumer** of the cost-first `IRoutingPolicy` / `IModelRouter` in HoneyDrunk.AI. Composes [ADR-0052](ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) cost governance (the `ICostLedger` model and per-agent/per-run attribution shape). Sibling to [ADR-0091](ADR-0091-honeyhub-app-stack-and-repo-node-home.md) (App Stack and Repo / Node Home); both implement PDR-0011 and build on ADR-0090. Tracked in the [HoneyHub program](../initiatives/programs/honeyhub.md).

---

## Context

ADR-0090 named the session model (`DispatchSession` / `DispatchRun` / `DispatchMessage` / `DispatchControlEvent` / `DispatchArtifact` / `UsageSignal` / `PolicyHint`) and the estimated-vs-exact usage split, but explicitly deferred their **persistence, retention, and the routing/coaching engine** to a follow-up ("Define `DispatchSession` storage and retention"; "Define usage-estimation heuristics and confidence levels" — ADR-0090 Follow-Up Work). PDR-0011 §F made usage governance a v1 differentiator and §H made data minimization part of the product shape; the HoneyHub program's dependency map names a "Routing + session/usage-telemetry ADR" that depends on the bridge ADR being accepted and carries "routing + subscription-governance." This is that ADR.

The headline feature is the **routing engine**: route a task to the agent backend that fits its capability and cost profile **and** load-balance across the user's own provider subscriptions so the user gets the most out of what they already pay for. PDR-0011 Amendment §1/§8 is emphatic about the marketing shape: this is **"route for capability/cost fit + optimize your own subscriptions,"** explicitly **NOT** "beat the rate limiter" or "cap-dodging." That distinction is load-bearing and is encoded as a `[Firm]` boundary here.

The ADR-0090 feasibility spike gives the concrete ground truth this ADR builds on:

| Capability | Claude Code | Codex | Copilot |
|---|---|---|---|
| usage | exact tokens **+ USD** | exact tokens (no USD) | premium-requests + duration only |

So `UsageSignal` must normalize **three** usage shapes. That is the spine of D2.

This ADR decides: the data model's persistence + local-first storage + retention (D1); the UsageSignal normalization / exact-vs-estimated model across the three backends (D2); the routing engine and how it plugs into ADR-0010 / ADR-0052 (D3); and rules-based coaching (`PolicyHint`) for v1 (D4). It does **not** design the learned coaching model — that is a separately gated v2 ADR (PDR-0011 Amendment §2/§8, named in the HoneyHub program's dependency map as `gated`).

---

## Decision

### D1. Data model persistence, local-first storage, and retention

The ADR-0090 D3 entities are persisted **local-first**, honoring the PDR-0011 §H / ADR-0090 D11 data-classification and retention rules:

| Entity | Persisted where (v1) | Notes |
|---|---|---|
| `DispatchSession` | Local store on the bridge host (and the desktop shell's local store), keyed by session id. | The user-facing container; one backend per session (ADR-0090 D2). |
| `DispatchRun` | Local, child of session. | One execution attempt; carries run-state-machine state (ADR-0090 D3). |
| `DispatchMessage` | Local transcript store; **sensitive by default** (ADR-0090 D11). | Streamed or final; never leaves the device unless the user enables session/workspace sync. |
| `DispatchControlEvent` | Local, child of run. | stop/pause/resume/redirect/approve/reject/timeout — also the bridge's process-launch audit trail (ADR-0090 D8). |
| `DispatchArtifact` | Local **metadata + links** (branch/PR/packet/draft/report); not copied hunks (ADR-0090 D11). | The PRs-as-artifacts write boundary; the durable, longer-retained record. |
| `UsageSignal` | Local; **operational metadata** safe to aggregate for the current user. | Exact or estimated (D2). |
| `PolicyHint` | Local, attached to session/run. | Advisory recommendation/warning (D4). |

**Storage shape `[Provisional]`:** an **embedded local store** (e.g. SQLite in the desktop shell / bridge host) for structured records (sessions, runs, control events, usage, artifacts metadata, hints), with transcripts (`DispatchMessage` bodies) in local files/blobs the user can pin or prune. `[Provisional]` — the exact embedded engine is a working assumption; the `[Firm]` part is **local-first with explicit user-controlled sync**, not the engine choice.

**Retention** (ADR-0090 D11, restated as the committed defaults):

- **Active sessions:** retain transcript + stream logs until the run completes.
- **Completed sessions:** keep the local transcript for a **configurable window** unless **pinned**; prune unpinned transcripts after the window.
- **Durable records** (run status, backend, repo, **artifact links, `UsageSignal` totals, outcome summaries**) are kept **longer than raw transcripts** — they are the governance/analytics substrate and carry no raw prompt/code content.
- **No central transcript store at v1.** Any future team/org aggregation is **metadata-only by default** (ADR-0090 D11) and requires a separate privacy decision (gated, out of this ADR).

This is `[Firm]` on the local-first/retention shape (it inherits the PDR-0011 §H product requirement) and `[Provisional]` on the concrete window values and the embedded engine.

### D2. UsageSignal normalization — the exact-vs-estimated model across three backends

`UsageSignal` normalizes the three usage shapes the ADR-0090 spike observed, with an explicit **fidelity tag** on every signal so the UI and the routing engine never silently treat an estimate as ground truth. Every `UsageSignal` carries a `fidelity` ∈ { `exact`, `derived`, `estimated` } and the backend label.

| Backend | What the backend exposes | HoneyHub `UsageSignal` | `fidelity` |
|---|---|---|---|
| **Claude Code** | exact tokens **+ USD** | tokens and USD taken directly; no computation. | `exact` |
| **Codex** | exact tokens (no USD) | tokens taken directly; **USD computed** from operator-configured per-model rates (the ADR-0052 / ADR-0016 D5 cost-rate table). | tokens `exact`, USD `derived` |
| **Copilot** | premium-requests + duration only (no tokens, no USD) | premium-request count + duration taken directly; tokens/USD **estimated** from text-size + duration proxies (ADR-0090 D5 estimated-local-signal list). Note (spike finding 5): Copilot's CLI runs a Claude model under the hood on a **separate billing bucket** — a premium-request unit, not a token bill. | premium-requests/duration `exact`, tokens/USD `estimated` |

**The model, precisely:**

- **`exact`** — the backend reported the number; store as-is.
- **`derived`** — exact input units (tokens) reported, but the **dollar value is computed** from the operator-configurable rate table. Deterministic, not a guess — but it depends on rate config, so it is tagged distinctly from `exact` so a stale rate table is diagnosable.
- **`estimated`** — neither the unit nor the dollar value is reported; HoneyHub estimates from proxies (prompt/response size, turn count, duration, model/tool label, files touched, diff size, commands run — ADR-0090 D5). Carries a coarse confidence band, never presented as a precise figure.

**Consequences of the model (committed):**

- The UI must **visually distinguish** exact / derived / estimated (e.g. an exact USD figure vs. a "~$" estimate band). Never render an estimate as an exact number — that is a `[Firm]` honesty rule paralleling ADR-0090 D4's "the bridge never fakes a capability."
- **Enforcement stays advisory in local v1** (PDR-0011 §F / ADR-0090 D6): because two of three backends are `derived`/`estimated`, HoneyHub **warns** but does not hard-block on usage in local mode. Hard enforcement waits for the BYOK-cloud / API provider (gated) where usage is `exact` end-to-end.
- The USD-rate table is the **same operator-configurable rate surface** ADR-0052 D2 / ADR-0016 D5 already own; HoneyHub does not coin a parallel rate config — it reads the Grid's cost-rate source so HoneyHub's "your spend" view and the Grid's cost ledger agree.

### D3. The routing engine — capability/cost fit + subscription-aware load-balancing

The routing engine is the headline feature. It does two things, and the boundary between them and "cap-dodging" is `[Firm]`:

**(a) Route for capability + cost fit.** Given a task (and its declared/inferred requirements — task type, repo, risk, context size), pick the backend whose capability profile fits and whose cost profile is appropriate ("use a cheaper/faster backend for discovery-only work" — ADR-0090 D6). This is exactly the **cost-first `IRoutingPolicy`** shape ADR-0010 defined for HoneyDrunk.AI.

**(b) Subscription/quota-aware load-balancing — "optimize your own subscriptions."** Track, per provider, how much of the **user's own** subscription/quota has been consumed, and prefer a backend with headroom when capability/cost fit is otherwise comparable — so the user gets the most value out of subscriptions they already pay for. This is **NOT** rate-limit evasion: it does not multiplex one account across many, does not rotate credentials to dodge a cap, and never markets "beat the limiter." It load-balances **the user's own** legitimately-held subscriptions. (PDR-0011 Amendment §1/§8 — the `[Firm]` marketing-shape boundary.)

**Quota tracking:**

- **Read quota where the backend exposes it**; **estimate otherwise.** Grounded in the same spike asymmetry as D2 — Claude Code exposes exact usage (so remaining headroom against a known plan is computable), Codex exposes exact tokens, Copilot exposes premium-request counts (so premium-request headroom is trackable directly). Where a provider exposes no quota signal, HoneyHub estimates consumed-vs-plan from accumulated `UsageSignal`s and a user-entered plan ceiling, tagged with the same `fidelity` discipline as D2. A `derived`/`estimated` quota figure never drives a hard action — only a soft routing preference.

**How it plugs into ADR-0010 / HoneyDrunk.AI and ADR-0052 — HoneyHub is the first real consumer:**

- ADR-0010 established `IModelRouter` / `IRoutingPolicy` (cost-first, capability-first, latency-first) in HoneyDrunk.AI, with policies stored in App Configuration and loaded via config — but it has had **no real consumer** until now (ADR-0010's Phase 3 was "HoneyHub integration, when HoneyHub is live"). HoneyHub's routing engine is that consumer: it **expresses HoneyHub's routing decisions as an `IRoutingPolicy`-shaped policy** so HoneyDrunk.AI remains the canonical routing-policy home, and the cost-first policy ADR-0010 named gains its first production exercise.
- **Placement `[Provisional]`:** the routing brain runs in the **HoneyHub app/UI tier** (where session + usage + quota data aggregate per device/user), **not inside the local bridge** (the bridge's job is narrow — drive one backend's CLI — per ADR-0090/ADR-0091 D3). The app-tier router *consumes* the ADR-0010 `IRoutingPolicy` shape. Whether HoneyHub calls a live HoneyDrunk.AI `IModelRouter` over a contract boundary or evaluates a policy-config copy app-side is `[Provisional]` (ADR-0091 D3 already flagged this is a contract-boundary concern, not a reason to make the bridge .NET) — the `[Firm]` part is "HoneyDrunk.AI's `IRoutingPolicy` is the canonical routing-policy contract; HoneyHub does not fork a parallel routing abstraction."
- **ADR-0052 cost governance** is composed, not duplicated: HoneyHub reads the operator-configurable cost rates (D2) and the per-agent/per-run attribution shape (ADR-0052 D6 — `AgentId`/`AgentRunId`) so a HoneyHub session's spend attributes cleanly into the Grid cost picture. HoneyHub's **local** advisory governance is distinct from ADR-0052's **Grid-wide kill-switch** (which fires on `ILlmDispatcher` calls inside the Grid's own AI Node, not on a developer's local CLI subscription spend) — the two are complementary surfaces over a shared rate/attribution model, and HoneyHub does **not** try to kill-switch a user's local subscription session (it has no authority to, and `estimated` usage couldn't safely drive a hard cap anyway).

**Routing heuristics are `[Provisional]`** (PDR-0011 Amendment §7 lists "routing heuristics" explicitly as provisional) — the fit/cost/headroom weighting is a working assumption to tune on signal; the `[Firm]` part is the policy *boundary* (canonical `IRoutingPolicy`; "optimize your own subscriptions," never cap-dodging).

### D4. Rules-based coaching (`PolicyHint`) for v1 — the learned model is a gated v2 ADR

v1 coaching is **rules-based only**, surfaced as advisory `PolicyHint`s (ADR-0090 D6, advisory in local v1). The v1 rule set:

- "Start a new session — this run crossed the configured turn/context threshold." (stale-session)
- "Use a cheaper/faster backend for discovery-only work." (routing hint)
- "Split this into planning and implementation runs." (split-task)
- "High-thinking mode requested for low-risk docs work — consider a lighter mode." (mode-fit)
- "This task looks like an automation/template candidate." (automation)
- "You have headroom on provider X this cycle — consider routing here." (subscription-optimization, the D3 surface as a coachable hint)

These are **deterministic rules over the `UsageSignal` / session-state data** (thresholds, labels, proxy counts) — no learned model, no per-user training. They are advisory: warning-only posture, never a hard block in local v1 (consistent with the `derived`/`estimated` fidelity of two of three backends, D2).

**The learned per-user coaching model is explicitly NOT designed here.** It is a **gated v2 ADR** (PDR-0011 Amendment §2 — "the coaching agent … a learned per-user model is a later paid enrichment"; §8 paid-tier table; named `gated` in the HoneyHub program dependency map as "Learned-coaching ADR"). This ADR ships only the free rules-based coach; the learned model is a separate decision behind the free-coach-shipped-plus-retention-signal gate. Designing it here would pre-empt that gate.

---

## Consequences

### Positive

- ADR-0090's deferred persistence/retention and usage-heuristics questions are closed, local-first, honoring §H without inventing a central transcript store.
- The exact/derived/estimated fidelity model makes the three-backend usage asymmetry (the spike's central finding) **honest and diagnosable** — the UI never lies about precision, and a stale rate table is visible as a `derived` figure drifting.
- HoneyDrunk.AI's `IRoutingPolicy` (ADR-0010) gets its **first real consumer** and first production exercise of the cost-first policy, without HoneyHub forking a parallel routing abstraction.
- Cost rates and per-agent/run attribution are **read from** the ADR-0052 / ADR-0016 surfaces, so HoneyHub's "your spend" view and the Grid cost ledger agree by construction.
- The "optimize your own subscriptions" framing is pinned `[Firm]` clear of cap-dodging, protecting the product's marketing shape and ToS posture (PDR-0011 Amendment §1).

### Negative

- **Usage governance is advisory, not enforcing, in local v1** — by design (two of three backends are `derived`/`estimated`). Hard enforcement waits for the gated BYOK-cloud/API provider where usage is `exact`. Users wanting hard caps locally are unserved until then; this is the accepted trade (ADR-0090 D6 / PDR-0011 §F).
- **Quota tracking is partly estimated** — where a provider exposes no quota signal, headroom is a best-effort estimate and only ever drives a *soft* routing preference. A confident-looking headroom number could mislead; the fidelity tag mitigates but does not eliminate this.
- **Routing-policy placement (app-tier vs live HoneyDrunk.AI call) is left `[Provisional]`** — a deliberate open seam, resolved by the implementing spike, not pre-committed.
- **The rate table becomes a shared dependency** — HoneyHub's USD figures are only as good as the operator-configured rates (ADR-0052 D2); a stale table makes `derived` USD wrong (visibly, via the fidelity tag).

### Affected / named Nodes

- **`HoneyDrunk.HoneyHub`** (ADR-0091) — owns the local session/usage store, the fidelity model, the app-tier routing engine, and the rules-based coach.
- **`HoneyDrunk.AI`** — consumed for the `IRoutingPolicy` / `IModelRouter` contract (ADR-0010) and the operator-configurable cost-rate surface (ADR-0016 D5 / ADR-0052 D2). HoneyHub is its first routing consumer; **no change to HoneyDrunk.AI's contracts is required by this ADR** (it consumes the existing shapes).
- **`HoneyDrunk.Architecture`** — `business/context/cost-budgets.json` / the cost-rate config (ADR-0052) is the rate source HoneyHub reads; no edit here.

### Cascade

- No `constitution/invariants.md` change. **No new invariant.** The honesty rule (never render an estimate as exact) and the "optimize your own subscriptions, never cap-dodge" boundary are HoneyHub `[Firm]` ledger items inheriting PDR-0011 Amendment §1/§7 and ADR-0090 D4's honest-capability discipline — they do not warrant a constitution entry for a solo operator (consistent with ADR-0089 D7 / ADR-0090 / ADR-0091).
- No `catalogs/*.json` / Node-graph edge is committed here; the `HoneyDrunk.HoneyHub → HoneyDrunk.AI` consume edge is named in ADR-0091 D6 and wired by the ADR-0091 standup packet.
- The routing engine is the first production consumer of ADR-0010 Phase 3 ("HoneyHub integration"); ADR-0010's phase plan is advanced, not amended.

### Tier

Tier 2 (per `routing/request-types.md`) — a session/telemetry/routing design over an accepted contract (ADR-0090) and an accepted routing layer (ADR-0010); the build is the heavier follow-up.

---

## Alternatives Considered

### Central (cloud) transcript + usage store at v1

Rejected. A central store contradicts the PDR-0011 §H / ADR-0090 D11 local-first default and pulls toward a content-bearing hosted surface before it is earned. Local-first with explicit user-controlled sync is the v1 posture; central metadata-only aggregation is gated team/org work.

### Treat all usage as a single number (drop the fidelity tag)

Rejected. The spike's central finding is that the three backends report fundamentally different things (exact USD vs exact tokens vs premium-requests). Collapsing them into one undifferentiated number would render estimates as facts, mislead the routing engine, and break the §F honesty the product sells. The exact/derived/estimated tag is the load-bearing fix.

### Hard-enforce usage caps locally in v1

Rejected. Two of three backends expose only `derived`/`estimated` usage; a hard local kill-switch on an estimate would fire wrongly and break a user's own legitimate subscription session HoneyHub has no authority over. Advisory in local v1; hard enforcement waits for the `exact` BYOK-cloud/API provider (gated). Mirrors ADR-0090 D6.

### Fork a HoneyHub-specific routing abstraction instead of consuming ADR-0010's `IRoutingPolicy`

Rejected. ADR-0010 already defined the cost-first routing contract in HoneyDrunk.AI specifically so callers don't hardcode routing; HoneyHub forking a parallel abstraction would duplicate it and split the canonical policy home. HoneyHub expresses its routing as an `IRoutingPolicy`-shaped policy and consumes the contract — HoneyHub is the consumer ADR-0010 was waiting for.

### Subscription multiplexing / credential rotation to extend effective limits

Rejected on principle and pinned `[Firm]` out of scope. This is the cap-dodging shape PDR-0011 Amendment §1/§8 bans. The routing engine load-balances **the user's own** legitimately-held subscriptions for value, and never multiplexes accounts or rotates credentials to defeat a rate limit. The marketing shape must never drift here.

### Design the learned per-user coaching model in this ADR

Rejected. The learned model is a gated paid v2 enrichment (PDR-0011 Amendment §2/§8; `gated` in the program dependency map). v1 ships only the deterministic rules-based coach; the learned model is a separate decision behind its own gate, and designing it here would pre-empt that gate.

---

## Decision Ledger

Per the HoneyHub flexibility posture (PDR-0011 Amendment §7), each decision is tagged `[Firm]` or `[Provisional]`. Firm boundaries are kept minimal and load-bearing.

- **`[Firm]`** — do not move without a real new decision:
  - **Local-first session/usage storage with explicit user-controlled sync**, and the §H/ADR-0090-D11 retention shape (active transcripts retained, unpinned pruned after a window, durable metadata/usage/artifact-links kept longer than raw transcripts, no central transcript store at v1) (D1).
  - **Usage fidelity is always tagged exact / derived / estimated, and the UI never renders an estimate as an exact figure** (D2) — the usage-honesty parallel to ADR-0090 D4's honest-capability rule.
  - **HoneyDrunk.AI's `IRoutingPolicy` (ADR-0010) is the canonical routing-policy contract; HoneyHub consumes it and does not fork a parallel routing abstraction** (D3).
  - **Routing = "optimize your own subscriptions" (capability/cost fit + the user's own subscription headroom), NEVER cap-dodging / rate-limit evasion / account multiplexing / credential rotation** (D3) — the PDR-0011 Amendment §1/§8 marketing-and-ToS boundary.
  - **Usage governance is advisory in local v1; hard enforcement waits for the gated `exact` BYOK-cloud/API provider** (D2/D4; inherits ADR-0090 D6).
  - **v1 coaching is rules-based only; the learned per-user model is a separately gated v2 decision, not designed here** (D4).
- **`[Provisional]`** — working assumptions, revise on signal via a conversation + an amendment note here (no new ADR) as long as no `[Firm]` line is crossed:
  - the embedded local-store engine (SQLite-class) and the concrete retention-window values (D1);
  - the routing heuristics — the fit/cost/headroom weighting (D3; PDR-0011 Amendment §7 lists routing heuristics as provisional);
  - the routing-engine placement detail — live HoneyDrunk.AI `IModelRouter` call vs. app-side evaluation of a policy-config copy (D3);
  - quota-estimation heuristics where a provider exposes no quota signal (D3);
  - the exact rules-based `PolicyHint` set and thresholds (D4; "coaching rules" is provisional per PDR-0011 Amendment §7).

> **Lightweight amendment note (template for future revisions):** A `[Provisional]` change is recorded as a dated bullet appended to this ledger ("Amended YYYY-MM-DD: added a `redirect-loop` PolicyHint rule; no `[Firm]` line crossed"). Only crossing a `[Firm]` line requires a new or amended ADR.

---

## Open Questions

| Question | Owner | Status |
|---|---|---|
| Does the app-tier router call a live HoneyDrunk.AI `IModelRouter`, or evaluate a synced policy-config copy app-side? | Architecture | Open — implementation-spike-gated (D3). |
| What plan-ceiling input does the user provide for providers that expose no quota signal, and how is `estimated` headroom presented without over-trusting it? | Product / Security | Open (D3). |
| Concrete retention-window defaults (transcript prune window; durable-record horizon) given local storage limits. | Product | Open (D1). |
| Which additional rules-based `PolicyHint`s earn their place once the operator dogfoods against day-job usage? | Product | Open — dogfood-gated (D4). |
| When does the gated learned-coaching v2 ADR open (free-coach-shipped + retention signal)? | Architecture / Product | Gated — out of this ADR (D4). |
