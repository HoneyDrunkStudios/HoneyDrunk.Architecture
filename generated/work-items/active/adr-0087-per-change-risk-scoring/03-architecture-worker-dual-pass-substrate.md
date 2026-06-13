---
name: Build the worker dual-pass substrate — second pass + synthesis + contrarian fallback
type: cross-repo-change
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["meta", "architecture", "automation", "infra", "tier-3", "adr-0087", "adr-0086", "wave-1"]
dependencies: []
adrs: ["ADR-0087", "ADR-0086"]
wave: 1
initiative: adr-0087-per-change-risk-scoring
node: honeydrunk-architecture
---

# Build the worker dual-pass substrate — second pass + synthesis + contrarian fallback

## Summary
Implement the ADR-0086-D8-deferred dual-pass execution substrate in the local `grid-agent-runner`: a risk-conditional **second independent review pass** in `Invoke-ReviewAgentPasses` (currently a flat single-pass `foreach`), synthesis of the two passes via `Join-ReviewFindings` (currently exported **dead code** with zero callers), and the contrarian-prompt fallback ADR-0086 D8 describes. This is the **hard prerequisite** for ADR-0087 enforcement (Phase 2/3): nothing can act on `double_review_required` until the second-pass machinery the gate triggers actually exists. This packet builds the machinery; **packet 04 wires the trigger to it.** It does NOT read `double_review_required` and does NOT depend on the scorer (packet 02) — it can run in parallel with packets 01 and 02.

## Context
ADR-0087 D8 (corrected) states honestly that the dual Codex/Claude second pass + synthesis + contrarian fallback that ADR-0086 D8 describes is **not yet implemented**. Verified in the corrected ADR against the code:
- ADR-0086's own Follow-up Work still lists *"Implement dual-pass synthesis in the worker"* as not-done.
- `infrastructure/workers/grid-agent-runner/lib/Queue.psm1`'s `Invoke-ReviewAgentPasses` runs a flat `foreach ($command in $JobSpec.AgentCommands)` loop with **no** risk-conditional second pass.
- `infrastructure/workers/grid-agent-runner/lib/Synthesis.psm1`'s `Join-ReviewFindings` is defined and exported but has **zero callers** (dead code).

So the substrate is ADR-0086 deferred work, not a preexisting thing ADR-0087 preserves. ADR-0087's enforcement end (Phase 2/3) cannot function until this exists. This packet is that build. It is cross-referenced to ADR-0086's Follow-up Work item — completing this closes that item.

The worker is **not a separate repo.** Per ADR-0086 D4 it is a portable PowerShell runner committed inside `HoneyDrunk.Architecture` under `infrastructure/workers/grid-agent-runner/`. This packet therefore targets `HoneyDrunk.Architecture`.

**Non-scope (do NOT do here):**
- Reading `double_review_required` from the queue comment, or any trigger wiring — that is packet 04. This packet builds the *capability*; it must be invocable by a simple boolean/parameter so packet 04 only has to flip the trigger.
- Any change to `job-review-request.yml` or the scorer (packet 02).
- The Invariant 53 enforceability flip (packet 04).

## Proposed Implementation

> **Re-read the actual `.psm1` files on checkout before editing — the descriptions below are from the corrected ADR's code-verified claims, not a fresh line-level read in this scoping pass.**

### 1. Second pass in `Invoke-ReviewAgentPasses` (Queue.psm1)
Today the function runs a single flat `foreach ($command in $JobSpec.AgentCommands)`. Restructure so the runner can execute **two independent review perspectives** — the dual Codex CLI + Claude Code CLI pass — when invoked in dual-pass mode, returning both findings sets to the caller for synthesis. Gate the second pass behind a parameter (e.g. `-DoubleReview` / a job-spec flag) so the default single-pass path is unchanged when the flag is false. **Do not wire the flag to the queue comment here** — packet 04 does that; here it is a plumbing parameter with a sensible default (single pass).

### 2. Call `Join-ReviewFindings` for synthesis (Synthesis.psm1)
`Join-ReviewFindings` is exported but uncalled. Make the dual-pass path actually call it to synthesize the two findings sets into one verdict (the ADR-0086 D8 synthesized-verdict contract). If the function's current signature/shape is insufficient for real synthesis (it was written speculatively and never exercised), bring it to a working state — but keep its public name and the synthesized-verdict output contract ADR-0086 D8 implies (one merged verdict posted to the PR).

### 3. Contrarian-prompt fallback (ADR-0086 D8)
Implement the contrarian-prompt fallback ADR-0086 D8 describes (when the two passes agree too readily / produce thin findings, run a contrarian prompt to stress the verdict). Scope it to what ADR-0086 D8 actually specifies — do not invent behavior beyond it. If ADR-0086 D8's description is underspecified for implementation, implement the minimal faithful version and note the interpretation in the worker CHANGELOG.

### 4. Tests
Add/extend Pester (or the runner's existing test harness) tests covering: single-pass path unchanged when the dual-pass flag is false; dual-pass path runs two perspectives and calls `Join-ReviewFindings`; synthesis merges two findings sets into one verdict; contrarian fallback triggers under its condition. No live CLI calls in tests — mock the agent-command invocation.

## Acceptance Criteria
- [ ] `Invoke-ReviewAgentPasses` can run a risk-conditional **second independent pass** (dual Codex + Claude perspectives) behind a parameter/flag; the default (flag false) single-pass behavior is unchanged.
- [ ] The dual-pass path **calls `Join-ReviewFindings`** (it is no longer dead code) to synthesize the two findings sets into one verdict matching the ADR-0086 D8 synthesized-verdict output contract.
- [ ] The contrarian-prompt fallback ADR-0086 D8 describes is implemented (minimal faithful version; interpretation noted in the worker CHANGELOG if ADR-0086 is underspecified).
- [ ] The dual-pass capability is invocable via a simple parameter/flag so packet 04 only needs to wire the trigger — this packet does NOT read `double_review_required` or any queue-comment field.
- [ ] Tests cover: single-pass unchanged (flag false); dual-pass runs two perspectives + calls `Join-ReviewFindings`; synthesis merges into one verdict; contrarian fallback fires under its condition. Agent-command invocation is mocked (no live CLI/LLM calls in tests).
- [ ] No change to `job-review-request.yml`, the scorer, or Invariant 53 (those are packets 02 / 04).
- [ ] Worker `CHANGELOG`/docs under `infrastructure/workers/grid-agent-runner/` record the new dual-pass substrate and close the ADR-0086 "Implement dual-pass synthesis in the worker" follow-up item.
- [ ] Repo-level `CHANGELOG.md` records the worker dual-pass substrate addition (this changes shipped worker behavior).

## Human Prerequisites
- [ ] After merge, deploy/restart the grid-agent-runner on the home-server host (Task Scheduler per ADR-0086 / ADR-0081, outside CI) so the live worker carries the new substrate. The substrate is dormant (default single-pass) until packet 04 wires the trigger, so this restart is not time-critical relative to packet 02, but the worker must carry it before packet 04's cutover.

## Dependencies
None within this initiative. Independent of packet 01 and packet 02 (it touches no catalog and no scorer). Relates to **ADR-0086** Follow-up Work ("Implement dual-pass synthesis in the worker") — completing this packet closes that item. Packet 04 depends on this packet AND packet 02.

## Agent Handoff

**Objective:** Build the dual-pass execution + synthesis + contrarian-fallback substrate in `grid-agent-runner` so an enforcement trigger has real machinery to fire. Do not wire the trigger (packet 04's job).
**Target:** HoneyDrunk.Architecture, branch from `main` (the worker lives at `infrastructure/workers/grid-agent-runner/`).
**Context:**
- Goal: stand up the ADR-0086-D8-deferred double-review substrate that ADR-0087 Phase 2/3 hard-depends on.
- Feature: risk-conditional second pass + `Join-ReviewFindings` synthesis + contrarian fallback, invocable behind a flag.
- ADRs: ADR-0087 D8 (names this as the hard prerequisite; the substrate is unbuilt), ADR-0086 D8 (the substrate's spec — dual Codex/Claude, synthesis, contrarian fallback, advisory posture) and its Follow-up Work item this closes.

**PR metadata (required by `pr-core` checks):** the PR body must carry `Authorship: <enum>` (one of `human` / `agent-codex` / `agent-copilot` / `agent-claude-code` / `mixed`) and exactly one of `Work Item: <issue link>` (this packet's filed issue) or `Out-of-band reason: <text>`. Free-form text breaks the `pr-core` metadata check.

**Acceptance Criteria:** see the checkboxes above — all must be met.

**Dependencies:** none in-initiative (parallel to 01/02). Closes the ADR-0086 dual-pass follow-up.

**Constraints:**
- **Build the capability, not the trigger.** Gate the second pass behind a parameter with a single-pass default. Do NOT read `double_review_required` or any queue-comment field here — packet 04 wires that. Keeping these separate preserves one-PR-per-repo sequencing across waves.
- **Honor the ADR-0086 D8 substrate spec.** Dual Codex CLI + Claude Code CLI perspectives synthesized into one verdict, with the contrarian-prompt fallback and advisory posture ADR-0086 D8 defines. Do not invent behavior beyond it; if underspecified, implement the minimal faithful version and document the interpretation.
- **`Join-ReviewFindings` must become live.** It is currently exported dead code (zero callers). The dual-pass path must actually call it; keep its public name and the synthesized-verdict output contract.
- **No LLM calls in tests.** Mock the agent-command invocation. The runner itself invokes the CLIs at runtime, but tests must be deterministic and offline.
- **Invariant 8 — secret values never appear in logs, traces, exceptions, or telemetry; only secret names/identifiers may be traced.** The synthesis and verdict carry findings text, never secret values.
- **CRLF line endings.** Grid repos require CRLF; the home-server worker is PowerShell. Match the existing `.psm1` line endings; run the repo's formatter/lint before committing.

**Key Files:**
- `infrastructure/workers/grid-agent-runner/lib/Queue.psm1` (`Invoke-ReviewAgentPasses` — add the second pass behind a flag)
- `infrastructure/workers/grid-agent-runner/lib/Synthesis.psm1` (`Join-ReviewFindings` — make it live)
- The runner's test dir (Pester or equivalent — add dual-pass / synthesis / contrarian tests)
- `infrastructure/workers/grid-agent-runner/CHANGELOG.md` (or docs) + repo-level `CHANGELOG.md`

**Contracts:**
- The dual-pass capability's invocation parameter/flag is the seam packet 04 wires to `double_review_required`. Keep it a simple boolean-ish parameter with a single-pass default.
- The synthesized-verdict output (one merged verdict posted to the PR) is the ADR-0086 D8 contract — preserve it.
