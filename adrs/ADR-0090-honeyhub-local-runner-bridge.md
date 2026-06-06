# ADR-0090: HoneyHub Local Runner Bridge for Agent Cockpit Sessions

**Status:** Proposed
**Date:** 2026-06-06
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform
**Implements:** [PDR-0011](../pdrs/PDR-0011-honeyhub-v1-agent-cockpit-and-usage-governance.md) (HoneyHub v1 — Agent Cockpit) §"Architecture Implications" bridge contract.
**Relationships:** Re-sequences the [PDR-0009](../pdrs/PDR-0009-honeyhub-as-internal-daily-driver-workspace.md) §G dispatch question; builds on the [ADR-0086](ADR-0086-pull-based-local-worker-grid-review-runner.md) local-worker substrate; distinct from ADR-0003 (HoneyHub control plane). Tracked in the [HoneyHub program](../initiatives/programs/honeyhub.md). Promoted from the feasibility-spike-validated `../generated/adr-drafts/ADR-DRAFT-honeyhub-local-runner-bridge.md` (see Appendix).

---

## Context

The Agent Cockpit product direction needs a local-first execution path. The operator works from mobile for HoneyDrunk, while day-job developers work from laptops/desktops. In both cases, the agent work itself needs local machine access: checked-out repos, git, GitHub CLI auth, local Codex/Claude Code sessions, existing subscriptions, local tools, and developer-specific environment.

A pure web app cannot safely launch local CLIs or inspect local repos. A desktop-only app underserves the mobile-first HoneyDrunk workflow, while cross-user team analytics would still need a web surface later. The proposed shape is therefore:

```
HoneyHub web/PWA -> secure local runner bridge -> local agent tools / git / gh
```

This ADR decides the bridge boundary and session contract. It does **not** decide the final hosted HoneyHub app stack or UI framework — those are the separate **app-stack ADR** (PDR-0011 §6; tracked in the HoneyHub program's dependency map). It **does** establish the `[Firm]` cloud-execution / subscription-auth boundary (D10).

---

## Decision

### D1. HoneyHub uses a local runner bridge for v1 agent execution

The v1 execution provider is a small local service, installed on a developer machine or runner host, that can start and control approved local tools.

The bridge owns:

- process launch and lifecycle,
- workspace/repo path access,
- backend adapter invocation,
- streaming stdout/stderr or structured events into HoneyHub,
- accepting user replies or control commands from HoneyHub,
- artifact detection and reporting,
- local run logs,
- secure pairing with HoneyHub.

HoneyHub owns:

- mobile/desktop session UI,
- transcript display,
- run status,
- notifications,
- policy hints,
- usage analytics,
- artifact links,
- team/admin configuration.

### D2. One session binds to one backend

A `DispatchSession` is bound to exactly one `AgentBackend`.

Initial backend classes:

| Backend | Mode | Notes |
|---|---|---|
| `codex.local` | Local CLI/session | Uses the developer's local Codex auth/session where supported. |
| `claude.local` | Local CLI/session | Uses the developer's local Claude Code auth/session where supported. |
| `copilot.local` | Local workflow adapter | Allowed only where there is a supported local interface; no unsupported automation of IDE UI. |
| `codex.api` | Future cloud/API provider | Exact token/cost accounting; not v1. |
| `claude.api` | Future cloud/API provider | Exact token/cost accounting; not v1. |

No v1 multi-agent room. A user can run multiple sessions, but each transcript is labeled by backend and uses that backend's capabilities.

### D3. Session model

HoneyHub records:

| Entity | Purpose |
|---|---|
| `DispatchSession` | User-facing conversation/control container. |
| `DispatchRun` | One execution attempt inside a session. |
| `DispatchMessage` | User/agent/system message, streamed or final. |
| `DispatchControlEvent` | Stop, pause, resume, redirect, approve, reject, timeout. |
| `DispatchArtifact` | Branch, diff, PR, issue packet, ADR/PDR draft, report, log bundle. |
| `UsageSignal` | Exact or estimated usage, cost, context, duration, turn count, model/tool label. |
| `PolicyHint` | Recommendation, warning, or block reason. |

Run state:

```
created -> queued -> starting -> running -> needs_input -> finalizing -> completed
                                    |             |             |
                                    v             v             v
                                  stopping      failed        cancelled
```

### D4. Chat-shaped control is required

The bridge must support the HoneyHub run screen:

- stream agent-visible messages/progress to HoneyHub,
- surface explicit questions as `needs_input`,
- accept user replies,
- support stop/cancel,
- support follow-up messages after completion,
- report artifacts as they appear.

Backends declare capabilities. The bridge must not pretend a backend supports live interaction if it only supports one-shot commands.

Capability flags:

| Flag | Meaning |
|---|---|
| `streaming_output` | Backend emits incremental text/events. |
| `interactive_reply` | Backend can receive a reply into the same live process/session. |
| `resume_session` | Backend can resume a previous session by id or transcript. |
| `stop_signal` | Backend supports graceful cancellation. |
| `structured_events` | Backend emits machine-readable status/events. |
| `usage_exact` | Backend exposes exact token/cost usage. |
| `usage_estimated` | HoneyHub estimates usage from text/runtime proxies. |

If `interactive_reply=false`, HoneyHub can still present a chat UX by starting a follow-up run with prior transcript, run metadata, and workspace context.

### D5. Local usage accounting starts estimated, exact when available

Local subscription-backed tools may not expose exact token/cost usage consistently. The bridge and HoneyHub therefore separate exact from estimated signals.

Estimated local signals:

- prompt character/token estimate,
- response character/token estimate,
- turn count,
- elapsed time,
- backend/tool label,
- selected model/thinking label when visible,
- repository and task type,
- files touched,
- diff size,
- commands run,
- tests/checks run,
- PR opened / review outcome / rework loop count.

Exact signals are recorded only when a backend exposes them through a supported interface. API/cloud providers are expected to provide exact usage and cost.

### D6. Policy hints are advisory in local v1

The v1 local bridge may warn but should not hard-block by default.

Examples:

- "Start a new session; this run has crossed the configured turn/context threshold."
- "Use a cheaper/faster backend for discovery-only work."
- "Split this into planning and implementation runs."
- "High-thinking mode requested for low-risk docs work."
- "This task should become an automation/template."

Individual desktop mode uses the same warnings, just with more screen space for personal analytics and run history. Cross-user team/org mode can later enable enforcement for org policy, but enforcement requires administrator opt-in, privacy decisions, and reliable backend capability detection.

### D7. Notifications are part of the run contract

HoneyHub emits notifications for:

- `needs_input`,
- `completed`,
- `failed`,
- `cancelled`,
- `PR opened`,
- `policy approval required` once enforcement exists.

Notification transports are outside this ADR's primary decision. Initial transports may include web push, Discord, or existing ADR-0084 alert-routing paths. The bridge reports state; HoneyHub decides how to notify.

### D8. Pairing and trust

The local bridge is trusted code running on the developer machine. Pairing must be explicit.

Minimum posture:

- user-initiated pairing flow from HoneyHub,
- per-device bridge identity,
- revocable token,
- local allowlist of workspace roots,
- backend allowlist,
- no secret values streamed into HoneyHub transcripts,
- bridge refuses paths outside configured roots,
- all process launches recorded as `DispatchRun` events.

For solo HoneyDrunk use, the bridge may run on the operator's dev machine or ADR-0086 runner host. For individual desktop use, the bridge runs on the developer's own machine. Future team dashboards aggregate metadata from multiple bridges, not raw local filesystem access.

### D9. Artifacts are the write boundary

The bridge does not directly mutate authoritative Architecture state on behalf of HoneyHub.

Accepted output artifacts:

- branch and commit,
- pull request,
- generated issue packet,
- generated ADR/PDR draft,
- report,
- failure note.

This preserves the PDR-0009 PRs-as-artifacts boundary. Direct writes to catalogs, ADRs, or code are only meaningful inside a git branch that becomes reviewable.

### D10. Cloud/API dispatch is a provider extension

Cloud/API execution uses the same `DispatchSession` / `DispatchRun` / `UsageSignal` model. It differs only in provider adapter and auth model.

**`[Firm]` — Cloud/hosted execution is BYO-API-key only; it MUST NEVER authenticate with a vendor subscription token.** Local execution drives each vendor's *official* CLI under the user's own local session (within ToS — the official CLI is fine even on a remote server the user themselves controls). The moment the official CLI runs on *HoneyDrunk's* hosted worker against a *user's subscription*, that re-creates the exact third-party-subscription-auth shape the Grid decommissioned in [ADR-0088](ADR-0088-decommission-openclaw-from-the-grid.md) (the OpenClaw teardown). HoneyHub therefore never holds, stores, or proxies subscription auth; hosted execution uses sanctioned per-token API keys only. This boundary is non-negotiable, not a default.

Cloud/API provider work is deferred until local v1 proves:

- chat-shaped control is useful,
- sessions produce reviewable artifacts,
- usage hints improve behavior,
- individual users or future teams want exact accounting or unattended execution enough to justify API cost.

### D11. Data classification and retention

The local bridge and HoneyHub must classify session data before storing or syncing it.

| Data | Default classification | V1 handling |
|---|---|---|
| User prompts and agent replies | Sensitive work content | Store locally by default; sync only when the user enables it for the session or workspace. |
| Source snippets and diff hunks | Sensitive code content | Do not copy into central analytics by default; link to local branch/PR artifacts instead. |
| File paths | Potentially sensitive metadata | Prefer repo-relative paths; avoid absolute local paths in synced records. |
| Command lines | Potentially secret-bearing metadata | Redact known secret patterns; allow command detail suppression in synced views. |
| Tool stdout/stderr | Sensitive work content | Stream to the active user; retain locally unless explicitly pinned or attached to an artifact. |
| Usage estimates | Operational metadata | Safe to aggregate for the current user; team aggregation is future work and metadata-only by default. |
| Exact provider usage/cost | Operational / billing metadata | Store when available; do not attach raw prompt/code content to cost records. |
| Notifications | Low-detail operational metadata | Include status, backend, repo, and link; exclude prompt text, code, secrets, stack traces, and full paths. |

Default retention:

- Active sessions retain transcript and stream logs until completion.
- Completed sessions keep a local transcript for a configurable window unless pinned.
- Durable HoneyHub records keep run status, backend, repo, artifact links, usage totals, and outcome summaries.
- Future team/org dashboards aggregate metadata, not transcripts, unless a later privacy/security decision changes that posture.

---

## Consequences

### Positive

- HoneyHub can become the phone/desktop surface for local Codex and Claude sessions without replacing those tools.
- Mobile HoneyDrunk operation gains notifications and mid-run control.
- Future team/org mode gets a path to governance without forcing API-first execution.
- The same session model supports local and future cloud/API providers.
- Usage analytics can start with estimates and become exact where providers expose data.

### Negative

- Local bridge packaging, updates, and pairing become product surface area.
- CLI adapters may be brittle if tool interfaces are not stable.
- Exact usage/cost data may be unavailable in local mode.
- Remote mobile control requires a secure relay or network path to the bridge.
- Governance quality depends on backend capability detection and honest limits.

---

## Alternatives Considered

### Pure web app

Rejected. It cannot safely launch local tools, inspect local repos, or reuse local CLI auth sessions.

### Desktop app only

Rejected for v1. It fits day-job developers but not the operator's mobile-first HoneyDrunk workflow. The bridge may later ship with tray/desktop packaging, but the main UI remains web/PWA.

### API/cloud-first execution

Deferred. It gives cleaner accounting but adds cost, auth, tenancy, and hosted-worker security before the core UX is proven.

### One unified multi-agent chat room

Rejected for v1. The product need is session control, not multi-agent theater. One session maps to one backend.

---

## Follow-Up Work

- Define the wire protocol between HoneyHub and the local bridge.
- Decide local bridge implementation home and packaging.
- Define `DispatchSession` storage and retention.
- Define bridge pairing, revocation, and workspace-root allowlisting.
- Prototype `codex.local` backend adapter.
- Prototype `claude.local` backend adapter.
- Define usage-estimation heuristics and confidence levels.
- Define mobile notification path.
- Draft team policy model for warning/enforcement posture.

---

## Open Questions

| Question | Owner | Status |
|---|---|---|
| Does the first bridge live inside an existing HoneyHub repo, a new repo, or an ADR-0086 runner package? | Architecture | **Deferred to the app-stack ADR** (PDR-0011 §6) |
| What is the minimum supported remote-control path for mobile: same LAN, Tailscale, cloud relay, or hosted HoneyHub tunnel? | Architecture / Ops | **Partly answered (spike)** — Claude Code (`--remote-control`) and Copilot (`--remote`/`--connect`) ship native remote-session control; LAN/Tailscale/relay choice still open for the app-stack ADR |
| Which Codex and Claude Code interfaces are stable enough for v1 adapters? | Architecture / Product | **Answered (spike)** — all three official CLIs drive stream/reply/stop/resume/usage today (see Appendix) |
| How much transcript content should team dashboards store versus summarize? | Product / Security | Open (v2 / team) |
| Which usage signals are acceptable in individual desktop mode if source code and prompts are sensitive? | Product / Security | Open |
| What metadata, if any, should future team/org mode aggregate across users? | Product / Security | Open (v2 / team) |

---

## Decision Ledger

Per the HoneyHub flexibility posture (PDR-0011 Amendment §7), each decision is tagged `[Firm]` or `[Provisional]`.

- **`[Firm]`** — do not move without a real new decision:
  - the bridge drives each vendor's **official CLI under the user's own local session**; HoneyHub never holds/stores/proxies subscription auth (D8);
  - **cloud/hosted execution is BYO-API-key only, never a subscription token** (D10);
  - **artifacts are the write boundary** — no direct mutation of authoritative state outside a reviewable git branch / PR (D9; PRs-as-artifacts inherited from PDR-0009 §D);
  - **honest capability flags** — the bridge never fakes live interaction a backend lacks (D4);
  - **state-only notifications** — status/backend/repo/link only, never prompt text/code/secrets (D7);
  - **local-first data default** with per-session/workspace opt-in sync (D11).
- **`[Provisional]`** — working assumptions, revise on signal: the wire protocol; bridge packaging/home; backend order and which interface backs each adapter; usage-estimation heuristics; the mobile relay mechanism; run-state-machine details.

Provisional decisions change by a conversation + an amendment note here (no new ADR) as long as no `[Firm]` line is crossed.

---

## Appendix: Feasibility Spike (2026-06-06)

A throwaway spike validated the full bridge contract against all three backends, each driven via its official CLI under the user's own local auth (the `[Firm]` ToS-clean path). The D4 capability flags are **observed, not assumed**.

| Capability | Claude Code | Codex | Copilot |
|---|---|---|---|
| streaming_output | token-level (`stream_event`) | message-level (`item.completed`) | token-level (`assistant.message_delta`) |
| interactive_reply | same-process live | resume-based | resume-based |
| stop_signal | ✓ | ✓ | ✓ |
| resume_session (+ memory) | ✓ | ✓ | ✓ |
| usage | exact tokens **+ USD** | exact tokens (no USD) | premium-requests + duration only |
| auth (this machine) | local subscription session | ChatGPT (local) | gh token (local) |

Findings that shaped this ADR: (1) the buildable path **is** the ToS-clean path (official CLIs, local session); (2) `UsageSignal` must normalize three usage shapes (exact-USD / exact-tokens / premium-requests) — validating the estimated-vs-exact split in D5; (3) `interactive_reply` is same-process for Claude Code, resume-based for Codex/Copilot — both covered by the D4 capability flags + the follow-up-run model; (4) Claude Code and Copilot ship native remote-session control — a candidate answer to the mobile-path question; (5) Copilot's CLI runs `claude-sonnet-4.6` under the hood — a separate billing bucket over a shared model.
