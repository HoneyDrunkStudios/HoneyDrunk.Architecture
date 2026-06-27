# ADR-0095: HoneyHub Group Check Runner — Scoped Process-Exec Exception to the Read-Only Bridge

**Status:** Proposed
**Date:** 2026-06-27
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / AI / Platform

**Relationships:** Extends the [ADR-0090](ADR-0090-honeyhub-local-runner-bridge.md) bridge boundary — specifically **D9, the artifact/write-boundary decision** and **D8's workspace-root allowlist** — by adding a *second* narrowly-scoped exception to the bridge's normally read-only posture, alongside the git **writes** (stage/commit/push/pull/checkout/discard) already governed by ADR-0090 D9. It mirrors the same confirmation-gated, allowlist-gated posture the HoneyHub Service Bus explorer uses for its destructive data-plane operations (the Service Bus write-boundary decision the code references as "ADR-0094 D5"; that decision is referenced in `crates/bridge/src/servicebus.rs` but not yet written to an ADR file — this ADR does **not** claim that number). Builds on the [ADR-0091](ADR-0091-honeyhub-app-stack-and-repo-node-home.md) Rust bridge / single-install app-stack decision (the runner is plain `std::process::Command`, not a shell or terminal) and the [ADR-0092](ADR-0092-honeyhub-session-usage-telemetry-and-routing.md) device-wide / host-synthesized event convention (the `check_result` event is device-wide and host-only, never backend-streamed). Aligns with the [ADR-0047](ADR-0047-testing-patterns-and-tooling.md) testing-patterns direction (declared per-repo build/test commands) and supports the [ADR-0093](ADR-0093-loop-engineering-closed-loop-agent-orchestration.md) "tests/checks run" signal as an operator-driven precursor to loop-gated checks. Tracked in the [HoneyHub program](../initiatives/programs/honeyhub.md). Scoped to **HoneyDrunk.HoneyHub** only.

---

## Context

A new **Groups** cockpit surface clusters working-tree changes across repos and worktrees by shared branch name, so the operator can view a related cross-repo change as one unit. The companion action is a group-level **Run checks** runner: for each member repo in a group, fire that repo's declared build/test command and aggregate pass/fail.

HoneyHub's repo CLAUDE.md states two boundaries this touches:

- **"Do not add a terminal."**
- The bridge is **read-only except for narrowly-scoped, confirmation-gated exceptions.**

Prior to this change, the only write/exec exceptions across the bridge were:

1. **Git writes** — stage/unstage/commit/push/pull/checkout/discard, governed by ADR-0090 D9 (the artifact/write-boundary decision), gated against the ADR-0090 D8 workspace allowlist and confirmation-gated in the Git screen.
2. **Service Bus destructive ops** — dead-letter resubmit, purge, send, receive, queue/topic management, gated and confirmation-gated in the cockpit (the Service Bus write-boundary decision referenced in code as "ADR-0094 D5").

Both prior exceptions invoke *specific, structured* external surfaces (`git`, the Azure Service Bus SDK). The Run checks runner is categorically broader: it executes an **arbitrary declared local process** (`npm test`, `cargo test --workspace`, `dotnet test`, etc.) in a repo root. That is local process execution across the bridge — close enough to "a terminal" that it needs an explicit decision recording *why it is not a terminal* and *what guardrails keep it inside the spirit of the boundary*.

The implementation already landed on branch `claude/multi-repo-grouped-changes-vbcv0h` in `HoneyDrunk.HoneyHub` (`crates/bridge/src/checks.rs`, plus the `wire.rs` / `core.rs` surface). This ADR records the boundary decision the implementation embodies.

---

## Decision

### D1. The bridge MAY execute a declared check command as a scoped exception

HoneyHub's bridge **MAY** run a declared check command (a repo's build/test) in an allowlisted repo root, as a third narrowly-scoped, confirmation-gated exception to the read-only / no-terminal boundary — joining git writes (ADR-0090 D9) and Service Bus destructive ops. The exception is valid **only** under every guardrail in D2–D7. Removing any one of them re-opens the boundary question and requires a new decision.

### D2. It is not a terminal — fixed declared commands only

There is **no interactive shell, no PTY, no editor, no REPL, no input stream**. The runner accepts a single declared command string per invocation and returns one structured outcome. It cannot be driven turn-by-turn, cannot keep a session, and cannot read the operator's typing. This is the line that keeps the feature on the right side of the "Do not add a terminal" boundary: a check runner is a one-shot, fire-and-report action, not a command surface.

### D3. Commands run shell-free — no injection surface

The command string is tokenized on ASCII whitespace; the **first token is the program and the rest are its args**, spawned directly via Rust `std::process::Command` (`crates/bridge/src/checks.rs::parse_command`). **No shell is involved**, so shell metacharacters are inert: `npm test` and `cargo test --workspace` work, but `npm test; rm -rf ~` cannot chain, redirect, glob, substitute, or expand. There is no shell-metacharacter / command-injection surface to defend, because there is no shell. This property is `[Firm]` — a future need for shell semantics (pipes, env expansion, `&&`) is a new decision, not a tweak.

### D4. The repo root is allowlist-gated — same gate as git writes

Before any command runs, the host gates the target `root` against the workspace allowlist — the **same `require(workspace_allows(root))` gate that fronts git writes** (ADR-0090 D8). A command can only ever run inside a directory the operator has explicitly added as a workspace root. The bridge refuses roots outside the allowlist exactly as it refuses out-of-root paths for reads and git writes.

### D5. It is confirmation-gated in the UI

Running a check is **confirmation-gated in the cockpit**, the same posture as git writes and Service Bus destructive ops. The operator confirms the exec; it never fires implicitly from navigation or polling.

### D6. Output is captured, clamped, and structurally typed

The runner captures combined stdout + stderr, trims it, and **clamps it to 40,000 characters** so a noisy run cannot flood the wire, returning a structured `CheckOutcome { root, command, ok, exitCode, output, truncated }`. Non-runnable cases — an **empty command** or a **spawn failure** (program not found, not executable) — surface **inline as `ok: false`** with the reason in `output`, **not** as a transport error. A failed or unrunnable check is a normal, displayable outcome, never a bridge fault.

### D7. The result is a device-wide, host-synthesized event a backend can never forge

The check outcome travels as a **device-wide, host-synthesized** `check_result` event (`BridgeEventPayload::CheckResult`), carrying empty `session_id` / `run_id` and `sequence = 0` like the other device-wide host events (roadmap, session list/detail, usage summary). The adapter stream validator **explicitly rejects** a `CheckResult` arriving on a backend stream (`crates/bridge/src/core.rs`: `event_unexpected_check_result` — "a backend stream must not emit device-wide check results"). A running agent backend can therefore **never synthesize or spoof a passing check**; only the host, in response to an operator-confirmed `RunCheck`, produces this event. This preserves the ADR-0092 device-wide / host-only event boundary and keeps check results trustworthy.

### D8. Wire surface

The exception adds exactly two wire shapes, no more:

- `ClientCommand::RunCheck { root, command }` — the operator-confirmed request.
- `BridgeEventPayload::CheckResult { result: CheckOutcome }` — the single host-synthesized response.

Implementation lives in the bridge module `crates/bridge/src/checks.rs`; the wire types and the host-only validator rule live in `crates/bridge/src/wire.rs` and `crates/bridge/src/core.rs`.

---

## Consequences

### Positive

- The Groups surface gains a real "test this cross-repo change as one unit" action without HoneyHub becoming a terminal or an editor.
- The blast radius is bounded by construction: shell-free spawn (D3) + allowlist gate (D4) + confirmation gate (D5) means the worst an attacker-controlled command string can do is run *one declared program* inside an *already-allowlisted* repo with *operator confirmation* — no chaining, no escape.
- Check results are trustworthy: a backend run can never forge a green check (D7), so the operator's pass/fail aggregate reflects actual local execution.
- Establishes a reusable pattern (declared-command, shell-free, allowlist+confirmation-gated, host-synthesized result) for any future bridge exec need, and a clean precedent for ADR-0093 loop-gated checks if/when a loop wants to run the same declared commands under tier gates.

### Negative

- This is genuinely a new capability class (arbitrary local process exec), not just another structured SDK call like git or Service Bus. It widens the bridge's exec surface and must be guarded as such — the guardrails are load-bearing, not decorative.
- Declared commands are operator-trusted; a careless declared command (e.g. a test script that itself does destructive work) runs with the operator's privileges. HoneyHub does not sandbox the spawned process beyond cwd and the no-shell property.
- Whitespace tokenization (D3) means commands needing quoted args with spaces, env-var expansion, or shell operators are not expressible. That is intentional (it is the no-injection property), but it constrains what a "declared command" can be.
- 40k output clamping (D6) can truncate a verbose failing run; the `truncated` flag signals it, but deep diagnostics may need the operator to run locally.

### Scope and follow-ups

- **Scoped to HoneyDrunk.HoneyHub.** No Grid catalog edit, no new Grid-wide invariant. The boundary lives in HoneyHub's repo CLAUDE.md; this ADR records the sanctioned exception to it.
- Where declared check commands are configured (per-repo manifest, group definition, or operator entry) is an implementation detail left to the Groups surface; this ADR governs only the *execution boundary*, not command authorship.
- A future tier that lets ADR-0093 loops fire the same declared commands under autonomy gates is a **separate** decision — D5's operator confirmation is the v1 floor and is not waived here.

---

## Alternatives Considered

### Launch an LLM agent to run the tests

Rejected. Dispatching a `claude.local` / `codex.local` session (ADR-0090 D2) just to type `cargo test` is heavyweight, non-deterministic, costs tokens, and routes a trivial, deterministic action through the full agent run/usage machinery. The whole point of the Groups "Run checks" action is a fast, deterministic, free pass/fail across N repos. An agent also could not produce the trustworthy host-synthesized `check_result` (D7) — its output would arrive on a backend stream the validator rejects, exactly the spoofable shape this ADR avoids.

### A full terminal / PTY in the cockpit

Rejected, and explicitly forbidden by HoneyHub's "Do not add a terminal" boundary. A terminal is an open-ended command surface with a shell, interactivity, and an unbounded injection/escape surface. The whole design of D2–D3 is to get the one useful capability (run a declared build/test) *without* importing the terminal's risk surface. Fixed, shell-free, one-shot declared commands are the minimum that does the job.

### Rely only on CI signals (no local exec at all)

Rejected for this surface. CI runs on push, per-repo, after the fact — it cannot tell the operator "does this *uncommitted, cross-repo, grouped* working-tree change pass its checks *right now*, before I commit/PR." The Groups flow is precisely about pre-commit, cross-worktree validation of related changes as a unit; CI remains the authoritative downstream gate, but it does not serve the in-cockpit, pre-artifact loop. Local declared-command checks complement CI; they do not replace it.

### A general "run any command" bridge RPC (no guardrails)

Rejected. An ungated `Exec { command }` would be the terminal-by-another-name the boundary forbids, with shell semantics and no allowlist/confirmation. Every guardrail (shell-free, allowlist-gated, confirmation-gated, host-only result) is what distinguishes a sanctioned check runner from an arbitrary remote-exec primitive.

---

## Decision Ledger

Per the HoneyHub flexibility posture (PDR-0011 Amendment §7; ADR-0090 Decision Ledger), each decision is tagged `[Firm]` or `[Provisional]`.

- **`[Firm]`** — do not move without a real new decision:
  - **not a terminal** — no shell, PTY, editor, REPL, or interactive input; declared one-shot commands only (D2);
  - **shell-free spawn** — direct `std::process::Command`, no shell, no metacharacter interpretation (D3);
  - **allowlist-gated** — every `root` passes the same `workspace_allows` gate as git writes before exec (D4; ADR-0090 D8);
  - **confirmation-gated** — operator confirms each run (D5);
  - **host-only, unforgeable result** — `check_result` is device-wide and host-synthesized; a backend stream emitting it is rejected (D7; ADR-0092).
- **`[Provisional]`** — working assumptions, revise on signal: the 40k output clamp value (D6); where/how declared commands are configured; whitespace tokenization details; the eventual loop-tier integration with ADR-0093.

Provisional items change by a conversation + an amendment note here (no new ADR) as long as no `[Firm]` line is crossed.
