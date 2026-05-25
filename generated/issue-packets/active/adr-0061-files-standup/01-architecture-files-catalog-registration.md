---
name: Architecture Catalog Registration
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "files", "adr-0061"]
dependencies: []
adrs: ["ADR-0061"]
accepts: ADR-0061
wave: 1
initiative: adr-0061-files-standup
node: honeydrunk-files
---

# Chore: Register HoneyDrunk.Files's standup decisions in Architecture catalogs

## Summary
Land the catalog and reference-doc surface for `HoneyDrunk.Files` per ADR-0061's "If Accepted — Required Follow-Up Work" checklist. Add the new Core-sector Node to every catalog file (`nodes.json`, `relationships.json`, `grid-health.json`, `modules.json`, `contracts.json`), add the Core-sector Files row to `constitution/sectors.md`, add the Files row and Azure backing rows to `infrastructure/reference/tech-stack.md`, add the roadmap bullet under Q2 2026, add an in-progress entry to `initiatives/active-initiatives.md`, and create the `repos/HoneyDrunk.Files/` context folder (`overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`) matching the template used by `repos/HoneyDrunk.Audit/` and `repos/HoneyDrunk.Communications/`.

ADR-0061 stays at `Status: Proposed` for this packet — the Status flip is a separate post-merge housekeeping step the scope agent handles after the entire initiative completes, per the user's standing ADR acceptance workflow. This packet's body does not edit the ADR header.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0061 establishes the `HoneyDrunk.Files` Node's sector and purpose (D1), its package families (D3), its exposed contracts (D6), its tenant-isolation strategy (D5), its dependency edges (D6), and its initial scaffolding boundary. None of that has reached the canonical catalogs yet. Until it does, every downstream consumer (the PDR-driven app Nodes Hearth/Lately/Currents/Curiosities, Notify Cloud's tenant-attachment story, any future Studios-product surface needing avatars) reads stale metadata when scoping its own work, and the scaffold packet (packet 04 of this initiative) has nothing to anchor its `node:` frontmatter or its in-Architecture context-folder cross-references against.

Eight catalog/doc surfaces drift today:

1. **`catalogs/nodes.json`** carries no `honeydrunk-files` entry. The Core sector currently ends at Audit; Files must slot in next to the other Core substrate Nodes.
2. **`catalogs/relationships.json`** has no `honeydrunk-files` block. The new edges (consumes Kernel/Vault/Data/Transport/Auth/Audit; consumed_by_planned the first PDR consumers) need to land in lockstep with the Node entry.
3. **`catalogs/grid-health.json`** has no Files row. Stand-up state is empty (no `v0.1.0` yet, no Azure resources, scaffold packet pending) — the row must reflect that honestly.
4. **`catalogs/modules.json`** has no Files package entries. ADR-0061 D3 commits four packages (`HoneyDrunk.Files.Abstractions`, `HoneyDrunk.Files`, `HoneyDrunk.Files.InMemory`, `HoneyDrunk.Files.AzureBlob`); all four need module entries at version 0.0.0 pre-scaffold.
5. **`catalogs/contracts.json`** has no Files contracts block. The five D6 contracts (`IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`) plus the supporting records (`FileDescriptor`, `UploadRequest`, `UploadSession`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy`) must be registered with `status: seed` so downstream Nodes can find the canonical surface.
6. **`constitution/sectors.md`** Core-sector table ends at Audit. Files must be added as a Seed row with the responsibility line.
7. **`infrastructure/reference/tech-stack.md`** has no Files entry in the Nodes table; Azure Blob Storage, Azure Defender for Storage, and Azure Front Door (CDN) all need rows under the storage/security/edge sections so the substrate is named alongside the other Azure surfaces the Grid already commits to.
8. **`initiatives/roadmap.md`** and **`initiatives/active-initiatives.md`** have no Files entries. The Q2 2026 (Apr–Jun) section is where this Node lives, given the named PDR-0005 Hearth driver.

The `repos/HoneyDrunk.Files/` context folder does not exist on disk — confirmed by `ls repos/` showing the sibling Core-sector folders (`HoneyDrunk.Audit/`, `HoneyDrunk.Communications/`, etc.) but no `HoneyDrunk.Files/`. This packet creates it with the four standard files matching the Audit template's shape.

The ADR Status flip (Proposed → Accepted) is intentionally **not** in this packet. Per the user's standing ADR acceptance workflow (`feedback_adr_workflow.md`), the scope agent flips Status only after the entire initiative's PRs have merged. This is a separate post-merge housekeeping step that runs after packets 01 / 02 / 03 / 04 are all closed — not a line-edit on this packet.

## Proposed Implementation

### `catalogs/nodes.json` — new `honeydrunk-files` entry

**Anchor semantically, not by line number.** The `honeydrunk-audit` and `honeydrunk-pulse` blocks may have AI-sector Nodes between them in the current `nodes.json` (confirmed at scoping time: `honeydrunk-audit` opens at line 312 and `honeydrunk-pulse` opens at line 357 with intervening Node entries). At edit time, re-grep `rg -n '"id": "honeydrunk-audit"' catalogs/nodes.json` and `rg -n '"id": "honeydrunk-pulse"' catalogs/nodes.json` to find the current positions, then insert the new `honeydrunk-files` block **at the end of the Core-sector substrate run** — i.e., immediately after the closing brace + comma of the `honeydrunk-audit` block and before the next sibling Node entry (whichever that turns out to be). Do not rely on the line numbers cited anywhere in this packet; treat them as scoping-time hints only and re-confirm by grep at edit time.

The new block follows the same schema every other Core-sector Node uses (see `honeydrunk-audit` and `honeydrunk-data` for shape reference).

```json
{
  "id": "honeydrunk-files",
  "type": "node",
  "name": "HoneyDrunk.Files",
  "public_name": "HoneyDrunk.Files",
  "short": "Grid-wide blob storage, media processing, signed-URL delivery",
  "description": "The Grid's single Node for bytes + bytes-metadata. Owns blob storage, media processing (thumbnails, resize, format conversion, EXIF stripping), malware scanning, signed-URL issuance, public CDN-fronted delivery, per-tenant quota enforcement, soft-delete and retention, and the deletion cascade for tenant offboarding and GDPR Article 17 user erasure. Backing-agnostic by contract; Azure Blob Storage is the v1 default.",
  "sector": "Core",
  "signal": "Seed",
  "cluster": "core-substrate",
  "energy": 0,
  "priority": 0,
  "flow": 0,
  "tags": ["files", "blob-storage", "media-processing", "signed-url", "cdn", "quota", "retention", "substrate"],
  "links": {
    "repo": "https://github.com/HoneyDrunkStudios/HoneyDrunk.Files"
  },
  "long_description": {
    "overview": "HoneyDrunk.Files is the Core sector's single Node for bytes + bytes-metadata. It owns blob storage, media processing (thumbnails, resize, format conversion, EXIF stripping), malware scanning, signed-URL issuance, public CDN-fronted delivery, per-tenant quota enforcement, soft-delete and retention windows, and the deletion cascade that supports tenant offboarding and GDPR Article 17 user erasure. It is the analog of Data for structured persistence, Vault for secrets, and Audit for the security record substrate.",
    "why_it_exists": "The Grid had no Node that owned the bytes themselves. Notify treated attachments as opaque provider-direct payloads (the bytes round-tripped through Resend/Twilio and were gone). Data was deliberately not a blob store. Vault's per-secret 8 KB budget made it categorically unsuitable. Every PDR-driven app (Hearth, Lately, Currents, Curiosities) assumes user-uploaded media but no Node owned signed-URL issuance, malware scanning, per-tenant quota, retention, or CDN-fronted public delivery. Files is the substrate that lets every consumer be mechanical work against a settled foundation rather than re-inventing the same eight capabilities at the wrong layer.",
    "primary_audience": "Every Grid consumer that needs to store, retrieve, or process user-uploaded bytes — PDR-0005 Hearth (journal media; the named first consumer), PDR-0003 Lately (avatars, photos), PDR-0006 Currents, PDR-0008 Curiosities, PDR-0002 Notify Cloud tenants (durable attachments), Studios product surfaces (avatars, marketing assets).",
    "value_props": [
      "Single Grid Node owns bytes + bytes-metadata — backing-agnostic by contract",
      "Signed-URL direct-to-blob upload — the API never proxies bytes",
      "Async processing pipeline (thumbnail/resize/format conversion/EXIF strip/virus scan) idempotent by file_id",
      "Per-tenant quota enforcement at SAS issuance — declared-size limits enforced before any byte is uploaded",
      "Public CDN-fronted delivery for public assets; short-lived SAS for private assets — no long-lived shared-key URLs",
      "Soft-delete with configurable retention; hard-delete cascade for tenant offboarding and GDPR erasure",
      "Tenant isolation enforced at SAS prefix-constraint and metadata-read level"
    ],
    "monetization_signal": "Internal-first Core primitive. The substrate that lets every PDR-driven consumer ship media features without bespoke per-app blob layers.",
    "roadmap_focus": "Stand up the Node, Abstractions package, InMemory reference adapter, and empty AzureBlob placeholder (ADR-0061). Azure resource provisioning, the real AzureBlob adapter, the processing pipeline implementation, and the malware-scan integration follow with the first feature packet activated by a real consumer (likely PDR-0005 Hearth).",
    "grid_relationship": "Consumes Kernel (IGridContext, lifecycle, telemetry), Vault (storage account credentials, SAS signing keys), Data (metadata persistence — the bytes-metadata table), Transport (processing pipeline messages and FileAvailable / TenantOffboarding / UserErasureRequest events), Auth (authorization policy on signed-URL issuance), and Audit (IAuditLog for Restricted-tier upload/download/deletion events). Emits operational telemetry consumed by Pulse — no runtime dependency on Pulse. Consumed (planned) by Hearth, Lately, Currents, Curiosities, Notify Cloud tenants, and Studios product surfaces. Downstream Nodes compile only against HoneyDrunk.Files.Abstractions.",
    "integration_depth": "deep",
    "demo_path": "Initiate IFileUploadSession.Initiate(UploadRequest) → receive signed_upload_url → client uploads bytes directly to InMemory store → BlobCreated event fires → processing pipeline runs (scan + EXIF strip + thumbnail) → FileAvailable event emitted → IFileStore.GetDownloadUrl returns short-lived read URL → bytes round-trip.",
    "signal_quote": "The bytes have a home.",
    "stability_tier": "seed",
    "impact_vector": "consumer-app substrate"
  },
  "foundational": false,
  "strategy_base": 14,
  "tier": "none",
  "time_pressure": 1,
  "done": false,
  "cooldown_days": 14
},
```

### `catalogs/relationships.json` — new `honeydrunk-files` block

**Anchor semantically, not by line number.** Add a new entry to the `nodes` array, placed adjacent to the other Core-sector substrate entries — immediately after the `honeydrunk-audit` block is the natural position. Find the current position via `rg -n '"id": "honeydrunk-audit"' catalogs/relationships.json` at edit time. Also amend six existing entries' `consumed_by_planned` arrays to record the new upstream dependency (find each via grep — `rg -n '"id": "honeydrunk-<name>"' catalogs/relationships.json`):

- `honeydrunk-kernel`: append `"honeydrunk-files"` to `consumed_by_planned`.
- `honeydrunk-vault`: append `"honeydrunk-files"` to `consumed_by_planned`.
- `honeydrunk-data`: append `"honeydrunk-files"` to `consumed_by_planned`.
- `honeydrunk-transport`: append `"honeydrunk-files"` to `consumed_by_planned`.
- `honeydrunk-auth`: append `"honeydrunk-files"` to `consumed_by_planned`.
- `honeydrunk-audit`: append `"honeydrunk-files"` to `consumed_by_planned`.

The new Files entry:

```json
{
  "id": "honeydrunk-files",
  "consumes": ["honeydrunk-kernel", "honeydrunk-vault", "honeydrunk-data", "honeydrunk-transport", "honeydrunk-auth", "honeydrunk-audit"],
  "consumed_by": [],
  "consumed_by_planned": ["honeydrunk-notify", "honeydrunk-communications"],
  "blocked_by": [],
  "exposes": {
    "contracts": ["IFileStore", "IFileUploadSession", "IFileMetadata", "IFileProcessor", "IFileQuotaPolicy", "FileDescriptor", "UploadRequest", "UploadSession", "SignedDownloadUrl", "QuotaSnapshot", "RetentionPolicy"],
    "packages": ["HoneyDrunk.Files.Abstractions", "HoneyDrunk.Files", "HoneyDrunk.Files.InMemory", "HoneyDrunk.Files.AzureBlob"]
  },
  "consumes_detail": {
    "honeydrunk-kernel": ["IGridContext", "IOperationContext", "IStartupHook", "IHealthContributor", "ITelemetryActivityFactory", "TenantId", "HoneyDrunk.Kernel.Abstractions"],
    "honeydrunk-vault": ["ISecretStore", "IConfigProvider", "HoneyDrunk.Vault"],
    "honeydrunk-data": ["IRepository", "IUnitOfWork", "HoneyDrunk.Data.Abstractions"],
    "honeydrunk-transport": ["ITransportPublisher", "ITransportConsumer", "HoneyDrunk.Transport"],
    "honeydrunk-auth": ["IAuthorizationPolicy", "HoneyDrunk.Auth.Abstractions"],
    "honeydrunk-audit": ["IAuditLog", "AuditEntry", "HoneyDrunk.Audit.Abstractions"]
  }
},
```

**Note on `consumed_by_planned`:** The ADR's "If Accepted" list names "Hearth, Lately, and any Studios-product surface" as future consumers. None of those Nodes have a stand-up ADR yet (no `honeydrunk-hearth` / `honeydrunk-lately` ids exist in `nodes.json` as of 2026-05-24). Listing them as future planned consumers in catalog form would invent Node ids that have not been committed. **Do not list non-existent Node ids in `consumed_by_planned`.** The two entries above (`honeydrunk-notify` and `honeydrunk-communications`) are the actual existing Nodes named in ADR-0061 D13 as compatibility consumers (Notify's attachment-via-file_id support; Communications referencing file_id in digest sends). When each PDR-driven app standup ADR lands (Hearth first, per PDR-0005 + scout's pick), that ADR's own Wave-1 catalog packet adds the bidirectional edge.

### `catalogs/grid-health.json` — new `honeydrunk-files` row

**Anchor semantically.** Insert a new row into the `nodes` array, immediately after the `honeydrunk-audit` row. Find the current position via `rg -n '"id": "honeydrunk-audit"' catalogs/grid-health.json` at edit time — do not trust scoping-time line citations. The row reflects empty-stand-up state — no `v0.1.0` yet, no Azure resources, no canary baseline.

```json
{
  "id": "honeydrunk-files",
  "name": "HoneyDrunk.Files",
  "sector": "Core",
  "signal": "Seed",
  "version": "0.0.0",
  "canary_status": "none",
  "last_release": null,
  "active_blockers": [
    "GitHub repo not yet created (packet 03 of adr-0061-files-standup)",
    "Scaffold packet (packet 04 of adr-0061-files-standup) not yet executed"
  ],
  "notes": "ADR-0061 standup ADR Proposed 2026-05-23 (Status flip to Accepted is a separate post-merge housekeeping step after the initiative completes). Catalog surface registered (5 contracts + 6 supporting records per D6: IFileStore, IFileUploadSession, IFileMetadata, IFileProcessor, IFileQuotaPolicy, plus FileDescriptor/UploadRequest/UploadSession/SignedDownloadUrl/QuotaSnapshot/RetentionPolicy). Awaiting GitHub repo creation (human-only, packet 03) and scaffold execution: HoneyDrunk.Files.Abstractions (zero HoneyDrunk dependencies; near-minimal contract surface), HoneyDrunk.Files runtime (composition, lifecycle, upload-session orchestrator, processing-pipeline dispatcher), HoneyDrunk.Files.InMemory (reference adapter for unit tests), HoneyDrunk.Files.AzureBlob (placeholder project at standup; real implementation deferred to first feature packet), Standards wiring, CI with contract-shape canary scoped to Abstractions. No Azure resources provisioned at standup — Azure Blob Storage / Defender for Storage / Front Door / CDN profile / Key Vault are all first-feature-packet decisions when PDR-0005 Hearth (the named first consumer) activates Files."
},
```

Also update the `summary.blocked_nodes` array at the bottom of the file — append `"honeydrunk-files"` and bump `summary.total_nodes`, `summary.seed`, and `summary.canary_none` each by 1. **Read the actual current values from `summary` at edit time** (find via `rg -n '"summary"' catalogs/grid-health.json`); scoping-time counts may have shifted if other Nodes flipped to Live or were added in the interim.

### `catalogs/modules.json` — four new module entries

Append four entries to the modules array (file is a flat JSON array). All four start at `version: "0.0.0"` reflecting empty pre-scaffold state. After the scaffold packet (packet 04) lands `v0.1.0`, a separate post-scaffold catalog reconciliation bumps these to 0.1.0 — that bump is the follow-up packet `05-architecture-files-post-release-version-bump.md` (filed at the same time as this initiative but parked behind `v0.1.0` shipping).

**Anchor semantically.** Insert immediately after the existing `audit-data` entry — find its position via `rg -n '"id": "audit-data"' catalogs/modules.json` at edit time:

```json
{
  "id": "files-abstractions",
  "nodeId": "honeydrunk-files",
  "name": "HoneyDrunk.Files.Abstractions",
  "type": "abstractions",
  "version": "0.0.0",
  "description": "Near-minimal contracts for the Grid's blob substrate — IFileStore, IFileUploadSession, IFileMetadata, IFileProcessor, IFileQuotaPolicy, plus supporting FileDescriptor/UploadRequest/UploadSession/SignedDownloadUrl/QuotaSnapshot/RetentionPolicy records. Backing-agnostic by design."
},
{
  "id": "files-runtime",
  "nodeId": "honeydrunk-files",
  "name": "HoneyDrunk.Files",
  "type": "runtime",
  "version": "0.0.0",
  "description": "Runtime composition for the Files Node — DI registration, lifecycle hooks, telemetry, upload-session orchestrator, processing-pipeline dispatcher. Backing adapters compose alongside (InMemory for tests; AzureBlob for production)."
},
{
  "id": "files-inmemory",
  "nodeId": "honeydrunk-files",
  "name": "HoneyDrunk.Files.InMemory",
  "type": "testing",
  "version": "0.0.0",
  "description": "In-process IFileStore reference adapter for unit tests and the first integration scenarios. Deterministic SAS-token analog; pass-through fake virus scan."
},
{
  "id": "files-azureblob",
  "nodeId": "honeydrunk-files",
  "name": "HoneyDrunk.Files.AzureBlob",
  "type": "provider",
  "version": "0.0.0",
  "description": "Placeholder project at standup carrying the .NET version, analyzers, and CI wiring; no implementation on day one. Azure adapter lands with the first feature packet that activates Files (likely PDR-0005 Hearth)."
}
```

### `catalogs/contracts.json` — new `honeydrunk-files` block

Append a new entry to the `contracts` array. Schema mirrors every other Node's block — find the `honeydrunk-audit` entry via `rg -n '"node": "honeydrunk-audit"' catalogs/contracts.json` at edit time for the closest substrate example:

```json
{
  "node": "honeydrunk-files",
  "node_name": "HoneyDrunk.Files",
  "package": "HoneyDrunk.Files.Abstractions",
  "status": "seed",
  "interfaces": [
    { "name": "IFileStore", "kind": "interface", "description": "Read/write/delete operations against bytes + metadata. Backing-agnostic. Issues short-lived read SAS for private assets; resolves CDN URLs for public assets." },
    { "name": "IFileUploadSession", "kind": "interface", "description": "Initiate an upload, issue a signed write-scoped SAS after IFileQuotaPolicy check, accept upload-completion signal, kick off the processing pipeline. Idempotent by client-provided idempotency key." },
    { "name": "IFileMetadata", "kind": "interface", "description": "Query metadata (purpose, size, content type, classification, upload timestamp, processing status, tenant id, soft-delete state) without reading the bytes." },
    { "name": "IFileProcessor", "kind": "interface", "description": "Pluggable processing-stage interface — thumbnail generator, EXIF stripper, format converter, virus-scan adapter. Idempotent by file_id per ADR-0042." },
    { "name": "IFileQuotaPolicy", "kind": "interface", "description": "Per-tenant byte total, file count, and single-file-size limits; behavior at the limit (UploadDenied with reason). Tier-driven defaults sourced from Billing when stood up." },
    { "name": "FileDescriptor", "kind": "type", "description": "Record. Canonical file metadata envelope — file_id, tenant_id, purpose, content_type, size, classification, upload timestamp, processing status, derivative paths. Value type, no I prefix." },
    { "name": "UploadRequest", "kind": "type", "description": "Record. Consumer-supplied upload intent — tenant_id (from IGridContext), purpose, content_type, declared_size, declared_classification, optional idempotency_key." },
    { "name": "UploadSession", "kind": "type", "description": "Record. Result of IFileUploadSession.Initiate — file_id, signed_upload_url, expires_at, completion_callback_url." },
    { "name": "SignedDownloadUrl", "kind": "type", "description": "Record. Result of IFileStore.GetDownloadUrl — url (either CDN-fronted public or short-lived read SAS), expires_at (null for public CDN URLs), is_public flag." },
    { "name": "QuotaSnapshot", "kind": "type", "description": "Record. Per-tenant current usage — bytes_used, file_count, last_refreshed; sourced from tier defaults via Billing when stood up." },
    { "name": "RetentionPolicy", "kind": "type", "description": "Record. Soft-delete window (default 30 days; tenant-tier configurable; min 7, max 90) and hard-delete cascade trigger." }
  ]
}
```

### `constitution/sectors.md` — add Files row to Core-sector table

The Core-sector table (find via `rg -n '^\| \*\*Core\*\*' constitution/sectors.md` and read the surrounding table) currently ends at:

```
| **Audit** | Seed | Grid-wide durable, attributable security and action record — append-only by interface, audit-class retention, forensic read surface |
```

Append a new row after Audit:

```
| **Files** | Seed | Blob storage, media processing, signed-URL delivery, per-tenant quota, retention/soft-delete, and the deletion cascade for tenant offboarding and GDPR erasure |
```

Also locate the **Dependency Flow (Real Nodes)** code block (find via `rg -n 'Dependency Flow' constitution/sectors.md`). The block ends at `└── Observe → Kernel, Vault`. Since Files is not yet "Real" (the repo doesn't exist; scaffold pending), do **not** add it to the Real-Nodes flow in this packet. It joins the diagram only after packet 04 lands `v0.1.0`. Flagging this here so a future agent doesn't preemptively edit the diagram against an unbuilt Node.

### `infrastructure/reference/tech-stack.md` — add Files and Azure backing rows

Multiple table additions, all under their existing sections (do not invent new sections):

**Backend section table.** No row to add — Files uses the standard `.NET 10.0` / `C# 14` already named. No Files-specific framework dependency at standup.

**Azure SDK section table.** Find via `rg -n '^## Azure' infrastructure/reference/tech-stack.md` at edit time. The existing block currently reads:

```
| Azure.Messaging.ServiceBus | 7.20.1 | Transport.AzureServiceBus |
| Azure.Storage.Queues | 12.25.0 | Transport.StorageQueue |
| Azure.Storage.Blobs | 12.27.0 | Notify |
| Azure.Security.KeyVault.Secrets | 4.8.0 | Vault.Providers.AzureKeyVault |
| Azure.Identity | 1.17.1 | All Azure-integrated services |
| Azure.Core | 1.50.0 | Transitive |
```

**Update the `Azure.Storage.Blobs` row's "Used By" field** to add Files: change `Notify` to `Notify, Files.AzureBlob` so the existing dependency is shared-not-duplicated.

**Planned/Future > Infrastructure table.** No edit — the Files Node is being stood up, but its Azure resources (storage account, CDN, Defender for Storage, Front Door) are deferred per the "provision when needed" preference (memory `feedback_provision_when_needed`). The tech-stack file tracks dependencies/SDKs, not Azure resources — the Azure resource ledger lives in `infrastructure/walkthroughs/` and is updated when each resource is actually provisioned (with the first feature packet).

**Planned Nodes (no code yet) table.** Find via `rg -n 'Planned Nodes' infrastructure/reference/tech-stack.md`. Update the table to add Files. The existing table reads:

```
| Agent Kit | AI | Agent execution runtime, tool abstraction, memory |
| Orchestrator | Core | Workflow orchestration, multi-step pipelines |
| HoneyHub | Creator | Project orchestration, creator dashboard |
| Gateway | Core | API gateway with Grid context |
| Jobs | Ops | Background job scheduling |
| Cache | Core | Distributed caching abstraction |
```

Files is being stood up (this initiative) — but the scaffold hasn't run, so it's still "no code yet" until packet 04 closes. Add the row:

```
| Files | Core | Blob storage, media processing, signed-URL delivery, per-tenant quota, retention cascade |
```

After packet 04 lands and `v0.1.0` ships, a follow-up reconciliation moves Files out of "Planned Nodes (no code yet)" into the live tables (Backend/Azure SDK/Hosting). That reconciliation is not in this packet's scope.

### `initiatives/roadmap.md` — add Files entry under Q2 2026

Find the Q2 2026 section via `rg -n 'Q2 2026' initiatives/roadmap.md`. The section currently lists in-progress and completed work for the quarter. The named first consumer (PDR-0005 Hearth) is also a Q2 priority per the user's stated app-concepts work. Add a new bullet under Q2 2026 after the `HoneyDrunk.Memory` line (find via `rg -n 'HoneyDrunk.Memory' initiatives/roadmap.md`):

```
- [ ] **HoneyDrunk.Files Standup (ADR-0061)** — Blob storage, media processing, signed-URL delivery; Abstractions + InMemory reference adapter + empty AzureBlob placeholder
```

### `initiatives/active-initiatives.md` — new "In Progress" entry

Insert a new entry under `## In Progress`, immediately after the **ADR-0030 Grid-Wide Audit Substrate** block (find via `rg -n 'ADR-0030 Grid-Wide Audit Substrate' initiatives/active-initiatives.md` at edit time and locate the end of that block by reading forward until the next `### ` header). The new entry:

```markdown
### ADR-0061 HoneyDrunk.Files Standup
**Status:** In Progress
**Scope:** Architecture (catalog/context-folder registration + invariants) + HoneyDrunk.Files (new repo, scaffold)
**Initiative:** `adr-0061-files-standup`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Stand up `HoneyDrunk.Files` as the Core sector's single Node for bytes + bytes-metadata per ADR-0061. Owns blob storage, media processing (thumbnails, resize, format conversion, EXIF stripping), malware scanning, signed-URL issuance, public CDN-fronted delivery, per-tenant quota enforcement, soft-delete and retention, and the deletion cascade for tenant offboarding and GDPR Article 17 user erasure. Four packets: catalog/context-folder registration (Architecture), two new invariants (Files domain-meaning boundary + signed-URL/CDN-only download path), human-only GitHub repo creation, scaffold (four packages: Abstractions, runtime, InMemory reference adapter, empty AzureBlob placeholder). No Azure provisioning at standup — Storage Account / Defender for Storage / CDN / Front Door are deferred to the first feature packet activated by a real consumer (likely PDR-0005 Hearth). Unblocks Hearth (the named first consumer), Lately, Currents, Curiosities, Notify Cloud tenant attachments, and Studios product surfaces needing avatars.

**Tracking:**
- [ ] Architecture#NN: Catalog registration + context folder (packet 01)
- [ ] Architecture#NN: Add two new Files invariants (packet 02)
- [ ] Architecture#NN: Create HoneyDrunk.Files GitHub repo (human-only — packet 03)
- [ ] Files#NN: Scaffold HoneyDrunk.Files — solution, four packages, contracts, CI, in-memory reference adapter (packet 04)
- [ ] Architecture#NN: Post-release catalog version bumps — `modules.json` Files entries `0.0.0` → `0.1.0`, `grid-health.json` Files row `version` `0.0.0` → `0.1.0`, clear `active_blockers` (packet 05; parked behind `HoneyDrunk.Files v0.1.0` shipping to NuGet)

> **Sync (YYYY-MM-DD):** Initiative scoped today. Packets 01/02 ready to file in Wave 1; packet 03 (human-only repo creation) ready in Wave 2; packet 04 parked on packets 02 + 03 landing — packet 02 because the scaffold body cites assigned invariant numbers, packet 03 because the repo must exist before file-packets.sh can target it. Packet 05 (catalog version-bump reconciliation) files alongside the others but stays Blocked behind `v0.1.0` shipping to NuGet.
```

Replace `YYYY-MM-DD` in the sync line with the date this packet's PR is opened (or merged — the convention is whichever your hive-sync agent normalizes against).

### `repos/HoneyDrunk.Files/` — new context folder (four files)

Create `repos/HoneyDrunk.Files/` with four files, all matching the template used by `repos/HoneyDrunk.Audit/` (the closest substrate analog).

#### `repos/HoneyDrunk.Files/overview.md`

```markdown
# HoneyDrunk.Files — Overview

**Sector:** Core
**Version:** 0.0.0 (standup pending)
**Framework:** .NET 10.0
**Repo:** `HoneyDrunkStudios/HoneyDrunk.Files`
**Status:** Capability/decision accepted (ADR-0061). Stand-up scaffold pending.

## Purpose

The Grid's single Node for bytes + bytes-metadata — blob storage, media processing (thumbnails, resize, format conversion, EXIF stripping), malware scanning, signed-URL issuance, public CDN-fronted delivery, per-tenant quota enforcement, soft-delete and retention windows, and the deletion cascade that supports tenant offboarding and GDPR Article 17 user erasure.

It is a substrate Node — the analog of Data for structured persistence, Vault for secrets, Cache for distributed cache backings, and Audit for the security record substrate. It owns the bytes; the consuming Node owns the domain meaning of those bytes.

## Key Packages

| Package | Type | Description |
|---------|------|-------------|
| `HoneyDrunk.Files.Abstractions` | Abstractions | `IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`, plus supporting records (`FileDescriptor`, `UploadRequest`, `UploadSession`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy`). Near-minimal; backing-agnostic. |
| `HoneyDrunk.Files` | Runtime | Composition, lifecycle hooks, telemetry, upload-session orchestrator, processing-pipeline dispatcher. Backing adapters compose alongside. |
| `HoneyDrunk.Files.InMemory` | Reference adapter | In-process `IFileStore` reference adapter for unit tests and the first integration scenarios. Deterministic SAS-token analog; pass-through fake virus scan. |
| `HoneyDrunk.Files.AzureBlob` | Provider | Placeholder project at standup carrying the .NET version, analyzers, and CI wiring; no implementation on day one. Azure adapter lands with the first feature packet. |

## Key Contracts

- `IFileStore` — read/write/delete operations against bytes + metadata. Backing-agnostic.
- `IFileUploadSession` — initiate an upload (quota-checked), issue a signed write-scoped SAS, accept completion, kick off processing.
- `IFileMetadata` — query metadata without reading bytes (purpose, size, content type, classification, upload timestamp, processing status, tenant id, soft-delete state).
- `IFileProcessor` — pluggable processing-stage interface (thumbnail generator, EXIF stripper, format converter, virus-scan adapter). Idempotent by `file_id`.
- `IFileQuotaPolicy` — per-tenant byte total, file count, single-file size cap; behavior at the limit.
- `FileDescriptor`, `UploadRequest`, `UploadSession`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy` — supporting records. Drop the `I` prefix per the Grid-wide naming rule.

## Design Notes

**Upload pattern is signed-URL direct-to-blob.** The API never proxies bytes. The consumer calls `IFileUploadSession.Initiate`, Files checks `IFileQuotaPolicy`, allocates a `file_id` (26-char ULID), generates a SAS scoped to the specific blob path with write-only permission, a content-type pin, and a maximum content length matching declared size + 5% slack, and returns the signed URL to the consumer. The client uploads bytes directly to the storage backing; Files responds to the upload-completion event and runs the processing pipeline asynchronously.

**Tenant isolation is path-prefixed within a single container per environment.** Path shape: `{tenant_id}/{purpose}/{file_id}{?/derivative}`. SAS issuance enforces the prefix-constraint at the storage layer; metadata reads enforce a `TenantId` match against `IGridContext.TenantId`. Cross-tenant access is a `tnt_internal`-only privileged operation, gated by Auth policy and audited.

**Public vs. private is metadata-driven, not path-driven.** Public assets are served via Azure Front Door / CDN at unauthenticated URLs with permissive cache headers versioned by `file_id`. Private assets are served via short-lived read-scoped SAS (default 15-minute TTL; max 4-hour TTL; never CDN-cached). Long-lived storage-account-shared-key URLs are forbidden anywhere in the Grid.

**Processing pipeline is async, idempotent, and scan-before-available.** Files are not consumer-visible until malware scan, format validation, and (for image uploads) EXIF strip have all passed. Each stage is keyed by `file_id` and is safely re-runnable per the idempotency contract.

**Phase-1 honest limitation:** the default backing at v1 is Azure Blob Storage. Cloudflare R2 stays in the consideration set as a future per-workload override for read-heavy public assets; the contract is backing-agnostic by design, so a future R2 adapter is a clean migration path. The Azure adapter implementation lands with the first feature packet activated by a real consumer (likely PDR-0005 Hearth).
```

#### `repos/HoneyDrunk.Files/boundaries.md`

```markdown
# HoneyDrunk.Files — Boundaries

## What Files Owns

- **Bytes + bytes-metadata.** The durable storage of arbitrary blob payloads (`IFileStore`), their accompanying metadata (`IFileMetadata`), and the metadata that travels with every operation (purpose, size, content type, classification, upload timestamp, processing status, tenant id, soft-delete state).
- **Signed-URL issuance.** Every download URL is either CDN-fronted-public or a short-lived SAS issued after policy check. No long-lived storage-account-shared-key URLs are issued anywhere.
- **Upload flow orchestration.** `IFileUploadSession.Initiate` performs the quota check, allocates the file_id, mints the write-scoped SAS, persists the pending UploadSession record, and emits the upload-pending event. The API never proxies the bytes themselves.
- **Processing pipeline.** Thumbnail generation, image resizing, format conversion (HEIC→JPEG, WebP, AVIF), EXIF stripping (forced for any Restricted-tier image upload), audio-format normalization. Idempotent by `file_id`.
- **Malware scanning integration.** Default backing wires to Azure Defender for Storage; the scan-pending visibility rule is the Node's responsibility (a file is not consumer-visible until scan + format validation + EXIF strip have all passed).
- **Per-tenant quota enforcement.** Byte total, file count, and single-file size cap; behavior at the limit; tier-driven defaults sourced from Billing (when stood up).
- **Soft-delete window and retention policy.** Default 30-day soft-delete, tenant-tier configurable (min 7 days, max 90 days); hard-delete cascade for tenant offboarding (driven by ADR-0050 `TenantOffboarding`/`TenantClosed` events) and GDPR Article 17 user erasure (driven by `UserErasureRequest` events).
- **Operational telemetry.** Upload latency, processing latency, scan latency, byte ingress/egress, quota-utilization metrics — emitted to Pulse via Kernel's `ITelemetryActivityFactory`. One-way; no runtime dependency on Pulse.
- **Audit event emission.** Restricted-tier uploads, admin/cross-tenant downloads, public-promotion transitions, hard-deletions, quota-exceed events, and tenant/user erasure cascades all emit via `IAuditLog` (see ADR-0061 D12).

## What Files Does NOT Own

- **Domain meaning.** A journal entry in a consuming Node references a `file_id`; that consumer owns the entry text, the timestamp, the user's reflection, the journal's themes. Files knows the bytes are 1.2 MB, were uploaded at 14:23:01, have `purpose: journal-media`, and have cleared malware scan. Files does not know it is a photo of a sunset that meant something to the user. The boundary is **bytes + bytes-metadata**, not domain meaning.
- **Cache backings.** Per the caching strategy ADR, cache backings live in `HoneyDrunk.Cache`. Files may *use* a cache (for SAS-token cache or quota snapshots) but does not host one.
- **Tenant lifecycle state.** Per the tenant lifecycle ADR, tenant state transitions live in Billing (when stood up) and orchestrate through Communications. Files is a **consumer** of the offboarding cascade — it receives `TenantOffboarding` / `TenantClosed` events and executes its deletion cascade. It does not own the state machine.
- **User identity or authorization.** Authentication and authorization decisions live in `HoneyDrunk.Auth`. Files checks the `IGridContext.TenantId` and the authenticated principal's claims via Auth's contracts; it does not mint identities or issue policies.
- **Audit record storage.** The audit record substrate is the Audit Node. Files emits audit events via `IAuditLog`; it does not store them.
- **Notification delivery.** Outbound messaging delivery is Notify's remit. Files does not send the "your file is ready" email — Communications orchestrates that, Notify delivers it. Files may emit a Transport event that Communications subscribes to.
- **Provider attachment payloads sent through Notify.** Notify's provider-direct attachment path stays (for purely transient attachments). Files is the *option*, not the only path; consumers choose.
- **Search, indexing, OCR, perceptual-hash dedup, ML feature extraction.** Files is a *bytes + bytes-metadata* substrate. A future OCR or dedup consumer is a separate Node or a Capabilities tool, not a Files extension.

## Boundary Decision Tests

- Is this **storing or retrieving the bytes**? → Files.
- Is this **deciding what the bytes mean for the user-facing domain**? → consuming Node.
- Is this **deciding allow/deny on the signed-URL issuance**? → Files calls Auth policy.
- Is this **recording that a Restricted-tier upload happened, durably and attributably**? → Files emits, Audit stores.
- Is this **orchestrating a notification that the file is ready**? → Communications + Notify.
- Is this **classifying what's in the bytes** (OCR, dedup, ML extraction)? → forbidden as a Files extension; a separate Node or Capabilities tool.
- Is this **a long-lived shared-key blob URL**? → forbidden — every download is either CDN-fronted public or a short-lived SAS.
```

#### `repos/HoneyDrunk.Files/invariants.md`

```markdown
# HoneyDrunk.Files — Invariants

Files-specific invariants (supplements `constitution/invariants.md`).

1. **Files.Abstractions stays near-minimal.**
   Only the ADR-permitted `HoneyDrunk.Kernel.Abstractions` dependency (for `TenantId` and ambient context types). No `Data*` / `Vault*` / `Pulse*` references in Abstractions; those live in the runtime composition or in backing-adapter packages.

2. **The Files Node persists bytes and bytes-metadata, never domain meaning.**
   The classification of *what a file means* lives in the consuming Node. Files knows the bytes, the size, the content type, the purpose-tag, the tenant, the classification, the upload timestamp, and the processing status — nothing more. Prevents Files from drifting into a half-baked content-management system.

3. **Every download path through Files is either CDN-fronted public or a short-lived SAS issued after policy check.**
   No long-lived storage-account-shared-key URLs anywhere in the Grid. The shape of every Files download is auditable from this rule alone. The two paths (public CDN; private short-lived SAS) are metadata-driven, not path-driven.

4. **Tenant isolation is enforced at SAS prefix-constraint and metadata-read level, not by container-per-tenant.**
   Path shape `{tenant_id}/{purpose}/{file_id}{?/derivative}` within a single container per environment. SAS issuance scopes every URL to the tenant's prefix at the storage layer; metadata reads enforce `TenantId` match against `IGridContext.TenantId`. Cross-tenant access is a `tnt_internal`-only privileged operation, gated by Auth policy and audited.

5. **The API never proxies bytes.**
   Upload is signed-URL direct-to-blob; download is either CDN-fronted public or a short-lived read SAS. The Files Container App / Function does not handle multi-GB request bodies, streaming, chunked uploads, or retry-on-partial-failure — the storage layer handles all of that natively.

6. **Files are not consumer-visible until scan + format validation + (for images) EXIF strip have all passed.**
   The processing pipeline runs asynchronously between upload completion and consumer visibility. Scan-async-quarantine is rejected as the default posture per ADR-0061 D9.

7. **Quotas are enforced at SAS issuance, not just at storage.**
   `IFileUploadSession.Initiate` returns `UploadDenied(reason)` if the declared size would exceed any quota dimension — no SAS is issued. The SAS itself enforces the declared size + 5% slack at the storage-account level as defense-in-depth.

8. **Soft-delete is the default; hard-delete only via the offboarding / erasure cascade or retention-elapsed sweep.**
   Consumer-initiated `IFileStore.Delete(file_id)` produces a soft-delete with the configured retention window. Hard-deletes happen on three paths: tenant `TenantClosed` cascade, GDPR `UserErasureRequest` cascade, and Lifecycle-Management retention-elapsed sweep. Each emits an audit event.

9. **Audit emission is scoped to Restricted-tier and privileged operations, not every consumer download.**
   Auditing every download would explode the audit substrate's volume and dilute the security signal. Consumer downloads are *expected*; admin / cross-tenant / ops downloads are *exceptional* and warrant the record.

_Constitutional invariants {N-domain-meaning} (Files persists bytes only, not domain meaning) and {N-download-shape} (every Files download is CDN-fronted public or short-lived SAS) in `constitution/invariants.md` are the Grid-level rules this Node exists to enforce. Both are landed by ADR-0061's stand-up initiative (packet 02). The numeric assignments are made at packet 02's edit time via the collision-check protocol._

## Status

Capability/decision accepted (ADR-0061 Proposed → Accepted flips after this initiative's PRs merge). Standup scaffold (repo, packages, contracts, CI) governed by ADR-0061 itself — a distinct initiative tracked at `generated/issue-packets/active/adr-0061-files-standup/`.
```

#### `repos/HoneyDrunk.Files/integration-points.md`

```markdown
# HoneyDrunk.Files — Integration Points

## Upstream Dependencies

| Node | Contract | Usage |
|------|----------|-------|
| **HoneyDrunk.Kernel** | `IGridContext`, `IOperationContext`, lifecycle hooks, health/readiness, `ITelemetryActivityFactory` (`HoneyDrunk.Kernel.Abstractions`) | Every upload, processing, and download operation runs inside a Grid context. `TenantId` is the strong type from `IGridContext.TenantId` per ADR-0026. Files emits its own operational telemetry via Kernel's telemetry factory. |
| **HoneyDrunk.Vault** | `ISecretStore`, `IConfigProvider` (`HoneyDrunk.Vault`) | Storage account credentials, SAS user-delegation keys, and Defender for Storage subscription identifiers live in Files' own Key Vault (`kv-hd-files-{env}`). App Configuration values (quota tier defaults, soft-delete window, scan integration toggles) flow via `IConfigProvider`. |
| **HoneyDrunk.Data** | `IRepository`, `IUnitOfWork` (`HoneyDrunk.Data.Abstractions`) | Bytes-metadata table — `FileDescriptor` records, `UploadSession` state, `QuotaSnapshot` cache, soft-delete state. The bytes themselves do NOT live in Data (Data is a relational store; `varbinary(max)` blobs are an anti-pattern for that store). |
| **HoneyDrunk.Transport** | `ITransportPublisher`, `ITransportConsumer` (`HoneyDrunk.Transport`) | `BlobCreated` Event Grid trigger → processing pipeline messages. `FileAvailable` event emitted on consumer-visibility transition. `TenantOffboarding` / `TenantClosed` / `UserErasureRequest` events consumed for the deletion cascade. |
| **HoneyDrunk.Auth** | `IAuthorizationPolicy` (`HoneyDrunk.Auth.Abstractions`) | Authorization policy check on signed-URL issuance. The authenticated principal's claims gate which `purpose`/`tenant_id` combinations are allowed; `tnt_internal` cross-tenant operations are policy-gated. |
| **HoneyDrunk.Audit** | `IAuditLog`, `AuditEntry` (`HoneyDrunk.Audit.Abstractions`) | Restricted-tier upload events, admin/cross-tenant downloads, public-promotion transitions, hard-deletions, quota-exceed events, and tenant/user erasure cascades all emit via `IAuditLog`. |

## Telemetry (no runtime dependency)

| Node | Direction | Notes |
|------|-----------|-------|
| **HoneyDrunk.Pulse** | Files emits → Pulse observes | One-way by contract. Files emits operational telemetry (upload latency, processing latency, scan latency, byte ingress/egress, quota-utilization metrics). Files has **no runtime dependency on Pulse**. |

## Downstream Consumers (Planned)

| Node | Contract Used | Status |
|------|---------------|--------|
| **HoneyDrunk.Notify** | `IFileStore.GetDownloadUrl` (`HoneyDrunk.Files.Abstractions`) | Notify's `Attachment` record gains an optional `file_id` field. Notify retrieves the bytes via `IFileStore` at delivery time with a short-lived read SAS and passes them to the provider. Notify's provider-direct attachment path stays for purely transient attachments (Files is the option, not the only path). |
| **HoneyDrunk.Communications** | `IFileStore`, `IFileMetadata` (`HoneyDrunk.Files.Abstractions`) | Communications may reference a `file_id` in a weekly digest send (e.g., embed a `journal-media` thumbnail in a Hearth digest email). |
| **PDR-driven app Nodes** (Hearth, Lately, Currents, Curiosities) | `IFileUploadSession`, `IFileStore`, `IFileMetadata` | First media-bearing packets in each app reference `IFileUploadSession.Initiate` to mint a signed-upload URL, then `IFileStore.GetDownloadUrl` for read paths. Each PDR-driven app's standup ADR will commit its specific edges. |
| **Studios product surfaces** | `IFileStore.GetDownloadUrl` (public) | Avatar serving via the public CDN-fronted path. |

## Boundary Notes

- Downstream Nodes consume `HoneyDrunk.Files.Abstractions` only — never the runtime, never the backing adapter directly. Composition (backing choice, processing toolchain, malware-scan integration) is a host-time concern.
- Files runs under its **own dedicated managed identity** (Phase-2 when the first Azure backing lands). At standup the Node is library-only — both `Abstractions` and `InMemory` are libraries, not deployables. Managed identity provisioning belongs with the first packet that deploys a Files-composing host.
- Key Vault and App Configuration access is scoped to Files' own identity (`kv-hd-files-{env}`). Storage account keys and SAS user-delegation keys never appear in environment variables or code; the Files Container App authenticates to Storage via Managed Identity where the operation supports it.
- The Notify dual-path (file_id-resolved attachment vs. provider-direct opaque payload) is **not redundant** — the two paths serve different lifecycles (transient vs. persistent). The dual path is documented at the Notify integration row above; Files is the recommended path for any byte that needs to outlive the delivery moment.

## Canary Coverage Required

Before any Files code is considered production-ready:

- `Files.Canary` → Kernel: verifies `IGridContext` flows through every operation; `TenantId` is propagated to upload-session creation, SAS issuance, metadata reads, and processing pipeline messages.
- `Files.Canary` → Data: verifies `FileDescriptor` round-trip through `IRepository<FileDescriptor>` + `IUnitOfWork.SaveChangesAsync`; verifies soft-delete state transitions persist atomically.
- `Files.Canary` → Auth: verifies signed-URL issuance is gated by Auth policy; verifies cross-tenant access is rejected for non-`tnt_internal` principals.
- `Files.Canary` → contract-shape: contract-shape canary in CI fails the build if any member of the Abstractions public surface (`IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`, or any of the supporting records) changes shape without a version bump.

## Dependency Order for Bring-Up

Files cannot be scaffolded until these Nodes have published their Abstractions packages:

1. Kernel (already Live — `HoneyDrunk.Kernel.Abstractions` 0.4.0+ stable)
2. Vault (already Live — `HoneyDrunk.Vault` 0.2.0+ stable)
3. Data (already Live — `HoneyDrunk.Data.Abstractions` 0.3.0+ stable)
4. Transport (already Live — `HoneyDrunk.Transport` 0.4.0+ stable)
5. Auth (already Live — `HoneyDrunk.Auth.Abstractions` 0.2.0+ stable)
6. Audit (already Live — `HoneyDrunk.Audit.Abstractions` 0.1.0+ stable per ADR-0031 standup completion)

Files is itself a hard prerequisite for:

1. Every PDR-driven app Node that includes user-uploaded media (Hearth, Lately, Currents, Curiosities)
2. Notify's optional `file_id` attachment path (D13)
3. Studios product surfaces requiring avatar serving
4. Any future Node that needs durable byte storage with signed-URL delivery
```

### `CHANGELOG.md` (Architecture repo)

Append to the current in-progress version section (per memory `feedback_no_unreleased_commits` — no entries under `## Unreleased`; use the existing dated SemVer-bumped section or create a new one if this commit bumps the version):

`Architecture: Register ADR-0061 standup decisions in catalogs. New honeydrunk-files Node entry in nodes.json (Core sector, Seed, 11 contracts/records, 4 packages); new relationships.json block with consumes Kernel/Vault/Data/Transport/Auth/Audit; consumed_by_planned [Notify, Communications] (PDR-driven Hearth/Lately/Currents/Curiosities ids added by their own future standup ADRs); 6 upstream consumed_by_planned amendments; new grid-health.json Seed row reflecting standup-pending state; 4 new modules.json entries at v0.0.0 (Abstractions, runtime, InMemory, AzureBlob); new contracts.json block with the 5 D6 interfaces + 6 supporting records (records drop the I prefix per the Grid-wide naming rule); Core-sector Files row added to sectors.md; Files row added to tech-stack.md Planned Nodes table (Notify shares Azure.Storage.Blobs with Files.AzureBlob — that row's Used By updated); Q2 2026 roadmap bullet added; in-progress entry in active-initiatives.md; new repos/HoneyDrunk.Files/ context folder with overview.md, boundaries.md, invariants.md, integration-points.md matching the Audit template. ADR-0061 stays Proposed in this packet — the Status flip is a separate post-merge housekeeping step.`

## Affected Files
- `catalogs/nodes.json`
- `catalogs/relationships.json` (new files block; 6 upstream entries' `consumed_by_planned` arrays amended)
- `catalogs/grid-health.json` (new row + summary counters bumped)
- `catalogs/modules.json` (4 new entries)
- `catalogs/contracts.json` (new files block)
- `constitution/sectors.md` (Core table — Files row added)
- `infrastructure/reference/tech-stack.md` (Planned Nodes table — Files row added; Azure SDK table — Azure.Storage.Blobs Used By updated)
- `initiatives/roadmap.md` (Q2 2026 — Files Standup bullet added)
- `initiatives/active-initiatives.md` (new In Progress entry)
- `repos/HoneyDrunk.Files/overview.md` (new file)
- `repos/HoneyDrunk.Files/boundaries.md` (new file)
- `repos/HoneyDrunk.Files/invariants.md` (new file)
- `repos/HoneyDrunk.Files/integration-points.md` (new file)
- `CHANGELOG.md`

`adrs/ADR-0061-stand-up-honeydrunk-files-node.md` is **not** edited by this packet. Its Status header stays `Proposed` — the flip is a separate post-merge housekeeping step.

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No code changes anywhere; metadata + docs only.
- [x] No contract bodies invented in this packet — only catalog registration of ADR-0061's already-decided D6 surface.
- [x] No new design decisions — ADR-0061 is authoritative for sector classification, package set, contract list, dependency edges, and standup boundary.
- [x] No edits to `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` in this packet. The Status flip is a separate post-merge housekeeping step per the user's standing ADR acceptance workflow.
- [x] The `consumed_by_planned` array on the new Files block lists only currently-cataloged Node ids (`honeydrunk-notify`, `honeydrunk-communications`). Speculative PDR-driven app Node ids (Hearth, Lately, Currents, Curiosities) are deliberately omitted — they get added when each PDR's own standup ADR commits the Node id.

## Acceptance Criteria

- [ ] `catalogs/nodes.json` carries a new `honeydrunk-files` entry with `sector: "Core"`, `signal: "Seed"`, `tags: ["files", "blob-storage", "media-processing", "signed-url", "cdn", "quota", "retention", "substrate"]`, and the full `long_description` block matching the structure of `honeydrunk-audit`'s entry.
- [ ] `catalogs/relationships.json` carries a new `honeydrunk-files` block with `consumes: ["honeydrunk-kernel", "honeydrunk-vault", "honeydrunk-data", "honeydrunk-transport", "honeydrunk-auth", "honeydrunk-audit"]`, `consumed_by: []`, `consumed_by_planned: ["honeydrunk-notify", "honeydrunk-communications"]` (only cataloged Node ids — no speculative PDR-app ids), `exposes.contracts` listing all 11 D6 interfaces/records, `exposes.packages` listing all 4 D3 packages, and `consumes_detail` for every upstream edge naming the specific contracts plus the package name.
- [ ] **Six upstream entries' `consumed_by_planned` arrays are amended** to include `"honeydrunk-files"`: `honeydrunk-kernel`, `honeydrunk-vault`, `honeydrunk-data`, `honeydrunk-transport`, `honeydrunk-auth`, `honeydrunk-audit`. Verify each via grep after the edit.
- [ ] `catalogs/grid-health.json` carries a new `honeydrunk-files` row with `signal: "Seed"`, `version: "0.0.0"`, `canary_status: "none"`, `last_release: null`, and `active_blockers` listing the GitHub repo + scaffold packet pending. The `summary.blocked_nodes` array includes `"honeydrunk-files"`. The `summary.total_nodes`, `summary.seed`, and `summary.canary_none` counters are bumped by 1 each (verify against the current high-water mark at edit time).
- [ ] `catalogs/modules.json` carries 4 new entries: `files-abstractions`, `files-runtime`, `files-inmemory`, `files-azureblob` — all `nodeId: "honeydrunk-files"`, all `version: "0.0.0"`, with the correct `type` values (`abstractions`, `runtime`, `testing`, `provider` respectively).
- [ ] `catalogs/contracts.json` carries a new `honeydrunk-files` block with `package: "HoneyDrunk.Files.Abstractions"`, `status: "seed"`, and the 11 interface/type entries (5 interfaces with `kind: "interface"`; 6 records with `kind: "type"`). Records have no `I` prefix in their names per the Grid-wide naming rule (`FileDescriptor`, `UploadRequest`, `UploadSession`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy`).
- [ ] `constitution/sectors.md` Core-sector table includes a `**Files** | Seed | …` row immediately after the Audit row. The Dependency Flow code block at the bottom of sectors.md is **not** edited (Files is not yet a Real Node until packet 04 lands).
- [ ] `infrastructure/reference/tech-stack.md` "Planned Nodes (no code yet)" table includes a `| Files | Core | Blob storage… | …` row. The Azure SDK table's `Azure.Storage.Blobs` row's Used By field is updated from `Notify` to `Notify, Files.AzureBlob` (or equivalent canonical naming — confirm against the actual current row text at edit time).
- [ ] `initiatives/roadmap.md` Q2 2026 section includes a `[ ] HoneyDrunk.Files Standup (ADR-0061)` bullet under the Q2 2026 list, positioned naturally (after the Memory bullet at line 37).
- [ ] `initiatives/active-initiatives.md` includes a new `### ADR-0061 HoneyDrunk.Files Standup` block under `## In Progress` with the Status / Scope / Initiative / Board / Description / Tracking fields populated. The `YYYY-MM-DD` placeholder in the Sync line is replaced with the actual date.
- [ ] `repos/HoneyDrunk.Files/` folder exists with exactly four files: `overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`. Each file's structure matches the Audit / Communications template (heading levels, section names, tables).
- [ ] `repos/HoneyDrunk.Files/overview.md` opens with the standard `Sector`/`Version`/`Framework`/`Repo`/`Status` block; lists the four packages in the Key Packages table; lists the five contracts + six supporting records (records drop the `I` prefix) in the Key Contracts section; carries Design Notes covering upload pattern (signed-URL direct-to-blob), tenant isolation (path-prefixed), public-vs-private distinction (metadata-driven), processing pipeline (async, idempotent, scan-before-available), and the Phase-1 honest limitation on backing choice.
- [ ] `repos/HoneyDrunk.Files/boundaries.md` lists "What Files Owns" / "What Files Does NOT Own" / "Boundary Decision Tests" sections matching the Audit template. Domain meaning is explicitly named as out-of-scope; long-lived shared-key URLs are explicitly named as forbidden.
- [ ] `repos/HoneyDrunk.Files/invariants.md` carries 9 repo-local invariants with the same numbered shape as `repos/HoneyDrunk.Audit/invariants.md`, plus a trailing cross-reference paragraph naming the two constitutional invariants by placeholder (`{N-domain-meaning}` and `{N-download-shape}` — packet 02 of this initiative substitutes the real numbers in place pre-push).
- [ ] `repos/HoneyDrunk.Files/integration-points.md` carries Upstream Dependencies / Telemetry / Downstream Consumers (Planned) / Boundary Notes / Canary Coverage Required / Dependency Order for Bring-Up sections matching the Audit template. Each upstream row names the specific contracts consumed and the package the contracts ship in. Pulse is in the Telemetry section, not Upstream Dependencies.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer-bumped section describing the catalog registration. The entry does NOT claim a Status flip — ADR-0061 stays Proposed in this packet's diff.
- [ ] `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` is **not** modified by this packet. (Verify the file is unchanged in the diff. The Status flip is deferred to post-merge housekeeping.)
- [ ] PR body explicitly notes: (1) catalogs reconciled across all five files (nodes/relationships/grid-health/modules/contracts); (2) Core-sector row added; (3) Planned-Nodes tech-stack row added; (4) roadmap + active-initiatives entries added; (5) `repos/HoneyDrunk.Files/` context folder created with four template-matching files; (6) ADR-0061 stays at `Status: Proposed` (separate post-merge housekeeping step).
- [ ] Grep audit after the edits: `rg -nr 'honeydrunk-files' catalogs/ repos/ constitution/ infrastructure/ initiatives/` returns matches in every catalog file, the sectors doc, the tech-stack doc, the roadmap, the active-initiatives doc, and the new repos/HoneyDrunk.Files/* files. `rg -nr 'HoneyDrunk.Files\b' repos/HoneyDrunk.Files/` returns the overview/boundaries/invariants/integration-points files.

## Human Prerequisites
None. ADR-0061 is fresh as of 2026-05-23 and carries all the design decisions this packet reflects; the Status flip is deferred to post-merge housekeeping.

## Referenced Invariants

> **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Files consumes Kernel, Vault, Data, Transport, Auth, and Audit. None of those Nodes reference Files. The new edges are DAG-consistent.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Files is its own Node, hence its own repo (created by packet 03 of this initiative).

> **Invariant 12:** Semantic versioning with CHANGELOG and README. — This packet updates the Architecture repo's CHANGELOG (which tracks Architecture changes, not Files version bumps).

## Referenced ADR Decisions

**ADR-0061 D1 (Files Node ownership):** `HoneyDrunk.Files` is the Core sector's single Node owning bytes + bytes-metadata for every Grid consumer. Substrate Node — the analog of Data for structured persistence, Vault for secrets, Cache for distributed cache backings, Audit for the security record substrate.

**ADR-0061 D3 (Initial scaffolding boundary):** Four packages — `HoneyDrunk.Files.Abstractions`, `HoneyDrunk.Files`, `HoneyDrunk.Files.InMemory`, `HoneyDrunk.Files.AzureBlob`. The AzureBlob package is a placeholder at standup; the real implementation lands with the first feature packet. The catalog entries in this packet reflect that empty-pre-scaffold state (all four at v0.0.0).

**ADR-0061 D6 (Boundaries — what Files owns / does NOT own):** Owns bytes + bytes-metadata, signed-URL issuance, processing pipeline, malware scan integration, per-tenant quota, soft-delete + retention, audit emission. Does NOT own domain meaning, cache backings, tenant lifecycle state, identity/authorization, audit storage, notification delivery, search/OCR/dedup/ML. The catalog `consumes` array reflects the dependency edges in D6; the boundaries doc reflects the same boundary text.

**ADR-0061 D6 (Five exposed contracts + six supporting records):** `IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy` (interfaces); `FileDescriptor`, `UploadRequest`, `UploadSession`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy` (records). Records drop the `I` prefix per the Grid-wide naming rule (memory `project_naming_rule_records`).

**ADR-0061 D5 (Tenant isolation — single container per environment, path-prefixed):** Reflected in the boundaries doc and the invariants doc — tenant isolation is policy-enforced at SAS prefix-constraint and metadata-read level, not at the Azure container surface.

**ADR-0061 D11 (Retention, soft-delete, deletion cascade):** Reflected in the boundaries doc's "What Files Owns" section and the invariants doc's invariant 8.

**ADR-0061 D13 (Notify-attachment compatibility):** Reflected in the integration-points doc's Downstream Consumers row for Notify — both paths supported, Files is the recommended path for any byte that needs to outlive the delivery moment.

## Dependencies
None. This packet is the foundation of the initiative — it can land first because every catalog field it edits is design-decided in ADR-0061. Packets 02, 03, and 04 reference this one via `packet:01`.

## Labels
`chore`, `tier-2`, `architecture`, `files`, `adr-0061`

## Agent Handoff

**Objective:** Bring the `HoneyDrunk.Architecture` repo's catalogs, sectors doc, tech-stack doc, roadmap, active-initiatives tracker, and `repos/HoneyDrunk.Files/` context folder into alignment with ADR-0061. Do not edit `adrs/ADR-0061-stand-up-honeydrunk-files-node.md`; do not invent any new design choices.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Catalog drift is the bottleneck that blocks the scaffold packet (packet 04) from naming a registered Node, and blocks every future downstream consumer (Notify's optional file_id path, Communications digests embedding `file_id`s, every PDR-driven app's media uploads) from referencing a coherent contract surface. This packet removes the drift introduced by ADR-0061's Proposed acceptance.
- Feature: ADR-0061 standup initiative, Wave 1, Packet 01.
- ADRs: ADR-0061 (this packet implements the catalog half of "If Accepted").

**Acceptance Criteria:** As listed above.

**Dependencies:** None — this packet runs first.

**Constraints:**

- **Invariant 4:** No circular dependencies. The dependency graph is a DAG. Kernel is always at the root. — Files consumes Kernel/Vault/Data/Transport/Auth/Audit; none of those Nodes reference Files in `consumes`. The new edges are DAG-consistent.
- **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Files is a separate Node and gets its own repo (created by packet 03).
- **D6 contract list is canonical.** 5 interfaces + 6 records. Records drop the `I` prefix per the Grid-wide naming rule (memory `project_naming_rule_records`). Apply this convention everywhere — `contracts.json` `kind: "type"` for records vs `kind: "interface"` for interfaces; the `Key Contracts` section in `overview.md` lists records without `I`.
- **`consumed_by_planned` only references existing Node ids.** PDR-driven app Nodes (Hearth, Lately, Currents, Curiosities) do not have committed Node ids in `nodes.json` as of 2026-05-24. Listing them speculatively would invent uncataloged ids and create downstream churn when each PDR's standup ADR lands. Use only `honeydrunk-notify` and `honeydrunk-communications` (the existing Nodes named in D13). When PDR-driven app standup ADRs land later, each adds its own edge.
- **No ADR Status flip in this packet.** ADR-0061 stays at `Status: Proposed`. The flip is a separate post-merge housekeeping step the scope agent runs after the entire initiative completes, per the user's standing ADR acceptance workflow. Do not edit the ADR header in this PR.
- **No `## Unreleased` section in CHANGELOG.** Per memory `feedback_no_unreleased_commits`, the commit lands under the current dated SemVer-bumped section. If no dated section exists for an in-progress version, create one with the appropriate SemVer bump and today's date.
- **No new Real-Nodes dependency-flow diagram edits.** Files is not yet Real until packet 04 lands `v0.1.0`. Updating `sectors.md`'s diagram preemptively would lie about the Grid's current shape.
- **Tech-stack Azure resource ledger is NOT in this file.** Per memory `feedback_provision_when_needed`, Azure resources are provisioned when first needed, not at standup. The Files row in `tech-stack.md` belongs in the "Planned Nodes (no code yet)" table at standup time. After packet 04 lands and `v0.1.0` ships, a follow-up reconciliation moves Files into the live tables — that reconciliation is not in this packet.
- **Repo context folder template is `repos/HoneyDrunk.Audit/` (the closest substrate analog).** Match its file set (`overview.md`, `boundaries.md`, `invariants.md`, `integration-points.md`), heading levels, table column shape, and "What X Owns / What X Does NOT Own / Boundary Decision Tests" structure.
- **Pulse is one-way.** Files emits operational telemetry via Kernel's `ITelemetryActivityFactory`; Files has no runtime dependency on Pulse. In `integration-points.md`, Pulse appears under the "Telemetry (no runtime dependency)" table, NOT under "Upstream Dependencies". The `relationships.json` `consumes` array does NOT include `honeydrunk-pulse`.

**Key Files:**
- `catalogs/nodes.json` — insert new `honeydrunk-files` entry after `honeydrunk-audit`
- `catalogs/relationships.json` — insert new `honeydrunk-files` block; amend 6 upstream entries' `consumed_by_planned` arrays
- `catalogs/grid-health.json` — insert new row; bump summary counters; add to `blocked_nodes`
- `catalogs/modules.json` — append 4 new module entries (Abstractions, runtime, InMemory, AzureBlob — all v0.0.0)
- `catalogs/contracts.json` — append new `honeydrunk-files` block with 5 interfaces + 6 records
- `constitution/sectors.md` — append Files row to Core-sector table (do not edit the Dependency Flow diagram)
- `infrastructure/reference/tech-stack.md` — Planned Nodes table (add Files row); Azure SDK table (update `Azure.Storage.Blobs` Used By)
- `initiatives/roadmap.md` — Q2 2026 list (add Files Standup bullet)
- `initiatives/active-initiatives.md` — `## In Progress` (insert new entry after the ADR-0030 block)
- `repos/HoneyDrunk.Files/overview.md` — new file
- `repos/HoneyDrunk.Files/boundaries.md` — new file
- `repos/HoneyDrunk.Files/invariants.md` — new file
- `repos/HoneyDrunk.Files/integration-points.md` — new file
- `CHANGELOG.md` — entry under the current dated SemVer-bumped section

`adrs/ADR-0061-stand-up-honeydrunk-files-node.md` and `adrs/README.md` are explicitly **not** edited in this packet.

**Contracts:**
- This packet does not author any new contracts. It records the five D6 interfaces + six supporting records in the catalog and in `repos/HoneyDrunk.Files/overview.md`. Authoring of the actual `.cs` files happens in packet 04 (the scaffold).
