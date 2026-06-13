---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "ai", "adr-0016", "human-only", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0016"]
wave: 2
initiative: adr-0016-honeydrunk-ai-standup
node: honeydrunk-architecture
actor: human
---

# Chore: Verify `HoneyDrunk.AI` GitHub repo settings + clone locally (human-only)

## Summary
Confirm `HoneyDrunkStudios/HoneyDrunk.AI` matches the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled), and clone the repo locally so packet 03's scaffolding agent has a working tree to author into. The repo itself was created during ADR-0016 drafting and currently contains only `.gitignore`, `LICENSE`, `README.md` — no scaffold yet. This is an org-admin / human action that cannot be delegated to an agent — it gates packet 03.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level + locally on the user's machine)

## Actor
**`Human`.** Org-admin rights on `HoneyDrunkStudios` are required to apply branch protection and seed labels; cloning the repo locally is also a human action. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation
`03-ai-node-scaffold.md` defines the solution, six packages, seven contracts, default runtime, four provider slots (InMemory functional, three stubs), and CI pipeline for `HoneyDrunk.AI` but cannot be executed by the scaffolding agent until:

1. The local working tree at `c:/.../HoneyDrunkStudios/HoneyDrunk.AI` exists. As of 2026-05-05 it does not — the GitHub repo exists but the user has not cloned it locally. The scaffolding agent will fail on `git clone` or directory-not-found if this prereq is unmet.
2. Branch protection rules are applied so the scaffolding PR can't be force-pushed to `main` and `pr-core` is required.
3. Labels needed for issue filing exist on the repo (`feature`, `tier-2`, `ai`, `scaffold`, `adr-0016`).

Surfacing this as an explicit Wave-2 work item keeps it visible on The Hive board as a human-only blocker instead of an implicit prerequisite. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` — except that one was create-and-configure, and this one is verify-and-clone-and-configure.

## Steps

### Step 1 — Verify repo settings (portal)

1. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.AI/settings — confirm:
   - **Default branch:** `main` (if not, change to `main`)
   - **Visibility:** Public (matches HoneyDrunk Grid default)
   - **Features:** Issues enabled, Actions enabled, Discussions optional
2. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.AI/settings/branches — confirm or create branch protection rule on `main`:
   - **Require a pull request before merging:** on
   - **Require status checks to pass before merging:** on
   - **Required status checks:** `pr-core / core` only for now (the `api-compatibility / abstractions-shape` check will be added to required-checks in a follow-up branch-protection update *after* the throwaway breaking-change PR confirms the canary fires post-merge — see packet 03 Human Prerequisites for the rationale)
   - **Allow force pushes:** off
   - **Allow deletions:** off
   - **Require signed commits:** off (matches other Grid repos)
   - Mirror the settings on `HoneyDrunk.Auth` if any field is unclear
3. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.AI/settings/security_analysis — confirm Dependabot alerts are enabled (org default — should already be on); CodeQL default-setup stays off per the org "HoneyDrunk Grid — public default" config.

### Step 2 — Seed labels (CLI)

Run the following from any local directory with `gh` CLI authenticated as the org owner. Color choices follow the existing convention used by other Grid repos.

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "ai:D946EF" "scaffold:BFDADC" "adr-0016:1D76DB" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.AI --color "$color" 2>/dev/null
done
```

If `gh label create` errors with "already exists" for any label, that is fine — it's idempotent for our purposes.

### Step 3 — Clone the repo locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.AI.git
cd HoneyDrunk.AI
git status
```

The clone should land at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.AI/`. After cloning, confirm the working tree contains `.gitignore`, `LICENSE`, `README.md` and nothing else. The scaffolding agent (packet 03) will create everything else.

### Step 4 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm the Grid's NuGet publishing identity has `repo:HoneyDrunkStudios/HoneyDrunk.AI:ref:refs/tags/v*` in its federated credential subject list. If not, add it via the Azure portal (Microsoft Entra → App registrations → the NuGet publishing identity → Certificates & secrets → Federated credentials). Without this, `release.yml` will fail to obtain a token at first tag-push.

## Acceptance Criteria
- [ ] `HoneyDrunkStudios/HoneyDrunk.AI` has branch protection on `main` requiring `pr-core / core`, no force-pushes, no deletions
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `ai`, `scaffold`, `adr-0016`, `wave-3`, `human-only`, `out-of-band` exist on the repo
- [ ] Local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.AI/` exists and contains `.gitignore`, `LICENSE`, `README.md`
- [ ] OIDC federated credential exists for `repo:HoneyDrunkStudios/HoneyDrunk.AI:ref:refs/tags/v*` against the Grid's NuGet publishing identity
- [ ] This chore issue is closed after all four checks above are verified
- [ ] After this chore is Done **and** packet 02 has merged, packet 03 (`03-ai-node-scaffold.md`) is fileable

## Human Prerequisites
- [ ] Org-admin role on `HoneyDrunkStudios` (required to set branch protection and seed labels)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner
- [ ] Azure portal access for the OIDC federated credential check (only needed if Step 4 turns up missing — the credential is usually pre-configured for new Grid repos)

## Dependencies
- `work-item:01` — catalog registration must merge first so the `repos/HoneyDrunk.AI/` files in the Architecture repo are aligned with what the local clone will eventually carry. Sequenced after Wave 1 by dispatch plan; the actual portal/CLI actions could run in parallel with Wave 1, but the tracking issue is filed in Wave 2.

## Downstream Unblocks
- `03-ai-node-scaffold.md` — becomes fileable and executable the moment this chore is Done **and** packet 02 has merged

## Referenced ADR Decisions

**ADR-0016 (Stand Up the HoneyDrunk.AI Node):**
- **§Decision / D1:** HoneyDrunk.AI is the AI sector's inference substrate. New Node ⇒ new repo per invariant 11 — the repo is already created on GitHub; this packet is the verification + clone half of the standup that lives outside the scaffolding agent's reach.
- **§Decision / D2:** Six package families. The local clone hosts the solution that packet 03 authors.

## Referenced Invariants

> **Invariant 11:** One repo per Node. Each repo has its own solution, CI pipeline, and versioning.

> **Invariant 24:** Work items are immutable once filed. This chore packet is itself filed in Wave 2; pre-filing amendments to packet 03 (the scaffold) are permitted under invariant 24 if invariant numbers shift in packet 02.

## Labels
`chore`, `tier-1`, `meta`, `ai`, `adr-0016`, `human-only`, `wave-2`

## Notes for the human executing this chore

- This is a 5-minute task split across portal + CLI + a single `git clone`. Most of the work is verification, not creation.
- After all four steps complete, close this chore issue and unblock packet 03.
- If branch protection is already correctly applied (org default kicks in for new repos), Step 1 is verify-only.
- If the OIDC federated credential is already in place (Grid default), Step 4 is verify-only.
- Do not provision any Azure resources. HoneyDrunk.AI is a library Node with no Azure footprint.
- Do not commit anything to the local clone in this chore — the scaffolding agent in packet 03 authors all source files.
