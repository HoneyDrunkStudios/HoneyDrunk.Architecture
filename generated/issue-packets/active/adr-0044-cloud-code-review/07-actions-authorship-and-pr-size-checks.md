---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "adr-0044", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0044", "ADR-0012"]
accepts: ["ADR-0044"]
wave: 2
initiative: adr-0044-cloud-code-review
node: honeydrunk-actions
---

# Add authorship-check and pr-size-check jobs to pr-core.yml

## Summary
Add two new jobs to `HoneyDrunk.Actions/.github/workflows/pr-core.yml`: `authorship-check`, which verifies every PR body declares a parseable `Authorship:` line (D6); and `pr-size-check`, which enforces the soft size cap on non-`human` PRs (D7) — warnings-only at this Phase-2 stage.

## Target Workflow
**File:** `.github/workflows/pr-core.yml`
**Family:** pr-core

## Motivation
ADR-0044 D6 requires every PR to declare an authorship class (`human`, `agent-codex`, `agent-copilot`, `agent-claude-code`, `mixed`) in a single `Authorship: <class>` line, verified by a CI check whose absence fails. D7 adds a soft size cap on non-`human` PRs to catch PR sprawl — the most common AI-authorship failure mode — before review effort is spent on it. Both checks belong in `pr-core.yml` (the shared tier-1 caller) so the whole Grid inherits them when Phase 2 activates discipline. Per D11 Phase 2, PR-size discipline "activates with warnings only" — the `> 800` auto-comment escalation is held until Phase 3.

## Proposed Change

### `authorship-check` job (D6)
- Parses the PR body for a line matching `Authorship: <class>` where `<class>` is one of `human`, `agent-codex`, `agent-copilot`, `agent-claude-code`, `mixed`.
- **Absence or an unparseable value fails the check** (required per D6).
- `human` is the documented default for any PR that does not declare otherwise — but the line must still be *present*; the check does not silently assume `human`.
- The parsed authorship class is exported as a job output so `pr-size-check` can consume it.

### `pr-size-check` job (D7)
Consumes the authorship class from `authorship-check`. For **non-`human`** PRs, computes changed lines excluding `skip_paths` (from `.honeydrunk-review.yaml`) and excluding test code:
- **≤ 400 changed lines** — normal path, no action.
- **> 400, ≤ 800** — the PR body must include a `Size justification:` block; the job auto-applies the `large-pr` label. If the block is missing, the job posts a comment requesting it (warnings-only — does not fail at Phase 2).
- **> 800** — the job auto-comments requesting a split or a `refine` pass. **Phase 2: warnings-only — the comment posts but the check does not fail.** (Phase 3 moves the `> 800` threshold from warning to a harder posture per packet 16; this packet must leave a clear, single-line toggle/comment so packet 16's change is surgical.)
- For `human` PRs, `pr-size-check` is a no-op.

### Phasing note
Both jobs are added in Phase 2. `authorship-check` is enforcing from the start (D6 says absence fails). `pr-size-check` is warnings-only in Phase 2 (D11). Document the Phase-3 tightening point inline so packet 16 is a one-line change.

## Consumer Impact
- Every repo that calls `pr-core.yml` inherits both jobs. This is Grid-wide once Phase 2 rolls out — the per-repo onboarding packets (09-14) do not need to wire these jobs; they come for free via `pr-core.yml`.
- `authorship-check` will fail PRs that lack the `Authorship:` line. The execution-surface amendments (packet 11 for Codex, packet 12 for Claude Code) emit the line automatically; human PRs need the line added manually (one line, documented in the PR template).

## Breaking Change?
- [x] Yes — `authorship-check` fails PRs without an `Authorship:` line. Consumers must update PR templates and execution surfaces (packets 11, 12) before or alongside this landing.
- [ ] No

## Acceptance Criteria
- [ ] `pr-core.yml` has an `authorship-check` job that fails when the `Authorship:` line is absent or unparseable, and accepts exactly the five classes
- [ ] `authorship-check` exports the parsed class as a job output
- [ ] `pr-core.yml` has a `pr-size-check` job consuming the authorship class; no-op for `human` PRs
- [ ] `pr-size-check` excludes `skip_paths` and test code from the line count
- [ ] `> 400, ≤ 800` auto-applies `large-pr` and requires/requests a `Size justification:` block
- [ ] `> 800` auto-comments requesting a split or `refine` pass; **Phase-2 warnings-only — does not fail the check** — with an inline-documented single-point toggle for Phase 3
- [ ] `docs/CHANGELOG.md` updated; `docs/consumer-usage.md` notes the new required `Authorship:` line and the warnings-only size discipline
- [ ] The PR template (in `HoneyDrunk.Actions` if one is templated centrally, else noted for per-repo follow-up) carries the `Authorship:` line placeholder

## Human Prerequisites
- [ ] Decide whether the `Authorship:` PR-template line is templated centrally or per-repo, and coordinate the rollout so `authorship-check` does not fail in-flight PRs across the Grid the moment it lands
- [ ] Ensure the `large-pr` label exists on consumer repos (packet 08 seeds it Grid-wide)

## Dependencies
- `packet:01` — ADR-0044 acceptance (soft; references D6/D7 as live rules).

## Referenced ADR Decisions

**ADR-0044 D6** — Every PR declares `Authorship: <class>` in the body; classes are `human`, `agent-codex`, `agent-copilot`, `agent-claude-code`, `mixed`; a `pr-core.yml` CI check verifies presence and parseability, absence fails.
**ADR-0044 D7** — Non-`human` PRs carry a soft size cap via `pr-size-check`: ≤ 400 normal; > 400 ≤ 800 needs a `Size justification:` block + `large-pr` label; > 800 auto-comments requesting a split/refine.
**ADR-0044 D11 Phase 2** — Authorship classification becomes mandatory; PR-size discipline activates with warnings only.
**ADR-0044 D11 Phase 3** — PR-size discipline moves from warnings to auto-comments at the > 800 threshold (packet 16).

## Constraints
> **Invariant 31:** Every PR traverses the tier-1 gate before merge. `authorship-check` becomes part of that gate; `pr-size-check` is warnings-only in Phase 2 and does not gate.

- **Warnings-only for `> 800` in Phase 2.** Per D11, the harder posture is Phase 3. Leave a surgical single-point toggle for packet 16.
- **`authorship-check` does not assume `human`.** The line must be present; absence fails.
- Follow the existing `pr-core.yml` job factoring (ADR-0012).

## Labels
`ci`, `tier-2`, `ops`, `adr-0044`, `wave-2`

## Agent Handoff

**Objective:** Add `authorship-check` (D6) and `pr-size-check` (D7, warnings-only) jobs to `pr-core.yml`.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Make authorship classification mandatory and PR-size discipline visible Grid-wide as Phase 2 activates.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 2.
- ADRs: ADR-0044 (D6, D7, D11), ADR-0012 (pr-core factoring).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0044 acceptance (soft).

**Constraints:**
- `> 800` is warnings-only in Phase 2; leave a one-point toggle for Phase 3 (packet 16).
- `authorship-check` requires the line present; never assumes `human`.

**Key Files:**
- `.github/workflows/pr-core.yml`
- `docs/CHANGELOG.md`
- `docs/consumer-usage.md`

**Contracts:** Consumes `.honeydrunk-review.yaml` `skip_paths`; emits the `authorship-check` job output consumed by `pr-size-check`.
