---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0047", "wave-3"]
dependencies: ["work-item:01", "work-item:07", "work-item:09", "work-item:11"]
adrs: ["ADR-0047", "ADR-0042"]
accepts: ["ADR-0047"]
wave: 3
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-kernel
---

# Bind the `IIdempotencyStore` contract test to the Cosmos backing in Tier 2b (Testcontainers)

## Summary
Bind the reusable `IIdempotencyStore` contract test authored in packet 11 to the **Cosmos** backing (`HoneyDrunk.Kernel.Idempotency.Cosmos`) as a Tier 2b container-backed integration test in a new `HoneyDrunk.Kernel.Tests.Integration.Containers` project, using a Testcontainers Cosmos DB emulator. The contract test must pass identically for the Cosmos backing and the InMemory backing (packet 11), satisfying ADR-0047 D4's "run against every backing … must pass for both."

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Kernel`

## HARD PRECONDITION — do not file or start this packet until both are true
This packet binds a contract test to `HoneyDrunk.Kernel.Idempotency.Cosmos` — a package that does **not exist verified today**. It is gated on ADR-0042 ("Idempotency Contract for Async Boundaries"), which is **Proposed** as of 2026-05-22, not Accepted. This packet must NOT be filed as a GitHub Issue, and the executing agent must NOT start, until **both** of the following hold:

1. **ADR-0042 is Accepted.** The idempotency contract is committed Grid law, not a draft. Until then the `IIdempotencyStore` member surface and `IdempotencyKey` semantics can still change, and a contract test written against a moving target is wasted work.
2. **The Cosmos backing package has shipped.** A `HoneyDrunk.Kernel.Idempotency.Cosmos` package (or whatever the ADR-0042 implementation actually names the Cosmos `IIdempotencyStore` backing) exists in the Kernel solution as a real, buildable project. Confirm the actual package/project name against the live Kernel solution — ADR-0047 D4 names it `HoneyDrunk.Kernel.Idempotency.Cosmos`, but the ADR-0042 implementation is authoritative. This is **not** a "verify the package name in-repo at runtime" guess — if the package does not exist, the packet does not run.

The `file-issues` agent holds this packet until both preconditions are confirmed. The dispatch plan records it as preconditioned in Wave 3. Packet 11 (the Tier 2a InMemory binding) carries no such precondition and ships independently in Wave 3 — it depends only on the `IIdempotencyStore` abstraction and `InMemoryIdempotencyStore`, both of which must exist for ADR-0042 to be implementable at all.

## Motivation
ADR-0047 D4: "The `IIdempotencyStore` contract test (per ADR-0042) … is run against every backing (`InMemoryIdempotencyStore`, `HoneyDrunk.Kernel.Idempotency.Cosmos`) and must pass for both." Packet 11 delivers the reusable contract test and the InMemory (Tier 2a) binding. This packet delivers the Cosmos (Tier 2b) binding — the half that exercises a real Cosmos-process dependency via Testcontainers and proves the Cosmos backing satisfies the same contract.

ADR-0047 D14 Phase 3 pilots Tier 2b on Kernel. The Cosmos binding is the Tier 2b instance of that pilot; the Postgres pilot on Data (packet 10) is the other.

## Proposed Implementation
1. Confirm both HARD PRECONDITIONS above. If either fails, stop — the packet is not ready.
2. Create `tests/HoneyDrunk.Kernel.Tests.Integration.Containers/`.
3. Author a concrete test class that binds the **reusable `IIdempotencyStore` contract test from packet 11** to the Cosmos backing. Do not re-author the contract assertions — reference the abstract class / parameterized fixture packet 11 created and supply the Cosmos backing as the system under test.
4. Back the Cosmos backing with a **Testcontainers Cosmos DB emulator** container managed via `IAsyncLifetime` — spin up per test class, share across tests where safe, tear down deterministically.
5. **The contract test must pass identically for the Cosmos backing and the InMemory backing.** ADR-0047 D4: "must pass for both." Any divergence is a real defect in the Cosmos backing, not a test-environment artifact — investigate, do not branch the test.
6. Adopt the packet-01 test-stack props fragment for the project.
7. Wire `job-integration-tests-containers.yml` (packet 09) into Kernel's caller workflow for the Tier 2b project.
8. Use the integration-test scaffold template (packet 07) as the structural starting point.

## Affected Packages
- New test project `HoneyDrunk.Kernel.Tests.Integration.Containers` (Tier 2b).
- No runtime package change — test-only addition.

## NuGet Dependencies
**`HoneyDrunk.Kernel.Tests.Integration.Containers` (Tier 2b) — new:**
- `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `NSubstitute`, `AwesomeAssertions`, `coverlet.collector` — inherited from the packet-01 test-stack props fragment (xUnit pinned v2.x).
- `Testcontainers` — current stable (core).
- `Testcontainers.CosmosDb` — current stable (the Cosmos DB emulator module). If a stable Testcontainers Cosmos module is unavailable, fall back to the generic `Testcontainers` container API pointed at the official Azure Cosmos DB emulator image and note the choice in the PR.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).
- `ProjectReference` to the Cosmos idempotency-store backing project (`HoneyDrunk.Kernel.Idempotency.Cosmos` per ADR-0047 D4 — use the actual project name confirmed by the HARD PRECONDITION check) and to `HoneyDrunk.Kernel.Abstractions`.

## Boundary Check
- [x] `IIdempotencyStore` is a Kernel-level abstraction (ADR-0042); its Cosmos-backing contract test belongs in `HoneyDrunk.Kernel`.
- [x] Test-only addition — no runtime behavior change, no contract change.
- [x] No new cross-Node runtime dependency — Testcontainers is test-time only (invariant 16).

## Acceptance Criteria
- [ ] Both HARD PRECONDITIONS confirmed in the PR body: ADR-0042 is Accepted, and the Cosmos `IIdempotencyStore` backing package exists in the Kernel solution (named, with the confirmed name recorded)
- [ ] `tests/HoneyDrunk.Kernel.Tests.Integration.Containers/` exists
- [ ] A Tier 2b concrete test binds the **packet-11 reusable contract test** (not a re-authored copy) to the Cosmos backing
- [ ] The Cosmos backing is exercised against a Testcontainers Cosmos DB emulator via `IAsyncLifetime`
- [ ] The contract test passes identically for the Cosmos backing and the InMemory backing (packet 11)
- [ ] Kernel's caller workflow invokes `job-integration-tests-containers.yml` (packet 09) for the Tier 2b project
- [ ] No `Thread.Sleep` in the new test code (invariant 51) — use Testcontainers readiness wait strategies
- [ ] `HoneyDrunk.Standards` analyzers referenced on every new project with `PrivateAssets: all` (invariant 26)
- [ ] Repo-level `CHANGELOG.md`: a tooling/test entry under the in-progress version (invariant 12); test-only, no runtime version bump (invariant 27)
- [ ] The new test project has a short `README.md` describing its scope (invariant 12)
- [ ] CI green on a Docker-capable runner; Tier 2b suite within the ADR-0047 D1 `< 10min` budget

## Human Prerequisites
- [ ] **Confirm ADR-0042 has been Accepted** before this packet is filed as a GitHub Issue. ADR-0042 is Proposed as of 2026-05-22; the `file-issues` agent holds this packet until the ADR flips.
- [ ] **Confirm the Cosmos `IIdempotencyStore` backing package has shipped** in the Kernel repo — the ADR-0042 implementation work must have produced it. This packet cannot create it.
- [ ] (At CI time) The Cosmos DB emulator runs as a Testcontainers container on GitHub-hosted `ubuntu-latest` — no Azure Cosmos account, no portal step. The emulator image is heavier than Postgres; container-layer caching from packet 09 matters here.

## Referenced ADR Decisions
**ADR-0047 D4 — Contract tests.** "The `IIdempotencyStore` contract test (per ADR-0042) … is run against every backing (`InMemoryIdempotencyStore`, `HoneyDrunk.Kernel.Idempotency.Cosmos`) and must pass for both."

**ADR-0047 D1 — Tier 2b.** Testcontainers for real-process dependencies; the Cosmos emulator is named explicitly; suite `< 10min`.

**ADR-0047 D14 Phase 3.** "Pilot on … `HoneyDrunk.Kernel` (idempotency-store contract tests per ADR-0042)."

**ADR-0042 — Idempotency contract.** Introduces the `IIdempotencyStore` Kernel-level abstraction and the Cosmos backing. **ADR-0042 is Proposed as of 2026-05-22** — this packet's HARD PRECONDITION requires it Accepted before the work starts. *(The implementing agent reads ADR-0042 in the Architecture repo for the precise `IIdempotencyStore` member surface, `IdempotencyKey` semantics, and the Cosmos backing's package identity — both repos are checked out during cloud execution per ADR-0008 D8.)*

## Referenced Invariants
> **Invariant 15 (amended) — Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception**, allowed because they are local, ephemeral, and deterministic. *(The Cosmos-emulator Tier 2b backing is an instance of this exception.)*

> **Invariant 16 — No test code in runtime packages.** Testcontainers and contract-test code live only in the `*.Tests.Integration.Containers` project.

> **Invariant 26 — `## NuGet Dependencies` + `HoneyDrunk.Standards` (`PrivateAssets: all`) on every new .NET project.**

> **Invariant 27 — Test projects are excluded from the solution version.**

## Constraints
- **HARD PRECONDITION — ADR-0042 Accepted + Cosmos backing shipped.** Do not file, do not start, until both hold. This is not a runtime guess — if the package does not exist, the packet does not run.
- **Reuse the packet-11 contract test.** Bind the existing reusable contract-test class to the Cosmos backing — do not duplicate the assertions.
- **Both backings must pass identically.** A divergence is a defect in the Cosmos backing — investigate, do not branch the test.
- **No `Thread.Sleep`** (invariant 51) — Cosmos-emulator startup is slow; use Testcontainers readiness wait strategies, never a sleep.
- **Test projects only** — no runtime change, no contract change to `IIdempotencyStore`.
- Use the packet-07 integration-test scaffold template as the structural starting point.

## Labels
`feature`, `tier-2`, `core`, `adr-0047`, `wave-3`

## Agent Handoff

**Objective:** Bind the packet-11 reusable `IIdempotencyStore` contract test to the Cosmos backing as a Tier 2b integration test (Testcontainers Cosmos emulator) in `HoneyDrunk.Kernel.Tests.Integration.Containers`, wiring it into Kernel's PR CI — only after ADR-0042 is Accepted and the Cosmos backing package has shipped.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Complete the ADR-0047 D4 "must pass for both backings" contract — pair the Cosmos binding with packet 11's InMemory binding.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 3 pilot (Tier 2b half).
- ADRs: ADR-0047 (D1, D4, D14 Phase 3), ADR-0042 (the `IIdempotencyStore` contract and Cosmos backing — must be Accepted first).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- work-item:01 — the shared test-stack props fragment.
- work-item:07 — the integration-test scaffold template (structural starting point).
- work-item:09 — `job-integration-tests-containers.yml` must exist to wire into Kernel's caller workflow.
- work-item:11 — the reusable contract test and Tier 2a InMemory binding; this packet binds the same reusable class to the Cosmos backing.

**Constraints:**
- HARD PRECONDITION: ADR-0042 Accepted + Cosmos backing package shipped — confirm before starting.
- Reuse the packet-11 contract test — no per-backing assertion duplication.
- Both backings must pass identically — a divergence is a defect.
- No `Thread.Sleep` (invariant 51) — use Testcontainers readiness waits.
- Test projects only; `HoneyDrunk.Standards` analyzers `PrivateAssets: all` (invariant 26).

**Key Files:**
- `tests/HoneyDrunk.Kernel.Tests.Integration.Containers/` (new — Cosmos binding)
- `tests/HoneyDrunk.Kernel.Tests.Integration/Contracts/` (packet 11 — the reusable contract test bound here)
- Kernel's `pr.yml` caller workflow (wire packet-09 workflow)
- `CHANGELOG.md` (repo-level — tooling/test entry)

**Contracts:** Consumes (does not change) the `IIdempotencyStore` contract from `HoneyDrunk.Kernel.Abstractions` per ADR-0042.
