---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0020", "human-only", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0020"]
accepts: ADR-0020
wave: 2
initiative: adr-0020-agents-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Verify `HoneyDrunk.Agents` GitHub repo settings + local clone (human-only)

## Summary

Confirm `HoneyDrunkStudios/HoneyDrunk.Agents` matches the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled); confirm the local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Agents/` is on `main` and clean; confirm OIDC federated credential. Both repo and clone already exist (LICENSE + README only). Verification packet.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Actor
**`Human`.** Org-admin rights required.

## Motivation

Packet 03 defines the solution, three packages, five contracts, function-calling adapter, in-memory testing fixture, and CI pipeline for `HoneyDrunk.Agents` but cannot execute until repo settings are confirmed and local clone is verified.

## Steps

### Step 0 — Reset local clone to `main`

The local clone at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Agents/` is currently on the `chore/wire-standard-workflows` branch (the standard workflows seed that landed via `HoneyDrunk.Actions`). Bring it back to `main` before continuing.

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Agents
git status                                          # confirm clean
git checkout chore/wire-standard-workflows         # confirm current branch
# If the chore PR has merged to main on remote:
git checkout main 2>/dev/null || git checkout -b main origin/main
git pull --ff-only origin main
git branch -d chore/wire-standard-workflows        # delete local chore branch
```

If `git status` is not clean, stop and resolve before proceeding — the scaffolding work in packet 03 expects a pristine working tree on `main`.

### Step 1 — Verify repo settings (portal)

1. https://github.com/HoneyDrunkStudios/HoneyDrunk.Agents/settings — default branch `main`, Public, Issues + Actions enabled.
2. https://github.com/HoneyDrunkStudios/HoneyDrunk.Agents/settings/branches — branch protection on `main`: PR required, required check `pr-core / core` only (canary added post-merge), no force pushes, no deletions.
3. https://github.com/HoneyDrunkStudios/HoneyDrunk.Agents/settings/security_analysis — Dependabot alerts enabled.

### Step 2 — Seed labels (CLI)

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0020:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Agents --color "$color" 2>/dev/null
done
```

### Step 3 — Verify local clone

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Agents
git status                       # clean tree on main (Step 0 guarantees this)
git branch --show-current        # should be `main`
ls                                # confirm LICENSE + README + .gitignore + .github/
```

Working tree on `main`, clean, contains LICENSE + README + .gitignore + the workflows seeded by the `HoneyDrunk.Actions` chore (already merged via Step 0).

### Step 4 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm `repo:HoneyDrunkStudios/HoneyDrunk.Agents:ref:refs/tags/v*` is in the Grid's NuGet publishing identity's federated credential subject list. Add via Azure portal if missing.

## Acceptance Criteria
- [ ] Local clone reset from `chore/wire-standard-workflows` to `main`, clean working tree, chore branch deleted (Step 0).
- [ ] Branch protection on `main` requires `pr-core / core`, no force pushes, no deletions.
- [ ] Labels seeded.
- [ ] Local working tree on `main`, clean.
- [ ] OIDC federated credential confirmed.
- [ ] Chore issue closed after all five checks.

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios`
- [ ] Browser logged in
- [ ] `gh` CLI authenticated
- [ ] Azure portal access if Step 4 needs work

## Dependencies
- `work-item:01`

## Downstream Unblocks
- `03-agents-node-scaffold.md` — becomes fileable after this chore is Done and packet 02 has merged.

## Referenced ADR Decisions

**ADR-0020 D1:** HoneyDrunk.Agents is the AI sector's agent-runtime substrate. New Node ⇒ new repo per invariant 11. Repo already created; this packet is verification.

**ADR-0020 D2:** Three package families. Local clone hosts the solution packet 03 authors.

## Referenced Invariants

> **Invariant 11:** One repo per Node.

> **Invariant 24:** Work items are immutable once filed. Pre-filing amendments to packet 03 permitted if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0020`, `human-only`, `wave-2`

## Notes
- ~5-minute task. Mostly verification.
- Do not commit anything to the local clone. The scaffolding agent in packet 03 authors all source files.
- No Azure provisioning required.
