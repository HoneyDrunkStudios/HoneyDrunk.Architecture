---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["ci", "tier-2", "ops", "adr-0008"]
dependencies: ["2026-04-12-actions-packet-filing-action.md", "2026-04-12-org-secret-gh-issue-token.md"]
adrs: ["ADR-0008"]
initiative: standalone
node: honeydrunk-architecture
actor: Agent
---

# Feature: Packet-filing caller workflow in HoneyDrunk.Architecture

## Summary

Add `.github/workflows/file-packets.yml` to `HoneyDrunk.Architecture`. This caller workflow triggers on pushes to `main` that touch `generated/issue-packets/active/**` and on `workflow_dispatch`, then delegates to the reusable `file-packets.yml` in `HoneyDrunk.Actions`. This is the glue that makes merging a packet PR automatically file its issues.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Dependencies

Both of the following must be complete before this workflow is useful:
- `2026-04-12-actions-packet-filing-action.md` — the reusable workflow it calls must exist in HoneyDrunk.Actions
- `2026-04-12-org-secret-gh-issue-token.md` — `GH_ISSUE_TOKEN` org secret must exist

## Proposed Implementation

### `.github/workflows/file-packets.yml`

```yaml
name: File Issue Packets

on:
  push:
    branches: [main]
    paths:
      - 'generated/issue-packets/active/**/*.md'
  workflow_dispatch:

jobs:
  file:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/file-packets.yml@main
    secrets:
      hive-field-mirror-token: ${{ secrets.HIVE_FIELD_MIRROR_TOKEN }}
      gh-issue-token: ${{ secrets.GH_ISSUE_TOKEN }}
```

That is the entire file. All logic lives in `HoneyDrunk.Actions`.

## Key Files

- `.github/workflows/file-packets.yml` (new)

## NuGet Dependencies

None.

## Acceptance Criteria

- [ ] Workflow file exists at `.github/workflows/file-packets.yml`
- [ ] Merging a PR that adds a packet to `generated/issue-packets/active/` triggers the workflow automatically
- [ ] `workflow_dispatch` also triggers it successfully
- [ ] Both secrets pass through correctly to the reusable workflow
- [ ] Workflow appears in the Actions tab and shows a green run after a test packet merge

## Referenced ADR Decisions

**ADR-0008 D6:** The caller in Architecture repo is the trigger surface. The implementation lives in HoneyDrunk.Actions per routing rules (CI plumbing belongs in Actions, not Architecture).
