# Handoff — Standup → Phase 2 (scaffold landed → build the bridge)

**Read once at the wave transition.** This baton passes from the standup wave (packets 01–03) to the Phase 2 build wave (packets 04–08). Immutable per the packet-immutability convention — it is a point-in-time handoff, not a live tracker.

## What just landed (upstream)
- **Packet 01 (Architecture):** `HoneyDrunk.HoneyHub` is registered in `catalogs/nodes.json` (Meta sector, Seed, `orchestration` cluster), `relationships.json` (all edge arrays empty — schema-native keys only, no invented `consumes_planned`; the planned upstream edges are recorded on `honeydrunk-architecture`'s and `honeydrunk-ai`'s `consumed_by_planned` arrays), `grid-health.json` (0.0.0); the Meta-sector row, roadmap bullet, and active-initiatives entry exist; the five-file `repos/HoneyDrunk.HoneyHub/` context folder exists. The **node-class is resolved**: `node_class: studios-typescript-native` (the dedicated seventh class added by the ADR-0082 2026-06-06 amendment — dual Node + Cargo workspace, self-contained `pr.yml`, required check `pr / build`).
- **Packet 02 (human):** the public `HoneyDrunkStudios/HoneyDrunk.HoneyHub` repo exists, branch protection requires **`pr / build`** (the repo's own self-contained `pr.yml` job, NOT `pr-core / core`), labels seeded, `repo-to-node.yml` maps it, the local tree is cloned. **No org secret is required by default** for the `studios-typescript-native` class (no `SONAR_TOKEN` — `pr.yml` does not consume `pr-core.yml`).
- **Packet 03 (scaffold):** the workspace monorepo builds — `packages/ui` (React+Vite PWA), `packages/shell` (minimal Tauri-class wrapper), `packages/shared-types` (the ADR-0090 session-contract TS types incl. `UsageSignal.fidelity`), `crates/bridge` (compiling Rust crate with module stubs: `session`/`process`/`pairing`/`adapter`/`artifact`). Dual-lane CI (Node + Rust) is green via the **self-contained `pr.yml`** (required check `pr / build`; not `pr-core.yml`). No Grid package published; no tag pushed.

## The session contract you are building against (ADR-0090 D3/D4)
Entities (now in `packages/shared-types` as TS types; mirror in Rust as you implement the wire protocol): `DispatchSession`, `DispatchRun`, `DispatchMessage`, `DispatchControlEvent`, `DispatchArtifact`, `UsageSignal` (with `fidelity ∈ {exact, derived, estimated}`), `PolicyHint`.

Run-state machine (implement exactly in packet 04):
```
created -> queued -> starting -> running -> needs_input -> finalizing -> completed
                                    |             |             |
                                    v             v             v
                                  stopping      failed        cancelled
```

Capability flags (the adapter declares; the core adapts): `streaming_output`, `interactive_reply`, `resume_session`, `stop_signal`, `structured_events`, `usage_exact`, `usage_estimated`.

## The Phase 2 build order (strict where noted)
1. **Packet 04 — bridge core** (keystone; precedes adapter + run screen). Run-state machine, the `AgentBackendAdapter` trait, process launch/lifecycle, the wire protocol carrying the session contract, a fake adapter for tests. The wire protocol is `[Provisional]` — keep it versioned behind a clean module boundary.
2. **Packet 05 — pairing + allowlist** (depends on 04). Per-device identity, revocable token, workspace-root allowlist (the real gate behind 04's seam), backend allowlist, PWA bridge-settings. Transport-agnostic (the Tailscale relay is `[Provisional]`).
3. **Packet 06 — Claude Code adapter** (depends on 04+05). The one backend for Phase 2 — cleanest per the spike: same-process `interactive_reply`, exact tokens+USD (`fidelity: exact`, taken directly, no rate-table computation). Drives the **official CLI under the user's own local session** — never holds/stores/proxies subscription auth.
4. **Packet 07 — local store + notifications** (depends on 04; parallel with 05/06). Embedded SQLite-class store (`[Provisional]` engine) + local transcript files; retention/pin/prune; state-only notifications (status/backend/repo/link only). No central transcript store; local-first by default.
5. **Packet 08 — minimal run screen** (depends on 06+07). The integration capstone: start/watch/reply/stop/see-artifacts in the one shared React PWA; usage display with fidelity visually distinguished.

## `[Firm]` boundaries you must not cross (inline, from the ledgers)
- The bridge drives each vendor's **official CLI under the user's own local session**; HoneyHub never holds/stores/proxies subscription auth (ADR-0090 D8/D10).
- Cloud/hosted execution is **BYO-API-key only, never a subscription token** (ADR-0090 D10 — not relevant to local Phase 2 but do not open any path toward it).
- **Artifacts are the write boundary** — no direct mutation of authoritative Architecture/catalog/code state outside a reviewable git branch/PR (ADR-0090 D9).
- **Honest capability flags** — the bridge never fakes live interaction a backend lacks (ADR-0090 D4).
- **State-only notifications** — status/backend/repo/link only, never prompt text/code/secrets/stack traces/full paths (ADR-0090 D7).
- **Local-first data default** with per-session/workspace opt-in sync; no central transcript store at v1 (ADR-0090 D11, ADR-0092 D1).
- **Usage fidelity always tagged; the UI never renders an estimate as exact** (ADR-0092 D2).
- **Not-an-editor / not-a-terminal** — the cockpit gains no code editor or terminal (PDR-0011).

## Phase 2 acceptance (the PDR-0011 kill-criterion check)
The slice ships when the operator can drive **one real Claude Code session** end-to-end from the run screen — start, watch the token-level stream, reply to a `needs_input` question, stop, and see an artifact link. If the bridge cannot reliably stream/reply/stop for Claude Code, PDR-0011's kill criterion says reduce scope to read-only session launch/logging before building governance — surface that immediately rather than papering over it.

## Toolchain note
Local dev needs **both** Node.js (>=22, pnpm/npm) and Rust (`rustup`, stable `cargo`, `clippy`). Run `cargo fmt` + the Node formatter locally before committing after any full-file rewrite (Write-tool output is LF on Windows; the formatters normalize).
