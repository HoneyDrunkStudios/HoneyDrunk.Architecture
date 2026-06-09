---
name: Pairing and Allowlist
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["feature", "tier-2", "honeyhub", "adr-0090", "wave-4"]
dependencies: ["packet:04"]
adrs: ["ADR-0090", "ADR-0091"]
source: human
generator: scope
wave: 4
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Feature: Secure pairing + workspace-root allowlist + backend allowlist (the bridge trust boundary)

## Summary
Implement the ADR-0090 D8 pairing and trust posture: a user-initiated pairing flow from HoneyHub to the bridge, a per-device bridge identity, a revocable pairing token, a local allowlist of workspace roots (the bridge refuses paths outside it), and a backend allowlist. This is the trust boundary the bridge core (packet 04) consumes when it gates process launches — packet 04 ships a config-injected allowlist seam; this packet makes it real, user-controlled, and revocable.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub` (`crates/bridge` pairing module + the PWA's pairing UI in `packages/ui`).

## Motivation
ADR-0090 D8: "The local bridge is trusted code running on the developer machine. Pairing must be explicit." The minimum posture is: user-initiated pairing flow from HoneyHub, per-device bridge identity, revocable token, a local allowlist of workspace roots (bridge refuses paths outside configured roots), a backend allowlist, no secret values streamed into HoneyHub transcripts, and all process launches recorded as `DispatchRun` events. Packet 04's core refuses out-of-allowlist paths but takes the allowlist as injected config; this packet owns the allowlist's lifecycle (user-configured, persisted, revocable) and the pairing handshake that authenticates the PWA to the bridge.

## Proposed Implementation

### Per-device bridge identity + pairing handshake
- The bridge generates a per-device identity on first run (a keypair or equivalent), persisted locally.
- Pairing is **user-initiated from HoneyHub**: the user triggers a pairing flow (e.g. the PWA displays/scans a pairing code, or the bundled-shell case auto-pairs over localhost with an explicit confirm). The handshake establishes a **revocable pairing token** the PWA presents on every subsequent wire-protocol connection (packet 04's protocol).
- The token is revocable: a "revoke device" action invalidates it; a revoked token is rejected by the bridge.
- For the bundled-desktop case (ADR-0091 D2), pairing is localhost and frictionless but still explicit (one confirm). For the mobile case, pairing happens over the Tailscale relay (ADR-0091 D5) — the same token model; the relay is a `[Provisional]` transport, so keep pairing transport-agnostic.

### Workspace-root allowlist
- A user-configured list of absolute workspace roots the bridge may operate within.
- The bridge **refuses to launch any backend process against a path outside the allowlist** (this is the gate packet 04's core calls). Refusal is an explicit error surfaced to the user, never a silent skip.
- The allowlist is persisted locally and editable from the PWA's bridge-settings UI.
- Prefer repo-relative paths in any synced/persisted record; avoid leaking absolute local paths into HoneyHub transcripts or notifications (ADR-0090 D11).
- **The workspace-root allowlist is stored as absolute paths (the bridge needs them to gate launches), but it is local-only and is NEVER synced off the bridge host** (ADR-0090 D11). The absolute paths live only in the bridge's local config; they never enter a transcript, a notification, or any sync surface — only the repo-relative derivations do.

### Backend allowlist
- A user-controlled list of which `AgentBackend`s the bridge may launch (`claude.local`, `codex.local`, `copilot.local`). At v1 only the Claude Code adapter exists (packet 06), but the allowlist is the seam so future adapters are opt-in.

### No-secret-leak posture
- No secret values are streamed into HoneyHub transcripts (ADR-0090 D8). The pairing token itself is never displayed in a transcript or a notification; command lines are secret-redacted (consumes packet 04's redaction).

### PWA pairing UI
- A minimal pairing + bridge-settings surface in `packages/ui`: pair a device, view paired devices, revoke, manage workspace-root allowlist, manage backend allowlist. This is bridge-settings UI, distinct from the run screen (packet 08).

## Acceptance Criteria
- [ ] The bridge generates and persists a per-device identity on first run.
- [ ] A user-initiated pairing handshake issues a revocable pairing token; the PWA presents the token on every wire-protocol connection; a revoked token is rejected.
- [ ] The bundled-desktop path pairs over localhost with one explicit confirm; pairing is transport-agnostic so the mobile/Tailscale path reuses the same token model.
- [ ] A user-configured workspace-root allowlist is persisted; the bridge refuses (explicit error, not silent skip) any process launch against a path outside it; packet 04's core gate now consumes this real allowlist.
- [ ] A user-controlled backend allowlist gates which `AgentBackend`s may launch.
- [ ] No secret values (including the pairing token) enter any transcript or notification; command-line redaction is applied.
- [ ] A minimal PWA bridge-settings surface lets the user pair/revoke devices and edit the workspace-root + backend allowlists.
- [ ] Unit tests cover: token issue/revoke, allowlist accept/refuse (including a path-traversal attempt outside the allowlist), and the revoked-token rejection path.
- [ ] `crates/bridge/CHANGELOG.md` + `packages/ui/CHANGELOG.md` + repo-level `CHANGELOG.md` updated (invariants 12, 27); READMEs updated if the public surface changed.
- [ ] PR body links the packet (invariant 32) and notes the relay transport is `[Provisional]` (ADR-0091 D5).

## Human Prerequisites
None for the code-change work. (Mobile pairing over Tailscale requires the operator to have Tailscale installed on the bridge host and phone — that is a relay-bringup concern handled when the mobile path is exercised, not a prerequisite for implementing the transport-agnostic pairing core. See `handoff-phase2-bringup.md`.)

## Dependencies
- `packet:04` — the bridge core owns the process-launch gate that consumes the allowlist and the wire protocol the pairing token rides on.

## Agent Handoff
**Objective:** Implement the bridge trust boundary — per-device identity, user-initiated revocable pairing, workspace-root allowlist (the real gate behind packet 04's seam), backend allowlist, and the PWA bridge-settings UI.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, `crates/bridge` pairing module + `packages/ui` bridge-settings, branch from `main`.
**Context:**
- Goal: make the bridge safe to pair and operate — the trust posture ADR-0090 D8 requires before real CLI driving (packet 06).
- ADRs: ADR-0090 D8 (pairing and trust) + D11 (data classification), ADR-0091 D5 (mobile relay = Tailscale, `[Provisional]`).

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 04 (bridge core).

**Constraints (full text inlined):**
- ADR-0090 D8 minimum posture `[Firm]`: user-initiated pairing flow from HoneyHub; per-device bridge identity; revocable token; local allowlist of workspace roots (bridge refuses paths outside configured roots); backend allowlist; no secret values streamed into HoneyHub transcripts; bridge refuses paths outside configured roots; all process launches recorded as `DispatchRun` events.
- ADR-0090 D11 data classification: prefer repo-relative paths; avoid absolute local paths in synced records; redact known secret patterns from command lines.
- ADR-0091 D5 `[Firm]` relay constraint: any mobile relay is an encrypted pass-through HoneyHub cannot read into, and HoneyHub never holds vendor subscription auth on the path. Keep pairing transport-agnostic so the Tailscale (`[Provisional]`) relay reuses the token model without baking the transport into the trust core.

**Key Files:**
- `crates/bridge/src/pairing.rs` (promote packet 03's stub), allowlist persistence.
- `packages/ui/src/` bridge-settings route (pair/revoke/allowlist).

**Contracts:**
- The pairing token + allowlist config are consumed by packet 04's core launch-gate (already seamed there).
