---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["docs", "tier-1", "meta", "openclaw", "adr-0044", "wave-1"]
dependencies: ["work-item:01"]
adrs: ["ADR-0044"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-architecture
supersedes: ["work-item:05"]
---

# Author the OpenClaw-aware .honeydrunk-review.yaml v1 schema doc

## Summary
Author `copilot/review-config-schema.md` for the revised ADR-0044 v1 schema. The schema keeps the enabled gate, severity floor, and skip paths, but replaces Anthropic/Sonnet/Opus model selection with `runner: openclaw-codex` and keeps API-backed execution as an explicit future fallback only.

## Context
The originally filed packet 05 documented `model: sonnet|opus` and `cost_cap_per_pr_usd: 5.00`. ADR-0044 now uses OpenClaw/Codex as the v1 runner to avoid a new per-token Anthropic bill. This packet supersedes packet 05 for schema work.

## Proposed v1 Schema

```yaml
enabled: true
runner: openclaw-codex       # openclaw-codex | api-ci; v1 default is openclaw-codex
severity_floor: Suggest      # Suggest | Request Changes | Block
skip_paths:
  - "**/*.Designer.cs"
  - "**/*.g.cs"
  - "**/generated/**"
cost_cap_per_pr_usd: 0.00    # v1 subscription-backed default; API fallback must set explicit non-zero cap
```

## Acceptance Criteria
- [ ] `copilot/review-config-schema.md` documents the revised v1 schema
- [ ] The schema includes `enabled`, `runner`, `severity_floor`, `skip_paths`, and `cost_cap_per_pr_usd`
- [ ] The doc says `openclaw-codex` is the default v1 runner
- [ ] The doc says `api-ci` is a future explicit fallback, not default behavior
- [ ] The doc removes Sonnet/Opus as per-repo config knobs for v1
- [ ] The doc explains reviewed-head-SHA behavior and `skip-review`
- [ ] Cross-links to ADR-0044 D1/D4/D5 and packet 02b runner docs

## Dependencies
- `work-item:01` — ADR-0044 acceptance/amendment (soft).

## Constraints
- Do not document Anthropic API as a required v1 dependency.
- Do not make review a blocking required check.

## Agent Handoff

**Objective:** Write the revised OpenClaw-aware `.honeydrunk-review.yaml` schema doc.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Key Files:**
- `copilot/review-config-schema.md`
