---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "new-node", "adr-0017", "human-only", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0017"]
wave: 2
initiative: adr-0017-capabilities-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Create `HoneyDrunk.Capabilities` GitHub repo (human-only)

## Summary
Create the `HoneyDrunkStudios/HoneyDrunk.Capabilities` repo on GitHub with the Grid's standard per-repo settings. This is an org-admin action that cannot be delegated to an agent — it gates the `04-capabilities-node-scaffold.md` packet, which is blocked until the repo exists.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level)

## Actor
**`Human`.** This entire work item is human-only. Org-admin rights on `HoneyDrunkStudios` are required to create a new repo, and repo creation is not delegated to agents. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation
`04-capabilities-node-scaffold.md` defines the solution, three packages, four contracts, default registry/invoker/guard implementations, in-memory testing fixture, and CI pipeline for `HoneyDrunk.Capabilities` but cannot be filed as a GitHub issue until the target repo exists. Surfacing this as an explicit Wave-2 work item keeps it visible on The Hive board as a human-only blocker instead of an implicit prerequisite. Same pattern as `02-architecture-create-communications-repo.md` from the ADR-0013 initiative.

## Steps (portal)

1. Navigate to https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. **Repository name:** `HoneyDrunk.Capabilities`
3. **Description:** `Tool-registry and dispatch substrate for the AI sector — registers tool descriptors, dispatches invocations, gates them through Auth policy via ICapabilityGuard. The "how a tool becomes callable" half of the AI sector base (paired with HoneyDrunk.AI for the inference half).`
4. **Visibility:** Public — matches the HoneyDrunk Grid default. The registry/dispatcher logic is design-pattern code and is openly shareable. Secrets never live in code; the only credentials Capabilities touches are at composition time (the host wires in Auth's policy resolver) and there is no per-repo secret to seed at creation. Do not commit tenant IDs, subscription IDs, or any environment-specific identifiers.
5. **Initialize with:**
   - [x] Add a README file
   - [x] Add `.gitignore` → `VisualStudio` template
   - [x] Choose a license → match what the other HoneyDrunk.* repos use (check `HoneyDrunk.Auth/LICENSE` since Capabilities is most similar to Auth in shape — pure abstractions + runtime + zero external SDK dependencies)
6. Click **Create repository**
7. After creation, apply org defaults:
   - Branch protection on `main` (mirror `HoneyDrunk.Auth` settings — require PR, require checks, no force push, no deletion)
   - Default branch = `main`
   - Actions enabled
   - Secrets and variables → nothing to seed yet (Capabilities is a library Node with no Azure footprint; future deployable hosts compose it in but the repo itself ships NuGet packages only)

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.Capabilities` exists and is accessible
- [ ] Visibility is Public (matches HoneyDrunk default)
- [ ] Default branch is `main` with a README committed
- [ ] Branch protection rules match the Grid standard (mirror `HoneyDrunk.Auth`'s settings)
- [ ] `.gitignore` and LICENSE committed
- [ ] "Next Steps" script below has been run, filing `04-capabilities-node-scaffold.md` as an issue on the new repo (assuming packet 02 has merged and any required invariant-number amendments to packet 04 have been applied)
- [ ] This chore issue is closed after the Next Steps script completes

## Next Steps (run immediately after the repo exists *and* packet 02 has merged)

These commands seed labels on the new repo, file `04-capabilities-node-scaffold.md` against it, add the resulting issue to The Hive, and prepare for the board-field population step. Run from the `HoneyDrunk.Architecture` repo root.

**Important order-of-operations:** Per the dispatch plan's filing-order rule, packet 04 cannot be filed until packet 02's PR has merged (so the assigned invariant numbers are locked in `constitution/invariants.md`) and any required pre-filing amendments to `04-capabilities-node-scaffold.md` have been applied. If packet 02 has not yet merged at the time this chore is being closed, file packet 04 **after** packet 02 lands — not now.

```bash
PACKETS="generated/work-items/active/adr-0017-capabilities-standup"

# 1. Seed the new repo with the labels the filing command needs.
#    Color choices follow the existing convention used by other Grid repos:
#    feature=green, tier-2=yellow, tier-3=purple, new-node=light-blue, ai=magenta,
#    scaffolding=pale-cyan, adr-0017=mid-blue, wave-3=yellow.
for label in "feature:0E8A16" "tier-2:FBCA04" "tier-3:5319E7" "new-node:C5DEF5" "ai:D946EF" "scaffolding:BFDADC" "adr-0017:1D76DB" "wave-3:FBCA04"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Capabilities --color "$color" 2>/dev/null
done

# 2. File the scaffold packet as an issue on the new repo
ISSUE_URL=$(gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Capabilities \
  --title "Scaffold HoneyDrunk.Capabilities repo, solution, three packages, contracts, CI, in-memory testing fixture" \
  --body-file "$PACKETS/04-capabilities-node-scaffold.md" \
  --label "feature,tier-2,new-node,ai,scaffolding,adr-0017,wave-3")
echo "Filed: $ISSUE_URL"

# 3. Add to The Hive — field IDs per infrastructure/github-projects-field-ids.md
gh project item-add 4 --owner HoneyDrunkStudios --url "$ISSUE_URL"

# 4. Set board fields (Wave 3 / Initiative adr-0017-capabilities-standup / Node honeydrunk-capabilities / Tier 2 / Actor Agent)
# See infrastructure/github-projects-field-ids.md for current option IDs; apply via `gh project item-edit`.
# (If that file does not exist yet, copy field option IDs from another already-filed packet's project-item state, e.g. an ADR-0016 or ADR-0026 issue.)
```

After this runs, `04-capabilities-node-scaffold.md` is filed against the new repo and is the next Wave-3 agent-eligible work item. Close this chore issue afterwards.

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios` (required to create new repos under the org)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner (for the Next Steps script)
- [ ] Confirm packet 02 (invariants) has merged before running the Next Steps script — if not, defer the script run until it has

## Dependencies
- `work-item:01` — catalog registration packet must merge first so the catalogs and `repos/HoneyDrunk.Capabilities/integration-points.md` already point at the eventual repo. Sequenced after Wave 1 by dispatch plan; the actual portal action could run in parallel with Wave 1, but the tracking issue is filed in Wave 2.

## Downstream Unblocks
- `04-capabilities-node-scaffold.md` — becomes fileable and executable the moment this chore is Done **and** packet 02 has merged (whichever happens later)

## Referenced ADR Decisions

**ADR-0017 (Stand Up the HoneyDrunk.Capabilities Node):**
- **§Decision / D1:** HoneyDrunk.Capabilities is a new Node in the AI sector. New Node ⇒ new repo per invariant 11.
- **§Decision / D2:** Three package families (`HoneyDrunk.Capabilities.Abstractions`, `HoneyDrunk.Capabilities`, `HoneyDrunk.Capabilities.Testing`) — all three live in this single repo per invariant 11.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

## Labels
`chore`, `tier-1`, `meta`, `new-node`, `adr-0017`, `human-only`, `wave-2`

## Notes for the human executing this chore

- This is a 3-minute portal task. No scripts beyond the Next Steps block, which is a quick CLI run after the portal click — and only after packet 02 has merged.
- After the repo is created, run the Next Steps script above to file `04-capabilities-node-scaffold.md`, then close this chore issue.
- Do not provision any Azure resources (Key Vault, App Configuration, Container App). HoneyDrunk.Capabilities is a library Node with no Azure footprint. Future deployable hosts that compose Capabilities will provision their own resources per the host's own bring-up; that is not this packet's concern.
- If you decide to defer Capabilities standup, close this as "not planned" with a note pointing at the deferral decision — do not delete the packet. A future acceptance can revive it.
