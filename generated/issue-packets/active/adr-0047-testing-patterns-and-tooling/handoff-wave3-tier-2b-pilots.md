# Wave 2 → Wave 3 Handoff — ADR-0047 Testing Patterns

**Initiative:** `adr-0047-testing-patterns-and-tooling`
**Transition:** Phase 2 (Tier 2a integration tests) → Phase 3 (Tier 2b container-backed integration tests — Data + Kernel pilots).
**Read once at the wave boundary.** Ephemeral baton pass, not a live tracker (ADR-0008 D7; immutable per invariant 24).

## What Wave 2 delivered

- **`job-integration-tests.yml` (Tier 2a)** exists in `HoneyDrunk.Actions` and is wired into `pr-core.yml` as a no-op-safe, auto-discovering, blocking tier-2 check. It runs `dotnet test` filtered to `*.Tests.Integration` and **excludes** `*.Tests.Integration.Containers`.
- **The integration-test scaffold template** exists under `issues/templates/` in `HoneyDrunk.Architecture`, capturing the ADR-0047 D4/D10 project layout, `WebApplicationFactory` (Tier 2a) and Testcontainers (Tier 2b) patterns, the `Contracts/` folder convention, and the naming/structure conventions.
- **`.claude/agents/review.md`** Testing Quality checklist enforces the ADR-0047 standards on every PR.

## What Wave 3 must do

Three packets:

1. **`09` — `HoneyDrunk.Actions`: `job-integration-tests-containers.yml` (Tier 2b).** A reusable workflow running `dotnet test --filter` for `*.Tests.Integration.Containers` projects on a Docker-capable runner (`ubuntu-latest`), with Docker-layer caching. No-op-safe. **Not wired into `pr-core.yml` Grid-wide** — Tier 2b is piloted first (per ADR-0047 D14 Phase 3); the pilot packets wire it into their Node's caller workflow.
2. **`10` — `HoneyDrunk.Data`: Tier 2b pilot.** Stand up `HoneyDrunk.Data.Tests.Integration.Containers` with a Testcontainers Postgres container (per-class `IAsyncLifetime`). Cover EF migrations applying against real Postgres, a repository round-trip, the outbox append + dispatch-claim path, and at least one Postgres-specific behavior that justifies Tier 2b. Wire `job-integration-tests-containers.yml` into Data's `pr.yml`.
3. **`11` — `HoneyDrunk.Kernel`: Tier 2b pilot.** Implement the `IIdempotencyStore` contract test once (against the abstraction), bind it to `InMemoryIdempotencyStore` in Tier 2a (`Contracts/` folder) and to the Cosmos backing in Tier 2b (`HoneyDrunk.Kernel.Tests.Integration.Containers`, Testcontainers Cosmos emulator). The contract test must pass identically for both backings. Wire `job-integration-tests-containers.yml` into Kernel's `pr.yml`.

## Interface signatures / contracts the Wave 3 work depends on

- **`job-integration-tests.yml` (packet 06)** is the pattern packet 09 mirrors — same input shape (`dotnet-version`, `runs-on`, `working-directory`, `project-path`), same no-op-safe behavior, plus a Docker-capable runner and container-layer caching.
- **The integration-test scaffold template (packet 07)** is the structural starting point for packets 10 and 11 — it encodes the `*.Tests.Integration.Containers` layout and the `IAsyncLifetime` container-lifecycle pattern.
- **`IIdempotencyStore` (ADR-0042).** Packet 11 implements a contract test against this Kernel-level abstraction from `HoneyDrunk.Kernel.Abstractions`. The contract test does NOT change `IIdempotencyStore` — it consumes it. The Cosmos backing is named `HoneyDrunk.Kernel.Idempotency.Cosmos` in ADR-0047 D4; the implementing agent must verify the actual package name against the live Kernel solution. ADR-0042 is in the Architecture repo — both repos are checked out during cloud execution (ADR-0008 D8), so the executor can read ADR-0042 for the precise `IIdempotencyStore` member surface and `IdempotencyKey` semantics.
- **The packet-01 test-stack props fragment** is consumed by both pilot projects (xUnit v2.x + NSubstitute + AwesomeAssertions + coverlet).

## Invariants in force (full text)

- **Invariant 15 (amended):** "Unit tests and in-process integration tests never depend on external services; use InMemory providers for isolation. **Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception, allowed because they are local, ephemeral, and deterministic.**" — Wave 3 IS that exception. Testcontainers dependencies (Postgres, Cosmos emulator) are permitted because they are local, ephemeral, single-tenant to the test process, and deterministic.
- **Invariant 16:** "No test code in runtime packages." — Testcontainers packages enter only the `*.Tests.Integration.Containers` projects, never a runtime `.csproj`.
- **Invariant 26:** Every packet for .NET code work must have a `## NuGet Dependencies` section; `HoneyDrunk.Standards` must be on every new .NET project with `PrivateAssets: all`.
- **Invariant 27:** "All projects in a solution share one version… excluding test projects." — The new test projects do not trigger a release.
- **Invariant 51:** "Test code contains no `Thread.Sleep`." — Container/emulator startup is slow; use Testcontainers' built-in readiness wait strategies, never a sleep.

## Wave 3 acceptance criteria

- `job-integration-tests-containers.yml` exists (Docker-capable, container-layer caching, no-op-safe, not wired Grid-wide).
- `HoneyDrunk.Data.Tests.Integration.Containers` exists, runs a Testcontainers Postgres suite on every Data PR within the `< 10min` budget, and includes at least one test demonstrating why Tier 2b exists.
- `HoneyDrunk.Kernel` has the `IIdempotencyStore` contract test running against both `InMemoryIdempotencyStore` (Tier 2a `Contracts/`) and the Cosmos backing (Tier 2b), passing identically for both.

## Sequencing notes

- Packet 09 depends softly on 06 (mirrors its pattern) — file after Wave 2.
- Packets 10 and 11 each depend **hard** on 09 (they wire its workflow into their Node's CI) and on 01 (the props fragment). Packet 11 also depends softly on 07 (the scaffold template).
- Packets 10 and 11 are mutually parallel — Data and Kernel pilots are independent.
- **Container-emulator cost note:** the Cosmos DB emulator image (packet 11) is heavier than Postgres (packet 10). The Docker-layer caching in packet 09 matters most for the Kernel pilot.
- Wave 4 (E2E web) does not start until Wave 3's exit criteria are met — Phase 4 is a discrete go/no-go per ADR-0047 D14. Wave 4 also has its own external gate: the Studios marketing site must be deployed to `dev` before the E2E pilot (packet 13) can run green.
