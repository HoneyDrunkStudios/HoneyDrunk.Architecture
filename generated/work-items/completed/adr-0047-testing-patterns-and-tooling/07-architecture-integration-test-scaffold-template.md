---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0047", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0047", "ADR-0042"]
accepts: ["ADR-0047"]
wave: 2
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-architecture
---

# Author the integration-test scaffold template for the `scope` agent

## Summary
Author a reusable integration-test scaffold template under `issues/templates/` (or the repo's template home) that the `scope` agent uses when a packet implies integration-test work — capturing the ADR-0047 D4 Tier 2a / Tier 2b project layout, the `WebApplicationFactory` and Testcontainers patterns, the `Contracts/` folder convention for `*.Abstractions` contract tests, and the D10 naming/structure conventions.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0047 Consequences names "Author an integration-test scaffold template for `scope` agent to use when packets imply integration test work" as explicit follow-up. Without it, every future packet that needs integration tests re-derives the project layout, the naming convention, the `IAsyncLifetime` container-lifecycle pattern, and the `Contracts/` folder rule from the ADR prose — inconsistently. A single scaffold template makes integration-test scoping mechanical and consistent, the same way `issues/templates/` already standardizes the other request types.

This is a docs/governance packet — it authors a template, not code.

## Scope
- New template file under `issues/templates/` (e.g. `integration-test-scaffold.md`) — or wherever the repo keeps reusable scaffolds; match the existing `issues/templates/` convention.
- The template is referenced by the `scope` agent; no `.claude/agents/scope.md` edit is required unless the repo convention is for agents to enumerate their templates — if so, add the reference.

## Proposed Implementation
The template captures, as a fill-in-the-blanks scaffold:

1. **Project layout (ADR-0047 D10):**
   ```
   tests/
     HoneyDrunk.<Node>.Tests.Integration/             (Tier 2a)
       Contracts/                                      (Abstractions contract tests)
     HoneyDrunk.<Node>.Tests.Integration.Containers/  (Tier 2b, where applicable)
   ```
2. **Tier 2a pattern (ADR-0047 D4):** `WebApplicationFactory<T>` for HTTP-fronted Nodes; a test-host bootstrapper without the web layer for non-HTTP Nodes. Internal Grid seams use the contract-compatible fakes per invariant 15 (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`); external boundaries faked in-process.
3. **Tier 2b pattern (ADR-0047 D4):** Testcontainers.NET; containers spun up per test class via `IAsyncLifetime`; shared across tests where safe; deterministic teardown. The project is named `*.Tests.Integration.Containers`; CI requests `runs-on: ubuntu-latest` with Docker.
4. **Contract-test convention (ADR-0047 D4):** Contract tests for `*.Abstractions` packages live in Tier 2a under a `Contracts/` folder. The contract test is run against every backing implementation and must pass for all — e.g. the `IIdempotencyStore` contract test (ADR-0042) runs against `InMemoryIdempotencyStore` and `HoneyDrunk.Kernel.Idempotency.Cosmos`.
5. **Naming/structure conventions (ADR-0047 D10):** class `<ClassUnderTest>Tests`; method `MethodName_Scenario_ExpectedOutcome`; `[Theory]` with `[InlineData]`/`[MemberData]`, no `[ClassData]`; AAA pattern, one Act per test, one logical assertion; async tests return `Task`/`ValueTask`, never `void`, never `.Result`/`.Wait()`; no `Thread.Sleep` (invariant 51).
6. **NuGet stack reminder:** the scaffold reminds the `scope` agent that integration-test packets must carry a `## NuGet Dependencies` section (invariant 26) listing the test stack — the packet-01 props fragment plus, for Tier 2a, `Microsoft.AspNetCore.Mvc.Testing` where the Node is HTTP-fronted, and for Tier 2b, `Testcontainers` (and the relevant `Testcontainers.PostgreSql` / `Testcontainers.CosmosDb` / Azurite module).
7. **Required-tier reminder:** invariant 50 — every Node has a `*.Tests.Unit` project; deployable Nodes also have `*.Tests.Integration`; HTTP-fronted Nodes also have `*.Tests.E2E`. The scaffold reminds the scoping agent to check whether the target Node already satisfies its required tiers.

## Affected Files
- New scaffold template under `issues/templates/`.
- Optionally `.claude/agents/scope.md` — only if the repo convention enumerates templates per agent.

## NuGet Dependencies
None. This packet authors a Markdown template; no .NET project is created or modified.

## Boundary Check
- [x] Templates and scoping artifacts live in `HoneyDrunk.Architecture` (routing rule "architecture, ADR, … → HoneyDrunk.Architecture").
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] A new integration-test scaffold template exists under `issues/templates/` (or the repo's template home)
- [ ] The template captures the ADR-0047 D4/D10 project layout, Tier 2a (`WebApplicationFactory`) pattern, Tier 2b (Testcontainers + `IAsyncLifetime`) pattern, and the `Contracts/` folder convention
- [ ] The template captures the D10 naming/structure conventions (class/method naming, AAA, async-Task, no `Thread.Sleep`)
- [ ] The template reminds the `scope` agent to include a `## NuGet Dependencies` section (invariant 26) with the tier-appropriate test packages
- [ ] The template reminds the `scope` agent to verify invariant 50's required-tier coverage for the target Node
- [ ] If the repo convention enumerates templates per agent, `.claude/agents/scope.md` references the new template
- [ ] No catalog schema change

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D4 — Integration tests.** Tier 2a `WebApplicationFactory<T>` + contract-compatible fakes; Tier 2b Testcontainers.NET via `IAsyncLifetime`. Project naming `*.Tests.Integration` / `*.Tests.Integration.Containers`. Contract tests for `*.Abstractions` live in Tier 2a under `Contracts/`, run against every backing.

**ADR-0047 D10 — Naming and structure conventions.** Class `<ClassUnderTest>Tests`; method `MethodName_Scenario_ExpectedOutcome`; AAA, one Act, one logical assertion; async returns `Task`/`ValueTask`; no `Thread.Sleep`. Project layout under `tests/`.

**ADR-0042 — Idempotency contract.** The `IIdempotencyStore` contract test is the concrete first case the scaffold's `Contracts/` convention serves — run against `InMemoryIdempotencyStore` and `HoneyDrunk.Kernel.Idempotency.Cosmos`.

## Constraints
- **This is a template, not code.** It produces a scaffold the `scope` agent fills in; it does not scaffold any actual test project.
- **Stay consistent with `issues/templates/` conventions** — frontmatter shape, section ordering — so the template is a peer of the existing request-type templates.
- **Inline the D10 conventions in full** so a packet generated from this scaffold is self-contained per the self-containment rule.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0047`, `wave-2`

## Agent Handoff

**Objective:** Author a reusable integration-test scaffold template under `issues/templates/` capturing the ADR-0047 D4/D10 integration-test layout, patterns, and conventions for the `scope` agent.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make integration-test scoping mechanical and consistent across all future packets.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 2.
- ADRs: ADR-0047 (D4, D10), ADR-0042 (the idempotency contract test is the concrete first case).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- work-item:00 — ADR-0047 acceptance (the template encodes Accepted decisions).

**Constraints:**
- Template, not code — no actual test project is scaffolded.
- Match `issues/templates/` conventions.
- Inline the D10 conventions in full (self-containment).

**Key Files:**
- New template under `issues/templates/`.
- `.claude/agents/scope.md` (conditional — only if the repo enumerates templates per agent).

**Contracts:** None changed.
