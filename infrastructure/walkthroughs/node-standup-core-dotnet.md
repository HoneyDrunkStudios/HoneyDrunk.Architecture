# Node Standup — Core .NET (Abstractions+Runtime, Runtime-only)

**Applies to:** ADR-0082 D5 a–m (the Core .NET class-specific steps).
**Companion docs:**
- `constitution/node-standup.md` (canonical procedure — rules live there; this walkthrough sequences them)
- `infrastructure/walkthroughs/oidc-federated-credentials.md` (Step h)
- `infrastructure/walkthroughs/sonarcloud-organization-setup.md` (Step l one-time org onboarding)
- `infrastructure/walkthroughs/org-secret-repo-binding.md` (Phase B)
**Related invariants:** 102 (node-registration-mandatory), 11 (one repo per Node), 12 (CHANGELOG + README), 26 (NuGet Dependencies section + Standards on every project), 27 (one shared solution version), 31 (tier-1 gate required), 32 (agent PRs link their packet), 33 (review/scope context coupling), 41 (new repos registered in `repos/`), 46 / 49 (contract-shape canary obligation).

## Goal

Stand up a Core .NET Node end-to-end across the three ADR-0082 phases.

- Class: `core-dotnet-abstractions-runtime` (default) or `core-dotnet-runtime-only`.
- Output: a published `v0.1.0` NuGet package (Abstractions+Runtime: two packages; Runtime-only: one) with the contract-shape canary armed and the org's PR-review pipeline online.

## Pre-flight

- Standup ADR drafted (shape: ADR-0019 / ADR-0027 / ADR-0031 / ADR-0059 / ADR-0061 — capability/decision body + "If Accepted — Required Follow-Up Work" checklist at the top).
- Node class decided and recorded in the standup ADR frontmatter (`node_class: core-dotnet-abstractions-runtime` or `core-dotnet-runtime-only`).
- Sector decided (Core / AI / Ops, etc.) for the `constitution/sectors.md` row.
- Invariant slot claimed in `constitution/invariant-reservations.md` if the standup adds invariants.

## Subclass divergence at a glance

| Concern | `core-dotnet-abstractions-runtime` (default) | `core-dotnet-runtime-only` |
|---|---|---|
| Package count | Two — `{Node}.Abstractions` + `{Node}` | One — `{Node}` (the runtime package *is* the contract holder) |
| Contract-shape canary scope | `src/HoneyDrunk.{Node}.Abstractions/**` | `src/HoneyDrunk.{Node}/**` (the runtime package's public surface) |
| Downstream coupling | Consumers compile against `.Abstractions` only | No downstream compiles against shapes — used only when the Node has no contract consumers (Kernel is the historical example) |

Everything else below is identical between the two subclasses.

## Phase A — Architecture registration

(One Architecture packet; no GitHub repo for the new Node yet.)

1. Catalog rows added to `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`.
2. Sector row added to `constitution/sectors.md` with signal `Seed`.
3. Five-file context folder created at `repos/{NodeName}/`: `overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`.
4. Standup ADR registered in `adrs/` and `adrs/README.md`.
5. Initiative entry in `initiatives/active-initiatives.md` (or defer to hive-sync per Phase D).
6. `repo-to-node.yml` mapping added to `HoneyDrunk.Actions/.github/config/`. Preferred to land in Phase A to avoid the historical drift channel — commit `23a183c` retrofitted Audit because this step was forgotten.

**Gate:** merge Phase A before starting Phase B. The scaffold packet's `target_repo` would otherwise point at a repo that does not exist.

## Phase B — GitHub repo creation (human-only org-admin)

1. Visit `https://github.com/organizations/HoneyDrunkStudios/new`.
2. Name: `HoneyDrunk.{NodeName}`. Visibility: **Public** (default per ADR-0082 D4 step 5; private only with an ADR-recorded carve-out per the ADR-0027 D2 precedent).
3. No README / `.gitignore` / license at create time — the scaffold packet lands those.
4. Branch protection on `main`:
   - Require PR before merging.
   - Require status check `pr-core / core` (Invariant 31).
   - Block force-push; block deletion.
   - Do not require signed commits (matches Grid posture).
5. Label seeding via a `gh label create` idempotent loop: `feature`, `chore`, `tier-1`, `tier-2`, `tier-3`, `scaffold`, `adr-{NNNN}`, `human-only`, `out-of-band`, plus wave/initiative-specific labels.
6. **Org-secret binding** — for every org secret the new repo will consume, follow `infrastructure/walkthroughs/org-secret-repo-binding.md`. Minimum for Core .NET: `SONAR_TOKEN` (always, public repos), `NUGET_API_KEY` (always — NuGet-shipping), and any conditional secrets per the matrix in `constitution/node-standup.md`.
7. OIDC federated credential subject pattern added to the Grid's NuGet publishing identity in Microsoft Entra: `repo:HoneyDrunkStudios/HoneyDrunk.{NodeName}:ref:refs/tags/v*`. Walkthrough: `oidc-federated-credentials.md`.
8. Local clone made.

**Gate:** Phase B complete before the Phase C scaffold packet can be filed — Invariant 24 (issue packets immutable once filed) means the `target_repo` must exist before the issue is created.

## Phase C — Scaffold landing (agent-eligible — bootstrap PR)

(One scaffold packet — exemplar `03-{node}-node-scaffold.md`.)

File-tree to land in the bootstrap PR:

```
/
├── .editorconfig                  (inherited from HoneyDrunk.Standards at build time; a local seed file is fine)
├── .github/
│   ├── copilot-instructions.md
│   └── workflows/
│       ├── pr.yml                 (calls HoneyDrunk.Actions pr-core.yml — drops the sonar job only for private repos)
│       ├── release.yml            (calls HoneyDrunk.Actions release.yml; tag-triggered)
│       ├── nightly-deps.yml       (calls HoneyDrunk.Actions reusable workflow per ADR-0009)
│       ├── nightly-security.yml   (calls HoneyDrunk.Actions reusable workflow per ADR-0009)
│       └── api-compatibility.yml  (calls HoneyDrunk.Actions job-api-compatibility.yml scoped to .Abstractions)
├── .honeydrunk-review.yaml        (enabled: true)
├── .coderabbit.yaml               (per ADR-0079 D2)
├── CHANGELOG.md                   (## [0.1.0] - YYYY-MM-DD entry from the first commit)
├── CLAUDE.md                      (links repos/{Node}/overview.md, standup ADR)
├── Directory.Build.props          (TargetFramework, Nullable, ImplicitUsings, LangVersion, TreatWarningsAsErrors, shared Version, package metadata)
├── HoneyDrunk.{NodeName}.slnx
├── LICENSE                        (MIT for public; FSL-1.1-MIT for open engines of revenue Nodes; LicenseRef-Proprietary for private revenue)
├── README.md                      (links standup ADR, repos/{Node}/ context folder)
├── sonar-project.properties       (public repos only)
└── src/
    ├── HoneyDrunk.{NodeName}.Abstractions/        (omit for core-dotnet-runtime-only)
    │   ├── HoneyDrunk.{NodeName}.Abstractions.csproj  (HoneyDrunk.Standards PrivateAssets="all")
    │   ├── CHANGELOG.md
    │   └── README.md
    └── HoneyDrunk.{NodeName}/
        ├── HoneyDrunk.{NodeName}.csproj
        ├── CHANGELOG.md
        └── README.md
tests/
    └── HoneyDrunk.{NodeName}.Tests.Unit/
        └── HoneyDrunk.{NodeName}.Tests.Unit.csproj  (xUnit + NSubstitute + AwesomeAssertions + coverlet per ADR-0074)
```

Notes on the file-tree:

- Every `.csproj` (including the test project) references `HoneyDrunk.Standards` with `PrivateAssets="all"` (Invariant 26). The Standards package brings the analyzers, StyleCop, `.editorconfig`, and the test-project `Thread.Sleep` analyzer (Invariant 51).
- Repo-level `CHANGELOG.md` and per-package `CHANGELOG.md` both exist from the first commit (Invariant 12). No `## Unreleased` placeholder — the first entry is `## [0.1.0] - YYYY-MM-DD`.
- The in-memory test fixture for the Node's primary contracts is internal to the runtime package's test project (ADR-0027 D3 precedent); cut to a `HoneyDrunk.{NodeName}.Testing` package only when a third consumer appears.
- The end-to-end smoke test exercises the in-memory fixture: write through the primary contract, read back through the query/observation contract, assert round-trip.
- **Runtime-only subclass:** omit the `.Abstractions` package; the runtime package's public surface is the contract surface, and the contract-shape canary scopes to it.

`pr.yml` minimal caller (per ADR-0012 D5 — caller permissions must be a superset of the reusable workflow's):

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

(Runtime-only subclass: scope the path filter to the runtime package's `src/HoneyDrunk.{NodeName}/**` and pass the runtime project as `project:`. The contract surface is the runtime package's public surface.)

## Post-merge — throwaway breaking-change PR ritual

Confirms the contract-shape canary fires:

1. Branch from `main`.
2. Make an intentionally breaking change to a public type in `HoneyDrunk.{NodeName}.Abstractions` (e.g. add a new required member to a public interface).
3. Open a PR. Do **not** bump `Version` in `Directory.Build.props`.
4. The `api-compatibility / abstractions-shape` check must fail on the PR. If it does not, the canary is misconfigured — fix and repeat.
5. Close the throwaway PR without merging.
6. Open a follow-up PR to update branch protection on `main` to require `api-compatibility / abstractions-shape` as a status check (and, for public repos, `job-sonarcloud / sonarcloud`).

## v0.1.0 tag and first publish

After scaffold merge + branch-protection update + canary confirmation:

1. The human (not an agent — Invariant 27: agents never push tags) pushes the `v0.1.0` tag.
2. `release.yml` runs against the tag, OIDC-authenticates via the federated credential, and publishes the package(s) to nuget.org.
3. The first non-bootstrap PR may now land — invariant 102 binds it.
