---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ops", "adr-0075", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0075", "ADR-0029", "ADR-0012"]
accepts: ["ADR-0075"]
wave: 3
initiative: adr-0075-docs-tooling
node: honeydrunk-actions
---

# Author the docs-deploy reusable workflow (Cloudflare Pages target)

## Summary
Author `job-deploy-docs-cloudflare-pages.yml` — the reusable GitHub Actions workflow that per-Node Docusaurus docs sites invoke to build and deploy to Cloudflare Pages, per ADR-0075 D6's "docs hosting platform" guidance and ADR-0029's Cloudflare-edge posture. Mirrors the existing reusable-workflow shape (`job-deploy-container-app.yml`, `job-deploy-function.yml`, `job-deploy-container.yml`). Inputs: artifact name with the built Docusaurus site, Cloudflare project name, environment (preview/production), branch name. Authentication: Cloudflare API token via OIDC-equivalent or repository secret per the Actions secret-handling convention.

## Context
ADR-0075 D6 lists docs hosting platform as "decision lives at the per-Node docs-deploy packet; Cloudflare Pages aligns with ADR-0029's edge posture and is the strong default." ADR-0075's Follow-up Work confirms: "The docs-deploy reusable workflow lands in HoneyDrunk.Actions (likely Cloudflare Pages per ADR-0029)."

ADR-0029 commits the Grid to Cloudflare for DNS and edge concerns; Cloudflare Pages is the edge-aligned static-site hosting target. Per ADR-0012, Actions is the Grid's CI/CD control plane — the docs-deploy workflow lives here, not duplicated in each per-Node repo.

**Repo-shape ground truth.**
- `HoneyDrunk.Actions/.github/workflows/` holds the reusable workflows the Grid composes against. The naming convention is `job-{purpose}.yml` for reusable building blocks (e.g., `job-deploy-container-app.yml`, `job-deploy-function.yml`, `job-deploy-container.yml`, `job-build-and-test.yml`, `job-static-analysis.yml`, `job-codeql.yml`). The docs-deploy workflow follows the same pattern: `job-deploy-docs-cloudflare-pages.yml`.
- The existing `job-deploy-*.yml` workflows demonstrate the input/output conventions: `runs-on`, `artifact-name`, `package-path`, environment selectors, OIDC authentication for Azure. The docs-deploy workflow mirrors the input shape, swapping Azure auth for Cloudflare auth.
- No existing Cloudflare Pages workflow exists in the Actions repo — this is a new reusable workflow, not an amendment.
- Consumer-usage docs live in `docs/consumer-usage.md` per the existing convention; this packet adds a consumer-usage section for the new workflow.

**The workflow's shape.**

```yaml
name: Deploy Docusaurus Docs to Cloudflare Pages

on:
  workflow_call:
    inputs:
      runs-on:
        description: 'GitHub runner to use'
        required: false
        type: string
        default: 'ubuntu-latest'
      artifact-name:
        description: 'Name of the uploaded artifact containing the built Docusaurus site'
        required: false
        type: string
        default: 'docs-site'
      build-output-dir:
        description: 'Path within the artifact to the built static files (typically `build/` for Docusaurus 3.x)'
        required: false
        type: string
        default: 'build'
      cloudflare-project-name:
        description: 'Cloudflare Pages project name (e.g., `notify-cloud-docs`)'
        required: true
        type: string
      cloudflare-pages-branch:
        description: 'Cloudflare Pages branch to deploy to (`main` for production, any other for preview deployment)'
        required: false
        type: string
        default: 'main'
      environment:
        description: 'Environment label (e.g., `production`, `staging`, `preview`) — used for GitHub Environment gating'
        required: false
        type: string
        default: 'production'
    secrets:
      CLOUDFLARE_API_TOKEN:
        description: 'Cloudflare API token with Pages:Edit permission on the project'
        required: true
      CLOUDFLARE_ACCOUNT_ID:
        description: 'Cloudflare account ID'
        required: true
    outputs:
      deployment-url:
        description: 'The deployed Cloudflare Pages URL'
        value: ${{ jobs.deploy.outputs.deployment-url }}

jobs:
  deploy:
    runs-on: ${{ inputs.runs-on }}
    environment: ${{ inputs.environment }}
    permissions:
      contents: read
      deployments: write
    outputs:
      deployment-url: ${{ steps.deploy.outputs.deployment-url }}
    steps:
      - name: Download built artifact
        uses: actions/download-artifact@v4
        with:
          name: ${{ inputs.artifact-name }}
          path: artifact

      - name: Deploy to Cloudflare Pages
        id: deploy
        uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy artifact/${{ inputs.build-output-dir }} --project-name ${{ inputs.cloudflare-project-name }} --branch ${{ inputs.cloudflare-pages-branch }}
```

Confirm the exact `cloudflare/wrangler-action` version pin at edit time. The action's API may evolve; pin to a stable major and use the standard `pages deploy` command surface.

**Authentication.** Cloudflare does not offer OIDC federated identity for Pages deployments today (verify at edit time — Cloudflare has been moving toward expanded OIDC support). The minimum-viable approach: a long-lived API token with scoped Pages:Edit permission, stored as a repo or org-level secret. Per the Actions secret-handling convention, the secret is **never logged**, never echoed, and is passed by `secrets:` workflow input. The token is rotated per the Vault rotation policy (invariant 20 — "No secret may exceed its tier's rotation SLA"). The CF Pages secret tier defaults to "low-risk" (it grants deploy on a single project) — 90-day rotation cadence matches the Grid's standard tier-3 secret.

**GitHub Environment gating.** The `environment: ${{ inputs.environment }}` line lets per-Node docs deploys gate on a GitHub Environment (with required reviewers, branch protection, wait-timers). The consumer chooses whether to require manual approval for production docs deploys.

**Consumer usage example.** A per-Node docs site's CI workflow consumes this as:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: pnpm install --frozen-lockfile
      - run: pnpm build
      - uses: actions/upload-artifact@v4
        with:
          name: docs-site
          path: build/

  deploy:
    needs: build
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-docs-cloudflare-pages.yml@main
    with:
      cloudflare-project-name: notify-cloud-docs
      cloudflare-pages-branch: main
      environment: production
    secrets:
      CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
      CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
```

This is a YAML/workflow packet. No .NET project, no NuGet.

## Scope
- A new reusable workflow file `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-docs-cloudflare-pages.yml` matching the existing `job-deploy-*.yml` conventions.
- A new section in `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Actions/docs/consumer-usage.md` (the established consumer-usage docs location) documenting the workflow's inputs, secrets, outputs, and a copy-pasteable consumer-usage example.
- The Actions repo's CHANGELOG (if the repo keeps one) — entry citing ADR-0075 D6 and ADR-0029.
- (Optional) A sample consumer workflow in the Actions repo's `examples/` directory — if the existing convention has per-workflow example consumers, add one for the docs-deploy workflow.

## Proposed Implementation
1. **Author** `.github/workflows/job-deploy-docs-cloudflare-pages.yml` matching the YAML shape in the Context section. Match the file-header comment style of the existing `job-deploy-*.yml` files (Purpose, Responsibilities, Target, Non-goals, Usage Example sections).
2. **Pin `cloudflare/wrangler-action`** to current stable major; document the version pin at the top of the file. Verify the action's `pages deploy` command surface at edit time.
3. **Document `secrets:`** — `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` are required workflow inputs. The descriptions must call out the Pages:Edit scope and the rotation cadence expectation (per the Grid's tier-3 secret rotation policy).
4. **Configure GitHub Environment gating.** The `environment: ${{ inputs.environment }}` line lets consumers gate on a GitHub Environment with required reviewers / wait-timers / branch protection. Document this in the workflow header.
5. **Outputs:** `deployment-url` — the deployed Cloudflare Pages URL, so consumer workflows can post it to PR comments or to deployment status.
6. **Update** `docs/consumer-usage.md` with a new section "Deploy Docusaurus Docs to Cloudflare Pages" containing:
   - Inputs table (matching the existing consumer-usage sections' format).
   - Secrets table.
   - Outputs table.
   - A copy-pasteable consumer workflow snippet (the example in the Context section).
   - A note on Cloudflare project provisioning — the Cloudflare Pages project must exist before the workflow runs; project creation is a human/portal step on first setup (recorded as a Human Prerequisite below).
7. **CHANGELOG entry** in the Actions repo's CHANGELOG.md (if it keeps one — match the existing convention) citing ADR-0075 D6 and ADR-0029.
8. **No edit to `actions-ci.yml` or `pr-core.yml`** — the docs-deploy workflow is consumed by per-Node docs-site repos, not by Actions itself. The Actions repo's own CI verifies the workflow's YAML syntax (which the existing `actions-ci.yml` should already do for new workflows).

## Affected Files
- `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-deploy-docs-cloudflare-pages.yml` (new)
- `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Actions/docs/consumer-usage.md` (new section)
- `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Actions/CHANGELOG.md` (entry if the repo keeps one)
- Optional: `c:/Users/tatte/source/repos/HoneyDrunkStudios/HoneyDrunk.Actions/examples/` (sample consumer workflow if the existing convention has one)

## NuGet Dependencies
None. This packet adds YAML and Markdown only; no .NET project, no NuGet, no npm.

## Boundary Check
- [x] `HoneyDrunk.Actions` is the right repo per ADR-0075 Follow-up Work ("docs-deploy reusable workflow lands in HoneyDrunk.Actions") and per ADR-0012 (Actions as the Grid's CI/CD control plane).
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] No secret committed to the repo — `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` are referenced as workflow secrets provided by the consuming workflow caller, never written into Actions's tracked files (invariant 8 — secret values never appear in logs, traces, exceptions, or telemetry; extended by convention to source-controlled YAML).

## Acceptance Criteria
- [ ] `.github/workflows/job-deploy-docs-cloudflare-pages.yml` exists matching the existing `job-deploy-*.yml` reusable-workflow conventions (file header, input shape, secret declarations, output declarations)
- [ ] The workflow accepts `cloudflare-project-name` (required), `cloudflare-pages-branch` (default `main`), `artifact-name` (default `docs-site`), `build-output-dir` (default `build`), `environment` (default `production`), and `runs-on` (default `ubuntu-latest`)
- [ ] The workflow declares `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as required `secrets:` inputs
- [ ] The workflow's output `deployment-url` captures the deployed Pages URL
- [ ] `cloudflare/wrangler-action` is pinned to current stable major
- [ ] The workflow honors GitHub Environment gating via `environment: ${{ inputs.environment }}`
- [ ] `docs/consumer-usage.md` documents the workflow with inputs/secrets/outputs tables and a consumer-usage snippet
- [ ] The Actions repo CHANGELOG entry cites ADR-0075 D6 and ADR-0029 (if the repo keeps a CHANGELOG)
- [ ] No secret values are written into source-controlled YAML — secrets come from `secrets:` workflow inputs only (invariant 8)
- [ ] The workflow's YAML passes the Actions repo's existing CI (lint/parse)

## Human Prerequisites
- [ ] **Provision the Cloudflare Pages project on first use.** Each consuming per-Node docs site needs a Cloudflare Pages project created in the Cloudflare dashboard before the workflow can deploy. The project name is the `cloudflare-project-name` input; the project's "Production branch" matches `cloudflare-pages-branch`. Portal walkthrough: Cloudflare dashboard → Pages → Create application → Direct Upload (the workflow uploads via wrangler) → set project name → confirm. **One-time per docs site, not per deploy.** (Cross-link: if an existing docs-deploy walkthrough document under `infrastructure/` walkthrough conventions exists, link to it; otherwise create one as a follow-on packet.)
- [ ] **Create and store `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`** as GitHub secrets in each consuming repo (or as org-level secrets if appropriate per the Grid's secret-distribution convention). The API token must have Pages:Edit scope on the Cloudflare account. Rotation cadence: 90 days per the Grid's tier-3 secret rotation policy (invariant 20).
- [ ] **Configure the GitHub Environment** in each consuming repo (e.g., `production` for the production docs deploy) with required reviewers if appropriate. This is a per-consumer choice; the reusable workflow honors whatever the consumer configures.

## Referenced ADR Decisions
**ADR-0075 D6 — Out of scope: docs hosting platform.** The decision lives at the per-Node docs-deploy packet; Cloudflare Pages aligns with ADR-0029's edge posture and is the strong default.

**ADR-0075 Follow-up Work — Docs-deploy reusable workflow lands in HoneyDrunk.Actions (likely Cloudflare Pages per ADR-0029).** This packet is that workflow.

**ADR-0029 — Cloudflare DNS and edge platform.** The Grid commits to Cloudflare for DNS and edge concerns; Cloudflare Pages is the edge-aligned static-site hosting target.

**ADR-0012 — Grid CI/CD control plane.** Actions is the Grid's CI/CD control plane. Reusable workflows live here, not duplicated in each per-Node repo.

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Extended by convention to source-controlled YAML — no Cloudflare API token or account ID is written into the workflow file; secrets come from `secrets:` workflow inputs only.

> **Invariant 20 — No secret may exceed its tier's rotation SLA without an active exception.** The Cloudflare API token is a tier-3 secret (deploy-on-single-project scope); 90-day rotation cadence. Document this expectation in `consumer-usage.md`.

- **Reusable workflow shape, not a per-repo workflow.** The workflow is invoked via `workflow_call`, never run directly. Match the existing `job-deploy-*.yml` files' shape.
- **Cloudflare Pages target only.** Other docs-hosting targets (Vercel, Netlify, Azure Static Web Apps) are not in scope per ADR-0075 D6 — Cloudflare Pages is the strong default. A future ADR could add a second target; this packet does not.
- **No secret committed.** API tokens and account IDs are workflow inputs, never written into source.
- **Wrangler action version pinned.** Pin to current stable major; record the pin in the workflow's file header.

## Labels
`feature`, `tier-2`, `ops`, `adr-0075`, `wave-3`

## Agent Handoff

**Objective:** Author `job-deploy-docs-cloudflare-pages.yml` — the reusable GitHub Actions workflow per-Node Docusaurus docs sites invoke to deploy to Cloudflare Pages.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: One reusable workflow for the Grid's docs deploys; per-Node docs-site repos consume it via `workflow_call`. Cloudflare Pages target per ADR-0075 D6 + ADR-0029.
- Feature: ADR-0075 Documentation Tooling rollout, Wave 3.
- ADRs: ADR-0075 D6 (primary), ADR-0029 (Cloudflare edge posture), ADR-0012 (Actions as CI/CD control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0075 should be Accepted before its docs-deploy workflow lands.

**Constraints:**
- Reusable workflow only (`workflow_call`); match the existing `job-deploy-*.yml` shape.
- No secrets committed — `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` are `secrets:` inputs from the caller.
- Pin `cloudflare/wrangler-action` to current stable major.
- Cloudflare Pages is the strong default per ADR-0075 D6; other hosting targets are out of scope for this packet.

**Key Files:**
- `HoneyDrunk.Actions/.github/workflows/job-deploy-docs-cloudflare-pages.yml` (new)
- `HoneyDrunk.Actions/docs/consumer-usage.md` (new section)
- `HoneyDrunk.Actions/CHANGELOG.md` (entry if the repo keeps one)

**Contracts:**
- Reusable workflow inputs: `runs-on`, `artifact-name`, `build-output-dir`, `cloudflare-project-name` (required), `cloudflare-pages-branch`, `environment`.
- Required secrets: `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.
- Output: `deployment-url`.
