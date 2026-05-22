---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ops", "adr-0044", "wave-2"]
dependencies: ["packet:07"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 2
initiative: adr-0044-cloud-code-review
node: honeydrunk-actions
---

# Seed large-pr, audit-sample, and skip-review labels Grid-wide

## Summary
Add the `large-pr`, `audit-sample`, and `skip-review` labels to the labels-as-code config and fan them out across every Grid repo using the existing labels-as-code / `seed-labels-fanout.yml` pattern established by the ADR-0011 rollout.

## Target Workflow
**File:** the labels-as-code config (e.g. `labels.yml`) and `seed-labels-fanout.yml`
**Family:** manual / labels-as-code

## Motivation
ADR-0044's discipline machinery references three labels that must exist on every repo before the corresponding checks can apply them: `large-pr` (D7, auto-applied to PRs > 400 lines), `audit-sample` (D9, auto-applied to the Nth merged agent PR), and `skip-review` (D5, the manual escape hatch the cloud reviewer honors). The ADR-0011 rollout already established a labels-as-code config and a `seed-labels-fanout.yml` fan-out workflow with a scoped PAT — this packet extends that config and re-runs the fan-out. Without the labels in place, `pr-size-check` (packet 07) and the `audit-sample` job (packet 16) auto-apply labels that do not exist.

## Proposed Change
- Add three label definitions to the labels-as-code config:
  - `large-pr` — applied to non-`human` PRs of 400-800 changed lines (D7).
  - `audit-sample` — applied at merge time to the Nth agent-authored PR selected for post-merge audit (D9).
  - `skip-review` — manual escape hatch; the cloud reviewer skips PRs carrying it (D5).
- Re-run `seed-labels-fanout.yml` to apply the three labels across every Grid repo (the same repo set the ADR-0011 fan-out used — all 12 live Nodes, which already includes Architecture and Studios).
- Pick colors/descriptions consistent with the existing label palette.

## Consumer Impact
- Every Grid repo gains three labels. Purely additive — no existing label changes.

## Breaking Change?
- [ ] Yes
- [x] No — additive label seeding via the established idempotent fan-out.

## Acceptance Criteria
- [ ] The labels-as-code config defines `large-pr`, `audit-sample`, and `skip-review` with colors/descriptions
- [ ] `seed-labels-fanout.yml` has been run and all three labels exist on every Grid repo (verified by browsing each repo's `/labels` page)
- [ ] The fan-out is idempotent — re-running it does not error or duplicate
- [ ] `docs/CHANGELOG.md` updated

## Human Prerequisites
- [ ] Confirm the `LABELS_FANOUT_PAT` from the ADR-0011 rollout is still valid and scoped to the full repo set; refresh if expired
- [ ] Trigger the `seed-labels-fanout.yml` `workflow_dispatch` run

## Dependencies
- `packet:07` — authorship/pr-size checks (soft; `large-pr` is the label `pr-size-check` applies — seeding it before or alongside packet 07's landing avoids a window where the check applies a non-existent label).

## Referenced ADR Decisions

**ADR-0044 D5** — `skip-review` label is the manual escape hatch the cloud reviewer honors.
**ADR-0044 D7** — `large-pr` label auto-applied to non-`human` PRs of 400-800 changed lines.
**ADR-0044 D9** — `audit-sample` label auto-applied at merge time to the Nth agent-authored PR.
**ADR-0044 Consequences** — "Every Grid repo (eventually) — adds `.honeydrunk-review.yaml`, `large-pr` and `audit-sample` labels via the existing label-setup pattern."

## Constraints
- **Use the existing labels-as-code pattern** from the ADR-0011 rollout — do not invent a new mechanism.
- The fan-out must stay idempotent.

## Labels
`chore`, `tier-1`, `ops`, `adr-0044`, `wave-2`

## Agent Handoff

**Objective:** Add `large-pr`, `audit-sample`, `skip-review` to the labels-as-code config and fan them out Grid-wide via `seed-labels-fanout.yml`.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ensure the three discipline labels exist on every repo before the checks that apply them activate.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 2.
- ADRs: ADR-0044 (D5, D7, D9).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:07` — authorship/pr-size checks (soft).

**Constraints:**
- Reuse the existing labels-as-code / fan-out pattern; keep it idempotent.

**Key Files:**
- the labels-as-code config (`labels.yml` or equivalent)
- `.github/workflows/seed-labels-fanout.yml`
- `docs/CHANGELOG.md`

**Contracts:** None.
