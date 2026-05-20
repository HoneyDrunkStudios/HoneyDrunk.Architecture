---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0023", "human-only", "wave-2", "new-node"]
dependencies: ["packet:01"]
adrs: ["ADR-0023"]
accepts: ADR-0023
wave: 2
initiative: adr-0023-evals-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Create `HoneyDrunk.Evals` GitHub repo + clone locally (human-only)

## Summary

Create the `HoneyDrunkStudios/HoneyDrunk.Evals` repo on GitHub with the Grid's standard per-repo settings, and clone it locally so packet 04 has a working tree. Same pattern as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` — the GitHub repo does NOT yet exist for Evals.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Actor
**`Human`.** Org-admin rights required to create a new repo.

## Motivation

Packet 04 defines the solution, three packages, six surfaces, default runtime, in-memory provider, CI for `HoneyDrunk.Evals` but cannot be filed against a repo that does not exist. Surfaces this as Wave-2 human-only work.

## Steps

### Step 1 — Create repo (portal)

1. https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. **Repository name:** `HoneyDrunk.Evals`
3. **Description:** `Evaluation and quality substrate for the AI sector — runs suites of cases against targets (chat, agent, retrieval, memory-backed workflows), scores outputs against rubrics, produces structured durable EvalReports with full run provenance. Pinned router-bypass through IEvalTarget for regression-grade model comparison.`
4. **Visibility:** Public.
5. **Initialize with:**
   - [x] Add a README file
   - [x] `.gitignore` → `VisualStudio` template
   - [x] License — match `HoneyDrunk.Auth/LICENSE` shape
6. Click **Create repository**
7. Apply org defaults:
   - Branch protection on `main` (mirror `HoneyDrunk.Auth`): PR required, `pr-core / core` required (canary added post-merge), no force pushes, no deletions
   - Default branch `main`
   - Actions enabled

### Step 2 — Seed labels

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0023:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9" "new-node:C5DEF5"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Evals --color "$color" 2>/dev/null
done
```

### Step 3 — Clone locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.Evals.git
cd HoneyDrunk.Evals
git status
ls
```

Confirm `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Evals/` exists with `.gitignore`, `LICENSE`, `README.md`.

### Step 4 — OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm `repo:HoneyDrunkStudios/HoneyDrunk.Evals:ref:refs/tags/v*` in the NuGet publishing identity's federated credential list. Add via Azure portal if missing.

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.Evals` exists, is Public, default branch `main`.
- [ ] Branch protection on `main` requires `pr-core / core`, no force pushes, no deletions.
- [ ] Labels seeded.
- [ ] Local working tree at `c:/.../HoneyDrunkStudios/HoneyDrunk.Evals/` exists with `.gitignore`, `LICENSE`, `README.md`.
- [ ] OIDC federated credential verified.
- [ ] Chore issue closed.

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios`
- [ ] Browser logged in as org owner
- [ ] `gh` CLI authenticated as org owner
- [ ] Azure portal access if Step 4 needs work

## Dependencies
- `packet:01`

## Downstream Unblocks
- `04-evals-node-scaffold.md` — fileable after this chore is Done AND packet 02 has merged.

## Referenced ADR Decisions

**ADR-0023 D1 / D2:** Evals is the evaluation and quality substrate. New Node ⇒ new repo per invariant 11.

## Referenced Invariants

> **Invariant 11:** One repo per Node.

> **Invariant 24:** Pre-filing amendments to packet 04 permitted if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0023`, `human-only`, `wave-2`, `new-node`

## Notes
- ~5-minute portal task + a single `git clone`.
- Do not commit anything to the local clone — scaffolding agent in packet 04 authors all source files.
- No Azure provisioning required. HoneyDrunk.Evals is a library Node.
