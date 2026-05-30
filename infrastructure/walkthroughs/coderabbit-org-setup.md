# CodeRabbit Organization Setup (Portal)

**Applies to:** ADR-0079 (Multi-Perspective PR Review Stack), D1 — CodeRabbit is
Reviewer 2, the third-party-AI perspective.
**Related invariants:** 8 (secrets never in config/logs), 31 (tier-1 PR gate is
the required check; reviewers are advisory).
**Canonical config:** [`templates/.coderabbit.yaml`](../../templates/.coderabbit.yaml)
— this walkthrough applies that file; it does not duplicate its contents.

## Goal

Stand up CodeRabbit as the vendor-independent AI reviewer across the HoneyDrunk
Grid: subscribe, install the GitHub App org-wide so every current and future repo
is covered, then paste the canonical Grid config into **Global Overrides** so the
baseline is enforced everywhere from one place — no per-repo file, no fan-out, no
drift. One-time per org.

This is the human prerequisite named in the ADR-0079 packet set ("CodeRabbit
subscription provisioning"). Until it is done, the `templates/.coderabbit.yaml`
artifact is inert: nothing reads it.

## Why Global Overrides, not a per-repo file in every repo

CodeRabbit resolves configuration in priority order — **Global Overrides
(org-wide) → per-repo `.coderabbit.yaml` → dashboard UI** — and deep-merges when
inheritance applies. Global Overrides:

- apply to **every repo in the org automatically, including repos created later**;
- are **admin-only** — an enforced baseline, not a copyable default a repo can
  silently diverge from;
- use the **identical YAML schema** as `.coderabbit.yaml`, so the canonical
  template pastes in verbatim.

A 20-plus-repo fan-out of identical `.coderabbit.yaml` files is exactly the drift
the Grid avoids elsewhere. Per-repo files stay reserved for genuine refinements
(see the template README).

## Prerequisites

- GitHub org **owner** role on `HoneyDrunkStudios` (required to install a GitHub
  App org-wide and to grant CodeRabbit access to all repos).
- A payment method for the CodeRabbit subscription (~$24/developer/month per
  ADR-0079 D6; one seat for the solo operator).
- The current contents of [`templates/.coderabbit.yaml`](../../templates/.coderabbit.yaml).

## Portal Breadcrumb

**coderabbit.ai → Login with GitHub → Authorize CodeRabbit → Add Organization →
HoneyDrunkStudios → Install GitHub App → All repositories → Subscribe → Org
Settings → Global Overrides → paste config → Save**

## Step-by-step

### 1. Sign up / sign in

1. Open https://coderabbit.ai and choose **Login with GitHub**.
2. Sign in with the GitHub identity that **owns** the `HoneyDrunkStudios` org.
3. Authorize the CodeRabbit OAuth app when prompted.

### 2. Add the organization and install the GitHub App org-wide

1. In the CodeRabbit dashboard, add / select the **HoneyDrunkStudios**
   organization.
2. When routed to GitHub to install the **CodeRabbit GitHub App**, choose
   **All repositories** (not "Only select repositories").
   - "All repositories" is what makes future Nodes covered automatically — a new
     repo inherits the app install and the Global Override with zero per-repo
     action. This is the behavior `constitution/node-standup.md` step 10 relies on.
3. Confirm the install. Back in CodeRabbit, the org's repos should now be listed.

### 3. Subscribe

1. In **Org Settings → Subscription** (or the billing prompt), start the paid
   plan with **one seat**.
2. ADR-0079 D6 bounds this at ~$24/mo. Do not add seats; the Grid is a single
   operator.

### 4. Apply the canonical config as a Global Override

1. Go to **Organization Settings**. Switch to **Global Overrides** mode (the mode
   switcher in the sidebar).
2. Paste the **entire contents** of
   [`templates/.coderabbit.yaml`](../../templates/.coderabbit.yaml) into the
   Global Overrides YAML editor. The schema is identical — it pastes verbatim.
3. **Save.** Overrides take effect on the next PR review across every repo.

> **Keep the dashboard in sync with the file.** `templates/.coderabbit.yaml` in
> `HoneyDrunk.Architecture` is the source of truth. When it changes via PR, the
> operator re-pastes the new contents into Global Overrides. The dashboard is the
> *application surface*; the file is the *authority* — same discipline as
> branch-protection and org-secret settings, which also live as documented intent
> in Architecture and are applied by hand in a portal.

### 5. Verify

1. Open (or push a commit to) any non-draft PR on an in-scope repo.
2. Within a few minutes CodeRabbit should post a review summary comment.
3. Confirm it respects the baseline: no review on **draft** PRs, machine-generated
   paths (`**/generated/**`, `**/obj/**`, etc.) are not commented on, and it does
   **not** post a blocking "Request changes" review (advisory only).
4. If nothing posts: check the GitHub App is installed on that repo (Step 2) and
   that the PR is not a draft.

## What this does NOT configure

- **Invariant 8.** Nothing here puts a secret in a repo file. CodeRabbit
  authenticates via the installed GitHub App; the config file and the Global
  Override carry no credentials.
- **The Grid-aware reviewers (3/4).** Those are the local worker running the
  `review` agent per ADR-0086 — a separate substrate. CodeRabbit does not enforce
  invariants or ADRs; do not expect it to.
- **Per-repo refinements.** Optional and incremental; see
  [`templates/README.md`](../../templates/README.md).

## Teardown / rollback

- To disable CodeRabbit Grid-wide: remove the Global Override (or set the GitHub
  App to no repositories). Reviewers 1 (Copilot) and 3/4 (Grid-aware agent)
  continue unaffected — CodeRabbit is one independent perspective, not a gate.
- To cancel billing: **Org Settings → Subscription → Cancel**. ADR-0079's stack
  degrades to three reviewers; no merge gate is affected (reviewers are advisory).
