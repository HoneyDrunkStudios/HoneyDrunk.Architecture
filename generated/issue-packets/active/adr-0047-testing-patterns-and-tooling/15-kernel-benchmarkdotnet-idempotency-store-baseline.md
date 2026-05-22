---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0047", "wave-6"]
dependencies: ["packet:01", "packet:11"]
adrs: ["ADR-0047", "ADR-0042"]
accepts: ["ADR-0047"]
wave: 6
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-kernel
---

# Add `HoneyDrunk.Kernel.Tests.Benchmarks` with a BenchmarkDotNet `IIdempotencyStore` lookup baseline

## Summary
Stand up the Grid's first BenchmarkDotNet project — `HoneyDrunk.Kernel.Tests.Benchmarks` — with an on-demand micro-benchmark that measures `IIdempotencyStore` dedup-store lookup latency, establishing the baseline that verifies ADR-0042 D2's operational claim ("single-digit ms lookup latency") and that future PRs can regress against.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Kernel`

## Motivation
ADR-0047 D9: "BenchmarkDotNet for micro-benchmarks where the hot-path performance matters. Lives in `HoneyDrunk.<Node>.Tests.Benchmarks` projects. Runs on-demand only." D9 names the exact first use case: "Verify the `IIdempotencyStore` dedup-store lookup latency is single-digit ms (per ADR-0042 D2's operational claim)." ADR-0047 D14 Phase 6 schedules BenchmarkDotNet adoption "per-Node where performance matters." The idempotency store is the highest-traffic hot path the Grid has committed an operational latency claim about, so it is the right first benchmark — it both proves the BenchmarkDotNet pattern (D9) and verifies a real ADR-0042 claim.

## Proposed Implementation
1. Create `tests/HoneyDrunk.Kernel.Tests.Benchmarks/` per ADR-0047 D10 project layout.
2. Add `BenchmarkDotNet`. The project is a console app (BenchmarkDotNet's `BenchmarkRunner.Run<T>()` entry point), built `Release`.
3. Author a benchmark class measuring `IIdempotencyStore` lookup latency:
   - Benchmark the claim/lookup hot path against `InMemoryIdempotencyStore` (the baseline; sub-millisecond expected).
   - Optionally benchmark the Cosmos backing if a stable local benchmark setup is feasible; if Cosmos requires a live emulator the benchmark may be marked `[Config]`-gated or skipped — benchmarks need a stable runner (D9), and an emulator-backed benchmark is noisy. Default scope: benchmark the InMemory backing; note Cosmos as a future addition.
   - Record the measured baseline numbers in the project `README.md` so future PRs have a reference point (D9: "Establish baselines that PRs can regress against; manual comparison").
4. **On-demand only.** Per ADR-0047 D9/D11, benchmarks are NOT in PR CI — "benchmark runs need a stable runner to produce meaningful numbers." Do not wire this into `pr-core.yml` or any PR workflow. Invocation is manual: `dotnet run -c Release` against the benchmark project.
5. Adopt the packet-01 test-stack props fragment for the analyzer/standard settings, but note BenchmarkDotNet is the runner here, not xUnit — the benchmark project is a console app, not an xUnit test project. Reference `HoneyDrunk.Standards` analyzers regardless (invariant 26).

## Affected Packages
- New project `HoneyDrunk.Kernel.Tests.Benchmarks` — a benchmark console app; test/tooling-only addition, no runtime change.

## NuGet Dependencies
New project `HoneyDrunk.Kernel.Tests.Benchmarks` `PackageReference` set:
- `BenchmarkDotNet` — current stable.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26 — mandatory on every new .NET project).
- `ProjectReference` to the Kernel runtime project exposing `InMemoryIdempotencyStore` and to `HoneyDrunk.Kernel.Abstractions`.
- Note: the benchmark project does NOT need the xUnit/NSubstitute/AwesomeAssertions stack — BenchmarkDotNet is the runner. It still references `HoneyDrunk.Standards` analyzers. The implementing agent should not blindly inherit the full packet-01 test-stack fragment if that fragment forces xUnit references onto the project; if the fragment is scoped only to `*.Tests.Unit/.Integration/.E2E` and not `*.Tests.Benchmarks`, no conflict — confirm and record in the PR.

## Boundary Check
- [x] `IIdempotencyStore` is a Kernel abstraction (ADR-0042); its benchmark belongs in `HoneyDrunk.Kernel`.
- [x] Tooling-only addition — no runtime behavior change, no contract change.
- [x] No new cross-Node runtime dependency — BenchmarkDotNet is a build/tooling dependency (invariant 16 spirit: not in runtime packages).

## Acceptance Criteria
- [ ] `tests/HoneyDrunk.Kernel.Tests.Benchmarks/` exists as a `Release`-built console app, named per ADR-0047 D10
- [ ] `BenchmarkDotNet` is referenced; the project runs via `BenchmarkRunner`
- [ ] A benchmark measures `IIdempotencyStore` lookup latency against `InMemoryIdempotencyStore`
- [ ] The measured baseline numbers are recorded in the project `README.md` as a regression reference
- [ ] The benchmark is **not** wired into `pr-core.yml` or any PR workflow — invocation is manual `dotnet run -c Release` (ADR-0047 D9/D11)
- [ ] `HoneyDrunk.Standards` analyzers referenced on the new project with `PrivateAssets: all` (invariant 26)
- [ ] Repo-level `CHANGELOG.md`: a tooling entry (invariant 12) — tooling-only, no runtime version bump (invariant 27)
- [ ] The new project has a `README.md` describing its purpose, how to run it, and the recorded baseline (invariant 12)
- [ ] The benchmark builds and runs to completion locally / on a stable runner

## Human Prerequisites
- [ ] Run the benchmark once on a stable machine to capture the baseline numbers for the README — BenchmarkDotNet results from a shared CI runner are noisy (ADR-0047 D9: "benchmark runs need a stable runner to produce meaningful numbers"). The developer or agent runs it once and records the numbers.

## Referenced ADR Decisions
**ADR-0047 D9 — Performance testing.** "BenchmarkDotNet for micro-benchmarks where the hot-path performance matters. Lives in `HoneyDrunk.<Node>.Tests.Benchmarks` projects. Runs on-demand only (not in PR CI; benchmark runs need a stable runner)." Named use: "Verify the `IIdempotencyStore` dedup-store lookup latency is single-digit ms (per ADR-0042 D2's operational claim)" and "Establish baselines that PRs can regress against."

**ADR-0047 D11 — CI integration.** Benchmarks: "On-demand `dotnet run -c Release` (manual invocation only at v1). No (informational)."

**ADR-0047 D14 Phase 6.** "BenchmarkDotNet projects added per-Node where performance matters."

**ADR-0042 D2 — operational claim.** The idempotency dedup-store lookup is claimed to be single-digit ms; this benchmark verifies it. *(The implementing agent should read ADR-0042 for the precise `IIdempotencyStore` lookup path being claimed.)*

## Constraints
- **On-demand only.** Do not wire the benchmark into any PR or scheduled CI workflow — ADR-0047 D9 is explicit; CI-runner benchmark numbers are meaningless.
- **Automated regression detection is out of scope.** ADR-0047 D9: "automated benchmark CI is future work." This packet establishes the baseline and the manual-comparison reference only.
- **Tooling-only** — no runtime change, no `IIdempotencyStore` contract change.
- **Do not force the xUnit test stack onto a BenchmarkDotNet console app** — confirm the packet-01 fragment's scoping does not collide.

## Labels
`feature`, `tier-2`, `core`, `adr-0047`, `wave-6`

## Agent Handoff

**Objective:** Stand up `HoneyDrunk.Kernel.Tests.Benchmarks` as a BenchmarkDotNet console app with an on-demand `IIdempotencyStore` lookup-latency benchmark, recording the baseline in the project README.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Prove the BenchmarkDotNet pattern and verify ADR-0042 D2's single-digit-ms idempotency-lookup claim.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 6.
- ADRs: ADR-0047 (D9, D11, D14 Phase 6), ADR-0042 (the operational latency claim under test).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:01 — the shared test-stack props fragment (for analyzer settings; confirm it does not force xUnit onto a benchmark console app).
- packet:11 — the `IIdempotencyStore` Tier 2b work establishes the contract-test surface; the benchmark targets the same abstraction. Sequence after 11.

**Constraints:**
- On-demand only — never wired into CI (ADR-0047 D9).
- Automated regression detection is out of scope — baseline + manual comparison only.
- Tooling-only — no runtime or contract change.

**Key Files:**
- `tests/HoneyDrunk.Kernel.Tests.Benchmarks/` (new console-app project)
- Its `README.md` (records the baseline numbers)
- `CHANGELOG.md` (repo-level — tooling entry)

**Contracts:** Consumes (does not change) `IIdempotencyStore` from `HoneyDrunk.Kernel.Abstractions`.
