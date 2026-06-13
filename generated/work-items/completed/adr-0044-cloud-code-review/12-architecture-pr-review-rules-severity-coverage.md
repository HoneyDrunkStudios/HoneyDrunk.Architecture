---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-1", "meta", "adr-0044", "wave-2"]
dependencies: ["work-item:04"]
adrs: ["ADR-0044", "ADR-0011"]
accepts: ["ADR-0044"]
wave: 2
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Verify pr-review-rules.md covers the severity taxonomy across all twenty D3 categories

## Summary
Audit `copilot/pr-review-rules.md` to confirm it covers the `Block` / `Request Changes` / `Suggest` severity taxonomy across all twenty ADR-0044 D3 categories, and expand it where gaps exist.

## Context
ADR-0044's Follow-up Work calls to "verify `copilot/pr-review-rules.md` covers the severity taxonomy across all twenty D3 categories; expand where gaps exist." `pr-review-rules.md` is the canonical severity-taxonomy reference — `review.md` (packet 04) maps each category's findings to a severity, and the per-category execution detail there points at this file. If `pr-review-rules.md` predates the twenty-category rubric, some categories (notably the newer ones — AI/agent-specific, anti-entropy, distributed systems) may have no severity guidance. This packet closes that gap.

## Scope
- `copilot/pr-review-rules.md` — audit and expand.

## Proposed Implementation
1. Read `copilot/pr-review-rules.md` and the twenty-category rubric in `review.md` (as authored by packet 04).
2. For each of the twenty D3 categories, confirm `pr-review-rules.md` gives severity guidance — what kind of finding in that category maps to `Block`, what to `Request Changes`, what to `Suggest`.
3. Where a category has no guidance, add it. Pay particular attention to categories likely missing from a pre-rubric version: AI/agent-specific (18), anti-entropy (19), distributed systems (14), enterprise readiness (10), human factors (20).
4. Keep the severity taxonomy definitions themselves stable — `Block` / `Request Changes` / `Suggest` are the established three; this packet maps categories onto them, it does not redefine them.
5. Confirm the cross-link from packet 05's `review-config-schema.md` (the `severity_floor` field references this taxonomy) is consistent.

## Affected Files
- `copilot/pr-review-rules.md`

## NuGet Dependencies
None. This packet edits a Markdown reference doc; no .NET project is created or modified.

## Boundary Check
- [x] `copilot/pr-review-rules.md` lives in `HoneyDrunk.Architecture` — correct repo.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] All twenty D3 categories have severity guidance in `copilot/pr-review-rules.md` (what maps to `Block` / `Request Changes` / `Suggest`)
- [ ] Gaps for the newer categories (AI/agent, anti-entropy, distributed systems, enterprise readiness, human factors) are closed
- [ ] The three severity levels themselves are unchanged — categories are mapped onto them, not redefined
- [ ] The audit outcome (which categories had gaps, what was added) is recorded in the PR body

## Human Prerequisites
None. Pure Architecture-repo doc edit.

## Dependencies
- `work-item:04` — `review.md` twenty-category rubric (**hard** — the audit checks `pr-review-rules.md` against the category names/numbering authored there).

## Referenced ADR Decisions

**ADR-0044 D3 (Severity and the agent-file binding)** — The reviewer comments findings against the twenty categories using the severity taxonomy in `copilot/pr-review-rules.md` (`Block` / `Request Changes` / `Suggest`).
**ADR-0044 Follow-up Work** — "Verify `copilot/pr-review-rules.md` covers the severity taxonomy across all twenty D3 categories; expand where gaps exist."
**ADR-0011** — `pr-review-rules.md` is the established severity-taxonomy reference for the review pipeline.

## Constraints
- **Do not redefine the three severity levels.** Map categories onto the existing `Block` / `Request Changes` / `Suggest`.
- Use the exact category names/numbering from `review.md`.

## Labels
`docs`, `tier-1`, `meta`, `adr-0044`, `wave-2`

## Agent Handoff

**Objective:** Audit `copilot/pr-review-rules.md` for severity-taxonomy coverage across all twenty D3 categories; expand where gaps exist.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ensure every rubric category has severity guidance so the reviewer's verdicts are consistent.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 2.
- ADRs: ADR-0044 (D3), ADR-0011.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:04` — `review.md` rubric (hard).

**Constraints:**
- Do not redefine the severity levels; map categories onto them.

**Key Files:**
- `copilot/pr-review-rules.md`

**Contracts:** None.
