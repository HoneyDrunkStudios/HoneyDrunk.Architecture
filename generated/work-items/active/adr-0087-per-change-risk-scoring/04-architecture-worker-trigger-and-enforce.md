---
name: Phase-3 enforce — worker reads double_review_required, fires dual-pass, gate cutover
type: cross-repo-change
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["meta", "architecture", "automation", "security", "infra", "tier-3", "adr-0087", "wave-3"]
dependencies: ["work-item:02", "work-item:03"]
adrs: ["ADR-0087", "ADR-0086", "ADR-0044"]
wave: 3
initiative: adr-0087-per-change-risk-scoring
node: honeydrunk-architecture
---

# Phase-3 enforce — worker reads double_review_required, fires dual-pass, gate cutover

## Summary
Wire the local worker (`infrastructure/workers/grid-agent-runner/`) to read the explicit `double_review_required` boolean from the queue comment and fire the dual-pass substrate (built in packet 03) when it is true; honor the sensitivity-forced subset for human-authored PRs in the named subset; and complete the Phase-3 cutover. The cutover asserts the pilot's `risk-gate-mode` is `gate` (not `shadow`) before treating any verdict as authoritative, and the worker **refuses to act on a `double_review_required=true` that carries `gate_mode: shadow`** (it checks the marker packet 02 emits). Flip Invariant 53 to enforceable. **There is NO `review_risk_class` retirement** — the worker never read that field; nothing to retire.

## Context
This is the enforcement end of ADR-0087, and it depends on **both** halves built upstream:
- **Packet 02 (Actions)** makes `job-review-request.yml` emit `risk_score`, `double_review_required`, `gate_mode`, and `risk_rationale` into the queue comment from day one, in shadow posture by default.
- **Packet 03 (Architecture)** builds the dual-pass execution + synthesis + contrarian-fallback substrate in the worker, invocable behind a flag. **Without 03 there is no second-pass machinery for the trigger to fire.**

This packet connects the two: the worker reads `double_review_required` and invokes the packet-03 dual-pass when true. The corrected ADR removes the entire `review_risk_class` transition/retirement story — the worker (`grid-agent-runner/lib/Queue.psm1`) parses only `head_sha` and `claimed_at` and never read `review_risk_class`/`risk_class`, so there is no legacy field to retire and no coordinated emitter-removal PR. (Packet 02 already does not emit it.)

The worker is **not a separate repo** (ADR-0086 D4 — committed inside `HoneyDrunk.Architecture`). This packet targets `HoneyDrunk.Architecture` for the worker change and the Invariant 53 flip. **No HoneyDrunk.Actions edit is required** (packet 02 already shipped the day-one fields with no `review_risk_class`).

Source ADR (read-only at execution): `adrs/ADR-0087-per-change-risk-scoring-for-double-review.md`.

> **Phase-2 go/no-go gate (human).** This packet is the Phase-3 work. It must NOT be executed until the Phase-2 pilot go/no-go is met (ADR-0087 D7 Phase 2: in `gate` mode on the `HoneyDrunk.Architecture` pilot, the gate fires on genuinely risky changes and stays quiet on docs/test churn). Filed now so the work is tracked; the `dependencies` edges enforce data/substrate ordering, and the Wave-3 dispatch-plan boundary note records the go/no-go confirmation before this is started.

**Non-scope:**
- Building the dual-pass substrate (that is packet 03 — this packet only triggers it).
- Any `review_risk_class` retirement (nothing to retire).
- Re-deriving the bulk of Invariant 53 (packet 01 set the wording; this packet flips only the enforceability clause).

## Proposed Implementation

> **Re-read the actual `.psm1` files on checkout before editing.**

### 1. Worker reads `double_review_required` and fires the packet-03 dual-pass
In the grid-agent-runner queue-comment parser (the module that today parses `head_sha`/`claimed_at`), add parsing of `double_review_required` (boolean), `gate_mode` (`shadow`|`gate`), and `risk_rationale` (string). When `double_review_required` is true **and** the verdict is authoritative (see step 2), invoke the dual-pass capability packet 03 built (its flag/parameter) — the dual Codex + Claude synthesized second pass. When false (or not authoritative), run the single Grid-aware pass. The substrate, synthesis, and contrarian fallback are packet 03's — this packet only supplies the trigger.

### 2. Refuse shadow-mode verdicts; assert gate mode before authoritative action
The worker MUST NOT treat a `double_review_required=true` as authoritative when the same queue comment carries `gate_mode: shadow`. Shadow output is observational (ADR-0087 D7 Phase 1). The worker acts on the gate **only** when `gate_mode: gate`. Concretely: authoritative ⇔ `double_review_required == true && gate_mode == gate`. A shadow-mode true is logged/recorded but runs the single pass. This makes the Phase-1→Phase-2 transition entirely operator-controlled via the pilot's `.honeydrunk-review.yaml` (`risk-gate-mode: gate`), with no worker code change needed to enter Phase 2 — the worker already honors `gate_mode`.

### 3. Sensitivity-forced gate fires on human-authored PRs (ADR-0087 D6)
The scorer (packet 02) already sets `double_review_required=true` for any PR tripping a `forced` pattern, including `human` authorship. The worker must **act** on that (when authoritative per step 2): a human-authored PR with `double_review_required=true && gate_mode=gate` gets the dual-pass, not the single pass. This is the narrow named exception — the worker does NOT force-gate human PRs outside the forced subset (those carry `risk-high` as a signal and get the single Grid-aware pass, because the human author supplies one perspective). Do not reintroduce a blanket human-PR exemption; ADR-0087 D6 withdrew it for the most-sensitive paths.

### 4. Flip Invariant 53 to enforceable
In `constitution/invariants.md`, change Invariant 53's trailing clause from "Enforceable once ADR-0087 Phase 3 lands **and** the ADR-0086 dual-pass worker substrate it depends on is implemented (D8 prerequisite)." to a present-tense enforceable statement (e.g. "Enforceable: the per-change scorer gates double-review on the pilot as of ADR-0087 Phase 3, the ADR-0086 dual-pass worker substrate being implemented."). Do not otherwise alter the wording packet 01 set — only the enforceability clause changes.

## Acceptance Criteria
- [ ] The grid-agent-runner parses `double_review_required`, `gate_mode`, and `risk_rationale` from the queue comment (in addition to the existing `head_sha`/`claimed_at`).
- [ ] When `double_review_required=true` **and** `gate_mode=gate`, the worker fires the packet-03 dual Codex + Claude synthesized second pass; otherwise it runs the single Grid-aware pass.
- [ ] The worker **refuses to treat a `double_review_required=true` carrying `gate_mode: shadow` as authoritative** — it records/logs it but runs the single pass. Authoritative ⇔ `double_review_required && gate_mode==gate`.
- [ ] A human-authored PR with `double_review_required=true && gate_mode=gate` (a `forced`-subset trip) receives the dual-pass; a human-authored PR with `risk-high` but `double_review_required=false` receives the single pass (no blanket human force-gate outside the forced subset).
- [ ] **No `review_risk_class` retirement work is performed** — the field was never read by the worker; there is no legacy fallback to remove and no coordinated Actions emitter-removal PR (packet 02 already emits no `review_risk_class`).
- [ ] The packet-03 dual-pass substrate, synthesis, and contrarian fallback are invoked unchanged — this packet only supplies the trigger; it does not modify the substrate.
- [ ] Invariant 53's trailing clause is flipped from the "Enforceable once ... Phase 3 lands and ... substrate implemented" caveat to a present-tense enforceable statement; the rest of the wording (set by packet 01) is unchanged.
- [ ] `initiatives/active-initiatives.md` marks Wave-3 / Phase-3 complete.
- [ ] Worker `CHANGELOG`/docs under `infrastructure/workers/grid-agent-runner/` record the trigger read-path change; repo-level `CHANGELOG.md` records the enforcement cutover.

## Human Prerequisites
- [ ] **Phase-2 go/no-go must be met before starting this packet.** On the `HoneyDrunk.Architecture` pilot, set `.honeydrunk-review.yaml` `risk-gate-mode: gate` and confirm `double_review_required` fires on genuinely risky changes (an `ISecretStore` touch, a Kernel.Abstractions contract widening) and stays quiet on docs/test churn (ADR-0087 D7 Phase 2). If the firing rate is unacceptable, tune weights/threshold in packet 02's scorer (operator config / a small Actions PR, no architecture change) until it passes — do not start this packet until it passes.
- [ ] Ensure packet 03's substrate is **deployed/live** on the home-server worker (Task Scheduler per ADR-0086 / ADR-0081) before this trigger change goes live — the trigger must have machinery to fire.
- [ ] Deploy/restart the grid-agent-runner on the home-server host after this trigger change so the live worker reads `double_review_required`/`gate_mode`.
- [ ] Set the pilot repo's `.honeydrunk-review.yaml` `risk-gate-mode: gate` (the operator-controlled Phase-2 entry; no worker code change needed — the worker honors the `gate_mode` marker).

## Dependencies
Blocked by **packet 02** (Actions scorer — the worker reads `double_review_required`/`gate_mode`/`risk_rationale` it writes) AND **packet 03** (the worker dual-pass substrate the trigger fires). Additionally gated on the human Phase-2 pilot go/no-go (recorded at the Wave-3 dispatch-plan boundary).

## Agent Handoff

**Objective:** Wire the worker to read `double_review_required`/`gate_mode` and fire the packet-03 dual-pass when authoritative; fire the sensitivity-forced gate on human PRs in the named subset; refuse shadow-mode verdicts; flip Invariant 53 to enforceable. No `review_risk_class` retirement.
**Target:** HoneyDrunk.Architecture, branch from `main` (worker + invariant). No Actions PR needed.
**Context:**
- Goal: complete the Phase-3 cutover so "high risk" is the per-change verdict and the worker acts on it only when the operator has flipped the pilot to `gate`.
- Feature: worker reads `double_review_required`+`gate_mode`, triggers the packet-03 dual-pass, including human-PR force-gating on the most-sensitive paths.
- ADRs: ADR-0087 (D1 no-retirement, D6 human-PR force-gate, D7 Phase 3, D8 substrate-prerequisite), ADR-0086 D8 (the dual-CLI substrate — built in packet 03, invoked here), ADR-0044 D8 (the superseded static flag).

**PR metadata (required by `pr-core` checks):** the PR body must carry `Authorship: <enum>` (one of `human` / `agent-codex` / `agent-copilot` / `agent-claude-code` / `mixed`) and exactly one of `Work Item: <issue link>` (this packet's filed issue) or `Out-of-band reason: <text>`. Free-form text breaks the `pr-core` metadata check.

**Acceptance Criteria:** see the checkboxes above — all must be met.

**Dependencies:** packet 02 (the scorer writes the fields) AND packet 03 (the substrate the trigger fires); plus the human Phase-2 go/no-go.

**Constraints:**
- **Trigger only — do not modify the substrate.** ADR-0087 D8: the ADR-0086 D8 dual-CLI execution, synthesis, contrarian fallback (built in packet 03) are unchanged; this packet changes only what *triggers* the second pass.
- **Refuse shadow-mode verdicts.** Authoritative ⇔ `double_review_required==true && gate_mode==gate`. A `double_review_required=true` carrying `gate_mode: shadow` must NOT trigger the dual-pass — it is observational (ADR-0087 D7 Phase 1). This is the operator-controlled Phase-1→Phase-2 seam.
- **Human-PR force-gate is the narrow named exception, not a blanket reversal (ADR-0087 D6).** "Outside those most-sensitive paths, human-authored PRs are not force-gated — they get the single Grid-aware pass and surface `risk-high` as a signal." Force-gate human PRs only on the `forced` subset (Vault secret-resolution, credentials, `ISecretStore`-class contracts).
- **No `review_risk_class` retirement (ADR-0087 D1).** The worker never read it (`Queue.psm1` parses only `head_sha`/`claimed_at`). There is nothing to retire, no fallback to remove, and no coordinated Actions PR. Do not invent retirement work.
- **Invariant 53 — exact wording set by packet 01; only the enforceability clause changes here.** Flip the trailing "Enforceable once ... Phase 3 lands and ... substrate implemented" clause to present-tense enforceable; do not re-derive the rest. For reference, the invariant reads (per packet 01): "Agent-authored PRs whose changes are scored high-risk receive two independent LLM-review perspectives before merge... It is never a static per-Node or per-repo flag; no `review_risk_class` repo field gates this invariant. A change whose sensitivity signal trips the most sensitive paths (Vault secret-resolution, credentials, `ISecretStore`-class contracts) is forced into the double-review gate regardless of authorship."
- **Invariant 8 — secret values never appear in logs, traces, exceptions, or telemetry; only secret names/identifiers may be traced.** The worker reads path/contract names from the rationale/queue comment, never secret values.
- **CRLF line endings.** Grid repos require CRLF; match the existing `.psm1` line endings and run the formatter/lint before committing.

**Key Files:**
- `infrastructure/workers/grid-agent-runner/lib/Queue.psm1` (add `double_review_required`/`gate_mode`/`risk_rationale` parsing alongside `head_sha`/`claimed_at`)
- the runner's pass-orchestration entry (where the single-pass is invoked today) — fire the packet-03 dual-pass flag when authoritative
- `constitution/invariants.md` (Invariant 53 enforceability clause)
- `initiatives/active-initiatives.md` (Wave-3 / Phase-3 tracking)
- `infrastructure/workers/grid-agent-runner/CHANGELOG.md` (or docs) + repo-level `CHANGELOG.md`

**Contracts:**
- Queue-comment keys read by the worker (written by packet 02): `double_review_required` (boolean — the trigger), `gate_mode` (`shadow`|`gate` — the authority guard), `risk_rationale` (string), `risk_score` (number). There is NO `risk_class`/`review_risk_class` key.
- The dual-pass capability flag/parameter is packet 03's contract — invoke it; do not reimplement the substrate.
- The dual-CLI synthesized-verdict output to the PR comment is the ADR-0086 D8 contract — unchanged.
