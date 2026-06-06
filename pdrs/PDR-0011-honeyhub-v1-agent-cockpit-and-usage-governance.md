# PDR-0011: HoneyHub v1 — Agent Cockpit and Usage Governance

**Status:** Accepted
**Date:** 2026-06-06
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform
**Relationship:** Selects the **v1 commercial wedge** under [PDR-0001](PDR-0001-honeyhub-platform-observation-and-ai-routing.md) (HoneyHub Platform — Observation and AI Routing). **Re-sequences** [PDR-0009](PDR-0009-honeyhub-as-internal-daily-driver-workspace.md): the internal Grid read-layer / daily-driver workspace becomes a **later layer**, not v1. **Implemented by** [ADR-DRAFT HoneyHub Local Runner Bridge](../generated/adr-drafts/ADR-DRAFT-honeyhub-local-runner-bridge.md) (the §B/§F dispatch substrate). **Adjacent** to [PDR-0010](PDR-0010-agent-action-ledger-hosted-forensic-record-for-ai-agents.md) (Agent Action Ledger — the eventual forensic/usage-record cousin). **Re-sequences ahead of** [PDR-0002](PDR-0002-notify-as-a-service-first-commercial-product.md) (Notify Cloud) for near-term focus.

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

This is the **commercial wedge** under PDR-0001's external-platform thesis. It is buildable now, testable now against the operator's own day-job agent usage, and it reaches a real team-shaped pain point ahead of Notify Cloud commercial readiness.

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

```
HoneyHub web/PWA -> secure local runner bridge -> local Codex / Claude Code / git / gh
```

Cloud/API execution is a later provider over the **same** session/run/usage contract:

```
HoneyHub web/PWA -> cloud dispatch provider -> provider APIs / hosted workers
```

Cloud/API mode is the clean path for exact token/cost accounting, unattended jobs, enterprise audit, and multi-tenant SaaS. Local mode is the right v1 because it reuses existing subscriptions, existing repo checkouts, and the tools developers already run — and because it is the fastest path to dogfooding against the operator's day-job usage.

### H. Data minimization and retention are part of the product shape

Transcripts, prompts, filenames, command lines, diff metadata, and usage signals are sensitive by default. v1 storage prefers local transcript storage with explicit user control over what syncs; usage analytics prefers metadata and summaries over raw prompt/code; command lines are redacted for known secret patterns; diff metadata starts as counts and links, not copied hunks; notifications carry status and links, never prompt text, code, secrets, stack traces, or full paths. Retention keeps active transcripts while a run is open, lets the user pin useful transcripts, prunes unpinned local transcripts after a configurable window, and keeps durable artifact links / usage totals / outcome summaries longer than raw transcripts. Cloud/API mode requires a separate retention and data-processing decision before multi-tenant use.

### I. The cockpit moves ahead of Notify Cloud for near-term focus

This thread moves **ahead of Notify Cloud (PDR-0002)** for near-term focus. Notify Cloud is not cancelled and remains a valid commercial product; it moves behind the cockpit v1 slice until the cockpit either proves useful or trips a kill criterion (see Risks / Kill Criteria). The cockpit's forcing function is stronger: real developer pain at the operator's day job, immediate HoneyDrunk operating value, direct fit with an AI-heavy Grid, an easier dogfooding loop than a public notification SaaS, and clearer differentiation than another notification API.

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

```
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

| Tier | Audience | Capabilities | Packaging intent |
|------|----------|--------------|------------------|
| **Solo / Operator** | HoneyDrunk solo operation (mobile-first) | Full session control, notifications, mid-run control, artifact links, advisory usage hints, local transcript store | First dogfooding tier; operator-controlled HoneyHub store; not a paid tier |
| **Individual** | Single developer (desktop-first) | Everything in Solo plus personal usage analytics, model/thinking-level recommendations, stale-session/split-task warnings, personal policy budgets (advisory) | The first **commercial** tier — per-seat; local bridge install; warning-only governance |
| **Team / Org** *(later)* | Multiple developers under shared policy | Cross-user **metadata** aggregation, admin model allowlists, expensive-mode approval thresholds, new-session rules, opt-in enforcement | Later tier; gated on privacy decision + reliable capability detection; admin/seat pricing |
| **Cloud/API** *(later provider, any tier)* | Exact accounting / unattended / multi-tenant | Same session model over provider APIs/hosted workers; exact token/cost accounting; enables hard enforcement | Separate retention + data-processing decision before multi-tenant use |

**Positioning:** not "another notification API" and not "an internal HoneyDrunk tool" — a **mobile-first cockpit and usage-governance layer for local AI coding agents**. The wedge is governance + control + monitoring of tools developers already pay for, dogfooded on the operator's real day-job usage before it is sold.

### What changes / does not change for the operator

- **Changes:** a single mobile-first surface to start/watch/interrupt/govern local agent sessions; notifications when a run needs input or finishes; usage visibility on the operator's own AI spend; the dispatch substrate that the later PDR-0009 workspace will reuse.
- **Does not change:** coding stays in the IDE; the packet → PR → review → merge discipline holds; the Architecture repo remains the source of truth; every cockpit mutation lands as a reviewable PR.

---

## What Does NOT Change

- **PDR-0001's external-platform thesis and fidelity-tier model** — intact; the cockpit is the v1 wedge under it.
- **PDR-0009 in substance** — not superseded; its structural backend, composition model, per-Node shell, products-via-same-shell, and PRs-as-artifacts boundary all stand as the *later* HoneyHub layer.
- **PDR-0002 Notify Cloud** — not cancelled; re-sequenced behind the cockpit for near-term focus, resumes priority if the cockpit trips a kill criterion.
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

- If the local bridge cannot reliably stream messages, accept replies, and stop/redirect sessions for **at least one** of Codex or Claude Code, reduce scope to read-only session launch/logging before building governance.
- If exact usage metrics are unavailable locally **and** estimates are too noisy to drive useful recommendations, keep enforcement disabled in local mode and limit governance to warnings until API/cloud mode exists.
- If individual developers will not install a local bridge, reposition the desktop experience as cloud/API-only and keep local mode as HoneyDrunk/operator tooling.
- If the cockpit does not reduce session switching and follow-up latency for HoneyDrunk within **two weeks** of dogfooding, return HoneyHub to the PDR-0009 read-only-workspace path and demote this thread back behind Notify Cloud.

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
