---
name: Claude Code Adapter
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["feature", "tier-2", "honeyhub", "adr-0090", "wave-5"]
dependencies: ["packet:04", "packet:05"]
adrs: ["ADR-0090", "ADR-0091", "ADR-0092"]
source: human
generator: scope
wave: 5
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Feature: Claude Code backend adapter — drive the official Claude Code CLI under the user's own local auth

## Summary
Implement the first `AgentBackendAdapter` (`claude.local`) against the official Claude Code CLI, driven locally under the user's own local session — the `[Firm]` ToS-clean path. Per the ADR-0090 feasibility spike, Claude Code is the cleanest backend: token-level `streaming_output`, same-process `interactive_reply`, native `stop_signal` and `resume_session`, and **exact tokens + USD** usage. This adapter implements `start`/`stream`/`reply`/`stop`/`resume` and emits `UsageSignal`s with `fidelity: exact` (tokens and USD taken directly, no computation).

This is the one backend for Phase 2 (the first shippable slice). Codex and Copilot adapters are Phase 3+ (outlined, not scoped here).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub` (`crates/bridge` — a `claude_local` adapter implementing the packet-04 trait).

## Motivation
ADR-0090 D2 names `claude.local` as a v1 backend: "Uses the developer's local Claude Code auth/session where supported." The spike (ADR-0090 Appendix) observed Claude Code's capability profile as the richest of the three — same-process live interaction and exact USD usage — making it "the cleanest per the spike" and the right first adapter. Packet 04 shipped the backend-agnostic core and the `AgentBackendAdapter` trait; packet 05 shipped pairing + the allowlist; this packet makes the cockpit actually drive a real agent.

The spike-observed capability profile for Claude Code (ADR-0090 Appendix), which this adapter must declare honestly:
- `streaming_output`: token-level (`stream_event`)
- `interactive_reply`: same-process live
- `stop_signal`: yes
- `resume_session` (+ memory): yes
- usage: **exact tokens + USD**
- auth (this machine): local subscription session

## Proposed Implementation

### Declare the spike-observed capabilities
`capabilities()` returns: `streaming_output: true`, `interactive_reply: true`, `resume_session: true`, `stop_signal: true`, `structured_events: true`, `usage_exact: true`, `usage_estimated: false`. These are **observed, not assumed** (the spike validated them). Because `interactive_reply` is true, the core routes replies into the live process (not the follow-up-run path).

### Drive the official CLI under the user's own local session (`[Firm]`)
- Launch the **official Claude Code CLI** in a streaming/headless mode that emits structured `stream_event`s, under the developer's own local auth (the local subscription session). The bridge **never** holds, stores, or proxies that subscription auth (ADR-0090 D10 `[Firm]`) — it shells out to the official CLI, which uses the user's own local session.
- Parse the CLI's structured events into the core's `BridgeEvent`s: incremental assistant text → `DispatchMessage` stream; explicit questions → `needs_input`; tool/command activity → control events; artifacts (branch/PR/diff) → `DispatchArtifact` (metadata + links only, per D11 — not copied hunks).
- `reply(run, text)`: send the user reply into the same live process (same-process interactive).
- `stop(run)`: invoke the CLI's graceful cancellation.
- `resume(session)`: resume a prior Claude Code session by id/transcript (the CLI supports it + memory).

### CLI invocation contract (the spike-proven mechanism the Rust adapter must reproduce)
The ADR-0090 feasibility-spike validated this exact mechanism (the spike used Node's `child_process` as the harness; the Rust adapter mirrors it via `std::process`/`tokio::process`). Reproduce it concretely:

- **Launch** the official `claude` CLI as a **long-lived child process** in streaming JSON mode:
  ```
  claude -p --output-format stream-json --input-format stream-json --include-partial-messages --verbose [--model <m>]
  ```
  (`--model` optional.) The process stays alive for the whole session; do not spawn one CLI per turn.
- **Send user messages** as **line-delimited JSON written to the child's stdin**, one object per line:
  ```json
  {"type":"user","message":{"role":"user","content":"..."}}
  ```
  **Keep stdin OPEN** after writing — an open stdin is what enables **same-process `interactive_reply`** (a reply is just another `user` line written to the still-open stdin of the live process; no resume needed). Closing stdin ends the input channel.
- **Read events** from the child's **stdout as JSONL** (one JSON event per line), and map them to `BridgeEvent`s:
  - `stream_event` / `content_block_delta` → token deltas (the live `DispatchMessage` token stream);
  - `assistant` → per-turn assistant text (a completed turn's message);
  - `result` → the turn/session result event, which carries **`session_id`**, **`usage`** (input / output / cache-read / cache-creation tokens), and **`total_cost_usd`** — this is the source of the exact-tokens + exact-USD `UsageSignal` (taken directly, no computation; see below).
- **`stop()`** = **kill the child process** (SIGKILL on POSIX; `taskkill /T` to kill the process tree on Windows) — record the outcome as a control event and transition the run.
- **`resume()`** = a **fresh** `claude -p -r <session_id> ...` invocation (a new child process resuming the prior session by the `session_id` captured from the `result` event), not a write into a dead process.

Cite the **ADR-0090 spike appendix** as the Node `child_process` analog this Rust harness mirrors (the appendix recorded Claude Code as `streaming_output: token-level (stream_event)`, `interactive_reply: same-process live`, `stop`/`resume` ✓, `usage: exact tokens + USD`). **Codex and Copilot use resume-based multi-turn** (their `interactive_reply` is resume-based, not same-process — a reply is a fresh `-r <session_id>` invocation, routed through the core's follow-up-run path); their adapters are Phase 3+ and are not built here.

### UsageSignal emission with `fidelity: exact` (ADR-0092 D2)
- Claude Code exposes **exact tokens + USD**. Emit `UsageSignal`s with `fidelity: exact` for both tokens and USD — **taken directly, no computation** (ADR-0092 D2: "tokens and USD taken directly; no computation"). Do not compute USD from a rate table for this backend (that `derived` path is for Codex, not Claude Code).
- The `UsageSignal` carries the backend label (`claude.local`), tokens, USD, turn count, duration, model/tool label — the exact-usage shape.

### Artifacts as the write boundary (ADR-0090 D9 `[Firm]`)
- When the Claude Code session produces a branch/commit/PR/packet/draft/report, the adapter reports it as a `DispatchArtifact` (metadata + link). The bridge does **not** directly mutate authoritative state — durable output lands only as a reviewable git branch/PR. The adapter detects artifacts; it does not open a direct-write path to catalogs/ADRs/code.
- **PR-open detection ownership (so the `PR opened` notification neither double-fires nor misses):** the **adapter owns detecting a PR-open event** (by parsing it out of the Claude Code CLI output) and emits a single `DispatchArtifact` of kind PR for it. The **store/notification seam (packet 07) owns firing the `PR opened` notification**, triggered by the new PR-artifact row being persisted — it does **not** independently re-parse CLI output. One detector (the adapter), one notifier (the store-observed artifact row): no double-fire, no miss.

### Honest degradation
- If the local Claude Code CLI is unavailable or unauthenticated, the adapter fails the run honestly (`failed` state with a clear reason) — it never fabricates a stream or fakes a capability.

## Acceptance Criteria
- [ ] `capabilities()` returns the spike-observed profile (streaming/interactive_reply/resume/stop/structured_events/usage_exact all true; usage_estimated false).
- [ ] The adapter drives the **official Claude Code CLI** under the user's own local session; the bridge holds/stores/proxies **no** subscription auth (ADR-0090 D10 `[Firm]`).
- [ ] `start`/`stream`/`reply`/`stop`/`resume` all work against a real local Claude Code CLI: a session starts, streams token-level output, surfaces `needs_input`, accepts a same-process reply, stops gracefully, and resumes a prior session.
- [ ] CLI structured events are parsed into the core's `BridgeEvent`s (assistant text → message stream; questions → `needs_input`; artifacts → `DispatchArtifact` metadata+link only).
- [ ] `UsageSignal`s are emitted with `fidelity: exact` for tokens **and** USD, taken directly from the CLI with no rate-table computation.
- [ ] Produced branches/PRs/packets/drafts are reported as `DispatchArtifact`s (metadata + link); the adapter opens no direct-write path to authoritative state.
- [ ] If the CLI is unavailable/unauthenticated, the run fails honestly with a clear reason; no fabricated stream.
- [ ] **PDR-0011 kill-criterion fallback (explicit):** if live `reply`/`stop` cannot be reliably driven against the real Claude Code CLI (per the bringup smoke), the slice reduces to **read-only launch/logging** for this backend — an accepted PDR-0011 exit, not a defect to grind on. The adapter must still deliver the read-only launch/stream/logging path in that case.
- [ ] Tests: a contract test asserting the adapter satisfies the `AgentBackendAdapter` trait and the capability declaration; an integration test against a **live duplex fake `claude` binary** — a test double that **reacts to stdin replies and stop signals** (reads the line-delimited `user` JSON from its stdin and emits a responsive JSONL stream; terminates on kill) — exercising start→stream→needs_input→reply→stop→resume and the exact-USD `result`-event usage emission. **A static recorded fixture is NOT sufficient** for this packet: a recording cannot prove `reply` (the fake must change its output in response to a written reply) or `stop` (the fake must actually terminate on the kill). (A full live real-CLI test is a human-run smoke per Human Prerequisites — see `handoff-phase2-bringup.md`.)
- [ ] `crates/bridge/CHANGELOG.md` + repo-level `CHANGELOG.md` updated (invariants 12, 27); README documents the `claude.local` backend.
- [ ] PR body links the packet (invariant 32) and notes the `[Firm]` ToS-clean local-CLI / no-subscription-auth posture.

## Human Prerequisites
- [ ] The operator/developer has the official **Claude Code CLI installed and authenticated** with their own local subscription session on the bridge host — required to run the live-CLI smoke test. The adapter never stores this auth; it relies on the CLI's own local session.
- [ ] (Smoke) Run one real Claude Code session through the cockpit end-to-end (start → stream → reply → stop → see an artifact) on the operator's machine to validate the adapter against the live CLI — the kill-criterion check from PDR-0011 (if the bridge cannot reliably stream/reply/stop for at least one backend, scope reduces to read-only launch/logging).

## Dependencies
- `packet:04` — the bridge core + the `AgentBackendAdapter` trait this adapter implements.
- `packet:05` — pairing + the workspace-root/backend allowlist must gate launches before a real CLI is driven.

## Agent Handoff
**Objective:** Implement the `claude.local` adapter driving the official Claude Code CLI under the user's own local session, with exact tokens+USD usage and same-process interactive reply.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, `crates/bridge` `claude_local` adapter, branch from `main`.
**Context:**
- Goal: the one backend for Phase 2 — the cleanest per the ADR-0090 spike.
- ADRs: ADR-0090 (D2 backend, D4 capabilities, D9 artifacts, D10 BYOK/no-subscription-auth, Appendix spike profile), ADR-0092 (D2 exact fidelity), ADR-0091 (Rust bridge).

**Acceptance Criteria:** as listed above.

**Dependencies:** packets 04 (core) + 05 (pairing/allowlist).

**Constraints (full text inlined):**
- ADR-0090 D10 `[Firm]`: "Local execution drives each vendor's official CLI under the user's own local session ... HoneyHub therefore never holds, stores, or proxies subscription auth." The adapter shells out to the official Claude Code CLI; it does not capture or forward the subscription token.
- ADR-0090 D4 honest capabilities `[Firm]`: declare only the spike-observed capabilities; never fabricate a stream or fake interaction.
- ADR-0090 D9 artifacts-as-write-boundary `[Firm]`: report produced branches/PRs/packets/drafts as `DispatchArtifact`s (metadata+link); open no direct-write path to authoritative catalogs/ADRs/code.
- ADR-0090 D11: `DispatchArtifact`s carry metadata + links, not copied diff hunks; redact secret patterns from command lines.
- ADR-0092 D2 `[Firm]`: Claude Code usage is `fidelity: exact` for tokens and USD taken directly — no rate-table computation (that `derived` path is Codex-only).

**Key Files:**
- `crates/bridge/src/adapters/claude_local.rs` (new), `crates/bridge/src/adapter.rs` (registration).

**Contracts:**
- Implements `AgentBackendAdapter` (packet 04). Emits `UsageSignal { fidelity: exact, ... }` (ADR-0092 D2 / `shared-types`).
