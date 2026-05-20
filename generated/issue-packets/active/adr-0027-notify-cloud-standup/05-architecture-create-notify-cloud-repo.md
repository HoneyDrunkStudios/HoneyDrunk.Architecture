---
name: Repo Chore (Private — First in the Grid)
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "new-node", "adr-0027", "human-only", "wave-3"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0027"]
accepts: ADR-0027
wave: 3
initiative: adr-0027-notify-cloud-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Create `HoneyDrunk.Notify.Cloud` GitHub repo as PRIVATE (human-only) — first private repo in the Grid

## Summary
Create the `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud` repo on GitHub. **CRITICAL: select PRIVATE visibility, not the org default of Public.** This is the Grid's first private repo. The decision and its justification are recorded in ADR-0027 D2 (revenue carve-out: customer-data-adjacent infrastructure, hyperscaler defense, billing-system integrity).

This packet is an org-admin action that cannot be delegated to an agent — it gates packet 06 (the scaffold packet), which cannot be filed until the repo exists.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level)

## Actor
**`Human`.** This entire work item is human-only. Org-admin rights on `HoneyDrunkStudios` are required to create a new repo. Selecting "Private" visibility is a deliberate, ADR-recorded carve-out from the Grid's public-by-default posture — the human must consciously click "Private" rather than letting GitHub default to Public. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation
`06-notify-cloud-node-scaffold.md` defines the solution, four packages, four contracts, default `INotifyCloudGateway`, in-memory API key store, Notify-Cloud-specific rate-limit policy, Stripe billing-adapter stub, Web placeholder, full CI including the contract-shape canary, and Container Apps deployment configuration for `HoneyDrunk.Notify.Cloud` — but cannot be filed as a GitHub issue until the target repo exists.

This chore is also the **first time in the Grid's history that a private repo is being created**. The repo policy (memory: "new HoneyDrunk repos are public unless revenue/compliance/experiment") admits a revenue carve-out, and Notify Cloud sits squarely in it per ADR-0027 D2. The justification, on the record:

- **Customer-data-adjacent infrastructure.** Tenant isolation enforcement, abuse heuristics, billing-fraud detection, and per-tenant Vault path resolution are concerns where public scrutiny of half-baked states actively harms customers. These are not educational primitives that benefit from community contribution.
- **Hyperscaler defense.** Open-sourcing the multi-tenant gateway produces an AWS-style "host Notify Cloud for cheaper" competitor against a solo developer who cannot match infra economics. The OSS-engine + private-wrapper split (FSL on Notify and Communications, proprietary on Notify Cloud) puts the moat in operational reliability and economy-of-scale infrastructure, not in closed-source secrets.
- **Billing-system integrity.** Stripe webhook signing keys, internal billing-event shapes, and abuse-rate thresholds lose value the moment they go public.

Surfacing this as an explicit Wave-3 work item keeps it visible on The Hive board as a human-only blocker (with the `human-only` label so the board surfaces `Actor=Human`) rather than an implicit prerequisite of packet 06. Same pattern as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md`, except the visibility selection differs.

## Steps (portal)

1. Navigate to https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. **Repository name:** `HoneyDrunk.Notify.Cloud`
3. **Description:** `Multi-tenant commercial wrapper above HoneyDrunk.Notify (the open engine) and HoneyDrunk.Communications (the orchestration layer). Owns API gateway, API key issuance/validation, per-tenant rate-limit enforcement, tenant-scoped billing-event emission, and the management website. Private repo (revenue carve-out per ADR-0027 D2). All rights reserved.`
4. **Visibility:** **PRIVATE.** (Critical — do NOT accept the GitHub default of Public.) This is the Grid's first private repo. ADR-0027 D2 records the justification: customer-data-adjacent infrastructure, hyperscaler defense, billing-system integrity.
5. **Initialize with:**
   - [x] Add a README file (initial placeholder — the scaffold packet replaces it)
   - [x] Add `.gitignore` → `VisualStudio` template
   - [ ] **Do NOT choose a public license.** The repo is private and proprietary — `LicenseRef-Proprietary` (all rights reserved by default of being private). Leave the GitHub license picker blank. The scaffold packet (06) commits a `LICENSE` file at the repo root with the proprietary stance.
6. Click **Create repository**
7. After creation, apply per-repo defaults:
   - **Default branch:** `main`
   - **Branch protection on `main`:**
     - Require a pull request before merging
     - Require status checks to pass before merging
     - Required status checks: `pr-core / core` (the `api-compatibility / abstractions-shape` check will be added to required-checks in a follow-up branch-protection update *after* the scaffold packet's throwaway breaking-change PR confirms the canary fires post-merge — see packet 06 Human Prerequisites)
     - Disallow force pushes
     - Disallow deletions
     - Require signed commits: off (matches other Grid repos)
   - **Features:** Issues enabled, Actions enabled, Discussions optional
   - **Secrets and variables → nothing to seed yet.** Notify Cloud Container Apps deployment uses OIDC federated credentials to the Grid's deployment identity, not a per-repo PAT. The Stripe webhook signing key is held in the Notify Cloud Node's Key Vault (`kv-hd-notify-cloud-{env}`), not as a GitHub Action secret.
8. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Notify.Cloud/settings/security_analysis and confirm Dependabot alerts are enabled (org default — should already be on for private repos too); CodeQL default-setup stays off per the org "HoneyDrunk Grid — public default" config.

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.Notify.Cloud` exists and is accessible to the org owner.
- [ ] **Visibility is PRIVATE** (confirmed by browsing to the repo's homepage and observing the "Private" badge next to the repo name — verify; if it reads "Public," delete and recreate as Private before proceeding).
- [ ] Default branch is `main` with a placeholder README committed.
- [ ] No public license selected during repo creation (LICENSE file is the scaffold packet's concern, and it carries `LicenseRef-Proprietary`).
- [ ] Branch protection rules on `main` match the Grid standard: require PR, require `pr-core / core` check, no force-pushes, no deletions.
- [ ] `.gitignore` committed (VisualStudio template).
- [ ] Dependabot alerts enabled (verify in Settings → Security & analysis).
- [ ] "Next Steps" script below has been run, filing `06-notify-cloud-node-scaffold.md` as an issue on the new repo (assuming packet 02 has merged and any required invariant-number amendments to packet 06 have been applied).
- [ ] This chore issue is closed after the Next Steps script completes.

## Next Steps (run immediately after the repo exists *and* packet 02 has merged)

These commands seed labels on the new repo, file `06-notify-cloud-node-scaffold.md` against it, add the resulting issue to The Hive, and prepare for the board-field population step. Run from the `HoneyDrunk.Architecture` repo root.

**Important order-of-operations:** Per the dispatch plan's filing-order rule, packet 06 cannot be filed until packet 02's PR has merged (so the assigned invariant numbers are locked in `constitution/invariants.md`) and any required pre-filing amendments to `06-notify-cloud-node-scaffold.md` have been applied. If packet 02 has not yet merged at the time this chore is being closed, file packet 06 **after** packet 02 lands — not now.

```bash
PACKETS="generated/issue-packets/active/adr-0027-notify-cloud-standup"

# 1. Seed the new repo with the labels the filing command needs.
#    Color choices follow the existing convention used by other Grid repos:
#    feature=green, tier-2=yellow, tier-3=purple, new-node=light-blue, ops=cyan,
#    scaffolding=pale-cyan, commercial=orange, adr-0027=mid-blue, wave-4=yellow.
for label in "feature:0E8A16" "tier-2:FBCA04" "tier-3:5319E7" "new-node:C5DEF5" "ops:0E7C7B" "scaffolding:BFDADC" "commercial:F8A93C" "adr-0027:1D76DB" "wave-4:FBCA04"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Notify.Cloud --color "$color" 2>/dev/null
done

# 2. File the scaffold packet as an issue on the new repo
ISSUE_URL=$(gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Notify.Cloud \
  --title "Scaffold HoneyDrunk.Notify.Cloud — solution, four packages, contracts, CI, Container Apps wiring" \
  --body-file "$PACKETS/06-notify-cloud-node-scaffold.md" \
  --label "feature,tier-2,new-node,ops,scaffolding,commercial,adr-0027,wave-4")
echo "Filed: $ISSUE_URL"

# 3. Add to The Hive — field IDs per infrastructure/github-projects-field-ids.md
gh project item-add 4 --owner HoneyDrunkStudios --url "$ISSUE_URL"

# 4. Set board fields (Wave 4 / Initiative adr-0027-notify-cloud-standup / Node honeydrunk-notify-cloud / Tier 2 / Actor Agent)
# See infrastructure/github-projects-field-ids.md for current option IDs; apply via `gh project item-edit`.
# (If that file does not exist yet, copy field option IDs from another already-filed packet's project-item state, e.g. an ADR-0016 or ADR-0017 issue.)
```

After this runs, `06-notify-cloud-node-scaffold.md` is filed against the new private repo and is the next Wave-4 agent-eligible work item. Close this chore issue afterwards.

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios` (required to create new repos under the org)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner (for the Next Steps script)
- [ ] Confirm packet 02 (invariants) has merged before running the Next Steps script — if not, defer the script run until it has
- [ ] **Conscious decision to click "Private" rather than the GitHub default "Public" — this is the Grid's first private repo and the choice is recorded by ADR-0027 D2.** If unsure, re-read ADR-0027 D2 (lines 47-59) before proceeding.

## Dependencies
- `packet:01` — context-folder registration packet must merge first so the catalogs and `repos/HoneyDrunk.Notify.Cloud/integration-points.md` already point at the eventual repo. (Note: `catalogs/*.json` itself is hive-sync-reconciled, not packet-01-edited, but the context-folder content from packet 01 is what gives external scoping agents something to read about the repo.)
- `packet:02` — constitution invariants must land before the scaffold packet is filed against the new repo (the scaffold packet's body cites assigned invariant numbers).

## Downstream Unblocks
- `06-notify-cloud-node-scaffold.md` — becomes fileable and executable the moment this chore is Done **and** packet 02 has merged (whichever happens later)

## Referenced ADR Decisions

**ADR-0027 D1 (Notify Cloud is the Ops sector's multi-tenant commercial wrapper above Notify):** New Node ⇒ new repo per invariant 11.

**ADR-0027 D2 (Repo visibility — private, with explicit justification):** First private repo in the Grid. Three justifications on the record:
- Customer-data-adjacent infrastructure (tenant isolation enforcement, abuse heuristics, billing-fraud detection, per-tenant Vault path resolution — concerns where public scrutiny of half-baked states actively harms customers).
- Hyperscaler defense (open-sourcing the multi-tenant gateway produces an AWS-style rehosting competitor; the OSS-engine + private-wrapper split puts the moat at operational economics).
- Billing-system integrity (Stripe webhook signing keys, internal billing-event shapes, and abuse-rate thresholds lose value the moment they go public).

The catalog `visibility` schema field introduction is hive-sync's concern, not this packet's — the human-only action here is the repo-creation portal click with the "Private" selection.

**ADR-0027 D3 (Package families):** Four packages — `HoneyDrunk.Notify.Cloud.Abstractions`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Notify.Cloud.Billing.Stripe`, `HoneyDrunk.Notify.Cloud.Web` — all live in this single repo per invariant 11.

**ADR-0027 D11 (FSL on open engine repos, proprietary on the wrapper):** The wrapper repo is not licensed publicly. Access is granted only to the studio. License is "All rights reserved" by default of being private. The scaffold packet (06) commits a `LICENSE` file with `LicenseRef-Proprietary` content; this packet only commits the placeholder README and `.gitignore`.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

> **Invariant 51 (assigned by packet 02 of this initiative — number subject to collision-check):** The HoneyDrunk Grid's repo default is public; private repos require an explicit ADR-recorded justification under the revenue/compliance/experiment carve-out. `HoneyDrunk.Notify.Cloud` is the first private repo; its justification (customer-data-adjacent infrastructure, hyperscaler defense, billing-system integrity) is recorded in ADR-0027 D2. — This packet is the application of that invariant: the human selects "Private" rather than the org default of "Public," with ADR-0027 D2 as the recorded justification.

## Labels
`chore`, `tier-1`, `meta`, `new-node`, `adr-0027`, `human-only`, `wave-3`

## Notes for the human executing this chore

- This is a 5-minute portal task. The only twist vs prior repo-creation chores is the visibility selection: **click "Private," not the GitHub default "Public."** Every prior repo in the Grid has been public; this is the first private one.
- After the repo is created, run the Next Steps script above to file `06-notify-cloud-node-scaffold.md`, then close this chore issue.
- Do NOT provision Azure resources in this packet. The scaffold packet (06) provisions the Container App (`ca-hd-notify-cloud-stg`), the shared `cae-hd-stg` Container Apps Environment (if not already in place), and any Key Vault (`kv-hd-notify-cloud-stg`) required by the deployment. Those are scaffold concerns.
- The repo will eventually need a Key Vault per invariant 17 (`kv-hd-notify-cloud-{env}`) once the Container App is provisioned — that is scaffold-packet (06) work, not repo-creation work.
- If you decide to defer Notify Cloud standup, close this as "not planned" with a note pointing at the deferral decision — do not delete the packet. A future acceptance can revive it.
- **Confirm the repo is private before pushing any code to it.** If a "Public" badge appears next to the repo name on the homepage after creation, delete the repo and recreate as Private. The error of pushing wrapper code to a public repo would expose customer-data-adjacent surfaces against ADR-0027 D2's recorded justification — recoverable only with effort, not zero-cost.
