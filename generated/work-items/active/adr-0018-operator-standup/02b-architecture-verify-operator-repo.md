---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0018", "human-only", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0018"]
accepts: ADR-0018
wave: 2
initiative: adr-0018-operator-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Verify `HoneyDrunk.Operator` GitHub repo settings + local clone (human-only)

## Summary

Confirm `HoneyDrunkStudios/HoneyDrunk.Operator` matches the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled), confirm the local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Operator/` is up to date with `main`, and confirm the OIDC federated credential for NuGet publishing is in place. Both the GitHub repo and the local clone already exist (the repo carries `.gitignore`, `LICENSE`, `README.md` plus drafting folders `docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`). This is a verification packet, not a creation packet.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (tracking issue lives here; actual portal/CLI work is on GitHub and locally)

## Actor
**`Human`.** Org-admin rights required to set branch protection and seed labels; local-clone verification is a human action.

## Motivation

Packet 03 (the scaffold) defines the solution, three packages, eight contracts, default runtime, in-memory testing fixture, and CI pipeline for `HoneyDrunk.Operator` but cannot be executed by the scaffolding agent until:

1. The local working tree at `c:/.../HoneyDrunkStudios/HoneyDrunk.Operator` is on `main` and clean.
2. Branch protection rules are applied (PR required, `pr-core` required, no force-pushes, no deletions).
3. Labels needed for issue filing exist on the repo.
4. The OIDC federated credential for the NuGet publishing identity is in place.

The existing drafting folders (`docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`) are **source material for the scaffolding agent**, not a finished scaffold. They contain design notes that the agent should consult while authoring `.cs` files but should not commit verbatim. Packet 03 handles this distinction in its own Constraints section.

## Steps

### Step 1 — Verify repo settings (portal)

1. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Operator/settings — confirm:
   - **Default branch:** `main`
   - **Visibility:** Public (HoneyDrunk Grid default)
   - **Features:** Issues enabled, Actions enabled
2. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Operator/settings/branches — confirm or create branch protection rule on `main`:
   - **Require a pull request before merging:** on
   - **Require status checks to pass before merging:** on
   - **Required status checks:** `pr-core / core` only for now (the canary check is added post-merge after the throwaway-PR verification — see packet 03 Human Prerequisites)
   - **Allow force pushes:** off
   - **Allow deletions:** off
3. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Operator/settings/security_analysis — confirm Dependabot alerts are enabled (org default).

### Step 2 — Seed labels (CLI)

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0018:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Operator --color "$color" 2>/dev/null
done
```

Already-exists errors are fine — idempotent.

### Step 3 — Verify local clone

**Pre-check.** The local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Operator/` is currently on `chore/wire-standard-workflows` at the time this packet was authored. Do **not** issue a bare `git checkout main` — the branch may not exist locally yet. Follow this sequence:

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Operator

# Step 0 — confirm state
git status                                         # confirm clean working tree
git branch --show-current                          # confirm chore/wire-standard-workflows (or current branch)
git fetch origin

# Branch A — chore PR has already merged to origin/main:
#   create the local main branch (if it doesn't exist) from origin/main, then drop the chore branch.
git checkout main 2>/dev/null || git checkout -b main origin/main
git pull --ff-only origin main
git branch -d chore/wire-standard-workflows 2>/dev/null || true    # safe-delete only if fully merged

# Branch B — chore PR has NOT merged yet:
#   STOP. Do not run the lines above. Merge `chore/wire-standard-workflows` to `main` on GitHub first
#   (review + approve + squash-merge), then return here and execute Branch A.

ls
```

Confirm the working tree is on `main`, clean, and contains at minimum `.gitignore`, `LICENSE`, `README.md` plus the drafting folders (`docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`).

**If `git branch -d chore/wire-standard-workflows` errors** with "not fully merged" the human should NOT use `-D` (force) without first confirming the chore work landed on `main`. The branch deletion is a cleanup nicety, not a blocker for the rest of this packet.

### Step 4 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm the Grid's NuGet publishing identity has `repo:HoneyDrunkStudios/HoneyDrunk.Operator:ref:refs/tags/v*` in its federated credential subject list. If not, add it via Microsoft Entra → App registrations → the NuGet publishing identity → Certificates & secrets → Federated credentials.

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.Operator` has branch protection on `main` requiring `pr-core / core`, no force-pushes, no deletions
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `ai`, `scaffold`, `adr-0018`, `wave-3`, `human-only`, `out-of-band` exist on the repo
- [ ] Local working tree at `c:/.../HoneyDrunkStudios/HoneyDrunk.Operator/` is on `main`, clean, contains `.gitignore`, `LICENSE`, `README.md` + drafting folders
- [ ] OIDC federated credential exists for `repo:HoneyDrunkStudios/HoneyDrunk.Operator:ref:refs/tags/v*`
- [ ] This chore issue is closed after all four checks above are verified
- [ ] After this chore is Done **and** packet 02 has merged, packet 03 is fileable

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios`
- [ ] Browser with GitHub session as org owner
- [ ] `gh` CLI installed locally and authenticated
- [ ] Azure portal access for OIDC verification (only if Step 4 finds a missing credential)

## Dependencies
- `work-item:01` — catalog registration must merge first.

## Downstream Unblocks
- `03-operator-node-scaffold.md` — becomes fileable the moment this chore is Done **and** packet 02 has merged.

## Referenced ADR Decisions

**ADR-0018 D1 (Substrate Node):** HoneyDrunk.Operator is the AI sector's human-policy enforcement substrate. New Node ⇒ new repo per invariant 11 — the repo is already created on GitHub and cloned locally; this packet is the verification half of the standup.

**ADR-0018 D2 (Package families):** Three package families. The local clone hosts the solution that packet 03 authors.

## Referenced Invariants

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning.

> **Invariant 24:** Work items are immutable once filed. Pre-filing amendments to packet 03 are permitted under invariant 24 if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0018`, `human-only`, `wave-2`

## Notes for the human executing this chore

- This is a ~5-minute task — most of the work is verification, not creation, because the repo and local clone both already exist.
- After all four steps complete, close this chore issue and unblock packet 03.
- If branch protection is already correctly applied, Step 1 is verify-only.
- If the OIDC federated credential is already in place, Step 4 is verify-only.
- Do **not** commit anything to the local clone in this chore — the scaffolding agent in packet 03 authors all source files. The drafting folders (`docs/`, `contracts/`, `policies/`, `prompts/`, `staging/`) are read-only source material for the agent.
- No Azure provisioning required. HoneyDrunk.Operator is a library Node with no Azure footprint.
