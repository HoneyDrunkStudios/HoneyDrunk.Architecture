---
name: Integration Test Scaffold
type: repo-feature
tier: 2
target_repo: "{repo}"
labels: ["tests", "tier-2", "{sector}"]
dependencies: []
adrs: ["ADR-0047"]
wave: 1
initiative: "{initiative-slug}"
node: "{node-id}"
---

# Integration Test Scaffold: {Node / Feature}

## Summary
<!-- One-sentence summary of the integration-test work being scoped. -->

## Target Repo
`{HoneyDrunkStudios/RepoName}`

## Motivation
<!-- Explain the production seam, contract, or behavior that requires integration-level validation rather than unit tests only. -->

## Required Tier Check
Before scoping implementation, verify ADR-0047 / Invariant 50 coverage for the target Node:

- [ ] `*.Tests.Unit` exists or this packet explains why it is created elsewhere
- [ ] Deployable Node has `*.Tests.Integration` (Tier 2a) or this packet creates it
- [ ] HTTP-fronted Node has `*.Tests.E2E` or a follow-up packet tracks it
- [ ] Existing test-project names follow `tests/HoneyDrunk.<Node>.Tests.{Tier}` conventions

> **Invariant 50:** Every Node has a `*.Tests.Unit` project; deployable Nodes also have a `*.Tests.Integration` project; HTTP-fronted Nodes also have a `*.Tests.E2E` project. A missing required test tier is a CI gate failure. See ADR-0047 D1, D11.

## Project Layout
Use this layout unless the repo already has an equivalent test folder convention:

```text
tests/
  HoneyDrunk.<Node>.Tests.Integration/             # Tier 2a
    Contracts/                                      # Abstractions contract tests
  HoneyDrunk.<Node>.Tests.Integration.Containers/  # Tier 2b, where applicable
```

### Tier 2a — in-process integration tests
Use Tier 2a when validating composition inside a Node or across internal Grid seams without real external dependencies.

- HTTP-fronted Nodes: use `Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<TEntryPoint>`.
- Non-HTTP Nodes: use an explicit test-host/bootstrapper pattern without the web layer.
- Internal Grid seams use contract-compatible fakes per Invariant 15, e.g. `InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`.
- External boundaries are faked in-process unless the behavior being validated specifically requires the real dependency.
- Tests run on the normal PR path through the Tier 2 integration workflow once available.

### Tier 2b — container-backed real dependency tests
Use Tier 2b only when the real external dependency behavior is part of the contract being validated.

- Project name: `HoneyDrunk.<Node>.Tests.Integration.Containers`.
- Use Testcontainers.NET for ephemeral local dependencies such as Postgres, Cosmos DB emulator, Azure Service Bus emulator, or Azurite.
- Containers are started per test class with `IAsyncLifetime`.
- Share containers across tests only when isolation remains deterministic.
- Teardown must be deterministic.
- CI requires Docker-capable `ubuntu-latest` runners.

Tier 2b is the scoped exception to Invariant 15: local, ephemeral, deterministic containers are allowed; shared/remote production-like services are not.

## Contract Test Convention
Contract tests for `*.Abstractions` packages live in Tier 2a under `Contracts/`.

- A reusable contract-test fixture defines behavior once.
- Every backing implementation must run and pass the same contract suite.
- Example: an `IIdempotencyStore` contract suite can run against `InMemoryIdempotencyStore` and, when ADR-0042/Cosmos backing exists, `HoneyDrunk.Kernel.Idempotency.Cosmos`.
- Contract tests should validate externally observable behavior, not implementation internals.

## Naming and Structure
Apply ADR-0047 D10 directly:

- Test class: `<ClassUnderTest>Tests`.
- Test method: `MethodName_Scenario_ExpectedOutcome`.
- Use `[Fact]` for single cases.
- Use `[Theory]` with `[InlineData]` or `[MemberData]` for parameterized cases.
- Do **not** use `[ClassData]`; it hides test data away from the test body.
- Use AAA structure: Arrange, Act, Assert.
- One Act per test.
- One logical assertion per test; grouped assertions are allowed only when they describe one outcome.
- Async tests return `Task` or `ValueTask`.
- Never use `async void`, `.Result`, `.Wait()`, or `Thread.Sleep`.

> **Invariant 51:** Test code contains no `Thread.Sleep`. Async work waits via `await`, polling primitives with explicit timeouts, or synchronously-completing fakes. `Thread.Sleep` is a CI flakiness multiplier. Enforced by an analyzer rule on test projects. See ADR-0047 D10.

## NuGet Dependencies
List the exact test packages this packet requires. Prefer the shared test-stack props fragment from HoneyDrunk.Standards once available.

Baseline stack:

- `xunit` v2.x
- `xunit.runner.visualstudio`
- `NSubstitute`
- `AwesomeAssertions`
- `coverlet.collector`
- `Microsoft.NET.Test.Sdk`

Tier-specific additions:

- Tier 2a HTTP-fronted Nodes: `Microsoft.AspNetCore.Mvc.Testing`
- Tier 2b: `Testcontainers`
- Tier 2b Postgres: `Testcontainers.PostgreSql`
- Tier 2b Cosmos: `Testcontainers.CosmosDb` or the documented emulator module/package available at implementation time
- Tier 2b Storage: Azurite/Testcontainers module or explicit container image wrapper

> **Invariant 26:** Every work item that touches code must include a `## NuGet Dependencies` section listing packages added, removed, or version-changed, with rationale.

## Boundary Check
- [ ] Test belongs in the target Node repo, not Architecture or Standards
- [ ] Test validates a real integration seam or contract boundary, not unit-only behavior
- [ ] No new runtime dependency is introduced only for tests
- [ ] Cross-Node dependency order is verified against `catalogs/relationships.json` if multiple packages are composed
- [ ] External services are faked in Tier 2a and local/ephemeral in Tier 2b

## Proposed Implementation
<!-- Fill this with repo-specific files/projects/classes to create or modify. -->

1. Create or update `{test-project-path}`.
2. Add the required package references or adopt the shared test-stack props fragment.
3. Add `{test-fixture-or-factory}` for composition/bootstrap.
4. Add integration tests for `{behavior-or-contract}`.
5. Wire the project into solution/test discovery.
6. Update docs/changelog only if repo conventions require it for test-only changes.

## Acceptance Criteria
- [ ] Required integration test project exists using ADR-0047 naming conventions
- [ ] Tier 2a tests use `WebApplicationFactory<T>` or a test-host bootstrapper as appropriate
- [ ] Tier 2b tests, if present, use Testcontainers with `IAsyncLifetime` lifecycle and deterministic teardown
- [ ] `Contracts/` folder exists when testing an `*.Abstractions` contract
- [ ] Test names and structure follow ADR-0047 D10
- [ ] No `Thread.Sleep`, `.Result`, `.Wait()`, or `async void` in test code
- [ ] `dotnet test` passes for the new/updated test project
- [ ] CI workflow discovers or will discover the project according to the ADR-0047 rollout phase

## Dependencies
<!-- Other issues, PRs, packages, or ADR acceptance requirements. -->

## Labels
`tests`, `tier-2`, `{sector}`
