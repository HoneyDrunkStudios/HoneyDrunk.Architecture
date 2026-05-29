---
name: Documentation
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "infra", "adr-0082", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0082", "ADR-0011", "ADR-0012", "ADR-0034", "ADR-0035", "ADR-0074"]
accepts: ADR-0082
wave: 3
initiative: adr-0082-node-standup
node: honeydrunk-architecture
---

# Chore: Author `infrastructure/walkthroughs/node-standup-core-dotnet.md` — per-class walkthrough for Core .NET Abstractions+Runtime and Runtime-only standups

## Summary

Author the per-class standup walkthrough at `infrastructure/walkthroughs/node-standup-core-dotnet.md` per ADR-0082 D7. The walkthrough is the operational step-by-step for Core .NET Abstractions+Runtime (default class) and Core .NET Runtime-only Node standups — it composes against `constitution/node-standup.md` (landed by packet 01) and does not re-derive the canonical rules. Includes the throwaway breaking-change PR sequence that confirms the contract-shape canary fires post-merge.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation

`constitution/node-standup.md` (packet 01) holds the **rules** (the eighteen mandatory steps, the class-specific steps a–z, the org-secret matrix). This walkthrough holds the **operational sequence** for the Core .NET classes — the actual order of operations, the precise CLI invocations where applicable, the file-tree snapshot, the throwaway-breaking-change-PR ritual that confirms the contract-shape canary fires, the gotchas observed across the Audit / Communications / Cache / Identity / Files standups.

Without the walkthrough, every new Core .NET standup re-derives the operational order from the most recent precedent scaffold packet. Per ADR-0082 D7, the walkthrough is *unlocked* by the ADR's acceptance but is a separate deliverable from the canonical procedure document.

## Proposed Implementation

### `infrastructure/walkthroughs/node-standup-core-dotnet.md` — new walkthrough

Create the file following the existing walkthrough structure (`**Applies to:**` / `**Related invariants:**` / `**Companion docs:**` / `## Goal` / `## Pre-flight` / `## Phase A` / `## Phase B` / `## Phase C` / `## Post-merge`). Concretely:

```markdown
# Node Standup — Core .NET (Abstractions+Runtime, Runtime-only)

**Applies to:** ADR-0082 D5 a–m (the Core .NET class-specific steps).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure — rules live there)
- `infrastructure/walkthroughs/oidc-federated-credentials.md` (Step h)
- `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (Step l one-time org onboarding)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** {N1} (node-registration-mandatory), 11, 12, 26, 27, 31, 32, 33, 41, 46, 49, 52.

## Goal

Stand up a Core .NET Node end-to-end across the three ADR-0082 phases.
- Class: `core-dotnet-abstractions-runtime` (default) or `core-dotnet-runtime-only`.
- Output: a published `v0.1.0` NuGet package (Abstractions+Runtime: two packages; Runtime-only: one) with the contract-shape canary armed and the org's PR-review pipeline online.

## Pre-flight

- Standup ADR drafted (shape: ADR-0019 / ADR-0027 / ADR-0031 / ADR-0059 / ADR-0061).
- Node class decided and recorded in standup ADR frontmatter (`node_class: core-dotnet-abstractions-runtime` or `core-dotnet-runtime-only`).
- Sector decided (Core / AI / Ops etc.) for the sectors.md row.
- Invariant slot claimed in `constitution/invariant-reservations.md` if the standup adds invariants.

## Phase A — Architecture registration

(One Architecture packet; no GitHub repo for the new Node yet.)

1. Catalog rows added to `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`.
2. Sector row added to `constitution/sectors.md` with signal `Seed`.
3. Five-file context folder created at `repos/{NodeName}/`: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`.
4. Standup ADR registered in `adrs/` and `adrs/README.md`.
5. Initiative entry in `initiatives/active-initiatives.md` (or defer to hive-sync Phase D).
6. `repo-to-node.yml` mapping added to `HoneyDrunk.Actions/.github/config/`. (Preferred to land in Phase A to avoid the historical drift channel — commit `23a183c` retrofitted Audit because this step was forgotten.)

**Gate:** merge Phase A before starting Phase B.

## Phase B — GitHub repo creation (human-only org-admin)

1. Visit https://github.com/organizations/HoneyDrunkStudios/new.
2. Name: `HoneyDrunk.{NodeName}`. Visibility: **Public** (default per ADR-0082 D4 step 5; private only with ADR-recorded carve-out per ADR-0027 D2 precedent).
3. No README/`.gitignore`/license at create time — the scaffold packet lands those.
4. Branch protection on `main`:
   - Require PR before merging.
   - Require status check `pr-core / core` (Invariant 31).
   - Block force-push; block deletion.
   - Do not require signed commits (matches Grid posture).
5. Label seeding via `gh label create` idempotent loop: `feature`, `chore`, `tier-1`, `tier-2`, `tier-3`, `scaffold`, `adr-{NNNN}`, `human-only`, `out-of-band`, plus wave/initiative-specific labels.
6. **Org-secret binding** — for every org secret the new repo will consume, follow `infrastructure/walkthroughs/org-secret-repo-binding.md`. Minimum for Core .NET: `SONAR_TOKEN` (always), `NUGET_API_KEY` (always — NuGet-shipping), and any conditional secrets per the matrix in `constitution/node-standup.md`.
7. OIDC federated credential subject pattern added to the Grid's NuGet publishing identity in Microsoft Entra: `repo:HoneyDrunkStudios/HoneyDrunk.{NodeName}:ref:refs/tags/v*`. Walkthrough: `oidc-federated-credentials.md`.
8. Local clone made.

**Gate:** Phase B complete before Phase C scaffold packet can be filed (Invariant 24 — `target_repo` must exist).

## Phase C — Scaffold landing (agent-eligible — bootstrap PR)

(One scaffold packet — exemplar `03-{node}-node-scaffold.md`.)

File-tree to land in the bootstrap PR:

```
/
├── .editorconfig (inherited from HoneyDrunk.Standards at build time, but a local file is fine to seed)
├── .github/
│   ├── copilot-instructions.md
│   └── workflows/
│       ├── pr.yml                 (calls HoneyDrunk.Actions pr-core.yml — D5l drops `sonar` only for private repos)
│       ├── release.yml            (calls HoneyDrunk.Actions release.yml; tag-triggered)
│       ├── nightly-deps.yml       (calls HoneyDrunk.Actions reusable workflow per ADR-0009)
│       ├── nightly-security.yml   (calls HoneyDrunk.Actions reusable workflow per ADR-0009)
│       └── api-compatibility.yml  (calls HoneyDrunk.Actions job-api-compatibility.yml scoped to .Abstractions)
├── .honeydrunk-review.yaml        (enabled: true)
├── .coderabbit.yaml               (per ADR-0079 D2)
├── CHANGELOG.md                   (## [0.1.0] - YYYY-MM-DD entry from first commit)
├── CLAUDE.md                      (links repos/{Node}/overview.md, standup ADR)
├── Directory.Build.props          (TargetFramework, Nullable, ImplicitUsings, LangVersion, TreatWarningsAsErrors, shared Version, package metadata)
├── HoneyDrunk.{NodeName}.slnx
├── LICENSE                        (MIT for public; FSL-1.1-MIT for open engines of revenue Nodes; LicenseRef-Proprietary for private revenue)
├── README.md                      (links standup ADR, repos/{Node}/ context folder)
├── sonar-project.properties       (public repos only)
└── src/
    ├── HoneyDrunk.{NodeName}.Abstractions/
    │   ├── HoneyDrunk.{NodeName}.Abstractions.csproj  (HoneyDrunk.Standards PrivateAssets="all")
    │   ├── CHANGELOG.md
    │   └── README.md
    ├── HoneyDrunk.{NodeName}/
    │   ├── HoneyDrunk.{NodeName}.csproj
    │   ├── CHANGELOG.md
    │   └── README.md
    └── (Runtime-only class: omit the .Abstractions package; the runtime package's public surface is the contract surface — the contract-shape canary scopes to that.)
tests/
    └── HoneyDrunk.{NodeName}.Tests.Unit/
        └── HoneyDrunk.{NodeName}.Tests.Unit.csproj  (xUnit + NSubstitute + AwesomeAssertions + coverlet per ADR-0074)
```

Notes on the file-tree:
- Every `.csproj` (including tests) references `HoneyDrunk.Standards` with `PrivateAssets="all"` (Invariant 26). The Standards package brings the analyzers, StyleCop, `.editorconfig`, and the test-project `Thread.Sleep` analyzer (Invariant 51).
- Repo-level `CHANGELOG.md` and per-package `CHANGELOG.md` both exist from the first commit (Invariant 12). No `## Unreleased` placeholder — first entry is `## [0.1.0] - YYYY-MM-DD`.
- In-memory test fixture for the Node's primary contracts is internal to the runtime package's test project (ADR-0027 D3 precedent); cut to `HoneyDrunk.{NodeName}.Testing` package only when a third consumer appears.
- End-to-end smoke test exercises the in-memory fixture: write through the primary contract, read back through the query/observation contract, assert round-trip.

`pr.yml` minimal caller (per ADR-0012 D5 — caller permissions must be superset of reusable workflow's):

```yaml
name: PR Core
on:
  pull_request:
    branches: [main]
permissions:
  contents: read
  pull-requests: write
  security-events: write
  id-token: write
jobs:
  core:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/pr-core.yml@main
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

(Public repos: `SONAR_TOKEN` is required. Private repos: drop the `job-sonarcloud` job per ADR-0011 D11.)

`release.yml` minimal caller — tag-triggered, no `secrets: inherit`:

```yaml
name: Release
on:
  push:
    tags: ['v*.*.*']
permissions:
  contents: write
  id-token: write
jobs:
  release:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/release.yml@main
    secrets:
      NUGET_API_KEY: ${{ secrets.NUGET_API_KEY }}
```

`api-compatibility.yml` minimal caller — path-filtered to `.Abstractions`:

```yaml
name: API Compatibility
on:
  pull_request:
    paths:
      - 'src/HoneyDrunk.{NodeName}.Abstractions/**'
      - 'Directory.Build.props'
permissions:
  contents: read
  pull-requests: write
jobs:
  abstractions-shape:
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml@main
    with:
      project: src/HoneyDrunk.{NodeName}.Abstractions/HoneyDrunk.{NodeName}.Abstractions.csproj
```

(Runtime-only class: scope the path filter to the runtime package's `src/HoneyDrunk.{NodeName}/**` and pass the runtime project as `project:`. The contract surface is the runtime package's public surface.)

## Post-merge — throwaway breaking-change PR ritual

Confirms the contract-shape canary fires:

1. Branch from `main`.
2. Make an intentionally breaking change to a public type in `HoneyDrunk.{NodeName}.Abstractions` (e.g. add a new required member to a public interface).
3. Open a PR. Do not bump `Version` in `Directory.Build.props`.
4. The `api-compatibility / abstractions-shape` check must fail on the PR. If it does not, the canary is misconfigured — fix and repeat.
5. Close the throwaway PR without merging.
6. Open a follow-up PR to update branch protection on `main` to require `api-compatibility / abstractions-shape` as a status check (and, for public repos, `job-sonarcloud / sonarcloud`).

## v0.1.0 tag and first publish

After scaffold merge + branch-protection update + canary confirmation:

1. Human (not agent — Invariant 27) pushes the `v0.1.0` tag.
2. `release.yml` runs against the tag, OIDC-authenticates via the federated credential, publishes the package(s) to nuget.org.
3. First non-bootstrap PR may now land — invariant 102 binds it.
```

## Affected Files

- `infrastructure/walkthroughs/node-standup-core-dotnet.md` (new)

## NuGet Dependencies

None.

## Boundary Check

- [x] All edits in `HoneyDrunk.Architecture`.
- [x] No code change in any other repo.

## Acceptance Criteria

- [ ] `infrastructure/walkthroughs/node-standup-core-dotnet.md` exists with the structure above
- [ ] The walkthrough composes against `constitution/node-standup.md` — it does not duplicate the rules, it sequences them
- [ ] All three phases are covered with the Phase A → B → C → Post-merge → v0.1.0 tag sequence
- [ ] File-tree snapshot, `pr.yml` / `release.yml` / `api-compatibility.yml` minimal caller examples are present and correct per ADR-0012 D5 and ADR-0034
- [ ] Throwaway breaking-change PR ritual is documented as the post-merge step that confirms the canary fires
- [ ] Companion docs are linked (`constitution/node-standup.md`, `oidc-federated-credentials.md`, `sonarcloud-organization-setup.md`, `org-secret-repo-binding.md`)
- [ ] Both Core .NET subclasses (Abstractions+Runtime and Runtime-only) are explicitly addressed — the file-tree, the canary scope, and the package count differ between them
- [ ] Repo-level `CHANGELOG.md` updated for the new walkthrough

## Human Prerequisites

None.

## Referenced ADR Decisions

**ADR-0082 D2** — Core .NET Abstractions+Runtime is the default class; Core .NET Runtime-only is used when the Node *is* the contract holder (Kernel is the historical example).
**ADR-0082 D5 a–m** — Core .NET class-specific steps: `.slnx`, `Directory.Build.props`, Standards reference, test layout, `release.yml`, nightlies, OIDC, canary, in-memory fixture, smoke test, Sonar.
**ADR-0082 D7** — Walkthrough unlocked by acceptance.
**ADR-0011 D11** — `sonar-project.properties` + `job-sonarcloud.yml` required for public repos.
**ADR-0012 D1, D4, D5** — Reusable workflows; CLI invocation discipline; caller permissions superset rule.
**ADR-0034** — NuGet publishing via OIDC federated credential.
**ADR-0035** — `.Abstractions` versioning discipline.
**ADR-0074** — Test stack (xUnit + NSubstitute + AwesomeAssertions + coverlet).

## Constraints

- **Composition, not duplication.** This walkthrough composes against `constitution/node-standup.md` (packet 01). It does not restate the rules — it sequences them and adds operational detail (file paths, CLI invocations, YAML examples).
- **Covers both subclasses.** Where Abstractions+Runtime and Runtime-only diverge (package count, canary scope), the walkthrough names the difference explicitly.
- **YAML examples are correct.** Caller permissions blocks satisfy ADR-0012 D5's superset rule. `release.yml` uses explicit named secrets, not `secrets: inherit`.
- **Throwaway-PR ritual is documented as a step, not a footnote.** The canary's post-merge confirmation is operationally load-bearing.
- **PR body metadata.** Strict `Authorship: <enum>` + exactly one of `Packet:` / `Out-of-band reason:`.

## Labels

`chore`, `tier-2`, `meta`, `docs`, `infra`, `adr-0082`, `wave-3`

## Agent Handoff

**Objective:** Author `infrastructure/walkthroughs/node-standup-core-dotnet.md` — the operational walkthrough for Core .NET (Abstractions+Runtime and Runtime-only) Node standups across all three ADR-0082 phases.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give every future Core .NET standup an operational runbook that composes against the canonical procedure document.
- Feature: ADR-0082 Canonical Node Standup Procedure, Wave 3.
- ADRs: ADR-0082 (D5 a–m, D7), ADR-0011 D11, ADR-0012 D1/D4/D5, ADR-0034, ADR-0035, ADR-0074.

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (canonical procedure document) must merge first so this walkthrough has something to compose against.

**Constraints:**
- Composition, not duplication — rules live in `constitution/node-standup.md`; this walkthrough sequences them.
- Cover both Core .NET subclasses; name divergences explicitly.
- YAML caller examples satisfy ADR-0012 D5's superset rule and ADR-0034's explicit-named-secrets rule.
- Throwaway-PR canary-confirmation ritual is a documented step.
- PR body carries strict `Authorship: <enum>` + exactly one of `Packet:` / `Out-of-band reason:`.

**Key Files:**
- `infrastructure/walkthroughs/node-standup-core-dotnet.md` (new)

**Contracts:** None changed.
