---
name: Repo Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "meta", "web-ui", "adr-0071", "human-only", "wave-2"]
dependencies: ["packet:01"]
adrs: ["ADR-0071"]
accepts: ADR-0071
wave: 2
initiative: adr-0071-web-ui-standup
node: honeydrunk-web-ui
actor: human
---

# Chore: Create `HoneyDrunk.Web.UI` public GitHub repo + npm scope verification + NPM_TOKEN + branch protection + labels + OIDC + clone locally (human-only)

## Summary
Create the public `HoneyDrunkStudios/HoneyDrunk.Web.UI` GitHub repo, apply the Grid's per-repo standard settings (branch protection, default branch, labels, Actions enabled, security analysis), verify or create the `@honeydrunk` npm scope under the HoneyDrunk Studios npm organization, seed the `NPM_TOKEN` repository (or org-level) secret so the scaffold packet's release workflow can publish `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` on first tag-push, wire the OIDC federated credential for tag-driven NuGet publishing of the future `HoneyDrunk.Web.UI.Blazor` package, and clone the repo locally so packet 04's scaffolding agent has a working tree to author into. This is an org-admin + npm-admin / human action that cannot be delegated to an agent — it gates packet 04.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture` (this is where the tracking issue lives; the actual work happens on GitHub at the org level + npmjs.com at the org level + locally on the user's machine)

## Actor
**`Human`.** Org-admin rights on `HoneyDrunkStudios` (GitHub) and admin rights on the `@honeydrunk` npm organization are required to create the repo, apply branch protection, seed labels, configure the OIDC federated credential, verify/claim the npm scope, and seed `NPM_TOKEN`. Frontmatter sets `actor: human` and labels include `human-only`; the filing pipeline mirrors `Actor=Human` onto The Hive.

## Motivation
`04-web-ui-node-scaffold.md` defines the monorepo layout, five package families (`@honeydrunk/web-ui-tokens` + `@honeydrunk/web-ui-css` shipped at v0.1.0; `@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native` as placeholders), pnpm workspace, build scripts, CI with npm publish-on-tag, etc. — but cannot be executed by the scaffolding agent until:

1. The `HoneyDrunkStudios/HoneyDrunk.Web.UI` GitHub repo exists. As of 2026-05-25 it does not (confirmed pre-scoping — neither the catalog entries nor the local working tree exist).
2. The local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Web.UI/` exists. As of 2026-05-25 it does not.
3. The `@honeydrunk` npm scope is owned by the HoneyDrunk Studios npm organization. **This must be claimed/verified before the first npm publish.** If the scope is already taken by an unrelated user, the package naming has to change — surfacing this here as a hard gate prevents a packet-04 surprise.
4. The `NPM_TOKEN` secret exists in the `HoneyDrunk.Web.UI` repo (or at the org level, accessible to the repo) so `release.yml` can authenticate to npmjs.com.
5. Branch protection rules are applied so the scaffolding PR cannot be force-pushed to `main` and `pr-core` is required.
6. Labels needed for issue filing exist on the repo (`feature`, `chore`, `tier-1`, `tier-2`, `web-ui`, `scaffold`, `adr-0071`, `wave-2`, `wave-3`, `human-only`, `out-of-band`).
7. The Grid's NuGet publishing OIDC federated credential has `repo:HoneyDrunkStudios/HoneyDrunk.Web.UI:ref:refs/tags/v*` in its subject list so the future `HoneyDrunk.Web.UI.Blazor` package can publish to NuGet at its eventual tag-push (the Blazor package is a 0.0.0 placeholder at v0.1.0, but the credential should be wired now so when the Blazor implementation lands and the version bumps, the publish flow is ready).

Surfacing this as an explicit Wave-2 work item with `Actor=Human` keeps it visible on The Hive board as a human-only blocker on packet 04 instead of an implicit prerequisite buried in the scaffold packet's body. Same shape as `adr-0061-files-standup/03-architecture-create-files-repo.md` and `adr-0031-audit-node-standup/02-architecture-create-audit-repo.md` — create-and-configure, not verify-and-clone. With the extra npm-scope step layered on because Web.UI is the first JS-shaped Node-standup the Grid has done.

## Steps

### Step 1 — Create the public repo (portal)

1. Open https://github.com/organizations/HoneyDrunkStudios/repositories/new
2. Fill in:
   - **Repository name:** `HoneyDrunk.Web.UI`
   - **Description:** `Cross-stack design system for the HoneyDrunk Grid — design tokens, primitive CSS, and component contracts shared across React, Blazor, and React Native consumers. Tokens cross-stack; components per-stack. The Creator sector's anchor Node.`
   - **Visibility:** **Public** (per memory `project_repos_public_by_default` — design substrate is exactly the build-in-public substrate the Grid licenses; no revenue/compliance/experiment carve-out applies)
   - **Initialize this repository with:** check `.gitignore` (template: `Node`), check `LICENSE` (template: `MIT` — matches other Grid repos), do **not** add a README (packet 04 will author the README so it lands with the scaffold; if GitHub forces a README at create-time, that initial placeholder is overwritten by packet 04's commit)
3. Click **Create repository**.
4. Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI/settings — confirm:
   - **Default branch:** `main`
   - **Visibility:** Public
   - **Features:** Issues enabled, Actions enabled, Discussions optional (off by default is fine)

### Step 2 — Verify or claim the `@honeydrunk` npm scope

This is the **most important Web.UI-specific step** — the npm scope must be confirmed before the scaffold can publish.

1. Open https://www.npmjs.com/ in a browser and sign in with the HoneyDrunk Studios npm account (or your operator account if it has admin on the HoneyDrunk Studios org).
2. Navigate to https://www.npmjs.com/settings/honeydrunk (or whatever the HoneyDrunk Studios npm organization slug is — verify at edit time).
   - **If the organization does not exist:** create it via https://www.npmjs.com/org/create. Name it `honeydrunk` (per ADR-0071 D6: "The npm packages live under the `@honeydrunk` scope"). The scope is `@honeydrunk`. Pick the free plan (public packages only) — paid plan is only needed for private packages, and Web.UI is public per ADR-0039.
   - **If the organization exists but the user account is not a member:** add the operator account as a member with admin role.
   - **If the `@honeydrunk` scope is taken by an unrelated user/org:** this is the hard-stop case. Options: (a) negotiate with the current owner to transfer or release the scope; (b) pick a different scope name (e.g., `@honeydrunk-studios`, `@hd-studios`, `@hdgrid`) and update ADR-0071 D6 + this packet + packet 01's catalog entries + packet 04's package.json files in lockstep. The scope name is **load-bearing** for every consumer's PackageReference; do not improvise.
3. **Verify scope is empty or contains only HoneyDrunk packages.** Run `npm view @honeydrunk/web-ui-tokens` and confirm `npm ERR! 404` (the package does not exist yet — packet 04 publishes it). If the package already exists and is owned by someone else, this is a name collision that needs resolution (most likely never published; this check is cheap insurance).
4. **Enable 2FA on the npm org** for security if not already on. (Org-level 2FA-required setting.)

### Step 3 — Seed `NPM_TOKEN`

1. On npmjs.com, navigate to https://www.npmjs.com/settings/{your-username}/tokens.
2. Click **Generate New Token** → **Classic Token** (or Granular Token if preferred; classic is simpler and works fine for org publishing).
3. Token type: **Automation** (CI-friendly; bypasses 2FA challenges on publish; required for the GitHub Actions publish flow). **Not Publish or Read-Only** — Automation is the correct selection for CI.
4. Scope: **Restrict to specific scopes** → `@honeydrunk` → **Read and write**.
5. Copy the token immediately — npm shows it only once.
6. **Decide the secret scope.** Two options:
   - **Org-level secret** (preferred for the Grid pattern): Open https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions and create `NPM_TOKEN` with the token value. Grant access to "Selected repositories" and include `HoneyDrunk.Web.UI` (and any future `@honeydrunk/...`-publishing repo). This matches the org-level `NUGET_API_KEY` pattern.
   - **Repo-level secret** (if org-level is unavailable for the user's npm pricing tier or other reason): Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI/settings/secrets/actions and create `NPM_TOKEN`.
7. Verify the secret name is **exactly** `NPM_TOKEN` (the reusable npm-publish workflow expects this name).

### Step 4 — Branch protection on `main`

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI/settings/branches and create a branch protection rule on `main`:

- **Require a pull request before merging:** on
- **Require approvals:** off (solo developer; matches other Grid repos)
- **Require status checks to pass before merging:** on
- **Required status checks:** `pr-core / core` only for now. Any package-publish-canary or contract-shape canary additions are deferred to a **follow-up branch-protection update** after the scaffold lands and the canary first runs cleanly — same first-PR `status: skipped` behavior as the Audit and Files scaffolds.
- **Allow force pushes:** off
- **Allow deletions:** off
- **Require signed commits:** off (matches other Grid repos)

Mirror the settings on `HoneyDrunkStudios/HoneyDrunk.Files` or `HoneyDrunkStudios/HoneyDrunk.Audit` if any field is unclear — those are the most-recent substrate Node standups and are the closest templates.

### Step 5 — Security analysis settings

Open https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI/settings/security_analysis and confirm:

- **Dependabot alerts:** Enabled (org default — should already be on)
- **Dependabot security updates:** **Off** (per memory `project_adr_0009_dependabot_stance` — alerts yes, auto-PRs no; grouped nightly-deps workflow replaces per-package Dependabot PRs)
- **CodeQL default-setup:** **Off** (per memory `project_github_security_configuration` — the org "HoneyDrunk Grid — public default" config keeps CodeQL default-setup off)
- **Secret scanning:** Enabled (org default)
- **Push protection:** Enabled

### Step 6 — Seed labels (CLI)

Run the following from any local directory with `gh` CLI authenticated as the org owner. Color choices follow the existing convention used by other Grid repos. **Per memory `project_windows_crlf_gotcha`, on Windows Git Bash the `gh` and `jq` output is CRLF — when piping through bash, `tr -d '\r'` may be needed. For this loop the labels are inline strings, so CRLF is not a risk; but if a label name appears mangled, that is the cause.**

```bash
for label in "feature:0E8A16" "chore:CCCCCC" "tier-1:E99695" "tier-2:FBCA04" "web-ui:14B8A6" "scaffold:BFDADC" "adr-0071:1D76DB" "wave-2:FBCA04" "wave-3:FBCA04" "human-only:B60205" "out-of-band:D4C5F9"; do
  name="${label%:*}"; color="${label#*:}"
  gh label create "$name" --repo HoneyDrunkStudios/HoneyDrunk.Web.UI --color "$color" 2>/dev/null
done
```

If `gh label create` errors with "already exists" for any label, that is fine — it is idempotent for our purposes. The `web-ui` label color `#14B8A6` matches the Creator sector chromeTeal per `constitution/sectors.md`.

### Step 7 — Clone the repo locally

```bash
cd c:/Users/tatte/source/repos/HoneyDrunkStudios/
git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.Web.UI.git
cd HoneyDrunk.Web.UI
git status
```

The clone should land at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Web.UI/`. After cloning, confirm the working tree contains `.gitignore`, `LICENSE`, and possibly a placeholder `README.md` from the GitHub create step — and nothing else. Packet 04's scaffolding agent will overwrite the placeholder README and create everything else (`package.json`, `pnpm-workspace.yaml`, `packages/`, `.github/workflows/`, `CHANGELOG.md`, etc.).

### Step 8 — Confirm OIDC federated credential (for future NuGet Blazor publish)

Cross-link: [`infrastructure/walkthroughs/oidc-federated-credentials.md`](../../../../infrastructure/walkthroughs/oidc-federated-credentials.md).

Confirm the Grid's NuGet publishing identity has `repo:HoneyDrunkStudios/HoneyDrunk.Web.UI:ref:refs/tags/v*` in its federated credential subject list. If not, add it via the Azure portal (Microsoft Entra → App registrations → the Grid's NuGet publishing app registration → Certificates & secrets → Federated credentials → Add credential). The `HoneyDrunk.Web.UI.Blazor` package is a 0.0.0 placeholder at v0.1.0 (no implementation), but wiring the credential now means the first feature packet that implements the Blazor component pack can tag-publish without an additional human gate.

### Step 9 — Confirm Architecture-side prereq

Confirm packet 01 (the Architecture catalog registration packet) has merged to `main`. That packet creates the `repos/HoneyDrunk.Web.UI/` context folder, registers `honeydrunk-web-ui` in the catalogs, anchors the Creator sector in `sectors.md`, captures Studios' tokens inventory at `repos/HoneyDrunk.Web.UI/studios-tokens-inventory.md` (which packet 04's scaffolding agent reads as the source for the first tokens release), adds the tech-stack rows, adds the roadmap bullet, and adds the in-progress entry in `active-initiatives.md`. If packet 01 has not merged, this chore can still proceed (the GitHub-side and npm-side actions are independent of Architecture-repo state) — but packet 04 (the scaffold) cannot proceed until packet 01 is in.

## Acceptance Criteria

- [ ] `HoneyDrunkStudios/HoneyDrunk.Web.UI` repo exists on GitHub, is public, has default branch `main`, has Issues + Actions enabled.
- [ ] Repo initialized with `.gitignore` (Node template) and `LICENSE` (MIT matching other Grid public repos).
- [ ] **`@honeydrunk` npm scope is verified as owned by the HoneyDrunk Studios npm organization, with the operator account having publish rights.** If the scope was unavailable, the alternative scope chosen is documented in the PR body and ADR-0071 D6 is updated in a separate amendment packet (out of scope here; flag and stop if encountered).
- [ ] `NPM_TOKEN` secret exists at org-level (or repo-level if org-level is unavailable) with **Automation** classification, scoped to `@honeydrunk` with read+write, and the `HoneyDrunk.Web.UI` repo has access to it.
- [ ] Branch protection on `main` requires `pr-core / core`, no force-pushes, no deletions, signed commits not required.
- [ ] Dependabot alerts: Enabled. Dependabot security updates: Off. CodeQL default-setup: Off. Secret scanning + push protection: Enabled.
- [ ] Labels `feature`, `chore`, `tier-1`, `tier-2`, `web-ui` (color `#14B8A6` — Creator sector chromeTeal), `scaffold`, `adr-0071`, `wave-2`, `wave-3`, `human-only`, `out-of-band` all exist on the repo.
- [ ] Local working tree at `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Web.UI/` exists, is a clean clone, contains `.gitignore` + `LICENSE` + at most a placeholder `README.md`.
- [ ] OIDC federated credential `repo:HoneyDrunkStudios/HoneyDrunk.Web.UI:ref:refs/tags/v*` exists on the Grid's NuGet publishing identity in Microsoft Entra (for the future `HoneyDrunk.Web.UI.Blazor` package's eventual publish).
- [ ] Packet 01 of this initiative merged to `main` (confirmation step — not blocked by it for these GitHub/npm-side actions, but packet 04 is).
- [ ] This chore issue is closed after all checks above are verified.
- [ ] After this chore is Done **and** packet 02 of this initiative has merged, packet 04 (`04-web-ui-node-scaffold.md`) is fileable.

## Human Prerequisites

- [ ] Org-admin role on `HoneyDrunkStudios` (required to create the repo, set branch protection, and seed labels)
- [ ] Admin role on the HoneyDrunk Studios npm organization (or ability to create the org if it does not exist)
- [ ] Browser with GitHub session logged in as the org owner
- [ ] Browser with npmjs.com session logged in as the user with publish rights
- [ ] `gh` CLI installed locally and authenticated as the org owner
- [ ] Azure portal access for the OIDC federated credential check (Microsoft Entra → App registrations → NuGet publishing identity → Certificates & secrets → Federated credentials)
- [ ] Packet 01 of this initiative merged to `main` — confirms `repos/HoneyDrunk.Web.UI/` context folder is registered and `honeydrunk-web-ui` is in `catalogs/nodes.json`

## Dependencies

- `packet:01` — Architecture catalog registration must have merged to `main` so the Architecture-side registration (catalog, sectors, context folder, tech-stack, roadmap, active-initiatives, Studios tokens inventory) is in place. The GitHub-side and npm-side actions in this chore are technically independent of packet 01's merge, but the scaffold (packet 04) is not — surfacing the dependency here keeps the chain visible on The Hive board.

## Downstream Unblocks

- Packet 04 of this initiative (`04-web-ui-node-scaffold.md`) becomes fileable the moment this chore is Done **and** packet 02 of this initiative has merged.

## Referenced Invariants

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — New Node ⇒ new repo. This chore creates that repo.

> **Invariant 24:** Issue packets are immutable once filed. Pre-filing amendments are permitted; post-filing corrections require a new packet. — This chore packet is filed in Wave 2 alongside the work that packet 02 (Wave 1) is wrapping up; pre-filing amendments to packet 04 (the scaffold) are permitted under invariant 24 if invariant numbers shift in packet 02 or if the npm scope choice changes.

## Referenced ADR Decisions

**ADR-0071 D1 (Web.UI Node ownership):** `HoneyDrunk.Web.UI` is the Creator sector's anchor Node owning design tokens, primitive CSS, and component contracts. New Node ⇒ new repo per invariant 11.

**ADR-0071 D6 (Package layout):** The npm packages live under the `@honeydrunk` scope (per the standard org convention). The NuGet package follows the existing `HoneyDrunk.*` naming. This packet verifies/claims the npm scope (Step 2) and wires both the npm publish credential (Step 3 — `NPM_TOKEN`) and the NuGet publish credential (Step 8 — OIDC federated credential).

**ADR-0071 §If Accepted — Required Follow-Up Work:** "Create `HoneyDrunk.Web.UI` GitHub repo as **public** (Grid default per ADR-0039; design tokens and CSS are the kind of substrate the build-in-public stance covers naturally)." This chore executes that checklist item, plus the npm-scope verification that the ADR's text implies but does not call out explicitly.

**ADR-0009 (Dependabot stance, Accepted):** Dependabot alerts on, auto-PRs off. The grouped nightly-deps workflow replaces per-package Dependabot PRs. This chore configures the security_analysis settings accordingly in Step 5.

**ADR-0039 (Grid open-source license policy):** Web.UI is public per the Grid default; license is MIT or equivalent. Step 1 specifies Visibility = Public and LICENSE template = MIT.

**Org GitHub security configuration (memory `project_github_security_configuration`):** "HoneyDrunk Grid — public default" config; CodeQL default-setup stays off (the Grid uses its own CodeQL invocation pattern, not the default-setup flow). Step 5 reflects this.

## Labels

`chore`, `tier-1`, `meta`, `web-ui`, `adr-0071`, `human-only`, `wave-2`

## Notes for the human executing this chore

- This is a 15-minute task split across GitHub portal + npm portal + CLI + Azure portal (for OIDC) + a single `git clone`. The npm-scope verification is the longest unfamiliar step if this is the first time the Grid has done JS publishing — budget the extra few minutes for navigating npm's org/scope/token UX.
- The OIDC federated credential step (Step 8) is the only Azure portal step. The Grid has a standard NuGet publishing identity used by every Node; if this is the first new repo since the credential was set up, confirm the subject pattern allows tag-pushes from `HoneyDrunk.Web.UI`.
- The `NPM_TOKEN` step (Step 3) is the **most consequential security step in this chore.** Use **Automation** classification, restrict scope to `@honeydrunk`, read+write only. If the token is ever exposed, rotate immediately by revoking on npmjs.com and regenerating.
- If GitHub forces a README at repo creation time, that placeholder is fine — packet 04 will overwrite it with the real scaffold README. Do not waste effort writing a temporary README here.
- Per memory `project_repos_public_by_default`: design substrate is exactly the kind of build-in-public substrate the Grid licenses — no carve-out applies. Public is the right call — same reasoning as Audit, Capabilities, Files, Communications, Studios.
- Per memory `feedback_provision_when_needed`: no Azure resources to provision yet. HoneyDrunk.Web.UI is a library Node at standup (published packages only — no runtime host, no Container App, no Function App). Storage Account, CDN, App Configuration, Managed Identity, Key Vault — none apply to Web.UI ever; it is a published-package substrate, not a service. The only "Azure touch" in this chore is the OIDC credential on Microsoft Entra (no resource provisioning).
- **If the `@honeydrunk` scope is unavailable**, this chore stops at Step 2 and a separate amendment packet to ADR-0071 D6 must rename the scope across (a) ADR-0071 D6, (b) packet 01's catalog entries that reference `@honeydrunk/...` package names, (c) packet 04's scaffolding body, (d) `repos/HoneyDrunk.Web.UI/overview.md` + `invariants.md` + `integration-points.md` from packet 01. This is a non-trivial pivot — flag and stop if encountered.
