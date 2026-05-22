---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0047", "wave-3"]
dependencies: ["packet:01", "packet:07", "packet:09"]
adrs: ["ADR-0047", "ADR-0042"]
accepts: ["ADR-0047"]
wave: 3
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-kernel
---

# Pilot Tier 2b on Kernel — `IIdempotencyStore` contract tests under `Contracts/`

## Summary
Stand up the integration-test pattern on `HoneyDrunk.Kernel` for the ADR-0042 `IIdempotencyStore` abstraction: a reusable contract test that runs against every backing implementation, with the InMemory backing in Tier 2a (`HoneyDrunk.Kernel.Tests.Integration/Contracts/`) and the Cosmos backing in Tier 2b (`HoneyDrunk.Kernel.Tests.Integration.Containers/`) using a Testcontainers Cosmos emulator.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Kernel`

## Motivation
ADR-0047 D14 Phase 3: "Pilot on … `HoneyDrunk.Kernel` (idempotency-store contract tests per ADR-0042)." ADR-0047 D4: "Contract tests for `*.Abstractions` packages — verifying that any backing implementation satisfies the abstraction's contract — live in Tier 2a under a `Contracts/` folder inside the integration project. The `IIdempotencyStore` contract test (per ADR-0042), for example, is run against every backing (`InMemoryIdempotencyStore`, `HoneyDrunk.Kernel.Idempotency.Cosmos`) and must pass for both."

ADR-0042 introduces the `IIdempotencyStore` Kernel-level abstraction and explicitly needs an integration-test pattern to validate end-to-end behavior — ADR-0047's Context names this as a forcing function. This packet is the concrete realization: the contract test is the artifact that proves both backings satisfy the same contract, and it spans both integration tiers (InMemory in 2a, Cosmos in 2b).

## Proposed Implementation
1. Create or extend `tests/HoneyDrunk.Kernel.Tests.Integration/` with a `Contracts/` folder per ADR-0047 D4.
2. Author the **reusable `IIdempotencyStore` contract test** as an abstract xUnit test class (or a parameterized fixture) that exercises the full `IIdempotencyStore` contract — claim a fresh key succeeds, claim an already-claimed key defers, the `IdempotencyKey` scheme behaves as ADR-0042 specifies, expiry/eviction semantics, concurrency. The test is written once against the abstraction.
3. **Tier 2a backing — InMemory:** a concrete test class binds the contract test to `InMemoryIdempotencyStore`. This lives in `HoneyDrunk.Kernel.Tests.Integration` (Tier 2a — fakes, no container).
4. **Tier 2b backing — Cosmos:** create `tests/HoneyDrunk.Kernel.Tests.Integration.Containers/` and a concrete test class binding the same contract test to `HoneyDrunk.Kernel.Idempotency.Cosmos`, backed by a Testcontainers Cosmos DB emulator container managed via `IAsyncLifetime`. (Per ADR-0042's package naming — confirm the actual Cosmos backing package name in the Kernel repo at implementation time; the ADR-0047 D4 text names it `HoneyDrunk.Kernel.Idempotency.Cosmos`.)
5. **The contract test must pass identically for both backings** — ADR-0047 D4: "must pass for both." Any divergence is a real defect in one backing, not a test-environment artifact.
6. Adopt the packet-01 test-stack props fragment for both projects.
7. Wire `job-integration-tests-containers.yml` (packet 09) into Kernel's caller workflow for the Tier 2b project; the Tier 2a project is picked up by `job-integration-tests.yml` (packet 06).
8. Use the integration-test scaffold template (packet 07) as the structural starting point.

## Affected Packages
- New / extended test project `HoneyDrunk.Kernel.Tests.Integration` (Tier 2a) with `Contracts/`.
- New test project `HoneyDrunk.Kernel.Tests.Integration.Containers` (Tier 2b).
- No runtime package change — test-only addition.

## NuGet Dependencies
**`HoneyDrunk.Kernel.Tests.Integration` (Tier 2a) — if newly created:**
- `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `NSubstitute`, `AwesomeAssertions`, `coverlet.collector` — inherited from the packet-01 test-stack props fragment.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).
- `ProjectReference` to the Kernel runtime project(s) exposing `InMemoryIdempotencyStore` and to `HoneyDrunk.Kernel.Abstractions`.

**`HoneyDrunk.Kernel.Tests.Integration.Containers` (Tier 2b) — new:**
- The same packet-01 fragment stack (xUnit v2.x + NSubstitute + AwesomeAssertions + coverlet).
- `Testcontainers` — current stable (core).
- `Testcontainers.CosmosDb` — current stable (the Cosmos DB emulator module). If a stable Testcontainers Cosmos module is unavailable, fall back to the generic `Testcontainers` container API pointed at the official Azure Cosmos DB emulator image and note the choice in the PR.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).
- `ProjectReference` to the Cosmos idempotency-store backing package (`HoneyDrunk.Kernel.Idempotency.Cosmos` per ADR-0047 D4 — verify the actual package name in-repo) and to `HoneyDrunk.Kernel.Abstractions`.

## Boundary Check
- [x] `IIdempotencyStore` is a Kernel-level abstraction (ADR-0042); its contract test belongs in `HoneyDrunk.Kernel`. Routing keyword map: "context, GridContext, … correlation, identity → HoneyDrunk.Kernel" — idempotency is a Kernel concern per ADR-0042.
- [x] Test-only addition — no runtime behavior change, no contract change.
- [x] No new cross-Node runtime dependency — Testcontainers is test-time only (invariant 16).

## Acceptance Criteria
- [ ] A reusable `IIdempotencyStore` contract test exists, written once against the abstraction, exercising claim-fresh / claim-already-claimed / `IdempotencyKey` scheme / expiry / concurrency
- [ ] The contract test lives under a `Contracts/` folder in `HoneyDrunk.Kernel.Tests.Integration` per ADR-0047 D4
- [ ] A Tier 2a concrete test binds the contract test to `InMemoryIdempotencyStore` (no container)
- [ ] A Tier 2b concrete test in `HoneyDrunk.Kernel.Tests.Integration.Containers` binds the same contract test to the Cosmos backing, using a Testcontainers Cosmos emulator via `IAsyncLifetime`
- [ ] The contract test passes identically for both backings
- [ ] Kernel's caller workflow invokes `job-integration-tests-containers.yml` (packet 09) for the Tier 2b project; the Tier 2a project is picked up by `job-integration-tests.yml` (packet 06)
- [ ] No `Thread.Sleep` in the new test code (invariant 51) — use Testcontainers readiness wait strategies
- [ ] `HoneyDrunk.Standards` analyzers referenced on every new project with `PrivateAssets: all` (invariant 26)
- [ ] Repo-level `CHANGELOG.md`: a tooling/test entry under the in-progress version (invariant 12); test-only, no runtime version bump (invariant 27)
- [ ] Each new test project has a short `README.md` describing its scope (invariant 12)
- [ ] CI green on a Docker-capable runner; Tier 2b suite within the ADR-0047 D1 `< 10min` budget

## Human Prerequisites
None. (The Cosmos DB emulator runs as a Testcontainers container on GitHub-hosted `ubuntu-latest`; no Azure Cosmos account, no portal step. Note: the Cosmos emulator image is heavier than Postgres — container-layer caching from packet 09 matters here.)

## Referenced ADR Decisions
**ADR-0047 D4 — Contract tests.** "Contract tests for `*.Abstractions` packages … live in Tier 2a under a `Contracts/` folder inside the integration project. The `IIdempotencyStore` contract test (per ADR-0042) … is run against every backing (`InMemoryIdempotencyStore`, `HoneyDrunk.Kernel.Idempotency.Cosmos`) and must pass for both."

**ADR-0047 D1 — Tier 2b.** Testcontainers for real-process dependencies; Cosmos emulator is named explicitly; suite `< 10min`.

**ADR-0047 D14 Phase 3.** "Pilot on … `HoneyDrunk.Kernel` (idempotency-store contract tests per ADR-0042)."

**ADR-0042 — Idempotency contract.** Introduces the `IIdempotencyStore` Kernel-level abstraction and canary; needs an integration-test pattern to validate end-to-end behavior. The `IdempotencyKey` scheme and the claim/defer semantics are the contract this test verifies. *(The implementing agent should read ADR-0042 in the Architecture repo for the precise `IIdempotencyStore` member surface and `IdempotencyKey` semantics — both repos are checked out during cloud execution per ADR-0008 D8.)*

## Referenced Invariants
> **Invariant 15 (amended) — Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception**, allowed because they are local, ephemeral, and deterministic. *(The Cosmos-emulator Tier 2b backing is an instance of this exception.)*

> **Invariant 16 — No test code in runtime packages.** Testcontainers and contract-test code live only in the `*.Tests.Integration*` projects.

> **Invariant 26 — `## NuGet Dependencies` + `HoneyDrunk.Standards` (`PrivateAssets: all`) on every new .NET project.**

> **Invariant 27 — Test projects are excluded from the solution version.**

## Constraints
- **Write the contract test once.** The whole point is one contract test, two backings — do not duplicate the assertions per backing.
- **Both backings must pass identically.** A divergence is a defect in a backing — investigate, do not branch the test.
- **Verify the Cosmos backing package name in-repo.** ADR-0047 D4 names it `HoneyDrunk.Kernel.Idempotency.Cosmos`; confirm against the actual Kernel solution and use the real name.
- **No `Thread.Sleep`** (invariant 51) — Cosmos-emulator startup is slow; use Testcontainers readiness wait strategies, never a sleep.
- **Test projects only** — no runtime change, no contract change to `IIdempotencyStore`.
- Use the packet-07 integration-test scaffold template as the structural starting point.

## Labels
`feature`, `tier-2`, `core`, `adr-0047`, `wave-3`

## Agent Handoff

**Objective:** Implement the `IIdempotencyStore` contract test once and run it against both backings — `InMemoryIdempotencyStore` in Tier 2a (`Contracts/` folder) and the Cosmos backing in Tier 2b (Testcontainers Cosmos emulator) — wiring both into Kernel's PR CI.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Prove the ADR-0047 D4 contract-test pattern on the ADR-0042 idempotency abstraction; pilot Tier 2b on Kernel.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 3 pilot.
- ADRs: ADR-0047 (D1, D4, D14 Phase 3), ADR-0042 (the `IIdempotencyStore` contract under test).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:01 — the shared test-stack props fragment.
- packet:07 — the integration-test scaffold template (structural starting point).
- packet:09 — `job-integration-tests-containers.yml` must exist to wire into Kernel's caller workflow.

**Constraints:**
- One contract test, two backings — no per-backing assertion duplication.
- Both backings must pass identically — a divergence is a defect.
- Verify the Cosmos backing package name against the actual Kernel solution.
- No `Thread.Sleep` (invariant 51) — use Testcontainers readiness waits.
- Test projects only; `HoneyDrunk.Standards` analyzers `PrivateAssets: all` (invariant 26).

**Key Files:**
- `tests/HoneyDrunk.Kernel.Tests.Integration/Contracts/` (contract test + InMemory binding)
- `tests/HoneyDrunk.Kernel.Tests.Integration.Containers/` (new — Cosmos binding)
- Kernel's `pr.yml` caller workflow (wire packet-09 workflow)
- `CHANGELOG.md` (repo-level — tooling/test entry)

**Contracts:** Consumes (does not change) the `IIdempotencyStore` contract from `HoneyDrunk.Kernel.Abstractions` per ADR-0042.
