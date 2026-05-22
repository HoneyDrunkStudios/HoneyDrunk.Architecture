---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
target_repos: ["HoneyDrunk.Kernel", "HoneyDrunk.Transport", "HoneyDrunk.Vault", "HoneyDrunk.Vault.Rotation", "HoneyDrunk.Auth", "HoneyDrunk.Web.Rest", "HoneyDrunk.Data", "HoneyDrunk.Audit", "HoneyDrunk.Pulse", "HoneyDrunk.Notify", "HoneyDrunk.Communications"]
labels: ["chore", "tier-2", "core", "ops", "coordination", "adr-0034", "wave-3"]
dependencies: ["packet:02", "packet:03"]
adrs: ["ADR-0034"]
accepts: ["ADR-0034"]
wave: 3
initiative: adr-0034-public-package-distribution
node: honeydrunk-architecture
---

# Adopt the packaging-metadata fragment + the job-publish-nuget.yml workflow across all public Nodes (ADR-0034 D3/D4/D6)

## Summary
Roll the ADR-0034 packaging conventions out to every public package-producing Node: import the shared `Directory.Build.props` packaging-metadata + SourceLink fragment from `HoneyDrunk.Standards` (packet 02), supply the three per-project metadata overrides and the Node-level metadata slots, ensure every package directory has a `README.md` packed into the nupkg, and amend each Node's release workflow to call `job-publish-nuget.yml` (packet 03) instead of any inline `dotnet nuget push`.

## Repo-list reconciliation (read this before filing)
ADR-0034's Affected Nodes section says "All public Nodes." This packet's fan-out is the **package-producing** subset. The membership test for the fan-out is concrete: a repo is in if it is **scaffolded** (a real repo with buildable .NET projects) **and package-producing** (it ships at least one `.nupkg`). It is *not* gated on a `Live` signal in `catalogs/nodes.json`.

- **`HoneyDrunk.Architecture`**, **`HoneyDrunk.Studios`**, and **`HoneyDrunk.Actions`** are excluded — none of the three ships any NuGet package. This is a known fact about what each repo produces: Architecture is docs/catalogs, Studios is a Next.js site, Actions ships reusable GitHub workflows. (There is no `packages` field in `catalogs/nodes.json` to cite — exclusion is by what the repo actually produces, confirmed against `catalogs/relationships.json` `exposes` and `catalogs/contracts.json`, neither of which lists a package for these three.)
- **`HoneyDrunk.Standards`** is excluded from *this* fan-out — it adopts its own fragment as part of authoring it (packet 02 ships the fragment and `HoneyDrunk.Standards`'s own packable analyzer/build-asset packages adopt it in that packet). Do not double-apply here.
- **`HoneyDrunk.Audit`** *is* included. Audit carries `signal: "Seed"` in `catalogs/nodes.json` (id `honeydrunk-audit`) — it is **not** a Live Node. But it **is** scaffolded and package-producing: the ADR-0030/0031 standup stood up the repo with buildable `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data` projects. Fan-out membership is the scaffolded-and-package-producing test, not the Live signal — Audit passes it, so it is in. No "drop at filing time" escape hatch applies: Audit is a fixed member of the pinned list.
- **`HoneyDrunk.Vault.Rotation`** is included — it ships `HoneyDrunk.Vault.Rotation`.

That leaves the **11 package-producing .NET Node repos** enumerated in `target_repos`. **Seed Nodes** (AI, Capabilities, Operator, Agents, Memory, Knowledge, Flow, Evals, Sim, Observe) are explicitly OUT — they are not yet scaffolded as package-producing repos; per ADR-0034 they adopt the conventions "as they scaffold," which is each Seed Node's own standup-ADR work, not a silent addition here. **Private revenue Nodes** (`HoneyDrunk.Notify.Cloud`, ADR-0027 — not yet scaffolded) are OUT: they publish to GitHub Packages (`feed: github-packages-private`) per ADR-0034 D2 and adopt the conventions in their own standup.

## Context
ADR-0034 D3/D4 commit every public package to a fixed metadata block + SourceLink + deterministic builds; D6 commits publish to the `job-publish-nuget.yml` reusable workflow. Packet 02 authored the shared `HoneyDrunk.Standards` fragment that carries the D3/D4 block and the build-failing metadata-enforcement target; packet 03 authored `job-publish-nuget.yml`. This packet is the per-Node adoption — the work ADR-0034 Follow-up Work names as "Roll out `Directory.Build.props` updates to all 12 live Nodes (one packet per repo; scope agent)" plus the D6 release-workflow amendment ("Existing Node release workflows are amended in a discrete follow-up rollout to call this reusable workflow").

**This is a multi-repo packet** describing one repeated unit of work across the 11 repos in `target_repos`. The `file-packets` agent files it as a tracking issue in `HoneyDrunk.Architecture` with one child issue per Node, or as 11 sibling issues. The per-repo work is identical in shape and small-to-medium.

## Per-repo work unit (repeated for each of the 11 Node repos)
For each Node repo:
1. **Import the metadata fragment.** Wire the repo-root `Directory.Build.props` to import the `HoneyDrunk.Standards` packaging-metadata + SourceLink fragment (packet 02). Match the repo's existing `HoneyDrunk.Standards` consumption mechanism (the same way it consumes the analyzer set).
2. **Supply the Node-level metadata slots.** Set the per-repo values the fragment leaves as slots: `RepositoryUrl` (the canonical GitHub URL for this repo), `PackageProjectUrl`, and — if the Node is on a non-default license — `PackageLicenseExpression` (default is `MIT` per ADR-0039; only override for a revenue/FSL Node, which none in this fan-out are).
3. **Per-project overrides.** For each packable project (`*.Abstractions`, the default backing, providers, `.AspNetCore`, etc.), set the three D3-permitted overrides: `PackageId`, `Description` (one paragraph), `PackageTags` (minimum: `honeydrunk`, the sector tag, the slot kind — `abstractions` / `backing` / `sdk`).
4. **Per-package README.** Ensure every packable package directory has a `README.md` (invariant 12 already requires this) and that `PackageReadmeFile` resolves to it so it is packed into the nupkg. Create the README if a package directory is missing one — describe purpose, installation (`dotnet add package <id>`), and public API surface.
5. **Verify the metadata-enforcement target passes.** The packet-02 build-failing target fails the build if any required D3 field is empty. After steps 1–4, `dotnet build` / `dotnet pack` must be green.
6. **Amend the release workflow.** Replace any inline `dotnet nuget push` in the repo's release workflow with a call to `job-publish-nuget.yml` (packet 03) at a pinned ref, passing `package-id`, `version`, and `feed`. `feed` is a `catalogs/package-feeds.json` feed-id — `nuget-org-public` for stable releases and `azure-artifacts-prerelease` for pre-release (`-preview.N` / `-rc.N`) per ADR-0034 D1. After this, no `dotnet nuget push` remains anywhere in the repo.
7. **Update `repos/{Node}/integration-points.md`** (in `HoneyDrunk.Architecture`) to record the Node's published feed — ADR-0034 Follow-up Work: "Update `repos/{name}/integration-points.md` for each Node with its published feed."

## Affected Repos
Exactly the 11 package-producing .NET Node repos in `target_repos`: Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications. **Architecture, Studios, Actions, Standards excluded** — Architecture/Studios/Actions ship no NuGet package at all (Architecture is docs/catalogs, Studios is a Next.js site, Actions ships reusable workflows); Standards self-adopts in packet 02. **Seed Nodes and private revenue Nodes excluded** (adopt at their own standup). The list is pinned and fixed — do not add or drop Nodes at filing time (Audit is `signal: Seed` but scaffolded and package-producing, so it is a permanent member, not a filing-time conditional).

## NuGet Dependencies
Per repo, the only `PackageReference` change is transitive through the imported fragment:
- `Microsoft.SourceLink.GitHub` — declared by the packet-02 fragment with `PrivateAssets="all"`; it becomes a reference on each packable project in the repo when the fragment is imported. The per-repo adoption does not add it by hand — importing the fragment is what brings it in.
- No other package reference is added or removed. `HoneyDrunk.Standards` analyzers remain referenced as before (invariant 26).

This packet adds no new .NET project. If a packable project in any repo lacks a `README.md`, one is **created** (a Markdown file, not a project) so `PackageReadmeFile` resolves — that is content, not a `PackageReference`.

## Boundary Check
- [x] Each repo's `Directory.Build.props`, per-project overrides, package READMEs, and release workflow live in that repo — correct ownership.
- [x] `repos/{Node}/integration-points.md` edits live in `HoneyDrunk.Architecture` — correct (it is the architecture-side model file).
- [x] No new cross-Node runtime dependency — the fragment is build tooling; `Microsoft.SourceLink.GitHub` is `PrivateAssets="all"` (build-time only, not a runtime dependency, so invariant 1 — Abstractions packages have zero runtime HoneyDrunk dependencies — is not touched).
- [x] No contract change — packaging metadata, not interface shape.

## Acceptance Criteria
- [ ] Each of the 11 repos in `target_repos` imports the `HoneyDrunk.Standards` packaging-metadata + SourceLink fragment in its repo-root `Directory.Build.props`
- [ ] Each repo supplies its Node-level metadata slots (`RepositoryUrl`, `PackageProjectUrl`); `PackageLicenseExpression` is `MIT` (none in this fan-out is a revenue/FSL Node)
- [ ] Every packable project in each repo sets `PackageId`, `Description`, and `PackageTags` (minimum `honeydrunk` + sector tag + slot kind)
- [ ] Every packable package directory has a `README.md` and `PackageReadmeFile` resolves to it — the README is packed into the nupkg
- [ ] The packet-02 metadata-enforcement target passes — `dotnet build` / `dotnet pack` green in every repo with no empty required D3 field
- [ ] SourceLink + `.snupkg` symbol packages are produced for every packable project (ADR-0034 D4 — verifiable in the pack output)
- [ ] Each repo's release workflow calls `job-publish-nuget.yml` at a pinned ref; **no `dotnet nuget push` remains** in any of the 11 repos
- [ ] `repos/{Node}/integration-points.md` in `HoneyDrunk.Architecture` records each Node's published feed (`nuget-org-public`, with pre-release via `azure-artifacts-prerelease`)
- [ ] Each repo's repo-level `CHANGELOG.md` carries an entry for the packaging-metadata/SourceLink adoption; per-package `CHANGELOG.md` entries only for packages with an actual functional change (the metadata adoption alone is a tooling change — a single repo-level entry suffices, no per-package noise per invariant 12/27)
- [ ] Seed Nodes, private revenue Nodes, Architecture, Studios, Actions, and Standards are NOT touched by this fan-out

## Human Prerequisites
- [ ] Packet 03's Human Prerequisites must be complete — the `HoneyDrunkStudios` nuget.org account claimed, the API key seeded in Vault, and the federated-OIDC trust configured — before any repo's amended release workflow can actually publish. (The workflow can be wired before that, but a publish run needs the credentials.)
- [ ] Confirm the pinned `job-publish-nuget.yml` ref for all 11 callers.
- [ ] Confirm the canonical `RepositoryUrl` / `PackageProjectUrl` for each of the 11 repos if not derivable.

## Dependencies
- `packet:02` — the `HoneyDrunk.Standards` packaging-metadata + SourceLink fragment (**hard** — each repo imports it; it must exist).
- `packet:03` — `job-publish-nuget.yml` (**hard** — each repo's release workflow is amended to call it; it must exist).

## Referenced ADR Decisions
**ADR-0034 D3 — Package identity.** Thirteen required metadata fields, CI-enforced; `Directory.Build.props` at the repo root is the enforcement point; per-project overrides limited to `PackageId`, `Description`, `PackageTags`. Public package naming: `HoneyDrunk.<Node>[.<Slot>]`. `PackageTags` minimum: `honeydrunk`, the sector tag, the slot kind.

**ADR-0034 D4 — SourceLink and deterministic builds.** Every public package enables SourceLink + symbols + deterministic builds; `.snupkg` symbol packages publish alongside. Non-negotiable.

**ADR-0034 D6 — Release workflow factoring.** Existing Node release workflows are amended in a discrete follow-up rollout to call `job-publish-nuget.yml` rather than running `dotnet nuget push` inline. (This packet is that rollout.)

**ADR-0034 D1 — Primary feed.** Stable versions publish to nuget.org; pre-release (`-preview.N` / `-rc.N`) transit Azure Artifacts first.

**ADR-0034 Follow-up Work.** "Roll out `Directory.Build.props` updates to all 12 live Nodes (one packet per repo; scope agent)." "Update `repos/{name}/integration-points.md` for each Node with its published feed."

**ADR-0034 — alternative rejected: "One package per repo."** Rejected — per-slot package identity is non-negotiable so external consumers can take `HoneyDrunk.<Node>.Abstractions` without dragging in a default backing. So every packable project — Abstractions, backing, providers — gets its own `PackageId`, not one per repo.

## Constraints
> **Invariant 12 — Semantic versioning with CHANGELOG and README.** Every package directory must contain a `README.md`. This packet ensures `PackageReadmeFile` resolves to it and packs it into the nupkg. Create the README where one is missing.

> **Invariant 27 — All projects in a solution share one version and move together; per-package changelogs updated only for packages with actual changes.** The metadata adoption is a tooling change — record it as one repo-level `CHANGELOG.md` entry per repo; do not add per-package changelog noise for packages whose only change is the imported fragment.

> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `Microsoft.SourceLink.GitHub` is `PrivateAssets="all"` — a build-time source-indexer, not a runtime dependency — so importing the fragment into an `.Abstractions` project does not violate this.

- **No `dotnet nuget push` may remain** in any of the 11 repos after the fan-out — that is the ADR-0034 D6 invariant (added by packet 00).
- **Per-slot package identity** — every packable project gets its own `PackageId`; do not collapse a repo to one package.
- **Pinned 11-repo list** — do not add Seed Nodes, private revenue Nodes, Architecture, Studios, Actions, or Standards.
- **No version bump is required by this packet alone** — adopting the metadata fragment is a build-tooling change. If a repo's release cadence means the next publish carries the change, the CHANGELOG entry rides the existing in-progress version per invariant 27; this packet does not itself trigger a release (agents never push tags — invariant 27).

## Labels
`chore`, `tier-2`, `core`, `ops`, `coordination`, `adr-0034`, `wave-3`

## Agent Handoff

**Objective:** Per-Node adoption of ADR-0034 D3/D4/D6 — import the `HoneyDrunk.Standards` packaging-metadata + SourceLink fragment, set the per-project + Node-level metadata, ensure per-package READMEs are packed, and amend each release workflow to call `job-publish-nuget.yml`. One identical work unit across 11 repos.

**Target:** Coordination/tracking issue in `HoneyDrunk.Architecture` with one child issue per Node repo; each child branches from `main` in its own repo. The `integration-points.md` edits land in `HoneyDrunk.Architecture`.

**Context:**
- Goal: Every public package ships consistent metadata + SourceLink + symbols and publishes through the one control-plane workflow.
- Feature: ADR-0034 Public Package Distribution rollout, Wave 3.
- ADRs: ADR-0034 (D3/D4/D6/D1, Follow-up Work), ADR-0039 (MIT default license).
- In scope: the 11 package-producing .NET Node repos in `target_repos`. Out: Seed Nodes, private revenue Nodes, Architecture, Studios, Actions, Standards.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` (hard — the fragment), `packet:03` (hard — the publish workflow).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- No `dotnet nuget push` may remain in any of the 11 repos.
- Per-slot package identity — every packable project gets its own `PackageId`.
- Pinned 11-repo list — no additions.
- This packet does not push tags / trigger a release.

**Key Files (per repo):**
- repo-root `Directory.Build.props`
- per-project `.csproj` files (the three metadata overrides)
- per-package `README.md` (created where missing)
- the repo's release workflow
- `CHANGELOG.md`
- `repos/{Node}/integration-points.md` (in `HoneyDrunk.Architecture`)

**Contracts:** No runtime contract change — packaging metadata only. Consumes the `HoneyDrunk.Standards` packaging fragment (packet 02) and the `job-publish-nuget.yml` `workflow_call` contract (packet 03).
