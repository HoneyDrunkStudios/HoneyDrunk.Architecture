---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0022", "human-only", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0022"]
accepts: ADR-0022
wave: 2
initiative: adr-0022-memory-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Verify `HoneyDrunk.Memory` GitHub repo settings + local clone (human-only)

## Summary

Confirm `HoneyDrunkStudios/HoneyDrunk.Memory` matches Grid standard settings; confirm local clone is on `main` clean; confirm OIDC. Repo and clone exist (LICENSE + README).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Actor
**`Human`.**

## Steps

### Step 1 — Repo settings (portal)
- /settings — default branch `main`, Public, Issues + Actions on.
- /settings/branches — branch protection: PR required, `pr-core / core` required, no force pushes, no deletions.
- /settings/security_analysis — Dependabot alerts on.

### Step 2 — Seed labels

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0022:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Memory --color "$color" 2>/dev/null
done
```

### Step 3 — Verify local clone

The HoneyDrunk.Memory clone is currently sitting on a `chore/wire-standard-workflows` branch from an earlier standard-workflow wave. Step 0 below brings it back to a clean `main` before the scaffold packet executes against it. If the chore PR for `chore/wire-standard-workflows` has not merged yet, leave the branch alone and re-run Step 3 after that PR lands.

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Memory

# Step 0 — get the clone onto a clean main
git status                                          # confirm clean (no uncommitted edits)
git checkout chore/wire-standard-workflows         # confirm current branch
# If the chore PR has merged to main on remote:
git checkout main 2>/dev/null || git checkout -b main origin/main
git pull --ff-only origin main
git branch -d chore/wire-standard-workflows        # delete local chore branch

# Step 3 — verify
git status; git fetch origin; git checkout main; git pull --ff-only origin main; ls
```

### Step 4 — OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md). Confirm `repo:HoneyDrunkStudios/HoneyDrunk.Memory:ref:refs/tags/v*` in the NuGet publishing identity's federated credential list.

## Acceptance Criteria
- [ ] Branch protection configured.
- [ ] Labels seeded.
- [ ] Local clone on `main`, clean.
- [ ] OIDC credential verified.
- [ ] Chore issue closed.

## Human Prerequisites
- [ ] Org-admin role; browser; gh CLI; Azure portal access for Step 4 if needed.

## Dependencies
- `packet:01`

## Downstream Unblocks
- `03-memory-node-scaffold.md` — fileable after this chore Done + packet 02 merged.

## Referenced ADR Decisions

**ADR-0022 D1 / D2:** Substrate Node, three packages.

## Referenced Invariants

> **Invariant 11:** One repo per Node.

> **Invariant 24:** Pre-filing amendments to packet 03 permitted if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0022`, `human-only`, `wave-2`

## Notes
- ~5-minute verification task.
- No commits to the local clone.
- No Azure provisioning.
