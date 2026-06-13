---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "cache", "adr-0059", "human-only", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0059"]
accepts: ADR-0059
wave: 2
initiative: adr-0059-cache-standup
node: honeydrunk-cache
actor: human
---

# Chore: Create `HoneyDrunk.Cache` public GitHub repo + branch protection + labels + OIDC + clone locally (human-only)

## Summary
Create the public `HoneyDrunkStudios/HoneyDrunk.Cache` GitHub repo, apply the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled, security analysis), wire the OIDC federated credential for tag-driven NuGet publishing, and clone the repo locally so packet 03's scaffolding agent has a working tree to author into. This is an org-admin / human action that cannot be delegated to an agent — it gates packet 03.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level + locally on the user's machine)

## Actor
**`Human`.** Org-admin rights on `HoneyDrunkStudios` are required to create the repo, apply branch protection, seed labels, configure the OIDC federated credential, and clone the repo locally. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation

`03-cache-node-scaffold.md` defines the solution, placeholder project, Standards wiring, CI workflows, README, CHANGELOG, and LICENSE shape for `HoneyDrunk.Cache` but cannot be executed by the scaffolding agent until:

1. The `HoneyDrunkStudios/HoneyDrunk.Cache` GitHub repo exists. As of 2026-05-24 it does not (confirmed pre-scoping — `ls c:/Users/tatte/source/repos/HoneyDrunkStudios/ | grep -i cache` returns nothing).
2. The local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Cache/` exists. As of 2026-05-24 it does not.
3. Branch protection rules are applied so the scaffolding PR cannot be force-pushed to `main` and `pr-core` is required.
4. Labels needed for issue filing exist on the repo (`feature`, `chore`, `tier-1`, `tier-2`, `cache`, `scaffold`, `adr-0059`, `wave-2`, `wave-3`, `human-only`, `out-of-band`).
5. The Grid's NuGet publishing OIDC federated credential has `repo:HoneyDrunkStudios/HoneyDrunk.Cache:ref:refs/tags/v*` in its subject list so `release.yml` can publish at first tag push (if and when a tag is ever pushed — at stand-up the scaffold has no implementations to publish, so the first tag push waits until the first backing implementation lands as a separate feature packet).

Surfacing this as an explicit Wave-2 work item keeps it visible on The Hive board as a human-only blocker on packet 03 instead of an implicit prerequisite. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` and `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md` — create-and-configure, not verify-and-clone (the HoneyDrunk.Cache repo was not pre-created during ADR-0059 drafting).

## Steps

### Step 1 — Create the public repo (portal)

1. Open https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. Fill in:
   - **Repository name:** `HoneyDrunk.Cache`
   - **Description:** `Distributed-cache backing host for the Grid. Implements ICacheStore<T> (declared in HoneyDrunk.Kernel.Abstractions). Hosts Redis-class, Cosmos-with-TTL, Postgres-with-TTL adapters as sibling packages. Empty on day one — first backing arrives when first consumer pulls on it.`
   - **Visibility:** **Public** (per memory `project_repos_public_by_default` — cache backings are substrate, no revenue/compliance/experiment carve-out applies)
   - **Initialize this repository with:** check `.gitignore` (template: `VisualStudio`), check `LICENSE` (template: `MIT` — matches other Grid repos; confirm with the Grid's existing LICENSE choice on `HoneyDrunk.Audit`, `HoneyDrunk.Kernel`, etc.), do **not** add a README (packet 03 will author the README so it lands with the scaffold; if GitHub forces a README at create-time, that initial placeholder is overwritten by packet 03's commit)
3. Click **Create repository**.
4. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Cache/settings — confirm:
   - **Default branch:** `main`
   - **Visibility:** Public
   - **Features:** Issues enabled, Actions enabled, Discussions optional (off by default is fine)

### Step 2 — Branch protection on `main`

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Cache/settings/branches and create a branch protection rule on `main`:

- **Require a pull request before merging:** on
- **Require approvals:** off (solo developer; matches other Grid repos)
- **Require status checks to pass before merging:** on
- **Required status checks:** `pr-core / core` only. **No `api-compatibility` check required** — per ADR-0059 D3 + D8 and the dispatch plan's asymmetry note, Cache owns no contracts of its own, so no contract-shape canary fires at this stage. The contract Cache implements (`ICacheStore<T>`) is canaried by Kernel's own surface, not by Cache's CI. If a future backing introduces its own public surface that warrants a canary, that's a follow-up branch-protection update at that packet's time.
- **Allow force pushes:** off
- **Allow deletions:** off
- **Require signed commits:** off (matches other Grid repos)

Mirror the settings on `HoneyDrunkStudios/HoneyDrunk.Audit` or `HoneyDrunkStudios/HoneyDrunk.Kernel` if any field is unclear.

### Step 3 — Security analysis settings

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Cache/settings/security_analysis and confirm:

- **Dependabot alerts:** Enabled (org default — should already be on)
- **Dependabot security updates:** **Off** (per memory `project_adr_0009_dependabot_stance` — alerts yes, auto-PRs no; grouped nightly-deps workflow replaces per-package Dependabot PRs)
- **CodeQL default-setup:** **Off** (per memory `project_github_security_configuration` — the org "HoneyDrunk Grid — public default" config keeps CodeQL default-setup off)
- **Secret scanning:** Enabled (org default)
- **Push protection:** Enabled

### Step 4 — Seed labels (CLI)

Run the following from any local directory with `gh` CLI authenticated as the org owner. Color choices follow the existing convention used by other Grid repos. **Per memory `project_windows_crlf_gotcha`, on Windows Git Bash the `gh` and `jq` output is CRLF — when piping through bash, `tr -d '\r'` may be needed. For this loop the labels are inline strings, so CRLF is not a risk; but if a label name appears mangled, that is the cause.**

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "cache:1D76DB" "scaffold:BFDADC" "adr-0059:5319E7" "wave-2:FBCA04" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Cache --color "$color" 2>/dev/null
done
```

If `gh label create` errors with "already exists" for any label, that is fine — it is idempotent for our purposes.

### Step 5 — Clone the repo locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.Cache.git
cd HoneyDrunk.Cache
git status
```

The clone should land at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Cache/`. After cloning, confirm the working tree contains `.gitignore`, `LICENSE`, and possibly a placeholder `README.md` from the GitHub create step — and nothing else. Packet 03's scaffolding agent will overwrite the placeholder README and create everything else (`.slnx`, `src/`, `tests/`, `.github/workflows/`, `CHANGELOG.md`, etc.).

### Step 6 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm the Grid's NuGet publishing identity has `repo:HoneyDrunkStudios/HoneyDrunk.Cache:ref:refs/tags/v*` in its federated credential subject list. If not, add it via the Azure portal (Microsoft Entra → App registrations → the Grid's NuGet publishing app registration → Certificates & secrets → Federated credentials → Add credential). Without this, `release.yml` will fail to obtain a token at first tag-push.

**Note on tag-push timing:** At stand-up the Cache scaffold has no implementations and no NuGet packages to publish — the `release.yml` workflow is wired in packet 03 so the trigger is ready, but no tag is pushed as part of this initiative. The first tag-push waits until the first backing implementation lands as a separate feature packet. Wiring the OIDC credential now (as part of repo creation) avoids a future blocker on a Friday when someone wants to tag `v0.1.0` for the first backing.

### Step 7 — Confirm Architecture-side prereq

Confirm packet 01 of this initiative (the catalog-registration packet) has merged to `main`. That packet creates the `repos/HoneyDrunk.Cache/` context folder, registers `honeydrunk-cache` in the four catalogs, adds the Core-sector Cache row to `sectors.md`, updates `tech-stack.md` and `roadmap.md`, and registers the initiative entry in `active-initiatives.md`. If packet 01 has not merged, this chore can still proceed (the GitHub-side actions are independent of Architecture-repo state) — but packet 03 (the scaffold) cannot proceed until packet 01 is in (the scaffold's README cross-references `repos/HoneyDrunk.Cache/overview.md` which packet 01 authors).

## Acceptance Criteria

- [ ] `HoneyDrunkStudios/HoneyDrunk.Cache` repo exists on GitHub, is public, has default branch `main`, has Issues + Actions enabled.
- [ ] Repo initialized with `.gitignore` (VisualStudio template) and `LICENSE` (matching the Grid's existing LICENSE choice on other public repos — MIT unless verified otherwise).
- [ ] Branch protection on `main` requires `pr-core / core`, no force-pushes, no deletions, signed commits not required. **`api-compatibility` is NOT in required checks** — Cache owns no contracts at stand-up.
- [ ] Dependabot alerts: Enabled. Dependabot security updates: Off. CodeQL default-setup: Off. Secret scanning + push protection: Enabled.
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `cache`, `scaffold`, `adr-0059`, `wave-2`, `wave-3`, `human-only`, `out-of-band` all exist on the repo.
- [ ] Local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Cache/` exists, is a clean clone, contains `.gitignore` + `LICENSE` + at most a placeholder `README.md`.
- [ ] OIDC federated credential `repo:HoneyDrunkStudios/HoneyDrunk.Cache:ref:refs/tags/v*` exists on the Grid's NuGet publishing identity in Microsoft Entra.
- [ ] Packet 01 of this initiative merged to `main` (confirmation step — not blocked by it for these GitHub-side actions, but packet 03 is).
- [ ] This chore issue is closed after all checks above are verified.
- [ ] After this chore is Done **and** packet 01 of this initiative has merged, packet 03 (`03-cache-node-scaffold.md`) is fileable.

## Human Prerequisites

- [ ] Org-admin role on `HoneyDrunkStudios` (required to create the repo, set branch protection, and seed labels)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner
- [ ] Azure portal access for the OIDC federated credential check (Microsoft Entra → App registrations → NuGet publishing identity → Certificates & secrets → Federated credentials)
- [ ] Packet 01 of this initiative merged to `main` — confirms `repos/HoneyDrunk.Cache/` context folder is in place and `honeydrunk-cache` is in `catalogs/nodes.json`

## Dependencies

- `work-item:01` — packet 01 of this initiative must have merged to `main` so the Architecture-side registration (catalog, sectors, context folder, tech-stack, roadmap, initiative entry) is in place. The GitHub-side actions in this chore are technically independent of packet 01's merge, but the scaffold (packet 03) is not — surfacing the dependency here keeps the chain visible on The Hive board.

## Downstream Unblocks

- Packet 03 of this initiative (`03-cache-node-scaffold.md`) becomes fileable the moment this chore is Done **and** packet 01 of this initiative has merged.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — New Node ⇒ new repo. This chore creates that repo.

> **Invariant 24:** Work items are immutable once filed. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This chore packet is filed in Wave 2 (after packet 01 of the same initiative). Pre-filing amendments to packet 03 (the scaffold) are permitted under invariant 24 if any context surfaces between packet 01's merge and packet 03's filing time.

## Referenced ADR Decisions

**ADR-0059 D1 (Cache Node ownership):** `HoneyDrunk.Cache` is the Core sector's single Node owning distributed-cache backing implementations of `ICacheStore<T>`. New Node ⇒ new repo per invariant 11.

**ADR-0059 D5 (Visibility):** The repo is **public** per the Grid default. No revenue carve-out (Cache backings are substrate, not commercial product). No compliance carve-out (Cache owns no secrets, no PII storage, no audit-bearing surfaces). No experiment carve-out (Cache is committed substrate, not exploratory). Step 1 specifies Visibility = Public.

**ADR-0059 D3 + D8 (Scaffolding boundary — no contract-shape canary):** Cache owns no contracts at stand-up; the contract it implements lives in `Kernel.Abstractions` and is guarded by Kernel's canary surface. Step 2 reflects this — `api-compatibility` is NOT in required branch-protection checks. This is a deliberate asymmetry vs the AI/Capabilities/Audit standups which all wired contract-shape canaries.

**ADR-0009 (Dependabot stance, Accepted):** Dependabot alerts on, auto-PRs off. The grouped nightly-deps workflow replaces per-package Dependabot PRs. This chore configures the security_analysis settings accordingly in Step 3.

**Org GitHub security configuration (memory `project_github_security_configuration`):** "HoneyDrunk Grid — public default" config; CodeQL default-setup stays off (the Grid uses its own CodeQL invocation pattern, not the default-setup flow). Step 3 reflects this.

## Labels

`chore`, `tier-1`, `meta`, `cache`, `adr-0059`, `human-only`, `wave-2`

## Notes for the human executing this chore

- This is a 10-minute task split across portal + CLI + Azure portal (for OIDC) + a single `git clone`. Most of the work is one-time configuration that establishes the repo for the rest of the initiative.
- The OIDC federated credential step (Step 6) is the only Azure portal step. The Grid has a standard NuGet publishing identity used by every Node; if this is the first new repo since the credential was set up, confirm the subject pattern allows tag-pushes from `HoneyDrunk.Cache`.
- If GitHub forces a README at repo creation time, that placeholder is fine — packet 03 will overwrite it with the real scaffold README. Do not waste effort writing a temporary README here.
- Per memory `project_repos_public_by_default`: the Cache Node is a reusable Core primitive (distributed-cache backing host). No revenue-stream secret-sauce (the adapter code is standard wrappers over public Azure services), no compliance carve-out (Cache owns no secrets or PII; cached data classification is the consumer's concern), no experimental branding worth hiding. Public is the right call.
- Per memory `feedback_provision_when_needed`: no Azure resources to provision yet. HoneyDrunk.Cache is a library Node at Phase 1. No managed identity, Container App, App Configuration keys, or Azure Cache for Redis instance — all deferred until the first deployable host composes a Cache backing. Step 6's OIDC credential is the only Azure-side touch in this chore, and that is on Microsoft Entra (no resource provisioning).
- **No `api-compatibility` in required checks (Step 2).** This is the key asymmetry vs the Audit, Capabilities, and AI standup chores — those all gated branch-protection on contract-shape canaries. Cache owns no contracts at stand-up, so no canary fires. If a future backing introduces its own public surface (e.g., `HoneyDrunk.Cache.Adapters.Redis` exposes configuration records or extension methods), that backing's packet adds an `api-compatibility.yml` workflow and updates branch protection in the same edit.
