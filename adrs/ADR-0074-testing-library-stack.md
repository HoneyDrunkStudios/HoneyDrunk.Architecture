# ADR-0074: Testing Library Stack — xUnit + NSubstitute + AwesomeAssertions

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / cross-cutting

## Context

[ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) (Accepted) committed the Grid's **testing patterns** — the testing pyramid, the integration-tier split, the coverage targets per Node tier, Playwright for web E2E, Testcontainers for tier-2b integration tests. ADR-0047 D2 also committed specific library picks: **xUnit + NSubstitute + AwesomeAssertions + coverlet**.

This ADR is a **specification of ADR-0047 D2** — it amends ADR-0047 by promoting the library-pick rationale from D2 prose into a standalone, frontmatter-citable decision, makes the rationale (Moq/SponsorLink, FluentAssertions v8 license, xUnit's `IClassFixture` model) load-bearing, and pins the library choices as standalone-citable defaults that future Node-standup packets and scaffolding ADRs can reference directly without re-reading ADR-0047's full body.

The amendment posture matches the precedent: [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) explicitly amends [ADR-0011](./ADR-0011-code-review-and-merge-flow.md); this ADR explicitly amends [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md).

The forcing functions for surfacing the library picks as their own ADR:

- **The library picks have stewardship-and-licensing reasoning that deserves first-class citation.** Moq's SponsorLink incident (2023) and FluentAssertions v8's commercial relicensing (October 2024) are not implementation details — they are the *reason* the Grid does not use those libraries. Burying the reasoning inside ADR-0047 D2's prose under-cites it; a standalone ADR makes the reasoning citable and stable.
- **Every new Node scaffold packet (HoneyDrunk.Identity per [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), HoneyDrunk.Files per [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md), HoneyDrunk.Cache per [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md), HoneyDrunk.Web.UI per [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md))** cites the testing-library stack in its `Directory.Build.props`. A canonical ADR is the right citation target.
- **The .NET ecosystem's library trajectory continues to surface trust events** (the broader pattern of OSS maintainers shifting licensing or stewardship under pressure). A standalone ADR creates the policy frame to evaluate the next event under, rather than re-relitigating the rationale ad hoc.
- **The `review` agent's testing-quality category per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 category 11** checks for the committed stack at PR time. Pinning the libraries as a citable ADR makes the reviewer's check unambiguous.

The charter framing ([`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 1):

> Quietly drifting into startup logic.

Stewardship and licensing are the equivalent for libraries — quietly drifting into hostile or unsustainable dependencies. The library-pick rationale exists to be an antibody against that drift; making it a standalone, citable ADR is the substrate-shaped move.

## Decision

### D1 — xUnit is the canonical test framework

**xUnit** is the test framework for every Grid test project — unit, integration (tier 2a and 2b), contract tests, and any other in-process .NET test suite.

The committed shape:

- **xUnit v2.x** for consumption stability today. xUnit v3 is in development at the time of this ADR; the Grid moves to v3 when it stabilizes and the migration cost is bounded.
- **Test project naming convention** per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D4: `HoneyDrunk.<Node>.Tests.Unit`, `HoneyDrunk.<Node>.Tests.Integration`, `HoneyDrunk.<Node>.Tests.Integration.Containers`.
- **`IClassFixture<T>` and `ICollectionFixture<T>`** for shared test-class state; parallel execution is on by default at the assembly level.
- **`Theory` + `MemberData` / `InlineData`** for data-driven tests.

**Why xUnit:**

- **Already in use.** Every existing Node's tests use xUnit. The choice is an explicit ratification of a de-facto standard, not a migration.
- **Parallel-test story is the best of the .NET-native frameworks.** xUnit's per-test-class isolation defaults make parallel execution safe out of the box; NUnit's defaults require more discipline.
- **Fixture model fits the Grid's canary patterns.** `IClassFixture` and `ICollectionFixture` map cleanly onto the per-Node contract-shape canary patterns ([ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md), [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) D7) and the Testcontainers-fixture patterns per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D4.
- **AI-assistance gradient.** Claude / Codex / Copilot pattern recognition on xUnit is deep — `[Fact]`, `[Theory]`, fixture patterns are universally well-known.
- **Long support runway.** xUnit has been the .NET community's de-facto default since ~2013; stewardship is healthy; v3 is the next major.

The negative form: NUnit is not adopted; MSTest is not adopted; TUnit is not adopted at v1.

### D2 — NSubstitute is the canonical mocking library

**NSubstitute** is the mocking library for every Grid test project. **Moq is not used for new work** and existing Moq usage migrates opportunistically.

The committed shape:

- **NSubstitute** for substitute / mock / spy patterns.
- **Standard NSubstitute syntax** — `Substitute.For<T>()`, `.Returns()`, `.Received()`, `.DidNotReceive()`, etc.
- **Per-test substitutes, not shared.** Reuse via fixtures is permitted; reuse via static state is forbidden.

**Why NSubstitute, not Moq:**

- **Moq's SponsorLink incident (August 2023) was a stewardship-trust event.** The Moq maintainer shipped undisclosed build-time telemetry (SponsorLink) that scraped developer git-config emails, hashed them, and phoned home to check sponsorship status against GitHub Sponsors. The behavior was added without changelog notice, without opt-out, and ran on every Moq-using project at build time. Under community backlash, SponsorLink was reverted. The technical revert closed the immediate breach; the trust event did not close. The question "would this maintainer ship a similar surprise again?" is not resolved by code — it is resolved by stewardship history, and that history is now suspect for the Grid's many-decade horizon ([`constitution/charter.md`](../constitution/charter.md)).
- **NSubstitute is the community's pragmatic answer.** Clean API, active maintenance, no stewardship drama. Used widely in the .NET community as the Moq alternative since the SponsorLink event.
- **Migration cost is mechanical.** Moq → NSubstitute is a syntax translation. The capability surface is equivalent for the patterns the Grid uses. The migration cost is paid once per file; the trust cost of staying on Moq compounds with every release.
- **The charter's many-decade horizon makes stewardship-history weight high.** A library the Grid uses for 30 years should be one whose maintainers the Grid trusts for 30 years. NSubstitute's track record is clean; Moq's is no longer.

**Why not FakeItEasy:** Considered as the third credible mocking option for .NET. Less ecosystem mindshare than NSubstitute in 2026; comparable capability. The pick-the-default exercise lands on NSubstitute on AI-assistance-gradient grounds (NSubstitute's pattern recognition in 2026 AI tools is deeper than FakeItEasy's).

**Migration discipline.** Existing Moq usage is not retroactively migrated under this ADR (mass refactor is exactly the architecture-as-procrastination failure mode the charter warns against). Migration happens when a file with Moq is being touched for other reasons; the rule is "new tests use NSubstitute; existing Moq tests migrate when touched."

### D3 — AwesomeAssertions is the canonical assertion library

**AwesomeAssertions** is the assertion library for every Grid test project. **FluentAssertions v8+ is not used** due to its commercial-license requirement; AwesomeAssertions is the MIT-licensed community fork of FluentAssertions v7 that the Grid adopts.

The committed shape:

- **AwesomeAssertions** as the package.
- **API is drop-in compatible with FluentAssertions v7.** Existing test code using `result.Should().Be(...)` patterns transfers unchanged.
- **Standard fluent-assertion patterns** — `Should().Be()`, `Should().NotBeNull()`, `Should().HaveCount()`, `Should().Throw<T>()`, etc.

**Why AwesomeAssertions, not FluentAssertions:**

- **FluentAssertions v8 (October 2024) moved to a paid commercial license.** Versions 8.0+ require a commercial license for "commercial use." The Grid is operated by a commercial entity (HoneyDrunk Studios LLC per [BDR-0001](../business/decisions/BDR-0001-mailbox-service-replacement.md) context); the use is therefore commercial. The per-developer pricing tier is small in absolute terms but the principle is the issue — the Grid's many-decade horizon makes commercial-license dependencies hostile by default, regardless of price.
- **AwesomeAssertions is the MIT-licensed fork of v7.** The fork captures the v7 API surface (which is what FluentAssertions has always been good at) without inheriting v8's licensing posture. Stewardship is community-driven; active maintenance; no current license-trajectory concerns.
- **Drop-in compatibility means migration is mechanical or even invisible.** Tests written against FluentAssertions v7 work with AwesomeAssertions with at most a `using` change.
- **Stewardship principle.** Same as D2's Moq → NSubstitute reasoning. The Grid favors libraries with healthy stewardship and permissive licensing over libraries whose maintainers have demonstrated willingness to charge or restrict downstream.
- **The technical-equivalence test passes.** AwesomeAssertions does what the Grid needs — fluent assertions in xUnit tests. Adopting it does not require giving up capability.

**Why not Shouldly:** Considered as another credible fluent-assertion library. Shouldly's API is sound and its license is permissive. AwesomeAssertions wins on **continuity** — the Grid's existing test code (where it uses fluent assertions) follows FluentAssertions v7 patterns; AwesomeAssertions is the path of least migration friction. Shouldly would be a credible alternative if the Grid were greenfield; for the Grid that exists today, AwesomeAssertions is cheaper.

**Why not xUnit's native assertions:** Considered. xUnit's `Assert.Equal(expected, actual)` and friends work. The downgrade in test readability is real — fluent assertions (`result.Should().BeEquivalentTo(expected)`) are markedly easier to read in failure messages and easier to compose in chained assertions. The cost of giving up fluency for the small win of "no third-party assertion library" is asymmetric in the wrong direction.

### D4 — coverlet is the canonical coverage tool

**coverlet** is the coverage tool for every Grid test project. Per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D3 the per-Node-tier coverage thresholds are enforced via coverlet's `runsettings` file and the CI per [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) / [ADR-0032](./ADR-0032-pr-validation-policy-coverage-gate-and-nuget-flagging.md).

The committed shape:

- **`coverlet.collector`** as the test-project package.
- **`coverlet.runsettings`** per Node project for threshold and format configuration.
- **Cobertura XML** as the output format (consumed by GitHub Actions coverage reporting and any future dashboard).

**Why coverlet:** It is the .NET standard. Already in use. Stable. Integrates with `dotnet test` natively.

### D5 — Default test-project template via `Directory.Build.props`

The combined stack — **xUnit + NSubstitute + AwesomeAssertions + coverlet** — is the default unit-test configuration. Per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D10, this configuration ships via per-repo `Directory.Build.props` so every new test project inherits the stack without per-project setup.

A future scaffolding template (per the DX-baseline ADR named in [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 4.1) ships the test-project scaffold with this stack pre-wired.

### D6 — Migration discipline (when to migrate Moq → NSubstitute and FluentAssertions → AwesomeAssertions)

Existing tests using Moq or FluentAssertions are **not retroactively migrated by a cross-cutting campaign**. The migration discipline:

- **New tests use the canonical stack.** No new Moq, no new FluentAssertions.
- **Existing tests migrate opportunistically.** When a test file is being touched for other reasons (test added, test updated, refactor), the file migrates to the canonical stack as part of the change.
- **FluentAssertions v7 stays on v7 indefinitely unless migrating.** Pinning to v7 (last MIT version) is permitted as an alternative to migration. The committed default for new test code is AwesomeAssertions; existing FluentAssertions v7 code is grandfathered.
- **Moq existing code stays on the most recent SponsorLink-free version unless migrating.** Pinning is permitted; the committed default for new test code is NSubstitute.

The grandfather clause matches [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) D9's reasoning: forced cross-cutting migration is exactly the architecture-as-procrastination failure mode the charter warns against. Pin defaults for new work; let existing code migrate at natural touch points.

### D7 — Out of scope

The following are explicitly **not** decided by this ADR:

- **E2E test framework.** Playwright for web is per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D5; mobile E2E is named-but-unsolved by ADR-0047.
- **Snapshot / approval testing.** Tools like Verify.NET are permitted on a per-Node basis; not adopted Grid-wide.
- **Load / performance testing.** Tools like NBomber, k6 are permitted; not adopted Grid-wide.
- **Mutation testing.** Stryker.NET is permitted on a per-Node basis; not committed.
- **BDD / SpecFlow.** Not adopted. The Grid's discipline favors imperative xUnit tests over Gherkin-shaped specs.
- **Property-based testing.** FsCheck / Hedgehog are permitted on a per-Node basis where they earn their keep; not Grid-wide.

## Consequences

### Affected Nodes

- **Every Node with a test project** — receives the canonical stack as the default. Most Nodes already use xUnit; the migration to NSubstitute and AwesomeAssertions is opportunistic per D6.
- **[ADR-0047](./ADR-0047-testing-patterns-and-tooling.md)** — this ADR amends ADR-0047 D2. The amendment is additive (the library picks are unchanged; this ADR makes them standalone-citable).
- **Future Node standups** ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md), [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md), [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md)) — each Node scaffolds with the canonical test-library stack from day one.
- **HoneyDrunk.Actions reusable workflows** — `pr-core.yml` tier 1 and tier 2 jobs run `dotnet test` against test projects using the canonical stack.

### Invariants

The following are committed conventions enforced at PR review by the `review` agent's testing-quality category per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 category 11:

- **New test code uses xUnit + NSubstitute + AwesomeAssertions + coverlet.**
- **Moq is not introduced into new test files.**
- **FluentAssertions v8+ is not introduced** (v7 is grandfathered per D6).
- **Test projects follow the naming convention from [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) D4.**

If the scope agent judges any of these invariant-class at acceptance time, numbering is added to `constitution/invariants.md` then. The numbering interacts with the proposed Invariants 50-51 framing from [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) (test-discipline invariants); coordination at acceptance.

### Operational Consequences

- **The Grid's test stack is now load-bearing-citable.** Every Node scaffold cites this ADR; every PR-review check cites this ADR; the operator does not re-derive the stack per Node.
- **Stewardship-trust principle is documented.** The Moq SponsorLink and FluentAssertions licensing events have a citable Grid record. Future stewardship events are evaluated under this ADR's frame rather than from scratch.
- **Migration cost is bounded and opportunistic.** No mass refactor; per-file migration when files are touched anyway.
- **AI-assistance leverage is preserved.** Claude / Codex / Copilot have deep pattern recognition on xUnit + NSubstitute + AwesomeAssertions in 2026. The stack is in the AI-assistance gradient.
- **Test-readability is preserved.** AwesomeAssertions inherits FluentAssertions v7's API; the fluency the Grid's tests already use carries forward.
- **License posture is clean.** All canonical libraries are MIT or permissive-equivalent. No commercial-license downstream dependencies in the test layer.

### Follow-up Work

- Ratify the canonical stack in every per-Node `Directory.Build.props`.
- The scaffolding template (per the DX-baseline ADR) ships the canonical stack pre-wired.
- The `review` agent's checklist is updated to enforce the canonical stack on new test code.
- Existing Moq-using and FluentAssertions-using Node tests carry an explicit "grandfathered per ADR-0074 D6" note in their `boundaries.md`.
- Watch list: xUnit v3 stabilization (migration target when ready); AwesomeAssertions stewardship trajectory (continues to be MIT-licensed and maintained); NSubstitute stewardship trajectory (no concerns today); the next .NET test-library stewardship event (evaluated under this ADR).

## Alternatives Considered

### Stay on Moq for mocking

Considered. The argument: Moq is the .NET-community-default; the SponsorLink incident was technically reverted; staying on the de-facto standard minimizes per-Node migration discipline.

Rejected per D2. The trust event was not closed by the technical revert. A library that shipped undisclosed build-time telemetry once might do so again; the Grid's many-decade horizon weights stewardship-history heavily. The migration cost is bounded (per D6, opportunistic, not campaign-driven); the trust cost of staying compounds with every release.

### Stay on FluentAssertions v7 (last MIT version), pinned indefinitely

Considered. The argument: v7 is MIT-licensed; pinning avoids both the migration cost and the AwesomeAssertions dependency.

Permitted per D6 as a grandfather clause for existing code; not adopted as the default for new code. The reason new code uses AwesomeAssertions: v7 is unmaintained (the v7 line stopped receiving updates when v8 launched as the commercial successor); AwesomeAssertions is the actively-maintained MIT continuation. Adopting v7 as the default forces every new Node to consume a known-unmaintained version; AwesomeAssertions is the better default.

### Pay for FluentAssertions v8 commercial license

Considered. The argument: the per-developer pricing is small; the migration cost to AwesomeAssertions is non-zero.

Rejected. The price is not the issue; the principle is. The Grid's many-decade horizon makes commercial-license dependencies hostile by default — every future contributor (the operator, the operator's collaborators, AI agents acting on the operator's behalf) is bound by the license, and the licensor controls the terms. Permissive licenses are the right substrate posture for a workshop intended to outlive any single vendor relationship.

### Switch to Shouldly instead of AwesomeAssertions

Considered. Shouldly is permissive-licensed, actively maintained, technically sound.

Rejected per D3 on continuity grounds. The Grid's existing fluent-assertion code uses FluentAssertions v7 patterns; AwesomeAssertions is drop-in compatible; Shouldly is not. The migration cost of moving to Shouldly is higher than the migration cost of moving to AwesomeAssertions for tests that already use fluent assertions. If the Grid were greenfield, Shouldly would be a credible default; for the Grid that exists, AwesomeAssertions wins.

### Use FakeItEasy for mocking instead of NSubstitute

Considered. FakeItEasy is the third credible .NET mocking library; permissive-licensed; technically sound.

Rejected per D2 on ecosystem-and-AI-gradient grounds. NSubstitute has wider community adoption in 2026; AI tools have deeper pattern recognition on NSubstitute's `Substitute.For<T>()` idiom than on FakeItEasy's `A.Fake<T>()` idiom. For a solo-dev shop running on the AI-multiplier bet, the wider-adopted option wins.

### Adopt TUnit as the test framework instead of xUnit

Considered. TUnit is a newer .NET test framework with modern source-generated test discovery and arguably cleaner DI integration.

Rejected as immature in 2026. The Grid's existing test corpus is xUnit; the AI-assistance gradient on TUnit is markedly thinner; the long-term-viability question is open. Reconsidered if TUnit's trajectory closes the gap by 2027–2028; today xUnit is the right call.

### Adopt NUnit as the test framework instead of xUnit

Considered. NUnit is the longest-running .NET test framework; mature, well-known.

Rejected. The Grid's existing tests use xUnit; switching imposes migration cost for no win. NUnit's parallel-execution defaults are worse than xUnit's for the kinds of canary patterns the Grid uses. AI-assistance gradient is comparable but xUnit's `IClassFixture` model maps better to the Grid's fixture patterns.

### Skip the ADR; let each Node pick

Considered. The argument: testing libraries are implementation detail; the Grid should not opinionate.

Rejected. Without an ADR, each Node re-derives the choice; the Moq / FluentAssertions stewardship events have to be re-discovered each time; per-Node drift undermines the `review` agent's testing-quality check. A canonical stack with a citable ADR is the cheaper substrate posture.

## References

- [`constitution/charter.md`](../constitution/charter.md) — many-decade horizon, stewardship-trust principle
- [`constitution/invariants.md`](../constitution/invariants.md) — invariant 15 (in-memory providers for tests), proposed invariants 50/51 (test-discipline framing)
- [ADR-0011](./ADR-0011-code-review-and-merge-flow.md) — code review (testing-quality category)
- [ADR-0032](./ADR-0032-pr-validation-policy-coverage-gate-and-nuget-flagging.md) — coverage gate
- [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md), [ADR-0045](./ADR-0045-grid-wide-error-tracking.md), [ADR-0046](./ADR-0046-specialist-review-agents.md) — broader cost-and-trust-aware default pattern this ADR is consistent with
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3 category 11 — testing-quality review checks
- [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md) — testing patterns and tooling (this ADR amends D2)
- [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md), [ADR-0060](./ADR-0060-stand-up-honeydrunk-identity-node.md), [ADR-0061](./ADR-0061-stand-up-honeydrunk-files-node.md), [ADR-0071](./ADR-0071-stand-up-honeydrunk-web-ui-node.md) — Node-standup ADRs that cite this stack
- [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) cluster 4.1 — DX-baseline ADR (future home of the scaffolding template)
