---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "core", "identity", "adr-0060", "human-only", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0060"]
accepts: ADR-0060
wave: 1
initiative: adr-0060-identity-standup
node: honeydrunk-identity
actor: human
---

# Chore: Create `HoneyDrunk.Identity` public GitHub repo + branch protection + labels + OIDC + clone locally (human-only)

## Summary

Create the public `HoneyDrunkStudios/HoneyDrunk.Identity` GitHub repo, apply the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled, security analysis), wire the OIDC federated credential for tag-driven NuGet publishing, and clone the repo locally so packet 04's scaffolding agent has a working tree to author into. This is an org-admin / human action that cannot be delegated to an agent — it gates packet 04.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level + locally on the user's machine)

## Actor

**`Human`.** Org-admin rights on `HoneyDrunkStudios` are required to create the repo, apply branch protection, seed labels, configure the OIDC federated credential, and clone the repo locally. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation

`04-identity-node-scaffold.md` defines the solution, two packages, six interfaces + seven records, Data-backed user-record and claim-map stores, in-memory test fixtures, and CI pipeline for `HoneyDrunk.Identity` but cannot be executed by the scaffolding agent until:

1. The `HoneyDrunkStudios/HoneyDrunk.Identity` GitHub repo exists. As of scoping (2026-05-24) it does not — ADR-0060 was Proposed on 2026-05-23 and the repo has not been created.
2. The local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Identity/` exists. As of scoping it does not.
3. Branch protection rules are applied so the scaffolding PR cannot be force-pushed to `main` and `pr-core` is required.
4. Labels needed for issue filing exist on the repo (`feature`, `chore`, `tier-1`, `tier-2`, `core`, `identity`, `scaffold`, `adr-0060`, `wave-2`, `human-only`, `out-of-band`).
5. The Grid's NuGet publishing OIDC federated credential has `repo:HoneyDrunkStudios/HoneyDrunk.Identity:ref:refs/tags/v*` in its subject list so `release.yml` can publish at first tag push.

Surfacing this as an explicit Wave-1 work item keeps it visible on The Hive board as a human-only blocker on packet 04 instead of an implicit prerequisite. Same shape as `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md` and `adr-0017-capabilities-standup/03-architecture-create-capabilities-repo.md` — create-and-configure, not verify-and-clone (the Identity repo was not pre-created during ADR-0060 drafting).

## Steps

### Step 1 — Create the public repo (portal)

1. Open https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. Fill in:
   - **Repository name:** `HoneyDrunk.Identity`
   - **Description:** `Core-sector owner of the canonical Grid user record, the external-IdP seam, short-lived internal-token issuance, and account-deletion fan-out. Wraps an external IdP; stores zero credentials.`
   - **Visibility:** **Public** (per memory `project_repos_public_by_default` — identity-layer code, not credential storage; no revenue/compliance/experiment carve-out applies)
   - **Initialize this repository with:** check `.gitignore` (template: `VisualStudio`), check `LICENSE` (template: `MIT` — matches other Grid repos; confirm with the Grid's existing LICENSE choice), do **not** add a README (packet 04 will author the README so it lands with the scaffold; if GitHub forces a README at create-time, that initial placeholder is overwritten by packet 04's commit)
3. Click **Create repository**.
4. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Identity/settings — confirm:
   - **Default branch:** `main`
   - **Visibility:** Public
   - **Features:** Issues enabled, Actions enabled, Discussions optional (off by default is fine)

### Step 2 — Branch protection on `main`

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Identity/settings/branches and create a branch protection rule on `main`:

- **Require a pull request before merging:** on
- **Require approvals:** off (solo developer; matches other Grid repos)
- **Require status checks to pass before merging:** on
- **Required status checks:** `pr-core / core` only for now. The `api-compatibility / abstractions-shape` check will be added to required-checks in a **follow-up branch-protection update** after the throwaway breaking-change PR confirms the canary fires post-merge — see packet 04 Human Prerequisites for the rationale (same first-PR `status: skipped` behavior as the Audit/AI scaffold).
- **Allow force pushes:** off
- **Allow deletions:** off
- **Require signed commits:** off (matches other Grid repos)

Mirror the settings on `HoneyDrunkStudios/HoneyDrunk.Audit` if any field is unclear.

### Step 3 — Security analysis settings

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Identity/settings/security_analysis and confirm:

- **Dependabot alerts:** Enabled (org default — should already be on)
- **Dependabot security updates:** **Off** (per memory `project_adr_0009_dependabot_stance` — alerts yes, auto-PRs no; grouped nightly-deps workflow replaces per-package Dependabot PRs)
- **CodeQL default-setup:** **Off** (per memory `project_github_security_configuration` — the org "HoneyDrunk Grid — public default" config keeps CodeQL default-setup off)
- **Secret scanning:** Enabled (org default)
- **Push protection:** Enabled

### Step 4 — Seed labels (CLI)

Run the following from any local directory with `gh` CLI authenticated as the org owner. Color choices follow the existing convention used by other Grid repos. **Per memory `project_windows_crlf_gotcha`, on Windows Git Bash the `gh` and `jq` output is CRLF — when piping through bash, `tr -d '\r'` may be needed. For this loop the labels are inline strings, so CRLF is not a risk; but if a label name appears mangled, that is the cause.**

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "core:7B61FF" "identity:5319E7" "scaffold:BFDADC" "adr-0060:1D76DB" "wave-2:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Identity --color "$color" 2>/dev/null
done
```

If `gh label create` errors with "already exists" for any label, that is fine — it is idempotent for our purposes.

### Step 5 — Clone the repo locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.Identity.git
cd HoneyDrunk.Identity
git status
```

The clone should land at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Identity/`. After cloning, confirm the working tree contains `.gitignore`, `LICENSE`, and possibly a placeholder `README.md` from the GitHub create step — and nothing else. Packet 04's scaffolding agent will overwrite the placeholder README and create everything else (`.slnx`, `src/`, `tests/`, `.github/workflows/`, `CHANGELOG.md`, etc.).

After cloning, also add the new path to the workspace's additional working directories list if the user's environment maintains one. (The Architecture repo's tooling may auto-discover; if not, mention the new path to the user.)

### Step 6 — Confirm OIDC federated credential

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm the Grid's NuGet publishing identity has `repo:HoneyDrunkStudios/HoneyDrunk.Identity:ref:refs/tags/v*` in its federated credential subject list. If not, add it via the Azure portal (Microsoft Entra → App registrations → the Grid's NuGet publishing app registration → Certificates & secrets → Federated credentials → Add credential). Without this, `release.yml` will fail to obtain a token at first tag-push.

### Step 7 — Confirm Architecture-side prereq

Confirm `packet:01` (Architecture catalog registration + ADR-0050/Auth amendments) has merged to `main`. That packet creates the `repos/HoneyDrunk.Identity/` context folder, registers `honeydrunk-identity` in the catalogs, adds the Core-sector Identity row to `sectors.md`, lands the ADR-0050 amendment, and amends the Auth context files. If packet 01 has not merged, this chore can still proceed (the GitHub-side actions are independent of Architecture-repo state) — but packet 04 (the scaffold) cannot proceed until packet 01 is in.

## Acceptance Criteria

- [ ] `HoneyDrunkStudios/HoneyDrunk.Identity` repo exists on GitHub, is public, has default branch `main`, has Issues + Actions enabled.
- [ ] Repo initialized with `.gitignore` (VisualStudio template) and `LICENSE` (matching the Grid's existing LICENSE choice on other public repos — MIT unless verified otherwise).
- [ ] Branch protection on `main` requires `pr-core / core`, no force-pushes, no deletions, signed commits not required.
- [ ] Dependabot alerts: Enabled. Dependabot security updates: Off. CodeQL default-setup: Off. Secret scanning + push protection: Enabled.
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `core`, `identity`, `scaffold`, `adr-0060`, `wave-2`, `human-only`, `out-of-band` all exist on the repo.
- [ ] Local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Identity/` exists, is a clean clone, contains `.gitignore` + `LICENSE` + at most a placeholder `README.md`.
- [ ] OIDC federated credential `repo:HoneyDrunkStudios/HoneyDrunk.Identity:ref:refs/tags/v*` exists on the Grid's NuGet publishing identity in Microsoft Entra.
- [ ] Packet 01 of this initiative merged to `main` (confirmation step — the GitHub-side actions are independent of it, but packet 04 is not).
- [ ] This chore issue is closed after all checks above are verified.
- [ ] After this chore is Done **and** packet 02 of this initiative has merged (so packet 04's invariant-number placeholders can be substituted pre-filing), packet 04 (`04-identity-node-scaffold.md`) is fileable.

## Human Prerequisites

- [ ] Org-admin role on `HoneyDrunkStudios` (required to create the repo, set branch protection, and seed labels)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] `gh` CLI installed locally and authenticated as the org owner
- [ ] Azure portal access for the OIDC federated credential check (Microsoft Entra → App registrations → NuGet publishing identity → Certificates & secrets → Federated credentials)
- [ ] `packet:01` of this initiative merged to `main` — confirms `repos/HoneyDrunk.Identity/` context folder is registered and `honeydrunk-identity` is in `catalogs/nodes.json`

## Dependencies

- `packet:01` — Packet 01 of this initiative must have merged to `main` so the Architecture-side registration (catalog, sectors, context folder, ADR-0050 amendment, Auth context amendments) is in place. The GitHub-side actions in this chore are technically independent of packet 01's merge, but the scaffold (packet 04) is not — surfacing the dependency here keeps the chain visible on The Hive board.

## Downstream Unblocks

- Packet 04 of this initiative (`04-identity-node-scaffold.md`) becomes fileable the moment this chore is Done **and** packet 02 of this initiative has merged (so packet 04's invariant-number placeholders can be substituted pre-filing).

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — New Node ⇒ new repo. This chore creates that repo.

> **Invariant 24:** Issue packets are immutable once filed. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This chore packet is filed in Wave 1 alongside packet 01 and packet 02; pre-filing amendments to packet 04 (the scaffold) are permitted under invariant 24 if invariant numbers shift in packet 02.

## Referenced ADR Decisions

**ADR-0060 D1 (Identity Node ownership):** `HoneyDrunk.Identity` is the Core sector's single Node owning the user record, the external-IdP seam, internal-token issuance, and account-deletion fan-out. New Node ⇒ new repo per invariant 11.

**ADR-0060 §If Accepted — Required Follow-Up Work (item 1):** "Create `HoneyDrunk.Identity` GitHub repo as **public** (Grid default; identity-layer code, not credential storage — see D2)." This chore executes that checklist item.

**ADR-0060 D9 (Identity Node has its own managed identity):** The Identity Node runs under its own dedicated managed identity, distinct from Auth's, Audit's, and Operator's. The managed identity is needed at the moment a deployable host composes `HoneyDrunk.Identity` (Phase 2 — first user-facing app's feature packet). This chore does not provision the managed identity; it only creates the GitHub repo. The Azure provisioning belongs with whichever packet first deploys an Identity-composing host.

**ADR-0009 (Dependabot stance, Accepted):** Dependabot alerts on, auto-PRs off. The grouped nightly-deps workflow replaces per-package Dependabot PRs. This chore configures the security_analysis settings accordingly in Step 3.

**Org GitHub security configuration (memory `project_github_security_configuration`):** "HoneyDrunk Grid — public default" config; CodeQL default-setup stays off (the Grid uses its own CodeQL invocation pattern, not the default-setup flow). Step 3 reflects this.

## Labels

`chore`, `tier-1`, `meta`, `core`, `identity`, `adr-0060`, `human-only`, `wave-1`

## Notes for the human executing this chore

- This is a 10-minute task split across portal + CLI + Azure portal (for OIDC) + a single `git clone`. Most of the work is one-time configuration that establishes the repo for the rest of the initiative.
- The OIDC federated credential step (Step 6) is the only Azure portal step. The Grid has a standard NuGet publishing identity used by every Node; if this is the first new repo since the credential was set up, confirm the subject pattern allows tag-pushes from `HoneyDrunk.Identity`.
- If GitHub forces a README at repo creation time, that placeholder is fine — packet 04 will overwrite it with the real scaffold README. Do not waste effort writing a temporary README here.
- Per memory `project_repos_public_by_default`: HoneyDrunk.Identity is identity-layer code, not credential storage. The credential store lives in the external IdP per ADR-0060 D2. No revenue-stream secret-sauce, no compliance carve-out (this is the substrate that future compliance work would build on, not the compliance result), no experimental branding worth hiding. Public is the right call.
- Per memory `feedback_provision_when_needed`: no Azure resources to provision yet. HoneyDrunk.Identity at Phase 1 ships an Abstractions library + a runtime library; Phase 2 adds the IdP adapter; Phase 2/3 deploys the runtime as a Container App (per ADR-0060 D9). Managed identity, Container Apps, App Configuration keys for IdP-vendor config, Key Vault for the internal-token signing key — all deferred until the first deployable host composes `HoneyDrunk.Identity`. Step 6's OIDC credential is the only Azure-side touch in this chore, and that is on Microsoft Entra (no resource provisioning).
