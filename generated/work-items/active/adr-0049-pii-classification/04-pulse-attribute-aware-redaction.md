---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0049", "wave-3"]
dependencies: ["work-item:02"]
adrs: ["ADR-0049", "ADR-0040", "ADR-0045"]
wave: 3
initiative: adr-0049-pii-classification
node: honeydrunk-pulse
---

# Wire attribute-aware PII redaction into Pulse's Azure Monitor sink (logs, traces, errors)

## Summary
Extend `HoneyDrunk.Pulse`'s Azure Monitor sink (the `HoneyDrunk.Telemetry.Sink.AzureMonitor` package, which is what ADR-0040 refers to as `HoneyDrunk.Observe.AzureMonitor`) with attribute-aware redaction: a `LogRecordProcessor` and `SpanProcessor` reflect over emitted payloads, replace any property carrying `[PiiField(Pii | SensitivePii)]` with a redaction marker, and pass-through `[PiiField(Pseudonymous)]`. Wire the same logic into the `IErrorReporter` backing (per ADR-0045 D7). This is the load-bearing v1 enforcement point for ADR-0040 D9's PII carve-outs and ADR-0045 D7's error-channel scrubbing — binding their previously-implicit "sensitive field" concept to the `[PiiField]` attribute from packet 02.

## Context
ADRs 0040 and 0045 each described boundary-redaction obligations against an undefined "sensitive field" concept. ADR-0040 D9 lists explicit forbidden content (prompt text, completion text, recipient email addresses, message bodies) but the list is observability-scoped and assumes the emitter applies the rule manually. ADR-0045 D7 defers to ADR-0040's mechanism but adds a fallback regex pass for unstructured exception messages. Neither ADR could mechanically enforce because the field-marking discipline did not exist.

ADR-0049 D5 ties the loose threads: the redactors run against the field-marking attributes shipped in packet 02. The mechanism:

- **Log payloads** — `LogRecordProcessor` walks structured log properties at OTel emit time; `[PiiField(Pii | SensitivePii)]` triggers replacement with a redaction marker before the Azure Monitor exporter ships the line. Unstructured log message templates are scanned by a fallback regex (emails, phone shapes, JWT shapes, card numbers) per ADR-0045 D7.
- **Trace attributes** — `SpanProcessor` walks span attributes; any `[PiiField(Pii | SensitivePii)]`-marked dimension is dropped. ADR-0040 D9's Evals carve-out (`evals.sensitive=true`) keeps its exception — sensitive eval suites carry content into a dedicated Log Analytics table per ADR-0040 D9.
- **Error events** — the `IErrorReporter` backing (per ADR-0045) walks the exception's `Data` dictionary and the `ErrorContext.Tags` dictionary; any value whose declared property type carries `[PiiField]` is redacted. The exception's `StackTrace` is **never** considered PII (stack frames are code, not data — per ADR-0049 D5 explicit rule).

**Defense-in-depth principle (ADR-0049 D5).** Redaction is enforced both at the emitter (where the developer has type knowledge) and at the boundary (where the framework has reflection knowledge). Neither alone is sufficient; either alone, plus the analyzer rule from packet 03, would leak on misuse.

The Pulse Azure Monitor sink is the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package (one of the sinks under `HoneyDrunk.Pulse`'s solution). Read the existing source structure at branch time to confirm the processor/exporter layout — ADR-0040's packet 03 (which lands the OTel distro backing) may have reshaped this folder.

> **Coordination with packet 06 (PII-scrubbing canary).** Packet 06 ships the canary surface that proves this redactor works end-to-end. Packet 06 depends on this packet. Within Wave 3 they may both land in either order, but the canary cannot light up green until the redactor exists.

> **Coordination with ADR-0040 packet 05.** ADR-0040 packet 05 ("Pulse PII processors and volume-discipline canary") originally scoped a regex-based first-pass PII processor against the ADR-0040 D9 hardcoded list. That packet is sibling to this one. The two scopes overlap at the `LogRecordProcessor`/`SpanProcessor` location; the **canonical v1 implementation** is the attribute-aware path from this packet plus the regex fallback for unstructured message templates. If ADR-0040 packet 05 has already landed a regex-only processor, this packet **extends** it with attribute-aware reflection; the regex layer stays as the fallback for unstructured templates. If ADR-0040 packet 05 has not landed yet, this packet ships both layers together. Read the current state at branch time.

## Scope
- `HoneyDrunk.Pulse` repo — `HoneyDrunk.Telemetry.Sink.AzureMonitor` (or wherever ADR-0040 packet 03 placed the OTel distro backing).
- New attribute-aware redactor types:
  - `PiiAwareLogRecordProcessor` (or matching name pattern from existing sink files) — OTel `BaseProcessor<LogRecord>` that walks structured-log properties and applies redaction.
  - `PiiAwareSpanProcessor` (or matching pattern) — OTel `BaseProcessor<Activity>` that walks span attributes.
  - Shared helper class (internal) — reflects over a property bag against `PiiFieldAttribute` and `ClassificationAttribute`, returns the redacted payload.
- The `IErrorReporter` backing implementation (the Pulse-side type that consumes `IErrorReporter` calls and feeds them into Azure Monitor) — extended to walk exception `Data`, custom dimensions, and `ErrorContext.Tags` through the same shared helper. Read ADR-0045 packet 02 / packet 03 for the existing structure if those packets have landed.
- Composition wiring — the new processors are registered in the existing OTel composition extension method (the one introduced by ADR-0040 packet 03); enabled by default for the Azure Monitor sink.
- Unit tests for the shared reflection helper (covers `Pii` → marker; `SensitivePii` → marker; `Pseudonymous` → pass-through; unmarked → pass-through; nested types; dictionary values).
- Repo-level `HoneyDrunk.Pulse/CHANGELOG.md` — new minor-version entry (invariant 27 bumps the entire solution).
- Per-package CHANGELOG entry on `HoneyDrunk.Telemetry.Sink.AzureMonitor` (real change). Other packages are alignment bumps — no per-package entry.
- README update on `HoneyDrunk.Telemetry.Sink.AzureMonitor` — document the redaction behavior, the Evals carve-out, the StackTrace-is-never-PII rule.

## Proposed Implementation

1. **Reflection helper (internal).** A static internal helper class:
   ```
   internal static class PiiRedactor
   {
       public static object? Redact(string propertyName, object? value, PiiFieldAttribute? marker);
       public static IReadOnlyDictionary<string, object?> RedactBag(IReadOnlyDictionary<string, object?> bag, Type? declaredType);
       public static Activity RedactActivity(Activity activity);
       public static LogRecord RedactLogRecord(LogRecord record);
   }
   ```
   - When `marker.Category == Pii`: replace value with `***[{propertyName}]` or a consistent redaction-marker string. The exact marker string is a public-API detail — choose one (e.g. `"***"`) and document it in the README.
   - When `marker.Category == SensitivePii`: replace value with `[REDACTED:sensitive]` (per ADR-0049 D5 worked example).
   - When `marker.Category == Pseudonymous`: pass-through.
   - When `marker == null` (no attribute): pass-through.
   - Reflection over the *declared* property type — if the bag is `Dictionary<string, object>`, look up the attribute on the source-type member if available; if not (raw bag with no source-type metadata), fall through and rely on the regex fallback (item 4). Document the fall-through in the README.

2. **`PiiAwareLogRecordProcessor`** — implements `BaseProcessor<LogRecord>`. On `OnEnd(LogRecord)`, walks `record.Attributes` (or whatever the structured-property surface is in the OTel version pinned by ADR-0040 packet 03) through `PiiRedactor.RedactBag`, replacing the attribute bag with the redacted version. Mutates the record in place (per OTel processor convention) or replaces fields as the SDK requires — match the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` processor implementations.

3. **`PiiAwareSpanProcessor`** — implements `BaseProcessor<Activity>`. On `OnEnd(Activity)`, walks span attributes (Tags). Drops `[PiiField(Pii | SensitivePii)]`-marked dimensions entirely (replace with marker or remove — match the existing dropped-dimension convention in `HoneyDrunk.Telemetry.Sink.AzureMonitor`). Honors the ADR-0040 D9 Evals carve-out: when a span carries `evals.sensitive=true`, the processor SKIPS redaction on that span — Evals signals deliberately carry prompts/outputs into a dedicated Log Analytics table per ADR-0040 D9.

4. **Regex fallback for unstructured templates** — when the property name and declared type are unknown (raw `LogRecord` `Body` string templates with no structured property metadata), apply a regex pass for common PII patterns: emails, phone shapes, JWT shapes, card numbers. Per ADR-0045 D7's existing rule. If ADR-0040 packet 05 has already landed a regex-only processor, reuse its regex patterns; do not duplicate.

5. **`IErrorReporter` backing extension** — the Pulse-side implementation of `IErrorReporter` (introduced by ADR-0045 packet 02; lands in a Pulse-side package) walks:
   - Exception `Data` dictionary entries through `PiiRedactor.RedactBag`.
   - Any `ErrorContext.Tags` dictionary through `PiiRedactor.RedactBag`.
   - Exception messages through the regex fallback (per ADR-0045 D7).
   - Exception `StackTrace` is **NEVER** redacted — explicit ADR-0049 D5 rule. Document this in code comment and README.

6. **Composition wiring** — extend the existing `AddAzureMonitorTelemetry` (or matching name from ADR-0040 packet 03) DI extension to register `PiiAwareLogRecordProcessor` and `PiiAwareSpanProcessor` in the OTel processor pipeline before the Azure Monitor exporter. The redactor is **on by default**; provide a configuration option to disable it only in tightly-controlled dev/test scenarios (the default-on posture is non-negotiable for production — invariant 47 + invariants 58/59 from packet 00 enforce it).

7. **Tests.** Cover the redaction helper exhaustively:
   - `Pii` marker → value replaced with redaction marker.
   - `SensitivePii` marker → value replaced with `[REDACTED:sensitive]`.
   - `Pseudonymous` marker → value passes through unchanged.
   - No marker → value passes through unchanged.
   - Nested record with mixed markers → each property redacted independently.
   - `Dictionary<string, object>` bag with source-type metadata → markers resolved from the source type.
   - `Dictionary<string, object>` bag WITHOUT source-type metadata → falls through; documented as caller-responsibility.
   - `evals.sensitive=true` span → `PiiAwareSpanProcessor` skips redaction.
   - `StackTrace` on exception → never touched by error-reporter redactor.
   - Integration: emit a structured log record with a `[PiiField(Pii)]`-marked property; consume it through the processor pipeline; assert the redacted form appears in the test-double exporter.

8. **Version bump.** Bump every non-test `.csproj` in the `HoneyDrunk.Pulse` solution to the same new minor version in one commit (invariant 27). Repo-level `CHANGELOG.md` gets a new `[X.Y.0]` entry. Per-package CHANGELOG entry on `HoneyDrunk.Telemetry.Sink.AzureMonitor` (real change). Other packages alignment-only — no per-package entries.

## Affected Files
- `HoneyDrunk.Telemetry.Sink.AzureMonitor/` — new `PiiAwareLogRecordProcessor`, `PiiAwareSpanProcessor`, internal `PiiRedactor` helper; composition extension edit.
- The Pulse-side `IErrorReporter` backing implementation (location depends on ADR-0045's packet structure — read at branch time).
- Tests in the appropriate `*.Tests.Unit` and `*.Tests.Integration` projects.
- `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md`, `README.md`.
- Repo-level `HoneyDrunk.Pulse/CHANGELOG.md`.
- Every non-test `.csproj` in the Pulse solution — version bump.

## NuGet Dependencies
- **`HoneyDrunk.Telemetry.Sink.AzureMonitor`** — gains `PackageReference` on `HoneyDrunk.Kernel.Abstractions` at the version shipped by packet 02 (needed at runtime to reflect on `ClassificationAttribute`, `PiiFieldAttribute`, `DataClass`, `PiiCategory`). If this package already references `HoneyDrunk.Kernel.Abstractions` for `IGridContext`/correlation, version-bump the existing reference to the new minor version; do not add a duplicate.
- No other new package references.

## Boundary Check
- [x] All edits in `HoneyDrunk.Pulse`. Routing rule "telemetry, trace, metrics, logs, sink, ... Pulse, collector → HoneyDrunk.Pulse" maps exactly.
- [x] The redactor consumes `HoneyDrunk.Kernel.Abstractions` only (the attributes and enums from packet 02). No runtime dependency on `HoneyDrunk.Audit` (separate substrate per ADR-0030 — Audit has its own redactor in packet 05).
- [x] Reflection happens at the Pulse boundary — the emitter is not required to pre-redact, but may; defense-in-depth per ADR-0049 D5.

## Acceptance Criteria
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor` ships `PiiAwareLogRecordProcessor` and `PiiAwareSpanProcessor` that walk emitted payloads against `[PiiField]` markers
- [ ] `[PiiField(Pii)]`-marked property values are replaced with a documented redaction marker; `[PiiField(SensitivePii)]` is replaced with `[REDACTED:sensitive]`; `[PiiField(Pseudonymous)]` passes through
- [ ] `evals.sensitive=true` span attribute triggers the Evals carve-out — `PiiAwareSpanProcessor` skips redaction on that span (ADR-0040 D9)
- [ ] The Pulse-side `IErrorReporter` backing walks `Exception.Data`, custom dimensions, and `ErrorContext.Tags` through the same redactor; regex fallback applies to exception messages
- [ ] `Exception.StackTrace` is NEVER redacted (explicit ADR-0049 D5 rule); a code comment cites the rule
- [ ] Unstructured log message templates fall back to the ADR-0045 D7 regex pass; if an ADR-0040 packet 05 regex processor already exists, the patterns are reused, not duplicated
- [ ] The redactor processors are registered in the `AddAzureMonitorTelemetry` composition by default; a configuration toggle exists for dev/test only
- [ ] Unit tests cover all four marker outcomes, the Evals carve-out, the StackTrace pass-through, and the dictionary-without-source-type fall-through
- [ ] At least one integration test asserts a `[PiiField(Pii)]`-marked property is redacted end-to-end through the processor pipeline to a test-double exporter
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor` adds (or version-bumps the existing) `PackageReference` to `HoneyDrunk.Kernel.Abstractions` at the packet-02 version
- [ ] Every non-test `.csproj` in the Pulse solution is at the new same minor version in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[X.Y.0]` entry; `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md` has a per-package entry; other packages have NO per-package entries (alignment bumps only)
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor/README.md` documents the redaction behavior, the Evals carve-out, and the StackTrace-pass-through rule

## Human Prerequisites
- [ ] **CRITICAL — Pulse runtime code must exist before this packet can execute.** `HoneyDrunk.Pulse` is currently `signal: Seed` in `catalogs/nodes.json` at authoring time (2026-05-24). The runtime targets this packet edits (`HoneyDrunk.Telemetry.Sink.AzureMonitor`, the Pulse-side `IErrorReporter` backing, the `AddAzureMonitorTelemetry` composition extension) are commitments of ADR-0040 (Telemetry Backend and Retention) and ADR-0045 (Grid-Wide Error Tracking) that have **not yet shipped runtime code**. This packet is **blocked on cross-init prereqs**:
  - **ADR-0040 standup must have shipped** the OTel distro backing (the package that becomes `HoneyDrunk.Telemetry.Sink.AzureMonitor`) and the existing `LogRecordProcessor`/`SpanProcessor` plumbing.
  - **ADR-0045 standup must have shipped** the `IErrorReporter` contract and its Pulse-side backing implementation.
  - Pulse's `signal` in `catalogs/nodes.json` must have advanced from `Seed` to at least `Standup` with the runtime packages on the package feed.
  - Verify all three at branch time before opening any branch on `HoneyDrunk.Pulse`. If any is incomplete, **do not execute this packet** — file the dependency back in the dispatch plan and surface to the Studio operator. The reviewer flagged this packet as blocked on Seed-signal repos; respecting that block is mandatory.
- [ ] **Confirm the published version of `HoneyDrunk.Kernel.Abstractions` carrying the packet-02 attributes is on the package feed before this packet's branch builds against it.** Agents merge code but never push git release tags — the Kernel solution release that ships the `[Classification]`/`[PiiField]` attributes is a human action between packet 02 merging and this packet building. If the published version is not yet on the feed at branch time, this packet's CI will fail at restore; wait until the publish lands.

## Referenced ADR Decisions
**ADR-0049 D5 — Boundary redaction at telemetry.** Telemetry traces: `SpanProcessor` walks attribute payloads, drops `[PiiField(Pii | SensitivePii)]`-marked dimensions; Evals `evals.sensitive=true` carve-out preserved. Telemetry logs: `LogRecordProcessor` walks structured log properties; `[PiiField]` triggers replacement with a redaction marker; unstructured log message templates fall back to a regex (emails, phone shapes, JWT shapes, card numbers) per ADR-0045 D7. Telemetry errors: exception `Data` dictionary and `ErrorContext.Tags` walked; values whose property type carries `[PiiField]` redacted; `StackTrace` is never considered PII.

**ADR-0049 D5 — Defense-in-depth principle.** Redaction is enforced both at the emitter (where the developer has type knowledge) and at the boundary (where the framework has reflection knowledge). Neither alone is sufficient; this packet ships the boundary half.

**ADR-0040 D9 — PII carve-outs in observability.** Prompt text, completion text, recipient email addresses, message bodies are forbidden in trace attributes and log properties — unless the `evals.sensitive=true` carve-out applies (sensitive Eval suites route content into a dedicated Log Analytics table per ADR-0040 D9).

**ADR-0045 D7 — Error-channel PII scrubbing.** Exception messages and custom dimensions stripped of common PII patterns via regex pre-export; defers to ADR-0040 D9's mechanism for the structured side. This packet replaces the "defers to ADR-0040" abstraction with a concrete shared redactor.

**Invariant 47 (amended in packet 00).** "Data-change details that include sensitive fields (as defined by ADR-0049 D2 — fields marked `[PiiField(SensitivePii)]`) must be redacted before append." The audit-side redactor is packet 05; this packet handles the telemetry-side redaction. Both are required for defense-in-depth.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The redactor is one of the load-bearing enforcement mechanisms. Secrets at the BCL/string level (raw API keys, JWT bearer tokens) are also covered by the regex fallback.

## Constraints
- **Defense-in-depth, not in-place replacement.** This packet adds the boundary redactor. Emitters may pre-redact; the boundary defends regardless.
- **`evals.sensitive=true` carve-out is mandatory.** The Evals Node's sensitivity flag is a contract; do not break it. The processor checks the span attribute and skips redaction on the entire span (per ADR-0040 D9).
- **StackTrace is never PII.** Stack frames are code, not data. Explicit ADR-0049 D5 rule; do not be tempted to scrub.
- **The redactor is on by default.** Configuration toggle exists only for dev/test scenarios. Production composition must not disable it.
- **No duplicate regex patterns.** If ADR-0040 packet 05 has already shipped a regex-only processor, this packet reuses those patterns (extract to a shared internal class if necessary). Do not re-author the regex set.
- **Invariant 27 — Solution-version bump.** Every non-test `.csproj` to the same new minor version in one commit.
- **Invariant 12 — Per-package CHANGELOG only for `HoneyDrunk.Telemetry.Sink.AzureMonitor`** (real change). Other Pulse packages are alignment bumps.
- **`PackageReference` to `HoneyDrunk.Kernel.Abstractions`** at the packet-02-published version. If a prior reference exists, version-bump it; do not duplicate.

## Labels
`feature`, `tier-2`, `ops`, `adr-0049`, `wave-3`

## Agent Handoff

**Objective:** Ship attribute-aware PII redaction in Pulse's Azure Monitor sink and the Pulse-side `IErrorReporter` backing.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Bind the previously-implicit "sensitive field" concept in ADR-0040 D9 and ADR-0045 D7 to the field-marking attributes from packet 02, with defense-in-depth at the boundary.
- Feature: ADR-0049 Data Classification rollout, Wave 3 (Phase 3 redactor integrations).
- ADRs: ADR-0049 D5 (primary), ADR-0040 D9 (forbidden content + Evals carve-out), ADR-0045 D7 (error-channel scrubbing).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:02` — `ClassificationAttribute` and `PiiFieldAttribute` exist in `HoneyDrunk.Kernel.Abstractions` and are published to the package feed.

**Constraints:**
- Defense-in-depth at the boundary; emitters may pre-redact. The boundary redactor is on by default.
- Evals carve-out (`evals.sensitive=true` span attribute) skips redaction; do not break it.
- StackTrace is never redacted. Explicit ADR-0049 D5 rule.
- Reuse ADR-0040 packet 05's regex patterns if that packet has shipped; do not duplicate.
- Invariant 27 bump on the Pulse solution; per-package CHANGELOG entry only on `HoneyDrunk.Telemetry.Sink.AzureMonitor`.
- The redactor's `PackageReference` to `HoneyDrunk.Kernel.Abstractions` must match the packet-02-published version.

**Key Files:**
- `HoneyDrunk.Telemetry.Sink.AzureMonitor/` — new processors and internal redactor helper.
- Pulse-side `IErrorReporter` backing (location depends on ADR-0045 packet placement — read at branch time).
- Tests in `HoneyDrunk.Pulse`'s test projects.
- `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md`, `README.md`; repo-level `CHANGELOG.md`.

**Contracts:**
- `PiiAwareLogRecordProcessor` (new) — OTel `BaseProcessor<LogRecord>` consuming `[PiiField]` markers.
- `PiiAwareSpanProcessor` (new) — OTel `BaseProcessor<Activity>` consuming `[PiiField]` markers; Evals carve-out aware.
- Internal `PiiRedactor` helper shared across processors and error reporter.
