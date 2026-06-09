# Program: HoneyHub

**Governing PDR:** [PDR-0011: HoneyHub v1 — Agent Cockpit and Usage Governance](../../pdrs/PDR-0011-honeyhub-v1-agent-cockpit-and-usage-governance.md) — Accepted (amended 2026-06-06)
**Status:** Active
**Roadmap thread:** [HoneyHub](../roadmap.md) (Q2 2026, lead product thread) · **Current-focus row:** #9 (reconcile sweep; v1 shipped)
**Kill criteria / gates:** PDR-0011 §Kill criteria (v1 feasibility) + Amendment §3 `[Firm]` BYOK-only-cloud boundary + Amendment §5 BYOK validation probe
**Last updated:** 2026-06-09 (HoneyHub v1 shipped; ADR-0090/0091/0092 all Accepted; residual = reconcile bookkeeping)

Context: HoneyHub v1 = the **free, local Agent Cockpit** (mobile PWA + desktop, one shared web UI; drives Codex / Claude Code / Copilot via their official CLIs under the user's own local auth). The internal Grid read-layer ([PDR-0009](../../pdrs/PDR-0009-honeyhub-as-internal-daily-driver-workspace.md)) is a later layer; the external-platform thesis ([PDR-0001](../../pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md)) is the long-horizon frame. Per [ADR-0089](../../adrs/ADR-0089-program-tier-for-multi-adr-product-efforts.md), this file is the live cross-ADR tracker.

## Phase Roadmap

The phase spine is PDR-0011's Rollout (dates live on `roadmap.md`, not here).

| Phase | Goal | Decisions in phase | State |
|-------|------|--------------------|-------|
| P1 — Direction on record | PDR accepted; bridge ADR promoted from draft | PDR-0011 (done); local-runner-bridge ADR | Done (PDR accepted; bridge ADR promoted) |
| P2 — Bridge + one backend, chat-shaped | Local bridge + secure pairing + 1 backend (stream/reply/stop); minimal web run screen; state-only notifications | ADR-0090 (accepted); ADR-0091 App-stack (accepted) | Decisions accepted (ADR-0090/0091); v1 shipped |
| P3 — Second backend + estimated usage + dogfood | 2nd adapter; `UsageSignal`s + advisory `PolicyHint`s; routing + subscription-governance; operator dogfoods vs kill criteria | ADR-0092 Routing + session/usage-telemetry (accepted) | Decisions accepted (ADR-0092); v1 shipped |
| P4 — Individual desktop tier | Desktop layout, personal usage analytics, per-repo/per-task reporting | ADR-0091 App-stack (covers packaging) | Decision accepted (ADR-0091); v1 shipped |
| P5 — Later layers (v2) | Cloud/API over the same contract; team metadata + admin policy; PDR-0009 read-layer on the dispatch substrate | BYOK-cloud, Dev-surface, team-governance, learned-coaching ADRs | Gated |
| P6 — Loop Console (loop engineering surface) | Define an LDR, launch a loop run, watch its heartbeat, approve the one human gate, see per-loop cost; composes (does not fork) the ADR-0090 session model + ADR-0092 `UsageSignal`/routing; becomes the fleet console at scale | ADR-0093 (Loop Console = D9); reuses ADR-0090/0092 contracts | Gated — v1 prerequisite met; not yet drafted/scheduled (sequenced behind Tier-B loops) |

## ADR Dependency Map

| Decision | Status | Depends on | Unblocks | Phase |
|----------|--------|------------|----------|-------|
| **[ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md)** Local-runner-bridge (spike-validated; `[Firm]` BYOK-only-cloud rule) | accepted (ADR-0090) | [ADR-0086](../../adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md) substrate (accepted) | App-stack ADR; Routing/telemetry ADR; HoneyHub repo standup | P2 |
| **[ADR-0091](../../adrs/ADR-0091-honeyhub-app-stack-and-repo-node-home.md)** App-stack + repo/Node-home (Tauri-class shell bundling the bridge; mobile→bridge Tailscale relay; new `HoneyDrunk.HoneyHub` Node; Rust bridge `[Provisional]`) | accepted (ADR-0091) | [ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md) *accepted* (decision→decision: cites session contract) | HoneyHub repo standup; Individual desktop tier | P2 / P4 |
| **[ADR-0092](../../adrs/ADR-0092-honeyhub-session-usage-telemetry-and-routing.md)** Routing + session/usage-telemetry (`DispatchSession`/`DispatchRun`/`UsageSignal` persistence + fidelity model; routing + subscription-governance; first consumer of ADR-0010 `IRoutingPolicy`; composes ADR-0052) | accepted (ADR-0092) | [ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md) *accepted* (cites session contract) | Coaching (rules); Team/org-governance ADR | P3 |
| **BYOK cloud-execution ADR** (`[Firm]` BYOK-API-key only, never subscription auth — Amendment §3) | gated | Local v1 *shipped* (build→build) + Amendment §5 probe converts | Cloud exact accounting + enforcement; unattended runs | P5 / v2 |
| **Dev-surface ADR** (vendor-neutral GitHub + ADO work/decisions/wiki; the re-sequenced PDR-0009 read-layer; internal-default) | gated | A design partner pays over bundled incumbent AI (Amendment §2 differentiation kill) | — | P5 / v2 |
| **Team/org-governance ADR** (cross-user metadata aggregation + admin policy) | gated | Privacy decision + reliable backend capability detection | — | P5 / v2 |
| **Learned-coaching ADR** (per-user learned model; paid enrichment of the free rules-based coach) | gated | Free rules-based coach shipped + retention signal | — | P5 / v2 |
| **[ADR-0093](../../adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md) Loop Console** (D9 — operator surface for loop engineering; LDR define / launch / heartbeat / one-gate-approve / per-loop cost; fleet console at scale) | gated | HoneyHub v1 *shipped* (ADR-0091 app stack + ADR-0092 session/usage); composes both | Fleet console; loop-observability meta-loop; long-horizon ADR-0003 control plane | P6 |

**Status legend:** `needed → drafting → accepted → implemented`, or `gated` (deliberately blocked behind a PDR gate / kill-criterion / validation probe).

## Child Initiatives

None yet — no child ADR is Accepted, so no initiative exists. Each ADR spawns its own `active-initiatives.md` entry when Accepted; this section links to them as they appear.

| Initiative | Governing ADR | active-initiatives link | Hive |
|------------|---------------|-------------------------|------|
| _(none yet)_ | — | — | — |

## Status Rollup

**HoneyHub v1 has shipped.** The free, local Agent Cockpit is live, and all three governing decisions are now Accepted: the **local-runner-bridge ADR ([ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md))** (spike-validated 2026-06-06 against all three backends via their official CLIs under the user's own local auth — the `[Firm]` ToS-clean path), the **app-stack + repo/Node-home ADR ([ADR-0091](../../adrs/ADR-0091-honeyhub-app-stack-and-repo-node-home.md))** (new `HoneyDrunk.HoneyHub` Node via ADR-0082; one shared React PWA; Tauri-class shell bundling the bridge; `[Provisional]` Rust bridge + Tailscale relay + Cloudflare Pages static host; no hosted backend at v1), and the **session/usage-telemetry + routing ADR ([ADR-0092](../../adrs/ADR-0092-honeyhub-session-usage-telemetry-and-routing.md))** (local-first session/usage persistence; the exact/derived/estimated `UsageSignal` fidelity model; the routing engine — HoneyHub is the first real consumer of ADR-0010's cost-first `IRoutingPolicy`, with "optimize your own subscriptions" pinned `[Firm]` clear of cap-dodging). ADR-0091 and ADR-0092 flipped to Accepted on 2026-06-09 — v1 shipping realized both, so promotion was bookkeeping. `HoneyDrunk.HoneyHub` and `HoneyDrunk.Infrastructure` are already registered in `catalogs/nodes.json`; the only residual is exit-review/verification bookkeeping, folded into the current-focus reconcile sweep (#9).

The entire **v2 cluster** (BYOK cloud, Dev-surface, team-governance, learned-coaching) stays `gated` behind v1 shipping plus the Amendment §5 BYOK waitlist probe and the §3 `[Firm]` subscription-auth boundary — none is drafted or built now. The next HoneyHub-program phase is the **P6 Loop Console ([ADR-0093](../../adrs/ADR-0093-loop-engineering-closed-loop-agent-orchestration.md))**, which composes the ADR-0090 session model and ADR-0092 `UsageSignal`/routing contracts; its v1 prerequisite is now met, but it is not yet drafted or scheduled (sequenced behind Tier-B/eval-gated loops per ADR-0093).

**Next action:** close out the exit-review/verification bookkeeping in the current-focus reconcile sweep (#9) — `HoneyDrunk.HoneyHub` is already registered in `catalogs/nodes.json`; the P6 Loop Console (ADR-0093) is the next HoneyHub-program phase — its v1 prerequisite is met, but it is not yet drafted/scheduled (sequenced behind Tier-B loops).
