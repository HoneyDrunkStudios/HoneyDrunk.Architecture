---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0025", "human-only", "wave-2", "new-node"]
dependencies: ["work-item:01"]
adrs: ["ADR-0025"]
accepts: ADR-0025
wave: 2
initiative: adr-0025-sim-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Create `HoneyDrunk.Sim` GitHub repo + clone locally (human-only)

## Summary

Create `HoneyDrunkStudios/HoneyDrunk.Sim` repo on GitHub and clone locally. Same pattern as `adr-0023-evals-standup/03-architecture-create-evals-repo.md` — the repo does NOT yet exist.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Actor
**`Human`.** Org-admin rights required.

## Motivation

Packet 04 cannot be filed against a repo that does not exist. Surfaces this as Wave-2 human-only work.

## Steps

### Step 1 — Create repo (portal)

1. https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. **Repository name:** `HoneyDrunk.Sim`
3. **Description:** `Simulation and plan-evaluation substrate for the AI sector — predicts what would happen when a workflow / agent plan / retrieval pipeline is run, without touching live state. Side-effect-free by construction. Router-bypass via ISimulationTarget for reproducible projections. Closing Node of the AI-sector standup wave.`
4. **Visibility:** Public.
5. **Initialize with:**
   - [x] Add a README file
   - [x] `.gitignore` → `VisualStudio`
   - [x] License — match `HoneyDrunk.Auth/LICENSE` shape
6. **Create repository**
7. Apply org defaults — branch protection on `main` (PR required, `pr-core / core` required (canary post-merge), no force pushes, no deletions), default branch `main`, Actions enabled.

### Step 2 — Seed labels

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0025:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9" "new-node:C5DEF5"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Sim --color "$color" 2>/dev/null
done
```

### Step 3 — Clone locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.Sim.git
cd HoneyDrunk.Sim
git status
ls
```

Confirm `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Sim/` exists with `.gitignore`, `LICENSE`, `README.md`.

### Step 4 — OIDC

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md). Confirm `repo:HoneyDrunkStudios/HoneyDrunk.Sim:ref:refs/tags/v*` in NuGet publishing identity's federated credential list.

## Acceptance Criteria
- [ ] Repo exists, Public, default branch `main`.
- [ ] Branch protection configured.
- [ ] Labels seeded.
- [ ] Local clone at `c:/.../HoneyDrunkStudios/HoneyDrunk.Sim/` with starter files.
- [ ] OIDC verified.
- [ ] Chore closed.

## Human Prerequisites
- [ ] Org-admin role
- [ ] Browser; gh CLI authenticated
- [ ] Azure portal access if Step 4 needs work

## Dependencies
- `work-item:01`

## Downstream Unblocks
- `04-sim-node-scaffold.md` — fileable after this chore Done + packet 02 merged.

## Referenced ADR Decisions

**ADR-0025 D1 / D2:** Sim is the simulation substrate (closing Node of the AI-sector wave). New Node ⇒ new repo per invariant 11.

## Referenced Invariants

> **Invariant 11:** One repo per Node.

> **Invariant 24:** Pre-filing amendments to packet 04 permitted if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0025`, `human-only`, `wave-2`, `new-node`

## Notes
- ~5-minute portal task + one `git clone`.
- Do not commit anything to the local clone — scaffolding agent in packet 04 authors all source files.
- No Azure provisioning required.
- **Sim closes the AI-sector standup wave** — after Sim's 0.1.0 ships, every cataloged AI-sector Node has a published Abstractions.
