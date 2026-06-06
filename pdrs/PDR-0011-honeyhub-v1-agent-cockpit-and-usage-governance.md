---
title: "PDR-0011: HoneyHub v1 — Agent Cockpit and Usage Governance"
status: Accepted
date: 2026-06-06
amended: 2026-06-06
deciders: HoneyDrunk Studios
sector: Meta / AI / Platform
relationship: "Names HoneyHub v1 as the FREE, local Agent Cockpit — the lead near-term build focus among parallel portfolio threads (charter §portfolio), and the operator's dogfood wedge. Re-sequences PDR-0009's internal Grid read-layer / daily-driver workspace as a later layer. Amended 2026-06-06 post product-strategist Critic passes (see Amendment §)."
implemented_by: "../generated/adr-drafts/ADR-DRAFT-honeyhub-local-runner-bridge.md"
adjacent: "PDR-0010 Agent Action Ledger; PDR-0002 Notify Cloud"
---

# PDR-0011: HoneyHub v1 — Agent Cockpit and Usage Governance

**Status:** Accepted (amended 2026-06-06)
**Date:** 2026-06-06
**Amended:** 2026-06-06
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform
**Relationship:** Names HoneyHub **v1 = the FREE, local Agent Cockpit** under [PDR-0001](PDR-0001-honeyhub-platform-observation-and-ai-routing.md) (HoneyHub Platform — Observation and AI Routing) — the **lead near-term build focus** among parallel portfolio threads ([`charter.md`](../constitution/charter.md) §"The portfolio model"), and the operator's dogfood wedge. **Re-sequences** [PDR-0009](PDR-0009-honeyhub-as-internal-daily-driver-workspace.md): the internal Grid read-layer / daily-driver workspace becomes a **later layer**, not v1. **Implemented by** [ADR-DRAFT HoneyHub Local Runner Bridge](../generated/adr-drafts/ADR-DRAFT-honeyhub-local-runner-bridge.md) (the §B/§F dispatch substrate). **Adjacent** to [PDR-0010](PDR-0010-agent-action-ledger-hosted-forensic-record-for-ai-agents.md) (Agent Action Ledger — the eventual forensic/usage-record cousin) and [PDR-0002](PDR-0002-notify-as-a-service-first-commercial-product.md) (Notify Cloud, which keeps its own Q3 commercial-trial slot — see Amendment §).

> **Amended 2026-06-06.** Two product-strategist Critic passes pressure-tested the commercial thesis and returned MODIFY. The original body overclaimed the commercial case (a single-product "wedge ahead of Notify Cloud" contest) and silently contradicted [ADR-0088](../adrs/ADR-0088-decommission-openclaw-from-the-grid.md)'s banned shape. The corrected, validated shape is encoded in the **[Amendment (2026-06-06)](#amendment-2026-06-06--commercial-reframing-cloud-execution-boundary-decision-ledger)** section at the end of this PDR, which is **load-bearing and supersedes** the original framing wherever they conflict. The original §A–§I prose is preserved as decision history (with two narrowly-scoped inline corrections flagged in the amendment), per the accepted-PDR amendment convention.

---

## Context

PDR-0001 repositioned HoneyHub from "internal control plane" to "operating system for any software project" and established the external-platform thesis, the Observation domain, the AI Routing layer, and the Native/Observed/Inferred fidelity tiers. It is the load-bearing PDR for HoneyHub's commercial direction, and it remains Accepted.

PDR-0009 then named the *internal* half: HoneyHub as the operator's daily-driver workspace sitting directly over the Architecture repo's knowledge graph, with a read layer, a composed structural+operational UI, per-Node management shells, and a PRs-as-artifacts dispatch boundary. PDR-0009 named the agent-dispatch service as explicit follow-up work but left its product shape and its near-term priority open.

The product signal has now widened, and the operator has made a sequencing call. The internal read-layer is valuable but it is not a wedge — it is HoneyDrunk-shaped, hard to sell, and gated on a large amount of read-index and per-Node-surface work before it produces external value. Meanwhile the operator's day-job environment surfaces a concrete, legible, team-shaped pain point: developers using local AI coding assistants (Codex, Claude Code, Copilot-style workflows) burn tokens, pick the wrong model/thinking level for the task, keep stale sessions alive across unrelated work, and have no single surface to start, watch, interrupt, and govern those sessions — least of all from mobile.

HoneyDrunk itself is heavily AI-operated, so a cockpit that controls local agent sessions, preserves transcripts, streams progress, notifies when input is needed, and records usage/governance signals improves the Grid's own operating loop *and* is the cleanest available dogfooding loop — it can be tested against the operator's real day-job agent usage well ahead of Notify Cloud reaching commercial readiness.

**Operator decision (2026-06-06): HoneyHub v1 leads with the Agent Cockpit product wedge, not the internal Grid read-layer.** This PDR records that decision, makes the cockpit the v1 build target, and cleanly demotes PDR-0009's internal read-layer to a later layer rather than superseding it.

---

## Problem Statement

### 1. The HoneyHub v1 surface was ambiguous between two theses

PDR-0001 (external platform) and PDR-0009 (internal daily-driver) are both true, both Accepted/Proposed, and both legitimate long-term directions — but neither names *what gets built first as a sellable, testable slice*. Without an explicit v1 wedge, HoneyHub risks shipping the internal read-layer first (large surface, no external buyer, slow dogfooding) by default, simply because PDR-0009 is the most concrete plan on record.

### 2. AI coding work is fragmented across tools, worst on mobile

Developers switch between Codex, Claude Code, Copilot surfaces, terminals, IDEs, browser tabs, and GitHub. Each tool has its own chat, session lifecycle, output surface, and notification behavior. On mobile the fragmentation is acute: it is hard to monitor a run, answer a blocking question, interrupt, or redirect without being in the right app at the right moment. The operator runs HoneyDrunk mobile-first; this is a daily friction.

### 3. Token and model usage has no operational governance

Teams adopting local AI coding tools lack a practical policy layer for: which model/thinking level fits a task, when to start a new session, when a high-cost mode needs approval, how much context a session has accumulated, whether a session is producing useful artifacts, and which developers/repos/task-types drive usage. Exact token data is cleanest through provider APIs; local subscription-backed tools expose less, but useful proxies (prompt/response size, duration, turn count, diff size, commands run, model/tool labels, outcome signals) remain available.

### 4. PDR-0009's dispatch follow-up needs a sharper product frame

If the agent-dispatch service is treated only as an internal HoneyHub helper, the design underweights chat UX, mobile notifications, session control, usage analytics, and policy — exactly the features that turn "run a command" into a product. The dispatch work needs to be re-framed as the cockpit, not as a read-layer accessory.

---

## Decision

### A. HoneyHub v1 is the Agent Cockpit

HoneyHub v1 is **Agent Cockpit and Usage Governance**: one web surface to start, watch, interrupt, and govern local AI coding-agent sessions, mobile-first for HoneyDrunk solo operation and desktop-first for individual developers.

> One web surface to start, watch, interrupt, and govern local AI coding-agent sessions — transcripts, token/model governance, and mobile monitoring — with mobile-first controls for HoneyDrunk solo operation and desktop-first controls for individual developers.

> **Corrected 2026-06-06 (Amendment §1).** The sentence below originally read "This is the **commercial wedge** under PDR-0001's external-platform thesis … ahead of Notify Cloud commercial readiness." That overclaimed. v1 is the **FREE, local Agent Cockpit** — the lead near-term *build* focus among parallel portfolio threads and the operator's dogfood wedge, **not** a single-product commercial contest that Notify Cloud lost. The commercial candidate that lives *inside* this thread is the gated, validation-first BYOK cloud-execution seam (Amendment §2/§5), not the free cockpit itself. Read the original sentence through that correction.

This is the **lead near-term build focus** among the studio's parallel portfolio threads ([`charter.md`](../constitution/charter.md) §"The portfolio model") under PDR-0001's external-platform thesis. It is buildable now, testable now against the operator's own day-job agent usage, and it reaches a real team-shaped pain point. It is the cleanest available dogfooding loop, which is why it leads the build queue — not because it won a commercial contest against another product.

### B. The internal Grid read-layer (PDR-0009) becomes a later layer, not v1

PDR-0009 is **not superseded**. Its content — the Architecture repo as HoneyHub's structural backend, the structural+operational composition model, the generic per-Node management shell, the products-via-same-shell integration, and the PRs-as-artifacts boundary — all remain on record and remain the destination for HoneyHub's internal-operator experience.

What changes is **sequencing**: PDR-0009's internal read-layer / daily-driver workspace is re-positioned as a **later layer of HoneyHub**, built after the cockpit wedge proves out, not as the v1 surface. Concretely:

- The cockpit ships first as a session-control product with its own minimal surface; it does **not** wait on the read layer, the catalog index, or any per-Node management shell.
- PDR-0009's read-only-with-dispatch workspace lands later, on top of (or alongside) the cockpit, reusing the cockpit's dispatch substrate for its "New ADR / New PDR / Scope / Refine / Netrunner" actions.
- PDR-0009's PRs-as-artifacts invariant (§D) is **inherited unchanged** by the cockpit — see §F below. The cockpit is the first system to actually exercise it.

This is a re-sequencing relationship, not a contradiction. PDR-0009 stays Proposed and describes the *later* HoneyHub layer; PDR-0011 describes the *v1* HoneyHub layer.

### C. The app is web/PWA plus a local runner bridge

The main UI is a responsive web app / PWA:

- **Mobile-first for HoneyDrunk solo operation** — session list, chat view, notifications, run status, PR/packet links, quick interrupt/redirect controls.
- **Desktop-first for individual developers** — chat plus workspace context, usage analytics, policy hints, session history, local run controls.

A **local runner bridge** runs on each developer machine or runner host and owns local machine access: starting and controlling local Codex / Claude Code sessions, Copilot-compatible workflows where a supported local interface exists, and the `git`/`gh` operations needed to produce artifacts. The web app owns session UX, policy, analytics, notifications, and run records. The bridge owns the local boundary.

### D. One session uses one agent backend

v1 does not attempt multi-agent group chat. A `DispatchSession` is bound to exactly one `AgentBackend` (`codex.local`, `claude.local`, future `codex.api` / `claude.api`, future `copilot.local` workflow). A user may run multiple sessions, but each session has one clear backend so transcripts, approvals, usage estimates, and tool permissions stay legible.

### E. Chat-shaped dispatch is the v1 interaction model

The interaction is a chat-like run screen: user starts a session with a task → the bridge starts the selected backend → agent text/progress/questions/summaries stream into HoneyHub → user can reply/redirect/stop/resume → the session records produced artifacts (branch, diff, PR, packet, ADR/PDR draft, report, failure note) → HoneyHub notifies on `needs_input`, `completed`, `failed`, and `PR opened`. Where a backend supports a stable interactive protocol the bridge keeps one live session; otherwise it approximates continuity by launching follow-up invocations carrying transcript, run metadata, and workspace context.

### F. Usage governance is product-critical, and PRs-as-artifacts is the write boundary

Usage governance is a v1 differentiator, not an afterthought. The cockpit tracks and recommends: model/tool selection by task type, thinking-level selection where exposed, estimated usage (and exact when available), session age and context size, stale-session warnings, new-session and split-task suggestions, expensive-mode approval prompts, automation candidates, and outcome-quality proxies (PR opened, tests passed, review comments, rework loops). Individual desktop mode adds stronger personal policy guidance (recommended model/tool, max session duration, max estimated token budget, required-new-session-per-issue, warning-only posture, per-repo/per-task analytics). Cross-user team/org governance is a later product layer (metadata-only by default).

The cockpit inherits PDR-0009 §D **PRs-as-artifacts** as its write boundary: the bridge never directly mutates authoritative catalog/decision/code state. All durable output lands as a branch/PR/packet/draft that becomes reviewable through the existing `pr-core` / cloud-`review` / branch-protection flow.

### G. Local-first now, cloud/API provider later

The first provider is local:

```text
HoneyHub web/PWA -> secure local runner bridge -> local Codex / Claude Code / git / gh
```

Cloud/API execution is a later provider over the **same** session/run/usage contract:

```text
HoneyHub web/PWA -> cloud dispatch provider -> provider APIs / hosted workers
```

Cloud/API mode is the clean path for exact token/cost accounting, unattended jobs, enterprise audit, and multi-tenant SaaS. Local mode is the right v1 because it reuses existing subscriptions, existing repo checkouts, and the tools developers already run — and because it is the fastest path to dogfooding against the operator's day-job usage.

### H. Data minimization and retention are part of the product shape

Transcripts, prompts, filenames, command lines, diff metadata, and usage signals are sensitive by default. v1 storage prefers local transcript storage with explicit user control over what syncs; usage analytics prefers metadata and summaries over raw prompt/code; command lines are redacted for known secret patterns; diff metadata starts as counts and links, not copied hunks; notifications carry status and links, never prompt text, code, secrets, stack traces, or full paths. Retention keeps active transcripts while a run is open, lets the user pin useful transcripts, prunes unpinned local transcripts after a configurable window, and keeps durable artifact links / usage totals / outcome summaries longer than raw transcripts. Cloud/API mode requires a separate retention and data-processing decision before multi-tenant use.

### I. The cockpit is the lead near-term build focus (parallel to Notify Cloud, not ahead of it)

> **Corrected 2026-06-06 (Amendment §1).** This section originally read "The cockpit moves **ahead of Notify Cloud (PDR-0002)** for near-term focus" and framed the two as a contest the cockpit won. That contradicted the charter's portfolio model and wrongly implied Notify Cloud was *demoted because of* the cockpit. The corrected position is below. **Notify Cloud keeps its Q3 commercial-trial slot** (its own PDR-0002 sequencing and the ADR-0077 provisioning re-sequencing are separate, legitimate dependencies and stand on their own). The cockpit is the **lead near-term *build* thread among parallel threads**, chosen for its dogfood loop and buildable-now shape — not because Notify Cloud lost a single-product contest.

The cockpit is the **lead near-term build focus** among the studio's parallel portfolio threads ([`charter.md`](../constitution/charter.md) §"The portfolio model"). Notify Cloud (PDR-0002) is **not** demoted by this PDR and **retains its Q3 commercial-trial slot**; the two run as parallel threads, not as a contest. The cockpit leads the *build queue* because its forcing function for **building** is stronger: real developer pain at the operator's day job, immediate HoneyDrunk operating value, direct fit with an AI-heavy Grid, and the cleanest available dogfooding loop. That is a sequencing-of-build-attention call, not a claim that the free cockpit out-competes Notify Cloud commercially. Per the charter, the studio is a portfolio; there is no single-product contest to win.

---

## Options Evaluated

### Option A: Keep HoneyHub v1 as the internal Architecture-repo read-layer (PDR-0009 as v1)

**Description:** Ship PDR-0009's read layer + generic Node shell + dispatch-via-PR workspace first; treat the cockpit as a later dispatch feature.

**Pros:**
- Most concrete plan already on record.
- Directly improves HoneyDrunk internal operation.
- Reuses the Architecture-as-code discipline end-to-end.

**Cons:**
- No external buyer — the read-layer is HoneyDrunk-shaped and hard to sell.
- Large surface area (read index, frontmatter parsing, per-Node shells) before any external value.
- Slow, narrow dogfooding loop (operator only, internal use).
- Leaves the legible day-job token/model-governance pain unsolved.

**Verdict:** Rejected as v1. Retained as the **later** HoneyHub layer (PDR-0009 stands, re-sequenced).

### Option B: Build a native desktop app for the cockpit

**Pros:** direct machine access; natural for laptop developers; easy tray/process management.

**Cons:** weak fit for the operator's mobile-first HoneyDrunk workflow; cross-platform packaging burden; team analytics still need a web dashboard.

**Verdict:** Rejected for v1. The bridge may later gain desktop/tray packaging, but the main product is web/PWA.

### Option C: Mobile-first web/PWA + local runner bridge *(Selected)*

**Pros:** works for HoneyDrunk mobile operation and team desktop usage via responsive layout; keeps local tool access in a trusted local process; one UI for sessions, notifications, and governance; can later wrap into native shells; reuses existing local subscriptions and checkouts; fastest dogfooding loop.

**Cons:** requires secure bridge pairing and a remote-control relay path; browsers cannot run local CLIs directly (the bridge exists precisely to bridge that gap); local subscription-backed tools may not expose exact token metrics.

**Verdict:** Selected.

### Option D: Go API/cloud-first

**Pros:** exact token/cost accounting; cleaner central governance; better unattended automation.

**Cons:** higher cost and auth/tenancy complexity; does not reuse developers' existing local subscriptions; slower path to HoneyDrunk mobile dogfooding.

**Verdict:** Deferred. Cloud/API is a second provider over the same contract, not v1.

---

## Trade-offs

| Trade-off | Chosen position | Rationale |
|-----------|-----------------|-----------|
| Internal read-layer (PDR-0009) as v1 vs. Agent Cockpit as v1 | **Cockpit as v1; read-layer later** | The cockpit is a sellable, testable wedge with an immediate dogfooding loop; the read-layer is HoneyDrunk-shaped and external-value-deferred. Re-sequence, do not supersede. |
| Web/PWA + bridge vs. native desktop | **Web/PWA + bridge** | Mobile-first is non-negotiable for HoneyDrunk solo operation; web/PWA serves both audiences from one surface; the bridge supplies the local access browsers lack. |
| Local-first vs. API/cloud-first | **Local-first now, cloud/API later over same contract** | Local reuses existing subscriptions and checkouts and is the fastest path to dogfooding; cloud/API earns its place once exact accounting / unattended / multi-tenant demand is proven. |
| One backend per session vs. multi-agent room | **One backend per session** | Keeps transcripts, approvals, usage estimates, and tool permissions legible; multi-agent theater is not the product need. |
| Exact usage vs. estimated proxies in local mode | **Estimated proxies in local v1; exact when exposed; enforcement advisory** | Local tools rarely expose exact tokens; advisory governance on good proxies is useful now, and enforcement waits for reliable signals / API mode. |
| Cockpit ahead of Notify Cloud vs. Notify Cloud first | **Cockpit ahead for near-term focus; Notify Cloud not cancelled** | Stronger forcing function, easier dogfooding, clearer differentiation; Notify Cloud resumes priority if the cockpit trips a kill criterion. |
| Direct writes vs. PRs-as-artifacts | **PRs-as-artifacts (inherited from PDR-0009 §D)** | Preserves the Grid's review/merge/label discipline; the cockpit is the first system to exercise the boundary in production. |

---

## Architecture Implications

### What this PDR names (direction; no scaffolding triggered here)

| Concept | Role |
|---------|------|
| **Agent Cockpit** | The v1 HoneyHub product surface — start/watch/interrupt/govern local agent sessions. |
| **Local runner bridge** | The local service that owns process launch/lifecycle, workspace access, backend adapters, streaming, control, artifact detection, and secure pairing. Decided by the implementing ADR below. |
| **`AgentBackend`** | Codex local, Claude Code local, future cloud/API providers, or an approved Copilot-compatible local workflow. |
| **`DispatchSession`** | One chat-shaped conversation/run bound to exactly one backend. |
| **`DispatchRun`** | One execution attempt within a session, with status and artifacts. |
| **`Artifact`** | Branch, diff, PR, issue packet, ADR/PDR draft, report, or failure note — the write boundary. |
| **`UsageSignal`** | Exact or estimated usage/cost/context/duration/turn metric. |
| **`PolicyHint`** | Recommendation, warning, or (later) block reason surfaced before/during a session. |

### Implementing ADR and the contract the cockpit requires from the bridge

The implementing technical decision is **[ADR-DRAFT: HoneyHub Local Runner Bridge for Agent Cockpit Sessions](../generated/adr-drafts/ADR-DRAFT-honeyhub-local-runner-bridge.md)** (to be promoted to a numbered ADR). It decides the bridge boundary and session contract; it does not decide the hosted HoneyHub app stack, UI framework, or cloud/API provider.

**The contract the cockpit needs from the bridge ADR:**

```text
HoneyHub web/PWA  ->  secure local runner bridge  ->  local agent tools / git / gh
```

built on the **ADR-0086 local-worker substrate** (the operator's surviving home-server hardware as runner host for solo/HoneyDrunk mode; the developer's own machine for individual desktop mode).

The bridge MUST provide, at minimum:

1. **Secure, explicit, revocable pairing** — user-initiated pairing from HoneyHub, per-device bridge identity, revocable token, a local allowlist of workspace roots (bridge refuses paths outside configured roots), and a backend allowlist. No secret values streamed into HoneyHub transcripts.
2. **One-session-one-backend execution** — start and control an `AgentBackend` per `DispatchSession`, with declared backend capability flags (`streaming_output`, `interactive_reply`, `resume_session`, `stop_signal`, `structured_events`, `usage_exact`, `usage_estimated`). The bridge MUST NOT pretend a one-shot backend supports live interaction.
3. **Chat-shaped run control** — stream agent-visible messages/progress to HoneyHub; surface explicit questions as `needs_input`; accept user replies and control events (stop/cancel/redirect/approve/reject); support follow-up runs after completion; report artifacts as they appear. The run-state machine is `created → queued → starting → running → needs_input → finalizing → completed`, with `stopping`/`failed`/`cancelled` branches.
4. **Usage accounting, estimated-first** — emit estimated local `UsageSignal`s (prompt/response size, turn count, elapsed time, model/tool label, repo, task type, files touched, diff size, commands run, checks run, PR/outcome/rework signals); record exact signals only when a backend exposes them through a supported interface.
5. **Artifacts as the write boundary** — accepted outputs are branch/commit, PR, generated packet, generated ADR/PDR draft, report, failure note. The bridge does NOT directly mutate authoritative Architecture/catalog/code state outside a reviewable git branch (PDR-0009 §D PRs-as-artifacts, inherited).
6. **State-only notifications** — the bridge reports run state (`needs_input`, `completed`, `failed`, `cancelled`, `PR opened`); HoneyHub decides transport (web push, Discord, or existing ADR-0084 alert-routing). Notifications carry status/backend/repo/link only — never prompt text, code, secrets, stack traces, or full paths.
7. **Data classification at the boundary** — the bridge classifies prompts/replies, source/diff content, file paths, command lines, and stdout/stderr before storing or syncing, per §H; prefers repo-relative paths; redacts known secret patterns; defaults transcripts to local storage with explicit user-controlled sync.
8. **A remote-control path for mobile** — a secure relay/network path so the mobile PWA can reach a bridge that runs on the operator's runner host (LAN / Tailscale / cloud relay / hosted HoneyHub tunnel — the specific mechanism is an open question for the ADR).
9. **Same contract for the future cloud/API provider** — the cloud/API provider is a drop-in adapter over the identical `DispatchSession` / `DispatchRun` / `UsageSignal` model, differing only in adapter and auth.

### What this PDR does NOT change

- **PDR-0001** — its external-platform thesis, Observation domain, AI Routing layer, and Native/Observed/Inferred fidelity tiers all stand. The cockpit is the v1 wedge *under* it.
- **PDR-0009** — not superseded. Its structural-backend framing, composition model, per-Node shell, products-via-same-shell integration, and PRs-as-artifacts boundary all remain on record. Only its *sequencing* changes: it describes the later HoneyHub layer.
- **PDR-0010** — the Agent Action Ledger remains a separately gated, behind-Notify-Cloud exploration. The cockpit's `UsageSignal` model is adjacent and may later feed it, but this PDR does not green-light it.
- **Architecture-as-code** — catalogs, decisions, packets, initiatives, constitution remain version-controlled markdown + JSON; the cockpit writes only through reviewable PRs.
- **`constitution/invariants.md`** — unchanged by this PDR. The PRs-as-artifacts boundary remains a candidate for a formal invariant via a future ADR.
- **`catalogs/nodes.json` / `relationships.json`** — no new Nodes or edges. Whether the bridge/cockpit becomes a `HoneyHub.Web` or new Node is an open question for the implementing ADR, not pre-decided here.
- **The IDE-versus-HoneyHub boundary** — hand-written code stays in the IDE; HoneyHub never gains a code editor. The cockpit *dispatches and governs* agent coding work; it does not become an editor.

---

## Product Implications

### v1 product shape

**Solo / HoneyDrunk mode (mobile-first):** local bridge on the operator's home/dev machine or ADR-0086 runner host; session list with status + backend labels; chat-shaped run view; notifications for input/completion/failure; artifact links to branches, PRs, packets, reports, drafts; quick controls (stop, redirect, summarize, open PR, start follow-up session).

**Individual desktop mode (desktop-first):** desktop web cockpit; local bridge on the developer's own machine; session controls for Codex, Claude Code, and approved workflows; personal usage-analytics dashboard; model/tool/thinking-level recommendations; stale-session and split-task warnings; per-repo and per-task-type usage reporting for the current user.

**Future team / org mode:** each developer runs their own local bridge; a central dashboard aggregates **metadata** across users/repos/task-types/tools; admins configure model allowlists, expensive-mode approval thresholds, new-session rules, and enforcement posture. Transcript/content sharing is a separate privacy/security decision; metadata-only aggregation is the default starting point.

### Capability tiers / packaging / positioning

> **Corrected 2026-06-06 (Amendment §8).** The original table below treated the **Individual** desktop tier as "the first **commercial** tier" and implied the paid surface was Dev-surface + arbitrage. That is superseded. The corrected tier shape is in **[Amendment §8 — Corrected capability-tier table](#8-corrected-capability-tier-table)**. In short: **everything that ships in v1 is FREE** (cockpit + cost/usage + optimization routing + rules-based coaching, local-first). The single gated, validation-first **paid** candidate is **BYOK cloud execution** (Amendment §2/§5), with **learned coaching** as a later paid enrichment. The **Dev surface is internal-default** (the PDR-0009 read-layer), not a committed paid tier until a design partner pays. Read the rows below through that correction; "the first commercial tier" no longer applies to Individual.

| Tier | Audience | Capabilities | Packaging intent |
|------|----------|--------------|------------------|
| **Solo / Operator** | HoneyDrunk solo operation (mobile-first) | Full session control, notifications, mid-run control, artifact links, advisory usage hints, local transcript store | First dogfooding tier; operator-controlled HoneyHub store; not a paid tier |
| **Individual** | Single developer (desktop-first) | Everything in Solo plus personal usage analytics, model/thinking-level recommendations, stale-session/split-task warnings, personal policy budgets (advisory) | **FREE per the amendment** (was "first commercial tier"); per-developer; local bridge install; warning-only governance |
| **Team / Org** *(later)* | Multiple developers under shared policy | Cross-user **metadata** aggregation, admin model allowlists, expensive-mode approval thresholds, new-session rules, opt-in enforcement | Later tier; gated on privacy decision + reliable capability detection; admin/seat pricing |
| **Cloud/API** *(later provider, any tier)* | Exact accounting / unattended / multi-tenant | Same session model over provider APIs/hosted workers; exact token/cost accounting; enables hard enforcement | **BYOK-API-key ONLY** (Amendment §3 — never a vendor subscription token); separate retention + data-processing decision before multi-tenant use |

**Positioning:** not "another notification API" and not "an internal HoneyDrunk tool" — a **mobile-first cockpit and usage-governance layer for local AI coding agents**, free at v1. The value is governance + control + monitoring of tools developers already pay for, dogfooded on the operator's real day-job usage. The optimization routing is framed as **"route for capability/cost fit + optimize your own subscriptions"** — explicitly **not** "beat the rate limiter" (Amendment §1). Marketing must never drift to defeating vendor rate limits.

### What changes / does not change for the operator

- **Changes:** a single mobile-first surface to start/watch/interrupt/govern local agent sessions; notifications when a run needs input or finishes; usage visibility on the operator's own AI spend; the dispatch substrate that the later PDR-0009 workspace will reuse.
- **Does not change:** coding stays in the IDE; the packet → PR → review → merge discipline holds; the Architecture repo remains the source of truth; every cockpit mutation lands as a reviewable PR.

---

## What Does NOT Change

- **PDR-0001's external-platform thesis and fidelity-tier model** — intact; the cockpit is the v1 wedge under it.
- **PDR-0009 in substance** — not superseded; its structural backend, composition model, per-Node shell, products-via-same-shell, and PRs-as-artifacts boundary all stand as the *later* HoneyHub layer.
- **PDR-0002 Notify Cloud** — not cancelled and **not demoted by this PDR**; it **keeps its Q3 commercial-trial slot** and runs as a parallel portfolio thread. *(Corrected 2026-06-06, Amendment §1: the original "re-sequenced behind the cockpit" framing wrongly implied the cockpit demoted Notify Cloud; the cockpit is the lead near-term **build** focus, which is a build-attention call, not a commercial demotion of Notify Cloud. The ADR-0077 provisioning re-sequencing is a separate, legitimate dependency.)*
- **Architecture-as-code and the PR-driven review/merge discipline** — `pr-core`, cloud-`review`, branch protection, packet linkage, `out-of-band` labeling all stand.
- **`constitution/invariants.md`, `catalogs/nodes.json`, `catalogs/relationships.json`** — unchanged; no new invariant, Node, or edge created by this PDR.
- **The IDE-versus-HoneyHub boundary** — HoneyHub never gains a code editor.

---

## Risks

| Risk | Severity | Description |
|------|----------|-------------|
| Bridge cannot reliably stream/reply/stop for either local backend | High | If neither Codex nor Claude Code local can be driven for streaming + replies + stop/redirect, the chat-shaped cockpit collapses to a launcher. |
| Local usage estimates too noisy to drive useful recommendations | Medium | If estimates can't support useful hints and exact data is unavailable locally, governance value is weak until API/cloud mode. |
| Developers won't install a local bridge | Medium | The individual commercial tier depends on bridge installation; refusal undermines the desktop product. |
| Secure mobile remote-control path is hard | Medium | Reaching a bridge on the runner host from mobile needs a secure relay; a weak path is a security risk, a heavy path is friction. |
| CLI adapters brittle against unstable tool interfaces | Medium | Codex/Claude Code/Copilot interfaces may shift; adapters may break. |
| Scope creep toward "everything app" / code editor | Medium | The pull to add an editor, terminal, or multi-agent room is strong; crossing the IDE boundary erodes the product. |
| Splitting focus from Notify Cloud without payoff | Medium | If the cockpit neither proves useful nor fails cleanly, it strands two pre-launch products. |
| Transcript/usage data leakage | Medium | Prompts, code, command lines, and paths are sensitive; careless sync or notification content leaks work and secrets. |

## Mitigations

| Risk | Mitigation |
|------|------------|
| Bridge can't drive a backend | Kill criterion: if neither Codex nor Claude Code local supports stream+reply+stop, reduce scope to read-only session launch/logging before building governance. Prototype both adapters early. |
| Noisy estimates | Keep enforcement disabled in local mode; limit governance to warnings on good proxies until exact (API/cloud) accounting exists. |
| No bridge installs | Kill criterion: if individual developers won't install a bridge, reposition desktop as cloud/API-only and keep local mode as operator tooling. |
| Mobile relay | Treat the remote-control path as an explicit open question for the bridge ADR (LAN / Tailscale / cloud relay / hosted tunnel); start with the operator's own runner host on a trusted path. |
| Brittle adapters | Backends declare capability flags; the bridge degrades honestly (no faking live interaction); follow-up runs approximate continuity where `interactive_reply=false`. |
| Scope creep | Bright, restated boundary: coding stays in the IDE; HoneyHub gains no editor and no multi-agent room in v1; crossing requires a new PDR. |
| Focus split | Hard kill criterion (below) returns HoneyHub to the PDR-0009 path and Notify Cloud to priority if the cockpit doesn't reduce session-switching/follow-up latency for HoneyDrunk within two weeks of dogfooding. |
| Data leakage | §H data minimization is part of the product shape and a hard requirement on the bridge ADR (classification, redaction, local-default storage, state-only notifications). |

### Kill criteria

**v1 feasibility kill criteria (original, retained):**

- If the local bridge cannot reliably stream messages, accept replies, and stop/redirect sessions for **at least one** of Codex or Claude Code, reduce scope to read-only session launch/logging before building governance.
- If exact usage metrics are unavailable locally **and** estimates are too noisy to drive useful recommendations, keep enforcement disabled in local mode and limit governance to warnings until API/cloud mode exists.
- If individual developers will not install a local bridge, reposition the desktop experience as cloud/API-only and keep local mode as HoneyDrunk/operator tooling.
- If the cockpit does not reduce session switching and follow-up latency for HoneyDrunk within **two weeks** of dogfooding, return HoneyHub to the PDR-0009 read-only-workspace path. *(Corrected 2026-06-06, Amendment §1: the original "demote this thread back behind Notify Cloud" wording is dropped — the two are parallel threads, not a contest. Tripping this criterion means the cockpit's **build** lead is reconsidered, not that Notify Cloud is "promoted past" it.)*

**Added 2026-06-06 (Amendment §4):**

- **Legal/ToS kill (hard).** Any feature that would require HoneyHub to **hold or forward a vendor subscription auth token**, or any **hosted/cloud execution running on a subscription token**, is **not built** — it is the banned shape. This is non-negotiable and ties directly to the `[Firm]` cloud-execution boundary in Amendment §3. **Precedent:** [ADR-0088](../adrs/ADR-0088-decommission-openclaw-from-the-grid.md) (the Grid's own OpenClaw decommission) and the Anthropic third-party-subscription-auth ToS ban that forced it (clarified early 2026). Re-creating that shape on HoneyHub's own hosted worker is the exact violation the ban targets.
- **Differentiation kill.** If a headline feature ships **free from the vendors or incumbents before us**, there is no wedge and it is not pursued as a paid surface. This has **already tripped for subscription/optimization routing** — 9Router and free OSS routers already do it — which is precisely why routing is a **free-tier-only** capability and never a selling point. It is a **live risk for the Dev surface**: Rovo, Notion, and Linear already bundle AI-over-work-management for free, and Microsoft owns both the GitHub and Azure DevOps endpoints and is actively closing the gap. The Dev surface therefore gets **no commercial scaffolding** until a design partner pays over-and-above their already-bundled incumbent AI (Amendment §2).

---

## Consequences

### Short-term

- HoneyHub's v1 surface is unambiguous: the Agent Cockpit, not the internal read-layer.
- PDR-0009's read-layer is cleanly re-sequenced (later layer) without being lost.
- The implementing bridge ADR has a precise contract to satisfy (§Architecture Implications).
- The operator gains a mobile-first surface to govern real day-job agent usage — the dogfooding loop starts immediately.
- Notify Cloud steps back for near-term focus, with explicit conditions to step forward again.

### Long-term

- The cockpit's `DispatchSession` / `UsageSignal` model becomes the dispatch substrate the later PDR-0009 workspace reuses for its "New ADR / Scope / Refine" actions — the two PDRs converge instead of competing.
- Cloud/API provider mode unlocks exact accounting, enforcement, unattended jobs, and multi-tenant SaaS over the same contract.
- The usage-record surface is a natural future feeder for PDR-0010's Agent Action Ledger, should that exploration promote.
- HoneyHub reaches the external market through a governance wedge developers feel daily, rather than through an internal tool no one outside HoneyDrunk can use.

---

## Rollout

This PDR is direction; execution happens through subsequent packets and initiatives.

### Phase 1 — Direction on record
- This PDR is accepted; the bridge ADR-DRAFT is promoted to a numbered ADR.

### Phase 2 — Bridge + one backend, chat-shaped
- Local runner bridge with secure pairing and one backend adapter (Codex *or* Claude Code local) supporting stream + reply + stop.
- Minimal web/PWA run screen: start session, watch stream, reply, stop, see artifacts.
- State-only notifications for `needs_input` / `completed` / `failed` / `PR opened`.

### Phase 3 — Second backend + estimated usage + solo dogfooding
- Second local backend adapter.
- Estimated `UsageSignal`s and advisory `PolicyHint`s (stale-session, split-task, model/thinking hints).
- Operator dogfoods against day-job usage; evaluate against kill criteria.

### Phase 4 — Individual desktop tier
- Desktop layout, personal usage analytics, per-repo/per-task reporting, personal policy budgets (advisory).
- First commercial (per-seat) packaging.

### Phase 5 — Later layers
- Cloud/API provider over the same contract (exact accounting, enforcement, unattended).
- Team/org metadata aggregation + admin policy (gated on privacy decision).
- PDR-0009 internal read-layer / daily-driver workspace built on top of the cockpit's dispatch substrate.

---

## Open Questions

| Question | Owner | Status |
|----------|-------|--------|
| Does the first bridge live in an existing HoneyHub repo, a new repo, or an ADR-0086 runner package? | Architecture | Open — for the bridge ADR. |
| Minimum supported mobile remote-control path: LAN, Tailscale, cloud relay, or hosted HoneyHub tunnel? | Architecture / Ops | Open — for the bridge ADR. |
| Which Codex and Claude Code interfaces are stable enough for v1 adapters? | Architecture / Product | Open — prototype-gated. |
| Which usage signals are acceptable in individual desktop mode given sensitive code/prompts? | Product / Security | Open. |
| What metadata may future team/org mode aggregate across users? | Product / Security | Open — metadata-only default. |
| Does the cockpit/bridge warrant a `HoneyHub.Web` (or new) Node, and when? | Architecture | Open — deliberate follow-up ADR, not pre-decided. |
| Does PRs-as-artifacts get promoted to a formal `constitution/invariants.md` entry now that the cockpit exercises it? | Architecture | Open — likely yes once the bridge ADR is accepted. |

---

## Recommended Follow-Up Artifacts

| Artifact | Type | Purpose |
|----------|------|---------|
| HoneyHub Local Runner Bridge | **ADR** (promote the existing ADR-DRAFT) | The implementing decision — bridge boundary, pairing, process control, capability flags, session/run model, transcript streaming, interruption, artifact contract, data classification. **This is the primary follow-up.** |
| Session and usage telemetry model | ADR | `DispatchSession` / `DispatchRun` / `UsageSignal` / policy hints; exact-vs-estimated accounting. |
| Mobile-first cockpit UX spec | Design doc | Session list, chat run view, notifications, artifacts; mobile and desktop layouts. |
| Individual desktop usage guidance | Design doc | Personal analytics, model/thinking-level hints, stale-session and split-task recommendations. |
| Team policy and governance model | ADR/PDR | Future admin controls, model allowlists, thinking-level policy, approval thresholds, enforcement posture, privacy boundaries. |
| Cloud/API dispatch provider | ADR | API-key/service-account execution, exact token/cost accounting, hosted-worker security, multi-tenant concerns. |
| Copilot-compatible workflow assessment | Research note | Which Copilot surfaces can be controlled locally or via supported APIs without violating tool boundaries. |
| PRs-as-artifacts as formal invariant | Invariant amendment via ADR | Promote the boundary inherited from PDR-0009 §D to a constitution-level invariant once the bridge ADR is accepted. |
| **BYOK-cloud-execution waitlist experiment** *(Amendment §5)* | Validation probe | One-page waitlist + concrete monthly price + reserve button; <1 solo-dev day to first signal. Gates any commercial scaffolding. |
| **App-stack ADR** *(Amendment §6)* | ADR | Decides the `[Provisional]` desktop packaging (Tauri-class native shell bundling the local bridge) and the mobile-PWA→bridge secure relay. |

---

## Amendment (2026-06-06) — Commercial reframing, cloud-execution boundary, Decision Ledger

**Status of the amendment:** This amendment **supersedes the commercial framing** of the original §A and §I, **adds** the load-bearing cloud-execution / ToS boundary (Amendment §3), **adds** two kill criteria, **records** the cheapest validation experiment, **updates** the v1 scope to match the operator design session, and **adds** the flexibility-posture / Decision Ledger machinery. The original §B–§H (the cockpit shape, the bridge contract, the PRs-as-artifacts write boundary, data minimization) is **unchanged in substance**; only its commercial *framing* and *tier wording* are corrected. The PDR was Accepted the same day it was amended (both dated 2026-06-06); this is a same-day course-correction after two product-strategist **Critic**-mode passes returned **MODIFY**, not a migration off a shipped shape.

This amendment does **not** rewrite the original §A–§I prose wholesale. Where the original framing was actively wrong or misleading, a dated inline correction note was added in place (flagged "Corrected 2026-06-06") and the corrected text follows; the original wording is quoted in the correction note so the delta is auditable. Everything else — the validated additions — lives in this section. **Where this section and the original body conflict, this section wins.**

### Why the amendment

Two product-strategist Critic passes pressure-tested the HoneyHub commercial thesis and each returned **MODIFY**. The findings:

1. **The commercial case was overclaimed.** The original cast v1 as "the commercial wedge … ahead of Notify Cloud," i.e. a single-product contest. Per [`charter.md`](../constitution/charter.md) the studio is a **portfolio, not a startup**; there is no single-product contest to win, and "first commercial product" / "wedge" language is a *trial framing*, not a structural commitment ([`charter.md`](../constitution/charter.md) §"How to read other docs"). v1 is the **FREE, local Agent Cockpit** — the lead near-term *build* thread and the operator's dogfood wedge.
2. **It silently contradicted [ADR-0088](../adrs/ADR-0088-decommission-openclaw-from-the-grid.md).** The "cloud/API provider later" framing left the door open to hosted execution on subscription auth — the exact OpenClaw-style shape the Grid already banned. That boundary is now made hard and explicit (§3).
3. **The paid-tier thesis was wrong.** It implied paid = Dev-surface + subscription arbitrage. Corrected below (§2): arbitrage is free-tier-only; the Dev surface is internal-default; the one real (gated) commercial candidate is BYOK cloud execution.

### §1 — Corrected commercial framing (the core fix)

- **v1 = the FREE, local Agent Cockpit.** It is the Grid's lead near-term *build* thread and the operator's dogfood wedge — **not** "the commercial flagship ahead of Notify Cloud." The single-product-contest framing is struck (charter §"The portfolio model"). The inline corrections in §A and §I above carry this.
- **Notify Cloud (PDR-0002) keeps its Q3 commercial-trial slot.** It is **not** demoted *because of* the cockpit. The ADR-0077 provisioning re-sequencing is a separate, legitimate dependency and remains valid; it is not a commercial demotion.
- **The subscription/optimization routing is a FREE-tier feature**, framed as **"route for capability/cost fit + optimize your own subscriptions"** — explicitly **NOT** "cap-dodging" or "beat the rate limiter." **Marketing and positioning must never drift to language about defeating vendor rate limits.** If the only story a feature can tell is "evade the vendor's limits," it is the wrong feature.

### §2 — Corrected paid-tier thesis: three parts, three fates

The original implied a single Dev-surface-plus-arbitrage paid tier. Corrected, the paid surface is three distinct parts with three distinct fates:

| Part | Fate | Reasoning |
|------|------|-----------|
| **BYOK cloud execution** | **The real (gated) commercial candidate** — pursued commercially **only after** the §5 validation probe converts. | "Kick off an agent from your phone, it runs in the cloud on your **own API key**, no laptop left on." A genuinely unserved seam: GitHub gated BYOK to Business/Enterprise, and BYOK does not apply to *cloud* agents. Cheaply testable (§5). The **only** part to pursue commercially, and only post-probe. **BYOK-API-key only — never a subscription token (§3).** |
| **The Dev surface** | **Recorded vision, default INTERNAL.** Build **no** commercial scaffolding until a design partner commits to pay over-and-above their already-bundled Rovo/Notion/Linear AI. | The vendor-neutral AI layer unifying GitHub Issues/Projects/PRs + Azure DevOps Boards/Repos/Wiki + ADRs/PDRs/knowledge, connector model, status stays in source systems, PRs-as-artifacts. **This is the PDR-0009 read-layer.** Most defensible *long-term* bet **and** the least cheaply-validatable. Honest risks: team-shaped buyer (wrong shape for a solo-dev GTM), incumbents bundle it free, and **Microsoft owns both the GitHub and Azure DevOps endpoints and is actively closing the gap.** |
| **The coaching agent** | **A retention FEATURE, not a standalone commercial leg.** Rules-based in v1 (free); a **learned per-user model** is a later **paid enrichment**. | Stop presenting it as a third commercial pillar. It increases retention of the free cockpit; the learned model is the only paid slice, and only later. |

### §3 — `[Firm]` cloud-execution / ToS boundary (the single most important addition)

This is a non-negotiable **`[Firm]`** decision (not a default), and it is the boundary that separates HoneyHub from the [ADR-0088](../adrs/ADR-0088-decommission-openclaw-from-the-grid.md)/OpenClaw banned shape:

- **HoneyHub never holds, stores, or proxies vendor subscription auth.** Local execution drives each vendor's **official** CLI, running **locally**, under the **user's own session**. (Anthropic confirms the official Claude Code CLI is within ToS even on a remote server that the user *themselves* SSHes into — i.e. a machine the user controls.)
- **Cloud/hosted execution is BYO-API-key ONLY and MUST NEVER authenticate with a vendor subscription token.** The "remote server" allowance covers a server **the user controls**, **NOT** a multi-tenant SaaS executing on their behalf with their subscription. Running the official CLI on **our** hosted worker against **their subscription** would re-create the exact violation — it is the OpenClaw/ADR-0088 banned shape. This is stated as **hard and explicit**: there is no configuration, tier, or convenience exception.

The §4 Legal/ToS kill criterion enforces this: any feature that would require holding/forwarding subscription auth, or hosting execution on subscription tokens, is **not built**.

### §4 — Added kill criteria

Both new kill criteria are recorded in the **[Kill criteria](#kill-criteria)** section above (the v1-feasibility kill criteria there are retained):

- **Legal/ToS kill (hard)** — no feature holds/forwards subscription auth; no hosted execution on subscription tokens. Precedent: ADR-0088 (the Grid's own OpenClaw decommission) + the Anthropic third-party-subscription-auth ToS ban that forced it (clarified early 2026).
- **Differentiation kill** — if a headline feature ships free from vendors/incumbents before us, there is no wedge. Already tripped for subscription/optimization routing (9Router, free OSS) → routing is free-tier-only and not a selling point. Live risk for the Dev surface (Rovo/Notion/Linear bundle AI-over-work-management free; Microsoft owns both endpoints).

### §5 — Cheapest validation experiment (before any commercial scaffolding)

Before **any** commercial scaffolding is built for BYOK cloud execution:

1. **One-page BYOK-cloud-execution waitlist** with a **concrete monthly price** and a **reserve button**, driven to the operator's build-in-public audience. **<1 solo-dev day to first signal.**
2. **If it converts past a pre-set threshold within 30 days →** graduate to a **Wizard-of-Oz** on the existing [ADR-0086](../adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md) runner for **3–5 design partners** (BYOK only, per §3).
3. **If not →** BYOK cloud execution stays **operator tooling**; no commercial build.

**The Dev surface has NO sub-2-week proof and therefore gets no scaffolding regardless** of the BYOK-cloud outcome. It remains internal-default (§2) until a design partner pays over-and-above their bundled incumbent AI.

### §6 — Richer v1 scope (from the operator design session)

The v1 product shape is updated to match what was actually decided. This supersedes the original §C "mobile-first … and desktop-first" phased reading and the Rollout's mobile-then-desktop ordering:

- **Mobile (PWA) + desktop in PARALLEL, one shared web UI.** (Corrects the original phased mobile-then-desktop sequencing.)
- **Desktop = "Option A": a single packaged native shell (Tauri-class) that BUNDLES the local bridge** → one easy install; the mobile PWA reaches that bundled bridge over a **secure relay**. Exact stack is **`[Provisional]`**, decided in the app-stack ADR.
- **Any repo; three backends via their official CLIs:** **Codex** + **Claude Code** (full), **GitHub Copilot CLI** (best-effort — its CLI wraps GPT/Claude). This relaxes the original §D "v1 does not attempt multi-agent group chat" only in *surface* (one chat across all three), not in the one-backend-per-session contract.
- **One chat surface across all three; parallel sessions/threads** (a unified multi-agent chat). Each session remains bound to exactly one backend (original §D preserved); the unification is at the chat surface, not the session contract.
- **Agent-discovery** from `.claude/agents/` and the Copilot agent folder — auto-surface and run them.
- **Always-on cost/token usage; rules-based coaching; local-first data.**

### §7 — Flexibility posture (explicit operator requirement)

For HoneyHub records, a deliberate flexibility posture so direction changes are cheap to **execute**, not just to decide.

#### Decision Ledger

Each HoneyHub decision is tagged **`[Firm]`** or **`[Provisional]`**.

- **`[Firm]`** — load-bearing boundaries we do not move without real cause:
  - not-an-editor / not-a-terminal (HoneyHub never gains a code editor or terminal — original §"What Does NOT Change" preserved);
  - **PRs-as-artifacts** write boundary (inherited from PDR-0009 §D, original §F);
  - connector-**never**-system-of-record (status stays in the source systems);
  - local-first data **default**;
  - honest capability flags (the bridge never fakes live interaction — original §F / contract item 2);
  - **never touch subscription auth / cloud = BYOK-only** (§3).
- **`[Provisional]`** — working assumptions we intend to revise on signal:
  - routing heuristics;
  - backend order / support (Codex/Claude/Copilot priority);
  - exact UX;
  - packaging / stack (the Tauri-class shell, the relay mechanism);
  - coaching rules;
  - the Dev-surface and BYOK-cloud **commercial bets**.

#### Lightweight amendment protocol

A **`[Provisional]`** decision changes via **a conversation + an amendment note in the record** — no new PDR/ADR, no ceremony — **as long as no `[Firm]` boundary is crossed**. Only crossing a **`[Firm]`** line needs a fresh decision (a new or amended ADR/PDR). This is consistent with the accepted-PDR amendment convention this very section uses.

#### Reversibility as architecture

The flexibility is **structural**, not just procedural: backends are **adapters behind a stable session contract** (original §D / §G — "same contract for the future cloud/API provider"); routing is **config/policy-driven**; connectors are **isolated**. A direction change swaps an adapter or a policy, not a rewrite.

### §8 — Corrected capability-tier table

This supersedes the original "Capability tiers / packaging / positioning" table (which is annotated inline above). The corrected shape:

| Tier | Cost | Capabilities |
|------|------|--------------|
| **Free** | $0 | Cockpit + cost/usage visibility + optimization routing ("route for capability/cost fit + optimize your own subscriptions") + rules-based coaching. **Local-first.** Includes the Solo/Operator and Individual desktop experiences — both free. |
| **Paid (gated, validated)** | TBD per §5 probe | **BYOK cloud execution** (the testable wedge — BYOK-API-key only, §3) **+ learned coaching** (later paid enrichment of the free rules-based coach). |
| **Dev surface** | **Internal-default — not a committed paid tier** | The PDR-0009 read-layer (vendor-neutral AI-over-work-management). **No commercial scaffolding** until a design partner pays over-and-above their already-bundled Rovo/Notion/Linear AI (§2). |

### What stays unchanged (amendment)

- **The cockpit shape** (original §A product definition, §B PDR-0009 re-sequencing, §C bridge architecture, §D one-backend-per-session contract, §E chat-shaped dispatch, §F usage governance + PRs-as-artifacts write boundary, §G local-first / same-contract cloud provider, §H data minimization) — **unchanged in substance.**
- **The implementing bridge ADR contract** (original §"Architecture Implications") — unchanged; it now additionally inherits the §3 `[Firm]` BYOK-only cloud boundary when the cloud/API adapter is built.
- **PDR-0001** (external-platform thesis, fidelity tiers) and **PDR-0009** (not superseded; the read-layer is the Dev surface, internal-default per §2) — unchanged.
- **`constitution/invariants.md`, `catalogs/nodes.json`, `catalogs/relationships.json`** — unchanged; this amendment adds no invariant, Node, or edge. The PRs-as-artifacts boundary remains a candidate for a future formal invariant.
