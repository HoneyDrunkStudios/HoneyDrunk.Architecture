---
name: Local Store and Notifications
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["feature", "tier-2", "honeyhub", "adr-0092", "wave-5"]
dependencies: ["work-item:04"]
adrs: ["ADR-0092", "ADR-0090"]
source: human
generator: scope
wave: 5
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Feature: Local-first DispatchSession store + state-only notifications

## Summary
Implement the local-first persistence of the ADR-0090 session model per ADR-0092 D1, and the state-only notification emission per ADR-0090 D7. Persist `DispatchSession`/`DispatchRun`/`DispatchControlEvent`/`DispatchArtifact` metadata + `UsageSignal`s in an embedded local store (SQLite-class, `[Provisional]` engine), with `DispatchMessage` transcript bodies in local files/blobs the user can pin or prune. Emit notifications for `needs_input`/`completed`/`failed`/`cancelled`/`PR opened` that carry status/backend/repo/link only.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub` (bridge-host store in `crates/bridge` and/or the desktop shell's local store; the notification seam in the bridge + a minimal PWA surfacing).

## Motivation
ADR-0092 D1 commits the local-first persistence + retention shape that ADR-0090 deferred ("Define `DispatchSession` storage and retention"). The store is the substrate the run screen (packet 08) reads (session list, run history, artifact links, usage totals) and the routing/coaching engines (Phase 3+) aggregate over. ADR-0090 D7 makes notifications part of the run contract — the bridge reports state; HoneyHub decides transport. For Phase 2 the notification surface is minimal (in-app + the run-state events), with richer transports (web push / Discord / ADR-0084) as later work.

## Proposed Implementation

### Local-first persistence (ADR-0092 D1)
Persist, keyed appropriately, **local-first** (honoring ADR-0090 D11 classification):
| Entity | Stored | Notes |
|---|---|---|
| `DispatchSession` | embedded store, keyed by session id | one backend per session |
| `DispatchRun` | embedded store, child of session | carries run-state |
| `DispatchControlEvent` | embedded store, child of run | also the process-launch audit trail (D8) |
| `DispatchArtifact` | embedded store — **metadata + links only**, not copied hunks (D11) | the durable, longer-retained record |
| `UsageSignal` | embedded store — operational metadata; carries `fidelity` (D2) | safe to aggregate for the current user |
| `PolicyHint` | embedded store, attached to session/run | advisory (Phase 3 rules engine) |
| `DispatchMessage` | **local files/blobs**, sensitive by default (D11); user can pin/prune | never leaves the device unless the user enables session/workspace sync |

**Storage engine is `[Provisional]`** — an embedded SQLite-class store for structured records, transcripts in local files. The `[Firm]` part is **local-first with explicit user-controlled sync**, not the engine. **No central transcript store at v1.**

### Retention (ADR-0092 D1, the committed defaults)
- Active sessions retain transcript + stream logs until the run completes.
- Completed sessions keep the local transcript for a **configurable window** unless **pinned**; prune unpinned transcripts after the window. (The exact window value is `[Provisional]` — ship a sensible default, e.g. 30 days, and make it configurable.)
- Durable records (run status, backend, repo, **artifact links, `UsageSignal` totals, outcome summaries**) are kept **longer than raw transcripts** — they carry no raw prompt/code content.

### State-only notifications (ADR-0090 D7 `[Firm]`)
- Emit notifications on `needs_input`, `completed`, `failed`, `cancelled`, `PR opened`.
- Each notification carries **status, backend, repo, and link only** — never prompt text, code, secrets, stack traces, or full paths (D7/D11).
- **`PR opened` ownership:** the **adapter** (packet 06) owns *detecting* a PR-open (parsing the CLI output) and persists it as a PR-kind `DispatchArtifact`; this store/notification seam fires the `PR opened` notification by **observing that new PR-artifact row landing in the store** — it does not re-parse CLI output. One detector (adapter), one notifier (store-observed row): the notification neither double-fires nor misses.
- For Phase 2, the transport is in-app (the PWA surfaces a notification list/badge) plus the run-state events on the wire protocol. Richer transports (web push, Discord, ADR-0084 alert-routing) are a later seam — define the notification emission as a transport-agnostic event so adding a transport is additive. (If the scaffold's CI or this feature emits operator-actionable Discord alerts, the ADR-0084 D10 alert-routing onboarding applies — but Phase 2's in-app notifications are not Discord alerts, so no `constitution/alert-routing.md` row is required here; flag if that changes.)

### Sync posture (`[Firm]` local-first default)
- Nothing syncs off-device by default. Sync is per-session/per-workspace opt-in (ADR-0090 D11 / ADR-0092 D1 `[Firm]`). At Phase 2 there is no sync backend; the store is purely local. The data model must not assume a central store.

## Acceptance Criteria
- [ ] An embedded local store persists `DispatchSession`/`DispatchRun`/`DispatchControlEvent`/`DispatchArtifact` (metadata+links only) + `UsageSignal` (with `fidelity`) + `PolicyHint`; transcripts (`DispatchMessage` bodies) live in local files/blobs separable from the structured store.
- [ ] Retention: active transcripts retained until completion; completed-session transcripts kept for a configurable window (default shipped) unless pinned, pruned after; durable records (status/backend/repo/artifact-links/usage-totals/outcome) kept longer than transcripts and carry no raw prompt/code.
- [ ] Pin and prune actions work; an unpinned transcript past the window is pruned; durable records survive the prune.
- [ ] Notifications fire on `needs_input`/`completed`/`failed`/`cancelled`/`PR opened`, carrying status/backend/repo/link only — verified by a test asserting no prompt text/code/secret/path leaks into a notification payload.
- [ ] Nothing syncs off-device by default; the data model carries no central-store assumption; sync is a per-session/workspace opt-in seam (not wired to any backend at v1).
- [ ] Tests cover persistence round-trip, retention/prune, pin survival, and the notification-payload redaction.
- [ ] CHANGELOGs updated (bridge/store package + repo-level) per invariants 12, 27; README documents the store + retention defaults.
- [ ] PR body links the packet (invariant 32) and notes the embedded-engine + retention-window values are `[Provisional]` (ADR-0092 ledger).

## Human Prerequisites
None for the code-change work.

## Dependencies
- `work-item:04` — the bridge core defines the session-contract entities and the run-state events this store persists and the notifications fire on.

## Agent Handoff
**Objective:** Implement the local-first DispatchSession store (embedded structured records + local transcript files, with retention/pin/prune) and state-only notification emission.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, the bridge-host store + notification seam, branch from `main`.
**Context:**
- Goal: the persistence + notification substrate the run screen (packet 08) reads and Phase 3 routing/coaching aggregate over.
- ADRs: ADR-0092 (D1 local-first persistence + retention), ADR-0090 (D7 state-only notifications, D11 data classification).

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 04 (bridge core).

**Constraints (full text inlined):**
- ADR-0092 D1 `[Firm]`: local-first session/usage storage with explicit user-controlled sync; the retention shape (active transcripts retained, unpinned pruned after a window, durable metadata/usage/artifact-links kept longer than raw transcripts, **no central transcript store at v1**).
- ADR-0090 D7 `[Firm]`: state-only notifications — status/backend/repo/link only, never prompt text/code/secrets/stack traces/full paths.
- ADR-0090 D11: `DispatchArtifact`s store metadata + links, not copied hunks; transcripts sensitive-by-default and local; prefer repo-relative paths.
- ADR-0092 D2: every `UsageSignal` carries `fidelity` (exact/derived/estimated) — the store persists the tag; the UI (packet 08) must never render an estimate as exact.
- The embedded engine and concrete retention-window values are `[Provisional]` (ADR-0092 ledger) — ship sensible configurable defaults behind a clean boundary.

**Key Files:**
- `crates/bridge/src/store/**` (or a dedicated store module), `crates/bridge/src/notify.rs` (notification seam).
- `packages/ui/src/` minimal notification surfacing (list/badge).

**Contracts:**
- Persists/serves the `shared-types` session entities; the run screen (packet 08) reads this store over the wire protocol.
