---
name: Bridge Core
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["feature", "tier-2", "honeyhub", "adr-0090", "wave-4"]
dependencies: ["work-item:03"]
adrs: ["ADR-0090", "ADR-0091"]
source: human
generator: scope
wave: 4
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Feature: Rust bridge core — process launch/lifecycle + the session contract over the wire (stream/reply/stop)

## Summary
Implement the Rust bridge core per ADR-0090 D1 (the bridge boundary) and D4 (chat-shaped control): process launch and lifecycle, the run-state machine, and the wire protocol carrying the ADR-0090 session contract (`DispatchSession`/`DispatchRun`/`DispatchMessage`/`DispatchControlEvent`/`DispatchArtifact`) between HoneyHub (the PWA) and the bridge. This is the **backend-agnostic** core: it defines the `AgentBackendAdapter` trait, the run-state transitions, the streaming/reply/stop event plumbing, and the local `DispatchRun` event log — but does **not** implement any specific backend. Secure pairing is packet 05; the Claude Code adapter is packet 06; the local DispatchSession store is packet 07; the minimal run screen is packet 08.

The bridge core precedes the adapters and the run screen — it is the keystone of Phase 2.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub` (the `crates/bridge` crate scaffolded in packet 03).

## Motivation
ADR-0090 D1 names what the bridge owns: process launch and lifecycle, workspace/repo path access, backend adapter invocation, streaming stdout/stderr or structured events into HoneyHub, accepting user replies or control commands, artifact detection, local run logs, secure pairing. D4 requires the bridge to stream agent-visible messages, surface `needs_input`, accept replies, support stop/cancel, support follow-up messages, and report artifacts — and to **declare backend capabilities honestly** (`[Firm]`: the bridge never pretends a backend supports live interaction it lacks). Packet 03 shipped the module stubs; this packet implements the backend-agnostic core so packet 06's Claude Code adapter slots into a working runtime.

## Proposed Implementation

### The run-state machine (ADR-0090 D3)
Implement the state machine exactly:
```
created -> queued -> starting -> running -> needs_input -> finalizing -> completed
                                    |             |             |
                                    v             v             v
                                  stopping      failed        cancelled
```
A `DispatchRun` carries its current state; transitions are the only way state changes; invalid transitions are rejected (return an error, never silently no-op). Each transition appends a `DispatchControlEvent` to the run's local event log (this log is also the process-launch audit trail per ADR-0090 D8 — "all process launches recorded as `DispatchRun` events").

### The `AgentBackendAdapter` trait
Promote the packet-03 stub to a real trait the core drives. It declares:
- `capabilities() -> CapabilityFlags` — the seven ADR-0090 D4 flags (`streaming_output`, `interactive_reply`, `resume_session`, `stop_signal`, `structured_events`, `usage_exact`, `usage_estimated`). The core **reads these and adapts** — e.g. if `interactive_reply == false`, the core routes a user reply through a **follow-up run** (new `DispatchRun` carrying prior transcript + run metadata + workspace context) rather than into the live process (ADR-0090 D4: "If `interactive_reply=false`, HoneyHub can still present a chat UX by starting a follow-up run").
- `start(session, workspace, task) -> RunHandle` — launch the backend process for a run.
- `stream() -> impl Stream<Item = BridgeEvent>` — incremental messages/progress/`needs_input`/artifact-detected/usage events.
- `reply(run, text)` — send a user reply into the live process (only valid when `interactive_reply`).
- `stop(run)` — graceful cancellation (only valid when `stop_signal`).
- `resume(session_id_or_transcript)` — resume a prior session (only valid when `resume_session`).

The core **never calls a capability the adapter did not declare** — that is the honest-capability `[Firm]` rule in code.

### Process launch / lifecycle
- Launch backend processes under the bridge's process group; track PID/handle per `DispatchRun`.
- Capture stdout/stderr streams; the adapter parses them into `BridgeEvent`s (the core does not assume any backend's format — that is adapter work).
- On `stop`, send graceful termination; escalate after a timeout; record the outcome as a `DispatchControlEvent`.
- On process exit, transition the run to `completed`/`failed`/`cancelled` per exit semantics.
- **Workspace path access is allowlist-gated** — the core refuses to launch against a path outside the configured workspace-root allowlist (the allowlist itself is owned by packet 05's pairing; the core consumes it). Refusing out-of-allowlist paths is the `[Firm]` D8 posture.

### The wire protocol (ADR-0090 follow-up; `[Provisional]`)
ADR-0090 left the exact wire protocol `[Provisional]` (decision ledger). Implement a concrete, documented protocol between the PWA and the bridge carrying the session-contract events — a WebSocket or local HTTP+SSE channel is the expected shape (localhost for the bundled desktop case; over the Tailscale relay for mobile per ADR-0091 D5). The protocol frames are the `shared-types` entities serialized; the run-screen (packet 08) is the first consumer. **The `crates/bridge` README is the authoritative wire-protocol document** — it is in-repo, versioned with the code, and testable; document the full versioned protocol there so packet 08 and the relay work build against a stable, in-repo surface. (Mirroring the protocol summary into the Architecture-side `repos/HoneyDrunk.HoneyHub/integration-points.md` is a **follow-up**, not a gate on this packet — see the acceptance criterion below.) Because the protocol is `[Provisional]`, keep it versioned and behind a clean module boundary so it can change without crossing a `[Firm]` line.

**Non-functional requirements for the wire protocol:**
- **No loopback-only assumption.** Do not pin the origin to `localhost`/`127.0.0.1` or assume a single never-dropped connection. The protocol must define **reconnect / resume semantics** (a client reconnecting mid-run re-attaches to the live `DispatchRun` stream and replays missed events from the local event log) so the same protocol works unchanged over the Tailscale relay (mobile, packet 05's transport-agnostic pairing) as over localhost (bundled desktop). No frame may encode a hard `localhost` origin.
- **Secure-context / mixed-content path.** A PWA served over **HTTPS** (Cloudflare Pages, ADR-0091 D4) cannot, under browser mixed-content rules, open a plain-`http`/`ws` connection to a local/tailnet bridge. The protocol design must **name an approach** for an https secure-context client reaching the bridge, e.g. one of: (a) the bridge terminates **TLS with a locally-trusted cert** (e.g. a Tailscale-provided cert / `*.ts.net` MagicDNS HTTPS, or a locally-installed dev cert) so the origin is `https`/`wss`; (b) the secure relay provides the `https` origin and forwards to the bridge; (c) the desktop shell serves the UI over a **custom scheme** (Tauri-class `app://`/IPC) so no mixed-content boundary exists for the bundled case. The chosen approach is `[Provisional]`; documenting that the protocol does not break on the HTTPS-PWA → local-http-bridge boundary is the requirement here.

### State-only event hygiene (ADR-0090 D7/D11)
Events the core emits for **notification** purposes carry status/backend/repo/link only — never prompt text, code, secrets, stack traces, or full paths (`[Firm]` D7). Transcript content (`DispatchMessage` bodies) flows on the in-session stream to the active user, not into notification events. The core redacts known secret patterns from command lines before they enter any persisted `DispatchControlEvent` (D11).

## Acceptance Criteria
- [ ] The run-state machine is implemented exactly per ADR-0090 D3; invalid transitions are rejected with an error (never a silent no-op); each transition appends a `DispatchControlEvent` to the run's local event log.
- [ ] The `AgentBackendAdapter` trait declares `capabilities()` (seven flags), `start`, `stream`, `reply`, `stop`, `resume`; the core never invokes a capability the adapter did not declare.
- [ ] When `interactive_reply == false`, a user reply is routed through a follow-up run carrying prior transcript + run metadata + workspace context (not into the live process).
- [ ] Process launch/lifecycle: processes are tracked per `DispatchRun`; stop sends graceful termination then escalates after a timeout; process exit transitions the run correctly; every launch is recorded as a `DispatchRun` event (audit trail per D8).
- [ ] The core refuses to launch against a workspace path outside the configured allowlist (consumes the allowlist packet 05 owns; for this packet a config-injected allowlist is sufficient with a TODO seam for packet 05).
- [ ] A concrete, versioned wire protocol carries the session-contract events between the PWA and the bridge; **the `crates/bridge` README is the authoritative wire-protocol document** (in-repo, versioned, testable) and documents the versioned protocol. Mirroring the protocol into the Architecture-side `repos/HoneyDrunk.HoneyHub/integration-points.md` is an explicit follow-up (or folded into the implementation-notes packet), **not** required of this HoneyHub-scoped packet.
- [ ] The wire protocol makes **no loopback-only assumption** — it defines reconnect/resume semantics (a reconnecting client re-attaches to the live run and replays missed events) and pins no `localhost` origin, so it works unchanged over the Tailscale relay and over localhost.
- [ ] The wire protocol's README documents the **secure-context / mixed-content** path for an HTTPS-served PWA reaching a local/tailnet bridge over http, naming a concrete approach (bridge terminates TLS with a locally-trusted cert / the relay provides the https origin / the desktop shell uses a custom scheme) — `[Provisional]`, but the HTTPS-PWA → local-bridge boundary is shown not to break the protocol.
- [ ] Notification-purpose events carry status/backend/repo/link only — never prompt text, code, secrets, stack traces, or full paths; command lines are secret-redacted before persistence.
- [ ] A **fake/in-memory adapter** is shipped in the crate's test module exercising the full lifecycle (start → stream → needs_input → reply → stop, and the follow-up-run path for a non-interactive fake) so the core is testable without a real CLI. Unit tests cover the state machine, the capability-gating, and the follow-up-run routing.
- [ ] `crates/bridge/CHANGELOG.md` gains a `## [0.2.0]` (or appended in-progress) entry; the repo-level `CHANGELOG.md` records the bridge-core feature (invariants 12, 27).
- [ ] **PDR-0011 kill-criterion fallback (explicit):** if live `reply`/`stop` cannot be driven against a real backend (validated downstream by packet 06 + the bringup smoke), the slice reduces to **read-only launch/logging** — an accepted exit per PDR-0011, not a defect to grind on. This packet's core must keep the read-only launch/logging path intact even if interactive reply/stop later proves unreliable for a backend.
- [ ] PR body links the packet (invariant 32) and notes the wire protocol is `[Provisional]` (ADR-0090 ledger).

## Human Prerequisites
None for the code-change work. (The agent needs the Rust toolchain locally per packet 03; that is a standing dev-environment prerequisite, not a per-packet portal step.)

## Dependencies
- `work-item:03` — the scaffold must exist (the `crates/bridge` crate, the `shared-types` session contract, and the CI lanes) before the core can be implemented.

## Agent Handoff
**Objective:** Implement the backend-agnostic Rust bridge core — run-state machine, the `AgentBackendAdapter` trait, process launch/lifecycle, the wire protocol carrying the session contract, and a fake adapter for testing.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, `crates/bridge`, branch from `main`.
**Context:**
- Goal: Phase 2 keystone — the bridge core that the Claude Code adapter (packet 06) and the run screen (packet 08) build on.
- Feature: ADR-0090 D1 (bridge boundary) + D4 (chat-shaped control) in Rust.
- ADRs: ADR-0090 (session contract, capability flags, run-state machine, honest capabilities, state-only notifications, artifacts-as-write-boundary), ADR-0091 (Rust bridge language, bundled in the Tauri-class shell).

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 03 (scaffold).

**Constraints (full text inlined):**
- ADR-0090 D4 honest-capability `[Firm]` rule: "Backends declare capabilities. The bridge must not pretend a backend supports live interaction if it only supports one-shot commands." The core reads `capabilities()` and never invokes an undeclared capability; non-interactive backends get the follow-up-run model, not a faked live reply.
- ADR-0090 D7 state-only notifications `[Firm]`: notifications carry status/backend/repo/link only — never prompt text, code, secrets, stack traces, or full paths.
- ADR-0090 D8 pairing/trust: the bridge refuses paths outside configured workspace roots; all process launches are recorded as `DispatchRun` events.
- ADR-0090 D9 artifacts-as-write-boundary `[Firm]`: the bridge does not directly mutate authoritative Architecture/catalog/code state — durable output lands only as a reviewable git branch/PR (this packet does not produce artifacts yet, but the core must not open any direct-write path).
- ADR-0090 D11 data classification: command lines are secret-redacted before persistence; transcripts default to local; absolute local paths avoided in records (prefer repo-relative).
- The wire protocol and run-state-machine details are `[Provisional]` (ADR-0090 ledger) — keep them versioned and behind a clean module boundary so they move without crossing a `[Firm]` line.

**Key Files:**
- `crates/bridge/src/session.rs`, `process.rs`, `adapter.rs`, `artifact.rs`, `wire.rs` (new)
- `crates/bridge/README.md` — **the authoritative wire-protocol document** (in-repo, versioned, testable); document the versioned protocol + the reconnect/resume + secure-context NFRs here.
- `crates/bridge/tests/` (fake-adapter lifecycle tests)
- `packages/shared-types/**` (keep the TS session types in sync with the Rust serialization if the wire protocol serializes them)
- `repos/HoneyDrunk.HoneyHub/integration-points.md` — **Architecture-repo, not editable by a HoneyHub-scoped agent. Demoted to a follow-up** (or folded into the implementation-notes packet): the authoritative protocol doc is the crate README above; the Architecture-side mirror is a later companion edit, not a gate on this packet.

**Contracts:**
- `AgentBackendAdapter` (Rust trait) — `capabilities`/`start`/`stream`/`reply`/`stop`/`resume`. This is the seam packet 06 (Claude Code) implements.
- The wire protocol frames = serialized `shared-types` entities. This is the seam packet 08 (run screen) consumes.
