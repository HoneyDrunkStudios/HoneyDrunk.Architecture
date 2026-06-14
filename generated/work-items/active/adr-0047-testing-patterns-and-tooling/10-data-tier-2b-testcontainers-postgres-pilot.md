---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["feature", "tier-2", "core", "adr-0047", "wave-3"]
dependencies: ["work-item:01", "work-item:09"]
adrs: ["ADR-0047"]
accepts: ["ADR-0047"]
wave: 3
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-data
---

# Pilot Tier 2b — add `HoneyDrunk.Data.Tests.Integration.Containers` with Testcontainers Postgres

## Summary
Stand up the Grid's first Tier 2b integration-test project — `HoneyDrunk.Data.Tests.Integration.Containers` — using Testcontainers.NET to run a real Postgres container, validating `HoneyDrunk.Data`'s repository / unit-of-work / outbox-store / migration behavior against a real database, and wire the `job-integration-tests-containers.yml` workflow (packet 09) into Data's caller workflow.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Data`

## Motivation
ADR-0047 D14 Phase 3: "Pilot on `HoneyDrunk.Data` (Testcontainers Postgres is the natural fit)." ADR-0047 D4 names the exact case Tier 2b exists for: "does our Postgres migration actually run?" — a question InMemory fakes (Tier 2a) cannot answer. `HoneyDrunk.Data` owns EF Core, SQL/Postgres data access, the outbox store, and migrations (per the routing keyword map). Those are precisely the behaviors whose correctness depends on the real database engine. Piloting Tier 2b here proves the Testcontainers pattern on the Node where it earns its keep most clearly.

## Proposed Implementation
1. Create `tests/HoneyDrunk.Data.Tests.Integration.Containers/` per ADR-0047 D10 project layout.
2. Adopt the shared test-stack props fragment from packet 01 (xUnit + NSubstitute + AwesomeAssertions + coverlet).
3. Add Testcontainers: a Postgres container spun up per test class via `IAsyncLifetime` (ADR-0047 D4 — "Tests spin up containers per test class via `IAsyncLifetime`, share containers across tests where safe, and tear down deterministically").
4. Author the pilot test set covering the behaviors Tier 2a fakes cannot validate:
   - provider-backed schema behavior is exercised against a real container. For SQL Server-backed Nodes, that means DACPAC publish against Testcontainers SQL Server; for a future explicitly chosen PostgreSQL backing, that means the provider-specific schema path against Postgres.
   - A representative repository round-trip (write then read) against real Postgres.
   - The outbox-store append + dispatch-claim path against real Postgres transactional semantics.
   - At least one test that would pass against an InMemory fake but exercises a Postgres-specific behavior (e.g. a concurrency/transaction-isolation case), demonstrating why Tier 2b exists.
5. Wire `job-integration-tests-containers.yml` (packet 09) into `HoneyDrunk.Data`'s caller workflow (its `pr.yml`), so the new project runs on every PR.
6. The project uses the packet-02 `coverlet.runsettings` if Data adopts one — coverage from Tier 2b is informational, not a second gate.

## Affected Packages
- New test project `HoneyDrunk.Data.Tests.Integration.Containers` — no runtime package changes; this is a test-only addition.

## NuGet Dependencies
New test project `HoneyDrunk.Data.Tests.Integration.Containers` `PackageReference` set:
- `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk` — inherited from the packet-01 test-stack props fragment (xUnit pinned v2.x).
- `NSubstitute` — inherited from the fragment.
- `AwesomeAssertions` — inherited from the fragment.
- `coverlet.collector` — inherited from the fragment.
- `Testcontainers` — current stable (the core Testcontainers.NET package).
- `Testcontainers.PostgreSql` — current stable (the Postgres module).
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26 — mandatory on every new .NET project).
- A `ProjectReference` to the `HoneyDrunk.Data` runtime project(s) under test, and to `HoneyDrunk.Data.Abstractions` as needed.
- Any EF Core Postgres provider package already used by `HoneyDrunk.Data` runtime, referenced by the test project to apply migrations.

If the repo does not yet consume the packet-01 props fragment, the agent adds the xUnit/NSubstitute/AwesomeAssertions/coverlet references explicitly and notes it in the PR; preferred path is fragment adoption.

## Boundary Check
- [x] EF Core / Postgres / migration / outbox-store testing is `HoneyDrunk.Data`'s own domain (routing keyword map: "repository, unit of work, EF Core, SQL Server, … outbox store, migration → HoneyDrunk.Data").
- [x] Test-only addition — no runtime behavior change, no contract change.
- [x] No new cross-Node runtime dependency — Testcontainers is a test-time dependency only (invariant 16: test code in test projects only).

## Acceptance Criteria
- [ ] `tests/HoneyDrunk.Data.Tests.Integration.Containers/` exists, named per ADR-0047 D10
- [ ] The project consumes the packet-01 test-stack props fragment (or declares the stack explicitly with a PR note)
- [ ] `Testcontainers` + `Testcontainers.PostgreSql` are referenced; a Postgres container is managed via `IAsyncLifetime` with deterministic teardown
- [ ] Tests cover: migrations apply cleanly against real Postgres; a repository write/read round-trip; the outbox append + dispatch-claim path; at least one Postgres-specific behavior that justifies Tier 2b
- [ ] `HoneyDrunk.Data`'s caller workflow invokes `job-integration-tests-containers.yml` (packet 09)
- [ ] The Tier 2b suite passes in CI on a Docker-capable runner; suite runtime within the ADR-0047 D1 `< 10min` budget
- [ ] No `Thread.Sleep` in the new test code (invariant 51)
- [ ] `HoneyDrunk.Standards` analyzers referenced on the new project with `PrivateAssets: all` (invariant 26)
- [ ] Repo-level `CHANGELOG.md`: a tooling/test entry under the in-progress version (invariant 12) — test-only, no runtime version bump (test projects excluded from solution version, invariant 27)
- [ ] New test project has a `README.md` describing its purpose (invariant 12 — new projects have CHANGELOG + README from the first commit; for a test project a short README describing scope is sufficient)
- [ ] CI green

## Human Prerequisites
None. (GitHub-hosted `ubuntu-latest` runners include Docker; the Postgres container is pulled from the public registry at test time. No Azure resource, no portal step.)

## Referenced ADR Decisions
**ADR-0047 D1 — Tier 2b.** Integration with real dependencies via Testcontainers; suite `< 10min`; runs every PR.

**ADR-0047 D4 — Tier 2b is Testcontainers.NET.** "Tests spin up containers per test class via `IAsyncLifetime`, share containers across tests where safe, and tear down deterministically." Project naming `HoneyDrunk.<Node>.Tests.Integration.Containers`. Tier 2b's reason to exist: "does our Postgres migration actually run?"

**ADR-0047 D14 Phase 3.** "Pilot on `HoneyDrunk.Data` (Testcontainers Postgres is the natural fit)."

## Referenced Invariants
> **Invariant 15 (amended) — Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception** to the no-external-services rule, "allowed because they are local, ephemeral, and deterministic." *(This pilot is a primary instance of that exception.)*

> **Invariant 16 — No test code in runtime packages.** The Testcontainers project is a dedicated `*.Tests.Integration.Containers` project; Testcontainers packages never enter a runtime `.csproj`.

> **Invariant 26 — `## NuGet Dependencies` section + `HoneyDrunk.Standards` on every new .NET project** with `PrivateAssets: all`.

> **Invariant 27 — Test projects are excluded from the solution version.** This addition does not trigger a release.

## Constraints
- **Test project only.** No runtime code change in `HoneyDrunk.Data`; no contract change.
- **`IAsyncLifetime` for container lifecycle** — per-class spin-up, deterministic teardown. Do not leak containers.
- **No `Thread.Sleep`** — invariant 51; if a test must wait for the container to be ready, use Testcontainers' built-in readiness wait strategies, not `Thread.Sleep`.
- **At least one test must demonstrate why Tier 2b exists** — a behavior a Tier 2a InMemory fake could not catch. The pilot's value is proving the tier, not just adding tests.
- **Coverage is informational here** — do not add a second hard coverage gate; Tier 1 owns the gate (ADR-0047 D3).

## Labels
`feature`, `tier-2`, `core`, `adr-0047`, `wave-3`

## Agent Handoff

**Objective:** Stand up `HoneyDrunk.Data.Tests.Integration.Containers` as the Grid's first Tier 2b project — real Postgres via Testcontainers, `IAsyncLifetime` lifecycle — and wire `job-integration-tests-containers.yml` into Data's PR workflow.

**Target:** `HoneyDrunk.Data`, branch from `main`.

**Context:**
- Goal: Prove the Tier 2b Testcontainers pattern on the Node where real-database behavior matters most.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 3 pilot.
- ADRs: ADR-0047 (D1, D4, D14 Phase 3).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- work-item:01 — the shared test-stack props fragment.
- work-item:09 — `job-integration-tests-containers.yml` must exist to be wired into Data's caller workflow.

**Constraints:**
- Test project only — no runtime change, no contract change.
- `IAsyncLifetime` container lifecycle; deterministic teardown; no leaked containers.
- No `Thread.Sleep` (invariant 51) — use Testcontainers readiness wait strategies.
- At least one test must justify Tier 2b (a behavior Tier 2a fakes cannot catch).
- `HoneyDrunk.Standards` analyzers, `PrivateAssets: all` (invariant 26).

**Key Files:**
- `tests/HoneyDrunk.Data.Tests.Integration.Containers/` (new project)
- `HoneyDrunk.Data`'s `pr.yml` caller workflow (wire packet-09 workflow)
- `CHANGELOG.md` (repo-level — tooling/test entry)

**Contracts:** None changed — test-only.
