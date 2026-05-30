---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "infrastructure", "adr-0011", "wave-1"]
dependencies: ["Architecture#NN — ADR-0011 acceptance (packet 01)"]
adrs: ["ADR-0011"]
wave: 1
initiative: adr-0011-code-review-pipeline
node: honeydrunk-architecture
---

# Feature: Portal walkthrough — SonarCloud organization setup, GitHub App install, `SONAR_TOKEN` org secret

## Summary
Author a portal-first walkthrough for the one-time SonarCloud setup that ADR-0011 D11's rollout depends on: create the `honeydrunkstudios` SonarCloud organization, link it to the GitHub org, install the SonarCloud GitHub App on every existing public repo, generate the org-level `SONAR_TOKEN`, and provision it as a `HoneyDrunkStudios` GitHub org secret. Index the new walkthrough in `infrastructure/README.md`.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0011 D11's "Follow-up Work" calls out exactly this: *"SonarCloud organization setup — create the `honeydrunkstudios` SonarCloud organization, link it to the GitHub org, install the SonarCloud GitHub App on public repos, provision `SONAR_TOKEN` as an org secret. Portal walkthrough in `HoneyDrunk.Architecture/infrastructure/` per the 'prefer portal over CLI' convention."*

Per established memory and convention, infrastructure setup work is documented as a portal walkthrough — not as a CLI script. The walkthrough is the **source of truth** for the click path, and the human follows it once during initial provisioning. Per-repo onboardings (packets 06, 07, and the deferred Wave-3 fan-out) all assume the org-level setup is in place; this packet ships that walkthrough.

This packet is `Actor=Agent` for the **doc-authoring** part: the agent writes the walkthrough markdown using the existing `infrastructure/*.md` style, indexes it, and adds appropriate cross-links. The actual portal clicks happen as **Human Prerequisites** — the human runs through SonarCloud's UI to create the org and seed the secret. The doc and the portal work happen on the same wave because they validate each other: the human follows the walkthrough as written, and the walkthrough is corrected if the click path is inaccurate.

## Proposed Implementation

Create `infrastructure/sonarcloud-organization-setup.md` matching the existing portal-first walkthrough structure used by `key-vault-creation.md`, `oidc-federated-credentials.md`, `app-configuration-provisioning.md`, etc. Sections:

1. **Goal** — one paragraph: stand up SonarCloud as the third-party static analysis tool for public HoneyDrunk repos, with PR decoration via the SonarCloud GitHub App and CI authentication via an org-level `SONAR_TOKEN`. One-time per-org setup; per-repo import is a separate walkthrough/packet.
2. **Prerequisites** — checklist:
   - Repo admin / GitHub org owner role
   - A SonarCloud account (free tier; sign in with GitHub recommended)
   - The list of public Grid repos that should be imported (everything currently in `catalogs/nodes.json` with a public GitHub repo, excluding `HoneyDrunk.Studios` which is TypeScript and onboards separately as a future packet)
3. **Portal Breadcrumb** — `https://sonarcloud.io → Sign in with GitHub → + → Create Organization → Free plan → Choose HoneyDrunkStudios`
4. **Step-by-step** — walk through each SonarCloud screen with bullet-level guidance:
   - **Step 1 — Sign in with GitHub.** Authorize SonarCloud's GitHub App to read the `HoneyDrunkStudios` org. Note that this is the SonarCloud OAuth grant, not the per-repo GitHub App install (that happens in step 4).
   - **Step 2 — Create the SonarCloud organization.** Choose "Free" plan; name it `honeydrunkstudios`; bind it to the `HoneyDrunkStudios` GitHub org.
   - **Step 3 — Verify free-tier eligibility.** SonarCloud's free tier covers public repos at zero cost. The org page should display "Free plan — public repos" with no payment method required. Confirm this before continuing.
   - **Step 4 — Install the SonarCloud GitHub App on public repos.** From SonarCloud → Administration → Bind organization, follow the link to GitHub, install the SonarCloud app on the `HoneyDrunkStudios` org, and **explicitly select the public repos to onboard** (do not use "All repositories" — private repos are intentionally excluded per ADR-0011 D11). The list to install on, today, is:
     - HoneyDrunk.Kernel
     - HoneyDrunk.Transport
     - HoneyDrunk.Vault
     - HoneyDrunk.Vault.Rotation
     - HoneyDrunk.Auth
     - HoneyDrunk.Web.Rest
     - HoneyDrunk.Data
     - HoneyDrunk.Pulse
     - HoneyDrunk.Notify
     - HoneyDrunk.Actions
     - HoneyDrunk.Architecture
     - (any future public Grid repo — onboarded ad-hoc when added)
     - **Excluded:** HoneyDrunk.Studios (TypeScript/Next.js — separate onboarding when needed)
   - **Step 5 — Generate `SONAR_TOKEN`.** From SonarCloud → My Account → Security → Generate Token. Token type: **User Token** scoped to organization analysis. Set a long expiration (12 months minimum, 24 months preferred) and add a calendar reminder to rotate before expiry. Copy the token value to a temporary secure clipboard manager — SonarCloud does not show it again.
   - **Step 6 — Provision the GitHub org secret.** Browse to `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions → New organization secret`. Name: `SONAR_TOKEN` (exact, all caps). Value: the token from step 5. Repository access: choose **"Selected repositories"** and pick the same list as step 4. Do NOT use "All repositories" — that grants the secret to private repos, which violates ADR-0011 D11's "private-repo SonarCloud is opt-in only" posture.
5. **Post-create hardening** — checklist:
   - [ ] Confirm the SonarCloud org dashboard now lists every onboarded repo as "Free — public"
   - [ ] Set a calendar reminder for the `SONAR_TOKEN` expiration date (and a second reminder 30 days before expiry to rotate)
   - [ ] In SonarCloud Organization Settings, confirm "Default New Code definition" is set to "Number of days" → 30 (default) — this controls the New-Code analysis window for the quality gate
   - [ ] In SonarCloud Organization Settings → Security → confirm "Two-factor authentication required" is on
   - [ ] If a future private Grid repo wants SonarCloud coverage, that is a separate per-repo opt-in packet — do not add private repos to the SonarCloud org via "All repositories"
6. **Quality gate posture (per ADR-0011 D11)** — short note:
   - Default quality gate is "Sonar way" (the SonarCloud built-in). It is acceptable as a starting point.
   - Each per-repo onboarding packet (Wave 2 + Wave 3) is responsible for adding the SonarCloud check to that repo's branch protection so the quality gate becomes enforcing per invariant 31's tier-2 reading.
   - Quality gate failures show up as PR check failures — same surface as `pr-core.yml` checks.
7. **Cost discipline** — explicit confirmation that this provisioning is **zero recurring cost** under SonarCloud's free public-tier pricing. Document the threshold at which costs change (private repos = paid per LOC; the free tier covers unlimited public repos). One-line note that any future private-repo SonarCloud onboarding requires a packet that justifies the cost in its own right (ADR-0011 D11 Gap 5).
8. **References**:
   - ADR-0011 (Code Review and Merge Flow) — D11 SonarCloud choice; this walkthrough operationalizes the "If Accepted" follow-up bullet
   - SonarCloud documentation: `https://docs.sonarsource.com/sonarcloud/`
   - GitHub org secrets documentation: `https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-an-organization`
   - Cross-link to `key-vault-rbac-assignments.md` for the prefer-portal-over-CLI convention this walkthrough follows
   - Cross-link to `azure-naming-conventions.md` for the "named org-level secret" precedent (this is GitHub, not Azure, but the discipline is the same)

### Indexing

In `infrastructure/README.md`, add a new entry to the Walkthrough Index in alphabetical order under a "Tooling / CI" subsection (or at the bottom of the index if no subsections exist):

- `sonarcloud-organization-setup.md` — One-time SonarCloud organization creation, GitHub App install on public repos, and `SONAR_TOKEN` org-level secret provisioning. Required before per-repo SonarCloud onboarding packets can run.

Add ADR-0011 to the References section if it is not already listed.

## Affected Files
- `infrastructure/sonarcloud-organization-setup.md` (new)
- `infrastructure/README.md` (index update + ADR-0011 reference)

## NuGet Dependencies
None. Docs only.

## Boundary Check
- [x] Architecture-repo work (docs and infrastructure walkthrough). Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" applies.
- [x] No code change in any other repo.
- [x] The walkthrough does not encode any secret value, organization key, or token. Token generation is described step-by-step; the value is created by the human in the SonarCloud UI and pasted into the GitHub UI.
- [x] No invariant violation: secrets stay out of the doc per invariant 8 ("Secret values never appear in logs, traces, exceptions, or telemetry") — this generalizes to documentation as well.

## Acceptance Criteria
- [ ] `infrastructure/sonarcloud-organization-setup.md` exists and follows the Goal / Prerequisites / Portal Breadcrumb / Step-by-step / Post-create hardening / Quality gate posture / Cost discipline / References structure of the existing walkthroughs (`key-vault-creation.md`, `oidc-federated-credentials.md`, etc.)
- [ ] Step 4 explicitly enumerates the public repo onboarding list and explicitly excludes private repos and `HoneyDrunk.Studios` (TypeScript)
- [ ] Step 6 specifies the secret name exactly as `SONAR_TOKEN` (all caps, exact)
- [ ] Step 6 specifies "Selected repositories" — never "All repositories" — for the GitHub org secret access
- [ ] No secret value, no token, no organization API key is committed to the doc
- [ ] Post-create hardening checklist includes the calendar-reminder rotation step
- [ ] Cost discipline section explicitly states: free for public repos, paid per-LOC for private repos, private opt-in is its own packet
- [ ] `infrastructure/README.md`: new entry indexes the walkthrough; ADR-0011 listed in References if not already present
- [ ] Repo-level `CHANGELOG.md`: append a docs entry to the in-progress version (or open one if this is the first packet in this wave to touch the Architecture repo's changelog — coordinate with packet 01's changelog stance: Architecture historically has no `CHANGELOG.md`, so this row may degrade to "skip per Architecture-repo precedent")
- [ ] No ADR IDs added to body narrative beyond the explicit "References" section (per user convention — index/reference sections are exempt; body narrative is not)
- [ ] The walkthrough was actually exercised by the human as part of authoring (Human Prerequisites below). If a step's wording differs from the real SonarCloud UI as of the authoring date, the doc reflects what the UI actually shows, not what the doc was originally drafted to say.

## Human Prerequisites
This packet has substantial human portal work. The agent authors the doc; the human follows the doc and corrects it. These steps must complete on the same wave:

- [ ] **Step 1–2:** Sign into `https://sonarcloud.io` with the HoneyDrunk Studios GitHub identity. Create the SonarCloud organization `honeydrunkstudios` on the Free plan, bound to the `HoneyDrunkStudios` GitHub org.
- [ ] **Step 3:** Verify the org page displays "Free plan — public repos" and no payment method is required.
- [ ] **Step 4:** Install the SonarCloud GitHub App on the `HoneyDrunkStudios` org, with **"Selected repositories"** scoped to the public-repo list enumerated in the walkthrough (today's list: Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Pulse, Notify, Actions, Architecture). Do not select Studios (TypeScript). Do not select "All repositories".
- [ ] **Step 5:** Generate a `SONAR_TOKEN` (User Token) in SonarCloud → My Account → Security. Long expiration (12+ months). Save the value to a secure password manager.
- [ ] **Step 6:** Add `SONAR_TOKEN` as an organization secret at `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`. Repository access: "Selected repositories" — same list as step 4.
- [ ] **Calendar reminder:** Set two reminders: one at the token expiration date, one 30 days before. Rotation steps will be the same as steps 5–6 with token recycling.
- [ ] **Doc validation:** As you click through the portal, note any wording or step-ordering drift from the agent-authored doc and update the doc inline before merging the PR.

**Cost note:** Free tier; zero recurring cost on the public side. Display the SonarCloud org page that shows "$0/month" before merging the PR as confirmation that the human did not accidentally onboard a private repo.

## Dependencies
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency on D11 being binding rather than aspirational.

## Downstream Unblocks
- `06-kernel-sonarcloud-onboarding.md` — Kernel onboarding requires the org and the secret to exist before its `pr.yml` can call `job-sonarcloud.yml` successfully.
- `07-web-rest-sonarcloud-onboarding.md` — same.
- All Wave-3 deferred per-repo onboardings.

This packet's portal work and the `02-actions-job-sonarcloud-workflow.md` workflow file together form the prerequisite pair: workflow file + org + secret. Per-repo onboardings need both.

## Referenced ADR Decisions

**ADR-0011 (Code Review and Merge Flow):**
- **D11 (SonarCloud chosen):** Free for public HoneyDrunk repos. The Grid is public by default, and the public-repo tier includes PR decoration, branch analysis, and the full C# rule set at zero cost.
- **D11 (Public-vs-private posture):** Public repos: SonarCloud enabled by default; quality gate is a required branch-protection check. Private repos: SonarCloud not enabled by default; opt-in per repo, recorded in a packet.
- **D11 (Contract for the SonarCloud stage):** `SONAR_TOKEN` as an org secret scoped to `HoneyDrunkStudios`. The walkthrough operationalizes this exact secret-name and scoping decision.
- **D11 Follow-up Work:** "SonarCloud organization setup — Portal walkthrough in `HoneyDrunk.Architecture/infrastructure/` per the 'prefer portal over CLI' convention." This packet is exactly that bullet.

**ADR-0005 (Configuration and Secrets Strategy)** is the precedent for "secrets are provisioned via portal walkthroughs documented in `infrastructure/`." Same pattern applies here, even though the secret store is GitHub org-level rather than Azure Key Vault.

## Referenced Invariants

> **Invariant 8 (secrets):** Secret values never appear in logs, traces, exceptions, or telemetry. *(Generalized: secret values do not appear in this walkthrough either. The `SONAR_TOKEN` value is generated by the human in the SonarCloud UI and pasted into the GitHub UI; neither value is committed to the repo.)*

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. *(The SonarCloud quality gate is tier 2; per-repo branch-protection wiring lives in the per-repo onboarding packets, not in this walkthrough.)*

## Constraints
- **Portal-only.** Do not author this as a CLI script. The "prefer portal over CLI" convention is explicit and applies here.
- **No secret values committed.** No `SONAR_TOKEN` value, no organization key, no project key in the doc body.
- **Public repos only.** Step 4's repo list and Step 6's secret access list both exclude private repos and Studios. Do not loosen to "All repositories" — that contradicts ADR-0011 D11 D11's private-repo posture.
- **Walkthrough is exercised by the human at authoring time.** This is the existing convention (per the ADR-0015 Container Apps walkthrough packet, which provisioned real `dev` resources during authoring). Drift between what the doc says and what the SonarCloud UI shows is corrected inline before merge.
- **No ADR IDs in narrative prose.** ADR-0011 is referenced only in the explicit "References" section, not in body narrative — per user convention.
- **Calendar reminder for token rotation is a Human Prerequisite, not a workflow.** No `nightly-cred-rotation.yml` is added; rotation is human-driven for this token.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `infrastructure`, `adr-0011`, `wave-1`

## Agent Handoff

**Objective:** Author a portal-first walkthrough at `infrastructure/sonarcloud-organization-setup.md` that the human follows once to create the SonarCloud organization, install the SonarCloud GitHub App on public repos only, and seed `SONAR_TOKEN` as a GitHub org secret with selected-repository scope. Index the new walkthrough in `infrastructure/README.md`. The human exercises the walkthrough during authoring.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Provide the one-time SonarCloud setup that all per-repo onboarding packets depend on.
- Feature: ADR-0011 Code Review Pipeline rollout.
- ADRs: ADR-0011 (D11 SonarCloud choice + Follow-up Work bullet), ADR-0005 (precedent for portal walkthroughs in `infrastructure/`).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Architecture#NN — ADR-0011 acceptance (packet 01). Soft dependency.

**Constraints:**
- Portal walkthrough format only. No CLI script.
- No secret values committed to the doc.
- Public repos only on the GitHub App install list (Step 4) and the GitHub org-secret access list (Step 6). "Selected repositories" — never "All repositories."
- Excluded from Step 4: HoneyDrunk.Studios (TypeScript; separate onboarding when needed) and any private repo.
- Free tier; zero recurring cost on the public side. Display "$0/month" confirmation before merging.
- Cross-link to existing walkthroughs for style and convention reference (`key-vault-creation.md`, `oidc-federated-credentials.md`, `app-configuration-provisioning.md`).
- ADR IDs only appear in the explicit References section.
- Walkthrough is exercised by the human at authoring time; drift is corrected inline.

**Key Files:**
- `infrastructure/sonarcloud-organization-setup.md` (new)
- `infrastructure/README.md` (index update + References section)
- Existing walkthroughs (`key-vault-creation.md`, `key-vault-rbac-assignments.md`, `oidc-federated-credentials.md`, `app-configuration-provisioning.md`, `log-analytics-workspace-and-alerts.md`) for style matching

**Contracts:**
- Org-secret name: `SONAR_TOKEN` — exact, all caps. This name is consumed by `job-sonarcloud.yml` (packet 02) and by every per-repo onboarding (packets 06, 07, future Wave 3). Renaming is a future-rename hazard.
- Org name in SonarCloud: `honeydrunkstudios` (lowercase, no dot) — bound to the `HoneyDrunkStudios` GitHub org. Project keys (per-repo) follow SonarCloud's auto-import format `honeydrunkstudios_{repo-name}`; the per-repo onboarding packets confirm and reference these keys.
