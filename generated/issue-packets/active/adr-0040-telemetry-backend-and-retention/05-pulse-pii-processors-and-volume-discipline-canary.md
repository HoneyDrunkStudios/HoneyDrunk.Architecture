---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0040", "wave-3"]
dependencies: ["packet:03", "packet:04"]
adrs: ["ADR-0040", "ADR-0023"]
accepts: ["ADR-0040"]
wave: 3
initiative: adr-0040-telemetry-backend-and-retention
node: honeydrunk-pulse
---

# Implement the PII span/log processors and the volume-discipline canary in HoneyDrunk.Pulse

## Summary
Add the PII redaction processors and the volume-discipline canary to the `HoneyDrunk.Telemetry.Sink.AzureMonitor` provider per ADR-0040 D6/D9: an OpenTelemetry `SpanProcessor` and `LogRecordProcessor` that strip prompt/completion text and PII before the exporter ships telemetry, the `evals.sensitive=true` carve-out routing, and a test-tier canary that flags `Information`-level events in identified hot paths. The PII regex scrubber is built as a **shared, mechanism-agnostic component** so ADR-0045's error path can reuse it.

## Context
ADR-0040 D9 makes telemetry **default-deny for user-typed content and model outputs**. The mechanism is OpenTelemetry `Processor`s — a `SpanProcessor` for traces and a `LogRecordProcessor` for logs that filter or redact attributes before the Azure Monitor exporter ships them. Consistent with D2, these are OTel-native primitives, not classic App Insights SDK constructs.

D9's rules:
- **Custom dimensions** (`tenant.id`, `service.name`, etc.) are not PII — allowed.
- **Telemetry containing user-typed content or model outputs** is forbidden by default. Specifically excluded: prompt text, completion text, recipient email addresses, message bodies.
- **`HoneyDrunk.Evals` carve-out** (per ADR-0023) — eval signals may carry prompts and outputs because that is what they are for. Eval-emitted signals are labeled `evals.sensitive=true` and filtered to a dedicated Log Analytics table with the same 90-day retention and tighter (Azure-AD-role-scoped) access control.
- **Audit emits** are PII-bearing by design and governed by ADR-0030's append-only semantics; the 730-day retention accounts for them.

D6 adds the volume-discipline canary: "A canary in the `HoneyDrunk.Pulse` test surface walks Node-level telemetry emission and asserts no `Information`-level events inside identified hot paths (heuristic — flagged for review, not auto-blocked)."

This packet appends to the `HoneyDrunk.Pulse` solution — packet 03 already bumped the version this initiative, so per invariant 27 this packet **does not bump again**; it appends to the CHANGELOG.

**Shared PII scrubber (ADR-0045 coordination).** ADR-0045 (Grid-wide error tracking) reuses the PII-scrubbing pipeline on the error path. To avoid ADR-0045 having to refactor this packet's code after the fact, build the regex-based PII scrubber as a **shared, mechanism-agnostic component from the start** — a plain string/attribute redaction utility that knows nothing about OTel `SpanProcessor`s or App Insights `ITelemetryProcessor`s. The OTel `SpanProcessor`/`LogRecordProcessor` in this packet *use* the shared scrubber; ADR-0045's error-path processor will *also* use it. Place the scrubber in `HoneyDrunk.Telemetry.Sink.Shared` (the existing shared sink-support project) so both consumers can reference it without a new dependency.

## Scope
- `HoneyDrunk.Telemetry.Sink.Shared` — the shared, mechanism-agnostic PII regex scrubber utility.
- `HoneyDrunk.Telemetry.Sink.AzureMonitor` — add the PII `SpanProcessor` and `LogRecordProcessor` (which call the shared scrubber), the `evals.sensitive=true` routing, and wire them into the provider builders via the seam packet 03 left.
- `HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit` (and a `Sink.Shared` test project) — unit tests for the redaction processors and the shared scrubber.
- The Pulse test/canary project (per the Grid's `.Canary` convention — match the existing test-project layout) — the volume-discipline canary.

## Proposed Implementation
1. **Shared PII regex scrubber** — in `HoneyDrunk.Telemetry.Sink.Shared`, a mechanism-agnostic redaction utility: given a string or a key/value attribute, it strips common PII patterns (emails, phone numbers) and applies a denylist of attribute keys carrying user-typed content. It has no OTel or App Insights type in its signature — it is pure string/attribute logic so the OTLP path (this packet) and the App Insights SDK error path (ADR-0045) can both consume it. Full XML documentation (invariant 13).
2. **PII `SpanProcessor`** — an OTel `SpanProcessor` that, before export, drops or redacts span attributes carrying user-typed content or model output, delegating the pattern matching to the shared scrubber. The default-deny set: prompt text, completion text, recipient email addresses, message bodies. Allowed-through: the custom dimensions (`tenant.id`, `service.name`, `user.id` as the opaque `PrincipalId`, etc.).
4. **PII `LogRecordProcessor`** — the same default-deny applied to log records before export, also delegating to the shared scrubber.
5. **`evals.sensitive=true` routing** — telemetry labeled with the `evals.sensitive=true` custom dimension is the deliberate carve-out (ADR-0023): it is *not* redacted, and it is routed to a **dedicated Log Analytics table** (a custom table, distinct from the default `traces`/`exceptions` tables) with 90-day retention and tighter access control. The routing mechanism: the Azure Monitor exporter / Log Analytics custom-table configuration. Document how the dedicated table is targeted (a custom-dimension-driven export rule, or a separate exporter pipeline keyed on the dimension). The dedicated table's *creation* and its access-control / retention configuration are an Azure-side concern — note in this packet whether the table is created here via the exporter's auto-table behavior or whether packet 06 must create it; coordinate with packet 06.
6. **Audit telemetry pass-through.** `HoneyDrunk.Audit`-attributed telemetry is PII-bearing by design — the processors must *not* strip it; it routes to the Audit-tagged table (`source=hd-audit` custom dimension per D3). The processors recognize the Audit `service.name` / `source=hd-audit` dimension and pass it through unredacted. (The 730-day retention on that table is packet 06.)
7. **Volume-discipline canary** — a canary test in the Pulse test/canary project that walks Node-level telemetry emission and asserts no `Information`-level events inside identified hot paths. Per D6 this is a **heuristic — flagged for review, not auto-blocked**: the canary surfaces findings as warnings / a review flag, it does not fail the build. Document the heuristic and the hot-path identification approach.
8. **Wire into the builders.** The processors compose into the `TracerProvider` / `LoggerProvider` builders via the seam packet 03 left.
9. **XML documentation** on every public member (invariant 13).
10. **Version.** Packet 03 already bumped the `HoneyDrunk.Pulse` solution version this initiative. Per invariant 27, this packet **does not bump again** — append to the repo-level `CHANGELOG.md` in-progress version entry. Update `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md` and `HoneyDrunk.Telemetry.Sink.Shared/CHANGELOG.md` (both have actual changes), and the respective `README.md`s if the PII-processor / scrubber configuration is part of the documented public surface.

## Affected Files
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.Shared/` — the shared mechanism-agnostic PII regex scrubber.
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` — PII processors, `evals.sensitive` routing, builder wiring.
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit/` — redaction tests.
- A `HoneyDrunk.Telemetry.Sink.Shared` test project — scrubber tests.
- The Pulse test/canary project (per the Grid convention) — the volume-discipline canary.
- Repo-level `CHANGELOG.md` — append to the in-progress version entry (no new version, no bump).
- `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md`, `HoneyDrunk.Telemetry.Sink.Shared/CHANGELOG.md`; the respective `README.md`s if they document the API surface.

## NuGet Dependencies
No new `PackageReference` entries beyond what packet 03 established for `HoneyDrunk.Telemetry.Sink.AzureMonitor` — the PII processors are OTel `SpanProcessor`/`LogRecordProcessor` types from the `OpenTelemetry` package packet 03 already referenced. The shared scrubber in `HoneyDrunk.Telemetry.Sink.Shared` is plain .NET (regex) — it needs only `HoneyDrunk.Standards`; add no OTel or Azure dependency to `Sink.Shared`. `Sink.AzureMonitor` gains a project reference to `Sink.Shared` if it does not already have one. Confirm `OpenTelemetry` and `HoneyDrunk.Standards` are present on the projects; add no others.

If the volume-discipline canary lands in a new `.Canary` project (rather than an existing test project), that new project takes:
- The Grid's standard test stack — match the other `HoneyDrunk.Pulse` test/canary projects.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).
- Project references as needed to walk the telemetry emission surface.

## Boundary Check
- [x] `HoneyDrunk.Pulse` is the correct repo — D9's processors extend `HoneyDrunk.Telemetry.Sink.AzureMonitor`, the shared scrubber lands in `HoneyDrunk.Telemetry.Sink.Shared`, D6's canary in the Pulse test surface; ADR-0040 (amended 2026-05-22) places this in Pulse.
- [x] PII redaction is a Pulse-runtime concern via OTel-native processors — backend-agnostic per D2.
- [x] No cross-Node boundary crossed — the processors recognize the Audit/Evals `service.name` / custom dimensions but introduce no runtime dependency on those Nodes.

## Acceptance Criteria
- [ ] A shared, mechanism-agnostic PII regex scrubber lives in `HoneyDrunk.Telemetry.Sink.Shared` — no OTel or App Insights type in its signature, so ADR-0045's error path can reuse it without refactoring
- [ ] A PII `SpanProcessor` strips/redacts prompt text, completion text, recipient email addresses, and message bodies from span attributes before export (delegating to the shared scrubber); custom dimensions (`tenant.id`, `service.name`, opaque `user.id`) pass through
- [ ] A PII `LogRecordProcessor` applies the same default-deny to log records before export, also via the shared scrubber
- [ ] The shared scrubber strips common PII patterns (emails, phone numbers) embedded in otherwise-allowed string attributes
- [ ] Telemetry labeled `evals.sensitive=true` is NOT redacted and is routed to a dedicated Log Analytics custom table (90-day retention, tighter access control) — the routing mechanism documented; coordination with packet 06 on table creation recorded
- [ ] `HoneyDrunk.Audit`-attributed telemetry passes through unredacted (PII-bearing by design, D3) and routes to the Audit-tagged table
- [ ] A volume-discipline canary in the Pulse test/canary surface walks Node telemetry emission and flags `Information`-level events in identified hot paths as a review warning — heuristic, NOT a build-fail (D6)
- [ ] The processors are wired into the `TracerProvider` / `LoggerProvider` builders via the packet-03 seam
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit` and a `Sink.Shared` test project cover the redaction logic — prompt/completion/email/body stripping and the `evals.sensitive` / Audit pass-through; tests use no external services (invariant 15), no `Thread.Sleep` (invariant 51)
- [ ] Every new public member has XML documentation (invariant 13)
- [ ] No version bump — packet 03 already bumped the solution; append to the repo-level `CHANGELOG.md` in-progress version entry (invariant 27); `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md` and `HoneyDrunk.Telemetry.Sink.Shared/CHANGELOG.md` updated
- [ ] The solution builds; existing unit and canary tests pass

## Human Prerequisites
None. (The dedicated `evals.sensitive` Log Analytics table's access-control configuration is an Azure-side concern — confirm with packet 06 whether it is created by the exporter automatically or needs a portal step; if a portal step, packet 06 owns it.)

## Referenced ADR Decisions
**ADR-0040 D9 — PII and sensitive-content carve-outs.** Mechanism is OpenTelemetry `Processor`s — a `SpanProcessor` for traces and a `LogRecordProcessor` for logs that filter or redact attributes before the Azure Monitor exporter ships them. Custom dimensions (`tenant.id`, `service.name`) are not PII; allowed. Telemetry containing user-typed content or model outputs is forbidden by default — specifically prompt text, completion text, recipient email addresses, message bodies. `HoneyDrunk.Evals` is the deliberate carve-out per ADR-0023: eval signals may carry prompts and outputs, labeled `evals.sensitive=true`, filtered to a dedicated Log Analytics table with 90-day retention and tighter (Azure-AD-role-scoped) access control. Audit emits are PII-bearing by design, governed by ADR-0030's append-only semantics; 730-day retention accounts for this.

**ADR-0040 D6 — Volume discipline.** High-frequency events in tight loops are forbidden as `Information`-level emissions. A canary in the `HoneyDrunk.Pulse` test surface walks Node-level telemetry emission and asserts no `Information`-level events inside identified hot paths — heuristic, flagged for review, not auto-blocked.

**ADR-0040 D3 — Audit logs.** Audit-sourced logs route to a custom Log Analytics table with `source=hd-audit` custom dimension and 730-day retention.

**ADR-0023 — Evals carve-out.** `HoneyDrunk.Evals` signals are the deliberate exception to the content default-deny — eval signals carry prompts and outputs because evaluating them is the Node's purpose.

## Constraints
> **Invariant 71 (added by ADR-0040 packet 00) — prompt and completion text appears in telemetry only behind the `evals.sensitive=true` custom dimension and the dedicated Log Analytics table.** Telemetry is default-deny for user-typed content and model outputs; `HoneyDrunk.Evals` is the only opt-in carve-out. The PII processors enforce this — anything not carrying `evals.sensitive=true` is redacted of prompt/completion content.

> **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards`.

> **Invariant 15 — Unit tests never depend on external services.** Redaction tests run in-process against constructed spans/log records — no live App Insights resource.

> **Invariant 27 — All projects in a solution share one version and move together.** Packet 03 already bumped the `HoneyDrunk.Pulse` solution this initiative. This packet does NOT bump again — append to the repo-level `CHANGELOG.md` in-progress version entry.

> **Invariant 51 — Test code contains no `Thread.Sleep`.**

- **OTel-native only.** `SpanProcessor` / `LogRecordProcessor`, not classic App Insights `ITelemetryProcessor` — D2/D9.
- **Shared, mechanism-agnostic scrubber.** The PII regex scrubber goes in `HoneyDrunk.Telemetry.Sink.Shared` with no OTel/App-Insights type in its signature — ADR-0045's error path reuses it as-is.
- **The volume-discipline canary is a heuristic, not a gate.** It flags for review; it must not fail the build (D6 is explicit).
- **Audit and Evals telemetry are NOT redacted** — they are the two deliberate carve-outs. The processors recognize them by `service.name` / custom dimension and pass them through.
- **No version bump** — append to the CHANGELOG.
- **Packet 04 lands first.** Packet 04 also touches `Sink.AzureMonitor`; this packet depends on `packet:04` and rebases on it.

## Labels
`feature`, `tier-2`, `ops`, `adr-0040`, `wave-3`

## Agent Handoff

**Objective:** Add the PII redaction `SpanProcessor`/`LogRecordProcessor` (built on a shared mechanism-agnostic scrubber), the `evals.sensitive=true` carve-out routing, and the volume-discipline canary to `HoneyDrunk.Pulse`.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Make telemetry default-deny for user content and model output per ADR-0040 D9, and add the D6 volume-discipline heuristic — so the Grid's telemetry cannot leak PII or prompt/completion text.
- Feature: ADR-0040 Telemetry Backend and Retention rollout, Wave 3.
- ADRs: ADR-0040 D6/D9/D3 (primary; amended 2026-05-22 — this is Pulse work), ADR-0023 (the Evals content carve-out).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:03` — hard. The processors compose into the `TracerProvider`/`LoggerProvider` builder seams `HoneyDrunk.Telemetry.Sink.AzureMonitor` exposes.
- `packet:04` — hard. Packet 04 also modifies `Sink.AzureMonitor`; this packet is sequenced after it to avoid a merge conflict on the shared project.

**Constraints:**
- OTel-native `SpanProcessor`/`LogRecordProcessor` — no classic App Insights `ITelemetryProcessor`.
- The PII regex scrubber is a shared, mechanism-agnostic component in `HoneyDrunk.Telemetry.Sink.Shared` — ADR-0045 reuses it.
- Default-deny for prompt/completion/email/message-body content; Audit and Evals telemetry are the two carve-outs (not redacted).
- The volume-discipline canary is a heuristic — flags for review, never fails the build.
- No version bump — packet 03 already bumped the solution; append to the CHANGELOG.

**Key Files:**
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.Shared/` — the shared PII scrubber
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` — processors + routing + wiring
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor.Tests.Unit/`
- The Pulse test/canary project
- Repo-level + `HoneyDrunk.Telemetry.Sink.AzureMonitor` + `HoneyDrunk.Telemetry.Sink.Shared` `CHANGELOG.md`

**Contracts:** None changed — internal OTel processor types composed into the provider builders.
