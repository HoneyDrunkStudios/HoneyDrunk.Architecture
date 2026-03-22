---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: "{repo}"
labels: ["feature", "tier-2", "{sector}"]
dependencies: []
---

# Feature: {Title}

## Summary
<!-- One-sentence summary of the feature -->

## Target Repo
`{HoneyDrunkStudios/RepoName}`

## Motivation
<!-- Why this feature is needed. Link to initiative if applicable. -->

## Proposed Implementation
<!-- High-level approach. Reference specific files, interfaces, or patterns. -->

## Affected Packages
<!-- Which NuGet packages in the repo are modified -->
- 

## Boundary Check
<!-- Confirm this work belongs in this repo. Reference /repos/{name}/boundaries.md -->
- [ ] Feature is within this Node's stated responsibilities
- [ ] Feature does not duplicate capabilities of another Node
- [ ] No new cross-Node dependencies introduced (or cascades identified)

## Acceptance Criteria
- [ ] Implementation complete
- [ ] Unit tests added
- [ ] XML docs on public APIs
- [ ] CHANGELOG.md updated
- [ ] Canary tests pass (if applicable)

## Dependencies
<!-- Other issues, PRs, or upstream version requirements -->

## Labels
`feature`, `tier-2`, `{sector}`
