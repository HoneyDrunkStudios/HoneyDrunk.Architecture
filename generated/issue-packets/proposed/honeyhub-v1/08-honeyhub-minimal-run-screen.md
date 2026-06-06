---
name: Minimal Run Screen
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["feature", "tier-2", "honeyhub", "adr-0091", "wave-6"]
dependencies: ["packet:06", "packet:07"]
adrs: ["ADR-0091", "ADR-0090", "ADR-0092"]
source: human
generator: scope
wave: 6
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Feature: Minimal React PWA run screen — start session, watch stream, reply, stop, see artifacts

## Summary
Implement the minimal chat-shaped run screen in the React+Vite PWA per PDR-0011 Phase 2 and ADR-0090 D4: start a session against the Claude Code backend, watch the live stream, reply to `needs_input`, stop the run, and see produced artifacts (branch/PR/packet links). This is the integration capstone of Phase 2 — it wires the PWA (over the packet-04 wire protocol) to the paired bridge (packet 05), drives the Claude Code adapter (packet 06), and reads the local store + notifications (packet 07). After this packet, the first shippable slice is complete: the operator can drive a real Claude Code session from the cockpit.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub` (`packages/ui` — the `/run` route promoted from packet 03's placeholder).

## Motivation
PDR-0011 Phase 2: "Minimal web/PWA run screen: start session, watch stream, reply, stop, see artifacts. State-only notifications for needs_input / completed / failed / PR opened." ADR-0090 D4 requires the run screen to stream agent-visible messages, surface explicit questions as `needs_input`, accept user replies, support stop/cancel, support follow-up messages after completion, and report artifacts as they appear. Packets 04–07 built the bridge core, pairing, the Claude Code adapter, and the store; this packet is the UI that makes them usable and validates the PDR-0011 kill criterion (does chat-shaped control actually work for one backend).

## Proposed Implementation

### The run screen (`/run`)
A single-session chat-shaped view:
- **Start a session**: pick a workspace root (from the packet-05 allowlist), pick the backend (`claude.local` — the only one at v1), enter the task, start. Connects over the wire protocol with the pairing token.
- **Watch the stream**: render the incremental `DispatchMessage` stream token-level; show the run state (`running`/`needs_input`/`finalizing`/`completed`/etc.) from the run-state machine.
- **Reply**: when the run is `needs_input`, surface the question and let the user reply (same-process for Claude Code per its `interactive_reply` capability); after completion, allow a follow-up message (a new run carrying prior transcript per ADR-0090 D4).
- **Stop**: a stop control that invokes the adapter's graceful cancellation.
- **See artifacts**: render `DispatchArtifact`s (branch/commit/PR/packet/draft/report) as links as they appear — metadata + link only.

### Session list (minimal)
A minimal session list reading the local store (packet 07): sessions with status + backend label + repo, selectable into the run view. Run history (prior runs in a session) and the bridge-settings/pairing UI (packet 05) are reachable but separate.

### Usage display with honest fidelity (ADR-0092 D2 `[Firm]`)
- Show the session's `UsageSignal`s. For the Claude Code backend these are `fidelity: exact` (tokens + USD) — render as exact figures.
- **The UI must visually distinguish exact / derived / estimated and never render an estimate as an exact number** (ADR-0092 D2 `[Firm]` honesty rule). At v1 only the exact (Claude Code) path exists, but build the rendering so a future `derived` (Codex USD) or `estimated` (Copilot tokens) figure shows its band/qualifier (e.g. an "~$" band for estimated) — do not hardcode "exact" presentation.

### Notifications surfacing
- Surface the packet-07 state-only notifications (`needs_input`/`completed`/`failed`/`cancelled`/`PR opened`) in-app (badge/list). No prompt text/code in the notification surface.

### Mobile + desktop, one UI (ADR-0091 D2 `[Firm]`)
- The run screen is the **one shared responsive React UI** — it works mobile-first (HoneyDrunk solo operation) and on desktop, from the same codebase (no separate mobile UI). For Phase 2 the bundled-desktop/localhost path is the primary exercise; the mobile-over-Tailscale path is validated in the relay-bringup (handoff), not blocked here.

### Not in scope (honest boundaries)
- No routing engine, no cost dashboard beyond the per-session usage display, no coaching hints (Phase 3+).
- No code editor, no terminal (`[Firm]` not-an-editor boundary).
- No second/third backend selector beyond `claude.local`.

## Acceptance Criteria
- [ ] A user can start a Claude Code session from the run screen: pick an allowlisted workspace root + backend `claude.local` + task, and start; the PWA connects to the paired bridge over the wire protocol with the pairing token.
- [ ] The run screen renders the live token-level stream and the current run state; `needs_input` surfaces the question.
- [ ] The user can reply to `needs_input` (same-process) and send a follow-up message after completion (new run with prior transcript).
- [ ] A stop control gracefully cancels the run; the UI reflects the `stopping`→`cancelled`/`completed` transition.
- [ ] Produced artifacts (branch/commit/PR/packet/draft/report) render as links (metadata + link only) as they appear.
- [ ] A minimal session list reads the local store and is selectable into the run view.
- [ ] Usage display shows the session's `UsageSignal`s with **fidelity visually distinguished**; the exact (Claude Code) path renders exact tokens+USD; the rendering is built so a future `derived`/`estimated` figure shows its qualifier and is never rendered as an exact number.
- [ ] State-only notifications surface in-app (no prompt text/code/secrets/paths).
- [ ] The run screen is the one shared responsive React UI (mobile + desktop from one codebase); a Vitest/RTL test covers the start→stream→reply→stop flow against a mocked wire protocol.
- [ ] `packages/ui/CHANGELOG.md` + repo-level `CHANGELOG.md` updated (invariants 12, 27); README documents the run screen.
- [ ] PR body links the packet (invariant 32) and confirms the Phase 2 first-shippable slice is complete.

## Human Prerequisites
- [ ] (Smoke / kill-criterion) Drive one real Claude Code session end-to-end through the run screen on the operator's machine — start, watch the stream, reply to a question, stop, and see an artifact link. This is the PDR-0011 Phase 2 acceptance and the kill-criterion check (chat-shaped control must work for at least one backend). **Record the verdict as a committed artifact** — a short bringup-result note in the repo (e.g. `docs/bringup/phase2-bringup-result.md`) per `handoff-phase2-bringup.md`; a verbal-only verdict is not sufficient.
- [ ] **PDR-0011 kill-criterion fallback (explicit):** if live `reply`/`stop` cannot be driven reliably (the smoke fails), the slice reduces to **read-only session launch/logging** — an accepted PDR-0011 exit, not a defect to grind on; the committed bringup note records that decision.
- [ ] (Deferred, validated separately) Mobile-over-Tailscale exercise of the same run screen — covered in `handoff-phase2-bringup.md`, not blocking this packet.

## Dependencies
- `packet:06` — the Claude Code adapter must drive a real session for the run screen to exercise.
- `packet:07` — the local store + notifications the run screen reads (session list, usage, notification surfacing).

## Agent Handoff
**Objective:** Build the minimal chat-shaped React PWA run screen (start/watch/reply/stop/see-artifacts) wiring the PWA to the paired bridge + Claude Code adapter + local store — the Phase 2 integration capstone.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, `packages/ui` `/run` route, branch from `main`.
**Context:**
- Goal: complete the first shippable slice — the operator can drive a real Claude Code session from the cockpit.
- ADRs: ADR-0091 (one shared React PWA across surfaces), ADR-0090 (D4 chat-shaped control), ADR-0092 (D2 usage-fidelity honesty in the UI).

**Acceptance Criteria:** as listed above.

**Dependencies:** packets 06 (Claude Code adapter) + 07 (store/notifications).

**Constraints (full text inlined):**
- ADR-0090 D4 chat-shaped control: stream agent-visible messages, surface explicit questions as `needs_input`, accept replies, support stop/cancel, support follow-up after completion, report artifacts as they appear.
- ADR-0092 D2 honesty `[Firm]`: the UI must visually distinguish exact/derived/estimated and **never render an estimate as an exact number**.
- ADR-0091 D2/D3 `[Firm]`: one shared React PWA codebase across all three surfaces — not a separate mobile UI.
- PDR-0011 `[Firm]` not-an-editor / not-a-terminal: the run screen is a cockpit, not an IDE — no editor, no terminal.
- ADR-0090 D7 `[Firm]`: notification surfacing carries status/backend/repo/link only.

**Key Files:**
- `packages/ui/src/routes/run/**` (promote packet 03's placeholder), `packages/ui/src/wire/**` (wire-protocol client), `packages/ui/src/components/UsageBadge` (fidelity-aware).

**Contracts:**
- Consumes the packet-04 wire protocol (serialized `shared-types` entities) and the packet-07 store reads.
