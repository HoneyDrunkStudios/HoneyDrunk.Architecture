---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0024", "human-only", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0024"]
accepts: ADR-0024
wave: 2
initiative: adr-0024-flow-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Verify `HoneyDrunk.Flow` GitHub repo settings + local clone (human-only)

## Summary

Confirm `HoneyDrunkStudios/HoneyDrunk.Flow` matches Grid-standard settings; confirm local clone is on `main` clean; confirm OIDC. Repo and clone already exist (LICENSE + README).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Actor
**`Human`.**

## Steps

### Step 0 — Reconcile local `chore/wire-standard-workflows` branch (if present)

The Flow clone may carry a stale `chore/wire-standard-workflows` branch from earlier scaffold prep. The clone is currently LICENSE + README only, so the branch may not exist on remote at all. **Run only if the branch exists locally** — verify with `git branch` first.

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Flow
git status                                          # confirm clean
git branch                                          # if no `chore/wire-standard-workflows`, skip to Step 1
git checkout chore/wire-standard-workflows         # if present, confirm current branch
# If the chore PR has merged to main on remote:
git checkout main 2>/dev/null || git checkout -b main origin/main
git pull --ff-only origin main
git branch -d chore/wire-standard-workflows        # delete local chore branch
```

If `chore/wire-standard-workflows` exists on remote and is unmerged, delete the remote branch before the scaffold packet lands (`git push origin --delete chore/wire-standard-workflows` after confirming the work is captured elsewhere or abandoned). Packet 03's scaffold lands on `main` and assumes no parallel chore branch is in flight.

### Step 1 — Verify repo settings (portal)
- /settings — default branch `main`, Public, Issues + Actions on.
- /settings/branches — PR required, `pr-core / core` required, no force pushes, no deletions.
- /settings/security_analysis — Dependabot alerts on.

### Step 2 — Seed labels

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0024:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Flow --color "$color" 2>/dev/null
done
```

### Step 3 — Verify local clone

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Flow
git status; git fetch origin; git checkout main; git pull --ff-only origin main; ls
```

### Step 4 — OIDC

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md). Confirm `repo:HoneyDrunkStudios/HoneyDrunk.Flow:ref:refs/tags/v*`.

## Acceptance Criteria
- [ ] Branch protection configured.
- [ ] Labels seeded.
- [ ] Local clone on `main`, clean.
- [ ] OIDC verified.
- [ ] Chore closed.

## Human Prerequisites
- [ ] Org-admin role; browser; gh CLI; Azure portal access for Step 4 if needed.

## Dependencies
- `packet:01`

## Downstream Unblocks
- `03-flow-node-scaffold.md` — fileable after this chore Done + packet 02 merged.

## Referenced ADR Decisions

**ADR-0024 D1 / D2:** Substrate Node, three packages.

## Referenced Invariants

> **Invariant 11:** One repo per Node.

> **Invariant 24:** Pre-filing amendments to packet 03 permitted if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0024`, `human-only`, `wave-2`

## Notes
- ~5-minute verification. No commits to clone. No Azure provisioning.
