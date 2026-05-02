---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-3", "ops", "new-node", "scaffolding", "adr-0013", "wave-2"]
dependencies: ["01-architecture-adr-0013-acceptance.md", "02-architecture-create-communications-repo.md"]
adrs: ["ADR-0013"]
wave: 2
initiative: adr-0013-communications-bringup
node: honeydrunk-communications
---

# Feature: Scaffold `HoneyDrunk.Communications` repo, solution, and project skeletons

## Summary
Stand up the `HoneyDrunk.Communications` repo with the Grid's standard solution structure and ship two empty-shell projects — `HoneyDrunk.Communications.Abstractions` and `HoneyDrunk.Communications` — plus repo metadata, editor configuration, and the `pr-core.yml` validate-pr workflow. **No contracts, no runtime logic** in this packet — Phase 1 (packet 04) ships the five seed contracts; Phase 2 (packet 05) ships the welcome flow.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Communications` (new, created by the paired human-only chore)

## Motivation
Phase 1 of the Communications Phase Plan is "Create repo and solution structure" + "Define contracts" + "Wire Kernel integration." We split that into two packets — this scaffold packet (repo + solution + empty projects + CI), and packet 04 (contracts + Kernel wiring + publish workflow). The split keeps PR sizes small and lets the scaffold PR stand alone as a reviewable artifact: "is the solution layout right? is CI green? is package metadata correct?" — separate from "are the contracts right?"

The scaffold PR's tier-1 gate (build, analyzers, secret scan) must pass on an empty solution, proving the foundation is sound before any contract types land.

## Scope

### Repo scaffold

Create the standard Grid repo layout. Use `HoneyDrunk.Notify` as the closest style reference (similar shape — Ops sector, two main packages, one repo).

- `HoneyDrunk.Communications.slnx` at repo root (referencing the two new projects + an empty `tests/` placeholder for future Tests/Canary projects)
- `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj` — empty Abstractions package (no `.cs` files yet beyond `AssemblyInfo` if needed)
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj` — empty runtime package (no `.cs` files yet)
- `tests/` — empty directory with `.gitkeep`, ready for `HoneyDrunk.Communications.Tests` and `HoneyDrunk.Communications.Canary` projects in Phase 1 / Phase 2 (invariant 16 — no test code in runtime packages)
- `.editorconfig` mirroring `HoneyDrunk.Notify/.editorconfig`
- `Directory.Build.props` mirroring `HoneyDrunk.Notify/Directory.Build.props` (sets `<TargetFramework>net10.0</TargetFramework>`, `<LangVersion>latest</LangVersion>`, `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`, `<Nullable>enable</Nullable>`, `<GenerateDocumentationFile>true</GenerateDocumentationFile>`, common package metadata)
- `.gitignore` (the GitHub-init one is fine; verify it covers `bin/`, `obj/`, `*.user`, `.vs/`)
- `README.md` at repo root — one-paragraph purpose, packages list, repo status (Seed). Should mention "tenant-aware orchestration" as part of the one-paragraph purpose so consumers reading the README know multi-tenancy is a first-class design concern (the actual contracts and stores arrive in packets 04 and 05). Do not embed ADR IDs in the narrative text. Do not list "Phase 3" features as if they exist.
- `CHANGELOG.md` at repo root (next to `.slnx`) — initial `0.1.0` entry describing the scaffold (invariant 12, 27 — first packet to land on the solution bumps the version)
- `.github/workflows/pr-core.yml` — consume `HoneyDrunk.Actions/.github/workflows/job-pr-core.yml@main` (or whatever the current canonical reusable validate-pr workflow is named in HoneyDrunk.Actions; check Notify's workflow as the reference)

### `HoneyDrunk.Communications.Abstractions` package metadata

- `<PackageId>HoneyDrunk.Communications.Abstractions</PackageId>`
- `<TargetFramework>net10.0</TargetFramework>`
- `<Nullable>enable</Nullable>`
- `<GenerateDocumentationFile>true</GenerateDocumentationFile>`
- Per-package `README.md` — short description, "no public types yet — Phase 1 (packet 04) adds five seed contracts"
- Per-package `CHANGELOG.md` — `0.1.0` initial scaffold entry
- Zero runtime HoneyDrunk dependencies (invariant 1). Phase 1 will not need any either — pure interfaces.

### `HoneyDrunk.Communications` package metadata

- `<PackageId>HoneyDrunk.Communications</PackageId>`
- `<TargetFramework>net10.0</TargetFramework>`
- `<Nullable>enable</Nullable>`
- `<GenerateDocumentationFile>true</GenerateDocumentationFile>`
- `<ProjectReference Include="..\HoneyDrunk.Communications.Abstractions\HoneyDrunk.Communications.Abstractions.csproj" />` — runtime depends on Abstractions per invariant 2
- Per-package `README.md` — short description, "no public types yet — Phase 1 (packet 04) wires Kernel integration; Phase 2 (packet 05) adds the welcome flow runtime"
- Per-package `CHANGELOG.md` — `0.1.0` initial scaffold entry
- HoneyDrunk dependencies needed at scaffold time: **none beyond Abstractions**. Phase 1 adds `HoneyDrunk.Kernel.Abstractions` and `HoneyDrunk.Kernel`. Phase 2 adds `HoneyDrunk.Notify.Abstractions`.

### `pr-core.yml` workflow

Mirror `HoneyDrunk.Notify/.github/workflows/pr-core.yml`. Triggers on `pull_request` to `main`. Calls the HoneyDrunk.Actions reusable workflow. No customization beyond the Notify pattern.

If Notify's `pr-core.yml` references a specific `HoneyDrunk.Actions` ref/version, mirror that exact ref (do not pin to a different version arbitrarily). The `wave-1` ADR-0009 package-scanning rollout has not yet closed for Communications (it is excluded — Communications does not yet exist for that initiative), so `pr-core.yml` is the only workflow needed in this packet. Additional scan workflows can be added in a follow-up if needed.

## NuGet Dependencies

### `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj`

| Package | Version pin | Notes |
|---|---|---|
| `HoneyDrunk.Standards` | latest published (mirror Notify's pin) | StyleCop + EditorConfig analyzers; `PrivateAssets="all"`. Required on every new .NET project per invariant 26. |

No other PackageReferences. No HoneyDrunk runtime references (invariant 1).

### `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj`

| Package / Project | Version pin | Notes |
|---|---|---|
| `HoneyDrunk.Standards` | latest published (mirror Notify's pin) | Analyzers; `PrivateAssets="all"`. |
| `<ProjectReference Include="..\HoneyDrunk.Communications.Abstractions\..." />` | — | Runtime → Abstractions per invariant 2. |

No HoneyDrunk NuGet references in the scaffold packet. Kernel integration arrives in packet 04.

## Affected Files

- `HoneyDrunk.Communications.slnx` (new)
- `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj` (new)
- `src/HoneyDrunk.Communications.Abstractions/README.md` (new)
- `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md` (new)
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj` (new)
- `src/HoneyDrunk.Communications/README.md` (new)
- `src/HoneyDrunk.Communications/CHANGELOG.md` (new)
- `tests/.gitkeep` (new)
- `.editorconfig` (new — mirror Notify)
- `Directory.Build.props` (new — mirror Notify)
- `.gitignore` (verify GitHub-init one is sufficient; supplement if needed)
- `README.md` (new at repo root)
- `CHANGELOG.md` (new at repo root)
- `.github/workflows/pr-core.yml` (new)

## Boundary Check

- [x] All work is in the new `HoneyDrunk.Communications` repo — no cross-repo edits
- [x] Abstractions has zero runtime HoneyDrunk dependencies (invariant 1) — only `HoneyDrunk.Standards` analyzers (`PrivateAssets="all"`)
- [x] Runtime depends on Abstractions only (invariant 2) — no cross-runtime references at this layer
- [x] No code yet — no contract surface, no concrete implementations. Empty projects with metadata only.
- [x] No Azure resources, no secrets, no provider-specific code

## Acceptance Criteria

- [ ] `HoneyDrunk.Communications.slnx` exists at repo root and includes both projects + the `tests/` folder placeholder
- [ ] `src/HoneyDrunk.Communications.Abstractions/` project created, builds clean, targets `.NET 10.0`, `Nullable enable`, `GenerateDocumentationFile true`
- [ ] `src/HoneyDrunk.Communications/` project created, builds clean, targets `.NET 10.0`, references Abstractions only
- [ ] Both projects reference `HoneyDrunk.Standards` with `PrivateAssets="all"` (invariant 26)
- [ ] Zero runtime HoneyDrunk package references on the Abstractions project (invariant 1)
- [ ] No HoneyDrunk runtime references on the Communications runtime project either at this packet (Kernel comes in packet 04)
- [ ] Repo-level `README.md` at root describes the Node's purpose, lists the two packages, marks status as Seed, links to the canonical Node entry in the public catalog
- [ ] Repo-level `CHANGELOG.md` at root with `0.1.0` initial entry (invariant 12, 27 — first bump for the solution)
- [ ] Per-package `README.md` and `CHANGELOG.md` present in `src/HoneyDrunk.Communications.Abstractions/` and `src/HoneyDrunk.Communications/` (invariant 12)
- [ ] `.editorconfig` and `Directory.Build.props` present at repo root and mirror `HoneyDrunk.Notify`'s versions
- [ ] `tests/.gitkeep` present (invariant 16 — placeholder for future test projects)
- [ ] `.github/workflows/pr-core.yml` present, consuming the reusable validate-pr workflow from `HoneyDrunk.Actions` (mirror Notify's invocation)
- [ ] PR traverses the tier-1 gate (build, analyzers, vuln scan, secret scan) and merges
- [ ] PR body links back to this packet (invariant 32)
- [ ] No public types defined in either project — that is intentional and explicit in the per-package READMEs
- [ ] No ADR IDs in narrative body of the repo `README.md` (per user preference; ADR ID allowed in `CHANGELOG.md` entries since those are metadata)

## Human Prerequisites

- [ ] `HoneyDrunkStudios/HoneyDrunk.Communications` repo must exist (created by the paired `02-architecture-create-communications-repo.md` chore)
- [ ] `HoneyDrunk.Standards` NuGet package must be resolvable by the target repo's CI (it is — every Grid repo references it)

## Dependencies

- `01-architecture-adr-0013-acceptance.md` — context folder must exist before scaffold ships (the scaffold PR's review agent reads `repos/HoneyDrunk.Communications/boundaries.md` and `invariants.md`)
- `02-architecture-create-communications-repo.md` — target repo must exist on GitHub

## Downstream Unblocks

- `04-communications-phase1-contracts.md` — Phase 1 contracts ride on this scaffold's empty projects
- `05-communications-phase2-welcome-flow.md` — Phase 2 welcome flow rides on Phase 1 contracts

## Referenced ADR Decisions

**ADR-0013 (Communications Orchestration Layer — HoneyDrunk.Communications):**
- **§Phase Plan / Phase 1:** "Create repo and solution structure" — exactly the scope of this packet. The contracts and Kernel wiring listed in the same Phase 1 section ship in packet 04, not here.
- **§Decision / New Node:** Two packages — `HoneyDrunk.Communications.Abstractions` (contracts) and `HoneyDrunk.Communications` (runtime). This packet stands up both as empty shells.
- **§Sector:** Ops.

## Referenced Invariants

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer. `HoneyDrunk.Communications` (runtime) depends on `HoneyDrunk.Communications.Abstractions`. Phase 2 will add `HoneyDrunk.Notify.Abstractions` (Notify's contracts package) — never `HoneyDrunk.Notify` runtime.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level `CHANGELOG.md` (next to the `.slnx` file) is mandatory; every version that ships must have an entry. Every package directory must contain a `README.md` describing the package's purpose, installation, and public API surface. New projects must have both files from the first commit.

> **Invariant 13:** All public APIs have XML documentation. Enforced by `HoneyDrunk.Standards` analyzers. *(No public APIs yet in this packet, but `<GenerateDocumentationFile>true</GenerateDocumentationFile>` is set so analyzers fire when contracts arrive in packet 04.)*

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only. *(Empty `tests/` directory placeholder honors this; Phase 1 / Phase 2 will populate.)*

> **Invariant 26:** Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section. `HoneyDrunk.Standards` must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`).

> **Invariant 27:** All projects in a solution share one version and move together. Both projects start at `0.1.0` in this scaffold packet — the first packet to land on the solution bumps the version. Subsequent packets in this initiative (04, 05) will bump both projects together (to `0.2.0` for Phase 1 contracts, `0.3.0` for Phase 2 welcome flow).

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. *(This packet is what wires that gate up for Communications.)*

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link.

## Constraints

- **Empty projects only.** No public types in either project. Resist any temptation to "stub out" the five contracts here — that is packet 04's job. The scaffold PR exists to prove the build and CI plumbing works on a clean slate.
- **Mirror Notify configurations exactly.** `.editorconfig`, `Directory.Build.props`, and `pr-core.yml` are copy-paste from Notify with the project names changed where appropriate. Do not invent new conventions.
- **Both projects start at `0.1.0`.** Per invariant 27, the first packet to land on a solution bumps the version. Both projects move together; both start at `0.1.0`.
- **No ADR IDs in repo `README.md` narrative body.** ADR IDs are fine in `CHANGELOG.md` entries (those are metadata). Per user preference, narrative prose stays free of ADR ID strings.
- **No Azure resources.** This is NuGet-only at scaffold time. Vault, App Configuration, OIDC federated credentials are not needed and must not be invented. Phase 3 (separate initiative) will provision Azure when Communications has runtime secrets and a deploy target.
- **`pr-core.yml` only.** No publish workflow, no deploy workflow, no scan workflows beyond what `pr-core.yml` already includes. Publish workflow ships in packet 04 (when there is an Abstractions package worth publishing). Deploy workflow is Phase 3.
- **Naming rule discipline (Grid-wide).** No public types are added in this packet, but the README forward-references future contracts — make sure those references use `I`-prefixed interface names and non-`I`-prefixed record names per the Grid-wide naming rule. Records to be introduced in Phase 1/2 (e.g., `MessageDecision`, `RecipientHandle`) must NOT carry the `I` prefix; the five seed contracts (all interfaces) all KEEP the `I` prefix.

## Labels
`feature`, `tier-3`, `ops`, `new-node`, `scaffolding`, `adr-0013`, `wave-2`

## Agent Handoff

**Objective:** Scaffold `HoneyDrunk.Communications` as a clean two-project solution with repo metadata, editor config, and the validate-pr workflow — no contracts, no runtime logic. The PR proves the build+CI plumbing on an empty solution, anchoring all subsequent contract and runtime packets.

**Target:** HoneyDrunk.Communications, branch from `main`

**Context:**
- Goal: Stand up the new repo's foundation so Phase 1 contracts (packet 04) and Phase 2 welcome flow (packet 05) have a clean home
- Feature: ADR-0013 Phase 1 — repo and solution structure
- ADRs: ADR-0013 (primary)

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `01-architecture-adr-0013-acceptance.md` (merged) — repo context folder exists in the Architecture repo
- `02-architecture-create-communications-repo.md` (closed) — target repo exists on GitHub

**Constraints:**

> **Invariant 1:** Abstractions packages have zero runtime dependencies on other HoneyDrunk packages. Only `Microsoft.Extensions.*` abstractions are permitted.

> **Invariant 2:** Runtime packages depend on Abstractions, never on other runtime packages at the same layer.

> **Invariant 11:** One repo per Node (or tightly coupled Node family).

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level `CHANGELOG.md` mandatory; per-package `README.md` and `CHANGELOG.md` mandatory from first commit.

> **Invariant 16:** No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only.

> **Invariant 26:** `HoneyDrunk.Standards` must be explicitly listed on every new .NET project (`PrivateAssets: all`).

> **Invariant 27:** All projects in a solution share one version and move together. Starting version `0.1.0` (this scaffold packet is the bumping packet for the new solution).

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. `pr-core.yml` is what wires that gate.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

- Empty projects only — no public types in either project
- Mirror Notify's `.editorconfig`, `Directory.Build.props`, `pr-core.yml`
- No Azure resources, no scan/publish/deploy workflows beyond `pr-core.yml`
- No ADR IDs in repo `README.md` narrative body
- Records to be added later drop the `I` prefix; interfaces keep it (Grid-wide naming rule)

**Key Files:**
- `HoneyDrunk.Communications.slnx` (new)
- `src/HoneyDrunk.Communications.Abstractions/HoneyDrunk.Communications.Abstractions.csproj` (new)
- `src/HoneyDrunk.Communications.Abstractions/README.md` (new)
- `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md` (new)
- `src/HoneyDrunk.Communications/HoneyDrunk.Communications.csproj` (new)
- `src/HoneyDrunk.Communications/README.md` (new)
- `src/HoneyDrunk.Communications/CHANGELOG.md` (new)
- `tests/.gitkeep` (new)
- `.editorconfig` (new — mirror Notify)
- `Directory.Build.props` (new — mirror Notify)
- `README.md` (new at repo root)
- `CHANGELOG.md` (new at repo root)
- `.github/workflows/pr-core.yml` (new — mirror Notify's)

**Contracts:** None. Contracts ship in packet 04.
