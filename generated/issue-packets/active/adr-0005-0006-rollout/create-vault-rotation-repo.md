---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "new-node", "adr-0006", "human-only", "wave-1"]
dependencies: []
adrs: ["ADR-0006"]
wave: 1
initiative: adr-0005-0006-rollout
node: honeydrunk-architecture
actor: human
---

# Chore: Create `HoneyDrunk.Vault.Rotation` GitHub repo (human-only)

## Summary
Create the `HoneyDrunkStudios/HoneyDrunk.Vault.Rotation` repo on GitHub with the Grid's standard per-repo settings. This is an org-admin action that cannot be delegated to an agent — it gates the `vault-rotation-scaffold` packet, which is blocked until the repo exists.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level)

## Actor
**`Human`.** This entire work item is human-only. Org-admin rights on `HoneyDrunkStudios` are required to create a new repo, and creating repos is not something we delegate to an agent even when technically possible.

## Motivation
`vault-rotation-scaffold.md` defines the solution, CI, and Function App skeleton for `HoneyDrunk.Vault.Rotation` but cannot be filed as a GitHub issue until the target repo exists. Without a tracked task, "create the repo" is an implicit prerequisite that's easy to forget. This packet surfaces it as an explicit Wave 1 work item so it shows up on The Hive's Agent Queue as a human-only blocker.

## Steps (portal)

1. Navigate to https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. **Repository name:** `HoneyDrunk.Vault.Rotation`
3. **Description:** `Tier-2 third-party secret rotation Azure Function App (ADR-0006)`
4. **Visibility:** Public — matches the HoneyDrunk Grid default. Secrets never live in the code (invariant 9 — all secret access is via `ISecretStore` at runtime), and the rotation pattern itself is not sensitive. Only go private if the repo ever needs to hold something genuinely proprietary, which is not the case for infrastructure glue. Do **not** commit tenant IDs, subscription IDs, resource group names, or vault URIs — those are environment-specific and belong in App Service config, not source (ADR-0005 §Bootstrap calls them out as non-secret but still environment-specific).
5. **Initialize with:**
   - [x] Add a README file
   - [x] Add `.gitignore` → `VisualStudio` template
   - [x] Choose a license → match what the other HoneyDrunk.* repos use (check `HoneyDrunk.Vault/LICENSE`)
6. Click **Create repository**
7. After creation, apply org defaults:
   - Branch protection on `main` (matches existing HoneyDrunk.* repos — require PR, require checks, no force push, no deletion)
   - Default branch = `main`
   - Actions enabled
   - Secrets and variables → nothing to seed yet (OIDC federated credential comes later via `architecture-infra-setup` walkthrough)

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.Vault.Rotation` exists and is accessible
- [ ] Visibility is Public (matches HoneyDrunk default)
- [ ] Default branch is `main` with a README committed
- [ ] Branch protection rules match the Grid standard (mirror `HoneyDrunk.Vault`'s settings)
- [ ] `.gitignore` and LICENSE committed
- [ ] "Next Steps" script below has been run, filing `vault-rotation-scaffold.md` as an issue on the new repo
- [ ] This chore issue is closed after the Next Steps script completes

## Next Steps (run immediately after the repo exists)

These commands file `vault-rotation-scaffold.md` against the newly-created repo, add it to The Hive, and populate all custom fields. **Copy-paste directly into a terminal** from the `HoneyDrunk.Architecture` repo root. They assume you just finished Step 7 above.

```bash
PACKETS="generated/issue-packets/active/adr-0005-0006-rollout"
PROJ=PVT_kwDOCxPmns4BUMbi

# 1. Seed the new repo with the labels the filing command needs
for label in "feature:0E8A16" "tier-3:5319E7" "new-node:C5DEF5" "adr-0006:1D76DB" "wave-1:FEF2C0" "core:0052CC" "infrastructure:BFDADC"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Vault.Rotation --color "$color" 2>/dev/null
done

# 2. File the scaffold packet as an issue on the new repo
ISSUE_URL=$(gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Vault.Rotation \
  --title "Scaffold HoneyDrunk.Vault.Rotation repo, solution, and Function App" \
  --body-file "$PACKETS/vault-rotation-scaffold.md" \
  --label "feature,tier-3,new-node,adr-0006,wave-1")
echo "Filed: $ISSUE_URL"

# 3. Add the new issue to The Hive and capture the board item ID
ITEM=$(gh project item-add 4 --owner HoneyDrunkStudios --url "$ISSUE_URL" --format json | python -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "Board item: $ITEM"

# 4. Populate all custom fields (Wave 1 / Initiative / Node=honeydrunk-vault / Tier 3 / ADR / Actor=Agent)
gh project item-edit --id $ITEM --project-id $PROJ --field-id PVTSSF_lADOCxPmns4BUMbizhBWQ88 --single-select-option-id cf93b1ff >/dev/null  # Wave 1
gh project item-edit --id $ITEM --project-id $PROJ --field-id PVTSSF_lADOCxPmns4BUMbizhBWRTQ --single-select-option-id dfba28ca >/dev/null  # Initiative
gh project item-edit --id $ITEM --project-id $PROJ --field-id PVTSSF_lADOCxPmns4BUMbizhBWSTA --single-select-option-id d49d8b1d >/dev/null  # Node = honeydrunk-vault
gh project item-edit --id $ITEM --project-id $PROJ --field-id PVTSSF_lADOCxPmns4BUMbizhBWS1w --single-select-option-id 943833d9 >/dev/null  # Tier 3
gh project item-edit --id $ITEM --project-id $PROJ --field-id PVTF_lADOCxPmns4BUMbizhBWS4U --text "ADR-0006" >/dev/null
gh project item-edit --id $ITEM --project-id $PROJ --field-id PVTSSF_lADOCxPmns4BUMbizhBbxQE --single-select-option-id b32d157e >/dev/null  # Actor = Agent

echo "Done. Scaffold packet is now a live Wave 1 agent-eligible work item."
echo "Close this chore issue (#8) and kick off the scaffold packet on Codex Cloud whenever you're ready."
```

After this runs, `vault-rotation-scaffold.md` is filed against the new repo and on The Hive with `Actor=Agent`. It becomes your next agent-eligible work item.

## Human Prerequisites
- Org-admin role on `HoneyDrunkStudios` (required to create new repos under the org)
- Browser with GitHub session logged in as the org owner

## Dependencies
None. This is the root blocker for `vault-rotation-scaffold.md`.

## Downstream Unblocks
- `vault-rotation-scaffold.md` — becomes fileable and executable the moment this chore is Done

## Referenced ADR Decisions

**ADR-0006 (Secret Rotation and Lifecycle):**
- **§New sub-Node:** `HoneyDrunk.Vault.Rotation` is a new Azure Function App sub-Node. It needs its own repo per invariant 11 (one repo per Node / tightly coupled Node family). Rotation is an *active* responsibility (timer-triggered, outbound API calls, writes to Key Vault) that doesn't fit `HoneyDrunk.Vault`'s *passive* library role — hence a sibling repo, not a subdirectory.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

## Labels
`chore`, `tier-1`, `meta`, `new-node`, `adr-0006`, `human-only`, `wave-1`

## Notes for the human executing this chore

- This is genuinely a 3-minute portal task. No scripts, no CLI.
- After you create the repo, run the commented-out `gh issue create` block in `dispatch-plan.md` for `vault-rotation-scaffold.md` and then close this issue.
- If you decide to defer the whole Vault.Rotation bring-up (waiting for a real third-party rotation need), close this as "not planned" with a note pointing at the deferral decision — don't delete the packet. A future ADR can revive it.
