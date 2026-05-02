---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Pulse
labels: ["feature", "tier-2", "ops", "telemetry", "adr-0026", "wave-1"]
dependencies: ["Kernel#NN — Grid multi-tenant primitives (packet 01) — Wave 1 lead"]
adrs: ["ADR-0026"]
wave: 1
initiative: adr-0026-grid-multi-tenant-primitives
node: pulse
coordinated_with: ["HoneyDrunk.Kernel", "HoneyDrunk.Data", "HoneyDrunk.Transport", "HoneyDrunk.Web.Rest"]
---

# Feature: Adopt typed TenantId on tenant_id telemetry tag with PDR-0002 cardinality discipline

## Summary
Update `ActivityEnricher` (and any sibling enrichers in `HoneyDrunk.Telemetry.OpenTelemetry`) to consume the typed `IGridContext.TenantId` introduced by packet 01, replacing the existing `string?` IsNullOrEmpty checks. Document the `tenant_id` tag's low-cardinality discipline in Pulse's docs / README, anchored on PDR-0002 §K kill criteria (paying customers measured in tens at v1; cardinality bound by Notify Cloud kill criteria). Bump the Pulse solution to its next minor version.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Pulse`

## Motivation
PDR-0002 §F lists `tenant_id` as a Pulse telemetry tag that needs cardinality discipline — at v1, paying customers are measured in tens, not millions. ADR-0026 D1–D2 promote `IGridContext.TenantId` and `IOperationContext.TenantId` from `string?` to a non-nullable `TenantId` strong type, making the existing Pulse enricher's `string.IsNullOrEmpty(context.TenantId)` checks obsolete (file `HoneyDrunk.Telemetry.OpenTelemetry/Enrichment/ActivityEnricher.cs` lines 31-34 and 53-56). After packet 01 ships, the enricher must consume the typed value instead.

**This packet is part of the coordinated Wave 1.** Per ADR-0026 D9 (revised) and the dispatch plan, Pulse is one of four downstream sister packets in Wave 1 (alongside Data, Transport, Web.Rest) that adapt to Kernel 0.5.0's typed `TenantId`. Each ships its own PR and version bump; the merge order within Wave 1 is **Kernel first**, then Data / Transport / Web.Rest / Pulse merge as soon as Kernel publishes (so each downstream restore resolves to Kernel 0.5.0 at PR-build time). Pulse is not Wave 2 — Wave 2 is Vault, which depends on the typed `TenantId` for its resolver but is not itself a typed-`TenantId` consumer-Node patch.

The cardinality discipline is the load-bearing rule: emitting `tenant_id` as a metric label without a customer-count ceiling would cause cardinality explosion in any time-series backend (Mimir, Prometheus, Azure Monitor metrics). PDR-0002 §K turns "tenant cardinality grows out of control" into an explicit kill criterion for Notify Cloud — if the customer count crosses a threshold that would cause Pulse cost to exceed value, the Notify Cloud product is killed. That ceiling is what makes `tenant_id` safe as a metric tag at v1.

## Proposed Implementation

### A. Adopt typed TenantId in `ActivityEnricher`

`HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.OpenTelemetry/Enrichment/ActivityEnricher.cs`:

Today's enricher uses `string?` IsNullOrEmpty checks:

```csharp
if (!string.IsNullOrEmpty(context.TenantId))
{
    activity.SetTag(TelemetryTagKeys.HoneyDrunk.TenantId, context.TenantId);
}
```

After packet 01, `context.TenantId` is `TenantId` (non-nullable, always present, default `TenantId.Internal` for header-less requests). The new emit predicate is `if (!context.TenantId.IsInternal)` — internal traffic is never tagged with a tenant ID (low-cardinality discipline starts at the source). Emit using `context.TenantId.ToString()` so the tag value is the ULID string form.

Apply the same change to:
- `EnrichWithOperationContext(Activity? activity, IOperationContext? context)` — `IOperationContext.TenantId` will likely also be promoted by packet 01 (verify; if `IOperationContext` exposes its own `TenantId` and packet 01 typed it, mirror the change here).
- `EnrichWithGridContext(Activity? activity, IGridContext? context)` — `context.TenantId.IsInternal` predicate.
- `EnrichWithGridContext(Activity? activity, string? gridId, string? tenantId)` — this overload takes a raw `string?`. Decision: keep this overload as-is for back-compat (it's used by code paths that already have a serialized tenant string, e.g., from a deserialized message), but document that callers with an `IGridContext` should use the typed overload. **Do not change this overload's signature in this packet** — it's a downstream-consumer-visible shape and changing it requires its own migration. Its body should still emit only when the value is non-empty AND parses to something other than the Internal sentinel — to avoid back-doors around the cardinality discipline. Pseudocode:
  ```csharp
  if (!string.IsNullOrEmpty(tenantId)
      && TenantId.TryParse(tenantId, out var parsed)
      && !parsed.IsInternal)
  {
      activity.SetTag(TelemetryTagKeys.HoneyDrunk.TenantId, tenantId);
  }
  ```

If `TelemetryTagKeys.HoneyDrunk.TenantId` is the canonical key today, keep it. Verify the tag key string is `tenant_id` (snake_case OpenTelemetry-style) — this is the wire format documented by PDR-0002 §F.

### B. Mirror the change in any sibling enrichers / collectors

`Pulse.Collector/Enrichment/TelemetryEnricher.cs` and `TelemetryEnricher.Log.cs` (per the existing code layout) — apply the same typed-TenantId pattern wherever they read `context.TenantId`. Verify by `rg "TenantId" --type cs` across the Pulse repo at execution time.

If Pulse has any code path that reads `IGridContext.TenantId` and treats it as a `string?` (e.g., a metrics emitter, a log scope factory), update each to consume the typed value with the `IsInternal` short-circuit.

### C. Cardinality discipline doc

Add a section to Pulse's docs (likely `HoneyDrunk.Pulse/HoneyDrunk.Telemetry.OpenTelemetry/README.md` or a new `docs/Tenancy.md` if Pulse follows Vault's docs/ pattern — pick whichever matches Pulse's existing convention; verify at execution by listing the docs structure). The section title is "Tenant Cardinality Discipline" or similar. Content:

1. **Why `tenant_id` is a tag, not a label per metric.** OpenTelemetry tags on traces are unbounded — Pulse's trace pipeline can carry arbitrary tenant IDs without backend cost growth. Metric labels are a different story — they become Prometheus / Mimir time-series multipliers. `tenant_id` is safe on metric labels ONLY because of the v1 customer-count ceiling.

2. **The v1 ceiling.** PDR-0002 §K kill criteria name "10–100 paying customers at v1" as the operating envelope. At 100 paying customers, `tenant_id` adds at most 100 unique values per metric — well within Mimir / Azure Monitor cost grants. At 1,000 customers without an ADR amendment, the model breaks. At 10,000 it is fatal.

3. **What enforces the ceiling.** The ceiling is enforced architecturally (PDR-0002 §K kill criteria) and operationally (Pulse alerts when distinct tenant_id count crosses a threshold — set the threshold in alert config to 200 distinct tenant IDs over a 24h window, suggesting the customer count has crossed the v1 envelope and ADR-0026 / PDR-0002 needs a follow-up). The alert config wiring is NOT part of this packet — it lives in alert-config infrastructure (see HoneyDrunk.Architecture's `infrastructure/log-analytics-workspace-and-alerts.md` for the pattern); this packet documents the threshold so an operator can wire it later.

4. **Internal traffic is never tagged.** The `IsInternal` short-circuit in the enricher means internal Grid traffic (Notify-internal, Communications-internal, anything calling itself with no tenant header) emits no `tenant_id` tag. This keeps the tag's cardinality bound to **paying customers only** — internal traffic is one giant unlabeled bucket, which is exactly what we want for cost-per-tag.

5. **What this is NOT.** Not a per-tenant SLO. Not a per-tenant dashboard generator. Not a billing pipeline (billing has its own `IBillingEventEmitter` channel introduced by packet 01). Pulse stays focused on telemetry; tenant-scoped commercial features live elsewhere.

6. **Tag key.** The canonical key is `tenant_id` (snake_case, OpenTelemetry semantic-convention style). Verify `TelemetryTagKeys.HoneyDrunk.TenantId` resolves to this string; if it doesn't, file a follow-up bug-fix packet rather than changing it here (changing tag keys is a downstream-breaking change that needs its own migration).

### D. Tests

Add tests in `Pulse.Tests/Collector/TelemetryEnricherTests.cs` (or wherever the existing enricher tests live):

1. **Internal-tenant traffic emits no `tenant_id` tag.** Build an `IGridContext` with `TenantId.Internal`. Call `ActivityEnricher.EnrichWithGridContext(activity, context)`. Assert `activity.Tags` does not contain a `tenant_id` entry.

2. **Non-internal tenant emits the ULID string.** Build an `IGridContext` with a known tenant ULID. Call enricher. Assert `activity.Tags["tenant_id"]` equals that ULID's string form.

3. **String-overload of `EnrichWithGridContext` rejects malformed tenant strings without emitting.** Pass `tenantId: "not-a-ulid"`. Assert no `tenant_id` tag was set.

4. **String-overload also rejects the Internal sentinel string.** Pass `tenantId: TenantId.Internal.ToString()`. Assert no `tenant_id` tag was set (the string-overload's parse-then-`IsInternal` check is the back-door defense).

Existing tests that assumed the `string?` shape on `context.TenantId` need updating to construct contexts with `TenantId` values rather than strings.

### E. Coordinated version bump

Per Invariant 27, every project in the Pulse solution moves to the same new version. Pulse is currently at `0.1.0` per its overview. Bump to `0.2.0` (minor — additive cardinality docs + breaking-only-internally enricher signature change driven by the upstream Kernel type change, no breaking change to `ITraceSink` / `ILogSink` / `IMetricsSink` contracts). Update every `.csproj` in the Pulse solution to `0.2.0`. Repo-level `CHANGELOG.md` gets a new `0.2.0` entry. Per-package `CHANGELOG.md` for `HoneyDrunk.Telemetry.OpenTelemetry/` and `Pulse.Collector/` are updated (both have actual changes). Sink packages and `HoneyDrunk.Telemetry.Abstractions/` get NO entries — no actual code changes (Invariant 12, no alignment-bump noise).

### F. README touch-up

Update Pulse's README (root and / or per-package as appropriate) to add a "Tenant Telemetry" subsection that links to the new cardinality discipline doc. Do NOT include the ADR ID per the no-ADR-in-docs convention.

## Affected Files

- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.OpenTelemetry/Enrichment/ActivityEnricher.cs` (edit)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/Pulse.Collector/Enrichment/TelemetryEnricher.cs` (edit)
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/Pulse.Collector/Enrichment/TelemetryEnricher.Log.cs` (edit if it reads tenant)
- Any other Pulse code reading `context.TenantId` — locate via `rg "TenantId" --type cs` at execution
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/Pulse.Tests/Collector/TelemetryEnricherTests.cs` (edit + new tests)
- New cardinality discipline doc — location TBD by Pulse's docs convention (verify at execution): either `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.OpenTelemetry/docs/Tenancy.md`, `HoneyDrunk.Pulse/docs/Tenancy.md`, or appended to an existing telemetry README
- All `.csproj` files in the Pulse solution — version bump to `0.2.0` (Invariant 27)
- Per-package `CHANGELOG.md` for `HoneyDrunk.Telemetry.OpenTelemetry/` and `Pulse.Collector/` only — actual changes
- Repo-root `CHANGELOG.md` — new `0.2.0` entry
- README updates (link to the cardinality doc)
- `HoneyDrunk.Kernel.Abstractions` PackageReference in Pulse's `.csproj`s — bump to the version produced by packet 01

## NuGet Dependencies

- `HoneyDrunk.Kernel.Abstractions` — already referenced; bump the version constraint to the version produced by packet 01 (target `0.5.0`).

No other `<PackageReference>` additions. The change is consuming an already-referenced type with a new shape.

## Boundary Check
- [x] All edits in `HoneyDrunk.Pulse`. Routing rule "telemetry, trace, metrics, logs, sink, ..., Pulse, collector" → `HoneyDrunk.Pulse` matches.
- [x] No change to `ITraceSink`, `ILogSink`, `IMetricsSink`, or `IAnalyticsSink`. Pulse's contract surface is unchanged.
- [x] Honors Pulse's existing boundaries: GridContext definition stays in Kernel; transport stays in Transport; sink credentials still come from Vault.
- [x] Cardinality doc lives in Pulse's docs (this is Pulse's discipline rule, not the Architecture repo's — Architecture would only own a Grid-wide cardinality invariant if one were proposed; ADR-0026 does not propose one).

## Acceptance Criteria

- [ ] `ActivityEnricher.EnrichWithGridContext(Activity? activity, IGridContext? context)` consumes the typed `TenantId` and emits the `tenant_id` tag only when `!context.TenantId.IsInternal`.
- [ ] `ActivityEnricher.EnrichWithOperationContext(Activity? activity, IOperationContext? context)` mirrors the same pattern (assuming packet 01 typed `IOperationContext.TenantId` — verify at execution).
- [ ] `ActivityEnricher.EnrichWithGridContext(Activity? activity, string? gridId, string? tenantId)` (the string overload) is preserved for back-compat but the body parses via `TenantId.TryParse` and rejects both null/empty/malformed values AND the Internal sentinel string before setting the tag.
- [ ] `Pulse.Collector/Enrichment/TelemetryEnricher.cs` (and `.Log.cs`) updated to consume the typed value where they read tenant.
- [ ] All four tests from section D pass.
- [ ] Existing enricher tests updated to construct contexts with the typed `TenantId` value.
- [ ] Cardinality discipline doc exists, anchored on the v1 customer-count ceiling and the alert threshold (200 distinct tenant IDs over 24h as the suggested operator alarm).
- [ ] Doc explicitly states the Internal short-circuit and the cardinality reasoning (internal traffic = one bucket).
- [ ] Doc explicitly states the canonical tag key is `tenant_id` (snake_case).
- [ ] No alert-config infrastructure was touched in this packet (alert wiring is a separate packet — this one only documents the suggested threshold).
- [ ] Every `.csproj` in the Pulse solution moves from `0.1.0` to `0.2.0` in a single commit (Invariant 27).
- [ ] Repo-level `CHANGELOG.md` has a new `0.2.0` entry covering the typed `TenantId` adoption and the cardinality doc.
- [ ] Per-package `CHANGELOG.md` updated for `HoneyDrunk.Telemetry.OpenTelemetry/` and `Pulse.Collector/`. No entries for sink packages or `HoneyDrunk.Telemetry.Abstractions/` (alignment-only — Invariant 12).
- [ ] Pulse's README links to the new cardinality discipline doc.
- [ ] Pulse `.csproj` reference to `HoneyDrunk.Kernel.Abstractions` is bumped to the version produced by packet 01.
- [ ] No change to `ITraceSink`, `ILogSink`, `IMetricsSink`, `IAnalyticsSink`. Verify with `git diff HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.Abstractions/`.
- [ ] No secret values logged. The enricher must never log a tenant-scoped secret value (this would be a defense-in-depth check; the resolver in packet 02 is responsible for not logging values, but Pulse should not introspect `BillingEvent.Attributes` either — verify by `rg "BillingEvent" --type cs` to confirm Pulse does not consume the type).
- [ ] All canary tests green; full unit-test suite green.

## Human Prerequisites
- [ ] **Confirm packet 01 (Kernel) merged and published.** This packet imports `TenantId.IsInternal` and reads the typed `IGridContext.TenantId` shape. If packet 01 is not merged + published when this packet runs, the build fails.
- [ ] **No alert config wiring required by this packet.** The cardinality discipline doc names a suggested threshold (200 distinct tenant IDs / 24h) for an operator alarm. Wiring that alarm into Azure Monitor / Mimir / wherever Pulse routes alerts is a separate packet under the operability initiative — not this one.
- [ ] No portal / Azure work for this packet. The change is library code + docs.

## Dependencies
- **Kernel#NN — Grid multi-tenant primitives (packet 01).** Hard dependency: typed `IGridContext.TenantId` and `TenantId.IsInternal`. Must be merged and the resulting NuGet version published before this packet can build green.

## Downstream Unblocks
- Wave 1 closure — once this packet merges (alongside the other Wave 1 sister packets — Data 01a, Transport 01b, Web.Rest 01c), Kernel 0.5.0 has working consumers and Wave 2 (Vault) can begin.
- Notify Cloud's telemetry has a single canonical source for the `tenant_id` tag — `IGridContext.TenantId.ToString()` filtered through `IsInternal`.
- Communications inherits the typed enrichment automatically.
- Architecture catalog packet (#04) — flips ADR-0026 to Accepted after Wave 1 (this packet + 01 + 01a + 01b + 01c) and Wave 2 (Vault packet 02) all merge.
- A future packet can wire the operator alarm at the documented 200-distinct-tenant-ID threshold.

## Referenced Invariants

> **Invariant 5 (Context):** GridContext must be present in every scoped operation. **Why it matters here:** The enricher reads `IGridContext` and must handle the typed `TenantId` correctly. The Internal-default behavior introduced by packet 01 means the enricher always reads a value (never null) — the `IsInternal` predicate is the new gate.

> **Invariant 8 (Secrets & Trust):** Secret values never appear in logs, traces, exceptions, or telemetry. **Why it matters here:** The enricher only emits the `tenant_id` ULID — never a secret value. Defense-in-depth: Pulse does not consume `BillingEvent` or any tenancy-scoped secret-bearing type.

> **Invariant 12 (Packaging):** Semantic versioning with CHANGELOG and README. Two tiers: repo-level (mandatory) and per-package (only when the package has functional changes — no noise entries for alignment bumps). **Why it matters here:** Repo-level `CHANGELOG.md` gets a `0.2.0` entry. Per-package CHANGELOGs only for `HoneyDrunk.Telemetry.OpenTelemetry/` and `Pulse.Collector/`. Sink packages and Abstractions get none.

> **Invariant 13 (Packaging):** All public APIs have XML documentation. **Why it matters here:** The cardinality discipline doc is referenced from XML docs on `ActivityEnricher` (a one-line `<remarks>` pointer is sufficient).

> **Invariant 14 (Testing):** Canary tests validate cross-Node boundaries. **Why it matters here:** Pulse's existing canary against Kernel context ownership invariants must continue to pass after the typed adoption.

> **Invariant 27 (Versioning):** All projects in a solution share one version and move together. **Why it matters here:** Pulse solution moves `0.1.0 → 0.2.0` in one commit. Sink packages bump version but get no per-package CHANGELOG noise.

> **Invariant 31 (Code Review):** Every PR traverses the tier-1 gate before merge.

## Referenced ADR Decisions

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **D1 — `TenantId` is a Kernel-Abstractions primitive.** This packet consumes the new `Internal` static and `IsInternal` predicate from packet 01.
- **D2 — `IGridContext.TenantId` is promoted to non-nullable `TenantId`.** This packet adopts the typed shape in the enricher.
- **D9 — Ordering — coordinated Wave 1.** Pulse adopts the typed shape in the same wave as Kernel 0.5.0 ships, alongside Data, Transport, and Web.Rest. Operational order: Kernel PR merges first within Wave 1 so the resulting Kernel 0.5.0 packages publish; Pulse PR then merges as soon as its build is green against published 0.5.0.
- **Unblocks (Pulse tenant-scoped telemetry):** "The `tenant_id` tag on Pulse telemetry has a single canonical source — `IGridContext.TenantId.ToString()` — so cardinality discipline is uniform across emitters." This packet is what realizes that uniform source.

**PDR-0002 (Notify Cloud) §F + §K — context only.**
- §F lists `tenant_id` as a Pulse telemetry tag with low-cardinality discipline.
- §K names a kill criterion: cardinality must stay bounded by the v1 customer-count envelope. The cardinality discipline doc anchors on this.

## Constraints

- **Do not change tag keys.** `tenant_id` is the canonical key — verify `TelemetryTagKeys.HoneyDrunk.TenantId` resolves to that string. If it doesn't, file a follow-up bug-fix packet; do not silently re-key in this packet.
- **String-overload of `EnrichWithGridContext` stays.** Removing or signature-changing it is a downstream-breaking change. Body changes are fine; signature changes are not in this packet's scope.
- **Internal short-circuit at the source.** The `IsInternal` check happens in the enricher — not in a downstream filter, not in the alert config, not in the sink. The cardinality discipline relies on internal traffic NEVER being tagged.
- **No alert wiring.** Document the suggested 200-distinct-tenant-IDs / 24h threshold; do not provision the alert. Alert provisioning is operability work.
- **No ADR ID in code / docs / README.** Per the no-ADR-in-docs convention, the new cardinality doc and any updated XML docs do NOT mention `ADR-0026` or `PDR-0002`. Describe the rule and the v1 customer-count envelope; do not link to the source documents. (Packet runtime data does reference the ADR / PDR.)
- **No new NuGet dependencies.** Verify `.csproj`s have no new `<PackageReference>` (only the version bump on the existing `HoneyDrunk.Kernel.Abstractions` reference).
- **Coordinated bump on every `.csproj`.** Sink packages bump to `0.2.0` per Invariant 27 but get no per-package CHANGELOG entries (Invariant 12).

## Labels
`feature`, `tier-2`, `ops`, `telemetry`, `adr-0026`, `wave-1`

## Agent Handoff

**Objective:** Adopt the typed `IGridContext.TenantId` from packet 01 in Pulse's enrichers, applying the `IsInternal` short-circuit so internal traffic is never tagged. Document the v1 cardinality discipline anchored on the customer-count envelope. Bump Pulse to `0.2.0`.

**Target:** `HoneyDrunk.Pulse`, branch from `main`.

**Context:**
- Goal: One canonical source for the `tenant_id` telemetry tag, with cardinality discipline at the source.
- Feature: ADR-0026 Grid Multi-Tenant Primitives, Wave 1 (coordinated multi-repo bump alongside Kernel + Data + Transport + Web.Rest).
- ADRs: ADR-0026 (multi-tenant primitives), PDR-0002 (Notify Cloud — context only for the cardinality envelope).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Kernel#NN — Grid multi-tenant primitives (packet 01). Hard. Provides typed `IGridContext.TenantId` and `TenantId.IsInternal`.

**Constraints:** Per Constraints section above. Specifically:
- Tag key stays `tenant_id`.
- String-overload signature unchanged.
- Internal short-circuit at the enricher, not downstream.
- No alert wiring in this packet.
- No ADR ID in code / docs / README.
- Coordinated `0.1.0 → 0.2.0` bump. Sink packages bump but get no CHANGELOG noise.

**Inlined Invariant Text (for review without leaving the target repo):**

> **Invariant 5:** GridContext must be present in every scoped operation.

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry.

> **Invariant 12:** Semantic versioning with CHANGELOG and README. Repo-level mandatory; per-package only when the package has functional changes (no noise on alignment bumps).

> **Invariant 13:** All public APIs have XML documentation.

> **Invariant 14:** Canary tests validate cross-Node boundaries.

> **Invariant 27:** All projects in a solution share one version and move together.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge.

**Key Files:**
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/HoneyDrunk.Telemetry.OpenTelemetry/Enrichment/ActivityEnricher.cs`
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/Pulse.Collector/Enrichment/TelemetryEnricher.cs`
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/Pulse.Collector/Enrichment/TelemetryEnricher.Log.cs`
- `HoneyDrunk.Pulse/HoneyDrunk.Pulse/Pulse.Tests/Collector/TelemetryEnricherTests.cs`
- New cardinality doc — location TBD by Pulse's docs convention
- All `.csproj` files in the Pulse solution
- Per-package `CHANGELOG.md` for `HoneyDrunk.Telemetry.OpenTelemetry/` and `Pulse.Collector/` only
- Repo-root `CHANGELOG.md` and `README.md`

**Contracts:**
- No change to `ITraceSink`, `ILogSink`, `IMetricsSink`, `IAnalyticsSink`, `IErrorSink`.
- Tag key `tenant_id` preserved.
- String-overload `EnrichWithGridContext(Activity?, string? gridId, string? tenantId)` signature preserved.
