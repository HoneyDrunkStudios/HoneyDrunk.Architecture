---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0021", "human-only", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0021"]
accepts: ADR-0021
wave: 2
initiative: adr-0021-knowledge-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Verify `HoneyDrunk.Knowledge` GitHub repo settings + local clone (human-only)

## Summary

Confirm `HoneyDrunkStudios/HoneyDrunk.Knowledge` matches the Grid's per-repo standard settings; confirm the local clone at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Knowledge/` is on `main` and clean; confirm OIDC federated credential. Repo and clone already exist (LICENSE + README).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Actor
**`Human`.**

## Steps

### Step 0 — Reconcile local clone branch state

The local clone at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Knowledge/` may currently be checked out on `chore/wire-standard-workflows` (the per-repo Standards-wiring chore branch). Before any other verification work, confirm the clone is clean and align it back to `main` so packet 03's scaffolding agent starts from a known baseline.

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Knowledge
git status                                          # confirm clean
git checkout chore/wire-standard-workflows         # confirm current branch
# If the chore PR has merged to main on remote:
git checkout main 2>/dev/null || git checkout -b main origin/main
git pull --ff-only origin main
git branch -d chore/wire-standard-workflows        # delete local chore branch
```

If `git status` reports uncommitted changes on the chore branch, stop and resolve those first — do not force-delete the branch. If the chore PR has not yet merged, defer the `git branch -d` step and leave the local chore branch in place; the scaffolding agent in packet 03 branches from `main` independently and is not blocked by the chore branch's presence.

### Step 1 — Verify repo settings (portal)
- https://github.com/HoneyDrunkStudios/HoneyDrunk.Knowledge/settings — default branch `main`, Public, Issues + Actions enabled.
- /settings/branches — branch protection: PR required, `pr-core / core` required, no force pushes, no deletions.
- /settings/security_analysis — Dependabot alerts enabled.

### Step 2 — Seed labels

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0021:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Knowledge --color "$color" 2>/dev/null
done
```

### Step 3 — Verify local clone (final sanity check)

Step 0 already aligned the clone to `main`. This step is a final post-portal sanity check:

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Knowledge
git status                                          # clean, on main
git fetch origin
git pull --ff-only origin main                     # absorb any portal-driven default-branch updates
ls                                                  # confirm LICENSE + README present
```

### Step 4 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm `repo:HoneyDrunkStudios/HoneyDrunk.Knowledge:ref:refs/tags/v*` in the Grid's NuGet publishing identity's federated credential list.

## Acceptance Criteria
- [ ] Branch protection on `main` configured.
- [ ] Labels seeded.
- [ ] Local clone is on `main`, clean, and the `chore/wire-standard-workflows` local branch has either been deleted (if the chore PR merged) or explicitly left in place with a note (if it has not yet merged).
- [ ] OIDC credential verified.
- [ ] Chore issue closed.

## Human Prerequisites
- [ ] Org-admin role
- [ ] Browser + gh CLI authenticated
- [ ] Azure portal access if Step 4 needs work

## Dependencies
- `work-item:01`

## Downstream Unblocks
- `03-knowledge-node-scaffold.md` — fileable after this chore Done and packet 02 merged.

## Referenced ADR Decisions

**ADR-0021 D1 / D2:** Substrate Node, three packages. Repo already exists; this is verification.

## Referenced Invariants

> **Invariant 11:** One repo per Node.

> **Invariant 24:** Pre-filing amendments to packet 03 permitted if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0021`, `human-only`, `wave-2`

## Notes
- ~5-minute task. Verification only.
- Do not commit anything to the local clone. Scaffolding agent in packet 03 authors all source files.
- No Azure provisioning required.
