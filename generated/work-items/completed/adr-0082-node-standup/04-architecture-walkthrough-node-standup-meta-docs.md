---
name: Documentation
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0082", "wave-3"]
dependencies: ["work-item:01"]
adrs: ["ADR-0082", "ADR-0011", "ADR-0012", "ADR-0044", "ADR-0064"]
accepts: ADR-0082
wave: 3
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Chore: Author `infrastructure/walkthroughs/node-standup-meta-docs.md` — per-class walkthrough for Meta / Docs / Wiki standups

## Summary

Author the Meta/Docs/Wiki per-class walkthrough at `infrastructure/walkthroughs/node-standup-meta-docs.md` per ADR-0082 D7. Composes against `constitution/node-standup.md` (packet 01). Covers the reduced procedure that applies to repos that ship docs/wiki/content rather than NuGet or deployables (Architecture, Lore, Standards, HoneyDrunk.Prompts).

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

Meta/Docs/Wiki repos are the simplest standup class:
- No NuGet publication, no `release.yml`, no OIDC federated credential (the repo *is* the deliverable).
- No `.slnx`, no `Directory.Build.props`, no `HoneyDrunk.Standards` reference.
- No deployment, no managed identity, no Bicep, no Container App.
- Mandatory steps 1–18 still apply (sector row, context folder, catalogs, branch protection, `repo-to-node.yml`, label seeding, `.honeydrunk-review.yaml`, CodeRabbit, README/CHANGELOG/LICENSE, `copilot-instructions.md`, `CLAUDE.md`, `pr.yml` calling `pr-core.yml`).
- For content-shipping Meta repos (Prompts per ADR-0064, future Standards content), a content-shape canary applies — frontmatter parses, declared parameters match body placeholders, no `classification: Restricted` content.

Without a dedicated walkthrough, every Meta standup re-derives "what *doesn't* apply" from a Core .NET precedent and risks leaving stray .slnx-class artifacts.

## Proposed Implementation

### `infrastructure/walkthroughs/node-standup-meta-docs.md` — new walkthrough

```markdown
# Node Standup — Meta / Docs / Wiki

**Applies to:** ADR-0082 D5 u–v (the Meta/Docs/Wiki class-specific steps).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure — mandatory steps 1–18 still apply)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** {N1} (node-registration-mandatory), 11, 12, 27, 31, 32, 33, 41, 52.

## Goal

Stand up a Meta/Docs/Wiki Node — Architecture, Lore, Standards, Prompts, or future docs/wiki repo. Three phases per ADR-0082 D3, but with the simplest content set.
- Class: `meta-docs`.
- Output: a public (default) GitHub repo with branch protection, the Grid context plumbing, the PR-review pipeline online, and the doc/wiki content structure ready to receive contributions.

## What is NOT in scope for Meta/Docs/Wiki

- **No `.slnx` solution, no `Directory.Build.props`, no `HoneyDrunk.Standards` reference.** The repo is not a .NET solution. Test projects (`*.Tests.Unit` etc.) per Invariant 50 also don't apply.
- **No NuGet publication, no `release.yml`, no NuGet-publishing OIDC federated credential.** The repo is the deliverable; there's nothing to publish to nuget.org.
- **No deployable, no Key Vault, no App Configuration, no managed identity, no Container App, no Bicep, no deploy workflow.** Nothing runs.
- **No contract-shape canary on `.Abstractions`** (no Abstractions package exists). For content-shipping Meta repos (Prompts, future Standards content), a content-shape canary applies — see Step v below.

## Phase A — Architecture registration

Same as Core .NET:
1. Catalog rows in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`. Meta Nodes carry `signal: "Live"` once the repo exists (no Seed phase since no scaffold complexity).
2. Sector row in `constitution/sectors.md` (Meta sector for governance/docs repos).
3. Five-file context folder at `repos/{NodeName}/`: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`. Even for the Architecture repo itself, the five-file shape is non-negotiable — it is the surface the `review` and `scope` agents load.
4. Standup ADR registered.
5. Initiative entry.
6. `repo-to-node.yml` mapping added to `HoneyDrunk.Actions/.github/config/`.

**Gate:** Phase A merges before Phase B.

## Phase B — GitHub repo creation (human-only org-admin)

1. Visit https://github.com/organizations/HoneyDrunkStudios/new.
2. Name: `HoneyDrunk.{NodeName}`. Visibility: **Public** (default per ADR-0082 D4 step 5).
3. Branch protection on `main`:
   - Require PR before merging.
   - Require status check `pr-core / core` (Invariant 31).
   - Block force-push; block deletion.
4. Label seeding (idempotent CLI loop) — same set as Core .NET, minus `scaffold` (there is no scaffold in the .NET sense; the first PR is the content + plumbing PR).
5. **Org-secret binding** — minimum `SONAR_TOKEN` (only if public repo's `pr.yml` runs `job-sonarcloud.yml`; for Markdown-only repos Sonar's value is limited and the team may opt out of the SonarCloud job entirely). No `NUGET_API_KEY` (no publishing). Per-class matrix in `constitution/node-standup.md` governs additions.
6. **No OIDC federated credential** — the Meta repo does not publish or deploy.
7. Local clone made.

**Gate:** Phase B complete before Phase C scaffold packet can be filed.

## Phase C — First content PR (bootstrap PR — agent-eligible)

File-tree to land in the bootstrap PR:

```
/
├── .github/
│   ├── copilot-instructions.md
│   └── workflows/
│       └── pr.yml                  (calls HoneyDrunk.Actions pr-core.yml — markdownlint, link-check, secret scan, frontmatter validation; opt out of Sonar for Markdown-only repos per ADR-0011 D11's intent)
├── .honeydrunk-review.yaml         (enabled: true)
├── .coderabbit.yaml                (per ADR-0079 D2; CodeRabbit is comparatively quiet on docs PRs but still adds value)
├── CHANGELOG.md                    (## [0.1.0] - YYYY-MM-DD)
├── CLAUDE.md                       (if the repo is a primary dev surface — for Architecture, Lore, Standards, Prompts: yes)
├── LICENSE                         (MIT for public; CC-BY-4.0 acceptable for pure content repos if the operator prefers and the standup ADR records the choice)
└── README.md                       (links standup ADR, repos/{Node}/ context folder)
```

(Per ADR-0082 D5 u: no `.slnx`, no `Directory.Build.props`, no `src/`, no `tests/`. The repo's content lives in topic-specific folders — `adrs/`, `constitution/`, `infrastructure/` for Architecture; `raw/`, `compiled/` for Lore; etc. The walkthrough does not prescribe the content folder shape — that is each Meta repo's own concern, codified in the standup ADR.)

`pr.yml` minimal caller for Meta:

```yaml
name: PR Core
on:
  pull_request:
    branches: [main]
permissions:
  contents: read
  pull-requests: write
  security-events: write
jobs:
  core:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/pr-core.yml@main
    with:
      run-dotnet-build: false
      run-dotnet-test: false
      run-sonarcloud: false  # opt-in per Meta repo; Markdown-only often opts out
    secrets: {}
```

(The opt-out flags above are illustrative; the actual `pr-core.yml` input names are whatever `HoneyDrunk.Actions/.github/workflows/pr-core.yml` exposes. The agent verifies the input names against the live workflow file at packet-execution time.)

## Content-shape canary (Step v — content-shipping Meta repos only)

Applies to repos that ship structured content other tools consume (HoneyDrunk.Prompts per ADR-0064; future structured Standards content). Does NOT apply to free-form Markdown repos (Architecture, Lore prose).

The canary is a workflow job that runs on every PR touching the content folder. For HoneyDrunk.Prompts per ADR-0064 D9/D11:
- Frontmatter parses (YAML-valid, declared fields present).
- Declared parameters match every `{{ parameter }}` placeholder in the body (Invariant 77 — the prompt-registry content-shape canary).
- No file carries `classification: Restricted` (Invariant 75 — Restricted-tier content stays out of the Prompts registry).

For other content-shipping Meta repos, the canary is shaped by the standup ADR's content-format decisions; the walkthrough names the canary requirement but does not prescribe the shape for repos that have not yet had a standup ADR commit to it.

## Post-merge

No throwaway-PR ritual (no contract-shape canary to confirm). Branch-protection update post-merge adds:
- `job-sonarcloud / sonarcloud` if Sonar is opted into.
- The content-shape canary check if content-shipping.

## No v0.1.0 tag

Meta repos do not version-publish. The repo *is* the deliverable; updates land via PR and are visible immediately on `main`.
```

## Affected Files

- `infrastructure/walkthroughs/node-standup-meta-docs.md` (new)

## NuGet Dependencies

None.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`.

## Acceptance Criteria

- [ ] `infrastructure/walkthroughs/node-standup-meta-docs.md` exists with the structure above
- [ ] "What is NOT in scope" section is explicit — no `.slnx`, no NuGet, no OIDC, no deployment, no contract-shape canary on `.Abstractions`
- [ ] Phase A, B, C sequence covers the reduced step set with explicit notes on what is omitted relative to Core .NET
- [ ] Content-shape canary (Step v) is documented for content-shipping Meta repos (Prompts, future structured Standards content) with the ADR-0064 D9/D11 + Invariants 75/77 reference
- [ ] `pr.yml` minimal caller example reflects the Markdown-mostly nature (sane defaults; opt-outs noted; agent verifies actual input names at execution time)
- [ ] No "post-merge throwaway PR" section (no contract canary to confirm); branch-protection update post-merge is the equivalent step
- [ ] Companion docs are linked (`constitution/node-standup.md`, `org-secret-repo-binding.md`)
- [ ] Repo-level `CHANGELOG.md` updated for the new walkthrough

## Human Prerequisites

None.

## Referenced ADR Decisions

**ADR-0082 D2** — Meta/Docs/Wiki class; the repo *is* the deliverable.
**ADR-0082 D5 u–v** — No NuGet/release.yml/OIDC; content-shape canary for content-shipping Meta repos.
**ADR-0082 D7** — Walkthrough unlocked by acceptance.
**ADR-0011 D11** — SonarCloud is per-repo opt-in for Meta/Markdown-only repos.
**ADR-0012 D5** — Caller permissions superset rule.
**ADR-0044 D4** — `.honeydrunk-review.yaml` mandatory.
**ADR-0064** — HoneyDrunk.Prompts content-shape canary spec (frontmatter parses, parameter parity, no Restricted-tier content).

## Constraints

- **Explicit about what's NOT in scope.** Meta repos are defined as much by what they don't have (no .slnx, no NuGet, no OIDC) as by what they do.
- **Content-shape canary covered for the Prompts case.** ADR-0064's spec is referenced concretely; other content-shipping repos noted as ADR-dependent.
- **`pr.yml` example notes the opt-out flags.** The actual input names are verified by the agent at packet-execution time against the live `pr-core.yml`.
- **No v0.1.0 tag, no throwaway-PR ritual.** The walkthrough is explicit that those steps don't apply.
- **PR body metadata.** Strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

## Labels

`chore`, `tier-2`, `meta`, `docs`, `adr-0082`, `wave-3`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/node-standup-meta-docs.md` — operational walkthrough for Meta/Docs/Wiki Node standups (Architecture, Lore, Standards, Prompts).

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give Meta standups a walkthrough that codifies the reduced procedure and prevents stray .NET-class artifacts.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 3.
- ADRs: ADR-0082 (D5 u–v, D7), ADR-0011 D11, ADR-0012 D5, ADR-0044 D4, ADR-0064.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (canonical procedure doc).

**Constraints:**
- Explicit "NOT in scope" section.
- Content-shape canary covered for Prompts; other content-shipping repos ADR-dependent.
- `pr.yml` opt-outs are documented; actual input names verified against live workflow at execution time.
- No throwaway-PR ritual; no v0.1.0 tag.
- PR body carries strict `Authorship: <enum>` + exactly one of `Work Item:` / `Out-of-band reason:`.

**Key Files:**
- `infrastructure/walkthroughs/node-standup-meta-docs.md` (new)

**Contracts:** None changed.
