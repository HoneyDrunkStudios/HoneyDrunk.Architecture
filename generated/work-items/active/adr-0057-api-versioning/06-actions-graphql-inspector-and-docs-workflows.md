---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-1", "core", "adr-0057", "wave-2"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0057", "ADR-0003"]
wave: 2
initiative: adr-0057-api-versioning
node: honeydrunk-actions
---

# Author job-graphql-inspector.yml and job-publish-graphql-docs.yml — HoneyHub Phase 4 substrate

## Summary
Author two reusable workflows in `HoneyDrunk.Actions/.github/workflows/` that ship the GraphQL substrate per ADR-0057 D16 + D17 Phase 4: `job-graphql-inspector.yml` runs `graphql-inspector` (or equivalent) on every PR that modifies a `schema.graphql`, flagging outright field/type removals (which require a 180-day `@deprecated` window per ADR-0057 D5 + D16); `job-publish-graphql-docs.yml` builds the HoneyHub GraphQL docs site (narrative via Docusaurus + GraphQL reference via Spectaql or equivalent GraphQL renderer) and deploys to Cloudflare Pages at `docs.honeyhub.honeydrunkstudios.com`. Both workflows ship now as substrate even though HoneyHub does not exist on disk yet — the workflows are buildable Actions assets, and per ADR-0057 D17 Phase 5 they must be in place before the HoneyHub standup begins.

## Context
ADR-0057 D16 commits HoneyHub's GraphQL schema-evolution model: additive-only on the live schema; breaking changes via per-field `@deprecated(reason: "Use newField instead. Sunset YYYY-MM-DD.")`; minimum 180-day deprecation window per field; tenant-notification flow (same as REST per D5) applies. ADR-0057 D17 Phase 4 commits the substrate: `job-graphql-inspector.yml` and `job-publish-graphql-docs.yml`. Invariant `{N4}` is the enforcement.

The two workflows mirror the REST counterparts in shape:
- `job-graphql-inspector.yml` is the GraphQL counterpart of `job-openapi-diff.yml` (packet 03) — it enforces the no-removal-without-deprecation rule.
- `job-publish-graphql-docs.yml` is the GraphQL counterpart of `job-publish-docs.yml` (packet 05) — it composes a narrative Docusaurus site with a GraphQL reference renderer (likely Spectaql, the GraphQL-Markdown plugin for Docusaurus, or GraphiQL-as-static).

HoneyHub does **not exist on disk**. ADR-0003 (HoneyHub) is Proposed; the `HoneyHub/` repo is not yet stood up; the `schema.graphql` is not yet committed. This packet ships the **substrate workflows in `HoneyDrunk.Actions`** — the per-API tag-driven wiring lands when HoneyHub stands up. The workflows are correct GitHub Actions assets at PR time; they pass their own self-tests; they are not invoked from any caller yet.

`graphql-inspector` (https://the-guild.dev/graphql/inspector) is the most mature open-source GraphQL schema diff/inspector tool. It runs on Node, ships as `@graphql-inspector/cli`, classifies changes into `BREAKING` / `NON_BREAKING` / `DANGEROUS` categories, and supports a CI gate mode. It is the default tool choice per ADR-0057 D16's "or equivalent" — pin the version in this workflow.

For the GraphQL docs renderer, the ecosystem is fragmented. Options:
- **Spectaql** — Spectaql renders GraphQL schemas as static HTML; Docusaurus-friendly via iframe embed or plugin. Less polished than Scalar for REST but mature.
- **`@graphql-markdown/docusaurus`** — a Docusaurus plugin that generates Markdown from a GraphQL schema. Most idiomatic for the Docusaurus-narrative model already committed for REST per ADR-0075.
- **GraphiQL embedded** — interactive query browser; less of a "reference site" feel; useful for try-it-out but doesn't replace static reference content.

The packet picks `@graphql-markdown/docusaurus` as the v1 default because it preserves the Docusaurus-as-narrative-shell convention (parity with the REST docs site) and renders reference content in the same Docusaurus pages — no iframe embedding. The choice is documented in the workflow inputs so a future swap is a single input change.

Both workflows ship in dry-run-compatible mode (the GraphQL docs workflow uses the same Cloudflare Pages token; the inspector workflow needs no secret). Until HoneyHub stands up, neither is invoked by any caller.

This is the fourth and final Actions packet.

## Scope
- **New file:** `HoneyDrunk.Actions/.github/workflows/job-graphql-inspector.yml`
- **New file:** `HoneyDrunk.Actions/.github/workflows/job-publish-graphql-docs.yml`
- **New file:** `HoneyDrunk.Actions/docs/job-graphql-inspector.md`
- **New file:** `HoneyDrunk.Actions/docs/job-publish-graphql-docs.md`
- Repo-level `CHANGELOG.md` entry.
- `HoneyDrunk.Actions/README.md` — workflow catalog links.

## Proposed Implementation

1. **`HoneyDrunk.Actions/.github/workflows/job-graphql-inspector.yml`** — `workflow_call` reusable workflow. Inputs:
   ```yaml
   inputs:
     schema-path:
       description: 'Path to the GraphQL schema (e.g. api/schema.graphql).'
       type: string
       required: true
     diff-mode:
       description: 'tag (compare against latest released tag) or branch (compare against main).'
       type: string
       required: false
       default: 'branch'  # HoneyHub uses schema-evolution without major-version tags per D16, so branch-anchored is the default
     graphql-inspector-version:
       description: 'graphql-inspector version; pinned for determinism.'
       type: string
       required: false
       default: '5.0.0'  # confirm latest stable at execution time
   ```
   Steps:
   - **Checkout** with `fetch-depth: 0`.
   - **Install Node + `@graphql-inspector/cli@${{ inputs.graphql-inspector-version }}`.**
   - **Resolve the comparison base.** Branch mode: check out `main`'s `schema-path` to `/tmp/base-schema.graphql`. Tag mode (if a HoneyHub-internal convention emerges): check out the latest tag's schema.
   - **Run inspector.** `graphql-inspector diff /tmp/base-schema.graphql ${{ inputs.schema-path }} --rule recommended` — `recommended` rule set classifies removals, type changes, required-arg additions as BREAKING; field deprecations as DANGEROUS-but-allowed.
   - **Gate.** If `graphql-inspector` returns BREAKING changes (i.e., any field/type was removed without first having been `@deprecated` for the minimum window OR a required arg was added), the workflow exits non-zero and publishes a sticky PR comment listing the offending changes plus the remediation: "Apply `@deprecated(reason: '...; sunset YYYY-MM-DD.')` to the field; wait the 180-day window; then remove."
   - **Slow-drift footnote.** `graphql-inspector` catches outright removals but does NOT catch *slow drift* in deprecation hygiene (e.g., a `@deprecated` field whose `reason` is missing the sunset date, or whose sunset date is unrealistically distant). The PR comment footer notes: "Note: `graphql-inspector` enforces removal-after-deprecation but does NOT check the deprecation `reason` string for the required sunset date format. Reviewer attention via the Grid-aware review agent (ADR-0044) checks the `reason` string."
   - **Sticky PR comment** — same pattern as `job-openapi-diff.yml`.

2. **`HoneyDrunk.Actions/.github/workflows/job-publish-graphql-docs.yml`** — `workflow_call` reusable workflow. Inputs:
   ```yaml
   inputs:
     schema-path:
       description: 'Path to the GraphQL schema.'
       type: string
       required: true
     docs-dir:
       description: 'Path to the Docusaurus source.'
       type: string
       required: false
       default: 'docs'
     surface-name:
       description: 'GraphQL surface name (e.g. honeyhub).'
       type: string
       required: true
     cloudflare-pages-project:
       description: 'Cloudflare Pages project name (e.g. honeydrunk-docs-honeyhub).'
       type: string
       required: true
     graphql-markdown-version:
       description: '@graphql-markdown/docusaurus version; pinned.'
       type: string
       required: false
       default: '1.20.0'  # confirm latest stable
     docusaurus-version:
       description: 'Docusaurus version; pinned.'
       type: string
       required: false
       default: '3.6.0'  # match packet 05
     dry-run:
       description: 'If true, build but do not deploy.'
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
   - **Checkout.**
   - **Install Node + Docusaurus + `@graphql-markdown/docusaurus`.**
   - **Generate GraphQL reference Markdown from the schema.** The plugin scans the schema and writes Markdown files into the Docusaurus tree at a configured path (e.g., `docs/reference/`). Pre-build step within the Docusaurus build.
   - **Build Docusaurus.** Outputs static HTML / JS / CSS.
   - **Deploy.** Same Cloudflare Pages path as packet 05. Dry-run if secrets absent.
   - **Workflow summary** — list the deployment URL.

   **No per-major path prefix.** Per ADR-0057 D16, HoneyHub does NOT version by URL prefix — schema evolution under a single `/graphql` endpoint. The docs site is therefore single-version; `docs.honeyhub.honeydrunkstudios.com/` serves the live schema's reference + narrative. No `/v1/` prefix.

3. **`HoneyDrunk.Actions/docs/job-graphql-inspector.md`** — consumer documentation:
   - **Purpose.** Enforce invariant `{N4}` (HoneyHub uses schema evolution; no URL-prefix versioning; removals require a 180-day `@deprecated` window).
   - **Invocation example** (a future HoneyHub PR check):
     ```yaml
     on:
       pull_request:
         paths:
           - 'HoneyHub/api/schema.graphql'
     jobs:
       graphql-inspector:
         uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-graphql-inspector.yml@main
         with:
           schema-path: HoneyHub/api/schema.graphql
     ```
   - **What is enforced** — outright field/type removal; type changes; required-arg additions.
   - **What is NOT enforced** — the `@deprecated(reason: "...")` string's sunset-date format (Grid-aware review agent per ADR-0044 catches this).

4. **`HoneyDrunk.Actions/docs/job-publish-graphql-docs.md`** — consumer documentation:
   - **Purpose.** Build and deploy HoneyHub's GraphQL docs site per ADR-0057 D15 (cross-applied to GraphQL).
   - **Invocation example** — when HoneyHub stands up:
     ```yaml
     on:
       push:
         branches: [main]
         paths:
           - 'HoneyHub/api/schema.graphql'
           - 'HoneyHub/docs/**'
     jobs:
       docs:
         uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-publish-graphql-docs.yml@main
         with:
           schema-path: HoneyHub/api/schema.graphql
           docs-dir: HoneyHub/docs
           surface-name: honeyhub
           cloudflare-pages-project: honeydrunk-docs-honeyhub
         secrets:
           CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
           CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
     ```
   - **No per-major path.** Single-version docs site.
   - **Dry-run** — until Cloudflare credentials and the `honeydrunk-docs-honeyhub` Pages project exist.
   - **Cross-link to packet 02 docs-subdomain provisioning playbook** — HoneyHub's docs subdomain follows the same playbook as the REST docs subdomains.

5. **`HoneyDrunk.Actions/CHANGELOG.md`** — dated, versioned entry.

6. **`HoneyDrunk.Actions/README.md`** — workflow catalog links for both.

## Affected Files
- `HoneyDrunk.Actions/.github/workflows/job-graphql-inspector.yml` (new)
- `HoneyDrunk.Actions/.github/workflows/job-publish-graphql-docs.yml` (new)
- `HoneyDrunk.Actions/docs/job-graphql-inspector.md` (new)
- `HoneyDrunk.Actions/docs/job-publish-graphql-docs.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Per ADR-0012.
- [x] No code change in any other repo.
- [x] HoneyHub does not exist on disk; the workflows are buildable substrate assets, not invoked by any caller yet.
- [x] The GraphQL docs renderer choice (`@graphql-markdown/docusaurus`) is documented and swappable via a future ADR.

## Acceptance Criteria
- [ ] `HoneyDrunk.Actions/.github/workflows/job-graphql-inspector.yml` exists; runs `graphql-inspector diff` with the `recommended` rule set; fails on BREAKING; publishes a sticky PR comment with the offending changes and the remediation; the comment includes the slow-drift footnote about `@deprecated` reason-string review
- [ ] `HoneyDrunk.Actions/.github/workflows/job-publish-graphql-docs.yml` exists; generates GraphQL reference Markdown via `@graphql-markdown/docusaurus`; builds Docusaurus; deploys to Cloudflare Pages with `dry-run` fallback when secrets absent; no per-major path prefix (single-version site)
- [ ] Pinned versions for `graphql-inspector`, `@graphql-markdown/docusaurus`, and Docusaurus (all three)
- [ ] `HoneyDrunk.Actions/docs/job-graphql-inspector.md` documents purpose, invocation example, what-is-enforced, what-is-NOT-enforced
- [ ] `HoneyDrunk.Actions/docs/job-publish-graphql-docs.md` documents purpose, invocation example, single-version-site note, dry-run, cross-link to packet 02
- [ ] `HoneyDrunk.Actions/CHANGELOG.md` records the addition in a dated, versioned section
- [ ] `HoneyDrunk.Actions/README.md` links to both new job docs
- [ ] Neither workflow is wired in a consuming repo (HoneyHub does not exist) — the wiring lands as part of the future HoneyHub standup

## Human Prerequisites
- [ ] **Confirm tool version pins** at PR time (`graphql-inspector` 5.0.0; `@graphql-markdown/docusaurus` 1.20.0; Docusaurus 3.6.0 — all placeholders).
- [ ] **HoneyHub stands up later.** Until then, these workflows are buildable substrate. The first invocation lands when the HoneyHub standup initiative wires them in HoneyHub's per-repo CI.
- [ ] **GraphQL docs renderer choice** — `@graphql-markdown/docusaurus` is the v1 default per the rationale in §Context. The choice is swappable via a future ADR if Spectaql or another renderer becomes the better fit.

## Referenced ADR Decisions
**ADR-0057 D16 — HoneyHub schema evolution.** Additive-only on the live schema. Breaking changes via per-field `@deprecated(reason: "Use newField instead. Sunset YYYY-MM-DD.")`. Minimum 180-day deprecation per field. No `/v2` for HoneyHub — `/graphql` is stable; the schema evolves underneath.

**ADR-0057 D17 Phase 4 — HoneyHub GraphQL schema commitment.** "Aligned with HoneyHub's Phase 2 timeline per ADR-0003." Schema checked in at `repos/HoneyHub/api/schema.graphql`; breaking-change CI gate via `graphql-inspector`; docs site at `docs.honeyhub.honeydrunkstudios.com`.

**ADR-0057 D17 Phase 5 — AI-sector standup wave inheritance.** "Every AI Node that exposes a public API ... inherits the Phase 1 substrate at standup." The Phase 4 substrate (this packet's workflows) is in place before HoneyHub stands up so HoneyHub's standup inherits an already-tested CI gate.

**ADR-0003 (referenced) — HoneyHub.** HoneyHub uses GraphQL where REST is the Grid default per ADR-0057 D1; D16 is the narrow exception. HoneyHub does not yet exist on disk.

**ADR-0044 (referenced) — Grid-aware review agent.** Catches the slow-drift deprecation-reason-string issues that `graphql-inspector` does not.

**Invariant `{N4}` — HoneyHub uses schema evolution, not URL-prefix versioning.** Enforced by `job-graphql-inspector.yml`.

## Constraints
- **Pinned tool versions.**
- **GraphQL docs renderer choice documented in workflow input.** Swap requires a follow-up ADR, not a silent change.
- **No HoneyHub repo wiring.** HoneyHub does not exist on disk; these workflows ship as buildable substrate.
- **Single-version GraphQL docs site.** No `/v{N}/` path prefix on the GraphQL docs site (D16 — schema evolution, not URL versioning).
- **Dry-run until Cloudflare credentials + HoneyHub Pages project.**
- **No `Unreleased` CHANGELOG.**

## Labels
`feature`, `tier-1`, `core`, `adr-0057`, `wave-2`

## Agent Handoff

**Objective:** Ship the two GraphQL substrate workflows in `HoneyDrunk.Actions` — `job-graphql-inspector.yml` (HoneyHub Phase 4 breaking-change CI gate per ADR-0057 D16; enforces invariant `{N4}`) and `job-publish-graphql-docs.yml` (HoneyHub docs site builder + Cloudflare Pages deploy per ADR-0057 D15 cross-applied to GraphQL). HoneyHub does not exist on disk; these workflows are buildable substrate, invoked by HoneyHub's per-repo CI when HoneyHub stands up.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Have the Phase 4 substrate ready before HoneyHub stands up, per ADR-0057 D17 Phase 5's "AI-sector inherits Phase 1 substrate" pattern (HoneyHub follows the same shape).
- Feature: ADR-0057 rollout, Wave 2 (Actions substrate).
- ADRs: ADR-0057 D16 / D17 Phase 4 (primary); ADR-0003 (HoneyHub Proposed; standup deferred); ADR-0075 (Docusaurus narrative); ADR-0044 (review agent catches deprecation-reason-string drift).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — invariants `{N1}-{N4}` live; this workflow enforces `{N4}`.
- `work-item:01` — tech-stack.md commits `graphql-inspector` as the tool.

**Constraints:**
- Pinned versions.
- HoneyHub does not exist; workflows are buildable assets, not invoked yet.
- Single-version GraphQL docs site (no `/v{N}/` prefix).
- Dry-run until Cloudflare credentials + HoneyHub Pages project.
- No `Unreleased` CHANGELOG.

**Key Files:**
- `HoneyDrunk.Actions/.github/workflows/job-graphql-inspector.yml` (new)
- `HoneyDrunk.Actions/.github/workflows/job-publish-graphql-docs.yml` (new)
- `HoneyDrunk.Actions/docs/job-graphql-inspector.md` (new)
- `HoneyDrunk.Actions/docs/job-publish-graphql-docs.md` (new)
- `HoneyDrunk.Actions/CHANGELOG.md`
- `HoneyDrunk.Actions/README.md`

**Contracts:** None — reusable workflows only.
