---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-1", "meta", "adr-0044", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
---

# Author the .honeydrunk-review.yaml v1 schema doc

## Summary
Author `copilot/review-config-schema.md` documenting the v1 schema of the per-repo `.honeydrunk-review.yaml` configuration file the cloud reviewer consumes — the enabled gate plus the four v1 knobs — so every repo onboarding in Phase 2 has a single authoritative reference.

## Summary of the work
ADR-0044 D4 defines the per-repo `.honeydrunk-review.yaml` config. The `job-review-agent.yml` workflow (packet 03) reads it; Phase 2 repo onboardings (packets 09-14) each author one. Without a schema doc, each onboarding re-derives the schema from the ADR and drift creeps in. This packet writes the canonical schema reference once.

## Context
ADR-0044 D4 deliberately keeps the v1 schema minimal — its primary purpose is the **enabled/disabled gate** during phased rollout. Per-path review-instruction overrides (the CodeRabbit-style `path_instructions` surface) are explicitly deferred to a polish phase (D11 Phase 4) and must **not** appear in the v1 doc. The doc lives under `copilot/` alongside `pr-review-rules.md` and `issue-authoring-rules.md` — the existing home for review-tooling reference docs.

## Scope
- New file `copilot/review-config-schema.md`.
- A cross-link added from `copilot/pr-review-rules.md` (one line pointing to the new schema doc).

## Proposed Implementation
The doc documents the v1 schema verbatim from ADR-0044 D4:

```yaml
enabled: true                # required; default-off until repo opts in (D11)
severity_floor: Suggest      # minimum severity for posted findings: Suggest | Request Changes | Block
skip_paths:                  # globs excluded from review
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
model: sonnet                # sonnet | opus; default sonnet, opus for high-risk-Node touches per D8
cost_cap_per_pr_usd: 5.00    # hard ceiling; agent aborts if exceeded mid-review and posts a partial-review comment
```

Each field documented with: type, whether required, default, and behavioral effect. The doc must state:
- A repo with **no** `.honeydrunk-review.yaml` is treated as `enabled: false` — this is the opt-in gate.
- `cost_cap_per_pr_usd` is a hard ceiling; on exceedance the agent posts a partial-review comment and exits cleanly (never silently fails).
- `model` defaults to `sonnet`; `opus` is selected automatically for high-risk-Node touches per D8 (Phase 3) — a repo rarely sets `model` by hand.
- Per-path `path_instructions`-style overrides are **explicitly deferred to a v2 polish phase**; v1 relies on the agent's built-in context loading. If v1 gaps justify them, they land in a documented v2 schema.

Include a worked example for the Architecture repo (the Phase-1 pilot) showing `skip_paths` tuned for a docs/catalog repo.

## Affected Files
- `copilot/review-config-schema.md` (new)
- `copilot/pr-review-rules.md` (one cross-link line)

## NuGet Dependencies
None. This packet creates a Markdown doc; no .NET project is created or modified.

## Boundary Check
- [x] The doc lives in `HoneyDrunk.Architecture` under `copilot/` — the existing home for review-tooling reference docs. Routing rule "architecture, ADR, invariant, catalog → HoneyDrunk.Architecture" maps.
- [x] No code change in any repo.

## Acceptance Criteria
- [ ] `copilot/review-config-schema.md` exists and documents the v1 schema with every field's type, required-ness, default, and behavioral effect
- [ ] The doc states the no-file-means-disabled opt-in gate explicitly
- [ ] The doc states that `path_instructions`-style per-path overrides are deferred to a v2 polish phase
- [ ] The doc includes a worked Architecture-repo example
- [ ] `copilot/pr-review-rules.md` carries a cross-link to the new schema doc
- [ ] No v2/polish fields appear in the v1 schema

## Human Prerequisites
None. This is a pure Architecture-repo doc edit.

## Dependencies
- `packet:01` — ADR-0044 acceptance (soft; the doc references ADR-0044 D4 as a live rule).

## Referenced ADR Decisions

**ADR-0044 D4** — `.honeydrunk-review.yaml` v1 schema: `enabled` (required, default-off), `severity_floor`, `skip_paths`, `model`, `cost_cap_per_pr_usd`. Repos without the file are `enabled: false`. Per-path overrides deferred to a polish phase.
**ADR-0044 D11** — Four-phase rollout; the config file's primary v1 purpose is the enabled gate during phased rollout.

## Constraints
- **v1 schema only.** Do not document `path_instructions` or any polish-phase field — ADR-0044 D4 explicitly defers them.
- The doc is a reference, not a tutorial; keep it tight and authoritative.

## Labels
`docs`, `tier-1`, `meta`, `adr-0044`, `wave-1`

## Agent Handoff

**Objective:** Author `copilot/review-config-schema.md` documenting the `.honeydrunk-review.yaml` v1 schema per ADR-0044 D4, with a worked Architecture-repo example, and cross-link it from `pr-review-rules.md`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Provide a single authoritative schema reference for every Phase-2 repo onboarding.
- Feature: ADR-0044 Cloud Code Review rollout, Phase 1.
- ADRs: ADR-0044 (D4, D11).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0044 acceptance (soft).

**Constraints:**
- v1 schema only; no polish-phase fields.

**Key Files:**
- `copilot/review-config-schema.md` (new)
- `copilot/pr-review-rules.md`

**Contracts:** None.
