# Wave 1 → Wave 2 Handoff — ADR-0047 Testing Patterns

**Initiative:** `adr-0047-testing-patterns-and-tooling`
**Transition:** Phase 1 (unit-test stack + migrations + coverage gates) → Phase 2 (Tier 2a integration tests).
**Read once at the wave boundary.** This is an ephemeral baton pass, not a live tracker (ADR-0008 D7; immutable per invariant 24).

## What Wave 1 delivered

- **ADR-0047 is Accepted** (packet 00). Its D-decisions are now live rules. ADR-0011's Gap 1 (integration tests) and Gap 3 (E2E tests) are recorded as closed-by-ADR-0047.
- **`HoneyDrunk.Standards` ships the shared test stack** (packet 01): a `Directory.Build.props` fragment declaring xUnit v2.x + NSubstitute + AwesomeAssertions + coverlet, scoped to `*.Tests.*` projects. Every Node consumes this one definition.
- **`HoneyDrunk.Standards` ships the `coverlet.runsettings` tier templates** (packet 02): Tier 0 85/80 hard gate, Tier 1 75/70 hard gate, Tier 2 60/55 warn. 30-day advisory grace period documented.
- **`HoneyDrunk.Standards` ships the `Thread.Sleep` analyzer rule** (packet 03): `error` severity in `*.Tests.*` projects, enforcing invariant 51.
- **Every Node's test projects are migrated** off FluentAssertions → AwesomeAssertions (packet 04) and off Moq → NSubstitute (packet 05). No `Moq` or `FluentAssertions` `PackageReference` remains Grid-wide.

## What Wave 2 must do

Three packets, parallel-safe after Wave 1's exit criteria are met:

1. **`06` — `HoneyDrunk.Actions`: `job-integration-tests.yml` (Tier 2a) + `pr-core.yml` wiring.** A reusable workflow running `dotnet test --filter` for `*.Tests.Integration` projects, **excluding** `*.Tests.Integration.Containers`. No-op-safe in repos without an integration project. Wired into `pr-core.yml` Grid-wide as a blocking tier-2 check (safe because no-op-safe).
2. **`07` — `HoneyDrunk.Architecture`: integration-test scaffold template.** A reusable `issues/templates/` scaffold capturing the ADR-0047 D4/D10 layout, `WebApplicationFactory` / Testcontainers patterns, the `Contracts/` folder convention, and the naming/structure conventions — for the `scope` agent to use on future integration-test packets.
3. **`08` — `HoneyDrunk.Architecture`: `review.md` Testing Quality checklist.** Update the `.claude/agents/review.md` Testing Quality section per ADR-0047 D13 so the `review` agent enforces the concrete ADR-0047 standards on every PR.

## Interface signatures / contracts the Wave 2 work depends on

- **The packet-01 props fragment** defines the test-stack `PackageReference` set and the `IsTestProject=true` / `IsPackable=false` properties. Packet 06's workflow auto-discovers `*.Tests.Integration` projects — those projects are produced by Nodes consuming this fragment.
- **Test-project naming convention (ADR-0047 D4/D10):** `HoneyDrunk.<Node>.Tests.Unit` (Tier 1), `.Tests.Integration` (Tier 2a), `.Tests.Integration.Containers` (Tier 2b), `.Tests.E2E`, `.Tests.Benchmarks`. Packet 06's `dotnet test` filter keys off `Tests.Integration` and must exclude `Tests.Integration.Containers`.
- **No catalog or runtime contract change** in Wave 1 — `catalogs/contracts.json` is untouched.

## Invariants in force (full text — the executor has no Architecture-repo access)

- **Invariant 15 (amended):** "Unit tests and in-process integration tests never depend on external services; use InMemory providers (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`) for isolation. Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception, allowed because they are local, ephemeral, and deterministic." — Tier 2a (packet 06's scope) uses InMemory fakes; the Tier 2b exception is Wave 3, not Wave 2.
- **Invariant 16:** "No test code in runtime packages. Tests live in dedicated `.Tests` or `.Canary` projects only."
- **Invariant 33:** "Review-agent and scope-agent context-loading contracts are coupled. The set of files loaded by the review agent must be a superset of those loaded by the scope agent." — Packet 08 edits only the Testing Quality checklist, NOT the context-loading section, so no mirrored `scope.md` edit is triggered. If a future packet changes either agent's context-loading list, honor the coupling.
- **Invariant 50:** "Every Node has a `*.Tests.Unit` project; deployable Nodes also have a `*.Tests.Integration` project; HTTP-fronted Nodes also have a `*.Tests.E2E` project. A missing required test tier is a CI gate failure."
- **Invariant 51:** "Test code contains no `Thread.Sleep`." — Now analyzer-enforced via packet 03.

## Wave 2 acceptance criteria

- `job-integration-tests.yml` exists in `HoneyDrunk.Actions`, `workflow_call`-exposed, filtering `*.Tests.Integration` and excluding `*.Tests.Integration.Containers`; no-op-safe; wired into `pr-core.yml`.
- The integration-test scaffold template exists under `issues/templates/` capturing D4/D10.
- `.claude/agents/review.md` Testing Quality checklist enforces the ADR-0047 standards (test-project naming, required-tier coverage, `Thread.Sleep`, async-`void`, missing contract tests, `Moq`/`FluentAssertions` reintroduction).

## Sequencing notes

- Packet 06 depends softly on 00 and 01 — file after Wave 1 lands so D-decision references are live and Nodes have the fragment that produces discoverable integration projects.
- Packets 07 and 08 depend softly on 00 only — they encode Accepted decisions.
- All three Wave 2 packets are mutually parallel.
- Wave 3 (Tier 2b pilots) does not start until Wave 2's exit criteria are met — Phase 3 is a discrete go/no-go per ADR-0047 D14.
