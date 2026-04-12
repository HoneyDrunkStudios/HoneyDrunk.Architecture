---
name: Repo Feature
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-2", "ops", "automation", "adr-0008"]
dependencies: ["2026-04-12-org-secret-gh-issue-token.md"]
adrs: ["ADR-0008"]
initiative: standalone
node: honeydrunk-actions
actor: Agent
---

# Feature: Batch packet-filing action (ADR-0008 D6)

## Summary

Build a GitHub Actions reusable workflow in `HoneyDrunk.Actions` that reads merged issue packets from `HoneyDrunk.Architecture/generated/issue-packets/active/`, files them as GitHub Issues in their target repos, adds them to The Hive (project #4), and populates all custom fields inline. This closes the ADR-0008 D6 gap and renders D5 (auto-add) irrelevant for the primary packet flow.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Actions`

## Human Prerequisites

Before this work can be executed end-to-end, the following human step must be complete:

- [ ] `GH_ISSUE_TOKEN` org secret created — see packet `2026-04-12-org-secret-gh-issue-token.md`

`HIVE_FIELD_MIRROR_TOKEN` is already in place from Actions#22.

## Motivation

Without D6, merging a packet PR stalls at the filing step. Issuing a 15-packet wave requires 15 manual `gh issue create` calls across multiple repos, then 15 `hive-backfill-issue.sh` calls. This packet makes filing invisible: merge the PR, the board populates.

## Proposed Implementation

### Reusable workflow: `.github/workflows/file-packets.yml`

**Triggers (when called via `workflow_call`):**
- Inputs: `architecture-ref` (branch/SHA to checkout Architecture repo, default `main`), `packets-dir` (default `generated/issue-packets/active`), `project-number` (default `4`), `project-owner` (default `HoneyDrunkStudios`)
- Secrets: `hive-field-mirror-token`, `gh-issue-token`

**Steps:**

1. Checkout `HoneyDrunk.Architecture` at `architecture-ref`
2. Read `generated/issue-packets/filed-packets.json` (manifest — created if absent)
3. For each `.md` file under `packets-dir` not already in the manifest:
   a. Parse YAML frontmatter (`target_repo`, `labels`, `tier`, `wave`, `adrs`, `initiative`, `node`, `actor`)
   b. Build issue body: header note linking back to Architecture packet path + full packet content below the frontmatter
   c. Synthesize full label set: frontmatter `labels` array **plus** `initiative-{initiative}` derived from the `initiative` field — the mirror script reads Initiative from this label; it will not be set without it
   d. `gh issue create --repo {target_repo} --title "{h1 from packet}" --body "{body}" --label "{all-labels}"`
   e. Capture returned issue URL
   f. `./scripts/hive-project-mirror.sh --url {issue_url} ...` — sets Wave, Tier, Node, ADR, Initiative from labels
   g. Set `Actor` field on the board item via a separate GraphQL `updateProjectV2ItemFieldValue` call using the `actor` frontmatter value — **the mirror script does not handle Actor; this must be an explicit step**
   h. Append `"{packet_relative_path}": "{issue_url}"` to manifest
4. Commit updated `filed-packets.json` back to Architecture repo (uses `gh-issue-token` which has `contents:write` on Architecture)
5. Output a summary table: packet → issue URL

### Filed-packets manifest: `generated/issue-packets/filed-packets.json`

Machine-written by the action. Never hand-edited. Path relative to Architecture repo root.

```json
{
  "generated/issue-packets/active/standalone/2026-04-12-actions-packet-filing-action.md": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Actions/issues/23"
}
```

**Idempotency rule:** If a packet path already has an entry, skip it unconditionally. Do not create a second issue.

### Script: `scripts/file-packets.sh`

Encapsulates the per-packet loop. Called by the workflow. Accepts:
- `--packets-dir` — path to `active/` directory
- `--manifest` — path to `filed-packets.json`
- `--project-owner` — default `HoneyDrunkStudios`
- `--project-number` — default `4`

Runnable locally with `GH_TOKEN` and `HIVE_FIELD_MIRROR_TOKEN` set in environment.

### Issue body format

```markdown
> [!NOTE]
> Filed from issue packet in [HoneyDrunk.Architecture](https://github.com/HoneyDrunkStudios/HoneyDrunk.Architecture).
> Packet: `{relative_packet_path}` · ADRs: {adrs} · Initiative: {initiative}

{full packet content below frontmatter}
```

## Key Files

- `.github/workflows/file-packets.yml` (new — reusable workflow)
- `scripts/file-packets.sh` (new)

The caller workflow in `HoneyDrunk.Architecture` is a separate packet — see `2026-04-12-architecture-file-packets-caller.md`.

## NuGet Dependencies

None — CI and shell tooling only.

## Acceptance Criteria

- [ ] Calling the reusable workflow against a test packet in `active/standalone/` creates a GitHub Issue in the correct target repo with correct labels
- [ ] The Hive board item shows correct Wave, Node, Tier, ADR, Initiative, Actor, and Status=Backlog with no manual steps
- [ ] Re-running against the same packets creates no duplicate issues (manifest check)
- [ ] `filed-packets.json` is committed back to Architecture repo after the run
- [ ] `initiative: adr-0005-0006-rollout` in frontmatter → `initiative-adr-0005-0006-rollout` label added to issue → Initiative field set on board
- [ ] `actor: Agent` in frontmatter → Actor=Agent on board; `actor: Human` → Actor=Human (set via direct GraphQL call, not via mirror script)
- [ ] `scripts/file-packets.sh` runs locally with env vars set
- [ ] Workflow passes `actionlint`

## Referenced ADR Decisions

**ADR-0008 D6:** Batch-filing script in `HoneyDrunk.Actions` — this packet delivers it as a proper GitHub Actions workflow.
**ADR-0008 D5:** Per-repo auto-add not needed for issues filed through this action; action adds to The Hive inline.
