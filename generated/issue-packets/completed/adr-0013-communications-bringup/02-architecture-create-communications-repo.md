---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "new-node", "adr-0013", "human-only", "wave-1"]
dependencies: []
adrs: ["ADR-0013"]
wave: 1
initiative: adr-0013-communications-bringup
node: honeydrunk-architecture
actor: human
---

# Chore: Create `HoneyDrunk.Communications` GitHub repo (human-only)

## Summary
Create the `HoneyDrunkStudios/HoneyDrunk.Communications` repo on GitHub with the Grid's standard per-repo settings. This is an org-admin action that cannot be delegated to an agent — it gates the `03-communications-scaffold.md` packet, which is blocked until the repo exists.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level)

## Actor
**`Human`.** This entire work item is human-only. Org-admin rights on `HoneyDrunkStudios` are required to create a new repo, and repo creation is not delegated to agents.

## Motivation
`03-communications-scaffold.md` defines the solution, CI, and project skeletons for `HoneyDrunk.Communications` but cannot be filed as a GitHub issue until the target repo exists. Surfacing this as an explicit Wave-1 work item keeps it visible on The Hive board as a human-only blocker instead of an implicit prerequisite.

## Steps (portal)

1. Navigate to https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. **Repository name:** `HoneyDrunk.Communications`
3. **Description:** `Decision and orchestration layer for outbound communications — message intent, recipient resolution, preferences, cadence, multi-step flows. Delegates delivery to HoneyDrunk.Notify.`
4. **Visibility:** Public — matches the HoneyDrunk Grid default. The orchestration logic is design-pattern code and is openly shareable. Secrets never live in code (the only credentials Communications might touch in Phase 3 are persistent-store connection strings, all resolved via `ISecretStore`). Do not commit tenant IDs, subscription IDs, or any environment-specific identifiers.
5. **Initialize with:**
   - [x] Add a README file
   - [x] Add `.gitignore` → `VisualStudio` template
   - [x] Choose a license → match what the other HoneyDrunk.* repos use (check `HoneyDrunk.Notify/LICENSE` since Communications is most similar to Notify in shape)
6. Click **Create repository**
7. After creation, apply org defaults:
   - Branch protection on `main` (mirror `HoneyDrunk.Notify` settings — require PR, require checks, no force push, no deletion)
   - Default branch = `main`
   - Actions enabled
   - Secrets and variables → nothing to seed yet (Phase 3 will provision the per-Node vault and OIDC federated credential when production deploy is needed)

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.Communications` exists and is accessible
- [ ] Visibility is Public (matches HoneyDrunk default)
- [ ] Default branch is `main` with a README committed
- [ ] Branch protection rules match the Grid standard (mirror `HoneyDrunk.Notify`'s settings)
- [ ] `.gitignore` and LICENSE committed
- [ ] "Next Steps" script below has been run, filing `03-communications-scaffold.md` as an issue on the new repo
- [ ] This chore issue is closed after the Next Steps script completes

## Next Steps (run immediately after the repo exists)

These commands seed labels on the new repo, file `03-communications-scaffold.md` against it, add the resulting issue to The Hive, and prepare for the board-field population step. Run from the `HoneyDrunk.Architecture` repo root.

```bash
PACKETS="generated/issue-packets/active/adr-0013-communications-bringup"

# 1. Seed the new repo with the labels the filing command needs.
#    Color choices follow the existing convention used by other Grid repos:
#    feature=green, tier-3=purple, new-node=light-blue, ops=orange,
#    scaffolding=pale-cyan, adr-0013=mid-blue, wave-2=yellow.
for label in "feature:0E8A16" "tier-3:5319E7" "new-node:C5DEF5" "ops:FFA500" "scaffolding:BFDADC" "adr-0013:1D76DB" "wave-2:FBCA04"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Communications --color "$color" 2>/dev/null
done

# 2. File the scaffold packet as an issue on the new repo
ISSUE_URL=$(gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Communications \
  --title "Scaffold HoneyDrunk.Communications repo, solution, and project skeletons" \
  --body-file "$PACKETS/03-communications-scaffold.md" \
  --label "feature,tier-3,new-node,ops,scaffolding,adr-0013,wave-2")
echo "Filed: $ISSUE_URL"

# 3. Add to The Hive — field IDs per infrastructure/github-projects-field-ids.md
gh project item-add 4 --owner HoneyDrunkStudios --url "$ISSUE_URL"

# 4. Set board fields (Wave 2 / Initiative adr-0013-communications-bringup / Node honeydrunk-communications / Tier 3 / Actor Agent)
# See infrastructure/github-projects-field-ids.md for current option IDs; apply via `gh project item-edit`.
# (That file is a known pre-existing gap — until it lands, copy field option IDs from another already-filed packet's project-item state, e.g. an ADR-0010 or ADR-0015 issue.)
```

After this runs, `03-communications-scaffold.md` is filed against the new repo and is the next Wave-2 agent-eligible work item. Packets 04 and 05 are filed by hand once Wave 3 / Wave 4 are ready, after the scaffold has merged.

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios` (required to create new repos under the org)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner (for the Next Steps script)

## Dependencies
None. This is a root blocker for `03-communications-scaffold.md`.

## Downstream Unblocks
- `03-communications-scaffold.md` — becomes fileable and executable the moment this chore is Done

## Referenced ADR Decisions

**ADR-0013 (Communications Orchestration Layer — HoneyDrunk.Communications):**
- **§Decision / New Node:** HoneyDrunk.Communications is a new Node in the Ops sector. New Node ⇒ new repo per invariant 11.
- **§Phase Plan / Phase 1:** "Create repo and solution structure" — exactly the scope this chore unblocks.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

## Labels
`chore`, `tier-1`, `meta`, `new-node`, `adr-0013`, `human-only`, `wave-1`

## Notes for the human executing this chore

- This is a 3-minute portal task. No scripts beyond the Next Steps block, which is a quick CLI run after the portal click.
- After the repo is created, run the Next Steps script above to file `03-communications-scaffold.md`, then close this chore issue.
- Do not provision any Azure resources (Key Vault, App Configuration, Container App). Phase 1 + Phase 2 ship NuGet packages only — Communications has no Azure footprint until Phase 3, which is its own initiative.
- If you decide to defer Communications standup (e.g., waiting on a clearer first-flow use case beyond welcome email), close this as "not planned" with a note pointing at the deferral decision — do not delete the packet. A future acceptance can revive it.
