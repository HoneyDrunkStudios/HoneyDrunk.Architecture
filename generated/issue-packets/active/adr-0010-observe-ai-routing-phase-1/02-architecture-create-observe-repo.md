---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "new-node", "adr-0010", "human-only", "wave-1"]
dependencies: []
adrs: ["ADR-0010"]
wave: 1
initiative: adr-0010-observe-ai-routing-phase-1
node: honeydrunk-architecture
actor: human
---

# Chore: Create `HoneyDrunk.Observe` GitHub repo (human-only)

## Summary
Create the `HoneyDrunkStudios/HoneyDrunk.Observe` repo on GitHub with the Grid's standard per-repo settings. This is an org-admin action that cannot be delegated to an agent — it gates the `03-observe-abstractions-scaffold.md` packet, which is blocked until the repo exists.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level)

## Actor
**`Human`.** This entire work item is human-only. Org-admin rights on `HoneyDrunkStudios` are required to create a new repo, and repo creation is not delegated to agents.

## Motivation
`03-observe-abstractions-scaffold.md` defines the solution, CI, and Abstractions package skeleton for `HoneyDrunk.Observe` but cannot be filed as a GitHub issue until the target repo exists. Surfacing this as an explicit Wave-1 work item keeps it visible on The Hive board as a human-only blocker instead of an implicit prerequisite.

## Steps (portal)

1. Navigate to https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. **Repository name:** `HoneyDrunk.Observe`
3. **Description:** `External project observation layer — contracts, runtime, and per-system connector packages`
4. **Visibility:** Public — matches the HoneyDrunk Grid default. Secrets never live in code (all connector credentials resolve via `ISecretStore` per invariant 29). Do not commit tenant IDs, subscription IDs, or webhook endpoints in the repo — those are environment-specific and belong in App Service config.
5. **Initialize with:**
   - [x] Add a README file
   - [x] Add `.gitignore` → `VisualStudio` template
   - [x] Choose a license → match what the other HoneyDrunk.* repos use (check `HoneyDrunk.Vault/LICENSE` or `HoneyDrunk.Kernel/LICENSE`)
6. Click **Create repository**
7. After creation, apply org defaults:
   - Branch protection on `main` (mirror `HoneyDrunk.Vault` settings — require PR, require checks, no force push, no deletion)
   - Default branch = `main`
   - Actions enabled
   - Secrets and variables → nothing to seed yet

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.Observe` exists and is accessible
- [ ] Visibility is Public (matches HoneyDrunk default)
- [ ] Default branch is `main` with a README committed
- [ ] Branch protection rules match the Grid standard (mirror `HoneyDrunk.Vault`'s settings)
- [ ] `.gitignore` and LICENSE committed
- [ ] "Next Steps" script below has been run, filing `03-observe-abstractions-scaffold.md` as an issue on the new repo
- [ ] This chore issue is closed after the Next Steps script completes

## Next Steps (run immediately after the repo exists)

These commands file `03-observe-abstractions-scaffold.md` against the newly-created repo, add it to The Hive, and populate custom fields. Run from the `HoneyDrunk.Architecture` repo root.

```bash
PACKETS="generated/issue-packets/active/adr-0010-observe-ai-routing-phase-1"

# 1. Seed the new repo with the labels the filing command needs
for label in "feature:0E8A16" "tier-3:5319E7" "new-node:C5DEF5" "ops:FFA500" "scaffolding:BFDADC" "adr-0010:1D76DB" "wave-2:FBCA04"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Observe --color "$color" 2>/dev/null
done

# 2. File the scaffold packet as an issue on the new repo
ISSUE_URL=$(gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Observe \
  --title "Scaffold HoneyDrunk.Observe repo, solution, and Abstractions package" \
  --body-file "$PACKETS/03-observe-abstractions-scaffold.md" \
  --label "feature,tier-3,new-node,ops,scaffolding,adr-0010,wave-2")
echo "Filed: $ISSUE_URL"

# 3. Add to The Hive — field IDs per infrastructure/github-projects-field-ids.md
gh project item-add 4 --owner HoneyDrunkStudios --url "$ISSUE_URL"

# 4. Set board fields (Wave 2 / Initiative adr-0010-observe-ai-routing-phase-1 / Node honeydrunk-observe / Tier 3 / Actor Agent)
# See infrastructure/github-projects-field-ids.md for current option IDs; apply via `gh project item-edit`.
```

After this runs, `03-observe-abstractions-scaffold.md` is filed against the new repo and is the next Wave-2 agent-eligible work item.

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios` (required to create new repos under the org)
- [ ] Browser with GitHub session logged in as the org owner

## Dependencies
None. This is a root blocker for `03-observe-abstractions-scaffold.md`.

## Downstream Unblocks
- `03-observe-abstractions-scaffold.md` — becomes fileable and executable the moment this chore is Done

## Referenced ADR Decisions

**ADR-0010 (Observation Layer and AI Routing):**
- **§New Node HoneyDrunk.Observe:** One new Node that owns both observation contracts and per-system connector packages. Provider-slot pattern same as Vault and Transport. First-wave connector slots: GitHub, Azure, HTTP. Each connector delegates credential resolution to Vault.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

## Labels
`chore`, `tier-1`, `meta`, `new-node`, `adr-0010`, `human-only`, `wave-1`

## Notes for the human executing this chore

- This is a 3-minute portal task. No scripts, no CLI.
- After the repo is created, run the Next Steps script above to file `03-observe-abstractions-scaffold.md` against the new repo, then close this chore issue.
- If you decide to defer Observe (e.g., waiting on a clearer first-connector use case), close this as "not planned" with a note pointing at the deferral decision — do not delete the packet. A future acceptance can revive it.
