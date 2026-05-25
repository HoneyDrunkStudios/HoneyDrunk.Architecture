# SonarQube Cloud Organization Setup (Portal)

**Applies to:** ADR-0011 (Code Review and Merge Flow), D11.
**Related invariants:** 8 (secrets never in logs), 31 (tier-1/tier-2 PR gates).
**Naming note:** SonarSource rebranded "SonarCloud" to **"SonarQube Cloud"** in early 2026. ADR-0011 was drafted under the old name and uses "SonarCloud" throughout; the product is the same.

## Goal

Stand up SonarQube Cloud as the third-party static-analysis tool for public HoneyDrunk repos. Create the `honeydrunkstudios` SonarQube Cloud organization, install the SonarQube Cloud GitHub App on the in-scope public repos, generate a long-lived-as-possible Personal Access Token, and provision it as a GitHub org secret named `SONAR_TOKEN`. One-time per org; per-repo project import is a separate per-repo onboarding (packets 06, 07, future Wave-3 fan-out).

## Prerequisites

- Repo admin / GitHub org owner role on `HoneyDrunkStudios`.
- A SonarQube Cloud account signed in with GitHub (use the account that owns the `HoneyDrunkStudios` GitHub org).
- The list of public Grid repos to onboard. As of 2026-05-25, this is **20 repos** (see Step 4).

## Portal Breadcrumb

**sonarcloud.io → avatar → My Account → Organizations → Create organization → Import from GitHub → HoneyDrunkStudios → Free → Create organization → (auto-routes to OSS plan)**

## Step-by-step

### 1. Sign in to SonarQube Cloud

1. Open https://sonarcloud.io and sign in with the GitHub identity that owns `HoneyDrunkStudios`.
2. Confirm the avatar in the top-right corresponds to that identity.

### 2. Open the Organizations page

1. Click the avatar (top-right) → **My Account**.
2. Left sidebar → **Organizations**.
3. The page should read **"You are not a member of any organizations yet."** with a **Create organization** button (top-right of the page body). If the page already lists `honeydrunkstudios`, skip to Step 5.

### 3. Create the organization

1. Click **Create organization**.
2. On the next screen, click **Import from GitHub**.
3. If prompted by GitHub: choose **Only select repositories** (NOT "All repositories") and pick the 20 in-scope repos enumerated in Step 4 below. Install the SonarQube Cloud GitHub App on the `HoneyDrunkStudios` org (not a personal account).
4. Back in SonarQube Cloud, fill in **Import organization details**:
   - **Name:** `HoneyDrunkStudios` (pre-filled from GitHub; max 255 chars).
   - **Key:** `honeydrunkstudios` (pre-filled; lowercase, letters/numbers/hyphens; load-bearing — `sonar-project.properties` files reference this string).
   - **"Automatically import new GitHub repositories":** **uncheck**. New repos onboard through explicit packets, not silent auto-import. Defence in depth in case GitHub App scope is ever widened to "All repositories" later.
5. Scroll to **Organization plan**.

### 4. Choose plan + repo scope

**Pick Free.** Click **Select free** under the Free card. Then scroll to the bottom and click **Create organization**.

SonarQube Cloud may **auto-route a public-only HoneyDrunkStudios-shaped org to the OSS plan** (badge: `OSS plan` + `Public`). This is *more generous* than Free — no member cap, no LOC cap, full features for public projects. Accept it. No payment method is required.

**In-scope public repos for the GitHub App install (Step 3.3) and the GitHub org secret (Step 6.5):**

Core (8):
- HoneyDrunk.Kernel
- HoneyDrunk.Transport
- HoneyDrunk.Vault
- HoneyDrunk.Vault.Rotation
- HoneyDrunk.Auth
- HoneyDrunk.Web.Rest
- HoneyDrunk.Data
- HoneyDrunk.Audit

Ops (4):
- HoneyDrunk.Notify
- HoneyDrunk.Communications
- HoneyDrunk.Pulse
- HoneyDrunk.Actions

AI / seed Nodes (8):
- HoneyDrunk.AI
- HoneyDrunk.Capabilities
- HoneyDrunk.Agents
- HoneyDrunk.Memory
- HoneyDrunk.Knowledge
- HoneyDrunk.Flow
- HoneyDrunk.Operator
- HoneyDrunk.Observe

**Explicitly excluded:**
- HoneyDrunk.Studios — TypeScript/Next.js; SonarQube Cloud supports JS but onboarding template differs from the .NET path. Separate future packet.
- HoneyDrunk.Architecture, HoneyDrunk.Lore, HoneyDrunk.Standards — docs/governance/wiki/analyzers; no application code to analyze.
- HoneyDrunk.Evals, HoneyDrunk.Sim — Seed Nodes in `catalogs/nodes.json` but the GitHub repos do not yet exist; onboard when the repos are stood up.

### 5. Verify the organization

1. After **Create organization**, you land on the org dashboard at `https://sonarcloud.io/organizations/honeydrunkstudios/projects`.
2. Confirm the badge shows **OSS plan + Public** and the website link reads `https://honeydrunkstudios.com/` (auto-pulled from GitHub org metadata).
3. "No projects here yet" is the expected state — projects auto-provision on first scanner push from CI (per-repo onboarding packets 06, 07, future Wave-3 fan-out).

### 6. Generate `SONAR_TOKEN`

SonarQube Cloud offers two token types in its UI:

- **Personal Access Token (PAT)** — bound to a user account; created from **My Account → Security**.
- **Scoped Organization Token (SOT)** — bound to the organization, not a user; recommended for CI; **Team plan only** ($32/mo+).

On Free/OSS plan, the org admin's PAT is the only option. Acceptable trade-off for a solo-dev studio with one admin account. **Do not upgrade to Team for the SOT alone — that is not a cost-disciplined spend** (per ADR-0011 D6 Cost Discipline).

Steps:

1. Click avatar (top-right) → **My Account** → left sidebar → **Security**.
2. Under **Generate Tokens**, enter the token name: `honeydrunkstudios-grid-ci` (descriptive; identifies the consumer as the Grid's CI). For rotated successors, append a date suffix: `honeydrunkstudios-grid-ci-2026-07`.
3. **There is no expiration option in the UI on Free/OSS plan.** Tokens are issued with a fixed **60-day expiration**. This is a hard cap with no UI override; see the "Token rotation" section in **Post-create hardening** below.
4. Click **Generate Token**.
5. **Copy the token value immediately.** SonarQube Cloud displays the token value once at the top of the page, then never again. Modern SonarQube Cloud tokens are opaque alphanumeric strings (no `sqp_`/`squ_` prefix family). Paste into a scratch text editor or password manager — wipe after Step 7.
6. Confirm the token appears in the **Existing Tokens** table with the **Scheduled expiry** date 60 days out. Capture this date — it goes into the calendar reminder in Step 7's hardening.

### 7. Provision the GitHub org secret

1. Open `https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions`.
2. Click **New organization secret** (top-right).
3. **Name:** `SONAR_TOKEN` — exact, all caps. Load-bearing: the reusable workflow in `HoneyDrunk.Actions/.github/workflows/job-sonarcloud.yml` (packet 02) and every per-repo `pr.yml` (packets 06, 07, future Wave-3) read this exact name.
4. **Value:** paste the token from Step 6.5.
5. **Repository access:** **Selected repositories**. Click **Select repositories** and check the same 20 repos enumerated in Step 4. Do NOT pick "All repositories" — that grants the secret to any future private repo, violating ADR-0011 D11's "private-repo SonarCloud is opt-in only" posture.
6. Click **Add secret**. The secret should appear in the Actions secrets list with `20 repositories` next to it.

### 8. Token hygiene cleanup

1. Wipe the scratch buffer where you copied the token in Step 6.5.
2. Clear clipboard manager history if you have one.
3. Close the SonarQube Cloud Security tab.

The token now lives in exactly two places: SonarQube Cloud's vault (you can't see it) and the GitHub org secret (you can't see it either). That is the desired posture.

## Post-create hardening

### Token rotation (every ~60 days)

SonarQube Cloud Free/OSS plan caps PAT expiration at 60 days with no UI to extend. Token rotation is a recurring chore until automated.

**Two calendar reminders required for every token generation:**

1. **30-day warning** — date = expiry − 10 days.
2. **Expiry day** — date = expiry exactly.

Reminder body template:

```
SonarQube Cloud PAT `<token-name>` expires on <expiry date>.

Rotation procedure (~5 minutes):
1. https://sonarcloud.io → avatar → My Account → Security
2. Click "Generate Token" with name `honeydrunkstudios-grid-ci-<YYYY-MM>`
3. Copy the new token value immediately (shown once)
4. https://github.com/organizations/HoneyDrunkStudios/settings/secrets/actions
5. Update `SONAR_TOKEN` org secret with the new value (Selected repositories
   scope must remain the same 20-repo list — verify before saving)
6. Revoke the old token in SonarQube Cloud (Existing Tokens → row → Delete)
7. Set the next pair of reminders ~60 days out from the new token's expiry

If missed: all SonarQube Cloud CI analyses fail with 401 starting the day after expiry.
```

**Future automation candidate:** the external-SaaS credential rotation ADR (drafted separately, see `generated/adr-drafts/`) may decide to automate this via a nightly workflow that detects within-30-days expirations and either auto-rotates or files a GitHub issue.

### Organization settings to verify

1. SonarQube Cloud → org → left sidebar → **Administration** (expand). Confirm:
   - **"Default New Code definition"** is **"Number of days = 30"** (default). This controls the New-Code analysis window for the quality gate.
   - **Two-factor authentication** is enforced for org members under Security settings.
2. If a future private Grid repo wants SonarQube Cloud coverage, that is a separate per-repo opt-in packet — do not add private repos to the SonarQube Cloud org via "All repositories" widening.

### Quality gate posture

Default quality gate is **"Sonar way"** (the SonarQube Cloud built-in). Acceptable as a starting point. Each per-repo onboarding packet (Wave 2 + Wave 3 of the ADR-0011 rollout) is responsible for adding the SonarQube Cloud check to its repo's branch protection so the gate becomes enforcing per invariant 31's tier-2 reading. Quality-gate failures surface as PR check failures on the same UI as `pr-core.yml` checks.

## Cost discipline

This provisioning is **zero recurring cost** on the OSS plan: unlimited public LOC, unlimited members, full feature set for public projects. The Team upgrade prompt ($32+/mo) exists to unlock private-LOC analysis, Jira, custom quality standards, AI CodeFix, and Scoped Organization Tokens. None of those are needed for the current Grid posture — do not upgrade without an ADR amendment that justifies the cost.

Any future private-repo SonarQube Cloud onboarding **requires a packet that justifies the cost in its own right** (per ADR-0011 D11 Gap 5).

## Verification

- SonarQube Cloud org `honeydrunkstudios` exists with badge **OSS plan + Public**.
- The SonarQube Cloud GitHub App is installed on `HoneyDrunkStudios` with **Only select repositories** scoped to the 20 in-scope repos.
- `SONAR_TOKEN` exists as a GitHub org secret with **Selected repositories** scoped to the same 20 repos.
- Two Outlook calendar reminders are set for the token's expiry day and 10 days before.
- "Automatically import new GitHub repositories" is **unchecked** on the org.
- No token value, organization key beyond `honeydrunkstudios`, or project key has been committed to any repo.

## Cross references

- [ADR-0011: Code Review and Merge Flow](../../adrs/ADR-0011-code-review-and-merge-flow.md) — D11 (SonarQube Cloud chosen as third-party static analysis), D6 (Cost Discipline).
- [ADR-0005: Configuration and Secrets Strategy](../../adrs/ADR-0005-configuration-and-secrets-strategy.md) — precedent for portal-first secret provisioning walkthroughs.
- [ADR-0006: Secret Rotation and Lifecycle](../../adrs/ADR-0006-secret-rotation-and-lifecycle.md) — Azure Key Vault rotation; `SONAR_TOKEN` lives outside this scope (GitHub org secret), pending the external-SaaS credential rotation ADR.
- [Grid Invariants](../../constitution/invariants.md) — 8 (secrets never in logs/docs), 31 (tier-1 gate; SonarQube Cloud quality gate is tier 2).
- SonarQube Cloud docs: https://docs.sonarsource.com/sonarcloud/
- GitHub org secrets docs: https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-an-organization
