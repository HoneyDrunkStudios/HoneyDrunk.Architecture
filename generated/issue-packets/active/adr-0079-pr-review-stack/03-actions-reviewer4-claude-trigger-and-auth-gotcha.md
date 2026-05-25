---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "meta", "adr-0079", "wave-2"]
dependencies: ["packet:00", "packet:02"]
adrs: ["ADR-0079", "ADR-0044", "ADR-0012"]
accepts: ["ADR-0079"]
wave: 2
initiative: adr-0079-pr-review-stack
node: honeydrunk-actions
---

# Wire the Reviewer 4 trigger (Anthropic-native Claude Code on the web) gated on substantive PRs and document the `ANTHROPIC_API_KEY` auth-precedence gotcha

## Summary
Author the workflow that triggers **Reviewer 4** per ADR-0079 D2 — the same `.claude/agents/review.md` Grid-aware agent executed through Anthropic's native Claude Code on the web GitHub integration, billed against the Claude Max Agent SDK credit pool — gated on packet 02's `is_substantive` output and the explicit `enabled` flag (which stays off until the June 15 2026 credit-pool launch). Document the ADR-0079 D8 auth-precedence gotcha (`ANTHROPIC_API_KEY` in the runner environment silently flips Claude execution to per-token billing) in the runner-configuration docs and at the top of the workflow file itself.

## Target Workflow
**Files:**
- `.github/workflows/job-claude-review.yml` (new — name and exact path subject to GitHub Actions convention at execution time; if a more idiomatic name exists in the Grid's workflow taxonomy, prefer it and document the choice).
- The runner-configuration docs that the Grid keeps for `HoneyDrunk.Actions` (e.g. `docs/runner-configuration.md` if it exists; otherwise the consumer-usage doc with a dedicated section).

**Family:** pr-core / review-request.

## Motivation
ADR-0079 D2 names Reviewer 4 as the canonical satisfaction of Invariant 53's "two independent Grid-aware perspectives" requirement: the same `.claude/agents/review.md` definition, executed through Anthropic's native Claude Code on the web GitHub integration, against the Claude Max Agent SDK credit pool (available from **June 15, 2026**). The execution path does **not** go through OpenClaw — Anthropic's native integration is its own runtime per D2's "Trigger path" callout.

ADR-0079 D8 codifies the **auth-precedence gotcha** as invariant 57: setting `ANTHROPIC_API_KEY` in the runner environment silently flips the Claude execution to per-token API billing (the SDK prefers env-var auth over session credentials). Per-token billing for Reviewer 4 is **explicitly out of scope by default** per ADR-0079 D6; opting in requires an ADR amendment. The mitigation is documenting the gotcha at every runner-configuration touchpoint and enforcing the default-unset rule at the workflow level.

ADR-0079 D7 names the **pre-June-15 transition state**: until the Agent SDK credit pool is available, Reviewer 4 does not run, and the workflow's `enabled` gate stays off. This packet ships the workflow file with the gate off; flipping it on is a one-line edit + an ADR-0079-mandated invariant-53-satisfaction-now-complete log entry.

### Gate: this packet authors against post-June-15 2026 Anthropic documentation

**The Anthropic native Claude Code on the web GitHub integration's workflow shape (event triggers, credential mechanism, error signals for credit-pool exhaustion, payload shape) is not fully documented as of this packet's authoring (2026-05-24).** The June 15 2026 Claude Agent SDK credit-pool launch is expected to be accompanied by official documentation describing the GitHub-integration shape that this workflow must conform to.

**Implementer gate:** before authoring `job-claude-review.yml`, confirm Anthropic's official documentation for the Claude Code on the web GitHub integration is available. If it is not (e.g., the implementer reaches this packet before June 15 2026 or shortly after with no docs visible yet), **defer this packet** and file a discovery follow-up to monitor for the docs. Do not author the workflow from inference. The pre-June-15 transition state per ADR-0079 D7 is the operating mode until the workflow lands.

The Proposed Change section below describes the **intended shape**; the implementer adapts to the actual documented surface at the moment of authoring. Where the Proposed Change makes a structural assumption that the docs override, the docs win; record the deviation in the workflow's header comment and in `CHANGELOG.md`.

## Proposed Change

### New workflow: `job-claude-review.yml`
A new reusable workflow that:
1. **Gates on three conditions:**
   - `enabled` input is `true` (default `false` — flipped on by the operator at or after June 15, 2026).
   - `is_substantive` input is `true` (read from packet 02's classifier output by the caller workflow).
   - The PR is not a draft (per ADR-0044 D1's cost discipline; the upstream `job-review-request.yml` already filters this, but the gate is repeated here for defense-in-depth).
2. **Authenticates via Anthropic's native session credentials**, **not** an `ANTHROPIC_API_KEY` environment variable. The exact credential mechanism depends on Anthropic's GitHub integration shape at execution time — research the documented mechanism (typically a session-credential secret stored at the runner level, configured once via the Claude Code on the web GitHub App installation). Document the choice.
3. **Loads `.claude/agents/review.md`** from the consuming repo's checkout — the same agent definition Reviewer 3 (Codex/OpenClaw) consumes per invariant `{N3}` (packet 00). The shared-agent-definition rule is the structural enforcement of the "two execution paths, one source of truth" discipline.
4. **Loads Grid context** the same way Reviewer 3 does — invariants, ADRs, catalogs, the packet via PR-body link (per ADR-0044 D2's context-loading contract; the review-agent's context-loading section in `.claude/agents/review.md` is the source of truth).
5. **Posts the Reviewer 4 verdict** as a separate PR comment (per ADR-0079 D9 — there is no cross-reviewer verdict aggregation; each reviewer posts its own comment).
6. **Falls back gracefully** if the Agent SDK credit pool is exhausted: per ADR-0079 D6, Reviewer 4 is **skipped** on subsequent PRs that day with an advisory comment. Per-token API billing as a fallback is **forbidden by default** (opting in requires an ADR amendment). The workflow detects credit-pool exhaustion via the Anthropic SDK's documented error signal and exits with a "skipped — credit pool exhausted" comment, **not** by falling through to API billing.

### Gate the workflow off by default
The new `enabled` input defaults to `false`. The caller workflow (`pr-core.yml` or `job-review-request.yml`) invokes `job-claude-review.yml` with `enabled: false` until the operator flips it on at or after June 15, 2026. The flip is a one-line edit + a CHANGELOG entry noting "Reviewer 4 enabled — Invariant 53 fully satisfied on substantive PRs."

### Top-of-file gotcha banner
The workflow file (`job-claude-review.yml`) carries a prominent header comment naming the `ANTHROPIC_API_KEY` rule:

```yaml
# ==============================================================================
# Reviewer 4 — Grid-Aware Agent via Anthropic-Native Claude Code
# ==============================================================================
# Source ADR: ADR-0079 D2.
# Invariant {N3} (packet 00): this workflow consumes .claude/agents/review.md —
# the SAME agent definition Reviewer 3 (Codex/OpenClaw) consumes. Drift between
# execution paths is forbidden.
# Invariant {N4} (packet 00): do NOT set ANTHROPIC_API_KEY in the runner
# environment of this workflow. The Agent SDK credit pool is consumed when
# authentication is via the operator's Claude Max session credentials. Setting
# ANTHROPIC_API_KEY silently flips execution to per-token API billing — which
# is explicitly out of scope per ADR-0079 D6 (an ADR amendment is required to
# opt in).
# ==============================================================================
```

### Runner-configuration docs
Add (or extend the existing equivalent) a `docs/runner-configuration.md` section titled "Reviewer 4 — `ANTHROPIC_API_KEY` precedence" with the following content:

- The Agent SDK credit pool is consumed when the runner authenticates as the operator's Claude Max session (via the Claude Code on the web GitHub integration's session credentials).
- If a runner environment variable named `ANTHROPIC_API_KEY` is set, the SDK uses it preferentially and per-token API billing applies silently. The operator may not notice for a billing cycle.
- The default Reviewer 4 runner configuration leaves `ANTHROPIC_API_KEY` unset.
- Operator-facing checklist for setting up Reviewer 4: install the Claude Code on the web GitHub App on the relevant repos; configure session credentials via the documented Anthropic mechanism; verify `ANTHROPIC_API_KEY` is **not** set in the runner environment; enable the workflow gate.
- Opting into per-token billing is forbidden by default; requires an ADR-0079 amendment.

### No change to Reviewers 1, 2, or 3
Reviewers 1 (Copilot), 2 (CodeRabbit), and 3 (Grid-aware via Codex/OpenClaw) continue to run on every non-draft PR. Per ADR-0079 D9, only Reviewer 4 is gated on `is_substantive`.

## Consumer Impact
- No PR sees Reviewer 4 behavior **until** the operator flips the `enabled` gate post-June-15. Existing reviewer behavior is unchanged.
- The runner-configuration docs gain an operator-facing checklist for Reviewer 4 enablement.
- The workflow file itself is inert until the gate flips — landing the file before June 15 is safe.

## Breaking Change?
- [ ] Yes
- [x] No — the new workflow defaults to disabled; flipping it on is a deliberate operator action post-June-15.

## Acceptance Criteria
- [ ] **Pre-authoring gate confirmed:** Anthropic's official documentation for the Claude Code on the web GitHub integration is available at the moment of authoring; if not, this packet is deferred and a discovery follow-up is filed. Record the docs URL consulted in the workflow's header comment.
- [ ] `.github/workflows/job-claude-review.yml` (or the chosen idiomatic name) exists and contains the Reviewer 4 reusable workflow per Proposed Change (adapted to the actual documented surface — docs win where they override the Proposed Change's structural assumptions)
- [ ] The workflow gates on `enabled` (default `false`), `is_substantive` (from packet 02's output), and non-draft PR status; all three must be true for Reviewer 4 to run
- [ ] The workflow loads `.claude/agents/review.md` from the consuming repo's checkout — the same agent definition Reviewer 3 consumes (invariant `{N3}`)
- [ ] The workflow authenticates via Anthropic's documented native session-credential mechanism; the workflow file does **not** set or rely on `ANTHROPIC_API_KEY` (invariant `{N4}`)
- [ ] The workflow falls back gracefully on Agent SDK credit-pool exhaustion: posts a "skipped — credit pool exhausted" comment and exits; does **not** fall through to per-token API billing (ADR-0079 D6)
- [ ] The workflow posts its verdict as a **separate** PR comment (no cross-reviewer aggregation per ADR-0079 D9)
- [ ] The workflow file carries the prominent top-of-file gotcha banner naming invariant `{N3}` (shared agent definition) and invariant `{N4}` (no `ANTHROPIC_API_KEY`)
- [ ] `docs/runner-configuration.md` (or the equivalent referenced docs) carries a "Reviewer 4 — `ANTHROPIC_API_KEY` precedence" section documenting the gotcha and the operator-facing enablement checklist
- [ ] No change to Reviewers 1, 2, or 3 — they continue to run on every non-draft PR
- [ ] No new secret committed to the repo (invariant 8); session credentials are configured at the runner level via the documented Anthropic mechanism
- [ ] The repo `CHANGELOG.md` is updated if the repo keeps one for the workflow surface, noting the workflow lands disabled and naming the docs URL the workflow was authored against
- [ ] Existing consumers of the PR-review workflows are unaffected — additive change only

## Human Prerequisites
- [ ] **Anthropic's Claude Code on the web GitHub integration documentation is available.** This packet's authoring is gated on documented workflow shape (event triggers, credential mechanism, error signals). If the documentation is not yet available at the moment of authoring, defer this packet and file a discovery follow-up.
- [ ] **Anthropic native Claude Code on the web GitHub App installed** on the relevant repos. One-time portal step per repo or per-organization. The workflow is inert without it.
- [ ] **Claude Max session credentials configured** at the runner level per Anthropic's documented mechanism. The exact configuration shape may change between the packet authoring (2026-05-24) and June 15 launch — the workflow author researches the current documented surface at execution time.
- [ ] **Explicit operator decision to flip the `enabled` gate** at or after June 15, 2026. This is the moment Invariant 53 transitions from "degraded-but-honest" to "fully satisfied on substantive PRs." Record the flip in `CHANGELOG.md` and in the dispatch plan.
- [ ] **Verify `ANTHROPIC_API_KEY` is not set** in the runner environment for this workflow before enabling. The gotcha is silent — the operator must check explicitly.

## Referenced ADR Decisions
**ADR-0079 D2 — Reviewer 4 is the Grid-aware `review` agent via Anthropic-native Claude Code on the web.** Same `.claude/agents/review.md` agent definition as Reviewer 3, executed through Anthropic's native Claude Code on the web GitHub integration. Trigger path: GitHub webhook → Anthropic's native integration → Claude Code on the web session → agent execution → PR comment. Billing: against the operator's Claude Max Agent SDK credit pool, available from June 15, 2026.

**ADR-0079 D6 — Per-token Anthropic API billing as a fallback is out of scope by default.** If the Agent SDK credit pool is exhausted, Reviewer 4 is skipped on subsequent PRs that day with an advisory comment. Opting into per-token billing requires an ADR amendment.

**ADR-0079 D7 — Pre-June-15 transition state.** Reviewer 4 does not run until the Agent SDK credit pool is available. Invariant 53's full satisfaction degrades to "single Grid-aware perspective + two generic perspectives" until then — degraded-but-honest.

**ADR-0079 D8 — `ANTHROPIC_API_KEY` auth-precedence gotcha.** Setting `ANTHROPIC_API_KEY` in the runner environment silently flips Claude execution to per-token billing. Codified as invariant `{N4}`. The gotcha is documented at the runner-configuration level and at the top of the workflow file.

**ADR-0079 D9 — Each reviewer posts its own PR comment.** No cross-reviewer verdict aggregation; aggregation is a future-state concern.

**Invariant `{N3}` (packet 00) — Shared agent definition across execution paths.** Both Reviewer 3 (Codex/OpenClaw) and Reviewer 4 (Anthropic-native Claude) consume the same `.claude/agents/review.md` definition. Drift between execution paths is forbidden.

**Invariant `{N4}` (packet 00) — `ANTHROPIC_API_KEY` not set in Reviewer 4 runner environment by default.** Codified rule; per-token billing is opt-in via ADR amendment only.

**Invariant 8 (referenced) — Secret values never appear in workflow files.** Session credentials are configured at the runner level via Anthropic's documented mechanism; no secret value is committed to the repo.

## Constraints
> **Invariant 8 — Secret values never appear in workflow files.** No DSN, no API key, no session-credential value is committed. The runner-level credential configuration is the operator's responsibility per Human Prerequisites.

> **Invariant `{N3}` — Shared agent definition across execution paths.** This workflow loads `.claude/agents/review.md` from the consuming repo's checkout — the same file Reviewer 3 (Codex/OpenClaw) consumes. The two execution paths must consume the same agent definition; drift is forbidden.

> **Invariant `{N4}` — `ANTHROPIC_API_KEY` not set in the Reviewer 4 runner environment by default.** The workflow file does not set this variable; the runner-configuration docs name the rule; the operator-facing checklist verifies the variable is unset before enabling Reviewer 4.

- **Default `enabled: false`.** The workflow ships disabled. Flipping it on is a deliberate post-June-15 operator action.
- **No fallback to per-token billing.** Credit-pool exhaustion → skip + advisory comment. Falling through to API billing is forbidden by default (ADR-0079 D6).
- **Separate PR comment.** No cross-reviewer aggregation (ADR-0079 D9).
- **Defense-in-depth gating.** The workflow re-checks `is_substantive` and the draft-PR filter even though the caller workflow filters them — the cost of an accidental Reviewer 4 run on a trivial or draft PR is non-zero credit-pool consumption.

## Labels
`ci`, `tier-2`, `meta`, `adr-0079`, `wave-2`

## Agent Handoff

**Objective:** Author the Reviewer 4 reusable workflow (Anthropic-native Claude Code) gated on `is_substantive` and the explicit `enabled` flag (default off until June 15, 2026); document the `ANTHROPIC_API_KEY` auth-precedence gotcha at the runner-configuration level and at the top of the workflow file.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ship the Reviewer 4 trigger workflow as the second Grid-aware reviewer (same agent definition, different model family) — the canonical satisfaction of Invariant 53 per ADR-0079 D7.
- Feature: ADR-0079 Multi-Perspective PR Review Stack rollout, Wave 2.
- ADRs: ADR-0079 D2/D6/D7/D8/D9 (primary), ADR-0044 (the Grid-aware-reviewer baseline ADR-0079 amends), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — hard. Reviewer 4's invariant backing (`{N1}`, `{N3}`, `{N4}`) lands in packet 00.
- `packet:02` — hard. The `is_substantive` output the gate consumes is packet 02's deliverable.
- **Anthropic docs availability** — hard external gate. The Claude Code on the web GitHub integration's workflow shape must be documented at the moment of authoring; if not, defer.

**Constraints:**
- Default `enabled: false`; flipped on by deliberate operator action post-June-15.
- No fallback to per-token API billing on credit-pool exhaustion (ADR-0079 D6).
- Shared agent definition (invariant `{N3}`) — load `.claude/agents/review.md` from the consuming repo.
- `ANTHROPIC_API_KEY` unset in the runner environment by default (invariant `{N4}`).
- Separate PR comment, no cross-reviewer aggregation (ADR-0079 D9).
- No secret committed (invariant 8).
- Docs-availability gate — defer if Anthropic's documentation for the Claude Code on the web GitHub integration is not available at the moment of authoring.

**Key Files:**
- `.github/workflows/job-claude-review.yml` (new).
- `docs/runner-configuration.md` (or the equivalent referenced docs).
- `docs/consumer-usage.md` (or the equivalent — note the new gated workflow).
- `CHANGELOG.md` (if maintained for the workflow surface).

**Contracts:** Consumes packet 02's `is_substantive` workflow output. Loads `.claude/agents/review.md` per invariant 56.
