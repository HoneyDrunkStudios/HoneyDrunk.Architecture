---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0047", "wave-3"]
dependencies: ["packet:06"]
adrs: ["ADR-0047", "ADR-0011"]
accepts: ["ADR-0047"]
wave: 3
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-actions
---

# Author `job-integration-tests-containers.yml` (Tier 2b) reusable workflow

## Summary
Add a new reusable workflow `job-integration-tests-containers.yml` in `HoneyDrunk.Actions` that runs Tier 2b container-backed integration tests (`dotnet test --filter "FullyQualifiedName~Tests.Integration.Containers"`) on a Docker-capable runner, with container-layer caching, parallel with the Tier 2a job. This completes ADR-0047 D11's CI surface for the integration tiers.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0047 D11 commits Tier 2b to "`job-integration-tests-containers.yml`; requires Docker; parallel with 2a", and D14 Phase 3 schedules it: "Author `job-integration-tests-containers.yml` (Tier 2b)." Tier 2b is the scoped exception to invariant 15 — it runs real-process dependencies (Postgres, Cosmos emulator, Service Bus emulator, Azurite) via Testcontainers.NET. Those tests cannot run in `job-integration-tests.yml` (packet 06) because that workflow's filter explicitly excludes `*.Tests.Integration.Containers` and Tier 2b needs a Docker-capable runner. This packet ships the dedicated Tier 2b workflow.

This packet ships the workflow only. It does **not** wire it into `pr-core.yml` Grid-wide and it does **not** add any Tier 2b test project — the pilot adoptions are packets 10 (Data) and 11 (Kernel). Per ADR-0047 D14 Phase 3, Tier 2b starts as a piloted, opt-in tier, unlike Tier 2a's safe Grid-wide wiring.

## Proposed Change
Create `.github/workflows/job-integration-tests-containers.yml` following the `job-*.yml` reusable-workflow conventions.

### Workflow shape
- `workflow_call` with inputs mirroring `job-integration-tests.yml` (packet 06): `dotnet-version`, `runs-on` (default `ubuntu-latest` — Docker is available on GitHub-hosted `ubuntu-latest`), `working-directory`, `project-path`.
- Steps: checkout, `actions/setup-dotnet`, restore, build `--configuration Release`, then `dotnet test --filter "FullyQualifiedName~Tests.Integration.Containers" --configuration Release`.
- **Docker requirement:** the workflow documents in its header that it requires a Docker-capable runner; `ubuntu-latest` GitHub-hosted runners have Docker preinstalled. If a caller passes a self-hosted `runs-on`, that runner must have Docker — document this in the header contract.
- **Container-layer caching:** add a step that caches Docker layers across runs to mitigate the ADR-0047 Consequences cost note ("Docker image pulls and container startup add ~30–60s per integration test job. Mitigated by layer caching in CI"). Use `docker/setup-buildx-action` + a cache, or the runner's image cache mechanism — pick whichever the existing `HoneyDrunk.Actions` workflows precedent supports; if there is no precedent, use `actions/cache` keyed on the test project's Testcontainers module versions.
- **No-op-safe:** if the repo has zero `*.Tests.Integration.Containers` projects, the filtered `dotnet test` is a passing no-op (same guard logic as packet 06).
- Runtime budget per ADR-0047 D1: Tier 2b suite target `< 10min`.
- Header comment block documents the tier, the Docker requirement, the filter contract, and the no-op behavior.

### Wiring
Per ADR-0047 D14 Phase 3, Tier 2b is piloted, not wired Grid-wide in this packet. Do **not** add this job to `pr-core.yml` here. The pilot packets (10, 11) wire it into their Node's caller workflow. After the pilot succeeds, a follow-up (outside this initiative) may wire it Grid-wide.

## Consumer Impact
- No consumer impact until a repo adds a `*.Tests.Integration.Containers` project and wires the job in (pilot packets 10, 11).

## Breaking Change?
- [x] No — new workflow, not wired Grid-wide; opt-in per Node.

## NuGet Dependencies
None. The workflow invokes `dotnet test`; no project-level `<PackageReference>` is added by this packet. The Testcontainers packages are added by the pilot packets (10, 11) in their respective test projects.

## Boundary Check
- [x] All edits in `HoneyDrunk.Actions`. Routing rule "workflow, CI, GitHub Actions → HoneyDrunk.Actions" maps exactly.
- [x] No code change in any consuming repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `.github/workflows/job-integration-tests-containers.yml` exists, `workflow_call`-exposed, with the inputs and steps above
- [ ] The `dotnet test` filter selects `*.Tests.Integration.Containers` only
- [ ] The workflow runs on a Docker-capable runner (`ubuntu-latest` default) and documents the Docker requirement in its header
- [ ] A Docker-layer caching step is present to mitigate container-startup cost
- [ ] The job is a passing no-op in a repo with zero `*.Tests.Integration.Containers` projects
- [ ] The workflow is **not** wired into `pr-core.yml` in this packet
- [ ] Header comment documents the tier, the Docker requirement, the filter contract, the no-op behavior
- [ ] `docs/CHANGELOG.md` updated; `docs/consumer-usage.md` updated to document the Tier 2b workflow and its Docker requirement
- [ ] `README.md` workflow-list section updated if one exists
- [ ] `.github/workflows/job-integration-tests-containers.yml` lints clean under `actionlint`

## Human Prerequisites
None. (GitHub-hosted `ubuntu-latest` runners include Docker; no portal provisioning. If the Studio later moves Tier 2b to self-hosted runners, Docker install on those runners becomes a human prerequisite at that time — out of scope here.)

## Referenced ADR Decisions
**ADR-0047 D1 — Tier 2b.** Integration — with real dependencies: same scope as Tier 2a, but external boundaries use Testcontainers for real-process dependencies (Postgres, Service Bus emulator, Cosmos emulator). Runtime budget `< 10s` per test, suite `< 10min`. Run every PR, parallel with 2a.

**ADR-0047 D4 — Tier 2b is Testcontainers.NET.** Ephemeral real-process dependencies; containers spun up per test class via `IAsyncLifetime`; deterministic teardown. Project naming `*.Tests.Integration.Containers`. "CI executes each project in a separate job; Tier 2b jobs explicitly request `runs-on: ubuntu-latest` (or a self-hosted runner with Docker) and cache container layers across runs."

**ADR-0047 D11 — CI integration.** Tier 2b: `dotnet test --filter "FullyQualifiedName~Tests.Integration.Containers"` in `job-integration-tests-containers.yml`; requires Docker; parallel with 2a; blocking branch-protection check.

**ADR-0047 D14 Phase 3.** "Author `job-integration-tests-containers.yml` (Tier 2b). Pilot on HoneyDrunk.Data … and HoneyDrunk.Kernel."

## Referenced Invariants
> **Invariant 15 (amended) — Unit tests and in-process integration tests never depend on external services; use InMemory providers for isolation. Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception, allowed because they are local, ephemeral, and deterministic.** *(This workflow is the CI home of that scoped exception — Testcontainers dependencies are local, ephemeral, single-tenant to the test process, and deterministic, which is why Tier 2b is permitted.)*

## Constraints
- **Filter selects `*.Tests.Integration.Containers` only.** Tier 2a (`*.Tests.Integration`) has its own workflow (packet 06).
- **Do not wire into `pr-core.yml` Grid-wide.** Tier 2b is piloted first (packets 10, 11) per ADR-0047 D14 Phase 3.
- **No-op-safe** in repos without a `*.Tests.Integration.Containers` project.
- **Container-layer caching is required** — the ADR's cost mitigation depends on it.
- **Reusable workflow lives in HoneyDrunk.Actions** per ADR-0012.

## Labels
`feature`, `tier-2`, `ci-cd`, `ops`, `adr-0047`, `wave-3`

## Agent Handoff

**Objective:** Ship `job-integration-tests-containers.yml` (Tier 2b) as a reusable workflow in `HoneyDrunk.Actions` — Docker-capable runner, container-layer caching, no-op-safe — without wiring it into `pr-core.yml` Grid-wide.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Provide the CI home for Tier 2b Testcontainers-backed integration tests; pilot packets (Data, Kernel) wire it in.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 3.
- ADRs: ADR-0047 (D1, D4, D11, D14 Phase 3), ADR-0012 (reusable workflows live in Actions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:06 — `job-integration-tests.yml` (Tier 2a) establishes the integration-test workflow pattern this packet mirrors; sequence after 06.

**Constraints:**
- Filter selects `*.Tests.Integration.Containers` only.
- Not wired into `pr-core.yml` Grid-wide — piloted via packets 10, 11.
- No-op-safe; container-layer caching required.

**Key Files:**
- `.github/workflows/job-integration-tests-containers.yml` (new)
- `.github/workflows/job-integration-tests.yml` (packet 06 — style + filter reference)
- `docs/CHANGELOG.md`, `docs/consumer-usage.md`, `README.md`

**Contracts:** None changed.
