---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0047", "wave-3"]
dependencies: ["packet:01", "packet:06", "packet:07"]
adrs: ["ADR-0047", "ADR-0042"]
accepts: ["ADR-0047"]
wave: 3
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-kernel
---

# Pilot Tier 2a on Kernel — reusable `IIdempotencyStore` contract test + InMemory binding under `Contracts/`

## Summary
Stand up the contract-test pattern on `HoneyDrunk.Kernel` for the ADR-0042 `IIdempotencyStore` abstraction: author a reusable contract test written **once against the abstraction**, and bind it to the `InMemoryIdempotencyStore` backing as a Tier 2a integration test in `HoneyDrunk.Kernel.Tests.Integration/Contracts/`. This packet needs **only** the `IIdempotencyStore` abstraction and the in-memory backing — it does not depend on any container, the Cosmos backing, or the Tier 2b workflow, so it ships independently in Wave 3. The Cosmos Tier 2b binding is a separate, hard-preconditioned packet (packet 12).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Kernel`

## Motivation
ADR-0047 D14 Phase 3: "Pilot on … `HoneyDrunk.Kernel` (idempotency-store contract tests per ADR-0042)." ADR-0047 D4: "Contract tests for `*.Abstractions` packages — verifying that any backing implementation satisfies the abstraction's contract — live in Tier 2a under a `Contracts/` folder inside the integration project."

ADR-0042 introduces the `IIdempotencyStore` Kernel-level abstraction and explicitly needs an integration-test pattern to validate end-to-end behavior — ADR-0047's Context names this as a forcing function. The reusable contract test is the artifact that proves a backing satisfies the contract. The `InMemoryIdempotencyStore` backing is shippable today: it depends only on the `IIdempotencyStore` abstraction in `HoneyDrunk.Kernel.Abstractions`, not on any Proposed-ADR-gated package. This packet is therefore the **independently-shippable Tier 2a half** of the Phase 3 Kernel pilot. The Cosmos backing — which is gated on ADR-0042 being Accepted and the `HoneyDrunk.Kernel.Idempotency.Cosmos` package having shipped — is split out to packet 12 so this Wave 3 packet is not blocked on an unverified, Proposed-ADR-gated dependency.

## Proposed Implementation
1. Create or extend `tests/HoneyDrunk.Kernel.Tests.Integration/` with a `Contracts/` folder per ADR-0047 D4.
2. Author the **reusable `IIdempotencyStore` contract test** as an abstract xUnit test class (or a parameterized fixture) that exercises the full `IIdempotencyStore` contract — claim a fresh key succeeds, claim an already-claimed key defers, the `IdempotencyKey` scheme behaves as ADR-0042 specifies, expiry/eviction semantics, concurrency. The test is written once against the abstraction so any future backing can bind to it (packet 12 binds the Cosmos backing to this same class).
3. **Tier 2a backing — InMemory:** a concrete test class binds the reusable contract test to `InMemoryIdempotencyStore`. This lives in `HoneyDrunk.Kernel.Tests.Integration` (Tier 2a — fakes, no container).
4. Adopt the packet-01 test-stack props fragment for the project.
5. The Tier 2a project is picked up automatically by `job-integration-tests.yml` (packet 06) — no caller-workflow change needed beyond Kernel already consuming `pr-core.yml`.
6. Use the integration-test scaffold template (packet 07) as the structural starting point.

## Affected Packages
- New / extended test project `HoneyDrunk.Kernel.Tests.Integration` (Tier 2a) with `Contracts/`.
- No runtime package change — test-only addition.

## NuGet Dependencies
**`HoneyDrunk.Kernel.Tests.Integration` (Tier 2a) — if newly created:**
- `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `NSubstitute`, `AwesomeAssertions`, `coverlet.collector` — inherited from the packet-01 test-stack props fragment (xUnit pinned v2.x).
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).
- `ProjectReference` to the Kernel runtime project(s) exposing `InMemoryIdempotencyStore` and to `HoneyDrunk.Kernel.Abstractions`.

No Testcontainers, no Cosmos package — those are packet 12's scope.

## Boundary Check
- [x] `IIdempotencyStore` is a Kernel-level abstraction (ADR-0042); its contract test belongs in `HoneyDrunk.Kernel`. Routing keyword map: "context, GridContext, … correlation, identity → HoneyDrunk.Kernel" — idempotency is a Kernel concern per ADR-0042.
- [x] Test-only addition — no runtime behavior change, no contract change.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] A reusable `IIdempotencyStore` contract test exists, written once against the abstraction, exercising claim-fresh / claim-already-claimed / `IdempotencyKey` scheme / expiry / concurrency
- [ ] The contract test lives under a `Contracts/` folder in `HoneyDrunk.Kernel.Tests.Integration` per ADR-0047 D4
- [ ] A Tier 2a concrete test binds the reusable contract test to `InMemoryIdempotencyStore` (no container)
- [ ] The reusable contract test class is structured so a future backing (the Cosmos backing, packet 12) can bind to it with no change to the test logic — it is genuinely backing-agnostic
- [ ] The Tier 2a project is picked up by `job-integration-tests.yml` (packet 06)
- [ ] No `Thread.Sleep` in the new test code (invariant 51)
- [ ] `HoneyDrunk.Standards` analyzers referenced on every new project with `PrivateAssets: all` (invariant 26)
- [ ] Repo-level `CHANGELOG.md`: a tooling/test entry under the in-progress version (invariant 12); test-only, no runtime version bump (invariant 27)
- [ ] Each new test project has a short `README.md` describing its scope (invariant 12)
- [ ] CI green

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D4 — Contract tests.** "Contract tests for `*.Abstractions` packages … live in Tier 2a under a `Contracts/` folder inside the integration project. The `IIdempotencyStore` contract test (per ADR-0042) … is run against every backing (`InMemoryIdempotencyStore`, `HoneyDrunk.Kernel.Idempotency.Cosmos`) and must pass for both." This packet delivers the reusable contract test and the InMemory binding; packet 12 adds the Cosmos binding.

**ADR-0047 D1 — Tier 2a.** Integration — in-process: multiple components composed within one Node; internal Grid seams use contract-compatible fakes per invariant 15; external boundaries faked. Runtime budget `< 1s` per test, suite `< 5min`. Run every PR.

**ADR-0047 D14 Phase 3.** "Pilot on … `HoneyDrunk.Kernel` (idempotency-store contract tests per ADR-0042)."

**ADR-0042 — Idempotency contract.** Introduces the `IIdempotencyStore` Kernel-level abstraction and canary; needs an integration-test pattern to validate end-to-end behavior. The `IdempotencyKey` scheme and the claim/defer semantics are the contract this test verifies. *(The implementing agent should read ADR-0042 in the Architecture repo for the precise `IIdempotencyStore` member surface and `IdempotencyKey` semantics — both repos are checked out during cloud execution per ADR-0008 D8.)* Note: ADR-0042 is itself **Proposed** as of 2026-05-22. The `InMemoryIdempotencyStore` and the `IIdempotencyStore` abstraction must already exist in the Kernel repo for this packet to run — confirm they are present before starting; if the abstraction has not yet shipped, this packet is blocked on ADR-0042 implementation and must not start.

## Referenced Invariants
> **Invariant 15 (amended) — Unit tests and in-process integration tests never depend on external services; use InMemory providers for isolation.** Tier 2a (this packet's scope) uses the `InMemoryIdempotencyStore` fake — exactly the in-process-fake posture invariant 15 mandates.

> **Invariant 16 — No test code in runtime packages.** Contract-test code lives only in the `*.Tests.Integration` project.

> **Invariant 26 — `## NuGet Dependencies` + `HoneyDrunk.Standards` (`PrivateAssets: all`) on every new .NET project.**

> **Invariant 27 — Test projects are excluded from the solution version.**

## Constraints
- **Write the contract test once.** The whole point is one reusable contract test; packet 12 binds a second backing to it. Do not write a Cosmos-specific test here and do not inline Cosmos assumptions into the reusable class.
- **Test projects only** — no runtime change, no contract change to `IIdempotencyStore`.
- **Confirm the abstraction exists.** ADR-0042 is Proposed; if `IIdempotencyStore` / `InMemoryIdempotencyStore` are not yet in the Kernel repo, this packet is blocked — do not stub them.
- **No `Thread.Sleep`** (invariant 51).
- Use the packet-07 integration-test scaffold template as the structural starting point.

## Dependencies
- packet:01 — the shared test-stack props fragment.
- packet:06 — `job-integration-tests.yml` picks up the Tier 2a project.
- packet:07 — the integration-test scaffold template (structural starting point).

## Labels
`feature`, `tier-2`, `core`, `adr-0047`, `wave-3`

## Agent Handoff

**Objective:** Implement the reusable `IIdempotencyStore` contract test once and bind it to `InMemoryIdempotencyStore` as a Tier 2a integration test in Kernel's `Contracts/` folder; the project is auto-discovered by `job-integration-tests.yml`.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Prove the ADR-0047 D4 contract-test pattern on the ADR-0042 idempotency abstraction; ship the independently-deliverable Tier 2a half of the Phase 3 Kernel pilot.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 3 pilot.
- ADRs: ADR-0047 (D1, D4, D14 Phase 3), ADR-0042 (the `IIdempotencyStore` contract under test).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:01 — the shared test-stack props fragment.
- packet:06 — `job-integration-tests.yml` discovers the Tier 2a project.
- packet:07 — the integration-test scaffold template.

**Constraints:**
- One reusable, backing-agnostic contract test — packet 12 binds the Cosmos backing to it.
- Confirm `IIdempotencyStore` / `InMemoryIdempotencyStore` exist in the Kernel repo (ADR-0042 is Proposed) — do not stub.
- No `Thread.Sleep` (invariant 51).
- Test projects only; `HoneyDrunk.Standards` analyzers `PrivateAssets: all` (invariant 26).

**Key Files:**
- `tests/HoneyDrunk.Kernel.Tests.Integration/Contracts/` (reusable contract test + InMemory binding)
- `CHANGELOG.md` (repo-level — tooling/test entry)

**Contracts:** Consumes (does not change) the `IIdempotencyStore` contract from `HoneyDrunk.Kernel.Abstractions` per ADR-0042.
