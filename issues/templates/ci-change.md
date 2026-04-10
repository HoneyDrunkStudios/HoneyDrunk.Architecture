---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops"]
dependencies: []
adrs: []
wave: 1
initiative: "{initiative-slug}"
node: "{node-id}"
---

# CI Change: {Title}

## Summary
<!-- One-sentence summary of the CI/workflow change -->

## Target Workflow
<!-- Which workflow or composite action is being changed -->
**File:** `.github/workflows/{filename}.yml` or `.github/actions/{action-name}/action.yml`
**Family:** pr-core | pr-sdk | release | nightly-security | nightly-deps | nightly-accessibility | weekly-governance | manual

## Motivation
<!-- Why this CI change is needed -->

## Proposed Change
<!-- What specifically changes in the workflow or action -->

## Consumer Impact
<!-- Which repos consume this workflow and how they are affected -->
- 

## Breaking Change?
- [ ] Yes — consumers need to update their caller workflows
- [ ] No — backward compatible

## Acceptance Criteria
- [ ] Workflow runs successfully on a test repo or branch
- [ ] No regressions in existing consumer repos
- [ ] Workflow versioning updated (if breaking)
- [ ] `docs/CHANGELOG.md` updated
- [ ] `docs/consumer-usage.md` updated (if interface changed)

## Dependencies
<!-- Other issues or version requirements -->

## Labels
`ci`, `tier-2`, `ops`
