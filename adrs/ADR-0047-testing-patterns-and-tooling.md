# ADR-0047: Testing Patterns and Tooling

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / cross-cutting

## Context

The Grid has no formal testing-patterns ADR. Today:

- **Unit tests** exist in most Nodes using xUnit and Moq, but conventions drift between Nodes — different assertion libraries, different mocking patterns, no shared test-data approach.
- **Integration tests** are explicitly named as an unresolved gap (ADR-0011 Gap 1). The slot in `pr-core.yml` tier 2 is defined; no implementation pattern is committed.
- **E2E tests** are named as an unresolved gap (ADR-0011 Gap 3) with Playwright identified as the chosen tool — but no scope, no setup pattern, no environment commitments.
- **Mobile E2E** is undecided. Six consumer-app PDRs (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0007 Arcadia, PDR-0008 Curiosities, plus PDR-0004 Wayside) all imply mobile distribution; mobile platform itself is pending an ADR, and the mobile E2E story is downstream.
- **Canary tests** exist as a pattern (Invariant 14) — small console apps that consume published packages and smoke-test consumability — but they sit alongside, not inside, the testing pyramid.
- **Test infrastructure decisions** (assertion library, coverage tool, test data approach, performance benchmarking, load testing) are made ad-hoc per Node.

The forcing functions for codifying this now:

- **ADR-0044 D3 category 11 (Testing Quality)** binds the `review` agent to walk a testing-quality checklist on every PR (coverage, anti-patterns, verification depth). That checklist is meaningless without a committed framework for what "good" looks like.
- **ADR-0042 (Idempotency Contract)** introduces a Kernel-level abstraction and canary that needs an integration test pattern to validate end-to-end behavior.
- **The deployable Nodes** (Notify.Functions, Notify.Worker, Pulse.Collector — all actively in the ADR-0015 rollout) are landing without an integration-test layer. The longer this gap stays open, the harder it is to retrofit.
- **The AI-sector standup wave** (ADR-0016 through ADR-0025) introduces nine new Nodes that need testing patterns from day one of their standup canaries.
- **Notify Cloud GA** (PDR-0002) is the first commercial product. Shipping it without E2E coverage is a credible-paying-customer-blocker.
- **Assertion-library licensing** has changed in the .NET ecosystem (FluentAssertions v8 moved to paid commercial license in October 2024). The de-facto standard is no longer free; a decision is forced.

This ADR commits to specific frameworks and patterns across the testing pyramid, closes ADR-0011 Gap 1 and Gap 3, and names the mobile-E2E tool.

## Decision

### D1 — The testing pyramid

Four named test categories, each with a specific scope, runtime budget, and CI integration:

| Tier | Name | Scope | Runtime budget | When run |
|------|------|-------|----------------|----------|
| 1 | **Unit** | Single class/method in isolation; all dependencies faked or mocked | < 10ms per test typical; suite < 30s | Every PR (pr-core.yml tier 1) |
| 2a | **Integration — in-process** | Multiple components composed within one Node; **internal** Grid seams use contract-compatible fakes per Invariant 15 (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`); **external** boundaries (DB, broker, Vault) faked | < 1s per test typical; suite < 5min | Every PR (pr-core.yml tier 2) |
| 2b | **Integration — with real dependencies** | Same scope as 2a, but external boundaries use **Testcontainers** for real-process dependencies (Postgres, Service Bus emulator, Cosmos emulator) | < 10s per test typical; suite < 10min | Every PR (pr-core.yml tier 2, parallel with 2a) |
| 3 | **E2E** | Full deployed environment, real Azure resources, real network paths, browser- or mobile-driven | < 60s per test typical; suite < 30min | On `staging`-tag deploy and on nightly schedule against `dev`; not on every PR (cost) |
| Special | **Canary** | Per Invariant 14 — small console apps that reference published NuGet packages and smoke-test consumability | < 5s per canary | Nightly per ADR-0012's grid-health aggregator; also after any package release |

The pyramid shape: many unit tests, fewer integration tests, fewer still E2E tests. Canaries are orthogonal — they validate **package consumability** rather than **behavior**, and they exist outside the pyramid.

**Why two integration tiers (2a and 2b):** The Grid's coupling rule (Abstractions-first per every standup ADR) makes most cross-Node testing possible **without** spinning up real dependencies — the contract-compatible fakes (Invariant 15) cover most cases at low cost. Tier 2a is the workhorse. Tier 2b exists for the cases where the **real dependency's behavior** is what's being tested (e.g., does our Postgres migration actually run? does the Service Bus deduplication window behave as expected under our `IdempotencyKey` scheme per ADR-0042?). Splitting them lets Tier 2a stay fast and parallel-friendly while Tier 2b carries the heavier startup cost only where it earns its keep.

### D2 — Unit tests: xUnit + Moq + AwesomeAssertions

The committed unit-test stack:

- **xUnit** as the test framework. Already in use across most Nodes; mature, well-supported, parallel-test-friendly. The ADR commits to xUnit v2.x for consumption stability (xUnit v3 is in development; adopt when stable).
- **Moq** as the mocking library. Already in use; user-directed. (Moq's 2023 SponsorLink incident is acknowledged as a brand-trust event; the technical decision stands because Moq is what the codebase uses today and the alternative migration cost — NSubstitute, FakeItEasy — exceeds the marginal benefit. NSubstitute is documented as a future-amendment option if Moq's stewardship becomes a problem.)
- **AwesomeAssertions** as the assertion library. **Not FluentAssertions** — FluentAssertions v8 (October 2024) moved to a paid commercial license, and the Studio is technically a commercial entity. AwesomeAssertions is the community MIT-licensed fork of FluentAssertions v7, drop-in compatible with the v7 API, actively maintained. This is the cheapest option that preserves the assertion-fluency the codebase already depends on; the alternative (downgrading to xUnit's native assertions) would be a meaningful regression in test readability.
- **coverlet** as the coverage tool. Already standard in .NET; integrates with `dotnet test`.

The combined stack — xUnit + Moq + AwesomeAssertions + coverlet — is the **default unit-test configuration** in `Directory.Build.props` per the test-project conventions added in D10.

### D3 — Coverage targets per Node tier

Per-Node coverage thresholds aligned with ADR-0036 DR tiers:

| Node tier | Line coverage | Branch coverage | Rationale |
|-----------|---------------|-----------------|-----------|
| Tier 0 (Vault, Audit, Notify Cloud tenant data) | **85%** line / **80%** branch | Hard CI gate | Loss of these Nodes is the highest-cost failure mode; coverage discipline is part of the trust posture. |
| Tier 1 (Notify, Memory, Knowledge) | **75%** line / **70%** branch | Hard CI gate | Important; customer-impacting; coverage protects customer-facing paths. |
| Tier 2 (Pulse, Flow, Evals) | **60%** line / **55%** branch | Warning, not gate | Best-effort; over-investment in coverage on best-effort Nodes is poor ROI. |
| Untiered (Architecture, Studios) | No threshold | No gate | Documentation/marketing repos; tests where they make sense, no enforcement. |

Coverage thresholds are configured per-project in `coverlet.runsettings` files at the Node root. The CI gate (per ADR-0011 D2 tier 1) reads these and fails the PR check if a Tier 0 / Tier 1 Node drops below threshold.

ADR-0032's PR Validation Policy already mandates a coverage gate; this ADR sets the specific numbers per tier. The numbers are deliberately moderate — high enough to catch missing tests, low enough to not force pointless coverage on getter/setter code.

### D4 — Integration tests: WebApplicationFactory + Testcontainers split

**Tier 2a (in-process with fakes):** Built on `Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<T>` for HTTP-fronted Nodes (Notify.Functions, Web.Rest consumers, future Notify Cloud gateway). For non-HTTP Nodes, the same composition pattern via a test-host bootstrapper without the web layer. Internal Grid seams use the contract-compatible fakes (Invariant 15); external boundaries (DB, broker, Vault, ESP) use in-process fakes too.

**Tier 2b (with real dependencies):** Built on **Testcontainers.NET** for ephemeral real-process dependencies — Postgres, Cosmos DB emulator, Azure Service Bus emulator (in preview at time of writing; falls back to a local emulator container until stable), Azurite for storage emulation. Tests spin up containers per test class via `IAsyncLifetime`, share containers across tests where safe, and tear down deterministically.

The split is enforced by test-project naming convention:

- `HoneyDrunk.<Node>.Tests.Unit` — Tier 1.
- `HoneyDrunk.<Node>.Tests.Integration` — Tier 2a.
- `HoneyDrunk.<Node>.Tests.Integration.Containers` — Tier 2b.

CI executes each project in a separate job; Tier 2b jobs explicitly request `runs-on: ubuntu-latest` (or a self-hosted runner with Docker) and cache container layers across runs.

**Contract tests** for `*.Abstractions` packages — verifying that any backing implementation satisfies the abstraction's contract — live in Tier 2a under a `Contracts/` folder inside the integration project. The `IIdempotencyStore` contract test (per ADR-0042), for example, is run against every backing (`InMemoryIdempotencyStore`, `HoneyDrunk.Kernel.Idempotency.Cosmos`) and must pass for both.

### D5 — E2E (web): Playwright (.NET binding)

**Playwright** for browser-driven E2E tests. Per ADR-0011 Gap 3 the choice was already made; this ADR commits the binding.

**.NET binding** (`Microsoft.Playwright`) over the TypeScript binding. Rationale: keeps the test stack in one language (C#), reuses the same test runner (xUnit) and assertion library (AwesomeAssertions) as the rest of the pyramid, lets test fixtures share types with production code where it helps. The TypeScript ecosystem has a marginally better Playwright UX (visual regression tooling is more mature in JS), but the language-consistency win is larger for a solo-dev shop.

Playwright tests live in `HoneyDrunk.<Surface>.Tests.E2E` projects — one per deployable web surface. Initial surfaces:

- **HoneyDrunk.Studios.Tests.E2E** — marketing site (per ADR-0029).
- **HoneyDrunk.HoneyHub.Tests.E2E** — when HoneyHub's UI lands (per ADR-0003 Phase 2+).
- **HoneyDrunk.NotifyCloud.Tests.E2E** — Notify Cloud tenant portal (when standup completes per ADR-0027).

Execution: against `dev` nightly (via Actions cron); against `staging` on tag deploy; against `prod` post-deploy as smoke (5–10 critical-path tests, not the full suite — cost discipline).

Browser binaries cached across CI runs; trace files retained for failed runs per ADR-0011 Gap 3's contract.

### D6 — E2E (mobile): Maestro

**Maestro** for mobile E2E tests. Declarative YAML-based, cross-platform (iOS + Android), works with native, React Native, Flutter, and .NET MAUI — which matters because the **mobile platform ADR is still in the backlog**. Picking a platform-agnostic E2E tool means the testing decision survives whatever the platform decision turns out to be.

Rationale:

- **Declarative YAML** is materially easier for a solo dev to maintain than Appium's verbose APIs or Detox's React-Native-specific instrumentation.
- **Cross-platform** keeps test code count low (one suite for iOS + Android).
- **Free and open source** (mobile.dev's hosted Cloud is paid but not required; local execution + CI is free).
- **Active community** (Maestro adoption is climbing in 2024–2025).
- **CI-friendly** — runs on iOS simulator on macOS runners and Android emulator on Linux runners.

The choice is **only** the test-driver tool. The mobile-platform ADR (when it lands) decides .NET MAUI vs Expo vs native; Maestro works with all of them.

Mobile E2E tests live in `HoneyDrunk.<App>.Tests.Mobile` projects (or directories — Maestro tests are YAML, not C#, but live in the same repo structure as the app under test). Initial scope: zero until the first consumer app actually exists; the tooling commitment is recorded so the first app doesn't re-litigate it.

Execution: on tag deploy for mobile apps; nightly against a test build. Mobile E2E is slow and flaky by nature; we accept that and offset by running it less often than web E2E.

### D7 — Test data: AutoFixture + Builders

**AutoFixture** for generating filler test data (`fixture.Create<Customer>()`) where the values don't matter to the test. Reduces boilerplate and surfaces "the test breaks when this field is non-null/empty/whatever" failures useful for catching brittle assumptions.

**Builder pattern** (hand-written) for the cases where the test data shape matters and AutoFixture's generated values are wrong (e.g., constructing a valid `TenantId` per ADR-0026, constructing a domain entity that satisfies invariants). Builders live alongside the production code in a `Testing` namespace inside the production assembly, marked `[InternalsVisibleTo("HoneyDrunk.<Node>.Tests.*")]`, so they can be reused across test projects.

**Bogus** only for **integration tests that need realistic seed data** (e.g., realistic-looking customer names for a UI integration test). Not used in unit tests — Bogus' realism is irrelevant when values don't matter, and AutoFixture is simpler for that case.

### D8 — Canary tests: per Invariant 14, formalized

Invariant 14 already establishes canaries: small console applications that reference the published Node package and smoke-test consumability. This ADR formalizes the pattern:

- Canaries live in the Node's repo at `tests/Canaries/HoneyDrunk.<Node>.Canary/`.
- One canary per published `.Abstractions` package and one per default backing.
- Each canary's `Program.cs` instantiates the published types via the public surface and exercises the contract-shape (the same shape the standup ADRs commit to).
- Canaries run **nightly** per Node (ADR-0012 grid-health aggregator) and **post-publish** (the publish workflow per ADR-0034 invokes the canary after `dotnet nuget push` returns).
- Failure is high-signal: a canary that breaks means the package is unusable by external consumers, which is graver than a unit-test failure (unit tests can pass on broken public surfaces).

Canaries are **not in the testing pyramid** (they're not behavior tests); they're a separate axis. ADR-0011 Gap 1's "Canaries ≠ Integration tests" note is preserved verbatim — they validate different properties.

### D9 — Performance and load testing

**BenchmarkDotNet** for micro-benchmarks where the hot-path performance matters. Lives in `HoneyDrunk.<Node>.Tests.Benchmarks` projects. Runs **on-demand only** (not in PR CI; benchmark runs need a stable runner to produce meaningful numbers). Used to:

- Verify the `IIdempotencyStore` dedup-store lookup latency is single-digit ms (per ADR-0042 D2's operational claim).
- Compare candidate implementations during design (e.g., the `tenant.id` lookup path in the Notify Cloud gateway).
- Establish baselines that PRs can regress against (manual comparison; automated benchmark CI is future work).

**Azure Load Testing** for macro-level load testing of HTTP-fronted Nodes. Free tier covers 50 virtual user-hours/month; Notify Cloud GA work likely needs more. Per-tenant SLA testing for Notify Cloud is the load-testing use case; before that, we run Azure Load Testing manually during major releases.

**k6 / Locust** are not adopted. Azure Load Testing leverages the existing Azure relationship (per the ADR-0040 pattern of preferring sunk-cost vendors) and integrates with Azure Monitor (per ADR-0040) for results inspection. Open-source tools work fine but add operational surface for a solo dev.

### D10 — Naming and structure conventions

Test class and method naming:

- **Test class name:** `<ClassUnderTest>Tests` (e.g., `TenantIdTests`, `IdempotentMessageHandlerTests`).
- **Test method name:** `MethodName_Scenario_ExpectedOutcome` (e.g., `Claim_KeyAlreadyClaimed_Defers`, `Claim_FreshKey_Succeeds`).
- **Theory data:** `[Theory]` with `[InlineData]` for simple cases; `[MemberData]` referencing a static method for complex cases. No `[ClassData]` (too much indirection for the savings).

Test structure:

- **AAA pattern** (Arrange / Act / Assert). One Act per test. Multiple assertions OK if they verify aspects of the same outcome.
- **One logical assertion per test.** "Logical" — three `.Should()` chained on the same returned object is one logical assertion.
- **Async tests** return `Task` (or `ValueTask`); never `void`; never `.Result` / `.Wait()`.
- **No `Thread.Sleep`.** Tests that need to wait for async work use `await`, polling primitives with timeout, or fakes that complete synchronously. `Thread.Sleep` is a CI flakiness multiplier.

Project structure under each Node repo:

```
src/
  HoneyDrunk.<Node>/
  HoneyDrunk.<Node>.Abstractions/
tests/
  HoneyDrunk.<Node>.Tests.Unit/
  HoneyDrunk.<Node>.Tests.Integration/
  HoneyDrunk.<Node>.Tests.Integration.Containers/  (where applicable)
  HoneyDrunk.<Node>.Tests.E2E/                      (where applicable; deployable Nodes)
  HoneyDrunk.<Node>.Tests.Benchmarks/               (where applicable; performance-sensitive Nodes)
  Canaries/
    HoneyDrunk.<Node>.Canary/
```

### D11 — CI integration per tier

| Tier | CI invocation | Blocking? |
|------|--------------|-----------|
| Unit | `dotnet test --filter "FullyQualifiedName~Tests.Unit"` in `job-build-and-test.yml` (per ADR-0011 D2 stage 2) | Yes (branch protection) |
| Integration 2a | `dotnet test --filter "FullyQualifiedName~Tests.Integration"` in a new `job-integration-tests.yml` (closes ADR-0011 Gap 1) | Yes (branch protection) |
| Integration 2b | `dotnet test --filter "FullyQualifiedName~Tests.Integration.Containers"` in `job-integration-tests-containers.yml`; requires Docker; parallel with 2a | Yes (branch protection) |
| E2E web | `dotnet test` in `job-e2e-web.yml`; runs nightly on `dev` and on `staging` tag deploy | Yes on `staging` tag; advisory on nightly `dev` |
| E2E mobile | `maestro test` in `job-e2e-mobile.yml`; runs on tag deploy for mobile apps; nightly against test builds | Yes on tag deploy; advisory on nightly |
| Benchmarks | On-demand `dotnet run -c Release` (manual invocation only at v1) | No (informational) |
| Canaries | Per ADR-0012 grid-health aggregator (nightly) and per ADR-0034 post-publish (on package release) | Yes post-publish (a failed canary blocks the release as broken) |

The new reusable workflows (`job-integration-tests.yml`, `job-integration-tests-containers.yml`, `job-e2e-web.yml`, `job-e2e-mobile.yml`) live in HoneyDrunk.Actions per ADR-0012's control-plane invariant.

### D12 — Closes ADR-0011 Gap 1 and Gap 3

ADR-0011 explicitly named integration tests (Gap 1) and E2E tests (Gap 3) as unresolved gaps with slots defined but no implementation pattern. This ADR closes both:

- **Gap 1 (integration tests):** D4 commits the WebApplicationFactory + Testcontainers split; D11 commits the CI jobs. The slot is filled.
- **Gap 3 (E2E tests):** D5 commits Playwright (.NET binding); D6 commits Maestro for mobile; D11 commits the CI jobs. The slot is filled.

ADR-0011's other unresolved gaps (Gap 2 SonarCloud, Gap 4 quantitative cost discipline, Gap 5 SonarCloud on private repos) are **not** addressed by this ADR; those remain ADR-0011's responsibility.

### D13 — Relationship to ADR-0044 D3 category 11 (Testing Quality)

ADR-0044 D3 category 11 (Testing Quality) binds the `review` agent to a per-PR testing checklist. The categories map to this ADR:

| ADR-0044 D3 cat 11 sub-bullet | Where the standard lives |
|---|---|
| Coverage quality (happy/failure/edge/concurrency) | D3 (per-tier thresholds) + reviewer judgment per `.claude/agents/review.md` |
| Test architecture (maintainable, not brittle) | D7 (Builders for shape) + D10 (naming/structure conventions) |
| Verification depth (unit/integration/contract/E2E) | D1 (the pyramid) + D4 (contract tests in Tier 2a) |
| Anti-patterns (testing internals, excessive mocking, non-deterministic) | D10 (no `Thread.Sleep`) + `.claude/agents/review.md` checklist |

This ADR binds the **frameworks and structural standards**; `.claude/agents/review.md` binds the **per-PR checklist that enforces them**.

### D14 — Phased rollout

- **Phase 1 (Week 1)** — Adopt the unit-test stack (xUnit + Moq + AwesomeAssertions + coverlet) as `Directory.Build.props` defaults. Migrate any Node using FluentAssertions (where the migration is mechanical — drop-in API). Establish per-tier coverage thresholds (D3) in CI gates.
- **Phase 2 (Week 2–3)** — Author `job-integration-tests.yml` (Tier 2a) in HoneyDrunk.Actions. Wire it into `pr-core.yml`. Each Node opts in by adding a `*.Tests.Integration` project; the CI job auto-discovers.
- **Phase 3 (Week 4–6)** — Author `job-integration-tests-containers.yml` (Tier 2b). Pilot on `HoneyDrunk.Data` (Testcontainers Postgres is the natural fit) and `HoneyDrunk.Kernel` (idempotency-store contract tests per ADR-0042).
- **Phase 4 (Month 2)** — Author `job-e2e-web.yml`. Pilot against `HoneyDrunk.Studios.Tests.E2E` (lowest-risk first surface). Wire nightly schedule against `dev`.
- **Phase 5 (When first mobile app ships)** — Author `job-e2e-mobile.yml` with Maestro. Zero work until then.
- **Phase 6 (Ongoing)** — BenchmarkDotNet projects added per-Node where performance matters; Azure Load Testing wiring as Notify Cloud GA approaches.

Each phase is a discrete go/no-go.

## Consequences

### Affected Nodes

- **Every Node with tests** (which is every Node) — `Directory.Build.props` updated for the unit-test stack; existing FluentAssertions usages migrate to AwesomeAssertions; coverage thresholds wired per D3.
- **HoneyDrunk.Actions** — gains four new reusable workflows (`job-integration-tests.yml`, `job-integration-tests-containers.yml`, `job-e2e-web.yml`, `job-e2e-mobile.yml`).
- **HoneyDrunk.Kernel** — gains the integration-test pattern for `IIdempotencyStore` contract tests per ADR-0042.
- **HoneyDrunk.Data** — pilot Node for Tier 2b (Testcontainers + Postgres).
- **HoneyDrunk.Studios** — pilot Node for E2E web (Phase 4).
- **HoneyDrunk.Architecture** — new section in `repos/{name}/integration-points.md` template referencing the testing tiers each Node provides.
- **`.claude/agents/review.md`** — D13 mapping baked into the Testing Quality checklist.
- **Constitution** — Invariant 14 (canaries) is preserved; the testing-pyramid framing in D1 amends the constitution to reference both pyramid and canaries explicitly.

### Invariants

Adds two:

- **Invariant: every Node has a `*.Tests.Unit` project; deployable Nodes also have `*.Tests.Integration`; HTTP-fronted Nodes also have `*.Tests.E2E`.** Missing required tier is a CI gate failure.
- **Invariant: no `Thread.Sleep` in test code.** Async work waits via primitives with timeouts. CI gate via analyzer rule.

(Final numbering assigned at constitution update time; `hive-sync` reconciles.)

### Operational Consequences

- **Existing FluentAssertions usages migrate to AwesomeAssertions.** API is drop-in for v7-compatible code; mechanical change, low risk. One-time effort per Node.
- **Tier 2b containers add CI runtime.** Docker image pulls and container startup add ~30–60s per integration test job. Mitigated by layer caching in CI; meaningful but not blocker-level cost.
- **E2E test environments need to exist.** Phase 4's Playwright pilot requires the Studios marketing site deployed to `dev`. Ahead of that being live, Phase 4 can't start. Acceptable; recorded as a dependency.
- **Mobile E2E is zero work until the first mobile app exists.** Maestro choice records the decision so the first mobile-app PR doesn't re-litigate it.
- **Coverage thresholds will surface coverage gaps.** Phase 1's Tier 0 / Tier 1 Nodes likely don't meet 85% / 75% line coverage today. The rollout includes a 30-day grace period during which thresholds are advisory (warning, not gate) so existing Nodes can backfill; after the grace window, the gate flips to blocking.
- **Performance benchmarks are manual-only at v1.** Automated regression detection is a future improvement; named as a follow-up per D9.

### Follow-up Work

- Author `job-integration-tests.yml`, `job-integration-tests-containers.yml`, `job-e2e-web.yml`, `job-e2e-mobile.yml` in HoneyDrunk.Actions (Phases 2–5).
- Migrate existing FluentAssertions usages to AwesomeAssertions across all Node repos (Phase 1).
- Add `coverlet.runsettings` files per Node with the D3 thresholds.
- Author the `Directory.Build.props` defaults for the unit-test stack.
- Pilot Tier 2b on HoneyDrunk.Data and HoneyDrunk.Kernel (Phase 3).
- Pilot E2E on HoneyDrunk.Studios when the marketing site is deployed (Phase 4).
- Add the analyzer rule that fails on `Thread.Sleep` in test projects.
- Update `.claude/agents/review.md` Testing Quality checklist per D13.
- Update `constitution/invariants.md` with the two new invariants.
- Author an integration-test scaffold template for `scope` agent to use when packets imply integration test work.

## Alternatives Considered

### Stick with FluentAssertions v8 and pay the commercial license

Considered. FluentAssertions v8 is the de-facto standard; switching is non-zero cost. Rejected on principle: paying $130+/dev/year for an assertion library when AwesomeAssertions is the actively-maintained MIT fork delivering the same API is paying for a brand. The community fork's existence specifically signals that the licensing change was unwelcome; supporting the fork aligns with the Grid's broader "prefer free/open where equivalent" cost discipline (per the recent ADR-0040 / ADR-0045 / ADR-0046 pivot to cost-aware defaults).

### Downgrade to xUnit's native assertions

Considered. Always-free, no library dependency. Rejected because xUnit's native assertions are materially less expressive (`Assert.Equal(expected, actual)` vs `actual.Should().Be(expected).Because("...")`). Test readability matters; AwesomeAssertions costs nothing.

### NSubstitute or FakeItEasy instead of Moq

Considered (the Moq SponsorLink incident in 2023 hit Moq's reputation). Rejected at v1 because the codebase already uses Moq and migration cost exceeds the marginal benefit at current scale. Documented as a future-amendment option if Moq's stewardship problems recur; NSubstitute is the leading alternative if/when that happens.

### Shouldly instead of AwesomeAssertions

Considered. Shouldly is free, well-maintained, slightly different API (`.ShouldBe()` vs `.Should().Be()`). Rejected on continuity: AwesomeAssertions preserves the FluentAssertions API the codebase already knows, no rewrite cost. Reconsidered if AwesomeAssertions stewardship lapses.

### Appium for mobile E2E

Considered. Mature, multi-platform, the legacy standard. Rejected on complexity: Appium's setup, driver management, and verbose API are a maintenance tax a solo-dev shop pays daily. Maestro's declarative YAML is materially less code to write and maintain.

### Detox for mobile E2E

Considered. Strong story for React Native. Rejected because the mobile platform isn't decided — Detox locks the platform choice to RN. Maestro stays platform-agnostic.

### Native XCUITest + Espresso

Rejected. Two codebases for the same logical tests. Solo-dev maintenance cost.

### k6 or Locust for load testing

Considered. Both are excellent open-source load-testing tools. Rejected on the existing-relationship argument (per the ADR-0040 pivot logic) — Azure Load Testing leverages the Azure subscription already in place and integrates with Azure Monitor, removing the operational surface of running k6/Locust workers. Reconsidered if Azure Load Testing's free tier becomes the bottleneck.

### Defer integration-test pattern until ADR-0042 lands

Rejected. ADR-0042 is itself in this PR; its idempotency-store contract test is one of the first concrete cases that needs Tier 2a wiring. Defer-and-discover would land idempotency without integration coverage.

### Defer E2E tooling until first mobile/web product is closer to ship

Rejected for web (Studios marketing site exists per ADR-0029; the E2E gap is current). Accepted in practice for mobile (Phase 5 is "when the first mobile app ships") — the tool decision is recorded so it isn't re-litigated under deadline.

### Skip the canary formalization (Invariant 14 already covers it)

Considered. Invariant 14 already establishes canaries; this ADR's D8 is largely codification. Rejected because the original invariant doesn't bind tooling, file location, or post-publish invocation. D8 makes the pattern concrete enough for `scope` agent to author canary-creation packets without re-inventing the structure.

### Establish testing patterns as a per-Node decision rather than Grid-wide

Rejected. Per-Node testing drift is exactly the symptom this ADR addresses. Grid-wide commitment to a stack (xUnit + Moq + AwesomeAssertions + Testcontainers + Playwright + Maestro) means the `scope` agent can write packets that assume the stack, the `review` agent can apply consistent quality checks, and contributors (human or agent) don't re-litigate tooling per PR.
