---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repos: []
labels: ["cross-repo", "tier-2", "coordination"]
dependencies: []
---

# Cross-Repo: {Title}

## Summary
<!-- One-sentence summary of the cross-repo change -->

## Affected Repos (in execution order)
<!-- List repos in dependency order — upstream first -->
1. `HoneyDrunkStudios/{UpstreamRepo}` — {what changes}
2. `HoneyDrunkStudios/{DownstreamRepo}` — {what changes}

## Motivation
<!-- Why this needs to span multiple repos -->

## Change Plan

### Phase 1: {Upstream Repo}
<!-- What changes in the upstream repo -->
- 

### Phase 2: {Downstream Repo}
<!-- What changes in the downstream repo after upstream merges -->
- 

## Contracts Affected
<!-- List specific interfaces or packages that change across repo boundaries -->
- 

## Cascade Validation
- [ ] Dependency order verified against `catalogs/relationships.json`
- [ ] No circular dependencies introduced
- [ ] Canary tests updated in downstream repos
- [ ] Version bumps coordinated

## Acceptance Criteria
- [ ] All phase PRs merged in order
- [ ] Canary tests passing in all affected repos
- [ ] Packages published to feed
- [ ] CHANGELOG.md updated in all repos

## Dependencies
<!-- Other issues or version requirements -->

## Labels
`cross-repo`, `tier-2`, `coordination`
