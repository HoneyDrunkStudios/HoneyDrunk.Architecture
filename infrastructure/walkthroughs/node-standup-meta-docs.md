# Node Standup — Meta / Docs / Wiki

**Applies to:** ADR-0082 D5 u–v (the Meta/Docs/Wiki class-specific steps).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure — mandatory steps 1–18 still apply)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** 102 (node-registration-mandatory), 11 (one repo per Node), 12 (CHANGELOG + README), 27 (shared version — applies if the repo ever versions content), 31 (tier-1 gate required), 32 (agent PRs link their packet), 33 (review/scope context coupling), 41 (new repos registered in `repos/`), 52 (cloud review on enabled repos).

## Goal

Stand up a Meta/Docs/Wiki Node — Architecture, Lore, Standards, Prompts, or a future docs/wiki repo. Three phases per ADR-0082 D3, but with the simplest content set.

- Class: `meta-docs`.
- Output: a public (default) GitHub repo with branch protection, the Grid context plumbing, the PR-review pipeline online, and the doc/wiki content structure ready to receive contributions.

## What is NOT in scope for Meta/Docs/Wiki

- **No `.slnx` solution, no `Directory.Build.props`, no `HoneyDrunk.Standards` reference.** The repo is not a .NET solution. The `*.Tests.Unit` / `*.Tests.Integration` / `*.Tests.E2E` projects required by Invariant 50 also do not apply (there is no compiled code to test).
- **No NuGet publication, no `release.yml`, no NuGet-publishing OIDC federated credential.** The repo is the deliverable; there is nothing to publish to nuget.org.
- **No deployable, no Key Vault, no App Configuration, no managed identity, no Container App, no Bicep, no deploy workflow.** Nothing runs.
- **No contract-shape canary on `.Abstractions`** (no Abstractions package exists). For content-shipping Meta repos (Prompts, future structured Standards content), a **content-shape** canary applies instead — see Step v below.

## Phase A — Architecture registration

Same as Core .NET:

1. Catalog rows in `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`. Meta Nodes carry `signal: "Live"` once the repo exists (no Seed phase, since there is no scaffold complexity to stage).
2. Sector row in `constitution/sectors.md` (Meta sector for governance/docs repos).
3. Five-file context folder at `repos/{NodeName}/`: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`. Even for the Architecture repo itself the five-file shape is non-negotiable — it is the surface the `review` and `scope` agents load (Invariant 33).
4. Standup ADR registered in `adrs/` and `adrs/README.md`.
5. Initiative entry in `initiatives/active-initiatives.md`.
6. `repo-to-node.yml` mapping added to `HoneyDrunk.Actions/.github/config/`.

**Gate:** Phase A merges before Phase B.

## Phase B — GitHub repo creation (human-only org-admin)

1. Visit `https://github.com/organizations/HoneyDrunkStudios/new`.
2. Name: `HoneyDrunk.{NodeName}`. Visibility: **Public** (default per ADR-0082 D4 step 5).
3. Branch protection on `main`:
   - Require PR before merging.
   - Require status check `pr-core / core` (Invariant 31).
   - Block force-push; block deletion.
4. Label seeding (idempotent CLI loop) — the same set as Core .NET, minus `scaffold` (there is no scaffold in the .NET sense; the first PR is the content + plumbing PR).
5. **Org-secret binding** — minimum `SONAR_TOKEN`, and only if the public repo's `pr.yml` runs `job-sonarcloud.yml`. For Markdown-only repos SonarCloud's value is limited and the team may opt out of the Sonar job entirely. No `NUGET_API_KEY` (no publishing). The per-class matrix in `constitution/node-standup.md` governs any additions. Follow `org-secret-repo-binding.md`.
6. **No OIDC federated credential** — the Meta repo neither publishes nor deploys.
7. Local clone made.

**Gate:** Phase B complete before the Phase C content packet can be filed.

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
├── CLAUDE.md                       (primary dev surface for Architecture, Lore, Standards, Prompts: yes)
├── LICENSE                         (MIT for public; CC-BY-4.0 acceptable for pure-content repos if the operator prefers and the standup ADR records the choice)
└── README.md                       (links standup ADR, repos/{Node}/ context folder)
```

(Per ADR-0082 D5 u: no `.slnx`, no `Directory.Build.props`, no `src/`, no `tests/`. The repo's content lives in topic-specific folders — `adrs/`, `constitution/`, `infrastructure/` for Architecture; `raw/`, `compiled/` for Lore; etc. The walkthrough does not prescribe the content-folder shape — that is each Meta repo's own concern, codified in its standup ADR.)

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

(The opt-out flags above are illustrative. The actual `pr-core.yml` input names are whatever `HoneyDrunk.Actions/.github/workflows/pr-core.yml` exposes — verify them against the live workflow file at packet-execution time and use the real names.)

## Content-shape canary (Step v — content-shipping Meta repos only)

Applies to repos that ship structured content other tools consume (HoneyDrunk.Prompts per ADR-0064; future structured Standards content). Does **not** apply to free-form Markdown repos (Architecture, Lore prose).

The canary is a workflow job that runs on every PR touching the content folder. For HoneyDrunk.Prompts per ADR-0064 D9/D11:

- Frontmatter parses (YAML-valid, declared fields present).
- Declared parameters match every `{{ parameter }}` placeholder in the body (Invariant 77 — the prompt-registry content-shape canary).
- No file carries `classification: Restricted` (Invariant 75 — Restricted-tier content stays out of the Prompts registry).

For other content-shipping Meta repos the canary shape is set by the repo's standup ADR's content-format decisions; this walkthrough names the canary requirement but does not prescribe a shape for repos whose standup ADR has not yet committed to one.

## Post-merge

No throwaway-PR ritual (no contract-shape canary to confirm). The branch-protection update post-merge adds:

- `job-sonarcloud / sonarcloud` if Sonar is opted into.
- The content-shape canary check if content-shipping.

## No v0.1.0 tag

Meta repos do not version-publish. The repo *is* the deliverable; updates land via PR and are visible immediately on `main`.
