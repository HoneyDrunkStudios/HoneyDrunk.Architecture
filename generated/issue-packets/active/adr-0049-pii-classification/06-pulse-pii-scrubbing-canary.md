---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0049", "adr-0040", "adr-0045", "wave-3"]
dependencies: ["packet:04", "packet:05"]
adrs: ["ADR-0049", "ADR-0040", "ADR-0045"]
wave: 3
initiative: adr-0049-pii-classification
node: honeydrunk-pulse
---

# Ship the PII-scrubbing canary (closes deferred follow-ups from ADR-0040 and ADR-0045)

## Summary
Build the cross-boundary PII-scrubbing canary in `HoneyDrunk.Pulse`'s canary suite. The canary constructs sample payloads with `[PiiField(Pii)]`, `[PiiField(SensitivePii)]`, and `[PiiField(Pseudonymous)]`-marked fields, sends them through the log path (Pulse `LogRecordProcessor`), the trace path (`SpanProcessor`), the error path (`IErrorReporter`), and the audit path (`IAuditLog`). Asserts each boundary applies the correct redaction outcome. A canary failure is a CI gate failure per ADR-0034 — the package does not ship. This closes the PII-scrubbing-canary follow-up explicitly deferred in ADR-0040 and ADR-0045 and named again in ADR-0049 D4 / D10 Phase 3.

## Context
Both ADR-0040 (Telemetry Backend and Retention) and ADR-0045 (Grid-Wide Error Tracking) committed to a PII-scrubbing canary in their Follow-up Work sections but did not ship one. Without it:

- The redactor regressions from packets 04 and 05 would not be caught at CI — a future PR that "optimizes" the reflection walk and accidentally skips `SensitivePii` markers would land without a build failure.
- The Evals carve-out (`evals.sensitive=true` skips redaction in `SpanProcessor`) is a contract that needs ongoing verification — a refactor that drops the carve-out check would silently break sensitive Eval suites.
- The `IAuditLog`-rejection-on-SensitivePii path needs to stay enforced — a future change that softens the rejection to a sentinel write would violate invariant 59 silently.

ADR-0049 D4 lists "Test canaries" as the fifth attribute-consumer: "every Node ships a redaction canary that constructs sample payloads with `[PiiField]`-marked fields, sends them through the log/audit/error paths, and asserts the output is properly redacted. A canary failure blocks the package release per ADR-0034." This packet ships the **Grid-wide canary** that proves redaction works at the Pulse and Audit boundaries; per-Node canaries (e.g. for consumer-app onboarding flows) are deferred to those Nodes' standup packets per ADR-0049 D10 Phase 6.

The canary lives in Pulse because Pulse is the boundary that owns the log/trace/error redactors. The audit-boundary assertion is included for full coverage even though the audit redactor lives in `HoneyDrunk.Audit`.

> **Invariant 48 fix — Abstractions-only audit boundary in this canary.** A prior draft of this packet took a `PackageReference` from the Pulse canary test project to the **runtime** `HoneyDrunk.Audit` package so that the canary could exercise the real `AuditPayloadRedactor`. That **violates invariant 48** ("Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` is a host-time concern resolved at application startup; consumer Nodes must not reference `HoneyDrunk.Audit.Data` in production composition. Packaged testing fixtures, when introduced, are test-time only."). The "test-time only" carve-out is for packaged testing fixtures shipped *from Audit*; ad-hoc canary code in Pulse pulling the Audit runtime is not that carve-out, and the reviewer correctly flagged it.
>
> **The fix:** the Pulse canary references **only `HoneyDrunk.Audit.Abstractions`** at runtime. The audit-boundary assertions in this canary exercise `IAuditLog` via a **test-double implementation** that lives in the Pulse canary project itself — a small in-process implementation of `IAuditLog` that runs the same reflection-against-`[PiiField]` logic the production `AuditPayloadRedactor` performs, but defined as a fixture in the test project (`TestAuditLogWithRedactor` or similar). The contract being canaried is `IAuditLog`'s shape, the reject-on-SensitivePii behavior, and the `AuditPiiToken`-substitution behavior; the canary verifies that **a faithful implementation of the contract produces the documented outcomes** — that is the boundary the canary owns.
>
> **What this means for end-to-end coverage of the real `HoneyDrunk.Audit` runtime:** the real `AuditPayloadRedactor` is covered by the integration tests inside the `HoneyDrunk.Audit` repo (per packet 05's Tests scope). The Pulse-side canary covers the **contract**, not a specific implementation. If end-to-end coverage of "the same `[PiiField]`-marked record traveling from emitter through Audit runtime" is needed beyond contract coverage, it lives in a separate **Audit-repo** canary (a logical packet 06b that would live in `HoneyDrunk.Audit` and consume `HoneyDrunk.Audit.Data` legitimately as the owning Node). That is **not in scope here** — flag it as a follow-up if the contract canary proves insufficient.
>
> **Operational telemetry assertion.** The Pulse canary cannot assert that the Audit runtime emits operational telemetry to App Insights on a SensitivePii rejection (that's an Audit-side runtime concern). Instead, the canary asserts that the **`IAuditLog` test-double in this project** emits the rejection result shape that production callers depend on (typed exception or `AuditAppendResult.Rejected`, whichever the Abstractions contract carries). The "operational telemetry is emitted on rejection" assertion belongs in the Audit-repo follow-up if added.

> **Why this is a Pulse packet, not an Audit packet.** The bulk of the boundary surface (logs, traces, errors) lives in Pulse. The Audit-contract assertion is one of four assertions the canary exercises; co-locating it in Pulse minimizes the per-PR coordination cost and keeps the assertion suite in one place, while invariant 48 is preserved by the Abstractions-only reference described above.

> **Canary placement.** ADR-0042 ships its own canary in `HoneyDrunk.Kernel.Tests.Canaries`. Pulse's canary project pattern (read at branch time — likely `HoneyDrunk.Pulse.Tests.Canaries` or similar) is the right home for this one. If no Pulse canary project exists yet, create one following the Kernel pattern.

## Scope
- A new canary project in `HoneyDrunk.Pulse` (e.g. `HoneyDrunk.Pulse.Tests.Canaries` — confirm the repo's existing canary-naming convention at branch time; reuse if a canary project already exists in the solution).
- Canary test cases (one per boundary):
  - `Logs_PiiField_Pii_IsRedacted` — emit a structured log with a `[PiiField(Pii)]`-marked property; assert the marker appears in the test-double exporter output.
  - `Logs_PiiField_SensitivePii_IsRedacted` — same with `SensitivePii`; assert `[REDACTED:sensitive]` appears.
  - `Logs_PiiField_Pseudonymous_PassesThrough` — same with `Pseudonymous`; assert the raw value appears.
  - `Logs_Unmarked_PassesThrough` — assert no false positives.
  - `Traces_PiiField_Pii_IsDropped` — emit a span with a `[PiiField(Pii)]`-marked attribute; assert the dimension is dropped from the exporter output.
  - `Traces_Evals_Sensitive_CarveOut` — emit a span with `evals.sensitive=true` AND a `[PiiField(SensitivePii)]`-marked attribute; assert the attribute is preserved (carve-out applied).
  - `Errors_PiiField_Pii_InDataDict_IsRedacted` — throw an exception with a `[PiiField(Pii)]`-bearing value in `Exception.Data`; report via `IErrorReporter`; assert the redacted form appears.
  - `Errors_StackTrace_NeverRedacted` — assert the exception's `StackTrace` survives verbatim through the error reporter (explicit ADR-0049 D5 rule).
  - `Errors_RegexFallback_OnUnstructuredMessage` — exception with an email in the message; assert the regex fallback redacts it.
  - `Audit_PiiField_Pii_IsTokenized` — emit an `AuditEntry` with a `[PiiField(Pii)]`-marked Before/After through a Pulse-local test-double `IAuditLog`; assert the captured entry shows the `AuditPiiToken` form (test-double composes the same `IAuditTokenizer` seam shipped in `HoneyDrunk.Audit.Abstractions` per packet 05).
  - `Audit_PiiField_SensitivePii_RejectsAppend` — emit an `AuditEntry` with a `[PiiField(SensitivePii)]`-marked field through the same test-double `IAuditLog`; assert `AppendAsync` returns the rejection result (or throws the typed exception, matching the shape declared in `HoneyDrunk.Audit.Abstractions`); assert no entry was captured.
  - `Audit_AppendOnly_NoUpdateOrDeleteMethodAdded` — sanity assertion the `IAuditLog` interface still exposes only append/query, not update or delete (preserves invariant 47's append-only-by-interface and protects against accidental contract weakening). This assertion runs against the **published `HoneyDrunk.Audit.Abstractions` shape**, not against a runtime implementation, so it is the strongest of the four audit assertions for invariant-48 purposes.
- Canary build target — the existing Pulse canary-suite invocation in `pr-core.yml` (or whatever workflow the canaries currently fire from) picks up the new project automatically if it follows the existing test-project naming convention. If a `pr-core.yml` change is required, scope it minimally.
- Test fixture records — small sample types defined in the canary test project carrying the `[PiiField]` markers; these are test code only, not runtime types.
- Per-package CHANGELOG entry on `HoneyDrunk.Telemetry.Sink.AzureMonitor` (this packet does not ship new runtime code in that package, but the canary verifies its behavior — so its CHANGELOG only updates if the package is bumped; coordinate with packet 04's bump).
- Repo-level `CHANGELOG.md` — append to the in-progress entry started by packet 04 (per invariant 27: "the first packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only"). Packet 04 is the bumping packet for the Pulse solution in this initiative; packet 06 appends to its `[X.Y.0]` entry without re-bumping.

## Proposed Implementation

1. **Read packet 04's repo state first.** Packet 04 bumps the Pulse solution and lands the redactor. This packet is the next Pulse-touching packet in the initiative — per invariant 27 it appends to the in-progress `[X.Y.0]` CHANGELOG entry and does NOT re-bump the solution version. If packet 04 has not yet merged, this packet WAITS — building against an unfinished redactor proves nothing.

2. **Canary project setup.** Add a new test-canary project under the Pulse solution at the conventional canary-project path (read existing canary projects to confirm naming). The project takes runtime `PackageReference` on:
   - `HoneyDrunk.Kernel.Abstractions` — for the `[PiiField]` / `[Classification]` attributes on the test-fixture records.
   - `HoneyDrunk.Telemetry.Sink.AzureMonitor` — to compose the Pulse redactor pipeline.
   - `HoneyDrunk.Audit.Abstractions` — for `IAuditLog`, `IAuditTokenizer`, `AuditEntry`, `AuditPiiToken`, and the rejection-result/exception type per packet 05.
   - The standard test stack (per ADR-0047 once that lands, otherwise the existing Pulse test-project package set).
   
   **Forbidden references (invariant 48):** the canary project must NOT reference `HoneyDrunk.Audit` (the runtime package) or `HoneyDrunk.Audit.Data`. The Pulse-side canary's audit assertions exercise the **contract surface** of `HoneyDrunk.Audit.Abstractions` via a test-double that lives in this canary project; end-to-end coverage of the real Audit runtime lives in the Audit repo per packet 05's Tests scope.

3. **Test-fixture records.** Define small sample types in the canary project:
   ```csharp
   internal sealed record SampleRecipient(
       [Classification(DataClass.Restricted)]
       [PiiField(PiiCategory.Pii, Purpose = "canary:email")]
       string EmailAddress,
       
       [Classification(DataClass.Restricted)]
       [PiiField(PiiCategory.SensitivePii, Purpose = "canary:taxid")]
       string? TaxIdentifier,
       
       [Classification(DataClass.Confidential)]
       string AccountStatus,
       
       [Classification(DataClass.Restricted)]
       [PiiField(PiiCategory.Pseudonymous, Purpose = "canary:correlation")]
       string CorrelationId
   );
   ```
   These records are NEVER instantiated outside the canary project; they exist purely as the test surface.

4. **Test-double exporter / test-double audit store.** Wire OTel composition in the canary fixture to use a `InMemoryExporter` (or matching pattern from the existing Pulse test infrastructure) so the canary can read the post-redaction payload. Wire the Audit composition to use a test-double `IAuditTokenizer` (the InMemory one shipped in packet 05) and a test-double audit store (read packet 05 for the exact composition).

5. **Per-boundary tests.** For each of the test cases listed in Scope, the canary:
   - Constructs a fixture record with markers.
   - Sends it through the boundary (log/trace/error/audit).
   - Reads the exporter / audit-store state.
   - Asserts the redaction outcome.
   - On failure, the test description names the regression class clearly (e.g. "PiiField(Pii) was NOT redacted in log output — invariant 47/82 violation").

6. **Audit append-only assertion.** A reflection-based test that asserts `IAuditLog` exposes only the append/query methods named in `HoneyDrunk.Audit.Abstractions` and that no `Update`/`Delete`/`Modify`/`Erase` member has been added. Reuses the contract-shape canary pattern (invariant 49) but scoped narrowly to the append-only property.

7. **Canary CI hook.** Confirm the canary is picked up by the existing Pulse canary-test job in `pr-core.yml`. If the existing job pattern uses naming like `*Tests.Canaries` to discover projects, this packet's naming matches; if it explicitly enumerates project paths, this packet adds the new path. Coordinate minimally with `HoneyDrunk.Actions` only if a workflow change is unavoidable — most likely none is needed.

8. **CHANGELOG appending.** Append a `### Added` bullet to the in-progress `[X.Y.0]` repo-level CHANGELOG entry (started by packet 04) describing the new canary. Add a per-package CHANGELOG entry under `HoneyDrunk.Telemetry.Sink.AzureMonitor` only if that package has a real functional change in this packet — which it does not (the redactor itself shipped in packet 04, this packet ships *canary verification* of it). Per invariant 12, do not add a noise entry for an alignment-only bump. If a new canary project is added, the project's own README documents its purpose.

## Affected Files
- New canary project under `HoneyDrunk.Pulse` (e.g. `HoneyDrunk.Pulse.Tests.Canaries/PiiScrubbingCanary.cs` plus the `.csproj` if a new project is needed).
- Pulse `pr-core.yml` invocation (only if the canary discovery pattern requires it).
- Pulse repo-level `CHANGELOG.md` — append to the `[X.Y.0]` entry started by packet 04.
- The canary project's `README.md`.

## NuGet Dependencies
- New canary project — `PackageReference` to: `HoneyDrunk.Kernel.Abstractions` (packet-02 version), `HoneyDrunk.Telemetry.Sink.AzureMonitor` (in-repo project reference), `HoneyDrunk.Audit.Abstractions` (packet-05 version), `HoneyDrunk.Audit` runtime package (packet-05 version). Standard test stack per the repo's existing test-project convention. `HoneyDrunk.Standards` analyzer reference per invariant 26 (PrivateAssets: all).

## Boundary Check
- [x] Canary lives in `HoneyDrunk.Pulse` — Pulse owns the log/trace/error boundary, and the audit append is exercised as a test-time consumer.
- [x] No new runtime dependency on Pulse from any production package. The canary is test-time only.
- [x] Audit append-only assertion preserves invariant 47; no new contract surface introduced.

## Acceptance Criteria
- [ ] New canary test class in `HoneyDrunk.Pulse.Tests.Canaries` (or the existing canary-project naming convention) exercises log, trace, error, and audit boundaries
- [ ] Test cases cover every outcome class: `Pii` redacted; `SensitivePii` redacted (logs/traces/errors) and rejected (audit); `Pseudonymous` passes through; unmarked passes through; Evals carve-out preserved; StackTrace never redacted; regex fallback fires on unstructured messages
- [ ] An assertion verifies `IAuditLog` exposes no `Update`/`Delete` member (append-only-by-interface preserved per invariant 47)
- [ ] The canary is picked up by the existing Pulse canary CI job; no `pr-core.yml` change is required, OR if a workflow change is unavoidable, it is scoped minimally and documented
- [ ] A failing canary fails the build at the tier-1 gate per ADR-0034
- [ ] Pulse repo-level `CHANGELOG.md` has a new bullet under the `[X.Y.0]` entry started by packet 04 describing the new canary
- [ ] No new per-package CHANGELOG noise entry is added (the canary is test-time verification of packet 04's runtime change — no functional change in the runtime package per invariant 12)
- [ ] No re-bump of the Pulse solution version — packet 04 is the bumping packet; this packet appends only (invariant 27)

## Human Prerequisites
- [ ] **Confirm packet 04 has merged on Pulse and packet 05 has merged on Audit and both have been released to the package feed.** This canary builds against the redactor implementations from those packets. Building against unpublished packages will fail at restore.

## Referenced ADR Decisions
**ADR-0049 D4 — Test canaries are the fifth attribute-consumer.** "Every Node ships a redaction canary (per the PII-scrubbing canary follow-up named in ADR-0040 and ADR-0045) that constructs sample payloads with `[PiiField]`-marked fields, sends them through the log/audit/error paths, and asserts the output is properly redacted. A canary failure blocks the package release per ADR-0034."

**ADR-0049 D10 Phase 3 — Redactor integrations + canaries.** "Wire the attribute-aware redactor into `HoneyDrunk.Observe.AzureMonitor`'s `LogRecordProcessor` and `IErrorReporter` backing. Wire the attribute-aware redactor into `HoneyDrunk.Audit`'s append path. Ship the PII-scrubbing canaries that were follow-ups of ADR-0040 and ADR-0045."

**ADR-0040 Follow-up Work — PII-scrubbing canaries.** Originally listed as Pulse follow-up; closed by this packet.

**ADR-0045 Follow-up Work — PII-scrubbing canaries.** Originally listed; closed by this packet.

**Invariant 14 — Canary tests validate cross-Node boundaries.** This canary exercises the Pulse↔Kernel-Abstractions boundary (logs/traces/errors) and the Audit↔Kernel-Abstractions boundary (append path) as one suite.

**Invariant 47 (amended in packet 00) + invariant 59.** The canary's audit assertions verify both: sensitive fields are redacted before append (invariant 47 amended), and SensitivePii is rejected entirely from the audit channel (invariant 59 new).

**ADR-0040 D9 — Evals carve-out.** `evals.sensitive=true` spans skip redaction; the canary asserts this carve-out is honored.

**ADR-0045 D7 — StackTrace and regex fallback.** Stack frames are never PII; unstructured exception messages fall back to regex scrubbing. The canary asserts both.

## Constraints
- **No re-bump of the Pulse solution version.** Packet 04 is the bumping packet for Pulse in this initiative; this packet appends to the in-progress `[X.Y.0]` CHANGELOG entry only (invariant 27).
- **No per-package CHANGELOG noise.** The canary verifies packet 04's behavior; it adds no functional change to any production package. Per invariant 12/27, only packages with real functional changes get per-package entries.
- **Test code only.** The canary lives in a test project; the sample records carrying `[PiiField]` markers are test-time fixtures, never runtime types. Invariant 16 (no test code in runtime packages) is preserved by construction.
- **Failing canary blocks the package per ADR-0034.** Do not soften the canary to a warning; a failure must fail the build.
- **Coordination with packets 04 and 05.** This packet builds against both redactor implementations. Confirm both are merged and published before this branch's CI runs.

## Labels
`feature`, `tier-2`, `ops`, `adr-0049`, `adr-0040`, `adr-0045`, `wave-3`

## Agent Handoff

**Objective:** Ship the cross-boundary PII-scrubbing canary in `HoneyDrunk.Pulse` that exercises log/trace/error/audit redaction end-to-end against `[PiiField]`-marked test fixtures.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Close the PII-scrubbing-canary follow-up from ADR-0040 and ADR-0045; make the redactor regressions from packets 04 and 05 detectable at CI.
- Feature: ADR-0049 Data Classification rollout, Wave 3 (Phase 3 redactor integrations).
- ADRs: ADR-0049 D4/D10 (primary), ADR-0040 D9 (Evals carve-out), ADR-0045 D7 (StackTrace + regex), ADR-0034 (canary-failure blocks release).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:04` — Pulse-side redactor exists and is published.
- `packet:05` — Audit-side redactor + `IAuditTokenizer` exist and are published.

**Constraints:**
- Test code only — no runtime change.
- Append to the `[X.Y.0]` CHANGELOG entry started by packet 04; do not re-bump.
- No per-package CHANGELOG noise entries.
- Canary failure must fail the build per ADR-0034.

**Key Files:**
- New canary test class in the Pulse canary project (create the project if it does not yet exist, following the existing canary-project naming convention).
- The Pulse repo-level `CHANGELOG.md`.
- Possibly the canary project's `README.md`.

**Contracts:** No new contracts. The canary verifies existing contracts from packets 04 and 05.
