# PDR-DRAFT: Agent Cockpit and Usage Governance

**Status:** Draft
**Date:** 2026-06-06
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform
**Related:** [PDR-0001](../../pdrs/PDR-0001-honeyhub-platform-observation-and-ai-routing.md), [PDR-0009](../../pdrs/PDR-0009-honeyhub-as-internal-daily-driver-workspace.md), [PDR-0010](../../pdrs/PDR-0010-agent-action-ledger-hosted-forensic-record-for-ai-agents.md)

---

## Context

PDR-0009 frames HoneyHub as the operator's internal daily-driver workspace over the Architecture repo, and names the agent-dispatch service as a follow-up. The original v1 shape was an internal cockpit: read Architecture state, start agent work, and capture outputs as PRs or packets.

The product signal has widened. The operator's day-job environment has a concrete pain point: developers using AI coding assistants spend too many tokens, choose the wrong model or thinking level for the task, keep stale sessions alive across unrelated work, and lack one place to control local Codex, Claude Code, and Copilot-like workflows. This is not just HoneyDrunk operator convenience. It is an immediately legible team/product problem.

HoneyDrunk itself is also heavily AI-operated. A cockpit that controls local agent sessions, preserves transcripts, streams progress, notifies when input is needed, and records usage/governance signals would improve the Grid's own operating loop while creating a product wedge that can be tested with real workplace pain before Notify Cloud reaches commercial readiness.

---

## Problem Statement

### 1. AI coding work is fragmented across tools

Developers switch between Codex, Claude Code, GitHub Copilot surfaces, terminals, IDEs, browser tabs, and GitHub. Each tool has its own chat, session lifecycle, output surface, and notification behavior. On mobile, the fragmentation is worse: it is hard to monitor work, answer questions, interrupt, or redirect a run without being in the right app at the right moment.

### 2. Token and model usage lacks operational governance

Teams adopting AI coding tools often lack a practical policy layer for:

- which model or thinking level is appropriate for a task,
- when to start a new session,
- when a high-cost mode needs approval,
- how much context a session has accumulated,
- whether a session is producing useful artifacts,
- which developers, repos, task types, or tools drive usage.

Exact token data is easiest when execution goes through provider APIs. Local subscription-backed tools may expose less precise accounting. Even then, a cockpit can track useful proxies: prompt/response size estimates, session duration, turn count, file/diff size, commands run, model/tool labels, artifacts produced, and outcome signals.

### 3. HoneyHub's dispatch work needs a sharper product frame

If the agent-dispatch service is treated only as an internal HoneyHub helper, the design may underweight chat UX, mobile notifications, session control, usage analytics, and team policy. Those are the features that turn dispatch from "run a command" into a product.

---

## Decision

### A. Agent Cockpit becomes a first-class HoneyHub product thread

HoneyHub gains a near-term product thread: **Agent Cockpit and Usage Governance**.

The first product promise is:

> One web surface to start, watch, interrupt, and govern local AI coding-agent sessions, with mobile-first controls for HoneyDrunk solo operation and desktop-first controls for individual developers.

This does not replace PDR-0009. It specializes its dispatch follow-up into a stronger product shape. PDR-0009 remains the internal-daily-driver frame; this PDR makes the local agent cockpit and usage-governance layer the first buildable slice.

### B. The app is web/PWA plus local runner bridge

The main UI is a responsive web app / PWA:

- **Mobile-first for HoneyDrunk solo operation**: session list, chat view, notifications, run status, PR/packet links, quick interrupt/redirect controls.
- **Desktop-first for individual developers**: chat plus workspace context, usage analytics, policy hints, session history, and local run controls.

A local runner bridge runs on each developer machine or runner host. It starts and controls local tools:

- Codex local sessions,
- Claude Code local sessions,
- Copilot-compatible workflows where an approved local interface exists,
- git and GitHub CLI operations needed to produce artifacts.

The bridge owns local machine access. The web app owns session UX, policy, analytics, notifications, and run records.

### C. One session uses one agent backend

v1 does not attempt multi-agent group chat. A session is bound to one backend:

- `Codex local`
- `Claude Code local`
- future `Cloud/API Codex`
- future `Cloud/API Claude`
- future `Copilot-compatible local workflow`

The user can have multiple sessions, but each session has a clear backend. This keeps transcripts, approvals, usage estimates, and tool permissions understandable.

### D. Chat-shaped dispatch is the v1 interaction model

The user experience is a chat-like run screen:

1. User starts a session with a task.
2. The local bridge starts the selected agent backend.
3. Agent text, progress updates, questions, and summaries stream into HoneyHub.
4. User can reply, redirect, stop, or resume from HoneyHub.
5. The session records produced artifacts: branch, diff, PR, packet, ADR/PDR draft, report, or failure note.
6. HoneyHub notifies on `needs input`, `completed`, `failed`, and `PR opened`.

If a backend supports a stable interactive protocol, the bridge keeps one live process/session. If not, the bridge approximates continuity by launching follow-up invocations with transcript, run metadata, and workspace context.

### E. Usage governance is product-critical, not an afterthought

The cockpit tracks and recommends:

- model/tool selection by task type,
- thinking-level selection where the backend exposes it,
- estimated token usage and exact usage when available,
- session age and context size,
- stale-session warnings,
- "start a new session" suggestions,
- "split this task" suggestions,
- expensive-mode approval prompts,
- reusable automation candidates,
- outcome quality proxies such as PR opened, tests passed, review comments, and rework loops.

Individual desktop mode adds stronger personal policy guidance:

- personal or company-provided model/tool recommendations,
- max session duration,
- max estimated token budget per session,
- expensive-mode warnings,
- required new session per issue/PR,
- warning-only posture,
- per-repo and per-task-type personal analytics.

Cross-user team/org governance is a later product layer. It may aggregate metadata across developers and provide admin controls, but it is not part of the first build target.

### F. Local-first now, cloud/API provider later

The first implementation provider is local:

```
HoneyHub web/PWA -> local runner bridge -> local Codex / Claude Code / git / gh
```

Cloud/API execution is a later provider using the same session/run contract:

```
HoneyHub web/PWA -> cloud dispatch provider -> provider APIs / hosted workers
```

Cloud/API mode is the clean path for exact token/cost accounting, unattended jobs, enterprise audit, and multi-tenant SaaS. Local mode is the right v1 because it uses existing subscriptions, existing repo checkouts, and the tools developers already run.

### G. Data minimization is part of the product shape

Agent Cockpit must treat transcripts, prompts, filenames, command lines, diff metadata, and usage signals as sensitive by default.

V1 storage posture:

- Solo / HoneyDrunk mode may store full transcripts locally or in the operator-controlled HoneyHub store.
- Individual desktop mode defaults to local transcript storage with explicit user control over what syncs.
- Usage analytics should prefer metadata and summaries over raw prompt/code content.
- File paths may reveal sensitive project structure; store repo-relative paths only when needed for artifact navigation.
- Command lines may contain secrets; redact known secret patterns and allow users to hide command detail from synced views.
- Diff metadata should start as counts and links, not copied code hunks.
- Notifications must carry status and links, not prompt text, code, secrets, stack traces, or full file paths.
- Future team/org mode starts metadata-only unless a separate privacy decision explicitly allows transcript sharing.

Retention posture:

- Keep active session transcripts while a run is open.
- Let the user pin transcripts that remain useful.
- Default to pruning unpinned local transcripts after a configurable window.
- Keep durable artifact links, usage totals, and outcome summaries longer than raw transcripts.
- Cloud/API mode requires a separate retention and data-processing decision before multi-tenant use.

### H. Priority changes if this PDR is accepted

This thread should move ahead of Notify Cloud for near-term focus if accepted.

Reason: Notify Cloud is still a valid product thread, but Agent Cockpit has a more immediate forcing function:

- real developer pain at the operator's day job,
- immediate HoneyDrunk operating value,
- direct fit with an AI-heavy Grid,
- easier dogfooding loop than a public notification SaaS,
- clearer differentiation than another notification API.

Notify Cloud should not be cancelled. It should move behind the Agent Cockpit v1 slice until the cockpit either proves useful or fails its kill criteria.

---

## Options Evaluated

### Option A: Keep HoneyHub as Architecture-repo UI only

**Pros**
- Smallest scope.
- Directly improves HoneyDrunk internal operation.
- Avoids tool-integration complexity.

**Cons**
- Misses the workplace pain point.
- Leaves token/model governance unsolved.
- Agent dispatch becomes a thin command launcher rather than a product.

**Verdict:** Rejected as the primary v1. Keep the read-only Architecture index as a supporting feature, not the product center.

### Option B: Build a native desktop app

**Pros**
- Direct machine access.
- Natural fit for laptop/desktop developers.
- Easier tray and local process management.

**Cons**
- Weak fit for the operator's mobile-first HoneyDrunk workflow.
- Packaging burden across platforms.
- Team analytics still need a web dashboard.

**Verdict:** Rejected for v1. A small local bridge may have desktop packaging later, but the main product is web/PWA.

### Option C: Build a mobile-first web/PWA with local bridge

**Pros**
- Works for HoneyDrunk mobile operation.
- Works for team desktop usage via responsive layout.
- Keeps local tool access in a trusted local process.
- Gives one UI for sessions, notifications, and governance.
- Can later wrap into native shells if needed.

**Cons**
- Requires secure bridge pairing and relay design.
- Browser cannot directly run local CLIs.
- Local subscription-backed tools may not expose exact token metrics.

**Verdict:** Selected.

### Option D: Go API/cloud-first

**Pros**
- Exact token/cost accounting.
- Cleaner central governance.
- Better unattended automation.

**Cons**
- Higher cost and auth complexity.
- Does not reuse developers' existing local subscriptions.
- Slower path to HoneyDrunk mobile dogfooding.

**Verdict:** Defer. Cloud/API is a second provider, not v1.

---

## v1 Product Shape

### Solo / HoneyDrunk Mode

- Mobile-first PWA.
- Local bridge on the operator's home/dev machine or ADR-0086 runner host.
- Session list with status and backend labels.
- Chat-shaped run view.
- Notifications for input/completion/failure.
- Artifact links to branches, PRs, packets, reports, and drafts.
- Quick controls: stop, redirect, summarize, open PR, start follow-up session.

### Individual Desktop Mode

- Desktop web cockpit for developers.
- Local bridge installed on the developer machine.
- Session controls for Codex, Claude Code, and approved workflows.
- Personal usage analytics dashboard.
- Model/tool/thinking-level recommendations.
- Stale-session and split-task warnings.
- Per-repo and per-task-type usage reporting for the current user.

### Future Team / Org Mode

- Multiple developers each run their own local bridge.
- A central dashboard aggregates metadata across users, repos, task types, and tools.
- Admins configure model allowlists, expensive-mode approval thresholds, new-session rules, and enforcement posture.
- Transcript/content retention is a separate privacy and security decision; metadata-only aggregation should be the default starting point.

### Shared Concepts

| Concept | Meaning |
|---|---|
| `AgentBackend` | Codex local, Claude Code local, future cloud/API providers, or approved Copilot-compatible workflow |
| `DispatchSession` | One chat-shaped conversation/run bound to one backend |
| `DispatchRun` | One execution attempt within a session, with status and artifacts |
| `Artifact` | Branch, diff, PR, work item, ADR/PDR draft, report, or failure note |
| `UsageSignal` | Exact or estimated usage/cost/context metric |
| `PolicyHint` | Recommendation or warning surfaced before/during a session |

---

## Follow-Up Artifacts

| Artifact | Type | Purpose |
|---|---|---|
| Agent cockpit local-runner bridge | ADR | Placement, auth, pairing, process control, transcript streaming, interruption, artifact contract |
| Session and usage telemetry model | ADR | `DispatchSession`, `DispatchRun`, `UsageSignal`, policy hints, exact-vs-estimated accounting |
| Mobile-first cockpit UX spec | Design doc | Session list, chat run view, notifications, artifacts, mobile and desktop layouts |
| Individual desktop usage guidance | Design doc | Personal analytics, model/thinking-level hints, stale-session warnings, split-task recommendations |
| Team policy and governance model | ADR/PDR | Future admin controls, model allowlists, thinking-level policy, approval thresholds, enforcement posture, privacy boundaries |
| Cloud/API dispatch provider | ADR | API-key/service-account execution, exact token/cost accounting, hosted worker security, multi-tenant concerns |
| Copilot-compatible workflow assessment | Research note | Determine which Copilot surfaces can be controlled locally or via supported APIs without violating tool boundaries |

---

## Kill Criteria

- If the local bridge cannot reliably stream messages, accept replies, and stop/redirect sessions for at least one of Codex or Claude Code, reduce scope to read-only session launch/logging before building governance.
- If exact usage metrics are unavailable locally and estimates are too noisy to drive useful recommendations, keep enforcement disabled in local mode and limit governance to warnings until API/cloud mode exists.
- If individual developers will not install a local bridge, reposition the desktop experience as cloud/API-only and keep local mode as HoneyDrunk/operator tooling.
- If the cockpit does not reduce session switching and follow-up latency for HoneyDrunk within two weeks of dogfooding, return HoneyHub to the PDR-0009 read-only workspace path and demote this thread behind Notify Cloud.

---

## Immediate Recommendation

Promote this draft into a formal PDR and make it the top near-term HoneyHub product slice. The first implementation decision should be the local-runner bridge ADR, explicitly mobile-first and session-based.

Notify Cloud remains valuable, but this thread has the clearer immediate forcing function and the stronger HoneyDrunk dogfooding loop.
