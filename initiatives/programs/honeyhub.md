# Program: HoneyHub

**Governing PDR:** [PDR-0011: HoneyHub v1 — Agent Cockpit and Usage Governance](../../pdrs/PDR-0011-honeyhub-v1-agent-cockpit-and-usage-governance.md) — Accepted (amended 2026-06-06)
**Status:** Active
**Roadmap thread:** [HoneyHub](../roadmap.md) (Q2 2026, lead product thread) · **Current-focus row:** #1
**Kill criteria / gates:** PDR-0011 §Kill criteria (v1 feasibility) + Amendment §3 `[Firm]` BYOK-only-cloud boundary + Amendment §5 BYOK validation probe
**Last updated:** 2026-06-06

Context: HoneyHub v1 = the **free, local Agent Cockpit** (mobile PWA + desktop, one shared web UI; drives Codex / Claude Code / Copilot via their official CLIs under the user's own local auth). The internal Grid read-layer ([PDR-0009](../../pdrs/PDR-0009-honeyhub-as-internal-daily-driver-workspace.md)) is a later layer; the external-platform thesis ([PDR-0001](../../pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md)) is the long-horizon frame. Per [ADR-0089](../../adrs/ADR-0089-program-tier-for-multi-adr-product-efforts.md), this file is the live cross-ADR tracker.

## Phase Roadmap

The phase spine is PDR-0011's Rollout (dates live on `roadmap.md`, not here).

| Phase | Goal | Decisions in phase | State |
|-------|------|--------------------|-------|
| P1 — Direction on record | PDR accepted; bridge ADR promoted from draft | PDR-0011 (done); local-runner-bridge ADR | In progress |
| P2 — Bridge + one backend, chat-shaped | Local bridge + secure pairing + 1 backend (stream/reply/stop); minimal web run screen; state-only notifications | Local-runner-bridge ADR; App-stack ADR | Not started |
| P3 — Second backend + estimated usage + dogfood | 2nd adapter; `UsageSignal`s + advisory `PolicyHint`s; routing + subscription-governance; operator dogfoods vs kill criteria | Routing + session/usage-telemetry ADR | Not started |
| P4 — Individual desktop tier | Desktop layout, personal usage analytics, per-repo/per-task reporting | App-stack ADR (covers packaging) | Not started |
| P5 — Later layers (v2) | Cloud/API over the same contract; team metadata + admin policy; PDR-0009 read-layer on the dispatch substrate | BYOK-cloud, Dev-surface, team-governance, learned-coaching ADRs | Gated |

## ADR Dependency Map

| Decision | Status | Depends on | Unblocks | Phase |
|----------|--------|------------|----------|-------|
| **[ADR-0090](../../adrs/ADR-0090-honeyhub-local-runner-bridge.md)** Local-runner-bridge (spike-validated; `[Firm]` BYOK-only-cloud rule) | drafting (ADR-0090 Proposed) | [ADR-0086](../../adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md) substrate (accepted) | App-stack ADR; Routing/telemetry ADR; HoneyHub repo standup | P2 |
| **App-stack + repo/Node-home ADR** (Tauri-class shell bundling the bridge; mobile→bridge relay; `HoneyHub.Web` Node) | needed | Bridge ADR *accepted* (decision→decision: cites session contract) | HoneyHub repo standup; Individual desktop tier | P2 / P4 |
| **Routing + session/usage-telemetry ADR** (`DispatchSession`/`DispatchRun`/`UsageSignal`; routing + subscription-governance; reaches into HoneyDrunk.AI / ADR-0010) | needed | Bridge ADR *accepted* (cites session contract) | Coaching (rules); Team/org-governance ADR | P3 |
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

HoneyHub is in **P1 → P2**. The critical path is the **local-runner-bridge ADR**: its draft exists and a throwaway feasibility spike (2026-06-06) validated the full bridge contract — stream / reply / stop / resume-with-memory / usage — against **all three backends** (Claude Code, Codex, Copilot), each driven via its official CLI under the user's own local auth (the `[Firm]` ToS-clean path). Promoting that draft to a numbered, Accepted ADR is the **rank-#1 current-focus deliverable**, and it unblocks both the **App-stack** and **Routing/telemetry** ADRs, which each cite its session contract and cannot be drafted until it lands.

The entire **v2 cluster** (BYOK cloud, Dev-surface, team-governance, learned-coaching) is `gated` behind v1 shipping plus the Amendment §5 BYOK waitlist probe and the §3 `[Firm]` subscription-auth boundary — none is drafted or built now. No HoneyHub repo exists yet; the App-stack ADR decides the `HoneyHub.Web` Node and its standup.

**Next action:** promote the local-runner-bridge ADR.
