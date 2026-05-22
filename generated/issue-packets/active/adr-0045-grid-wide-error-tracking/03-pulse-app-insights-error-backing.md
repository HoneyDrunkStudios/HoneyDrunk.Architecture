---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "adr-0045", "wave-3"]
dependencies: ["packet:02", "Architecture#ADR0040-PACKET05"]
adrs: ["ADR-0045", "ADR-0040", "ADR-0005", "ADR-0023", "ADR-0026"]
accepts: ["ADR-0045"]
wave: 3
initiative: adr-0045-grid-wide-error-tracking
node: honeydrunk-pulse
---

# Implement the App Insights error-capture backing and the error PII processor in HoneyDrunk.Telemetry.Sink.AzureMonitor

## Summary
Extend the **existing** `HoneyDrunk.Telemetry.Sink.AzureMonitor` package with the App-Insights-SDK-based error-capture backing and the `IErrorReporter` facade implementation per ADR-0045 D3, the `operation_id` cross-link wiring (D4), the `application_Version` release tagging hook (D6), and the error-path PII scrubbing per D7 — consuming the shared PII scrubber ADR-0040 builds. This is the core implementation packet of the initiative.

## Context
ADR-0045 D3 routes errors through `HoneyDrunk.Pulse` but, unlike traces/metrics/logs (which use OTLP per ADR-0040 D2), the error backing uses the **App Insights .NET SDK** (`Microsoft.ApplicationInsights`). The carve-out exists because App Insights' error model carries fields that are not OTLP primitives — `problem_id`, `application_Version`, custom dimensions for user/tenant scoping that drive Failures-blade grouping. Routing errors as OTLP-generic would strip those features.

This packet adds the error backing to the **existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package** — the same Pulse sink ADR-0040 uses for traces/metrics/logs. It does **not** create a new package and does **not** live in `HoneyDrunk.Observe`. The App Insights connection string (seeded into Vault by ADR-0040 packet 02) is reused; ADR-0045 D2 is explicit that errors capture into the same App Insights resource as traces/metrics/logs. No new resource, no new secret.

**Facade over the existing `IErrorSink`.** Packet 02 added the `IErrorReporter` facade to `HoneyDrunk.Telemetry.Abstractions`. This packet has two parts: (1) extend `HoneyDrunk.Telemetry.Sink.AzureMonitor`'s error-capture path — the `IErrorSink` backing that routes an `ErrorEvent` to App Insights via the SDK; and (2) implement the `IErrorReporter` facade — the class that captures ambient context, maintains breadcrumb/scope state, builds an `ErrorEvent`, and routes it to `IErrorSink`. The facade implementation belongs in `HoneyDrunk.Telemetry.Sink.AzureMonitor` (or a Pulse runtime/shared project — match the Pulse solution's existing structure for where sink-backed services compose). It must **not** reinvent `IErrorSink`; it builds an `ErrorEvent` and hands it over.

**Cross-initiative dependency — read first.** This packet's `dependencies:` references **ADR-0040 packet 05** (`Architecture#<issue-number>` once filed — replace the `Architecture#ADR0040-PACKET05` placeholder before this folder is pushed). ADR-0040 packet 05 builds the PII redaction processors **and the shared, mechanism-agnostic PII scrubber as a shared component from the start** (ADR-0040 packet 05 was corrected to do so). This is a plain hard cross-initiative dependency: this packet **consumes** that shared scrubber — no refactor needed. It also means all of ADR-0040's Pulse waves have landed, so the `HoneyDrunk.Pulse` solution version state is settled.

**Version.** Per invariant 27, this packet appends to the `HoneyDrunk.Pulse` solution's in-progress version entry if packet 02 of *this* initiative bumped it, or bumps if packet 02 only appended to an ADR-0040 entry that has since released. Check the in-progress state at edit time and record the decision. The two ADR-0045 Pulse packets (02 and 03) and ADR-0040's Pulse packets all share one solution version — only the first un-released packet bumps.

## PII processor — `ITelemetryProcessor` is correct; consume the shared scrubber
ADR-0045 D7 says error PII scrubbing uses `ITelemetryProcessor` — the classic App Insights SDK filter pipeline. ADR-0040 D9 is OTel-native (`SpanProcessor`/`LogRecordProcessor`). The two are not contradictory once the mechanism is understood: errors use the App Insights SDK directly (D3's carve-out), and the App Insights SDK's *only* filter hook is `ITelemetryProcessor` — OTel processors do not sit in the App Insights SDK's pipeline. So the error path **must** use `ITelemetryProcessor`; it is the correct and only mechanism for SDK-captured exception telemetry. ADR-0040 D9's mechanism choice applies to the *OTLP* path, not the *SDK* path.

The **regex scrubbing rules** (emails, phone numbers, credit-card patterns, API keys, JWT shapes — the D7 list, identical to ADR-0040 D9's set) are **not** re-implemented here. ADR-0040 packet 05 builds the PII scrubber as a **shared, mechanism-agnostic component** (a plain, framework-free `PiiScrubber` — string in → redacted string out, plus an attribute/dimension allowlist). This packet's error `ITelemetryProcessor` simply **consumes** that shared scrubber. No refactor of ADR-0040 packet 05's code is needed — it is already shared by construction. Do not duplicate the regex set; reference the shared component.

## Scope
- `HoneyDrunk.Telemetry.Sink.AzureMonitor` — add the App-Insights-SDK-based error-capture path (exceptions → `TrackException`), the error `ITelemetryProcessor` for PII scrubbing (consuming the shared `PiiScrubber` from ADR-0040 packet 05), the `operation_id` cross-link wiring, the `application_Version` release-tag hook, the `IErrorReporter` facade implementation, and the DI registration so `IErrorReporter` is part of the standard Pulse telemetry registration (D5).
- The `HoneyDrunk.Telemetry.Sink.AzureMonitor` unit-test project — unit tests for error capture, PII scrubbing, breadcrumb/scope behavior, and the `evals.sensitive` / Audit pass-through.

## Proposed Implementation
1. **App Insights error backing + `IErrorReporter` facade.** Extend `HoneyDrunk.Telemetry.Sink.AzureMonitor` so its error path captures exceptions into App Insights via `Microsoft.ApplicationInsights`'s `TelemetryClient`, and implement the `IErrorReporter` facade (packet 02's contract) — the class that captures ambient context, maintains breadcrumb/scope state, builds an `ErrorEvent`, and routes it through `IErrorSink`. The facade does not reinvent `IErrorSink`.
   - `CaptureException` → builds an `ErrorEvent` from the exception + `ErrorContext`, routed via `IErrorSink` to `TelemetryClient.TrackException`, mapping `ErrorContext.TraceId` to the telemetry's `operation_Id` (D4 cross-link), `TenantId`/`UserId`/`Release` to custom dimensions / `Context.Component.Version`, and `Tags` to custom properties.
   - `CaptureMessage` → `TelemetryClient.TrackTrace` with the mapped `ErrorLevel` → `SeverityLevel`.
   - `AddBreadcrumb` → a scoped breadcrumb buffer; on the next capture, breadcrumbs are emitted as `customEvents` on the same `operation_Id` (D3 — App Insights expresses Sentry-style breadcrumbs via custom events).
   - `PushScope` → an `AsyncLocal`-backed scope stack; scoped tags merge into subsequent captures until the returned `IDisposable` disposes.
2. **`application_Version` release tag (D6)** — the implementation reads `ErrorContext.Release` and sets it as the telemetry's `application_Version`. Where `ErrorContext.Release` is not supplied, fall back to the host's assembly/informational version. The deploy-time release-annotation API call is packet 04's concern — this packet only ensures captured exceptions carry the version.
3. **Connection string from Vault.** Reuse the App Insights connection string ADR-0040 packet 02 seeded into the relevant `kv-hd-{service}-{env}` Key Vault, resolved via `ISecretStore` — invariant 9, Vault is the only source of secrets; ADR-0045 D2 reuses the ADR-0040 connection string, no new secret. Never read it from an env var holding the raw value or an Azure SDK default credential path. The `TelemetryClient`'s `TelemetryConfiguration.ConnectionString` is set from the Vault-resolved value.
4. **Error PII `ITelemetryProcessor` (D7)** — an `ITelemetryProcessor` registered into the App Insights SDK's processing pipeline (the SDK's only filter hook):
   - Scrubs `ExceptionTelemetry` messages, stack-frame data, and custom dimensions of the D7 default-deny set: prompt text, completion text, recipient email addresses, message bodies, plus the common PII patterns (emails, phone numbers, credit-card patterns, API keys, JWT shapes).
   - **Allowed through:** `tenant_id` (low-cardinality, load-bearing for triage, not PII); `user_id` as the opaque `PrincipalId` (ADR-0026); `service.name`; release version.
   - **`evals.sensitive=true` carve-out** — exceptions thrown from AI-Node agent-execution paths carrying the `evals.sensitive=true` dimension are *not* scrubbed of prompt/completion content (ADR-0023 / ADR-0040 D9 carve-out). Without that dimension, prompt/completion content is redacted. The breadcrumb (capability invoked, model, cost) is always allowed.
   - **`HoneyDrunk.Audit`-emitted errors** carry PII by design (recipient address on a notification failure). These are recognized by the Audit `service.name` / `source=hd-audit` dimension and pass through unredacted to the Audit-tagged Log Analytics table (`sensitive=audit`, 730-day retention per ADR-0040 D3).
5. **Consume the shared `PiiScrubber`.** ADR-0040 packet 05 builds the regex PII scrubber as a shared, mechanism-agnostic component (a plain, framework-free `PiiScrubber` — string in → redacted string out, plus the attribute allowlist). This packet's error `ITelemetryProcessor` references that shared component — it does **not** re-implement the regex set and does **not** refactor packet 05's code (the component is already shared by construction). One regex surface, no duplication, no drift.
6. **DI registration (D5)** — a registration extension so `IErrorReporter` is part of the standard Pulse telemetry registration. All Nodes consuming Pulse get error reporting once the backing is wired; opt-out is per Node via configuration. The error `ITelemetryProcessor` is added to the `TelemetryConfiguration` pipeline in the same extension.
7. **XML documentation** on every public member (invariant 13).
8. **Version.** See Context — append or bump per the invariant-27 in-progress state check; record the decision.
9. **CHANGELOG / README.** `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md` gets an entry (actual change). Repo-level `CHANGELOG.md` updated. Update `HoneyDrunk.Telemetry.Sink.AzureMonitor/README.md` if the error-capture registration is part of the documented public surface.

## Affected Files
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` — the App Insights error-capture path (`IErrorSink` backing), the `IErrorReporter` facade implementation, error `ITelemetryProcessor`, breadcrumb/scope handling, DI registration.
- The `HoneyDrunk.Telemetry.Sink.AzureMonitor` unit-test project — error-capture and scrubbing tests.
- Repo-level `CHANGELOG.md`; `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md`; `HoneyDrunk.Telemetry.Sink.AzureMonitor/README.md` (if API-surface relevant).
- Possibly every non-test `.csproj` (if this packet bumps the solution version).

## NuGet Dependencies
`HoneyDrunk.Telemetry.Sink.AzureMonitor` — confirm `Microsoft.ApplicationInsights` is present (the App Insights .NET SDK — `TelemetryClient`, `ExceptionTelemetry`, `ITelemetryProcessor`); the existing AzureMonitor sink most likely already references it. Add it only if absent. ADR-0045 D3's carve-out: the error path uses the SDK directly, not OTLP. If a hosting integration is needed, `Microsoft.ApplicationInsights.AspNetCore` — pick per the Pulse runtime's host model and document.

Already present in `HoneyDrunk.Telemetry.Sink.AzureMonitor` (confirm; add none of these new):
- `HoneyDrunk.Telemetry.Abstractions` — the project reference carrying `IErrorReporter` and `IErrorSink`/`ErrorEvent` (packet 02 added the facade).
- The shared `PiiScrubber` component from ADR-0040 packet 05 — reference the project/package it lives in; do not duplicate the regex set.
- The Vault `ISecretStore` reference for the connection string.
- `HoneyDrunk.Kernel.Abstractions` — Grid context for `TenantId`/`PrincipalId`.
- `Microsoft.Extensions.DependencyInjection.Abstractions`, `Microsoft.Extensions.Options`, `Microsoft.Extensions.Logging.Abstractions`.
- `HoneyDrunk.Standards` — analyzers, `PrivateAssets: all` (invariant 26).

The `HoneyDrunk.Telemetry.Sink.AzureMonitor` unit-test project — no new packages beyond the existing test stack; project reference to `HoneyDrunk.Telemetry.Sink.AzureMonitor`.

## Boundary Check
- [x] `HoneyDrunk.Pulse` is the correct repo — outbound error telemetry export belongs to Pulse per `repos/HoneyDrunk.Observe/boundaries.md` and `repos/HoneyDrunk.Pulse/boundaries.md`; the error backing extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package. ADR-0045 (amended 2026-05-22) confirms it.
- [x] The App Insights error SDK lives inside the Pulse sink package, never in a consuming Node — D3/D5 reversibility property.
- [x] The error backing consumes the published `IErrorReporter`/`IErrorSink` contracts from `HoneyDrunk.Telemetry.Abstractions`, not internals (invariant 3); the `IErrorReporter` facade does not reinvent `IErrorSink`.
- [x] No consuming Node changes in this packet — Nodes wire `IErrorReporter` via the standard Pulse telemetry registration (packet 05 / the wiring playbook do the per-Node wiring).
- [x] No new package — the error backing extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor`.

## Acceptance Criteria
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor` captures exceptions into App Insights via the .NET SDK (`TelemetryClient.TrackException`/`TrackTrace`); the `IErrorReporter` facade is implemented over the existing `IErrorSink` and does not reinvent it
- [ ] `ErrorContext.TraceId` maps to the telemetry's `operation_Id` so the App Insights Failures→Transactions cross-link works natively (D4)
- [ ] `application_Version` is set from `ErrorContext.Release` (fallback: host assembly version) so captured exceptions carry release info (D6)
- [ ] `AddBreadcrumb` and `PushScope` work as scoped `IDisposable`s; breadcrumbs emit as `customEvents` on the same `operation_Id`
- [ ] The App Insights connection string is resolved via `ISecretStore` (Vault) — the same secret ADR-0040 packet 02 seeded, no new secret; never from an env var holding the raw value, never hardcoded (invariants 8, 9)
- [ ] An error PII `ITelemetryProcessor` is registered into the App Insights SDK pipeline and scrubs prompt/completion text, recipient emails, message bodies, and common PII patterns (emails, phones, credit cards, API keys, JWT shapes) from exception messages and custom dimensions
- [ ] `tenant_id`, the opaque `user_id`, `service.name`, and release version pass through (not PII per D7)
- [ ] Telemetry carrying `evals.sensitive=true` is NOT scrubbed of prompt/completion content (the ADR-0023/ADR-0040 D9 carve-out); `HoneyDrunk.Audit`-attributed errors pass through unredacted to the Audit-tagged table
- [ ] The error `ITelemetryProcessor` **consumes the shared `PiiScrubber`** from ADR-0040 packet 05 — single regex surface, no duplication, no re-implementation of the regex set
- [ ] `IErrorReporter` is registered as part of the standard Pulse telemetry registration so consuming Nodes get error reporting automatically; per-Node opt-out is configurable (D5)
- [ ] The `HoneyDrunk.Telemetry.Sink.AzureMonitor` unit-test project covers error capture, the `operation_id` mapping, breadcrumb/scope behavior, PII scrubbing, and the `evals.sensitive`/Audit pass-through; tests use no external services (invariant 15), no `Thread.Sleep` (invariant 51)
- [ ] Every new public member has XML documentation (invariant 13)
- [ ] The invariant-27 version-state check is performed — bump or append — and recorded in the PR
- [ ] `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md` updated; repo-level `CHANGELOG.md` updated
- [ ] The solution builds; existing unit and canary tests pass

## Human Prerequisites
- [ ] The `dev` App Insights resource and its Vault-stored connection string must exist — provisioned by **ADR-0040 packet 02** (`infrastructure/walkthroughs/application-insights-provisioning.md`). ADR-0045 introduces **no new Azure resource**: errors capture into the same App Insights resource as traces/metrics/logs (D2). This is a cross-initiative prerequisite, not a `dependencies:` edge — the filing pipeline does not resolve cross-initiative `packet:NN` references, so it is listed here. Unit tests for this packet must not require a live resource (invariant 15 — use in-memory doubles); the end-to-end smoke check (an exception appears in the `dev` App Insights Failures blade) is the realistic verification and is deferred until ADR-0040 packet 02 has run.

## Referenced ADR Decisions
**ADR-0045 D3 — Errors flow through Pulse; `IErrorReporter` is a facade over `IErrorSink`; the App Insights backing uses the .NET SDK.** A carve-out from ADR-0040's OTLP path: the App Insights error model carries `problem_id`, `application_Version`, and Failures-blade grouping dimensions that are not OTLP primitives. The SDK is wrapped behind Pulse's `IErrorSink`; `IErrorReporter` is the facade over it. A backend swap (Sentry, D11 — via the existing `HoneyDrunk.Telemetry.Sink.Sentry`) stays a config change.

**ADR-0045 — amendment 2026-05-22.** The error backing extends the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor` package in `HoneyDrunk.Pulse` — it does not create a new package and does not live in `HoneyDrunk.Observe`.

**ADR-0045 D4 — Cross-link via `operation_id`.** App Insights' Failures and Transactions blades share `operation_id` (≈ `trace_id`). Mapping `ErrorContext.TraceId` to `operation_Id` makes the errors↔traces↔logs navigation native — no configured integration.

**ADR-0045 D5 — Per-Node opt-in via Pulse configuration.** `IErrorReporter` is part of the standard Pulse telemetry registration; all Nodes consuming Pulse get error reporting once the backing is wired; opt-out is per Node via configuration.

**ADR-0045 D6 — Release tracking via `application_Version`.** Captured exceptions carry the deployable's SemVer; the Failures-blade release annotations make "this error first appeared in v0.4.2" visible. The deploy-time annotation call is packet 04.

**ADR-0045 D7 — PII, tenant scoping, sensitive-content carve-outs.** Mechanism is `ITelemetryProcessor` (the App Insights SDK's filter hook — the correct mechanism for SDK-captured telemetry; ADR-0040 D9's mechanism choice applies only to the OTLP path). `tenant_id` allowed (not PII); `user_id` allowed as the opaque `PrincipalId`; prompt/completion text forbidden by default, allowed only behind `evals.sensitive=true`; common PII patterns regex-scrubbed via the shared scrubber; Audit-emitted errors are PII-bearing by design and route to the Audit-tagged table.

**ADR-0040 D9 — PII carve-outs.** ADR-0040 builds the PII scrubber as a shared, mechanism-agnostic component; this packet's error `ITelemetryProcessor` consumes that shared component.

**ADR-0040 D2 — Pulse is the telemetry-export boundary.** The error path is the explicit carve-out — SDK, not OTLP — but the backend still lives inside the Pulse sink family, never in a consuming Node.

**ADR-0023 — Evals carve-out.** `HoneyDrunk.Evals` signals (and prompt/completion content) are the deliberate exception to the content default-deny.

**ADR-0005 — Vault.** The App Insights connection string is resolved via `ISecretStore`. One Key Vault per deployable Node per environment.

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** Does not apply to `HoneyDrunk.Telemetry.Sink.AzureMonitor` (a provider/sink package) — but the App Insights SDK reference goes in the sink package, never in `HoneyDrunk.Telemetry.Abstractions` (packet 02 kept the abstraction SDK-free).

> **Invariant 3 — Provider packages depend on their parent Node's contracts, not internals.** `HoneyDrunk.Telemetry.Sink.AzureMonitor` implements the published `IErrorSink`; the `IErrorReporter` facade builds on it. Neither reinvents the other.

> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** The App Insights connection string is a secret. Additionally — load-bearing for an *error-tracking* packet — the PII processor must ensure scrubbing never lets a secret value (API key, JWT) survive into a captured exception.

> **Invariant 9 — Vault is the only source of secrets.** The connection string is resolved via `ISecretStore` — the same secret ADR-0040 packet 02 seeded. No new secret for the error path in v1 (ADR-0045 D2).

> **Invariant 13 — All public APIs have XML documentation.**

> **Invariant 15 — Unit tests never depend on external services.** Error-capture and scrubbing tests run in-process against constructed `ExceptionTelemetry` — no live App Insights resource.

> **Invariant 26 — `## NuGet Dependencies` section required; `HoneyDrunk.Standards` on every new .NET project.**

> **Invariant 27 — All projects in a solution share one version and move together.** Perform the in-progress version-state check; bump or append; record the decision.

> **Invariant 51 — Test code contains no `Thread.Sleep`.**

> **Error-flow invariant (invariant 80, added by packet 00) — errors captured for the D8 capture-eligible cases flow through `IErrorReporter`, never via a direct backend SDK call.** This packet is the *only* place the App Insights SDK is touched for errors — it is the backing behind `IErrorSink`/`IErrorReporter`. Consuming Nodes never call `TelemetryClient` directly.

- **`ITelemetryProcessor` is correct here.** The error path uses the App Insights SDK directly (D3's carve-out); `ITelemetryProcessor` is the SDK's only filter hook. ADR-0040 D9's mechanism choice applies to the OTLP path, not the SDK path. Do not try to use an OTel `SpanProcessor` for SDK-captured exceptions.
- **Consume the shared `PiiScrubber`.** ADR-0040 packet 05 builds the PII scrubber as a shared, mechanism-agnostic component from the start. This packet consumes it — do not re-implement the regex set, do not refactor packet 05's code.
- **No new App Insights resource, no new secret, no new package.** Errors reuse the ADR-0040 resource and connection string (D2) and extend the existing `HoneyDrunk.Telemetry.Sink.AzureMonitor`.
- **`IErrorReporter` is a facade over `IErrorSink`.** Do not reinvent error capture — build an `ErrorEvent` and route it through the existing sink.

## Labels
`feature`, `tier-2`, `ops`, `adr-0045`, `wave-3`

## Agent Handoff

**Objective:** Extend `HoneyDrunk.Telemetry.Sink.AzureMonitor` with the App-Insights-SDK-based error backing, the `IErrorReporter` facade implementation, the `operation_id` cross-link, the `application_Version` release tag, and the error PII `ITelemetryProcessor`.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: Give the Grid a real error-capture path — `IErrorReporter` (facade) over `IErrorSink` backed by App Insights Failures, with native trace cross-link and PII scrubbing.
- Feature: ADR-0045 Grid-Wide Error Tracking rollout, Wave 3.
- ADRs: ADR-0045 D3/D4/D5/D6/D7 (primary), ADR-0040 D2/D9 (the OTLP carve-out and the shared PII-scrubbing surface), ADR-0023 (Evals carve-out), ADR-0005 (Vault), ADR-0026 (tenant/principal primitives).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. This packet implements the `IErrorReporter` facade packet 02 added.
- ADR-0040 packet 05 (cross-initiative) — hard. Packet 05 builds the shared PII scrubber this packet consumes. Express as `Architecture#<issue-number>` once filed.

**Constraints:**
- The App Insights error SDK lives in the Pulse sink package, never in a consuming Node.
- `ITelemetryProcessor` is the correct mechanism for the SDK error path — not an OTel `SpanProcessor`.
- Consume the shared `PiiScrubber` from ADR-0040 packet 05 — do not re-implement or refactor.
- `IErrorReporter` is a facade over the existing `IErrorSink` — do not reinvent error capture.
- Connection string from Vault — the same secret as ADR-0040 packet 02, no new secret (invariants 8, 9).
- Perform the invariant-27 version-state check on the `HoneyDrunk.Pulse` solution — bump or append; record the decision.

**Key Files:**
- `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Sink.AzureMonitor/` — error backing, `IErrorReporter` facade impl, error `ITelemetryProcessor`, DI registration
- The `HoneyDrunk.Telemetry.Sink.AzureMonitor` unit-test project
- `HoneyDrunk.Telemetry.Sink.AzureMonitor/CHANGELOG.md`; repo-level `CHANGELOG.md`

**Contracts:**
- Implements `IErrorSink` (existing) and the `IErrorReporter` facade (from packet 02). No contract change — this is the backing.
