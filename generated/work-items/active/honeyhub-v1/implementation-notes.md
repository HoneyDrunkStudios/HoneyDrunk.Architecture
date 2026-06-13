# HoneyHub v1 — Implementation Notes (as-built)

As-built record for the HoneyHub v1 build, authored by the implementing agent (ADR-0008 amendment / Arch PR #555: the implementer writes the as-built record, not hive-sync). Captures **decided ➜ as-built deltas** and the **why**; it does not rewrite the immutable packets or the ADR decisions. Governing ADRs: ADR-0090 (Local Runner Bridge), ADR-0091 (App Stack / Node Home), ADR-0092 (Session / Usage / Routing). Companion to the 2026-06-08 ADR-0092 amendment (synced-snapshot routing + invariant-45 local-first carve-out).

**Repo:** `HoneyDrunk.HoneyHub` — a Rust workspace (`crates/bridge`, `crates/bridge-host`) + a TS monorepo (`packages/shared-types`, `packages/ui`, `packages/shell`). As of this writing: bridge crate `0.20.0`; shared-types `0.14.0`; ui/shell/root `0.14.0`.

---

## What shipped (merged PRs)

| Area | PR(s) | Packet 09 § |
|---|---|---|
| Bridge core + wire `honeyhub.bridge.v1` + pairing/allowlist + local store + notifications + run screen | (Phase 2, prior) | 04–08 |
| `claude.local` / `codex.local` / `copilot.local` adapters + shared `child_run` driver | #22, #27, #28 | 3a/3b |
| Session diagnostics; rules-based coaching **engine** | #21, #25 | (diagnostics) / 3e-engine |
| **Cost / "your spend" view** | #30 | 3c |
| **Cross-session coaching surface** | #31 | 3e |
| **Agent discovery + Agents catalog** | #32 | 3f-bis |
| **App-tier routing engine** | #33 | 3d |

Not yet built (operator-gated): desktop Tauri shell (§3f), Tailscale relay hardening (§3g).

---

## Decided ➜ as-built deltas (and why)

### Backends (ADR-0090 §3a/3b)

- **Shared `child_run` driver.** All three adapters are thin strategies over one `adapters::child_run` process driver (spawn / stderr-drain / stdout reader thread / kill-tree / reap / one-time exit detection). The ADR framed three adapters; the as-built factors the *mechanics* into one place so each adapter supplies only command + capability flags + JSONL parsing + reply mechanism.
- **Three usage fidelities are a `CapabilityFlags` triple + a `UsageSignal.fidelity` tag** (`usage_exact` / `usage_derived` / `usage_estimated`; at most one set). Matches ADR-0092 D2 exactly: Claude `exact`, Codex `derived` (tokens exact, USD via an injected `UsdRateLookup`; absent → USD omitted, never fabricated), Copilot `estimated` (premium-requests exact, tokens/USD proxied).
- **Process teardown — accepted recycle window (follow-up HoneyHub#26).** The tree is killed exactly once (`kill_tree_once`, idempotent across close + Drop). A small pid-recycle window remains on the unix group-signal-after-reap path; accepted for v1, with the recycle-immune fix (Linux `pidfd` / Windows job objects) tracked in **#26**. Operator-confirmed.
- **argv-prompt exposure for codex/copilot — accepted (ADR-0090 note, follow-up #29).** Codex/Copilot take the task on the command line (their CLI shape), so the prompt is visible in the local process list for the run's lifetime. Accepted for v1 local-first single-user; tracked in **#29**. Recorded as an ADR-0090 amendment.
- **Test fixtures gated behind a `test-fixtures` cargo feature** (`required-features` on the `fake_*` bins + `#![cfg(feature)]` on integration tests) so they are never product binaries (Grid invariant 16). CI passes `--features honeyhub-bridge/test-fixtures` for test/clippy only.

### Cost view — §3c (PR #30)

- **Runtime-sourced, not store-sourced (delta).** `UsageSummary::from_signals` is a pure aggregator (per `(backend, fidelity)`, grounded USD = exact + derived only, estimated premium-requests separate). The host answers a fieldless `usage_summary` wire query from `BridgeRuntime::usage_summary()`, which reads usage back out of the **in-memory** run event logs. **Delta from the D1 "persisted local store" intent:** the summary is host-lifetime, not persistent — the `LocalStore` exists but is not yet wired into the host. A persistent-store-backed summary (surviving restart) is a follow-up; the aggregator is already store-ready (it is pure over `&[UsageSignal]`).
- **Honesty enforced structurally** (ADR-0092 D2): grounded dollars and estimated activity are kept apart at the aggregator, the wire, and the view, so a guess can never read as a measured cost. `grounded_total_usd` is `None` (not `0.00`) when nothing grounded was recorded.

### Coaching surface — §3e (PR #25 engine, #31 surface)

- **`coach(&CoachingSnapshot) -> Vec<PolicyHint>`** is a pure, deterministic engine (ids `coach:{session}:{code}`); advisory only, never a `Block` severity (ADR-0092 D4). Rules shipped: `stale_session`, `high_cost_session` (grounded spend only), `estimate_only_spend`. Routing-dependent rules (`routing_hint`/`mode_fit`/`subscription_optimization`) deferred to land with routing.
- **`elapsed_minutes` is `None` in the wired surface (delta).** `BridgeRuntime::coaching_hints(now)` runs the coach over every session, but passes `elapsed_minutes: None` — the bridge crate is deliberately dependency-free (it hand-rolls `civil_from_days`; no date-parse), and idle wall-time is a weak staleness signal, so the token/message thresholds carry the `stale_session` rule. The time-based trigger is the only coach input not wired; documented as acceptable.
- **Message count uses the latest run only, anchored deterministically.** Because resume-based `reply()` carries the prior transcript into each follow-up run, summing every run's transcript would double-count; the count is read from the session's latest run (chosen by max `(started_at, run_id)` — relies on the system-wide normalized-RFC3339-UTC ordering already used by `store::prune` / `replay_events`).

### Agent discovery — §3f-bis (PR #32)

- **Source conventions (operator-decided, a delta from the packet's open "which folders").** Table-driven: `.claude/agents/*.md` → `claude.local` (every markdown file); `.github/` files whose name contains "agent" → `copilot.local`. **Codex has no folder-of-agents convention and is not scanned** (rather than inventing a path).
- **Defense-in-depth (as-built hardening from review).** Read-only, metadata-only (never the prompt body). Allowlist-gated **twice**: a root must be in the `WorkspaceAllowlist` (refused before any scan), and results are filtered to the `BackendAllowlist` (never advertise an unrunnable agent). **No absolute path crosses the wire**: `source_path` is workspace-relative, `workspace_label` is the root basename (hash-derived for a rootless root), `id` hashes the normalized root. A symlinked agent file or source folder that escapes the workspace is dropped by a canonical-path containment check (the folder is checked before it is even listed).

### Routing engine — §3d (PR #33) + the 2026-06-08 amendment

- **Synced-snapshot, app-tier, bundled (resolves the D3 Open Question).** The router is app-tier TypeScript; it reads the rates + policy from a **bundled JSON data artifact** (`routingSnapshot.bundled.json`) through `loadRoutingSnapshot()` — a fetch-shaped seam that returns the bundled projection in v1 and can fetch+cache a published projection later without touching callers.
- **Invariant 45 carve-out (the load-bearing governance delta).** A bundled projection of routing policy collides with invariant 45 (no hardcoded rates/policies/capabilities in app code, sourced from Azure App Config). HoneyHub is offline and cannot call App Config at runtime — the reason the synced-snapshot shape exists. Resolved by **(1)** keeping the policy in a data artifact loaded via a seam (not constants) and **(2)** a **local-first carve-out amendment to invariant 45** (`constitution/invariants.md` §45) permitting a local-first Node to consume a synced-snapshot projection, with the bundled default an explicit temporary placeholder until HoneyDrunk.AI publishes the projection.
- **Capability/cost-fit only in v1 (narrowed claim).** `recommendBackend` prefers capability for complex tasks (estimated from keyword + length), cost for light ones. The **"optimize your own subscriptions" recent-usage tiebreak ships as a tested but un-wired hook** — no UI passes live per-backend usage yet; wiring real usage/headroom is a follow-up. The changelog reflects the actual shipped behavior.
- **Honest capabilities (review delta).** The backend picker offers only the user's **configured** backends (Bridge settings); before any are configured it offers only the **proven-initial backend (Claude)**, so an empty config never implies Codex/Copilot (which the user may not have installed) are launchable. The bridge still enforces its allowlist on launch. The run's backend is **frozen at launch** so the active run's diagnostics never drift on a mid-session config change.

---

## Out-of-band note (process)

Per the operator (2026-06-08), v1 slices shipped **out-of-band** against the packet 09 outline (which states no code ships directly from it). Grid `changes-requested-by-agent` whose only blocker was packet/scope was treated as non-blocking; **real code-level findings and invariant violations still blocked** and were fixed (e.g. the invariant-45 resolution above). Concrete child packets were not cut per slice; this as-built record + the ADR amendments are the scope trail.

## Tracked follow-ups

- **#26** — recycle-immune process teardown (Linux `pidfd` / Windows job objects).
- **#29** — argv-prompt exposure for codex/copilot (move the prompt off argv where the CLI allows).
- **Persistent cost summary** — wire `LocalStore` into the host so `usage_summary` survives restart (aggregator already store-ready).
- **Routing producer + delivery** — HoneyDrunk.AI publishes the routing/cost-rate snapshot projection; add fetch-and-cache delivery + a stale-snapshot age indicator (ADR-0092 amendment open seams 1–3).
- **Live-usage routing** — wire per-backend usage/headroom (from the cost-view data) into `recommendBackend` so the subscription tiebreak is active.
- **Coaching time-trigger** — wire `elapsed_minutes` if a date-parse is added to the host (not the clock-free bridge crate).
- **Desktop shell §3f + Tailscale §3g** — operator-gated (code-signing, native build, Tailscale infra).
