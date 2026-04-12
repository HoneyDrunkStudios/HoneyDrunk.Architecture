---
name: Dependency Upgrade
type: dependency-upgrade
tier: 2
target_repos: []
labels: ["dependency-upgrade", "tier-2", "coordination"]
dependencies: []
adrs: []
wave: 1
initiative: "{initiative-slug}"
node: "{node-id}"
---

# Dependency Upgrade: {Title}

## Summary
<!-- e.g., "Upgrade HoneyDrunk.Kernel from 0.3.0 to 0.4.0 across all consumers" -->

## Package Being Upgraded
**Package:** `{PackageName}`
**From:** `{currentVersion}`
**To:** `{targetVersion}`

## Breaking Changes
<!-- List breaking changes from the package's CHANGELOG -->
- 

## Affected Repos (in dependency order)
<!-- List repos that consume this package, ordered upstream-first -->
1. `HoneyDrunkStudios/{Repo}` — {impact summary}

## Upgrade Plan

### Phase 1: Upstream Package Release
- [ ] New version tagged and published

### Phase 2: Consumer Updates
<!-- For each consuming repo -->
- [ ] `{Repo}` — PackageReference updated, build passing, canary tests green

## Compatibility Check
- [ ] Verified against `catalogs/compatibility.json`
- [ ] No invariant violations introduced
- [ ] Canary tests passing in all affected repos

## Acceptance Criteria
- [ ] All consuming repos upgraded
- [ ] All builds green
- [ ] Repo-level CHANGELOG.md updated in each upgraded repo
- [ ] Per-package CHANGELOG.md updated only for packages with actual changes (not alignment-only bumps)
- [ ] `catalogs/compatibility.json` updated with new version ranges
- [ ] `initiatives/releases.md` updated

## Dependencies
<!-- Other issues or upstream version requirements -->

## Labels
`dependency-upgrade`, `tier-2`, `coordination`
