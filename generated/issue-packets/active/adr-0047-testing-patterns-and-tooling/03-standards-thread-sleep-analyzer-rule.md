---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "ops", "adr-0047", "wave-1"]
dependencies: ["packet:01"]
adrs: ["ADR-0047"]
accepts: ["ADR-0047"]
wave: 1
initiative: adr-0047-testing-patterns-and-tooling
node: honeydrunk-standards
---

# Add the analyzer rule that fails the build on `Thread.Sleep` in test projects

## Summary
Add an analyzer rule to `HoneyDrunk.Standards` that flags any use of `System.Threading.Thread.Sleep` inside `*.Tests.*` projects as a build error, enforcing ADR-0047 D10 and the already-landed invariant 51 ("Test code contains no `Thread.Sleep`").

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Standards`

## Motivation
ADR-0047 D10 states "No `Thread.Sleep`. … `Thread.Sleep` is a CI flakiness multiplier." The ADR Consequences section names "Add the analyzer rule that fails on `Thread.Sleep` in test projects" as explicit follow-up work, and invariant 51 (already landed, commit 120f39d) makes it a CI gate: "Enforced by an analyzer rule on test projects." `HoneyDrunk.Standards` already owns the Grid-wide analyzer set (invariant 26 — "StyleCop + EditorConfig analyzers"), so the rule belongs there. Without it, invariant 51 is a rule with no enforcement, and the review agent's Testing Quality checklist (ADR-0044 D3 category 11 / ADR-0047 D13) would carry the burden manually.

## Proposed Implementation
`HoneyDrunk.Standards` is the Grid's modeled analyzer home (`repos/HoneyDrunk.Standards/`, `catalogs/nodes.json` id `honeydrunk-standards`) — it already ships the StyleCop + EditorConfig analyzer set referenced Grid-wide (invariant 26, invariant 58). The `Thread.Sleep` rule is the same class of artifact and belongs in the same analyzer package.

Two viable enforcement mechanisms — both ship from the existing `HoneyDrunk.Standards` analyzer package. The implementing agent picks based on whether the package already consumes the banned-API analyzer, and records the choice in the PR:

**Option A — Roslyn analyzer (preferred when no banned-API analyzer is present).** Add a `DiagnosticAnalyzer` to the existing `HoneyDrunk.Standards` analyzer assembly that reports a diagnostic (e.g. `HD0051`) on any invocation of `Thread.Sleep` (and `Thread.Sleep(TimeSpan)`). Scope it to test projects: the analyzer keys off the `IsTestProject` MSBuild property (set by packet 01's props fragment) surfaced via a `build_property` analyzer-config value, OR the diagnostic is registered with default severity `none` and the test-stack props fragment from packet 01 raises it to `error` for `*.Tests.*` projects. The diagnostic severity must be `error` in test projects so it fails the build.

**Option B — Banned API analyzer (preferred when `Microsoft.CodeAnalysis.BannedApiAnalyzers` is already in the `HoneyDrunk.Standards` analyzer stack).** Add `T:System.Threading.Thread; M:System.Threading.Thread.Sleep` entries to a `BannedSymbols.txt` that ships only to `*.Tests.*` projects via the test-stack props fragment (packet 01). This is the lower-effort option when the banned-API analyzer is already present — check the `HoneyDrunk.Standards` analyzer package's existing `PackageReference` set first.

Either way:
1. The rule must fire only on test projects — runtime code may legitimately use `Thread.Sleep` and must not be flagged.
2. The rule must be `error` severity in test projects (build-breaking), per invariant 51 "is a CI gate failure."
3. Both `Thread.Sleep(int)` and `Thread.Sleep(TimeSpan)` overloads are covered.
4. Document the rule, its ID, and the approved alternatives (`await`, polling primitives with explicit timeouts, synchronously-completing fakes) in the repo `README.md`.

## Affected Packages
- `HoneyDrunk.Standards` — gains the analyzer rule (or banned-symbols entry) and ships it to test projects.

## NuGet Dependencies
- If Option A: no new `PackageReference` — the analyzer is added to the existing `HoneyDrunk.Standards` analyzer assembly, which already targets the Roslyn analyzer SDK.
- If Option B: `Microsoft.CodeAnalysis.BannedApiAnalyzers` if not already referenced — add it to the analyzer-hosting project with `PrivateAssets: all`.
- Any new `.csproj` created in `HoneyDrunk.Standards` must reference `HoneyDrunk.Standards` analyzers with `PrivateAssets: all` per invariant 26.

## Boundary Check
- [x] Grid-wide analyzer rules belong in `HoneyDrunk.Standards` (invariant 26 — it owns the StyleCop + EditorConfig analyzer set).
- [x] No Node behavior change; this packet ships a build-time diagnostic.
- [x] Does not duplicate any other Node's responsibility.

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards` ships an analyzer rule (Roslyn diagnostic or banned-API entry) that flags `Thread.Sleep(int)` and `Thread.Sleep(TimeSpan)`
- [ ] The rule is `error` severity in `*.Tests.*` projects and does NOT fire on runtime (`src/`) projects
- [ ] A test project containing `Thread.Sleep` fails to build; the same call in a runtime project builds clean
- [ ] The rule ships to test projects through the packet-01 test-stack props fragment (no per-Node opt-in beyond consuming that fragment)
- [ ] Repo `README.md` documents the rule ID, scope, and the approved alternatives (`await`, polling-with-timeout, synchronous fakes)
- [ ] Repo-level `CHANGELOG.md` updated — append to the in-progress version entry from packet 01 (invariants 12, 27); per-package `CHANGELOG.md` updated for the analyzer package
- [ ] Build green; existing `HoneyDrunk.Standards` consumers unaffected

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0047 D10 — No `Thread.Sleep`.** "Tests that need to wait for async work use `await`, polling primitives with timeout, or fakes that complete synchronously. `Thread.Sleep` is a CI flakiness multiplier."

**ADR-0047 D13 — Relationship to ADR-0044 D3 category 11.** The Testing Quality checklist sub-bullet "Anti-patterns (testing internals, excessive mocking, non-deterministic)" maps to "D10 (no `Thread.Sleep`) + `.claude/agents/review.md` checklist." This analyzer makes the `Thread.Sleep` half of that anti-pattern check a compile-time failure rather than a reviewer-judgment call.

## Referenced Invariants
> **Invariant 51 — Test code contains no `Thread.Sleep`.** "Async work waits via `await`, polling primitives with explicit timeouts, or synchronously-completing fakes. `Thread.Sleep` is a CI flakiness multiplier. Enforced by an analyzer rule on test projects." (Already landed in `constitution/invariants.md`, commit 120f39d. This packet builds the enforcing analyzer.)

> **Invariant 16 — No test code in runtime packages.** Relevant inversely: the analyzer must NOT flag runtime projects, only `*.Tests.*` projects.

## Constraints
- **Scope to test projects only.** Runtime code may use `Thread.Sleep` legitimately. Firing on `src/` projects would be a false-positive storm and is wrong.
- **`error` severity, not `warning`.** Invariant 51 makes this a CI gate failure — a warning would not gate.
- **Cover both overloads** — `Thread.Sleep(int)` and `Thread.Sleep(TimeSpan)`.
- Do not migrate any existing `Thread.Sleep` call in this packet — the analyzer surfaces them; remediation is per-Node test-hardening work outside this initiative.

## Labels
`feature`, `tier-2`, `ops`, `adr-0047`, `wave-1`

## Agent Handoff

**Objective:** Add a build-breaking analyzer rule to `HoneyDrunk.Standards` that fails any `*.Tests.*` project containing `Thread.Sleep`, enforcing ADR-0047 D10 / invariant 51.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Make invariant 51 enforceable at compile time across every Node.
- Feature: ADR-0047 Testing Patterns and Tooling initiative, Phase 1.
- ADRs: ADR-0047 (D10, D13).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- packet:01 — the rule ships to test projects via the test-stack props fragment. Sequence after 01.

**Constraints:**
- Test projects only — never flag runtime `src/` code.
- `error` severity (build-breaking), not warning.
- Cover `Thread.Sleep(int)` and `Thread.Sleep(TimeSpan)`.
- Do not remediate existing `Thread.Sleep` calls — surface them only.

**Key Files:**
- `HoneyDrunk.Standards` analyzer assembly (Option A) or `BannedSymbols.txt` (Option B).
- The packet-01 test-stack props fragment — wire severity/shipping here.
- `README.md`, `CHANGELOG.md` (repo-level + per-package).

**Contracts:** None — build-time diagnostic, not a runtime contract.
