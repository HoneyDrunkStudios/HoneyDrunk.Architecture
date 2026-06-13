---
name: Phase 3+ Outline
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["chore", "tier-2", "honeyhub", "adr-0092", "wave-7"]
dependencies: ["work-item:08"]
adrs: ["ADR-0092", "ADR-0090", "ADR-0091", "ADR-0010"]
source: human
generator: scope
wave: 7
initiative: honeyhub-v1
node: honeydrunk-honeyhub
---

# Outline: HoneyHub Phase 3+ work units (low-resolution placeholder — re-scope each before execution)

## Summary
A **low-resolution outline** of the Phase 3+ work that follows the Phase 2 first-shippable slice. This packet is a tracked placeholder so the program board carries the forward shape; **each bullet below becomes its own concretely-scoped packet (or initiative) before execution** — do not implement directly from this outline. Several Phase 3+ decisions are `[Provisional]` or `gated`; the re-scope/refine pass for each must resolve the open seam before a real packet is cut.

This packet should be **kept open as a tracking item** and closed only when all its child packets have been cut. It does not itself ship code.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.HoneyHub` (most child packets; some Architecture-side for catalog/edge wiring when the HoneyDrunk.AI consume edge lands).

## Outline of Phase 3+ work units

### 3a. Second backend adapter — Codex (`codex.local`)
- Drive the official Codex CLI under the user's own local (ChatGPT) session. Spike profile: message-level `streaming_output` (`item.completed`), **resume-based** `interactive_reply` (so the core uses the follow-up-run path, not same-process), `stop_signal` + `resume_session` yes, usage = **exact tokens (no USD)**.
- `UsageSignal` fidelity: tokens `exact`; **USD `derived`** — computed from the operator-configurable per-model rate table (ADR-0052 D2 / ADR-0016 D5). This is the first packet exercising the `derived` path and the rate-table dependency.
- Re-scope note: the resume-based interactive model must be validated against the live Codex CLI; the rate-table read is a new dependency on the ADR-0052/ADR-0016 surface.

### 3b. Third backend adapter — Copilot (`copilot.local`)
- Drive the official GitHub Copilot CLI under the user's own local `gh` token. Spike profile: token-level `streaming_output` (`assistant.message_delta`), resume-based `interactive_reply`, `stop_signal` + `resume_session` yes, usage = **premium-requests + duration only** (no tokens, no USD). Spike finding: Copilot's CLI runs a Claude model under the hood on a **separate billing bucket** (a premium-request unit, not a token bill).
- `UsageSignal` fidelity: premium-requests/duration `exact`; tokens/USD **`estimated`** from text-size + duration proxies (ADR-0090 D5 estimated-signal list), with a coarse confidence band.

### 3c. UsageSignal normalization + cost display
- Normalize the three usage shapes across all three backends with the `fidelity` tag end-to-end (ADR-0092 D2), and a "your spend" view that reads the ADR-0052/ADR-0016 rate surface so HoneyHub's spend view and the Grid cost ledger agree. The UI fidelity-distinguishing rendering (built in packet 08) gets its first `derived`/`estimated` real data here.

### 3d. The routing engine (the headline feature) — `[Provisional]` placement
- The app-tier routing engine: route for capability/cost fit + subscription-aware load-balancing ("optimize your own subscriptions"), expressed as an ADR-0010 `IRoutingPolicy`-shaped policy (ADR-0092 D3). **`[Firm]`**: HoneyDrunk.AI's `IRoutingPolicy` is canonical — HoneyHub consumes it, never forks it; routing is "optimize your own subscriptions," **never** cap-dodging / rate-limit evasion / account multiplexing / credential rotation.
- **Open seam (`[Provisional]`, ADR-0092 Open Q):** does the app-tier router call a live HoneyDrunk.AI `IModelRouter` over a contract boundary, or evaluate a synced policy-config copy app-side? The re-scope must resolve this. This is also where the `HoneyDrunk.HoneyHub → HoneyDrunk.AI` consume edge gets **wired** in the catalogs (named in ADR-0091 D6, deferred from packet 01).
- Quota tracking: read quota where the backend exposes it, estimate otherwise (same fidelity discipline); a `derived`/`estimated` quota figure only drives a soft routing preference, never a hard action.

### 3e. Rules-based coaching (`PolicyHint`)
- The v1 rules-based coach (ADR-0092 D4): stale-session, routing-hint, split-task, mode-fit, automation-candidate, subscription-optimization hints — deterministic rules over `UsageSignal`/session-state data, advisory only (never a hard block in local v1). The **learned per-user coaching model is a separately gated v2 ADR** (PDR-0011 Amendment §2) — not designed or built here.

### 3f. Desktop Tauri-class shell packaging
- The full bundled-shell-with-bridge single installer (ADR-0091 D2 Option A): the desktop shell bundles the Rust bridge into one per-OS installer. Open seams (`[Provisional]`, ADR-0091 Open Q): the exact desktop-shell toolkit, code-signing, and auto-update. The re-scope must pick the toolkit and resolve signing/update before a real packaging packet.

### 3f-bis. Agent-discovery from `.claude/agents/` + the Copilot agent folder
- Auto-discover the user's own agent definitions from their repo's `.claude/agents/` directory and the Copilot agent folder, and **surface them in the cockpit so they can be selected and run** as dispatch targets (PDR-0011 Amendment §6 v1-scope item). Spike note: this reads agent-definition files from an allowlisted workspace root (consuming packet 05's allowlist) and presents them as runnable entries — it does not author or mutate them.
- **Explicitly deferred to Phase 3+** — absent from the Phase 2 first-shippable slice; cut its own concretely-scoped packet (resolve: discovery scope, which folders, how a discovered agent maps to a `DispatchSession`/backend) before execution.

### 3g. Tailscale mobile relay bringup
- The mobile PWA reaching the bridge on the operator's runner host / desktop over Tailscale (ADR-0091 D5, `[Provisional]`). `[Firm]` constraint: any relay is an encrypted pass-through HoneyHub cannot read into, and HoneyHub never holds vendor subscription auth on the path. The pairing core (packet 05) is already transport-agnostic; this work exercises and hardens the relay path. A future zero-install tier's dumb-pipe relay is `gated`, not in scope.

### Gated / out of scope (per the program tracker)
The entire v2 cluster stays `gated` behind v1 shipping + the PDR-0011 Amendment §5 BYOK validation probe: **BYOK cloud execution** (BYOK-API-key only, never subscription auth — `[Firm]`), the **Dev-surface read-layer** (PDR-0009, internal-default), **team/org governance**, and the **learned-coaching v2 ADR**. None is scoped by this outline.

## Acceptance Criteria
- [ ] This packet remains an open tracking item until each Phase 3+ bullet has been cut into its own concretely-scoped packet/initiative.
- [ ] No code is shipped directly from this outline; each child packet resolves its own `[Provisional]`/`gated` open seams in a refine pass before execution.
- [ ] When the routing-engine child packet is cut, it includes the Architecture-side wiring of the `HoneyDrunk.HoneyHub → HoneyDrunk.AI` consume edge (deferred from packet 01 per ADR-0091 D6).

## Human Prerequisites
None (tracking placeholder). Individual child packets will carry their own (e.g. the Codex/Copilot CLIs installed + authenticated for the adapter smokes; code-signing certs for desktop packaging; Tailscale install for the relay).

## Dependencies
- `work-item:08` — Phase 3+ builds on the completed Phase 2 first-shippable slice.

## Agent Handoff
**Objective:** (Tracking) Hold the forward shape of HoneyHub Phase 3+ so the program board carries it; spawn concretely-scoped child packets, do not implement from this outline.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub` (most), Architecture (the AI consume edge when routing lands).
**Context:** Phase 3+ of PDR-0011; ADR-0092 (routing/usage/coaching), ADR-0091 (packaging/relay), ADR-0010 (`IRoutingPolicy` HoneyHub is the first consumer of).

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 08 (Phase 2 complete).

**Constraints (full text inlined, for the child packets to carry forward):**
- ADR-0092 D3 `[Firm]`: HoneyDrunk.AI's `IRoutingPolicy` is the canonical routing-policy contract; HoneyHub consumes it and does not fork a parallel routing abstraction. Routing = "optimize your own subscriptions" (capability/cost fit + the user's own subscription headroom), NEVER cap-dodging / rate-limit evasion / account multiplexing / credential rotation.
- ADR-0092 D2 `[Firm]`: usage fidelity always tagged exact/derived/estimated; the UI never renders an estimate as exact.
- ADR-0092 D4: v1 coaching is rules-based only; the learned per-user model is a separately gated v2 decision, not designed here.
- ADR-0091 D5 `[Firm]`: any mobile relay is an encrypted pass-through HoneyHub cannot read into; HoneyHub never holds vendor subscription auth on the path.
- ADR-0090 D10 / PDR-0011 Amendment §3 `[Firm]`: cloud/hosted execution is BYO-API-key only, never a subscription token — the entire v2 BYOK cluster is gated behind the §5 validation probe.

**Key Files:** (per child packet) `crates/bridge/src/adapters/{codex_local,copilot_local}.rs`, the app-tier router module, the coaching-rules module, the shell packaging config, the relay bringup; Architecture `catalogs/relationships.json` for the AI consume edge.

**Contracts:** Each adapter implements `AgentBackendAdapter`; the router consumes ADR-0010 `IRoutingPolicy`.
