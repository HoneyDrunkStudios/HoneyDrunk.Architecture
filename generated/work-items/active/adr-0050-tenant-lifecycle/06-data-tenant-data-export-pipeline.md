---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Data
labels: ["feature", "tier-2", "core", "adr-0050", "wave-4"]
dependencies: ["work-item:03"]
adrs: ["ADR-0050"]
wave: 4
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-data
---

# Implement the tenant-data export pipeline (ITenantDataExporter)

## Summary
Implement the ADR-0050 D7 data export contract in `HoneyDrunk.Data`: the `ITenantDataExporter` contract in `HoneyDrunk.Data.Abstractions`, a runtime that walks tenant-scoped repositories filtering by `TenantId` per ADR-0026's primitives, emits NDJSON + CSV + manifest.json + schema/*.json + README.md into a ZIP archive, uploads the ZIP to Azure Blob Storage, and returns a 7-day signed URL. Rate-limited to one export per tenant per 24 hours per D7. Audited via `TenantDataExported` event. Version-bumping packet for `HoneyDrunk.Data`.

## Context
ADR-0050 D7 commits the data export contract. Customers own their data; offboarding (and any point in the lifecycle) must produce a complete export. The format is a ZIP archive containing:
- `manifest.json` — version, tenant ID, export timestamp, included tables, record counts, schema version.
- `data/*.json` — NDJSON, one record per line, one file per logical entity type.
- `data/*.csv` — parallel CSV per relevant table, for non-developer-friendly inspection.
- `schema/*.json` — JSON schema documents for each entity type.
- `README.md` — explains the structure, schema versions, format guarantees.

**Scope (per D7):** tenant-scoped data only. The audit substrate is excluded (tenant is not the controller; audit holds pseudonymous tokens anyway). Pulse / Observe telemetry is excluded. Stripe billing records are excluded (customer can export from Stripe directly).

**Delivery:** a signed Azure Blob Storage URL, valid for 7 days. Trigger is self-serve via the tenant portal (eventually — this packet ships the export pipeline; the portal-facing trigger is a deferred follow-up Studios change). Rate limit: **one export per tenant per 24 hours.**

**Per the dispatch plan,** the export walks tenant-scoped repositories filtering by `TenantId` per ADR-0026's primitives (which exist today). It does NOT assume a particular per-tenant partition layout — when a Tenant-Data-Isolation ADR lands (currently absent; cited in ADR-0050 as "ADR-0049" but that citation is an error), the export contract is partition-agnostic and the implementation can grow partition-awareness behind the same surface.

`HoneyDrunk.Data` is a live Node at v0.6.0 (per the active-initiatives.md and overview doc). This packet is the **first packet on the `HoneyDrunk.Data` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.6.0` → `0.7.0`; new feature: the export pipeline; additive).

> **Hybrid sync/async note (per ADR-0050 D7 alternatives section).** D7 alternatives discuss synchronous-only vs hybrid sync/async delivery. The v1 path is **hybrid**: for small exports (under a partition-size threshold, decided at implementation time — start with 10 MB compressed estimate), generate the ZIP synchronously and return the signed URL inline. For larger exports, queue the export work, return immediately, and email the tenant owner the signed URL when generation completes. This packet ships the synchronous path; the async/email path is **deferred to a follow-up packet** because the async path requires (a) a queue substrate, (b) an email-on-export-complete template in `HoneyDrunk.Communications`, and (c) decisions about how the queue work is scheduled. The sync-only path is fine for v1 — partition sizes are small at v1 volume.

## Scope

### `HoneyDrunk.Data.Abstractions` — new contracts
- `ITenantDataExporter` — interface:
  - `ValueTask<TenantExportResult> ExportAsync(TenantId tenant, PseudoUserToken requestingUser, CancellationToken ct)` — generates the export, uploads to Blob, returns a result carrying the signed URL.
- `TenantExportResult` — record carrying: the signed URL, the URL's expiration timestamp (T+7 days), the export's blob name, the record-count summary (one count per entity type exported), the total uncompressed bytes, the total compressed bytes, the export timestamp.
- `TenantExportEntry` — record describing one logical entity type included in the export: entity-type name, table/repository name, record count, schema version.
- `TenantExportManifest` — record describing the manifest.json contents: schema version (start at `"1"`), tenant ID, export timestamp, included entries, requesting user token, total record count.
- `ITenantExportRateLimiter` — interface:
  - `ValueTask<bool> TryAcquireAsync(TenantId tenant, CancellationToken ct)` — returns true if the tenant has not exported in the last 24 hours; false otherwise.
- `TenantExportRateLimitException` — thrown when the rate limit is exceeded; the message names the next-allowed-at timestamp.

### `HoneyDrunk.Data` (runtime) — implementations
- `TenantDataExporter` implementation. Walks tenant-scoped repositories via the existing `IRepository<T>` / `IUnitOfWork` surface, filtering by `TenantId`. For each registered entity type:
  - Streams NDJSON to a temp file.
  - Streams CSV to a temp file (skipping nested/complex types that don't flatten cleanly — document the rule).
  - Generates the JSON schema for the type into a temp file.
- Builds `manifest.json` from `TenantExportManifest`.
- Generates `README.md` from a static template (the structure description, schema-version notes, format guarantees).
- ZIPs everything (`System.IO.Compression.ZipArchive`).
- Uploads the ZIP to Azure Blob Storage at a tenant-scoped path: `exports/{tenant_id}/{export_timestamp_ulid}.zip`.
- Generates a SAS (Shared Access Signature) URL valid for 7 days from generation, with read-only permissions.
- Returns a `TenantExportResult`.

In-memory `ITenantExportRateLimiter` default (mirrors the in-memory pattern across the Grid); a real implementation would use a small Cosmos/SQL table — deferred follow-up.

### Audit emission

The export emits a `TenantDataExported` audit event via `IAuditLog.Append(AuditEntry.CreatePseudonymous(..., AuditEvents.TenantDataExported, ...))` with the tenant's `PseudoTenantToken` and the requesting user's `PseudoUserToken`. Metadata: blob name, record-count summary, success/failure outcome. **This packet's audit emission is direct from the exporter** (the exporter has the tokens in hand — they're passed in to `ExportAsync` — and is composing audit at the natural boundary). Alternative routing through `HoneyDrunk.Communications` is unnecessary here: the export is a deterministic, single-shot operation, not an orchestrated cross-Node workflow.

### Configuration
- The Azure Blob Storage account / container name for exports — config-time. Default container name: `tenant-exports`.
- The signed-URL TTL — config-time, default 7 days (T+7 per D7).
- The rate-limit window — config-time, default 24 hours per tenant.

### Versioning
- Bump every non-test `.csproj` in the `HoneyDrunk.Data` solution to `0.7.0` in one commit (invariant 27).
- Repo-level `CHANGELOG.md` new `[0.7.0]` entry.
- `HoneyDrunk.Data.Abstractions/CHANGELOG.md` `[0.7.0]` entry.
- `HoneyDrunk.Data/CHANGELOG.md` `[0.7.0]` entry.
- READMEs updated.

## Proposed Implementation

### 1. Walking tenant-scoped repositories

The Grid's existing tenant-scoping primitive is `TenantId` per ADR-0026. Tenant-scoped repositories filter by `TenantId` already (per the existing `IRepository<T>` patterns). The exporter:

- Accepts a registered list of `ITenantExportableEntity` descriptors (entity-type name, repository accessor, schema version). The host registers each tenant-scoped entity it wants included.
- For each descriptor, calls `repository.Query().Where(e => e.TenantId == tenant).AsAsyncEnumerable()` (or the equivalent in the repository's API).
- Serializes each entity as NDJSON (one JSON object per line, `\n` terminator).
- Generates a CSV with a header row matching the entity's public properties; nested complex types serialize as JSON-stringified columns; nullable fields are blank cells.
- Generates the entity's JSON schema (using `System.Text.Json.Schema` or a similar generator).

The list of exportable entities **is empty in v1** — the contract surface exists, the runtime works, but no entity is registered out of the box because no Grid Node has tenant-scoped data yet (Auth's `Tenant` table is tenant-metadata, not tenant data the tenant owns; Communications' Prospect / decision-log records are operational, not tenant-owned). When Notify gains tenant-scoped message records, or when Billing scaffolds with tenant-scoped invoice records, those Nodes register their export descriptors via `services.AddTenantExportDescriptor<MessageRecord>(...)`.

The empty-export case (no descriptors registered) is acceptable and a tested code path: the manifest is empty, the ZIP contains only `manifest.json` + `README.md` ("No tenant-owned entities were exportable at this time. This is correct for the current Grid configuration."), the signed URL is still returned.

### 2. The ZIP layout

```
{export_timestamp_ulid}.zip
├── manifest.json
├── README.md
├── data/
│   ├── {entity-type-1}.ndjson
│   ├── {entity-type-1}.csv
│   ├── {entity-type-2}.ndjson
│   ├── {entity-type-2}.csv
│   └── ...
└── schema/
    ├── {entity-type-1}.schema.json
    ├── {entity-type-2}.schema.json
    └── ...
```

### 3. The signed URL

Use `Azure.Storage.Blobs` SDK to generate a SAS URL with:
- Read-only permission.
- 7-day expiration from generation.
- The SAS is generated using the account's user-delegation key (preferred) or the account key — config-time decision.

### 4. Rate limiting

```csharp
public async ValueTask<TenantExportResult> ExportAsync(TenantId tenant, PseudoUserToken requestingUser, CancellationToken ct)
{
    if (!await _rateLimiter.TryAcquireAsync(tenant, ct))
        throw new TenantExportRateLimitException(
            tenant,
            nextAllowedAt: /* now + remaining window */);

    // ... generate the export
}
```

The in-memory rate limiter is a simple `ConcurrentDictionary<TenantId, DateTimeOffset>` of last-export timestamps; if `now - lastExport < 24h`, return false.

### 5. Audit emission

After upload succeeds:

```csharp
var auditEntry = AuditEntry.CreatePseudonymous(
    id: AuditEntryId.New(),
    occurredAt: DateTimeOffset.UtcNow,
    actor: requestingUser,
    tenantToken: /* resolved from IIdentityMap by tenant id */,
    eventName: AuditEvents.TenantDataExported,
    category: AuditCategory.Action,
    outcome: AuditOutcome.Succeeded,
    target: new AuditTarget(...),
    metadata: new Dictionary<string, string>
    {
        ["blob_name"] = blobName,
        ["record_count"] = totalRecords.ToString(),
        ["compressed_bytes"] = compressedBytes.ToString(),
    });

await _auditLog.Append(auditEntry);
```

The tenant's `PseudoTenantToken` is resolved via `IIdentityMap.ResolveTenantAsync(tenant)` — packet 03's Auth-side `IIdentityMap` is wired here (TenantDataExporter takes `IIdentityMap` as a constructor dependency).

If the export *fails* (storage upload error, etc.), emit a `TenantDataExported` event with `AuditOutcome.Failed` and the failure reason in metadata. The audit substrate gets the record of attempted-and-failed; the exception is rethrown to the caller.

### 6. Tests

- Happy path with one registered entity: export runs, ZIP contains manifest + README + data + schema files for the entity, signed URL returned, audit event emitted.
- Empty-export path (no descriptors registered): ZIP contains manifest (empty entries array) + README explaining the empty result, signed URL still returned, audit event emitted.
- Rate-limit path: second export within 24 hours throws `TenantExportRateLimitException`; no audit event emitted (or an audit event with `Failed` outcome — implementation choice, document in tests).
- Failure path: storage upload fails; exception rethrown; audit event emitted with `Failed` outcome.
- NDJSON shape: each line is valid JSON; line count matches record count.
- CSV shape: header row matches entity properties; row count = record count + 1 (header).
- Manifest shape: entries list matches the descriptors that ran; record counts match the actual data.

## Affected Files
- `src/HoneyDrunk.Data.Abstractions/TenantExport/` — new folder with contracts (ITenantDataExporter, TenantExportResult, TenantExportEntry, TenantExportManifest, ITenantExportRateLimiter, TenantExportRateLimitException, ITenantExportableEntity)
- `src/HoneyDrunk.Data/TenantExport/` — new folder with implementations (TenantDataExporter, InMemoryTenantExportRateLimiter, ZipExportWriter, the manifest-builder, the README template)
- `src/HoneyDrunk.Data/DependencyInjection/ServiceCollectionExtensions.cs` (extended — `AddHoneyDrunkTenantExport`, `AddTenantExportDescriptor<T>`)
- Every non-test `.csproj` — version bump to `0.7.0`
- `src/HoneyDrunk.Data.Abstractions/CHANGELOG.md`, `README.md`
- `src/HoneyDrunk.Data/CHANGELOG.md`, `README.md`
- Repo-level `CHANGELOG.md`
- Test project(s) — the tests listed above

## NuGet Dependencies
- **`HoneyDrunk.Data.Abstractions`** — gain `HoneyDrunk.Auth.Abstractions` v0.6.0 (for `IIdentityMap` — used by the exporter to resolve the tenant token) and `HoneyDrunk.Audit.Abstractions` v0.2.0 (for `PseudoUserToken`, `PseudoTenantToken`, `AuditEvents`). The existing `HoneyDrunk.Kernel.Abstractions` is retained.
- **`HoneyDrunk.Data`** (runtime) — gain `Azure.Storage.Blobs` (latest stable, currently 12.x — confirm at execution time). Transitively gains the above Abstractions.
- Confirm exact versions at execution time — packets 02 and 03 set them.

## Boundary Check
- [x] The export pipeline is **persistence and data-shape**, not orchestration. It belongs in `HoneyDrunk.Data` per the existing patterns (`IRepository<T>`, `IUnitOfWork`, the outbox). Routing rule "persistence, repository, tenant data, ... → HoneyDrunk.Data" maps exactly.
- [x] The signed-URL emission uses Azure Blob Storage; this is the existing pattern for Grid-internal blob handling (per `HoneyDrunk.Data` conventions). No new vendor.
- [x] Audit emission goes through `IAuditLog.Append` with `AuditEntry.CreatePseudonymous` from packet 02 — preserves invariant 47 (audit append-only) and satisfies invariant 78 (pseudonymous tokens only).
- [x] Tenant-scoping uses ADR-0026's `TenantId` primitive — preserves invariant 39 (tenant mechanics at intake/post-dispatch boundaries).

## Acceptance Criteria
- [ ] `HoneyDrunk.Data.Abstractions` exposes `ITenantDataExporter` with `ExportAsync(TenantId, PseudoUserToken, CancellationToken)`
- [ ] `HoneyDrunk.Data.Abstractions` exposes `TenantExportResult`, `TenantExportEntry`, `TenantExportManifest`, `ITenantExportRateLimiter`, `TenantExportRateLimitException`, `ITenantExportableEntity`
- [ ] `HoneyDrunk.Data` ships `TenantDataExporter` implementation: walks registered tenant-scoped entities filtering by `TenantId`, emits NDJSON + CSV + JSON schema per entity, builds manifest.json + README.md, ZIPs everything, uploads to Azure Blob Storage, returns a 7-day signed URL
- [ ] Rate limit: a second export within 24 hours throws `TenantExportRateLimitException` naming the next-allowed timestamp
- [ ] Audit emission: every export (success or failure) emits a `TenantDataExported` event via `IAuditLog.Append(AuditEntry.CreatePseudonymous(...))` using the tenant's `PseudoTenantToken` (resolved via `IIdentityMap`) and the requesting user's `PseudoUserToken`
- [ ] Empty-export path (no registered entities) returns a valid manifest with empty entries list + README explaining the empty result + a signed URL — does not throw
- [ ] DI extensions `AddHoneyDrunkTenantExport()` and `AddTenantExportDescriptor<T>()` register the exporter and the per-entity descriptors
- [ ] Configuration carries the Blob storage account/container name and the signed-URL TTL (default 7 days)
- [ ] All new public types have XML documentation (invariant 13)
- [ ] Every non-test `.csproj` in the solution is at `0.7.0` in a single commit (invariant 27)
- [ ] Repo-level `CHANGELOG.md` has a new `[0.7.0]` entry
- [ ] `HoneyDrunk.Data.Abstractions/CHANGELOG.md` and `HoneyDrunk.Data/CHANGELOG.md` have `[0.7.0]` entries
- [ ] READMEs updated to document the export contract
- [ ] Tests cover happy path, empty-export, rate limit, failure-with-audit, NDJSON shape, CSV shape, manifest shape
- [ ] Tests contain no `Thread.Sleep` (invariant 51)
- [ ] The `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Azure Blob Storage container exists for tenant exports** — a `tenant-exports` container in a Grid-shared or Data-owned Storage Account (`sthd{purpose}{env}` per Grid naming). Free tier is fine for v1 (object count and TTL are both small).
- [ ] **SAS user-delegation key configured (preferred) OR account key seeded in Vault** — the runtime needs credentials to generate signed URLs. User-delegation-key with the Data Node's Managed Identity is the preferred path (per ADR-0006 Vault-namespaced secrets); account-key in the Data Node's Vault namespace is the fallback. The choice is implementation-time.
- [ ] **Blob lifecycle rule for the export container** — set up a 30-day lifecycle rule to auto-delete exports older than 30 days. Exports are short-lived signed-URL-accessed artifacts; permanent retention is wasted storage. Configure in the portal under Storage Account → Lifecycle management. Cost: negligible at v1 volume.
- [ ] No Studios portal change in this packet — the customer-facing "Download my data" trigger is a deferred follow-up tied to the eventual Studios admin console + tenant portal work.

## Referenced ADR Decisions

**ADR-0050 D7 — Data export contract.** ZIP archive with manifest.json + data/*.ndjson + data/*.csv + schema/*.json + README.md. Tenant-scoped data only — audit, telemetry, Stripe records are explicitly excluded. Signed Azure Blob URL valid for 7 days. Self-serve trigger (eventually via tenant portal — deferred). Rate-limited to one export per tenant per 24 hours. Audited via `TenantDataExported` event referencing pseudonymous tokens.

**ADR-0050 D5 — Offboarding-window exports.** During the 30-day Offboarding grace window, the tenant portal remains accessible for export purposes only. This packet ships the export pipeline; the offboarding-window-specific portal path is a deferred follow-up.

**ADR-0050 D7 alternatives — Sync-only vs hybrid sync/async delivery.** v1 ships synchronous-only; async/email path is a deferred follow-up.

**ADR-0026 — `TenantId` primitive (referenced).** The export walks repositories filtering by `TenantId`. Tenant-scoping mechanics are unchanged.

**ADR-0050 D6 — `TenantDataExported` audit event uses pseudonymous tokens.** Tenant's `PseudoTenantToken` (resolved via `IIdentityMap.ResolveTenantAsync`); requesting user's `PseudoUserToken`. The audit substrate carries the operational record without PII; invariants 47 and 78 are preserved.

**Invariant 27 (constraint) — Solution-wide version bump.** `0.6.0 → 0.7.0` for `HoneyDrunk.Data` in one commit.

**Invariant 39 (referenced) — Tenant mechanics at intake/post-dispatch boundaries.** The exporter is a post-dispatch operation; tenant resolution + filter happens at the exporter's entry, not in shared dispatch paths.

**Invariant 47 (referenced) — Audit substrate is append-only.** `TenantDataExported` event uses `IAuditLog.Append` (append-only).

**Invariant 78 (this initiative) — Audit substrate accepts only pseudonymous tokens.** The export's audit emission uses `AuditEntry.CreatePseudonymous` with `PseudoTenantToken` + `PseudoUserToken`.

## Constraints
- **Tenant-scoped data only.** The export must NOT include the audit substrate, Pulse/Observe telemetry, Stripe records, or any data the tenant is not the controller for. This is a load-bearing privacy / boundary commitment — the test suite must verify the exclusions explicitly.
- **The exportable-entity registry is empty by default.** No registered descriptors out of the box. Hosts compose `services.AddTenantExportDescriptor<T>(...)` when they have tenant-owned entities. The empty case is a tested code path returning an empty manifest + a README explaining the empty result.
- **Synchronous-only delivery for v1.** Do NOT scaffold the async/email path in this packet. The async path requires a queue substrate and a Communications-side email template — both deferred. The sync path is sufficient for v1 partition sizes.
- **Signed URL TTL is 7 days, configurable.** Default 7 days per D7. Configuration may override; the default is 7.
- **Rate limit is 24 hours per tenant, configurable.** Default 24 hours per D7. Configuration may override.
- **Audit emissions use the new pseudonymous-token factory.** `AuditEntry.CreatePseudonymous(...)` from packet 02. Never the legacy `string Actor` constructor.
- **Failure paths emit a Failed audit event.** Don't swallow the exception or skip the audit emission on storage failure.
- **`HoneyDrunk.Data.Abstractions` stays Abstractions-only.** New references to `HoneyDrunk.Auth.Abstractions` and `HoneyDrunk.Audit.Abstractions` are acceptable (both are Abstractions packages, invariant 1 preserved). No new HoneyDrunk runtime dependencies.
- **Records drop the `I`.** `TenantExportResult`, `TenantExportEntry`, `TenantExportManifest` are records. Interfaces keep `I`.
- **Invariant 27 — version bump every non-test `.csproj` in one commit.** No partial bumps.

## Labels
`feature`, `tier-2`, `core`, `adr-0050`, `wave-4`

## Agent Handoff

**Objective:** Implement the tenant-data export pipeline in `HoneyDrunk.Data`: contract surface in Abstractions, runtime that emits a ZIP with manifest + NDJSON + CSV + schema + README, uploads to Azure Blob, returns a 7-day signed URL, rate-limited per tenant per day, audited via `TenantDataExported`. Bump the solution to `0.7.0`.

**Target:** `HoneyDrunk.Data`, branch from `main`.

**Context:**
- Goal: Ship the export pipeline ADR-0050 D7 specifies. The customer-portal trigger and the async/email delivery path are deferred follow-ups; this packet ships the sync export contract + runtime.
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 4.
- ADRs: ADR-0050 D5/D6/D7 (primary), ADR-0026 (`TenantId` primitive), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:03` — `HoneyDrunk.Auth` v0.6.0 ships `IIdentityMap` (used to resolve the tenant's `PseudoTenantToken`).

**Constraints:**
- **Tenant-scoped data only.** Exclude audit, telemetry, Stripe records. Test the exclusions.
- **Empty exportable-entity registry is a valid path.** No registered descriptors → empty manifest + explanatory README + valid signed URL.
- **Synchronous-only delivery for v1.** Don't scaffold the async/email path here.
- **Rate limit 1 per 24h per tenant; signed URL TTL 7 days; both configurable.**
- **Audit emissions use `AuditEntry.CreatePseudonymous` with pseudonymous tokens.** Resolve the tenant token via `IIdentityMap`.
- Records drop the `I`; interfaces keep it.
- Bump every non-test `.csproj` to `0.7.0` in one commit (invariant 27). This is the bumping packet for `HoneyDrunk.Data` in this initiative.

**Key Files:**
- `src/HoneyDrunk.Data.Abstractions/TenantExport/` (new folder with contracts)
- `src/HoneyDrunk.Data/TenantExport/` (new folder with implementations)
- DI extension
- Every non-test `.csproj` for the version bump
- Repo-level `CHANGELOG.md`; per-package CHANGELOGs; READMEs

**Contracts:**
- `ITenantDataExporter` (new interface) — `ExportAsync(TenantId, PseudoUserToken, CancellationToken)`.
- `TenantExportResult`, `TenantExportEntry`, `TenantExportManifest` (new records).
- `ITenantExportRateLimiter`, `TenantExportRateLimitException`.
- `ITenantExportableEntity` — descriptor for hosts to register tenant-scoped entities.
- Default runtime + in-memory rate limiter in `HoneyDrunk.Data`.
