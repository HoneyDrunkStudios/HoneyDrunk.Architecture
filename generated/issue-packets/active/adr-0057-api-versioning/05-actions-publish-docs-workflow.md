---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-1", "core", "adr-0057", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0057", "ADR-0075"]
wave: 2
initiative: adr-0057-api-versioning
node: honeydrunk-actions
---

# Author job-publish-docs.yml — per-API docs site generation (Scalar + Docusaurus) and Cloudflare Pages deploy

## Summary
Author the reusable workflow `job-publish-docs.yml` in `HoneyDrunk.Actions/.github/workflows/` that, on a per-API tag matching `{api}-api-v{N}.{spec-revision}.{sdk-patch}`, builds the per-API docs site by composing Docusaurus (narrative content) with Scalar (OpenAPI reference rendered from the spec) per ADR-0057 D15 and ADR-0075 D1 + D2, and deploys it to Cloudflare Pages at `docs.{api}.honeydrunkstudios.com/v{N}/`. Each major version gets its own path prefix; the version switcher is built into the Docusaurus shell. The workflow handles both first-version provisioning and subsequent-major additions. Cloudflare Pages deployment relies on a Cloudflare API token (operator-time-budgeted; packet 11 onboarding).

## Context
ADR-0057 D15 (reconciled with ADR-0075 — 2026-05-24) commits the two-part docs composition: Scalar renders the OpenAPI reference (spec-driven; endpoints / schemas / try-it-out / error catalog), Docusaurus carries the narrative (getting-started, conceptual explainers, tutorials, migration guides). The two compose into a single per-API docs site at `docs.{api}.honeydrunkstudios.com`. Per-version routing: `/v{N}/` for narrative, `/v{N}/api/` for the OpenAPI reference. Root redirects to current default major. Archived majors live at `/archive/v{N}/`.

Per ADR-0075 D1, Scalar is already in use as the in-product OpenAPI renderer via `Scalar.AspNetCore`. This packet uses the same Scalar but in **static-publication mode** — the workflow runs `scalar build` (or equivalent) against the OpenAPI spec at release time and the resulting static HTML / JS / CSS is committed under the Docusaurus build output, served under `/v{N}/api/`. Docusaurus is per ADR-0075 D2 the narrative framework; the per-API repo's `docs/` directory contains the Docusaurus source.

The deployment target is **Cloudflare Pages** per packet 02's docs-subdomain provisioning playbook. Cloudflare Pages free-tier is sufficient at Studios traffic ceilings; the per-API project is named `honeydrunk-docs-{api}` and bound to the per-API repo. The workflow uses the Cloudflare API token (secret `CLOUDFLARE_API_TOKEN`; account ID secret `CLOUDFLARE_ACCOUNT_ID`) to push the built site. Packet 11 onboarding seeds these.

Per-API repos that don't yet have a `docs/` directory (Web.Rest at v1 freeze time per packet 07; Notify at v1 introduction per packet 08) need that directory scaffolded as part of those packets. This workflow assumes the docs directory exists; it does not scaffold it. Packets 07 and 08 ship the per-API Docusaurus scaffold; this workflow consumes it.

For per-API docs sites that ship multiple majors over time, the build output composes both majors into the same Pages project — the build pulls the spec from each currently-live major and renders both Scalar references, plus pulls the Docusaurus content from each major's branch / tag. The two-major coexistence (per ADR-0057 D6) means the build typically generates two reference sites + two narrative sites + one root redirect. The archive output at `/archive/v{N}/` is a one-time copy at sunset (a separate manual step per the deprecation runbook in packet 02; this workflow does not automate the archive copy because sunset is a deliberate operator action, not a tag-driven event).

This is the third Actions packet. Independent of packets 03 and 04 at execution time but composed by them in the per-API caller workflow (the tag-publication caller runs `job-openapi-diff` → `job-publish-public-sdk` → `job-publish-docs` in sequence).

## Scope
- **New file:** `HoneyDrunk.Actions/.github/workflows/job-publish-docs.yml` — the reusable workflow.
- **New file:** `HoneyDrunk.Actions/docs/job-publish-docs.md` — consumer documentation.
- Optionally: **a docs-site Docusaurus preset / package** in `HoneyDrunk.Actions/openapi-templates/docusaurus/` carrying the shared theme + version switcher + Scalar embed pattern — keep this small in v1; per-API repos consume the preset rather than re-implementing.
- Repo-level `CHANGELOG.md` entry.
- `HoneyDrunk.Actions/README.md` — workflow catalog link.

## Proposed Implementation

1. **`HoneyDrunk.Actions/.github/workflows/job-publish-docs.yml`** — `workflow_call` reusable workflow. Inputs:
   ```yaml
   inputs:
     spec-paths:
       description: 'Space-separated list of OpenAPI spec paths for currently-live majors (e.g. "api/openapi-v1.yaml api/openapi-v2.yaml").'
       type: string
       required: true
     docs-dir:
       description: 'Path to the per-API docs directory (Docusaurus source).'
       type: string
       required: false
       default: 'docs'
     surface-name:
       description: 'API surface name (e.g. notify, web-rest).'
       type: string
       required: true
     current-default-major:
       description: 'The major the docs root redirects to (e.g. 1 or 2).'
       type: number
       required: true
     cloudflare-pages-project:
       description: 'Cloudflare Pages project name (e.g. honeydrunk-docs-notify).'
       type: string
       required: true
     scalar-version:
       description: 'Scalar CLI version; pinned for determinism.'
       type: string
       required: false
       default: '0.4.0'  # confirm latest stable at execution time
     docusaurus-version:
       description: 'Docusaurus version; pinned for determinism.'
       type: string
       required: false
       default: '3.6.0'  # confirm latest stable at execution time
     dry-run:
       description: 'If true, build but do not deploy to Cloudflare Pages.'
       type: boolean
       required: false
       default: false
   secrets:
     CLOUDFLARE_API_TOKEN:
       required: false
     CLOUDFLARE_ACCOUNT_ID:
       required: false
   ```
   Steps:
   - **Checkout** with `fetch-depth: 0`.
   - **Install Node + Docusaurus + Scalar.** Pin versions per inputs.
   - **For each spec in `spec-paths`:**
     - Extract the major from the filename (`openapi-v(\d+)\.yaml`).
     - Run Scalar against the spec; output to `/tmp/build/v{major}/api/` (static HTML / JS / CSS).
     - Build the Docusaurus narrative for that major (Docusaurus supports versioned docs via its built-in versioning; the per-API repo's `docs/` carries a `versioned_docs/version-{major}/` subdirectory per Docusaurus convention). Output to `/tmp/build/v{major}/`.
   - **Compose the root redirect.** Write `/tmp/build/index.html` as a simple `<meta http-equiv="refresh" content="0; url=/v{current-default-major}/">` (or a JS-driven redirect if SEO matters; meta-refresh is sufficient at Studios scale).
   - **Compose the cross-major version switcher** — the Docusaurus shell's top nav includes the version dropdown that crosses majors at the same conceptual path (per ADR-0057 D15: `/v1/api/messages` ↔ `/v2/api/messages`). The shared preset in `openapi-templates/docusaurus/` (if shipped) provides this; otherwise the per-API repo's `docusaurus.config.js` implements it.
   - **Deploy.** If `dry-run: true` OR `CLOUDFLARE_API_TOKEN` is unset: log "DRY-RUN: skipping Cloudflare Pages deploy" and exit 0 (the built site is uploaded as a workflow artifact for inspection). Otherwise: use `cloudflare/pages-action@v1` (or the Wrangler CLI) to deploy `/tmp/build/` to the `${{ inputs.cloudflare-pages-project }}` project; the deployment URL is published in the workflow summary.
   - **Workflow summary** — list each major's docs URL, the root URL, the Cloudflare Pages deployment URL.

2. **`HoneyDrunk.Actions/openapi-templates/docusaurus/`** (optional but recommended in v1) — a small shared preset that per-API repos import:
   - `preset.js` — Docusaurus preset adding the version switcher, the Scalar embed shim, the docs-site theme (shared color palette, footer linking back to `honeydrunkstudios.com`).
   - `README.md` — how a per-API repo's `docusaurus.config.js` consumes the preset (`presets: [require.resolve('@honeydrunk/docusaurus-preset/preset.js')]` — or via direct npm install once the preset is published; defer publish if dry-run).
   - The preset itself does not get npm-published in this packet — per-API repos import via relative path (`require.resolve('../../HoneyDrunk.Actions/openapi-templates/docusaurus/preset.js')` or via a git submodule, or — most cleanly — the per-API repo's `docs/package.json` declares a `file:` dependency pointing at the cloned Actions directory at workflow run time). The simplest path at v1 is **the workflow copies the preset into the per-API build's `node_modules/@honeydrunk/docusaurus-preset/`** before running `docusaurus build`, sidestepping the npm-publish bootstrap problem.

3. **`HoneyDrunk.Actions/docs/job-publish-docs.md`** — consumer documentation:
   - **Purpose.** Build and deploy a per-API docs site per ADR-0057 D15.
   - **Tag-driven invocation example:**
     ```yaml
     on:
       push:
         tags:
           - 'notify-api-v*'
     jobs:
       docs:
         uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-publish-docs.yml@main
         with:
           spec-paths: 'HoneyDrunk.Notify/api/openapi-v1.yaml'
           docs-dir: 'HoneyDrunk.Notify/docs'
           surface-name: notify
           current-default-major: 1
           cloudflare-pages-project: honeydrunk-docs-notify
         secrets:
           CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
           CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
     ```
   - **Multi-major invocation** — when v2 ships, the caller passes both specs: `spec-paths: 'HoneyDrunk.Notify/api/openapi-v1.yaml HoneyDrunk.Notify/api/openapi-v2.yaml'`. The build emits both reference docs.
   - **Dry-run** — when `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` are unset, the workflow builds but uploads the result as an artifact rather than deploying.
   - **Per-API repo setup** — the per-API repo's `docs/` directory must exist and contain a Docusaurus scaffold (per Docusaurus 3.x conventions: `docusaurus.config.js`, `sidebars.js`, `docs/`, `versioned_docs/`, etc.). Packets 07 (Web.Rest) and 08 (Notify) scaffold those in their per-API repos.
   - **Version switcher** — the shared preset (or the per-API `docusaurus.config.js`) provides the cross-major version dropdown.
   - **Archive** — sunset is a deliberate operator action per the deprecation runbook in packet 02; the workflow does NOT auto-archive at sunset.

4. **`HoneyDrunk.Actions/CHANGELOG.md`** — dated, versioned entry.

5. **`HoneyDrunk.Actions/README.md`** — workflow catalog link.

## Affected Files
- `HoneyDrunk.Actions/.github/workflows/job-publish-docs.yml` (new)
- `HoneyDrunk.Actions/openapi-templates/docusaurus/preset.js` (new, optional in v1 — recommended)
- `HoneyDrunk.Actions/openapi-templates/docusaurus/README.md` (new, optional)
- `HoneyDrunk.Actions/docs/job-publish-docs.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Per ADR-0012.
- [x] No code change in any other repo.
- [x] Cloudflare Pages deployment is the canonical hosting target per packet 02's playbook and ADR-0029's DNS substrate.
- [x] Per-API `docs/` directory is NOT scaffolded by this workflow — packets 07 and 08 handle that.

## Acceptance Criteria
- [ ] `HoneyDrunk.Actions/.github/workflows/job-publish-docs.yml` exists with the documented inputs and outputs a Cloudflare Pages deployment URL
- [ ] The workflow builds per-major Scalar reference + per-major Docusaurus narrative; emits a root redirect to `current-default-major`; deploys to the named Cloudflare Pages project
- [ ] When `CLOUDFLARE_API_TOKEN` is unset OR `dry-run: true`, the workflow builds but uploads as artifact and does not deploy — logs the dry-run reason clearly
- [ ] When secrets are seeded and `dry-run: false`, the workflow deploys via `cloudflare/pages-action@v1` (or Wrangler CLI equivalent)
- [ ] Scalar and Docusaurus versions are pinned (no `latest`)
- [ ] Multi-major invocation (two specs in `spec-paths`) builds both reference sites + both narrative sites in the same deploy
- [ ] `HoneyDrunk.Actions/openapi-templates/docusaurus/preset.js` is shipped (or this packet documents why it was deferred) so per-API repos do not re-implement the version switcher / Scalar embed shim / shared theme
- [ ] `HoneyDrunk.Actions/docs/job-publish-docs.md` documents tag-driven invocation, multi-major, dry-run, per-API setup expectation, and the no-auto-archive note
- [ ] `HoneyDrunk.Actions/CHANGELOG.md` records the addition in a dated, versioned section
- [ ] `HoneyDrunk.Actions/README.md` links to the new job docs

## Human Prerequisites
- [ ] **Confirm Scalar and Docusaurus version pins** at PR time (`0.4.0` and `3.6.0` are placeholders).
- [ ] **The workflow runs in dry-run mode until packet 11's operator onboarding seeds `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.** Packet 11 covers the Cloudflare API token scoping (Account.Cloudflare Pages: Edit) and the org-secret seeding.
- [ ] **Per-API Cloudflare Pages project provisioning** — per the packet 02 docs-subdomain playbook, a Cloudflare Pages project named `honeydrunk-docs-{api}` must exist before the workflow can deploy to it. Packet 09 (Studios) ships the first concrete instance (`honeydrunk-docs-notify`) and the DNS / Pages project provisioning.

## Referenced ADR Decisions
**ADR-0057 D15 (reconciled with ADR-0075 — 2026-05-24) — Per-API docs site composition.** Scalar renders the OpenAPI reference (spec-driven part — endpoints, schemas, try-it-out, error catalog). Docusaurus carries the narrative content. Hosted at `docs.{api}.honeydrunkstudios.com`. Per-major path prefix: `/v{N}/` narrative, `/v{N}/api/` reference. Root redirects to current default major. Archived majors at `/archive/v{N}/`. Version switcher crosses majors at the same conceptual path.

**ADR-0075 D1 (referenced) — Scalar as in-product OpenAPI renderer.** Same renderer in static-publication mode here.

**ADR-0075 D2 (referenced) — Docusaurus as narrative framework.**

**ADR-0057 D5 + D6 — Deprecation and archive.** Sunset is a deliberate operator action per the deprecation runbook (packet 02). This workflow does NOT auto-archive at sunset.

**ADR-0029 (referenced) — Cloudflare DNS rollout.** Cloudflare Pages is the docs hosting target; the Cloudflare-managed zone owns the `docs.{api}.honeydrunkstudios.com` records.

**ADR-0012 (referenced) — Actions as CI/CD control plane.**

## Constraints
- **Pinned tool versions.**
- **Dry-run until packet 11 + packet 09.** Until both the Cloudflare credentials are seeded (packet 11) and the Pages project exists (packet 09 for Notify; per-API-specific for others), the workflow runs in build-only mode.
- **Per-API `docs/` directory must exist.** The workflow does not scaffold it; packets 07 and 08 do.
- **Shared Docusaurus preset is recommended but defer-able.** If the preset adds non-trivial complexity in v1, the executor can defer it to a follow-up packet — per-API repos then carry their own `docusaurus.config.js` with the version switcher + Scalar embed (duplicated; acceptable for v1; tracked as tech debt).
- **No auto-archive at sunset.** The sunset cutover is operator-driven per packet 02's runbook.
- **No `Unreleased` CHANGELOG.**

## Labels
`feature`, `tier-1`, `core`, `adr-0057`, `wave-2`

## Agent Handoff

**Objective:** Ship the reusable `job-publish-docs.yml` workflow that composes Scalar (OpenAPI reference) and Docusaurus (narrative) per ADR-0057 D15 + ADR-0075, builds per-major-version paths, and deploys to Cloudflare Pages. Run in dry-run mode until credentials + Pages project exist.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Single tag push on a per-API repo regenerates the entire per-API docs site (both currently-live majors) and deploys to Cloudflare Pages.
- Feature: ADR-0057 rollout, Wave 2 (Actions substrate).
- ADRs: ADR-0057 D15 (primary, reconciled with ADR-0075); ADR-0075 D1 + D2 (Scalar + Docusaurus); ADR-0029 (Cloudflare DNS); ADR-0012 (Actions as control plane).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0057 Accepted.
- `packet:01` — tech-stack.md commits Scalar + Docusaurus.

**Constraints:**
- Pinned versions for Scalar and Docusaurus.
- Dry-run until Cloudflare credentials + per-API Pages project exist.
- Per-API `docs/` directory not scaffolded here.
- Shared Docusaurus preset recommended but defer-able to a follow-up if it adds v1 complexity.
- No auto-archive.
- No `Unreleased` CHANGELOG.

**Key Files:**
- `HoneyDrunk.Actions/.github/workflows/job-publish-docs.yml` (new)
- `HoneyDrunk.Actions/openapi-templates/docusaurus/preset.js` + `README.md` (new, recommended)
- `HoneyDrunk.Actions/docs/job-publish-docs.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

**Contracts:** None — reusable workflow + shared preset.
