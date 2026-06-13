---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
target_repos: ["HoneyDrunk.Kernel", "HoneyDrunk.Transport", "HoneyDrunk.Vault", "HoneyDrunk.Vault.Rotation", "HoneyDrunk.Auth", "HoneyDrunk.Web.Rest", "HoneyDrunk.Data", "HoneyDrunk.Audit", "HoneyDrunk.Pulse", "HoneyDrunk.Notify", "HoneyDrunk.Communications", "HoneyDrunk.Observe"]
labels: ["chore", "tier-2", "core", "ops", "coordination", "adr-0035", "wave-3"]
dependencies: ["work-item:01", "work-item:03"]
adrs: ["ADR-0035", "ADR-0034"]
accepts: ["ADR-0035"]
wave: 3
initiative: adr-0035-abstractions-versioning
node: honeydrunk-architecture
---

# Adopt the public-API-analyzer fragment, commit PublicAPI.Shipped.txt baselines, and wire job-api-diff.yml across all public Nodes (ADR-0035 D9)

## Summary
Roll the ADR-0035 enforcement out to every public package-producing Node: import the `HoneyDrunk.Standards` public-API-analyzer fragment (packet 01), commit the one-time baseline `PublicAPI.Shipped.txt` for every packable project at its current published surface, add an empty `PublicAPI.Unshipped.txt`, and amend each Node's release/PR pipeline to call `job-api-diff.yml` and run the `[Obsolete]`-audit (packet 03).

## Repo-list reconciliation (read this before filing)
ADR-0035's Affected Nodes section says "Every public Node — gains `PublicAPI.{Shipped,Unshipped}.txt`, the analyzer reference, and a one-time baseline commit at current published version." ADR-0035 governs **every public `*.Abstractions` package**, so the gating test for inclusion in this fan-out is concrete and per-node:

> **Inclusion test: a Node is in this fan-out if its repo is scaffolded and it currently ships at least one public `.Abstractions` NuGet package** (per `catalogs/relationships.json` `exposes.packages`, cross-checked against the actual scaffolded repo). A Node whose Abstractions package is still only `packages_planned` adopts ADR-0035's tooling at its own standup, not here.

Applying that test:

- **`HoneyDrunk.Architecture`**, **`HoneyDrunk.Studios`**, **`HoneyDrunk.Actions`** are excluded — **these repos ship no NuGet packages at all** (Architecture is the governance/catalog repo, Studios is the marketing site, Actions is the CI workflow repo). There is no public API surface to baseline.
- **`HoneyDrunk.Standards`** is excluded from *this* fan-out — it adopts its own analyzer fragment as part of authoring it (packet 01). Do not double-apply here.
- **`HoneyDrunk.Audit`** *is* included — it ships `HoneyDrunk.Audit.Abstractions` (`catalogs/relationships.json` id `honeydrunk-audit`; ADR-0030/0031 standup). If at filing time Audit's repo is not yet package-publishing, the `file-work-items` agent drops it from the fan-out and notes it.
- **`HoneyDrunk.Vault.Rotation`** is included — it ships `HoneyDrunk.Vault.Rotation`.
- **`HoneyDrunk.Observe`** *is* included — it is an **Ops-sector Node** (`catalogs/nodes.json` `sector: "Ops"`), its repo **is scaffolded** (`src/HoneyDrunk.Observe.Abstractions/`), and it currently ships the public `HoneyDrunk.Observe.Abstractions` package (v0.1.0; `catalogs/relationships.json` `exposes.packages: ["HoneyDrunk.Observe.Abstractions"]`). Since ADR-0035 governs every public `.Abstractions` package, `Observe.Abstractions` is in scope. Observe's other packages (`HoneyDrunk.Observe`, the connector packages) are still `packages_planned` — only the already-shipped `Observe.Abstractions` is baselined now; the planned packages adopt the fragment when they scaffold.

That gives the **12 package-producing scaffolded .NET Node repos** enumerated in `target_repos`. **The 9 AI-sector Seed Nodes** (AI, Capabilities, Agents, Memory, Knowledge, Flow, Operator, Evals, Sim) are explicitly OUT — they fail the inclusion test: not yet scaffolded as live package-producing repos. They adopt ADR-0035's tooling as they scaffold, in each Node's own standup-ADR work. **Private revenue Nodes** (`HoneyDrunk.Notify.Cloud`, ADR-0027 — not yet scaffolded) are OUT: ADR-0035 D8 says private packages are not bound by D1–D6 (they may break consumers at minor versions). They adopt their own rule at standup. The 12-repo list is pinned — do not add Nodes at filing time; apply the inclusion test if in doubt.

## Context
ADR-0035 D9 commits three CI gates. Packet 01 authored the shared `HoneyDrunk.Standards` public-API-analyzer fragment (gate 1's analyzer + the `PublicAPI.{Shipped,Unshipped}.txt` convention). Packet 03 authored `job-api-diff.yml` (gate 2) and the `[Obsolete]`-audit (gate 3). This packet is the per-Node adoption — the work ADR-0035's Follow-up Work names as "Add `Microsoft.CodeAnalysis.PublicApiAnalyzers` to every public Node's `Directory.Build.props`; one-time baseline commit."

The **baseline commit** is the load-bearing part. `Microsoft.CodeAnalysis.PublicApiAnalyzers` treats every public member not listed in `PublicAPI.Shipped.txt` as an undeclared addition and fails the build. So the moment a Node imports the fragment, the build breaks until `PublicAPI.Shipped.txt` is populated with the Node's *current* public surface. The fix is the one-time baseline: generate `PublicAPI.Shipped.txt` from the existing surface (the analyzer ships a "add to shipped API" code fix; or `dotnet format`-style generation) and commit it. From that point on, any new public member must be added to `PublicAPI.Unshipped.txt` in the same PR or CI fails — which is exactly ADR-0035 D9 gate 1.

**This is a multi-repo packet** describing one repeated unit of work across the 12 repos in `target_repos`. The `file-work-items` agent files it as a tracking issue in `HoneyDrunk.Architecture` with one child issue per Node, or as 12 sibling issues. The per-repo work is identical in shape and small-to-medium.

## Per-repo work unit (repeated for each of the 12 Node repos)
For each Node repo:
1. **Import the analyzer fragment.** Wire the repo-root `Directory.Build.props` to import the `HoneyDrunk.Standards` public-API-analyzer fragment (packet 01). Match the repo's existing `HoneyDrunk.Standards` consumption mechanism (the same way it consumes the analyzer set and — if the ADR-0034 initiative has already landed in this repo — the packaging-metadata fragment).
2. **Commit the baseline `PublicAPI.Shipped.txt`.** For every packable project (`*.Abstractions`, the default backing, providers, `.AspNetCore`, etc.), generate `PublicAPI.Shipped.txt` populated with the project's **current published public surface** and commit it next to the `.csproj`. Use the `PublicApiAnalyzers` "add to shipped public API" bulk code fix, or the analyzer's documented generation path. The baseline must reflect what is *already published* — do not editorialize the surface; this is a snapshot, not a cleanup.
3. **Add an empty `PublicAPI.Unshipped.txt`.** Commit an empty (or header-only) `PublicAPI.Unshipped.txt` next to each packable `.csproj` so the analyzer's tracked-file pair is complete. Future public-surface additions land here.
4. **Verify the analyzer passes.** After steps 1–3, `dotnet build` must be green — the analyzer sees every public member declared in `Shipped.txt` and raises nothing. A build failure here means the baseline is incomplete; regenerate it.
5. **Audit existing `[Obsolete]` members.** Scan the repo's public surface for `[Obsolete]` attributes. ADR-0035 D6 requires each carry a `DiagnosticId` and a `UrlFormat`. Any existing `[Obsolete]` member missing either must be brought into compliance — add a `DiagnosticId` and a `UrlFormat` pointing to a migration doc in the repo (create the migration doc if absent: name the replacement, show a before/after snippet). If a repo has no `[Obsolete]` members, this step is a no-op — record that.
6. **Wire the API-diff gate.** Amend the repo's release workflow to call `job-api-diff.yml` (packet 03) at a pinned ref before publish. The release workflow first uploads each packable project's `PublicAPI.{Shipped,Unshipped}.txt` pair as the `public-api-surface` GitHub Actions artifact (the decided handoff shape from packet 03), then calls `job-api-diff.yml` passing `package-id`, `version`, `declared-bump`, and `surface-artifact-name: public-api-surface` (the default). The `declared-bump` value is sourced from the release's intended SemVer level (the developer/release process declares it; this packet wires the call, it does not compute the bump).
7. **Confirm the `[Obsolete]`-audit gate is active.** Packet 03 wired the `[Obsolete]`-audit as a job inside `pr-core.yml` Grid-wide — so it is **already active** on every .NET repo. This step is a no-code confirmation: verify the repo's PR pipeline runs the `pr-core.yml` tier-1 gate (it must, per invariant 31) and record that the `[Obsolete]`-audit is therefore in effect. No per-repo audit wiring is added.
8. **Update `repos/{Node}/integration-points.md`** (in `HoneyDrunk.Architecture`) to record that the Node now enforces the ADR-0035 surface gates and which Abstractions package(s) it tracks with `PublicAPI.{Shipped,Unshipped}.txt`.

## Affected Repos
Exactly the 12 package-producing scaffolded .NET Node repos in `target_repos`: Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Observe. **Architecture, Studios, Actions excluded** (these repos ship no NuGet packages); **Standards excluded** (it self-adopts in packet 01). **The 9 AI-sector Seed Nodes excluded** (not yet scaffolded — they fail the inclusion test; adopt at their own standup). **Private revenue Nodes excluded** (not bound by D1–D6 per D8). The list is pinned — do not add Nodes at filing time; the inclusion test is "scaffolded repo currently shipping a public `.Abstractions` package".

## NuGet Dependencies
Per repo, the only `PackageReference` change is transitive through the imported fragment:
- `Microsoft.CodeAnalysis.PublicApiAnalyzers` — declared by the packet-01 fragment with `PrivateAssets="all"`; it becomes an analyzer reference on each packable project when the fragment is imported. The per-repo adoption does not add it by hand — importing the fragment is what brings it in.
- No other package reference is added or removed. `HoneyDrunk.Standards` analyzers remain referenced as before (invariant 26).

This packet adds no new .NET project. `PublicAPI.Shipped.txt`, `PublicAPI.Unshipped.txt`, and any created migration doc are **content** (text/Markdown files), not `PackageReference` entries.

## Boundary Check
- [x] Each repo's `Directory.Build.props`, `PublicAPI.*.txt` baselines, `[Obsolete]` fixes, migration docs, and release/PR workflow live in that repo — correct ownership.
- [x] `repos/{Node}/integration-points.md` edits live in `HoneyDrunk.Architecture` — correct (it is the architecture-side model file).
- [x] No new cross-Node runtime dependency — the fragment carries a build-time analyzer; `Microsoft.CodeAnalysis.PublicApiAnalyzers` is `PrivateAssets="all"`. Invariant 1 (Abstractions packages have zero runtime HoneyDrunk dependencies) is not touched.
- [x] No contract change — committing `PublicAPI.Shipped.txt` is a *snapshot* of the existing surface, not a surface modification. Adding a missing `DiagnosticId`/`UrlFormat` to an existing `[Obsolete]` is an attribute-argument change, not a public-shape change.

## Acceptance Criteria
- [ ] Each of the 12 repos in `target_repos` imports the `HoneyDrunk.Standards` public-API-analyzer fragment in its repo-root `Directory.Build.props`
- [ ] Every packable project in each repo has a `PublicAPI.Shipped.txt` committed next to its `.csproj`, populated with the project's current published public surface, and an empty `PublicAPI.Unshipped.txt`
- [ ] `dotnet build` is green in every repo — the analyzer raises nothing against the committed baseline
- [ ] Every existing `[Obsolete]` member in each repo carries a `DiagnosticId` and a `UrlFormat`; a migration doc exists for each (created where absent); repos with no `[Obsolete]` members record that as a no-op
- [ ] Each repo's release workflow uploads the `public-api-surface` artifact (the `PublicAPI.{Shipped,Unshipped}.txt` pair per packable project) and calls `job-api-diff.yml` at a pinned ref before publish, passing `package-id` / `version` / `declared-bump` / `surface-artifact-name`
- [ ] The `[Obsolete]`-audit gate is confirmed active for each repo via the central `pr-core.yml` tier-1 wiring (packet 03 wired it Grid-wide — no per-repo opt-in); each repo records the confirmation
- [ ] `repos/{Node}/integration-points.md` in `HoneyDrunk.Architecture` records that each Node enforces the ADR-0035 surface gates and which Abstractions package(s) it tracks
- [ ] Each repo's repo-level `CHANGELOG.md` carries an entry for the public-API-surface-tracking adoption; per-package `CHANGELOG.md` entries only for packages with an actual functional change — the analyzer adoption + baseline is a tooling change, a single repo-level entry suffices, no per-package noise (invariant 12/27)
- [ ] The 9 AI-sector Seed Nodes, private revenue Nodes, Architecture, Studios, Actions, and Standards are NOT touched by this fan-out

## Human Prerequisites
- [ ] Confirm the pinned `job-api-diff.yml` ref for all 12 callers.
- [ ] For each repo, confirm the `declared-bump` value the release process supplies — or confirm that the release process declares it at release time (this packet wires the call; it does not encode a fixed bump).
- [ ] Review each Node's generated `PublicAPI.Shipped.txt` baseline before merge — the baseline is the contract of record for that Node's surface; a wrong baseline silently weakens the gate. This is a review step, not a manual authoring step (the agent generates the file).

## Dependencies
- `work-item:01` — the `HoneyDrunk.Standards` public-API-analyzer fragment (**hard** — each repo imports it; it must exist).
- `work-item:03` — `job-api-diff.yml` + the `[Obsolete]`-audit (**hard** — each repo's release/PR pipeline is amended to call them; they must exist).

## Referenced ADR Decisions
**ADR-0035 D9 — Enforcement.** `Microsoft.CodeAnalysis.PublicApiAnalyzers` enabled on every public package; `PublicAPI.Shipped.txt` and `PublicAPI.Unshipped.txt` tracked in-repo; PRs touching the public surface must update `Unshipped.txt`, CI fails if stale. The API-diff job compares the post-build surface to the previous nuget.org version and asserts the diff matches the declared bump. The `[Obsolete]`-audit fails CI on any `[Obsolete]` member without a `DiagnosticId` and `UrlFormat`.

**ADR-0035 Consequences — Affected Nodes.** "Every public Node — gains `PublicAPI.{Shipped,Unshipped}.txt`, the analyzer reference, and a one-time baseline commit at current published version." **Follow-up Work:** "Add `Microsoft.CodeAnalysis.PublicApiAnalyzers` to every public Node's `Directory.Build.props`; one-time baseline commit." (This packet is that fan-out.)

**ADR-0035 D6 — Deprecation window.** Every deprecated member carries `[Obsolete(message, error: false)]` with a `DiagnosticId` and a `UrlFormat` pointing to a migration doc in the Node's repo; the migration doc names the replacement and shows a before/after snippet.

**ADR-0035 D8 — Private packages get a different rule.** `HoneyDrunk.Notify.Cloud.*` and future revenue Nodes are not bound by D1–D6 — they may break consumers at minor versions. They are excluded from this fan-out and adopt their own rule at standup. (Public Abstractions transitively consumed by a private package are still bound — but that is the public Node's own gate, already covered here.)

**ADR-0035 D1 — Pre-1.0 packages.** Every Node except the post-baseline Kernel is currently pre-1.0. Pre-1.0 makes no compatibility promise; the API-diff gate (packet 03) runs the additive check at warning severity for `0.Y` packages. The baseline commit still happens — pre-1.0 status changes the *strictness* of the diff, not whether the surface is tracked.

## Constraints
> **Invariant 12 — Semantic versioning with CHANGELOG and README.** The repo-level `CHANGELOG.md` gets an entry for the surface-tracking adoption.

> **Invariant 27 — All projects in a solution share one version and move together; per-package changelogs updated only for packages with actual changes.** The analyzer adoption + baseline is a tooling change — one repo-level `CHANGELOG.md` entry per repo; no per-package changelog noise for packages whose only change is the imported fragment + a committed `PublicAPI.*.txt` pair. This packet does not push tags / trigger a release (agents never push tags).

> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `Microsoft.CodeAnalysis.PublicApiAnalyzers` is `PrivateAssets="all"` — a build-time Roslyn analyzer, not a runtime dependency — so importing the fragment into an `.Abstractions` project does not violate this.

- **The baseline is a snapshot, not a cleanup.** `PublicAPI.Shipped.txt` must reflect the surface *as currently published*. Do not remove, rename, or "tidy" public members while baselining — that would itself be an undeclared breaking change. If a Node's surface genuinely needs cleanup, that is a separate, deliberate major-bump packet, not this one.
- **Build must be green per repo before the per-repo unit is done.** An incomplete `PublicAPI.Shipped.txt` leaves the analyzer failing — the per-repo unit is not complete until `dotnet build` passes.
- **Pinned 12-repo list** — do not add the 9 AI-sector Seed Nodes, private revenue Nodes, Architecture, Studios, Actions, or Standards. The inclusion test is "scaffolded repo currently shipping a public `.Abstractions` package".
- **No version bump is required by this packet alone** — adopting the analyzer is a build-tooling change. If a repo's release cadence means the next publish carries the change, the CHANGELOG entry rides the existing in-progress version per invariant 27; this packet does not itself trigger a release.

## Labels
`chore`, `tier-2`, `core`, `ops`, `coordination`, `adr-0035`, `wave-3`

## Agent Handoff

**Objective:** Per-Node adoption of ADR-0035 D9 — import the `HoneyDrunk.Standards` public-API-analyzer fragment, commit the one-time `PublicAPI.Shipped.txt` baseline + empty `PublicAPI.Unshipped.txt` for every packable project, bring existing `[Obsolete]` members into D6 compliance, wire `job-api-diff.yml` into each release pipeline, and confirm the `pr-core.yml`-resident `[Obsolete]`-audit is active. One identical work unit across 12 repos.

**Target:** Coordination/tracking issue in `HoneyDrunk.Architecture` with one child issue per Node repo; each child branches from `main` in its own repo. The `integration-points.md` edits land in `HoneyDrunk.Architecture`.

**Context:**
- Goal: Every public Node mechanically enforces ADR-0035's version semantics — surface drift fails CI, a SemVer-inconsistent bump fails the API-diff, a malformed `[Obsolete]` fails the audit.
- Feature: ADR-0035 Abstractions Versioning and Deprecation Policy rollout, Wave 3.
- ADRs: ADR-0035 (D9/D6/D8/D1, Follow-up Work), ADR-0034 (D1 — nuget.org is the API-diff's previous-version source).
- In scope: the 12 package-producing scaffolded .NET Node repos in `target_repos` (Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Observe). Out: the 9 AI-sector Seed Nodes, private revenue Nodes, Architecture, Studios, Actions, Standards.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:01` (hard — the analyzer fragment), `work-item:03` (hard — the API-diff + `[Obsolete]`-audit workflows).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- The `PublicAPI.Shipped.txt` baseline is a snapshot of the *currently published* surface — do not clean up / remove / rename members while baselining.
- `dotnet build` must be green per repo before that repo's unit is done.
- Pinned 12-repo list — no additions. Inclusion test: scaffolded repo shipping a public `.Abstractions` package.
- The `[Obsolete]`-audit is already Grid-wide via `pr-core.yml` (packet 03) — confirm, do not re-wire per repo.
- The API-diff caller uploads the `public-api-surface` artifact then calls `job-api-diff.yml` with `surface-artifact-name`.
- This packet does not push tags / trigger a release.

**Key Files (per repo):**
- repo-root `Directory.Build.props`
- `PublicAPI.Shipped.txt` + `PublicAPI.Unshipped.txt` next to each packable `.csproj` (created)
- migration docs for any non-compliant `[Obsolete]` member (created where absent)
- the repo's release workflow (uploads the `public-api-surface` artifact, calls `job-api-diff.yml`)
- `CHANGELOG.md`
- `repos/{Node}/integration-points.md` (in `HoneyDrunk.Architecture`)

(The `[Obsolete]`-audit needs no per-repo file change — it is resident in `pr-core.yml` Grid-wide from packet 03.)

**Contracts:** No runtime contract change — `PublicAPI.Shipped.txt` snapshots the existing surface; the `[Obsolete]` fixes are attribute-argument changes. Consumes the `HoneyDrunk.Standards` analyzer fragment (packet 01) and the `job-api-diff.yml` `workflow_call` contract + `public-api-surface` artifact handoff (packet 03).
