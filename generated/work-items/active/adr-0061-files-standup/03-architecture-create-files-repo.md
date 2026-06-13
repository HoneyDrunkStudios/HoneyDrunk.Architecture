---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "files", "adr-0061", "human-only", "wave-2"]
dependencies: ["work-item:01"]
adrs: ["ADR-0061"]
accepts: ADR-0061
wave: 2
initiative: adr-0061-files-standup
node: honeydrunk-files
actor: human
---

# Chore: Create `HoneyDrunk.Files` public GitHub repo + branch protection + labels + OIDC + clone locally (human-only)

## Summary
Create the public `HoneyDrunkStudios/HoneyDrunk.Files` GitHub repo, apply the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled, security analysis), wire the OIDC federated credential for tag-driven NuGet publishing, and clone the repo locally so packet 04's scaffolding agent has a working tree to author into. This is an org-admin / human action that cannot be delegated to an agent — it gates packet 04.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level + locally on the user's machine)

## Actor
**`Human`.** Org-admin rights on `HoneyDrunkStudios` are required to create the repo, apply branch protection, seed labels, configure the OIDC federated credential, and clone the repo locally. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation
`04-files-node-scaffold.md` defines the solution, four packages, five contracts + six supporting records, default registry/upload-session/processor implementations, in-memory reference adapter, and CI pipeline for `HoneyDrunk.Files` but cannot be executed by the scaffolding agent until:

1. The `HoneyDrunkStudios/HoneyDrunk.Files` GitHub repo exists. As of 2026-05-24 it does not (confirmed pre-scoping — neither the catalog entries nor the local working tree exist).
2. The local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Files/` exists. As of 2026-05-24 it does not.
3. Branch protection rules are applied so the scaffolding PR cannot be force-pushed to `main` and `pr-core` is required.
4. Labels needed for issue filing exist on the repo (`feature`, `chore`, `tier-1`, `tier-2`, `files`, `scaffold`, `adr-0061`, `wave-2`, `wave-3`, `human-only`, `out-of-band`).
5. The Grid's NuGet publishing OIDC federated credential has `repo:HoneyDrunkStudios/HoneyDrunk.Files:ref:refs/tags/v*` in its subject list so `release.yml` can publish at first tag push.

Surfacing this as an explicit Wave-2 work item keeps it visible on The Hive board as a human-only blocker on packet 04 instead of an implicit prerequisite buried in the scaffold packet's body. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` and `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md` — create-and-configure, not verify-and-clone.

## Steps

### Step 1 — Create the public repo (portal)

1. Open https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. Fill in:
   - **Repository name:** `HoneyDrunk.Files`
   - **Description:** `Grid-wide blob storage, media processing, signed-URL delivery, per-tenant quota, and the deletion cascade for tenant offboarding and GDPR erasure. Backing-agnostic by contract; Azure Blob Storage is the v1 default.`
   - **Visibility:** **Public** (per memory `project_repos_public_by_default` — Files substrate is a Core primitive, no revenue/compliance/experiment carve-out applies)
   - **Initialize this repository with:** check `.gitignore` (template: `VisualStudio`), check `LICENSE` (template: `MIT` — matches other Grid repos), do **not** add a README (packet 04 will author the README so it lands with the scaffold; if GitHub forces a README at create-time, that initial placeholder is overwritten by packet 04's commit)
3. Click **Create repository**.
4. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Files/settings — confirm:
   - **Default branch:** `main`
   - **Visibility:** Public
   - **Features:** Issues enabled, Actions enabled, Discussions optional (off by default is fine)

### Step 2 — Branch protection on `main`

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Files/settings/branches and create a branch protection rule on `main`:

- **Require a pull request before merging:** on
- **Require approvals:** off (solo developer; matches other Grid repos)
- **Require status checks to pass before merging:** on
- **Required status checks:** `pr-core / core` only for now. The `api-compatibility / abstractions-shape` check will be added to required-checks in a **follow-up branch-protection update** after the throwaway breaking-change PR confirms the canary fires post-merge — see packet 04 Human Prerequisites for the rationale (same first-PR `status: skipped` behavior as the Audit scaffold).
- **Allow force pushes:** off
- **Allow deletions:** off
- **Require signed commits:** off (matches other Grid repos)

Mirror the settings on `HoneyDrunkStudios/HoneyDrunk.Audit` if any field is unclear — Audit is the most-recent Core-sector substrate Node and is the closest template.

### Step 3 — Security analysis settings

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Files/settings/security_analysis and confirm:

- **Dependabot alerts:** Enabled (org default — should already be on)
- **Dependabot security updates:** **Off** (per memory `project_adr_0009_dependabot_stance` — alerts yes, auto-PRs no; grouped nightly-deps workflow replaces per-package Dependabot PRs)
- **CodeQL default-setup:** **Off** (per memory `project_github_security_configuration` — the org "HoneyDrunk Grid — public default" config keeps CodeQL default-setup off)
- **Secret scanning:** Enabled (org default)
- **Push protection:** Enabled

### Step 4 — Seed labels (CLI)

Run the following from any local directory with `gh` CLI authenticated as the org owner. Color choices follow the existing convention used by other Grid repos. **Per memory `project_windows_crlf_gotcha`, on Windows Git Bash the `gh` and `jq` output is CRLF — when piping through bash, `tr -d '\r'` may be needed. For this loop the labels are inline strings, so CRLF is not a risk; but if a label name appears mangled, that is the cause.**

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "files:5319E7" "scaffold:BFDADC" "adr-0061:1D76DB" "wave-2:FBCA04" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Files --color "$color" 2>/dev/null
done
```

If `gh label create` errors with "already exists" for any label, that is fine — it is idempotent for our purposes.

### Step 5 — Clone the repo locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.Files.git
cd HoneyDrunk.Files
git status
```

The clone should land at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Files/`. After cloning, confirm the working tree contains `.gitignore`, `LICENSE`, and possibly a placeholder `README.md` from the GitHub create step — and nothing else. Packet 04's scaffolding agent will overwrite the placeholder README and create everything else (`.slnx`, `src/`, `tests/`, `.github/workflows/`, `CHANGELOG.md`, etc.).

### Step 6 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm the Grid's NuGet publishing identity has `repo:HoneyDrunkStudios/HoneyDrunk.Files:ref:refs/tags/v*` in its federated credential subject list. If not, add it via the Azure portal (Microsoft Entra → App registrations → the Grid's NuGet publishing app registration → Certificates & secrets → Federated credentials → Add credential). Without this, `release.yml` will fail to obtain a token at first tag-push.

### Step 7 — Confirm Architecture-side prereq

Confirm packet 01 (the Architecture catalog registration packet) has merged to `main`. That packet creates the `repos/HoneyDrunk.Files/` context folder, registers `honeydrunk-files` in the catalogs, adds the Core-sector Files row to `sectors.md`, adds the Files row to `tech-stack.md`, adds the roadmap bullet, and adds the in-progress entry in `active-initiatives.md`. If packet 01 has not merged, this chore can still proceed (the GitHub-side actions are independent of Architecture-repo state) — but packet 04 (the scaffold) cannot proceed until packet 01 is in.

## Acceptance Criteria

- [ ] `HoneyDrunkStudios/HoneyDrunk.Files` repo exists on GitHub, is public, has default branch `main`, has Issues + Actions enabled.
- [ ] Repo initialized with `.gitignore` (VisualStudio template) and `LICENSE` (matching the Grid's existing LICENSE choice on other public repos — MIT unless verified otherwise).
- [ ] Branch protection on `main` requires `pr-core / core`, no force-pushes, no deletions, signed commits not required.
- [ ] Dependabot alerts: Enabled. Dependabot security updates: Off. CodeQL default-setup: Off. Secret scanning + push protection: Enabled.
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `files`, `scaffold`, `adr-0061`, `wave-2`, `wave-3`, `human-only`, `out-of-band` all exist on the repo.
- [ ] Local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Files/` exists, is a clean clone, contains `.gitignore` + `LICENSE` + at most a placeholder `README.md`.
- [ ] OIDC federated credential `repo:HoneyDrunkStudios/HoneyDrunk.Files:ref:refs/tags/v*` exists on the Grid's NuGet publishing identity in Microsoft Entra.
- [ ] Packet 01 of this initiative merged to `main` (confirmation step — not blocked by it for these GitHub-side actions, but packet 04 is).
- [ ] This chore issue is closed after all checks above are verified.
- [ ] After this chore is Done **and** packet 02 of this initiative has merged, packet 04 (`04-files-node-scaffold.md`) is fileable.

## Human Prerequisites

- [ ] Org-admin role on `HoneyDrunkStudios` (required to create the repo, set branch protection, and seed labels)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner
- [ ] Azure portal access for the OIDC federated credential check (Microsoft Entra → App registrations → NuGet publishing identity → Certificates & secrets → Federated credentials)
- [ ] Packet 01 of this initiative merged to `main` — confirms `repos/HoneyDrunk.Files/` context folder is registered and `honeydrunk-files` is in `catalogs/nodes.json`

## Dependencies

- `work-item:01` — Architecture catalog registration must have merged to `main` so the Architecture-side registration (catalog, sectors, context folder, tech-stack, roadmap, active-initiatives) is in place. The GitHub-side actions in this chore are technically independent of packet 01's merge, but the scaffold (packet 04) is not — surfacing the dependency here keeps the chain visible on The Hive board.

## Downstream Unblocks

- Packet 04 of this initiative (`04-files-node-scaffold.md`) becomes fileable the moment this chore is Done **and** packet 02 of this initiative has merged.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — New Node ⇒ new repo. This chore creates that repo.

> **Invariant 24:** Work items are immutable once filed. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This chore packet is filed in Wave 2 alongside the work that packet 02 (Wave 1) is wrapping up; pre-filing amendments to packet 04 (the scaffold) are permitted under invariant 24 if invariant numbers shift in packet 02.

## Referenced ADR Decisions

**ADR-0061 D1 (Files Node ownership):** `HoneyDrunk.Files` is the Core sector's single Node owning bytes + bytes-metadata. New Node ⇒ new repo per invariant 11.

**ADR-0061 §If Accepted — Required Follow-Up Work (line 12):** "Create `HoneyDrunk.Files` GitHub repo as **public** (per the build-in-public default for non-revenue Nodes; the bytes and metadata stored are the consuming Node's data, not Files' data — see D5)." This chore executes that checklist item.

**ADR-0009 (Dependabot stance, Accepted):** Dependabot alerts on, auto-PRs off. The grouped nightly-deps workflow replaces per-package Dependabot PRs. This chore configures the security_analysis settings accordingly in Step 3.

**Org GitHub security configuration (memory `project_github_security_configuration`):** "HoneyDrunk Grid — public default" config; CodeQL default-setup stays off (the Grid uses its own CodeQL invocation pattern, not the default-setup flow). Step 3 reflects this.

## Labels

`chore`, `tier-1`, `meta`, `files`, `adr-0061`, `human-only`, `wave-2`

## Notes for the human executing this chore

- This is a 10-minute task split across portal + CLI + Azure portal (for OIDC) + a single `git clone`. Most of the work is one-time configuration that establishes the repo for the rest of the initiative.
- The OIDC federated credential step (Step 6) is the only Azure portal step. The Grid has a standard NuGet publishing identity used by every Node; if this is the first new repo since the credential was set up, confirm the subject pattern allows tag-pushes from `HoneyDrunk.Files`.
- If GitHub forces a README at repo creation time, that placeholder is fine — packet 04 will overwrite it with the real scaffold README. Do not waste effort writing a temporary README here.
- Per memory `project_repos_public_by_default`: the Files Node is a reusable Core primitive. The bytes it stores are the consuming Node's data (a journal entry in Hearth, an avatar in Lately, an attachment in Notify Cloud); Files itself owns no revenue carve-out (it is substrate, not commercial product), no compliance carve-out (the *consumers* of Files carry classification concerns), no experimental branding worth hiding. Public is the right call — same reasoning as Audit, Capabilities, Communications.
- Per memory `feedback_provision_when_needed`: no Azure resources to provision yet. HoneyDrunk.Files is a library Node at standup (Abstractions + InMemory reference adapter + empty AzureBlob placeholder). Managed identity, Container App, Storage Account, Defender for Storage, Front Door, CDN, App Configuration keys for quota tier defaults — all deferred until the first deployable host composes `HoneyDrunk.Files.AzureBlob` (likely PDR-0005 Hearth's first media-bearing packet). Step 6's OIDC credential is the only Azure-side touch in this chore, and that is on Microsoft Entra (no resource provisioning).
