# Program: HoneyHub

**Governing PDR:** [PDR-0011: HoneyHub v1 — Agent Cockpit and Usage Governance](../../pdrs/PDR-0011-honeyhub-v1-agent-cockpit-and-usage-governance.md) — Accepted (amended 2026-06-06)
**Status:** Active
**Roadmap thread:** [HoneyHub](../roadmap.md) (Q2 2026, lead product thread) · **Current-focus row:** #1
**Kill criteria / gates:** PDR-0011 §Kill criteria (v1 feasibility) + Amendment §3 `[Firm]` BYOK-only-cloud boundary + Amendment §5 BYOK validation probe
**Last updated:** 2026-06-07 (honeyhub-v1 active packets + Phase A registration underway)

Context: HoneyHub v1 = the **free, local Agent Cockpit** (mobile PWA + desktop, one shared web UI; drives Codex / Claude Code / Copilot via their official CLIs under the user's own local auth). The internal Grid read-layer ([PDR-0009](../../pdrs/PDR-0009-honeyhub-as-internal-daily-driver-workspace.md)) is a later layer; the external-platform thesis ([PDR-0001](../../pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md)) is the long-horizon frame. Per [ADR-0089](../../adrs/ADR-0089-program-tier-for-multi-adr-product-efforts.md), this file is the live cross-ADR tracker.

## Phase Roadmap

The phase spine is PDR-0011's Rollout (dates live on `roadmap.md`, not here).

| Phase | Goal | Decisions in phase | State |
|-------|------|--------------------|-------|
| P1 — Direction on record | PDR accepted; bridge ADR promoted from draft | PDR-0011 (done); local-runner-bridge ADR | In progress |
| P2 — Bridge + one backend, chat-shaped | Local bridge + secure pairing + 1 backend (stream/reply/stop); minimal web run screen; state-only notifications | ADR-0090 (accepted); ADR-0091 App-stack (drafting) | Not started |
| P3 — Second backend + estimated usage + dogfood | 2nd adapter; `UsageSignal`s + advisory `PolicyHint`s; routing + subscription-governance; operator dogfoods vs kill criteria | ADR-0092 Routing + session/usage-telemetry (drafting) | Not started |
| P4 — Individual desktop tier | Desktop layout, personal usage analytics, per-repo/per-task reporting | ADR-0091 App-stack (covers packaging) | Not started |
| P5 — Later layers (v2) | Cloud/API over the same contract; team metadata + admin policy; PDR-0009 read-layer on the dispatch substrate | BYOK-cloud, Dev-surface, team-governance, learned-coaching ADRs | Gated |

## ADR Dependency Map

| Decision | Status | Depends on | Unblocks | Phase |
|----------|--------|------------|----------|-------|
| **[ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md)** Local-runner-bridge (spike-validated; `[Firm]` BYOK-only-cloud rule) | accepted (ADR-0090) | [ADR-0086](../../adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md) substrate (accepted) | App-stack ADR; Routing/telemetry ADR; HoneyHub repo standup | P2 |
| **[ADR-0091](../../adrs/ADR-0091-honeyhub-app-stack-and-repo-node-home.md)** App-stack + repo/Node-home (Tauri-class shell bundling the bridge; mobile→bridge Tailscale relay; new `HoneyDrunk.HoneyHub` Node; Rust bridge `[Provisional]`) | drafting (ADR-0091, Proposed) | [ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md) *accepted* (decision→decision: cites session contract) | HoneyHub repo standup; Individual desktop tier | P2 / P4 |
| **[ADR-0092](../../adrs/ADR-0092-honeyhub-session-usage-telemetry-and-routing.md)** Routing + session/usage-telemetry (`DispatchSession`/`DispatchRun`/`UsageSignal` persistence + fidelity model; routing + subscription-governance; first consumer of ADR-0010 `IRoutingPolicy`; composes ADR-0052) | drafting (ADR-0092, Proposed) | [ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md) *accepted* (cites session contract) | Coaching (rules); Team/org-governance ADR | P3 |
| **BYOK cloud-execution ADR** (`[Firm]` BYOK-API-key only, never subscription auth — Amendment §3) | gated | Local v1 *shipped* (build→build) + Amendment §5 probe converts | Cloud exact accounting + enforcement; unattended runs | P5 / v2 |
| **Dev-surface ADR** (vendor-neutral GitHub + ADO work/decisions/wiki; the re-sequenced PDR-0009 read-layer; internal-default) | gated | A design partner pays over bundled incumbent AI (Amendment §2 differentiation kill) | — | P5 / v2 |
| **Team/org-governance ADR** (cross-user metadata aggregation + admin policy) | gated | Privacy decision + reliable backend capability detection | — | P5 / v2 |
| **Learned-coaching ADR** (per-user learned model; paid enrichment of the free rules-based coach) | gated | Free rules-based coach shipped + retention signal | — | P5 / v2 |

**Status legend:** `needed → drafting → accepted → implemented`, or `gated` (deliberately blocked behind a PDR gate / kill-criterion / validation probe).

## Child Initiatives

None yet — no child ADR is Accepted, so no initiative exists. Each ADR spawns its own `active-initiatives.md` entry when Accepted; this section links to them as they appear.

| Initiative | Governing ADR | active-initiatives link | Hive |
|------------|---------------|-------------------------|------|
| _(none yet)_ | — | — | — |

## Status Rollup

HoneyHub is in **P2 standup / Phase 2 bringup**. The **local-runner-bridge ADR ([ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md))** is Accepted (spike-validated 2026-06-06 against all three backends via their official CLIs under the user's own local auth — the `[Firm]` ToS-clean path). With its session contract locked, the two ADRs it unblocked are drafted and packetized: **[ADR-0091](../../adrs/ADR-0091-honeyhub-app-stack-and-repo-node-home.md)** decides the app stack and repo/Node home (new `HoneyDrunk.HoneyHub` Node via ADR-0082; one shared React PWA; Tauri-class shell bundling the bridge; `[Provisional]` Rust bridge + Tailscale relay + Cloudflare Pages static host; no hosted backend at v1), and **[ADR-0092](../../adrs/ADR-0092-honeyhub-session-usage-telemetry-and-routing.md)** decides session/usage persistence (local-first), the exact/derived/estimated `UsageSignal` fidelity model, and the routing engine — HoneyHub is the first real consumer of ADR-0010's cost-first `IRoutingPolicy`, with "optimize your own subscriptions" pinned `[Firm]` clear of cap-dodging.

The entire **v2 cluster** (BYOK cloud, Dev-surface, team-governance, learned-coaching) stays `gated` behind v1 shipping plus the Amendment §5 BYOK waitlist probe and the §3 `[Firm]` subscription-auth boundary — none is drafted or built now. The `honeyhub-v1` packet set is active; the local `HoneyDrunk.HoneyHub` repo exists and is being reconciled through ADR-0082 standup. Phase A registers the Node in Architecture, packet 10 wires the Actions repo-to-node mapping, and packet 03 scaffolds the mixed TypeScript/Rust workspace before Phase 2 bridge work starts.

**Next action:** complete packet 01 Architecture registration, audit packet 02 human repo setup gaps, land packet 10 in Actions, then scaffold `HoneyDrunk.HoneyHub` via packet 03.
