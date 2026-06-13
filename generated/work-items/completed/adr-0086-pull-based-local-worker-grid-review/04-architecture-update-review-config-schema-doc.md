---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-1", "meta", "adr-0086", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0086", "ADR-0044"]
accepts: []
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Update copilot/review-config-schema.md for the new runner enum (drop openclaw-codex, add local-worker default)

## Summary
Update `copilot/review-config-schema.md` for the breaking change ADR-0086 D5 makes to the `.honeydrunk-review.yaml` schema: drop the `openclaw-codex` enum value, add `local-worker` as the new default, preserve `api-ci`. Record the breaking-schema-change disposition and the Phase A → B migration story explicitly.

## Context
ADR-0086 D5 changes the `runner:` field's enum shape:
- `local-worker` (new default) — the worker described in ADR-0086 D1–D4 runs the agent under subscription-backed Codex CLI / Claude Code CLI.
- `api-ci` (preserved) — explicit per-token API fallback. Same constraint as ADR-0044 D5: must set non-zero `cost_cap_per_pr_usd`, must name provider/model, advisory posture preserved.
- `openclaw-codex` (removed) — the v1 default per ADR-0044 D4 (as later refined in the OpenClaw-aware `05b` packet). The enum value is dropped from the schema.

This is a breaking schema change. The impact is small because per ADR-0044 D11 Phase 1 only `HoneyDrunk.Architecture` has actually been opted in to date — the Phase 2 fan-out (ADR-0044 packet 11) was still pending when ADR-0086 was authored, and ADR-0086 supersedes it (this initiative's packet 09 is the replacement fan-out at the new default). The schema doc is the single authoritative reference every Phase B repo onboarding consumes; updating it now keeps every later repo's `.honeydrunk-review.yaml` aligned.

This packet only updates the schema doc. The Architecture-repo `.honeydrunk-review.yaml` migration (`runner: openclaw-codex` → `runner: local-worker`) is the Phase-A cutover packet (07).

## Scope
- `copilot/review-config-schema.md` — drop the `openclaw-codex` enum value, add `local-worker` as the new default, preserve `api-ci`, update the worked example, document the breaking-change disposition.

## Proposed Implementation

Update the schema documentation to reflect ADR-0086 D5 verbatim:

```yaml
enabled: true                # required; default-off until repo opts in
severity_floor: Suggest      # minimum severity for posted findings: Suggest | Request Changes | Block
skip_paths:                  # globs excluded from review
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
runner: local-worker         # local-worker (default) | api-ci
cost_cap_per_pr_usd: 5.00    # only meaningful for runner: api-ci; ignored when runner: local-worker
```

Documentation requirements for the `runner:` field:

- **`local-worker` (default)** — the pull-based local worker described in ADR-0086 D1–D4 runs the canonical `.claude/agents/review.md` agent under the operator's existing Codex CLI / Claude Code CLI subscription sessions. Marginal LLM cost is $0/PR by default; `cost_cap_per_pr_usd` is ignored for this runner.
- **`api-ci` (preserved)** — explicit per-token API fallback. Same constraint as ADR-0044 D5 (preserved by ADR-0086 D5): must set a non-zero `cost_cap_per_pr_usd`, must name provider/model elsewhere in the file, advisory posture preserved. Not the default. Only use when the local worker is structurally unavailable for a specific repo (e.g., a repo the home-server worker cannot reach for some operator reason).
- **`openclaw-codex` (removed)** — the previous v1 default. **Dropped from the schema by ADR-0086 D5.** Existing repos with this value migrate to `local-worker` at cutover (this initiative's packet 09 handles the fan-out migration; for Architecture itself, packet 07).

Update the "Repos without a `.honeydrunk-review.yaml`" note to remain consistent with ADR-0044 D4's opt-in posture (preserved by ADR-0086 D5): repos without the file continue to be treated as `enabled: false`.

Update the worked Architecture-repo example to use `runner: local-worker`:

```yaml
# .honeydrunk-review.yaml — HoneyDrunk.Architecture (Phase A pilot)
enabled: true
severity_floor: Suggest
skip_paths:
  - "**/generated/**"
  - "**/*.g.cs"
runner: local-worker
```

Add a short "Breaking change history" note at the bottom of the doc:

> **2026-05-26 — Breaking change (ADR-0086 D5).** The `runner:` enum dropped `openclaw-codex` and added `local-worker` as the new default. Repos previously carrying `runner: openclaw-codex` migrate via the Phase B fan-out (initiative `adr-0086-pull-based-local-worker-grid-review`, packet 09). The `api-ci` value is preserved unchanged. Per ADR-0044 D11 Phase 1, only `HoneyDrunk.Architecture` had been opted in at the time of this change, so practical migration scope is bounded.

## Affected Files
- `copilot/review-config-schema.md`
- `CHANGELOG.md`

## NuGet Dependencies
None. This packet edits a Markdown doc; no .NET project is created or modified.

## Boundary Check
- [x] The schema doc lives in `HoneyDrunk.Architecture/copilot/` — the established home for review-tooling reference docs (alongside `pr-review-rules.md`, `issue-authoring-rules.md`).
- [x] No code change in any repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `copilot/review-config-schema.md` documents the `runner:` field with exactly two enum values: `local-worker` (default) and `api-ci`. `openclaw-codex` is removed.
- [ ] The doc states that `cost_cap_per_pr_usd` is meaningful only for `runner: api-ci`; ignored for `runner: local-worker` (because marginal LLM cost is $0 under subscription auth).
- [ ] The doc states that repos without `.honeydrunk-review.yaml` are treated as `enabled: false` (preserved from ADR-0044 D4).
- [ ] The Architecture-repo worked example uses `runner: local-worker`.
- [ ] A "Breaking change history" section at the bottom records the 2026-05-26 ADR-0086 D5 change, the migration story (initiative `adr-0086-pull-based-local-worker-grid-review`, packet 09 for the fan-out), and the practical migration scope (Architecture only, per ADR-0044 D11 Phase 1 status).
- [ ] No polish/v2 fields (e.g., `path_instructions`) appear in the schema — those remain deferred per ADR-0044 D4 (preserved).
- [ ] CHANGELOG.md updated with an entry noting the schema breaking change.

## Human Prerequisites
None. Pure docs edit.

## Dependencies
- `work-item:01` — ADR-0086 acceptance (soft; the doc references ADR-0086 D5 as a live rule).

## Referenced ADR Decisions

**ADR-0086 D5** — `.honeydrunk-review.yaml` `runner:` enum update. `local-worker` (new default), `api-ci` (preserved with the same ADR-0044 D5 constraints), `openclaw-codex` (removed). Breaking schema change; small practical impact because only `HoneyDrunk.Architecture` had been opted in.

**ADR-0044 D4 (preserved by ADR-0086 D5)** — `.honeydrunk-review.yaml` is the per-repo config; repos without the file are `enabled: false`; v1 minimal schema (enabled gate + `severity_floor` + `skip_paths` + `runner` + `cost_cap_per_pr_usd`). Per-path overrides explicitly deferred to a v2 polish phase.

**ADR-0044 D5 (preserved by ADR-0086 D5)** — `api-ci` runner constraints: non-zero `cost_cap_per_pr_usd`, named provider/model, advisory posture.

## Constraints
- **Schema doc is a reference, not a tutorial.** Keep edits tight and authoritative.
- **`openclaw-codex` is removed, not deprecated.** Do not leave it in the doc with a "(removed)" marker — drop it entirely; the breaking-change history note carries the historical record.
- **Do not add polish/v2 fields.** ADR-0044 D4's deferral of `path_instructions` and similar is preserved by ADR-0086 D5.
- **Do not edit any `.honeydrunk-review.yaml` file in this packet.** Architecture's migration is packet 07; the Phase B fan-out is packet 09.

## Labels
`docs`, `tier-1`, `meta`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Update `copilot/review-config-schema.md` for ADR-0086 D5: drop `openclaw-codex`, add `local-worker` (default), preserve `api-ci`, update the worked example, record the breaking-change history.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Provide every Phase B fan-out repo with the canonical schema reference at the new default.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A.
- ADRs: ADR-0086 (D5), ADR-0044 (D4/D5 preserved).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` — ADR-0086 acceptance (soft).

**Constraints:**
- Schema doc is a reference, not a tutorial — keep edits tight.
- `openclaw-codex` is removed, not deprecated.
- Do not add polish/v2 fields.
- Do not edit any `.honeydrunk-review.yaml` file in this packet.

**Key Files:**
- `copilot/review-config-schema.md`
- `CHANGELOG.md`

**Contracts:** None.
