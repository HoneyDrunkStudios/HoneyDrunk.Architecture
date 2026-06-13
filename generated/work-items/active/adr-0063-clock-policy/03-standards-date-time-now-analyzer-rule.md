---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["feature", "tier-2", "core", "adr-0063", "wave-1"]
dependencies: []
adrs: ["ADR-0063"]
wave: 1
initiative: adr-0063-clock-policy
node: honeydrunk-standards
---

# Add the analyzer rule that flags direct DateTime.UtcNow / DateTimeOffset.UtcNow in production code

## Summary
Add a Roslyn analyzer rule (proposed diagnostic id `HD0054`, matching the invariant number this packet's packet-00 sibling lands) to `HoneyDrunk.Standards.Analyzers` that flags direct invocations of `System.DateTime.UtcNow`, `System.DateTime.Now`, `System.DateTimeOffset.UtcNow`, and `System.DateTimeOffset.Now` in **production code** (anything *not* in a `*.Tests.*` project), with an `[AllowSystemClock]` (or equivalent name — see naming below) opt-out attribute for documented interop boundaries per ADR-0063 D3. The rule ships at **warning severity** initially per ADR-0063 D12; the user flips it to error once the bulk of touched code paths have migrated.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Standards`

## Motivation
ADR-0063 D1 forbids direct calls to `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, and `DateTimeOffset.Now` in production code. The "If Accepted" follow-up list names this rule explicitly: "Add a new analyzer rule (or extend `HoneyDrunk.Standards`) that flags `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, and `DateTimeOffset.Now` in non-test code, with an opt-out attribute for documented interop exceptions per D3." ADR-0063 D12 also names the migration path: "ship the rule at warning severity initially; flip to error after the natural touch points have migrated."

Without this rule, ADR-0063 D1 is a policy with no enforcement, and packet 00's invariant 54 ("Production code reads time via `TimeProvider`") would be reviewer-judgment only. ADR-0063's enforcement story is built around this rule firing at compile time.

`HoneyDrunk.Standards` already ships the Grid's analyzer pack — the `HoneyDrunk.Standards.Analyzers` project under `HoneyDrunk.Standards/HoneyDrunk.Standards/HoneyDrunk.Standards.Analyzers/` ships at least `HD0051` (the `ThreadSleepInTestsAnalyzer` for invariant 51). This new analyzer follows the same pattern.

## Proposed Implementation
The implementing agent reads the existing `ThreadSleepInTestsAnalyzer.cs` as the structural model.

1. **Diagnostic ID and severity:**
   - Proposed ID: `HD0054` (matches invariant 54 from packet 00). If the Standards repo's ID numbering convention disagrees, follow the repo's existing convention and surface the chosen ID in the PR — the invariant cross-reference still applies.
   - Initial severity: **`Warning`** (per ADR-0063 D12 — "ship the rule at warning severity initially; flip to error after the natural touch points have migrated"). Documented in the analyzer descriptor.
   - Default-enabled: yes.
2. **Banned APIs:**
   - `System.DateTime.UtcNow` (property getter)
   - `System.DateTime.Now` (property getter)
   - `System.DateTimeOffset.UtcNow` (property getter)
   - `System.DateTimeOffset.Now` (property getter)
   - These are property getters, not method invocations — register on `OperationKind.PropertyReference` (not `OperationKind.Invocation`), and inspect `IPropertyReferenceOperation.Property` for the four target getters. Compare via `SymbolEqualityComparer.Default` against the resolved property symbols on `compilation.GetTypeByMetadataName("System.DateTime")` and `compilation.GetTypeByMetadataName("System.DateTimeOffset")`.
3. **Project scoping — opposite of `HD0051`:**
   - `HD0051` (`Thread.Sleep`) fires only in **test** projects (`build_property.HD_IsGridTestProject == true`).
   - `HD0054` (this rule) fires only in **non-test** projects. Use the same `HD_IsGridTestProject` analyzer-config property and invert the check: register the analysis action only when the property is absent or `false`.
   - This is symmetric to `HD0051`: both gate off the same MSBuild property; they fire in mutually-exclusive project sets.
4. **Opt-out attribute for documented interop:**
   - Define a public `[AllowSystemClock]` attribute (or `[SystemClockUsageAllowed]`, or whatever naming the Standards repo's existing opt-out attributes use — match the repo's existing convention; if there is no existing convention, prefer `[AllowSystemClock]` as the most readable and ship a brief XML-doc).
   - Attribute target: `[AttributeUsage(AttributeTargets.Method | AttributeTargets.Constructor | AttributeTargets.Property | AttributeTargets.Class)]` — allow opt-out at the smallest reasonable scope.
   - The attribute lives in the public assembly that consumers will reference. `HoneyDrunk.Standards.Analyzers` is the analyzer assembly (netstandard2.0); attributes must live where consumer code can reference them. Likely placement: a small `HoneyDrunk.Standards` (or `HoneyDrunk.Standards.Annotations`) runtime assembly that consumers `PackageReference` alongside the analyzer. If the Standards repo already ships such an assembly, place the attribute there; if not, the implementing agent chooses the most idiomatic placement (a new shared annotations package, or extend the existing analyzers package with a public attribute type usable from C# consumers via a separate small reference assembly). The chosen placement is recorded in the PR.
   - Suppression: when the analyzer fires on a `DateTime.UtcNow` / `DateTimeOffset.UtcNow` etc. reference, it walks the enclosing symbols (method, then containing type) checking for the opt-out attribute. If found, the diagnostic is not reported. The opt-out attribute requires a `Reason` string property (or constructor argument) — the analyzer does NOT inspect the reason, but the attribute requires one as a documentation discipline. Example use:
     ```csharp
     [AllowSystemClock(Reason = "Process bootstrap log line — DI not yet up; see ADR-0063 D1.")]
     private static void LogStartupTime() => Console.WriteLine($"Started at {DateTimeOffset.UtcNow:O}");
     ```
5. **Carve-outs the rule must NOT flag:**
   - `Stopwatch.GetTimestamp()`, `Environment.TickCount`, `Environment.TickCount64` — these are elapsed-time mechanisms, explicitly out of scope per ADR-0063's "Use `Stopwatch` or `Environment.TickCount` for elapsed-time measurements" clarification. The analyzer is scoped to the four named property reads — these other APIs are not touched.
   - `TimeProvider.System.GetUtcNow()` — explicitly *the* committed call. The analyzer is keyed on `DateTime.UtcNow` / `DateTimeOffset.UtcNow` / `.Now`; `TimeProvider.GetUtcNow()` is a method call on a different type, not a property of `DateTime` or `DateTimeOffset`.
   - `DateTime.UtcNow` reads inside a `*.Tests.*` project — explicitly out of scope (test code may use direct reads where the test isn't time-dependent, or wires its own discipline via `FakeTimeProvider`).
6. **Migration discipline (per ADR-0063 D12):**
   - The rule ships at `Warning` initially. Flipping to `Error` is a one-line severity change in the `DiagnosticDescriptor`, gated on the user's judgment — not on a CI metric and not a separate packet. Document the flip path in the rule's XML-doc and in the repo `README.md`: "When the bulk of direct `DateTime`/`DateTimeOffset.UtcNow` reads have been migrated to `TimeProvider`, change `DiagnosticSeverity.Warning` to `DiagnosticSeverity.Error` and re-publish."
   - This packet does NOT migrate any existing call site. The rule fires (at warning) on every existing direct `UtcNow` read across the Grid the day after the analyzer ships; per ADR-0063 D12 those migrations are "amortized across the natural touch points" — each touching packet converts the reads it crosses. Do not include a bulk-migration sweep in this packet.
7. **Unit tests:** add tests under `HoneyDrunk.Standards.Tests` covering:
   - A non-test project reading `DateTime.UtcNow` is flagged (one diagnostic at the property-reference site).
   - A non-test project reading `DateTime.Now`, `DateTimeOffset.UtcNow`, `DateTimeOffset.Now` is flagged (one diagnostic per read).
   - A test project (`HD_IsGridTestProject = true`) reading `DateTime.UtcNow` is NOT flagged.
   - A non-test method annotated `[AllowSystemClock(Reason = "...")]` reading `DateTime.UtcNow` is NOT flagged (opt-out works).
   - A non-test method calling `TimeProvider.GetUtcNow()` is NOT flagged (correct usage).
   - A non-test method calling `Stopwatch.GetTimestamp()` and `Environment.TickCount64` is NOT flagged (carve-outs).
8. **README and CHANGELOG:**
   - Document the rule (ID, scope, severity, the `[AllowSystemClock]` opt-out, the carve-outs) in the Standards repo `README.md`.
   - Repo-level `CHANGELOG.md` — new version entry per `HoneyDrunk.Standards`'s own versioning (it sits at 0.2.9 per the Kernel `.csproj` reference; check the current Standards version at execution time and bump per its CHANGELOG cadence).
   - Per-package `CHANGELOG.md` for `HoneyDrunk.Standards.Analyzers` — describe `HD0054`, severity Warning, the opt-out attribute.

## Affected Packages
- `HoneyDrunk.Standards.Analyzers` — gains `DateTimeNowInProductionAnalyzer` (or similarly named, matching repo convention) with diagnostic `HD0054`.
- The runtime annotations assembly (whichever Standards-shipped package consumers reference for attributes; the implementing agent picks the most idiomatic placement and records it in the PR) — gains the `[AllowSystemClock]` attribute.

## NuGet Dependencies
- No new `PackageReference`. The analyzer uses `Microsoft.CodeAnalysis.*` already referenced by `HoneyDrunk.Standards.Analyzers`.
- If a new shared annotations assembly is introduced (e.g., `HoneyDrunk.Standards.Annotations`) to host the `[AllowSystemClock]` attribute, it follows the repo's existing project-creation discipline (CHANGELOG, README, `Directory.Build.props`, version aligned with the solution per invariant 27).

## Boundary Check
- [x] Grid-wide analyzer rules belong in `HoneyDrunk.Standards` — the existing `HD0051` precedent is the template (invariant 26).
- [x] No Node behavior change; this packet ships a compile-time diagnostic.
- [x] Does not duplicate any other Node's responsibility.
- [x] No analyzer fired on `TimeProvider.GetUtcNow()` (correct usage) — only the four banned property reads.
- [x] Symmetric to `HD0051`: opposite project scoping (`HD0054` fires in non-test code; `HD0051` fires in test code), same `HD_IsGridTestProject` MSBuild property gates both.

## Acceptance Criteria
- [ ] `HoneyDrunk.Standards.Analyzers` ships a new `DiagnosticAnalyzer` keyed on `OperationKind.PropertyReference` that flags `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, `DateTimeOffset.Now` reads
- [ ] Diagnostic ID is `HD0054` (or the equivalent the repo's numbering convention assigns; documented in PR)
- [ ] Severity is `DiagnosticSeverity.Warning` (per ADR-0063 D12)
- [ ] The rule fires ONLY in non-test projects (gated off `build_property.HD_IsGridTestProject` — fires when absent or `false`; suppressed when `true`)
- [ ] An `[AllowSystemClock]` (or equivalently-named) attribute exists in a consumer-referenceable assembly, with a required `Reason` string, allowed targets `Method | Constructor | Property | Class`
- [ ] The analyzer walks enclosing symbols (method → containing type) for the opt-out attribute and suppresses the diagnostic when found
- [ ] The analyzer does NOT fire on `TimeProvider.GetUtcNow()`, `Stopwatch.GetTimestamp()`, `Environment.TickCount`, or `Environment.TickCount64`
- [ ] Unit tests cover all four banned reads, the test-project carve-out, the opt-out attribute, and the correct-usage / out-of-scope-API negatives
- [ ] `HoneyDrunk.Standards/README.md` documents the rule ID, scope, severity, opt-out attribute usage, and the migration path (warning → error per ADR-0063 D12)
- [ ] Repo-level `CHANGELOG.md` and `HoneyDrunk.Standards.Analyzers/CHANGELOG.md` updated; version bumped per Standards solution cadence (invariant 27 — all `.csproj` move together)
- [ ] Build green; existing `HoneyDrunk.Standards` consumers are unaffected at *error* severity (they may see new *warnings* — that is the intended migration signal per ADR-0063 D12)
- [ ] No bulk migration of existing `DateTime.UtcNow` reads in this packet — the rule surfaces them; remediation is per-Node, packet-driven per ADR-0063 D12

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0063 D1 — `TimeProvider` is the Grid-wide clock abstraction.** Direct calls to `DateTimeOffset.UtcNow`, `DateTimeOffset.Now`, `DateTime.UtcNow`, and `DateTime.Now` are forbidden in production code. The documented exceptions: interop with libraries that demand `DateTime` directly, and process-startup-time concerns where DI is not yet available. The opt-out attribute applies to both carve-outs.

**ADR-0063 D3 — Type usage policy.** `DateTime` is banned in new code; `DateTimeOffset` is the strict replacement for instants. The analyzer flags `DateTime` usage in non-test code per the "If Accepted" follow-up checklist; the opt-out attribute permits documented interop cases.

**ADR-0063 D12 — Migration path for existing code.** "The analyzer rule has a configurable severity: at first introduction it ships as a **warning**; once the bulk of touched code paths have migrated (judged by the user, no metric committed), it flips to **error**. This is the same migration discipline applied to other Grid-wide analyzer rules."

**ADR-0063 "Use `Stopwatch` or `Environment.TickCount` for elapsed-time measurements instead of `TimeProvider`" — clarified, not rejected.** "This ADR governs wall-clock reads (`GetUtcNow()`) and time-driven decisions (TTLs, cadence, retries). Elapsed-time measurements for telemetry purposes (`Stopwatch`, `Environment.TickCount`) are out of scope; they are a Pulse/observability concern and the existing usage stands. The analyzer rule per D12 does not flag `Stopwatch` usage."

## Referenced Invariants
> **Invariant 54 — Production code reads time via `TimeProvider`.** "Direct calls to `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, or `DateTimeOffset.Now` are forbidden outside documented interop boundaries. Production composition wires `TimeProvider.System`; tests wire `Microsoft.Extensions.TimeProvider.Testing.FakeTimeProvider`. The opt-out attribute on the analyzer rule (per packet 03) permits documented interop cases. See ADR-0063 D1, D11." (Lands via packet 00 in this initiative.)

> **Invariant 56 — `DateTime` is banned in new code.** "`DateTimeOffset` is the committed type for instants; `DateOnly` for calendar dates; `TimeOnly` for wall-clock times; `TimeSpan` for durations. Exceptions for legacy interop are opt-in via the analyzer attribute. See ADR-0063 D3." (Lands via packet 00.)

> **Invariant 26 — StyleCop + EditorConfig analyzers ship from `HoneyDrunk.Standards`.** The same package owns this new analyzer.

## Constraints
- **Scope to non-test code only.** Test code may legitimately use `DateTime.UtcNow` for non-time-dependent tests (e.g., a test that constructs a sample value); firing in test projects would be a false-positive storm. The `HD_IsGridTestProject` property gates this — opposite of `HD0051`.
- **Warning severity at first introduction.** Do NOT ship at error. ADR-0063 D12 is explicit. The flip-to-error is a follow-up under user judgment, not in this packet's scope.
- **Cover all four reads.** `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, `DateTimeOffset.Now`. Both `UtcNow` and `Now` for both types.
- **Property reads, not method calls.** These are property getters in the BCL — register on `OperationKind.PropertyReference`, not `OperationKind.Invocation`.
- **Do not flag `TimeProvider.GetUtcNow()`.** That is the committed correct usage. The analyzer is keyed on the property symbols, not on the name `UtcNow` as a string — symbol-based comparison via `SymbolEqualityComparer.Default`.
- **Do not flag `Stopwatch`, `Environment.TickCount`, `Environment.TickCount64`.** ADR-0063 explicitly clarifies these are out of scope.
- **`[AllowSystemClock]` requires a `Reason` string.** Discipline-of-documentation: the analyzer does not parse the reason, but the attribute's required string forces the author to write one.
- **Do not migrate existing call sites in this packet.** ADR-0063 D12: "No bulk-migration packet is filed; the burden is amortized across the natural touch points."

## Labels
`feature`, `tier-2`, `core`, `adr-0063`, `wave-1`

## Agent Handoff

**Objective:** Add a warning-severity analyzer rule to `HoneyDrunk.Standards.Analyzers` that flags direct `DateTime.UtcNow` / `DateTime.Now` / `DateTimeOffset.UtcNow` / `DateTimeOffset.Now` reads in non-test projects, with an `[AllowSystemClock]` opt-out attribute for documented interop.

**Target:** `HoneyDrunk.Standards`, branch from `main`.

**Context:**
- Goal: Make ADR-0063 D1 (invariant 54 once packet 00 lands) enforceable at compile time across every Node. Ship at warning per D12 to enable opportunistic migration.
- Feature: ADR-0063 Date, Time, and Clock Policy rollout, Wave 1.
- ADRs: ADR-0063 (D1, D3, D12 primary).

**Acceptance Criteria:** As listed above.

**Dependencies:** None expressed in `dependencies:`. Packet 03 can land before packet 00 — the rule encodes ADR-0063 D1 regardless of whether the invariant is numbered yet. Operator-enforced merge ordering: packet 03 should merge before packet 00 (the acceptance flip), since the ADR's own "If Accepted" checklist commits the Status flip "after the analyzer rule lands."

**Constraints:**
- Non-test projects only — gated off `build_property.HD_IsGridTestProject` (opposite of `HD0051`).
- Warning severity at introduction (ADR-0063 D12), not error.
- Cover all four property reads: `DateTime.UtcNow`, `DateTime.Now`, `DateTimeOffset.UtcNow`, `DateTimeOffset.Now`.
- Register on `OperationKind.PropertyReference`, not `OperationKind.Invocation`.
- Do not flag `TimeProvider.GetUtcNow()`, `Stopwatch`, or `Environment.TickCount`.
- `[AllowSystemClock]` requires a `Reason` string property.
- No bulk migration of existing call sites — surface only.

**Key Files:**
- `HoneyDrunk.Standards.Analyzers/DateTimeNowInProductionAnalyzer.cs` (new) — model on existing `ThreadSleepInTestsAnalyzer.cs`.
- Annotations assembly — placement chosen by implementing agent; new attribute type `AllowSystemClockAttribute`.
- `HoneyDrunk.Standards.Tests/` — analyzer tests.
- `README.md`, `CHANGELOG.md` (repo-level + per-package), `.csproj` version bumps per solution cadence (invariant 27).

**Contracts:** None — build-time diagnostic. The `[AllowSystemClock]` attribute is the only consumer-facing public surface added; it ships in whatever Standards-published assembly consumers already reference for the existing analyzer set.
