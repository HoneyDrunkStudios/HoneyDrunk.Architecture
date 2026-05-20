---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "audit", "adr-0031", "human-only", "wave-1"]
dependencies: ["Architecture#108"]
adrs: ["ADR-0031", "ADR-0030"]
accepts: ADR-0031
wave: 1
initiative: adr-0031-audit-node-standup
node: honeydrunk-audit
actor: human
---

# Chore: Create `HoneyDrunk.Audit` public GitHub repo + branch protection + labels + OIDC + clone locally (human-only)

## Summary
Create the public `HoneyDrunkStudios/HoneyDrunk.Audit` GitHub repo, apply the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled, security analysis), wire the OIDC federated credential for tag-driven NuGet publishing, and clone the repo locally so packet 03's scaffolding agent has a working tree to author into. This is an org-admin / human action that cannot be delegated to an agent — it gates packet 03.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level + locally on the user's machine)

## Actor
**`Human`.** Org-admin rights on `HoneyDrunkStudios` are required to create the repo, apply branch protection, seed labels, configure the OIDC federated credential, and clone the repo locally. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation
`03-audit-node-scaffold.md` defines the solution, two packages, three contracts, Data-backed append-only store, in-memory test fixture, and CI pipeline for `HoneyDrunk.Audit` but cannot be executed by the scaffolding agent until:

1. The `HoneyDrunkStudios/HoneyDrunk.Audit` GitHub repo exists. As of 2026-05-20 it does not (confirmed pre-scoping — the catalog entries exist via ADR-0030 packet 01, but the actual GitHub repo has not been created).
2. The local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Audit/` exists. As of 2026-05-20 it does not.
3. Branch protection rules are applied so the scaffolding PR cannot be force-pushed to `main` and `pr-core` is required.
4. Labels needed for issue filing exist on the repo (`feature`, `chore`, `tier-1`, `tier-2`, `audit`, `scaffold`, `adr-0031`, `wave-2`, `wave-3`, `human-only`, `out-of-band`).
5. The Grid's NuGet publishing OIDC federated credential has `repo:HoneyDrunkStudios/HoneyDrunk.Audit:ref:refs/tags/v*` in its subject list so `release.yml` can publish at first tag push.

Surfacing this as an explicit Wave-1 work item keeps it visible on The Hive board as a human-only blocker on packet 03 instead of an implicit prerequisite. Same shape as `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` — create-and-configure, not verify-and-clone (the HoneyDrunk.Audit repo was not pre-created during ADR-0031 drafting, unlike the AI repo).

## Steps

### Step 1 — Create the public repo (portal)

1. Open https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. Fill in:
   - **Repository name:** `HoneyDrunk.Audit`
   - **Description:** `Grid-wide durable, attributable security and action record. Append-only by interface; Data-backed; audit-class retention distinct from observability.`
   - **Visibility:** **Public** (per memory `project_repos_public_by_default` — audit substrate is a Core primitive, no carve-out applies)
   - **Initialize this repository with:** check `.gitignore` (template: `VisualStudio`), check `LICENSE` (template: `MIT` — matches other Grid repos; confirm with the Grid's existing LICENSE choice), do **not** add a README (packet 03 will author the README so it lands with the scaffold; if GitHub forces a README at create-time, that initial placeholder is overwritten by packet 03's commit)
3. Click **Create repository**.
4. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Audit/settings — confirm:
   - **Default branch:** `main`
   - **Visibility:** Public
   - **Features:** Issues enabled, Actions enabled, Discussions optional (off by default is fine)

### Step 2 — Branch protection on `main`

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Audit/settings/branches and create a branch protection rule on `main`:

- **Require a pull request before merging:** on
- **Require approvals:** off (solo developer; matches other Grid repos)
- **Require status checks to pass before merging:** on
- **Required status checks:** `pr-core / core` only for now. The `api-compatibility / abstractions-shape` check will be added to required-checks in a **follow-up branch-protection update** after the throwaway breaking-change PR confirms the canary fires post-merge — see packet 03 Human Prerequisites for the rationale (same first-PR `status: skipped` behavior as the AI scaffold).
- **Allow force pushes:** off
- **Allow deletions:** off
- **Require signed commits:** off (matches other Grid repos)

Mirror the settings on `HoneyDrunkStudios/HoneyDrunk.Auth` if any field is unclear.

### Step 3 — Security analysis settings

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Audit/settings/security_analysis and confirm:

- **Dependabot alerts:** Enabled (org default — should already be on)
- **Dependabot security updates:** **Off** (per memory `project_adr_0009_dependabot_stance` — alerts yes, auto-PRs no; grouped nightly-deps workflow replaces per-package Dependabot PRs)
- **CodeQL default-setup:** **Off** (per memory `project_github_security_configuration` — the org "HoneyDrunk Grid — public default" config keeps CodeQL default-setup off)
- **Secret scanning:** Enabled (org default)
- **Push protection:** Enabled

### Step 4 — Seed labels (CLI)

Run the following from any local directory with `gh` CLI authenticated as the org owner. Color choices follow the existing convention used by other Grid repos. **Per memory `project_windows_crlf_gotcha`, on Windows Git Bash the `gh` and `jq` output is CRLF — when piping through bash, `tr -d '\r'` may be needed. For this loop the labels are inline strings, so CRLF is not a risk; but if a label name appears mangled, that is the cause.**

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "audit:5319E7" "scaffold:BFDADC" "adr-0031:1D76DB" "wave-2:FBCA04" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Audit --color "$color" 2>/dev/null
done
```

If `gh label create` errors with "already exists" for any label, that is fine — it is idempotent for our purposes.

### Step 5 — Clone the repo locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.Audit.git
cd HoneyDrunk.Audit
git status
```

The clone should land at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Audit/`. After cloning, confirm the working tree contains `.gitignore`, `LICENSE`, and possibly a placeholder `README.md` from the GitHub create step — and nothing else. Packet 03's scaffolding agent will overwrite the placeholder README and create everything else (`.slnx`, `src/`, `tests/`, `.github/workflows/`, `CHANGELOG.md`, etc.).

### Step 6 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm the Grid's NuGet publishing identity has `repo:HoneyDrunkStudios/HoneyDrunk.Audit:ref:refs/tags/v*` in its federated credential subject list. If not, add it via the Azure portal (Microsoft Entra → App registrations → the Grid's NuGet publishing app registration → Certificates & secrets → Federated credentials → Add credential). Without this, `release.yml` will fail to obtain a token at first tag-push.

### Step 7 — Confirm Architecture-side prereq

Confirm Architecture#108 (ADR-0030 packet 01) has merged to `main`. That packet creates the `repos/HoneyDrunk.Audit/` context folder, registers `honeydrunk-audit` in the catalogs, adds the Core-sector Audit row to `sectors.md`, flips ADR-0030 Status to Accepted, and registers the initiative + roadmap bullet. If ADR-0030 packet 01 has not merged, this chore can still proceed (the GitHub-side actions are independent of Architecture-repo state) — but packet 03 (the scaffold) cannot proceed until ADR-0030 packet 01 is in.

## Acceptance Criteria

- [ ] `HoneyDrunkStudios/HoneyDrunk.Audit` repo exists on GitHub, is public, has default branch `main`, has Issues + Actions enabled.
- [ ] Repo initialized with `.gitignore` (VisualStudio template) and `LICENSE` (matching the Grid's existing LICENSE choice on other public repos — MIT unless verified otherwise).
- [ ] Branch protection on `main` requires `pr-core / core`, no force-pushes, no deletions, signed commits not required.
- [ ] Dependabot alerts: Enabled. Dependabot security updates: Off. CodeQL default-setup: Off. Secret scanning + push protection: Enabled.
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `audit`, `scaffold`, `adr-0031`, `wave-2`, `wave-3`, `human-only`, `out-of-band` all exist on the repo.
- [ ] Local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Audit/` exists, is a clean clone, contains `.gitignore` + `LICENSE` + at most a placeholder `README.md`.
- [ ] OIDC federated credential `repo:HoneyDrunkStudios/HoneyDrunk.Audit:ref:refs/tags/v*` exists on the Grid's NuGet publishing identity in Microsoft Entra.
- [ ] Architecture#108 merged to `main` (confirmation step — not blocked by it for these GitHub-side actions, but packet 03 is).
- [ ] This chore issue is closed after all checks above are verified.
- [ ] After this chore is Done **and** packet 01 of this initiative has merged, packet 03 (`03-audit-node-scaffold.md`) is fileable.

## Human Prerequisites

- [ ] Org-admin role on `HoneyDrunkStudios` (required to create the repo, set branch protection, and seed labels)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner
- [ ] Azure portal access for the OIDC federated credential check (Microsoft Entra → App registrations → NuGet publishing identity → Certificates & secrets → Federated credentials)
- [ ] Architecture#108 (ADR-0030 packet 01) merged to `main` — confirms `repos/HoneyDrunk.Audit/` context folder is registered and `honeydrunk-audit` is in `catalogs/nodes.json`

## Dependencies

- `Architecture#108` — ADR-0030 packet 01 must have merged to `main` so the Architecture-side registration (catalog, sectors, context folder, ADR-0018 amendment verification, initiative + roadmap bullets) is in place. The GitHub-side actions in this chore are technically independent of ADR-0030 packet 01's merge, but the scaffold (packet 03) is not — surfacing the dependency here keeps the chain visible on The Hive board.

## Downstream Unblocks

- Packet 03 of this initiative (`03-audit-node-scaffold.md`) becomes fileable the moment this chore is Done **and** packet 01 of this initiative has merged.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — New Node ⇒ new repo. This chore creates that repo.

> **Invariant 24:** Issue packets are immutable once filed. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This chore packet is filed in Wave 1 alongside packet 01; pre-filing amendments to packet 03 (the scaffold) are permitted under invariant 24 if invariant numbers shift in packet 01.

## Referenced ADR Decisions

**ADR-0031 D1 (Audit Node ownership):** `HoneyDrunk.Audit` is the Core sector's single Node owning the Grid's durable, attributable security-and-action record. New Node ⇒ new repo per invariant 11.

**ADR-0031 §If Accepted — Required Follow-Up Work (line 12):** "Create the `HoneyDrunk.Audit` GitHub repo as **public** (Grid default; no revenue/compliance/experiment carve-out applies — audit substrate is a reusable Core primitive)." This chore executes that checklist item.

**ADR-0009 (Dependabot stance, Accepted):** Dependabot alerts on, auto-PRs off. The grouped nightly-deps workflow replaces per-package Dependabot PRs. This chore configures the security_analysis settings accordingly in Step 3.

**Org GitHub security configuration (memory `project_github_security_configuration`):** "HoneyDrunk Grid — public default" config; CodeQL default-setup stays off (the Grid uses its own CodeQL invocation pattern, not the default-setup flow). Step 3 reflects this.

## Labels

`chore`, `tier-1`, `meta`, `audit`, `adr-0031`, `human-only`, `wave-1`

## Notes for the human executing this chore

- This is a 10-minute task split across portal + CLI + Azure portal (for OIDC) + a single `git clone`. Most of the work is one-time configuration that establishes the repo for the rest of the initiative.
- The OIDC federated credential step (Step 6) is the only Azure portal step. The Grid has a standard NuGet publishing identity used by every Node; if this is the first new repo since the credential was set up, confirm the subject pattern allows tag-pushes from `HoneyDrunk.Audit`.
- If GitHub forces a README at repo creation time, that placeholder is fine — packet 03 will overwrite it with the real scaffold README. Do not waste effort writing a temporary README here.
- Per memory `project_repos_public_by_default`: the Audit Node is a reusable Core primitive (durable, attributable Grid-wide security record). No revenue-stream secret-sauce, no compliance carve-out (this is the foundation that compliance would build on), no experimental branding worth hiding. Public is the right call.
- Per memory `feedback_provision_when_needed`: no Azure resources to provision yet. HoneyDrunk.Audit is a library Node at Phase 1 (both `Abstractions` and `Data` packages are libraries). Managed identity, Container Apps, App Configuration keys for retention — all deferred until the first deployable host composes `HoneyDrunk.Audit.Data`. Step 6's OIDC credential is the only Azure-side touch in this chore, and that is on Microsoft Entra (no resource provisioning).
