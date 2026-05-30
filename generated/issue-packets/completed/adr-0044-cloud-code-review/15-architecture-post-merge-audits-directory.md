---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-1", "meta", "adr-0044", "wave-4"]
dependencies: ["packet:01"]
adrs: ["ADR-0044", "ADR-0043"]
accepts: ["ADR-0044"]
wave: 4
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Create the generated/post-merge-audits/ directory with a README

## Summary
Create the `generated/post-merge-audits/` directory in `HoneyDrunk.Architecture` with a README documenting its purpose, the file-naming convention, and how D9 sampling-audit output lands here.

## Context
ADR-0044 D9 establishes a post-merge sampling audit: every Nth agent-authored merged PR is selected for a deeper `/ultrareview` audit, and the output is committed to `generated/post-merge-audits/{YYYY-MM-DD}-{repo}-{pr-number}.md`. The `audit-sample` labeling job (packet 16) and the audit run depend on this directory existing with a documented convention. This packet creates the directory ahead of D9 activation so the audit-output commits have a defined home.

## Scope
- New directory `generated/post-merge-audits/`.
- New `generated/post-merge-audits/README.md`.

## Proposed Implementation
The README documents:
- **Purpose** — the directory holds post-merge sampling-audit reports per ADR-0044 D9. The audit measures **the review process's own quality**, not individual bugs (the code already shipped).
- **File-naming convention** — `{YYYY-MM-DD}-{repo}-{pr-number}.md`, e.g. `2026-07-14-honeydrunk-kernel-218.md`.
- **How files land here** — D9's audit runs `/ultrareview` against the merged PR's diff; the output is committed here. Selection is automatic — CI labels every Nth agent-authored merged PR `audit-sample` at merge time (N starts at 10, tunable via the weekly briefing per ADR-0043).
- **Downstream flow** — findings at `Block` or `Request Changes` severity become Reactive packets per ADR-0043's Reactive source taxonomy. Findings also feed back into `.claude/agents/review.md` and ADR-0044 itself.
- A `.gitkeep` is not needed once the README exists — the README keeps the directory tracked.

Match the format of other `generated/` subdirectory READMEs (e.g. `generated/incidents/`, `generated/issue-packets/`) for consistency.

## Affected Files
- `generated/post-merge-audits/README.md` (new)

## NuGet Dependencies
None. This packet creates a directory and a Markdown README; no .NET project is created or modified.

## Boundary Check
- [x] `generated/` subdirectories live in `HoneyDrunk.Architecture` — correct repo (the ADR's Consequences name this repo explicitly).
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `generated/post-merge-audits/` exists and is tracked (via its README)
- [ ] `generated/post-merge-audits/README.md` documents purpose, the `{YYYY-MM-DD}-{repo}-{pr-number}.md` naming convention, how files land, and the ADR-0043 Reactive-packet downstream flow
- [ ] The README format is consistent with other `generated/` subdirectory READMEs
- [ ] The README states the audit measures review-process quality, not shipped bugs

## Human Prerequisites
None. Pure Architecture-repo directory + doc creation.

## Dependencies
- `packet:01` — ADR-0044 acceptance (soft; D9 is a live binding once ADR-0044 is Accepted).

## Referenced ADR Decisions

**ADR-0044 D9** — Post-merge sampling audit: every Nth agent-authored merged PR is `audit-sample`-labeled at merge; the audit runs `/ultrareview`; output commits to `generated/post-merge-audits/{YYYY-MM-DD}-{repo}-{pr-number}.md`; `Block`/`Request Changes` findings become Reactive packets per ADR-0043; the audit measures review-process quality.
**ADR-0043** — Reactive source taxonomy; weekly briefing tunes N.

## Constraints
- Match the existing `generated/` README format.
- The directory is a passive landing zone — no tooling logic in this packet (the `audit-sample` job is packet 16).

## Labels
`docs`, `tier-1`, `meta`, `adr-0044`, `wave-4`

## Agent Handoff

**Objective:** Create `generated/post-merge-audits/` with a README documenting D9's sampling-audit output convention.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give D9's audit output a defined home before D9 activates.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 4.
- ADRs: ADR-0044 (D9), ADR-0043 (Reactive source).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0044 acceptance (soft).

**Constraints:**
- Match existing `generated/` README format; passive landing zone only.

**Key Files:**
- `generated/post-merge-audits/README.md` (new)

**Contracts:** None.
