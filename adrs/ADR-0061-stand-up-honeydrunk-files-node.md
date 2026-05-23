# ADR-0061: Stand Up the HoneyDrunk.Files Node — Blob Storage, Media Processing, and Signed-URL Delivery

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates catalog and cross-repo obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Create `HoneyDrunk.Files` GitHub repo as **public** (per the build-in-public default for non-revenue Nodes; the bytes and metadata stored are the consuming Node's data, not Files' data — see D5)
- [ ] Add `honeydrunk-files` entry to `catalogs/nodes.json` with Core sector and the contract list from D6 (`IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`)
- [ ] Add `honeydrunk-files` entries to `catalogs/relationships.json` (consumes `honeydrunk-kernel`, `honeydrunk-vault`, `honeydrunk-data`, `honeydrunk-transport`, `honeydrunk-auth`; `consumed_by_planned` covers the first PDR consumers — Hearth, Lately, and any Studios-product surface that needs avatars)
- [ ] Add `honeydrunk-files` to `catalogs/grid-health.json` and `catalogs/modules.json`
- [ ] Update `constitution/sectors.md` Core-sector entry to include Files as the home for blob storage, media processing, signed-URL delivery, and tenant-quota policy
- [ ] Update `infrastructure/reference/tech-stack.md` — add `Files | Core | Blob storage and media processing` to the Nodes table; add `Azure Blob Storage | Required | HoneyDrunk.Files default backing` and `Azure Defender for Storage | Required | Malware scan on upload` rows under storage/security sections
- [ ] Update `initiatives/roadmap.md` — add `HoneyDrunk.Files — Blob storage, media processing, signed-URL delivery` under the Core substrate section (or "Stood up, not yet implemented" subsection if such exists)
- [ ] Create `repos/HoneyDrunk.Files/` context folder with `overview.md`, `boundaries.md`, `invariants.md` stubs (matching the template used by `repos/HoneyDrunk.Communications/` and `repos/HoneyDrunk.Audit/`)
- [ ] File the `HoneyDrunk.Files` scaffold packet (solution structure, `HoneyDrunk.Standards` wiring, CI pipeline via HoneyDrunk.Actions shared workflows, the `HoneyDrunk.Files.Abstractions` contract package, the `HoneyDrunk.Files.InMemory` reference adapter for unit tests, no Azure backing on day one)
- [ ] Scope agent assigns final invariant numbers if any new invariants are promoted from this ADR at acceptance time (candidates: "the Files Node never persists domain meaning, only bytes and bytes-metadata"; "every download path through Files is either CDN-fronted public or a short-lived SAS issued after policy check")
- [ ] Scope agent flips Status → Accepted after the scaffold packet lands

## Context

The Grid has accumulated several Nodes that move bytes around the edges of what they really do — `HoneyDrunk.Notify` accepts and dispatches attachments through its email/SMS providers; `HoneyDrunk.AI` may ship inference responses containing image content; the consumer-app PDRs (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0008 Curiosities) every one of them assumes users will upload photos, voice clips, journal media, and avatars. None of these workloads has a home for the *bytes themselves*.

Audit of what exists today:

- **[`HoneyDrunk.Notify`](../repos/HoneyDrunk.Notify/overview.md)** delivers attachments by passing them through its provider adapters (Resend for email, Twilio for SMS). Notify treats attachments as opaque payload data and does not store them — the bytes round-trip through provider APIs and are gone. There is no Grid-side persistence, no Grid-side scan, no Grid-side classification. This is the right boundary for Notify (it owns *delivery*, not storage) and the wrong outcome for the Grid (no Node owns the storage).
- **[`HoneyDrunk.Data`](../repos/HoneyDrunk.Data/overview.md)** is the persistence-store host for structured records. It is deliberately not a blob store. Mixing blob storage into Data would either bloat the relational backings (large `varbinary(max)` columns are an anti-pattern) or split Data's identity across two substantively different storage shapes.
- **[`HoneyDrunk.Vault`](../repos/HoneyDrunk.Vault/overview.md)** stores secrets, not blobs. Vault's per-secret budget (8 KB) makes it categorically unsuitable for media even if the boundary were a fit.
- **[`HoneyDrunk.Audit`](../repos/HoneyDrunk.Audit/overview.md)** owns the durable, attributable system of record for security and privileged-action events ([ADR-0030](./ADR-0030-grid-wide-audit-substrate.md), [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md)). Audit consumes records *about* file operations from the Files Node; Audit does not store the files themselves.
- **No Grid Node owns blob storage, signed-URL issuance, media processing, malware scanning, per-tenant quota, retention/soft-delete, or CDN-fronted public delivery.** Every future consumer would reinvent the same eight capabilities at the wrong layer.

The forcing functions for deciding this now:

- **PDR-0005 Hearth** is the scout's first-build pick (per `project_app_concepts_2026_05_05`). Hearth ships as a journaling-town app. The first time a user attaches a photo to a journal entry, the answer must not be "put blob upload logic inside Hearth." That answer would propagate to every subsequent PDR-driven consumer and become the permanent shape.
- **PDR-0003 Lately, PDR-0006 Currents, PDR-0008 Curiosities** every one assumes user-uploaded media — avatars, photos in suggestions, location-tagged images. The same forcing function applies to each.
- **PDR-0002 Notify Cloud** is approaching multi-tenant GA. Notify Cloud tenants will eventually ask "can my customers attach images to the emails I send through your API?" The Grid-correct answer is "Notify accepts an attachment reference resolved against Files, which is where your tenants' bytes live." Without Files, the answer is bespoke per tenant.
- **The PII / data-classification rubric from [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md)** treats journal entries, photo uploads, location traces, and voice/audio payloads as **Restricted** tier (per D1's example list). Restricted-tier data has explicit storage requirements — encryption at rest, tenant-isolated backings, access logged via `IAuditLog`. No existing Node satisfies these requirements for arbitrary byte payloads. A consumer that holds Restricted-tier blobs without a Grid-correct home cannot satisfy ADR-0049.
- **The tenant lifecycle from [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md)** commits a 30-day Offboarding grace window followed by hard-delete of tenant data. Tenant-uploaded blobs are within scope of that hard-delete. There must be a Node that owns the cascade — Files is that Node, and the cascade contract has to exist before Hearth, Lately, or any other tenant-bearing consumer puts blobs in production.
- **The GDPR Article 17 erasure pathway** (per [ADR-0050 D6](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md)) for individual users must include their uploaded media. Pseudonymization handles audit references; the underlying blobs themselves must be hard-deletable. That deletion path must exist before the first user-uploaded byte lands in production.

The constitution explicitly licenses this kind of substrate work. From [`constitution/charter.md`](../constitution/charter.md) §"What this charter licenses":

> Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work.

The same charter language has licensed every Node standup since the standup-ADR convention was set 2026-04-19. Agents, Knowledge, Memory, Evals, Flow, Sim, Operator, Audit, and Cache were all stood up before their first feature consumers materialized. Files fits that pattern — the boundary is named now so when Hearth scopes "users upload photos to their journal," the answer is mechanical work against a settled foundation rather than substrate work bundled with feature work.

This ADR commits the Node's sector and purpose, the front-loading justification, the initial scaffold boundary, the boundaries against the rest of the Grid (what Files owns and does not own), the backing choice (Azure Blob Storage as default; alternatives evaluated and rejected for v1), the tenant-isolation strategy, the upload-flow shape (signed-URL direct-to-blob), the processing pipeline shape, the virus-scan posture, the public-vs-private delivery posture, the quota and retention model, the audit-event surface, the Vault wiring, the Notify-attachment compatibility decision, and the charter sanity check.

It does **not** ship code, provision Azure resources, or commit a specific media-processing toolchain. Those are first-feature-packet decisions when the first PDR consumer activates Files.

## Decision

### D1. HoneyDrunk.Files is the Core sector's home for blob storage, media processing, and signed-URL delivery

`HoneyDrunk.Files` is the single Node in the Core sector that owns **bytes + bytes-metadata** for every Grid consumer. It is a substrate Node — the analog of `HoneyDrunk.Data` for structured persistence, `HoneyDrunk.Vault` for secrets, `HoneyDrunk.Cache` for distributed cache backings, `HoneyDrunk.Audit` for the security record substrate.

**Node name:** `HoneyDrunk.Files`
**Sector:** Core
**Purpose:** Blob storage, media processing (thumbnails, resize, format conversion, EXIF stripping), malware scanning, signed-URL issuance, public CDN-fronted delivery, per-tenant quota enforcement, soft-delete and retention windows, and the deletion cascade that supports [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) tenant offboarding and GDPR Article 17 user erasure.

**Node sector classification:** Core. Files sits at the same layer as Kernel, Vault, Transport, Data, Audit, and Cache — substrate Nodes whose role is to provide foundational primitives for the rest of the Grid. It is not Ops (no operational orchestration), not AI (no inference or agent runtime), not Meta (not about the Grid's self-development). Core is the right sector.

### D2. Front-loaded per the charter, with a concrete first consumer queued

This stand-up happens **now** even though no Grid Node has put a byte into a Files-owned blob yet. The justification, on the record:

> Time invested in ADRs, invariants, substrate hygiene, and architectural correctness is not "premature optimization" or "procrastinating on shipping." It is the work. — [`constitution/charter.md`](../constitution/charter.md)

Files differs slightly from the most front-loaded standups (Cache, Sim, Evals) because a concrete first consumer is already named: **PDR-0005 Hearth is the scout's first-build pick**, and Hearth's journaling-town concept requires media uploads from the first usable iteration. The lead time between this ADR and Hearth's first packet that touches Files is measured in weeks, not quarters. The front-loading is short.

The "provision Azure resources when first needed" preference (per `feedback_provision_when_needed`) governs **Azure resource provisioning**, not Node standup. No Azure Storage account, no CDN profile, no Front Door endpoint, no Defender for Storage subscription is provisioned by this ADR. The scaffold is repo + solution + CI + contract package + InMemory reference adapter + context folder. The first Azure backing is provisioned at the first feature packet's time, not this one's.

### D3. Initial scaffolding boundary — abstractions + InMemory reference + no Azure backing

The first PR (a separate scaffold packet, not part of this ADR's text) produces:

- **Solution layout:**
  - `HoneyDrunk.Files.Abstractions` — contract package (`IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`, plus records — see D6 for the contract list).
  - `HoneyDrunk.Files` — runtime composition package (DI registration, lifecycle hooks, telemetry, the upload-session orchestrator, the processing-pipeline dispatcher).
  - `HoneyDrunk.Files.InMemory` — reference adapter for unit tests and the first integration scenarios (in-process store, in-memory metadata, deterministic SAS-token analog, no real malware scan — a synchronous pass-through fake).
  - `HoneyDrunk.Files.AzureBlob` — **placeholder project carrying the .NET version, analyzers, and CI wiring; no implementation on day one.** The Azure adapter lands with the first feature packet that activates Files.
  - `HoneyDrunk.Files.Tests.Unit` — unit-test project; tests against `InMemory`.
  - `HoneyDrunk.Files.Tests.Canary` — canary project against `Abstractions` per Invariant 14.
- **`HoneyDrunk.Standards` wiring** on every project (analyzers, EditorConfig, `PrivateAssets: all`) per Invariant 26.
- **CI pipeline** consuming [HoneyDrunk.Actions](../../HoneyDrunk.Actions/) shared workflows — build, test, security scan, secret scan, package scan. Per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md). No deploy workflow at stand-up (Files has no Azure surface yet).
- **`README.md`** at the repo root and per package, describing purpose, installation, and public API surface (Invariant 12).
- **`CHANGELOG.md`** at solution level (Invariant 12). Starts at `0.0.1` with the standup entry.
- **`LICENSE` file** — public-default per `project_repos_public_by_default`. Files holds no revenue carve-out (it is substrate, not commercial product), no compliance carve-out (the *consumers* of Files carry classification concerns; Files itself owns no secrets and its public surface is byte-shaped abstractions, not tenant-specific behavior).
- **No Azure resource provisioning.** No storage account. No CDN. No Front Door. No Defender for Storage. Those land with the first feature packet.
- **No production processing toolchain.** ImageSharp / Magick.NET / FFmpeg adapter choice is **deferred** to the first feature packet that activates processing.

### D4. Default backing — Azure Blob Storage; alternatives evaluated and rejected for v1

The hot question in the request: which cloud holds the bytes?

| Backing | Pros | Cons | Verdict |
|---------|------|------|---------|
| **Azure Blob Storage** | Single-cloud footprint matches the rest of the Grid; Managed Identity flows already exist per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) and [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md); Defender for Storage provides on-upload malware scan with no extra deployable; Azure Front Door already on the Grid roadmap as the edge per [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md) (Cloudflare for DNS/edge; Azure resources behind it); Storage Lifecycle Management gives free retention policy primitives; Event Grid integration for upload-completion triggers is first-class. | Egress costs on read-heavy public workloads. No native zero-egress story for public delivery (unlike R2). | **Selected for v1.** |
| **Cloudflare R2** | Egress-free. Attractive for public read-heavy workloads (avatars, public photos in Lately/Curiosities). | Adds a second cloud, fragments Managed Identity story, no equivalent of Defender for Storage (would require a queued ClamAV worker as separate deployable), splits monitoring across two backends. | Rejected for v1. **Reconsider after Files has been in production for 6+ months** and the egress bill against Azure has actual data behind it. The Files contract is backing-agnostic by design (D6); a future R2 adapter is a clean migration path, not an architecture rewrite. |
| **Backblaze B2** | Cheapest cold storage. | Weak Azure integration story; no on-upload scan equivalent; smaller operational community. | Rejected. No driver among current consumers favors cold-storage cost over operational coherence. |
| **Self-hosted MinIO** | Maximum control. | Over-engineered for a solo workshop; introduces a deployable the studio would have to operate; no benefit over Azure Blob Storage at the Grid's current scale. | Rejected with one sentence per the brief: MinIO is over-engineered for a solo workshop. |
| **"No Node yet — first app rolls its own"** | Zero substrate investment now; the first consumer learns the actual shape. | The architecture-as-procrastination check goes the **other** way here. The substrate is not the procrastination — *building Hearth's bespoke blob layer* would be the procrastination, because the bespoke layer would have to be torn out the second another consumer (Lately, Notify Cloud tenant attachments) needs the same capability. The substrate cost is one ADR + a scaffold packet; the cost of not having it is N×bespoke-implementations across N consumers. | **Rejected.** The boundary is being named now precisely so the first consumer's first packet is mechanical work against a settled foundation. |

**Decision:** Azure Blob Storage is the v1 default backing. The `HoneyDrunk.Files.AzureBlob` adapter (filed empty at stand-up per D3) is the first implementation to land. Cloudflare R2 stays in the consideration set as a future per-workload override for read-heavy public assets.

### D5. Tenant isolation — single storage account, container-per-environment, tenant-prefixed path within container

Two viable tenant-isolation strategies were evaluated:

| Strategy | Pros | Cons | Verdict |
|----------|------|------|---------|
| **Container-per-tenant** | Hard isolation boundary at the Azure surface; per-tenant SAS lifetimes; per-tenant lifecycle management policies; per-tenant Defender scope. | Azure Storage caps at 500K containers per storage account before performance degrades and there are name-length / character-set constraints; tenant ULIDs (per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md), 26 chars `tnt_`-prefixed) fit but produce churn at provisioning time; tenant offboarding cascade becomes a container-delete operation (slow at scale). | Rejected for v1. |
| **Single container with tenant-prefixed path** (`{env}-files` container; blob paths shaped `{tenant_id}/{purpose}/{file_id}`) | Constant-time tenant boundary check at the path level; no container-explosion ceiling; offboarding cascade is a prefix scan + delete (well-supported by Azure Storage Lifecycle Management or a Transport-driven worker); SAS issuance scopes to a prefix via Stored Access Policies; tenant-isolation invariant lives in the issuance policy code, not in the Azure surface shape. | The isolation is enforced by the Files Node's policy code, not by an Azure boundary. A bug in SAS issuance could leak across tenants; the Azure surface alone does not prevent it. | **Selected for v1.** |

**Decision:** **Single container per environment (`{env}-files`), tenant-prefixed paths within.** Path shape:

```
{tenant_id}/{purpose}/{file_id}{?/derivative}
```

Where:
- `{tenant_id}` is the 26-char ULID per [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md); the `tnt_internal` sentinel hosts first-party Grid blobs (Studios assets, agent artifacts).
- `{purpose}` is a Files-defined enumeration (`avatar`, `journal-media`, `attachment`, `voice-clip`, `system-asset`, etc.) — adds a second-axis namespace for retention and processing-policy selection.
- `{file_id}` is a 26-char ULID generated by Files at upload-session creation.
- `{?/derivative}` optionally identifies a processed derivative (e.g., `/thumb-256`, `/web-1280`); the original always lives at the un-suffixed path.

**The failure mode of the rejected alternative (container-per-tenant):** at scale, the 500K-container ceiling forces a re-architecture mid-flight. Migrating from container-per-tenant to path-prefixed is operationally painful (every existing blob URL changes; SAS policies must be rewritten; consumer Nodes' stored references must be migrated). The path-prefixed model has no such ceiling — the 200 TB-per-account ceiling is the next constraint, and at that point the answer is "another storage account in the same Files Node," which is a one-character config change, not an architectural rewrite.

**Tenant-isolation enforcement lives in `IFileQuotaPolicy` and `IFileUploadSession`:**
- Every SAS issued by Files carries a prefix constraint matching the tenant's path. A SAS issued to tenant A cannot be used to read or write blobs under tenant B's prefix, even if a bug in consumer code passed the wrong SAS to the wrong client.
- Every metadata read from `IFileStore` enforces a `TenantId` match against the requesting `IGridContext.TenantId`.
- Cross-tenant access is a `tnt_internal`-only privileged operation, gated by `HoneyDrunk.Auth` policy and audited per D11.

This isolation pattern matches the per-Node Vault namespace shape committed by [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) — soft isolation enforced by policy code, with the path/name discipline keeping the surface small enough for the policy code to be auditable.

### D6. Boundaries — what Files owns, what Files does NOT own

**What Files owns:**
- The `HoneyDrunk.Files.Abstractions` contracts:
  - `IFileStore` — read/write/delete operations against bytes + metadata. Backing-agnostic.
  - `IFileUploadSession` — initiate an upload, issue a signed URL, accept upload completion, kick off processing pipeline.
  - `IFileMetadata` — query metadata (purpose, size, content type, classification, upload timestamp, processing status, tenant-id, soft-delete state) without reading the bytes.
  - `IFileProcessor` — pluggable processing-stage interface (thumbnail generator, EXIF stripper, format converter, virus-scan adapter).
  - `IFileQuotaPolicy` — per-tenant byte/file/single-file-size limits and the limit-exceeded behavior.
  - Records: `FileDescriptor`, `UploadRequest`, `UploadSession`, `SignedDownloadUrl`, `QuotaSnapshot`, `RetentionPolicy`.
- Backing adapter packages: `HoneyDrunk.Files.AzureBlob` (v1 default), future `HoneyDrunk.Files.R2`, `HoneyDrunk.Files.InMemory` (test reference).
- The signed-URL issuance policy: every download URL is either CDN-fronted-public (D8) or a short-lived SAS issued after policy check. **No long-lived storage-account-shared-key URLs are issued.**
- The processing pipeline: thumbnail generation, image resizing, format conversion (HEIC→JPEG, WebP, AVIF), EXIF stripping (forced for any Restricted-tier image upload), audio-format normalization. **Idempotent by `file_id` per [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md).**
- The malware-scan integration with Azure Defender for Storage (v1) — quarantine policy, scan-status metadata, the scan-pending visibility rule (D9).
- Per-tenant quota enforcement: byte total, file count, single-file size cap; behavior at the limit (D10).
- Soft-delete window and retention policy (D11).
- Operational telemetry — upload latency, processing latency, scan latency, byte ingress/egress, quota-utilization metrics — emitted to Pulse via Kernel's `ITelemetryActivityFactory`.
- The audit-event emission surface (D12) — uploads of Restricted-tier content, admin downloads, deletions, quota-exceed events.

**What Files does NOT own:**
- **Domain meaning.** A journal entry in Hearth references a `file_id`; the entry text, the timestamp, the user's reflection, the journal's themes — all of those live in Hearth's data. Files knows the blob is 1.2 MB, was uploaded at 14:23:01, has `purpose: journal-media`, and has cleared malware scan. Files does not know it is a photo of a sunset that meant something to the user. The boundary is **bytes + bytes-metadata**, not domain meaning.
- **The `ICacheStore<T>` contract or any cache backing.** Per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md), cache backings live in `HoneyDrunk.Cache`. Files may *use* a cache (e.g., for SAS-token cache or quota snapshots) but does not host one.
- **Tenant lifecycle.** Per [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md), tenant state transitions live in Billing (when stood up) and orchestrate through Communications. Files is a **consumer** of the offboarding cascade (D11) — it receives a `TenantOffboarding` or `TenantClosed` event and executes its deletion cascade. It does not own the state machine.
- **User identity or authorization.** Per ADR-0006 and the Auth Node, authentication and authorization decisions live in `HoneyDrunk.Auth`. Files checks the `IGridContext.TenantId` and the authenticated principal's claims via Auth's contracts; it does not mint identities or issue policies.
- **Audit storage.** Per [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md), the audit record substrate is the Audit Node. Files emits audit events via `IAuditLog`; it does not store them.
- **Notification delivery.** Per [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md), outbound messaging delivery is Notify's remit. Files does not send the "your file is ready" email — Communications orchestrates that, Notify delivers it. Files may emit a Transport event that Communications subscribes to.
- **Provider attachment payloads sent through Notify.** Per D13, Notify's provider-direct attachment path stays. Files is the *option*, not the only path; consumers choose.
- **Search or indexing.** No full-text search across blob contents, no OCR pipeline, no perceptual-hash deduplication, no ML feature extraction. Files is a *bytes + bytes-metadata* substrate. If a future consumer needs OCR, that's a `HoneyDrunk.OCR` Node or a Capabilities tool, not a Files extension.

**Dependency direction (one-way, strict):**

```
HoneyDrunk.Files
  ├─ consumes ──► HoneyDrunk.Kernel.Abstractions (IGridContext, lifecycle, telemetry)
  ├─ consumes ──► HoneyDrunk.Vault (storage account credentials, signing keys for SAS issuance)
  ├─ consumes ──► HoneyDrunk.Data (metadata persistence; the bytes-metadata table)
  ├─ consumes ──► HoneyDrunk.Transport (processing pipeline messages, upload-completion events)
  ├─ consumes ──► HoneyDrunk.Auth (authorization policy checks on signed-URL issuance)
  ├─ consumes ──► HoneyDrunk.Audit.Abstractions (IAuditLog for Restricted-tier events)
  └─ emits telemetry ──► Pulse (one-way; no runtime dependency)
```

Files is a leaf-ish substrate Node from the consumer side: PDR-driven app Nodes (Hearth, Lately, Curiosities, Currents), Studios product surfaces, and Notify Cloud tenants take the dependency edge against `HoneyDrunk.Files.Abstractions`.

### D7. Upload flow — signed-URL direct-to-blob, with the API issuing the SAS after policy check

The upload pattern is **signed-URL direct-to-blob**. The API never proxies bytes. The sequence:

```
1. Consumer Node calls IFileUploadSession.Initiate(UploadRequest)
   - UploadRequest carries: TenantId (from IGridContext), purpose, content_type,
     declared_size, declared_classification.

2. Files checks IFileQuotaPolicy for the tenant:
   - declared_size + current_usage <= byte_quota? → continue
   - file_count + 1 <= file_quota? → continue
   - declared_size <= single_file_cap? → continue
   - Otherwise: return UploadDenied(reason) [no SAS issued].

3. Files allocates a file_id (26-char ULID).

4. Files generates a SAS (Shared Access Signature) scoped to:
   - The specific blob path: {tenant_id}/{purpose}/{file_id}
   - Write-only permission (no read; no overwrite of existing blob).
   - 15-minute TTL (configurable per consumer, but capped at 60 minutes).
   - Content-type pin matching UploadRequest.content_type.
   - Maximum content length matching UploadRequest.declared_size + 5% slack.

5. Files writes an UploadSession record in metadata (state: pending).
   - Idempotency key: {tenant_id}:{purpose}:{client_provided_idempotency_key}
     (per ADR-0042 — re-initiating the same logical upload returns the same
     file_id and reuses the existing pending session if not yet completed).

6. Files returns UploadSession to the consumer:
   - file_id, signed_upload_url, expires_at, completion_callback_url.

7. Consumer hands signed_upload_url to the client (browser, mobile app).
   Client uploads bytes directly to Azure Blob Storage.

8. Client (or Azure Blob Storage Event Grid trigger) signals completion.
   Files transitions UploadSession to scan-pending.

9. Files triggers the processing pipeline (D9).

10. On processing + scan completion, Files transitions UploadSession to available.
    Files emits FileAvailable event over Transport.
    Consumer Node receives the event and may now reference the file_id
    in its domain (e.g., Hearth attaches the file_id to the journal entry).
```

The "API never proxies bytes" property matters at two scales: cost (we don't pay egress through the Files API; we pay Azure-internal data plane only) and operational simplicity (Files' Container App / Function does not need to handle multi-GB request bodies, streaming, chunked uploads, or retry-on-partial-failure — Azure Blob Storage's REST API handles all of that natively, and its SLA is better than anything the Grid could provide).

### D8. Public vs. private assets — CDN-fronted for public, short-lived SAS for private

**Public assets** are the Files-tagged category for blobs designed to be world-readable (e.g., a tenant's published avatar, a Studios marketing asset, a public photo in a Curiosities discovery feed where the user has explicitly chosen "public"). Public assets:

- Live in the same single container per environment, under the same path-prefixed scheme. Their public-ness is a metadata property, not a path property.
- Are served through **Azure Front Door / CDN** at `cdn.{env}.honeydrunkstudios.com` (or per-PDR subdomains like `cdn.hearth.honeydrunkstudios.com` if separation matters at brand level). The CDN is fronted by Cloudflare per [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md), with Azure Front Door as the Azure-side origin handling the storage account binding.
- Have permissive cache headers (years), versioned by `file_id` so a derivative regeneration produces a new `file_id` and the CDN naturally invalidates by URL change.
- Do **not** receive a SAS; the CDN URL is unauthenticated.

**Private assets** are everything else (journal media, voice clips, attachments, anything tagged Restricted per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md)). Private assets:

- Are served via short-lived **read-scoped SAS** issued by `IFileStore.GetDownloadUrl(file_id, ttl)`.
- Default TTL: 15 minutes. Maximum TTL: 4 hours (configurable per consumer, capped at the storage account level).
- Are **never** CDN-cached. The SAS URL is single-use-shaped (different request → different SAS); CDN caching of a SAS URL would defeat the security model.
- Carry a Stored Access Policy that allows revocation in case of credential compromise.

**The distinction is metadata-driven, not path-driven.** A consumer that uploads a file under `journal-media` purpose receives a private-by-default file. A consumer that explicitly flags `is_public: true` at upload time receives a public-by-default file (and the upload is audited per D12). The promotion-from-private-to-public path is a deliberate operation, not a side effect.

### D9. Processing pipeline — async, idempotent, scan-before-available

The processing pipeline runs **asynchronously** between upload completion and the file becoming available to consumers. Pipeline stages:

```
upload-complete
  → malware-scan (Defender for Storage, on-upload)
  → format-validation (content-type matches actual bytes; reject mismatches)
  → exif-strip (for image uploads; forced for Restricted-tier per ADR-0049)
  → derivative-generation (thumbnails, web-sized variants for images;
     transcoded mp3/ogg for voice clips)
  → metadata-finalize (classification, processing status, derivative paths)
  → file-available (Transport event; consumer-visible)
```

**Idempotency.** Per [ADR-0042](./ADR-0042-idempotency-contract-for-async-boundaries.md), each stage is keyed by `file_id` and is safely re-runnable. If the pipeline fails mid-flight (e.g., the EXIF-strip stage throws), the file_id remains in `processing-{stage}` state; a retry resumes from the failed stage without re-executing prior stages.

**Trigger mechanism.** Upload completion fires an Azure Blob Storage `BlobCreated` Event Grid event. A Files-owned subscriber (Container App or Functions; the deployable shape is a [ADR-0015](./ADR-0015-container-hosting-platform.md) Container App by default, picked at first-feature-packet time) consumes the event, validates the path matches a pending `UploadSession`, and enqueues the pipeline.

**Scan-before-available is the default posture.** A file is **not** consumer-visible until malware scan, format validation, and EXIF strip have all passed. The alternative (scan-async, quarantine-on-fail) was considered:

| Option | UX | Risk | Cost |
|--------|----|------|------|
| **Scan-before-available** (selected) | User uploads, sees "processing..." for a few seconds, file then appears. | Zero — no malware-bearing byte is ever visible to anyone other than the original uploader's session. | Defender for Storage's per-GB scan cost; processing latency on the user. |
| **Scan-async, quarantine-on-fail** | User uploads, file appears immediately. If malware detected, file is removed retroactively and any consumers who already saw it have a stale reference. | Real — there's a window during which malware is visible. For Hearth's journal use case (user sees their own file before scan completes) the window is bounded to the original uploader; for a multi-user feature (e.g., a shared photo), the window is unbounded across the audience. | Lower processing latency; complexity in the "retroactive removal" path. |

**Decision:** Scan-before-available. The latency cost (a few seconds for the average image) is acceptable; the malware-visibility risk on a multi-user feature is not.

**Processing-toolchain selection deferred.** The specific image library (ImageSharp / Magick.NET / SkiaSharp), audio toolchain (FFmpeg / NAudio), and video pipeline (if introduced — out of v1 scope) are first-feature-packet decisions. The `IFileProcessor` interface is the contract; the implementations land when the first consumer needs them.

### D10. Quotas — per-tenant byte total, file count, single-file size cap; tier-driven defaults; behavior at the limit

Per-tenant quotas are enforced by `IFileQuotaPolicy` and consist of:

- **Byte total quota** — total stored bytes across all files for the tenant.
- **File count quota** — total file count across all purposes for the tenant.
- **Single-file size cap** — maximum size of a single uploaded file.

Quota defaults are **tier-driven**, sourced from `HoneyDrunk.Billing` (when stood up per [ADR-0037](./ADR-0037-payment-and-billing-integration.md)) and cached per-tenant in a `QuotaSnapshot` record. Tier-default seed values (to be confirmed at first-feature-packet time):

| Tier | Byte total | File count | Single-file cap |
|------|-----------|-----------|-----------------|
| `tnt_internal` (Grid first-party) | 1 TB | 1,000,000 | 1 GB |
| Trialing | 500 MB | 1,000 | 25 MB |
| Active (Pro tier) | 25 GB | 50,000 | 100 MB |
| Active (Scale tier) | 250 GB | 500,000 | 500 MB |
| Suspended | Frozen — no new uploads; existing reads continue per [ADR-0050 D4](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md). | | |
| Offboarding | Frozen — export-only reads per [ADR-0050 D5](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md). | | |

**Behavior at the limit:**

- **Pre-upload check (at SAS issuance):** if the declared upload size would exceed any quota, `IFileUploadSession.Initiate` returns `UploadDenied(reason)`. **No SAS is issued.** The consumer Node receives a structured error and surfaces the appropriate UX (e.g., Hearth shows "You've reached your storage limit; upgrade or delete some files.").
- **Mid-upload escape (post-SAS, pre-completion):** the SAS itself enforces the declared size + 5% slack at the storage-account level. Azure Blob Storage rejects oversize writes; the upload fails at the storage layer, and Files cleans up the pending UploadSession on the next sweep.
- **At-quota soft warning:** at 80% / 90% / 100% of any quota dimension, Files emits a `QuotaThresholdCrossed` Transport event. Communications subscribes and decides whether to send a customer notification per the tenant's preferences.

**Alarms before any tenant can run up a bill** (per the brief's "explicit alarms before any tenant can run up a bill" requirement):

- Per-tenant **byte-ingress alarm** at 90% of plan quota.
- Grid-wide **storage-account-total alarm** at 80% of the storage account's published capacity. The Grid pays for storage; runaway tenant uploads against a misconfigured quota are a financial-incident class. The alarm wires into the Grid cost-governance posture per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md).
- Per-tenant **egress alarm** at the equivalent of $X (configurable; default seed value $50/month per tenant). Excess egress on a Trialing tenant is most likely abuse and triggers an ops review.

### D11. Retention, soft-delete, and the deletion cascade — driven by [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md)

**Soft-delete window.** Every file deletion (consumer-initiated `IFileStore.Delete(file_id)`, system-initiated cleanup, or admin-initiated removal) is **soft** by default. Soft-deleted files:

- Are removed from `IFileStore.Get` and `IFileStore.GetDownloadUrl` (the consumer can no longer reach them).
- Are still present in Azure Blob Storage, under a `soft-deleted-{timestamp}` marker.
- Are recoverable via an ops-only `IFileStore.Restore(file_id)` path for the duration of the soft-delete window.
- Are hard-deleted by an Azure Blob Storage Lifecycle Management rule after the soft-delete window elapses.

**Soft-delete window:** **30 days by default.** Configurable per tenant tier; minimum 7 days; maximum 90 days.

**Tenant offboarding cascade.** When [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) transitions a tenant to `Offboarding`, Files receives the `TenantOffboarding` Transport event. Files:

1. Locks new uploads for the tenant (already enforced by quota in the `Offboarding` state per D10).
2. Marks all the tenant's files as `pending-tenant-deletion`. Existing soft-delete state is preserved (overlapping cascades resolve to the longer-deferred date).
3. The tenant's read path remains available **for export only** per [ADR-0050 D5](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md). Files cooperates by issuing read-only SAS URLs against the existing blobs through the export endpoint.
4. At `Offboarding T+30` (when [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) transitions the tenant to `Closed`), Files receives `TenantClosed` and executes the **hard-delete cascade**:
   - Hard-delete every blob under the `{tenant_id}/` prefix.
   - Hard-delete every metadata row for the tenant.
   - Emit a `TenantFilesErased` audit event referencing the (now-orphaned) `pseudo_tenant_token` per [ADR-0050 D6](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md).
5. The Azure Blob Storage soft-delete window on the storage account itself (Azure default 7-14 days) provides a recovery-from-mistake buffer for ops; the keys are inaccessible to the tenant. The pseudonymous tokens in audit records become permanently unresolvable.

**User-level erasure cascade (GDPR Article 17).** When [ADR-0050 D6](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) executes an individual-user erasure, Files receives a `UserErasureRequest` event referencing the user's `pseudo_user_token`. Files:

1. Queries metadata for every file whose `uploaded_by` resolves to the user's identity.
2. Hard-deletes those files (no soft-delete buffer for GDPR erasure — the request is statutory and must be fulfilled "without undue delay").
3. Emits a `UserFilesErased` audit event referencing the `pseudo_user_token`.

### D12. Audit events — Files emits to `IAuditLog` for Restricted-tier and privileged operations

Files emits audit events through `IAuditLog` (per [ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md)) for the following operations:

| Event | Trigger | Tier | Includes |
|-------|---------|------|----------|
| `FileUploadInitiated` | Restricted-tier upload only | Restricted | `tenant_id` (pseudonymized), `uploaded_by` (pseudonymized), `purpose`, `declared_size`, `declared_classification` — no file content, no filename if filename itself is PII |
| `FileUploadCompleted` | Restricted-tier upload only | Restricted | Same fields plus `file_id`, final classification, scan result |
| `FileUploadDenied` | Quota exceeded, scan failed, format mismatch | Confidential | `tenant_id` (pseudonymized), `purpose`, `reason` |
| `FileDownloaded` | Admin / cross-tenant / ops-initiated downloads only — **NOT** every consumer download | Restricted | `tenant_id` (pseudonymized), `accessed_by` (pseudonymized), `file_id`, `reason_code` |
| `FilePromotedToPublic` | Any private→public transition | Confidential | Same fields plus old/new visibility |
| `FileDeleted` | Hard-delete only — soft-delete is not audit-worthy | Confidential | `tenant_id` (pseudonymized), `deleted_by` (pseudonymized), `file_id`, `cascade_reason` (consumer-initiated / tenant-offboarding / user-erasure / retention-elapsed) |
| `MalwareDetected` | Defender scan returns positive | Restricted | `tenant_id` (pseudonymized), `file_id`, `scan_signature`, `quarantine_path` |
| `TenantFilesErased` | Tenant Closed cascade complete | Confidential | `pseudo_tenant_token`, file count erased, total bytes erased |
| `UserFilesErased` | User erasure cascade complete | Confidential | `pseudo_user_token`, file count erased, total bytes erased |

**Per-download audit is deliberately scoped to admin / cross-tenant / ops paths**, not every consumer-driven download. Auditing every consumer download would explode the audit substrate's volume and dilute the security signal. Consumer downloads are *expected*; admin downloads of a tenant's data are *exceptional* and warrant the record.

**Pseudonymization at the audit boundary** per [ADR-0050 D6](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md). Every actor reference in a Files audit event is a `pseudo_tenant_token` or `pseudo_user_token`; the real tenant/user identity is resolvable only through the Auth IdentityMap, which is erasable.

### D13. Notify-attachment compatibility — Notify keeps its provider-direct path; Files is the option

The brief asks whether Notify should route attachments via Files or keep its own provider attachments. The answer: **both, with Files as the recommended path for any byte that needs to outlive the delivery moment.**

**Notify's existing provider-direct path stays.** Notify currently accepts attachments as opaque payload data and passes them through to Resend / Twilio. For purely transient attachments (an email-only attachment that the recipient will download once and the Grid does not need to keep), the provider-direct path is fine and remains supported.

**Files is the recommended path for any byte that needs to:**
- Outlive the delivery moment (tenant wants the attachment kept for audit, future re-send, or download from a portal).
- Be referenced by `file_id` across multiple Grid Nodes (Hearth attaches a journal image, then later Communications references that same `file_id` in a weekly digest email).
- Be subject to per-tenant quota or Restricted-tier classification.
- Have CDN-fronted public delivery.

**Concrete integration shape (decided here, packets land later):**
- Notify's `Attachment` record gains an optional `file_id` field. If `file_id` is set, Notify retrieves the bytes via `IFileStore` at delivery time (with a short-lived read SAS) and passes them to the provider.
- Consumers that want Grid-side persistence upload to Files first, get back a `file_id`, then pass the `file_id` to Notify.
- Consumers that want pure transience pass raw bytes to Notify as today; Notify never round-trips them through Files.

This keeps Notify's surface backward-compatible while making Files the right answer for any non-transient attachment. The two paths are **not redundant** — they serve different lifecycles. Notify's provider-direct path is the wrong place to durably persist bytes; Files is the wrong place to handle the per-send, per-provider attachment shape.

### D14. Vault wiring — storage account keys and SAS signing keys live in per-Node Key Vault

Per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md) and [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md):

- Files has its own Key Vault: `kv-hd-files-{env}`.
- Storage account connection strings, SAS user-delegation keys, and Defender for Storage subscription identifiers all live in that Key Vault.
- The Files Container App authenticates to Storage via Managed Identity (preferred — no key in Vault at all) where the operation supports it; Vault holds the fallback shared-key value and the user-delegation-key endpoint reference.
- Storage account keys are Tier-1 rotation (Azure-native, per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md)) — Azure rotates the keys on the schedule the Key Vault policy commits, and the Files cache invalidates via Event Grid on `Microsoft.KeyVault.SecretNewVersionCreated`.
- **Files holds no secrets directly in code, configuration files, or environment variables beyond the `AZURE_KEYVAULT_URI` per Invariant 18.**

### D15. Charter sanity check — is this premature?

The brief asks explicitly: *is this premature? The Node doesn't get built until the first app needs media.*

The answer is no, with stated reasoning:

1. **The first app that needs media is already named.** PDR-0005 Hearth is the scout's first-build pick and requires media upload from the first usable iteration. The lead time between this ADR and Hearth's first packet that touches Files is weeks, not quarters. The front-loading is short, not speculative.

2. **The cost of front-loading is bounded.** The scaffold is an afternoon's work — repo + solution + CI + contract package + InMemory adapter + context folder. No Azure resources are provisioned by this ADR; no monetary cost is incurred. The substrate cost is one ADR + one scaffold packet.

3. **The cost of *not* front-loading is N×bespoke-implementations.** If Hearth ships its own blob layer, that layer must be torn out the moment Lately, Curiosities, Currents, or Notify Cloud tenant attachments need the same capability. The architecture-as-procrastination check (per [`constitution/charter.md`](../constitution/charter.md) §"What this charter forbids" item 2) cuts the *other* way here — the procrastination would be putting blob logic inside Hearth and committing to ripping it out later.

4. **The boundary is what's being committed, not the implementation.** This ADR commits the contract surface (`IFileStore`, `IFileUploadSession`, `IFileQuotaPolicy`, etc.) and the boundaries (D6: what Files owns, what Files does not own). The Azure Blob adapter, the malware scan integration, the CDN configuration — those are first-feature-packet decisions and are not in this ADR's scope. The procrastination test is "is the foundation work matched by active feature work?" The active feature work is the Hearth scout standing up; this is exactly the moment to commit the substrate boundary so the scout's first packet is mechanical work against a settled foundation.

5. **The charter's self-check question** ("if a year goes by and only ADRs ship, the foundation is consuming the workshop instead of supporting it") points at *runaway substrate work*, not at *necessary substrate work paired to a named consumer*. Files is the latter. The charter's antibody fires when ADRs are written for hypothetical workloads; it does not fire when an ADR is written for an imminent named workload.

**The standup is correctly-sized.** The Node is not Accepted today; this ADR is Proposed. Acceptance follows the scaffold packet landing per the standup-ADR convention. If Hearth's first packet does not arrive within ~60 days of acceptance, the substrate sits empty in good company (Sim, Flow, Evals, Knowledge stood up before their first features). If Hearth's packet does arrive, Files is ready and the substrate cost is repaid in full.

### D16. Catalog updates required — call out, do not edit in this ADR

This ADR identifies the catalog and reference-doc updates required at acceptance. The updates themselves are filed as scope-agent-dispatched packets, not authored in this ADR text:

- **[`catalogs/nodes.json`](../catalogs/nodes.json)** — Add `honeydrunk-files` entry with Core sector, contracts from D6, `visibility: "public"` (implicit by absence; or explicit if the catalog now defaults to including the field), tags `["files", "blob-storage", "media-processing", "signed-url", "cdn", "substrate"]`.
- **[`catalogs/relationships.json`](../catalogs/relationships.json)** — Add `honeydrunk-files` with `consumes: ["honeydrunk-kernel", "honeydrunk-vault", "honeydrunk-data", "honeydrunk-transport", "honeydrunk-auth", "honeydrunk-audit"]`, empty `consumed_by` at stand-up, `consumed_by_planned: ["honeydrunk-hearth", "honeydrunk-lately", "honeydrunk-notify", "honeydrunk-notify-cloud"]` (or whichever Node IDs the PDR-driven app standups commit when they land).
- **[`catalogs/grid-health.json`](../catalogs/grid-health.json)** — Add `honeydrunk-files` row reflecting empty-stand-up state (abstractions + InMemory shipped; AzureBlob adapter empty; no Azure resources provisioned).
- **[`catalogs/modules.json`](../catalogs/modules.json)** — Add the Files Node entry with the four packages from D3 (`HoneyDrunk.Files.Abstractions`, `HoneyDrunk.Files`, `HoneyDrunk.Files.InMemory`, `HoneyDrunk.Files.AzureBlob`).
- **[`constitution/sectors.md`](../constitution/sectors.md)** — Update the Core sector entry to include Files as the home for blob storage, media processing, signed-URL delivery, and tenant-quota policy.
- **[`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md)** — Add Files to the Nodes table; add `Azure Blob Storage`, `Azure Defender for Storage`, `Azure Front Door (CDN)` rows under appropriate sections (with the Cloudflare-as-edge front-of-edge story from [ADR-0029](./ADR-0029-cloudflare-dns-and-edge-platform.md) preserved).
- **[`initiatives/roadmap.md`](../initiatives/roadmap.md)** — Add Files entry under the Core substrate section (or "Stood up, not yet implemented" subsection if such exists).
- **`repos/HoneyDrunk.Files/` folder** — Create with `overview.md`, `boundaries.md`, `invariants.md` stubs matching the template used by [`repos/HoneyDrunk.Audit/`](../repos/HoneyDrunk.Audit/) and [`repos/HoneyDrunk.Communications/`](../repos/HoneyDrunk.Communications/).

These updates are listed in the follow-up checklist at the top of this ADR.

## Consequences

### Implementation — Done When

This ADR is "Done" when all of the following are true:

- [ ] `HoneyDrunk.Files` public repo created.
- [ ] Scaffold packet landed: solution with the four packages from D3, HoneyDrunk.Standards wiring, CI pipeline, README, CHANGELOG, LICENSE.
- [ ] `HoneyDrunk.Files.Abstractions` package builds and packs (contract surface from D6).
- [ ] `HoneyDrunk.Files.InMemory` package builds, packs, and passes unit tests against the abstractions.
- [ ] `HoneyDrunk.Files.AzureBlob` placeholder project exists, builds empty, ships no published implementation.
- [ ] CI pipeline green on the scaffold (build, unit tests, canary against the abstractions).
- [ ] `repos/HoneyDrunk.Files/` context folder exists in the Architecture repo with `overview.md`, `boundaries.md`, `invariants.md`.
- [ ] `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/modules.json` carry the new Node entry.
- [ ] `constitution/sectors.md` Core-sector entry includes Files.
- [ ] `infrastructure/reference/tech-stack.md` and `initiatives/roadmap.md` reflect the stand-up.
- [ ] Scope agent flips Status → Accepted.

### Unblocks

Accepting this ADR — and landing the follow-up scaffold packet — unblocks the following:

- **Hearth's first media-bearing packet.** Hearth's scout work can scope "user uploads a photo to a journal entry" against the `HoneyDrunk.Files.Abstractions` surface from day one, with no need to invent a bespoke blob layer.
- **The AzureBlob adapter feature packet.** When the first real consumer (likely Hearth) activates Files, the AzureBlob adapter packet has a home Node to land in and a contract to implement.
- **The Azure resource provisioning packet.** First storage account, first CDN profile, first Defender for Storage subscription, first Front Door endpoint — provisioned at the AzureBlob adapter feature packet's time, per the "provision when needed" preference.
- **Notify's attachment-via-file_id support.** Notify can add the optional `file_id` field on `Attachment` against the Files abstractions package without waiting for the AzureBlob adapter.
- **PDR-0002 Notify Cloud tenant attachments.** Notify Cloud tenants get a coherent answer ("upload to Files, reference the `file_id` in your Notify call") instead of a per-tenant bespoke story.
- **PDR-0003 Lately, PDR-0006 Currents, PDR-0008 Curiosities** — every consumer-PDR that assumes user-uploaded media has a Grid-correct landing pad.
- **The [ADR-0050](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) tenant-offboarding cascade.** The cascade requires a Node to own the deletion of tenant-uploaded blobs; Files is that Node.
- **The [ADR-0050 D6](./ADR-0050-tenant-lifecycle-provisioning-suspension-offboarding-and-data-export.md) GDPR Article 17 user-erasure cascade.** Same — the user's uploaded media must be hard-deletable; Files owns that path.

### New invariants

Two candidate invariants are nominated for promotion at acceptance time. The scope agent assigns final invariant numbers when the ADR flips to Accepted:

- **Candidate: "The Files Node never persists domain meaning, only bytes and bytes-metadata."** The classification of *what a file means* lives in the consuming Node; Files knows the bytes, the size, the content type, the purpose-tag, the tenant, the classification, the upload timestamp, and the processing status — nothing more. Prevents Files from drifting into a half-baked content-management system.
- **Candidate: "Every download path through Files is either CDN-fronted public or a short-lived SAS issued after policy check."** Forbids long-lived storage-account-shared-key URLs anywhere in the Grid. The shape of every Files download is auditable from this rule alone.

A third candidate is **conditional on first-feature-packet evidence**: "Restricted-tier image uploads must have EXIF stripped before becoming consumer-visible." This is committed in D9 as the default processing-pipeline shape; whether it warrants invariant-level promotion (with a canary test enforcing it) is a question best answered after the first real image upload pipeline runs.

### Catalog obligations

`catalogs/nodes.json` does not currently carry an entry for `honeydrunk-files`. Adding one is straightforward — the schema fields are well-established by every existing Node entry. The new entry carries:
- `id: "honeydrunk-files"`
- `name: "HoneyDrunk.Files"`
- `sector: "Core"`
- Contracts from D6 (`IFileStore`, `IFileUploadSession`, `IFileMetadata`, `IFileProcessor`, `IFileQuotaPolicy`).
- Tags: `["files", "blob-storage", "media-processing", "signed-url", "cdn", "quota", "substrate"]`.
- `visibility` either omitted (defaulting to public) or explicit `"public"` per the existing catalog convention.

`catalogs/relationships.json` gains the dependency edges in D6. `catalogs/grid-health.json` gains a row reflecting empty-stand-up state. `catalogs/modules.json` gains the Node entry with the four packages from D3. `constitution/sectors.md` gains a Files row in the Core-sector table. `infrastructure/reference/tech-stack.md` gains Files and the Azure backing rows. `initiatives/roadmap.md` adds the Files entry.

These reconciliations are tracked in the follow-up work checklist at the top of this ADR.

### Negative

- **Two clouds are simpler than one for the public-asset egress story.** Cloudflare R2's egress-free pricing is genuinely attractive for read-heavy public workloads (avatars in Lately, photos in a Currents discovery feed). By committing Azure-only for v1, the Grid pays Azure egress for every CDN miss. Mitigation: the contract is backing-agnostic; a future R2 adapter is a clean migration path if egress costs become material. Reassess at the 6-month mark with real data.
- **Single-storage-account scaling ceiling.** Azure Storage caps a storage account at 200 TB and at 20,000 transactions per second per partition. At Grid scale today (effectively zero usage), neither limit is near. At 100×+ scale, a second storage account would be needed — a config change, not an architecture change. The path-prefixed isolation model handles multi-account by hashing the tenant prefix to an account; the bookkeeping is non-trivial but bounded.
- **Path-prefixed tenant isolation depends on Files' policy code being correct.** Unlike container-per-tenant (which fails-closed at the Azure surface for a cross-tenant access bug), path-prefixed isolation can leak across tenants if Files' SAS issuance code has a bug. Mitigation: the SAS prefix-constraint is enforced by Azure (the storage layer itself rejects out-of-prefix writes against a prefix-scoped SAS); the bug surface is narrow (only `IFileUploadSession` and `IFileStore.GetDownloadUrl` mint SAS tokens), and both have canary tests at boundary level.
- **The Defender for Storage cost.** Per-GB scan pricing applies to every uploaded byte. At low scale (Hearth's first hundred users) this is negligible; at Notify Cloud commercial scale, it could be material. Mitigation: the alarm posture from D10 gives early warning; the scan-async-quarantine alternative is on the shelf if cost becomes the dominant pain point and the multi-user-visibility risk is acceptably narrow for the affected workloads.
- **Processing latency on uploads.** Scan-before-available adds a few seconds to the user-visible upload latency. For Hearth (a journaling app where the user expects to see their photo immediately) this may feel slow. Mitigation: the optimistic UI pattern — Hearth shows a placeholder with "processing..." status, reads the `FileAvailable` event over Transport, then swaps in the real image — is a UX-side decision that does not change the Files contract.
- **A repo with limited production code on day one is reviewable surface that future agents and contributors may misread.** The first PR ships abstractions + InMemory + empty AzureBlob, which is more than the Cache standup (which had no production code at all) but less than a "real" Node. Mitigation: the README links to this ADR as the canonical reference; the AzureBlob placeholder carries a clear "no implementation on day one — see ADR-0061" comment.
- **The Notify dual-path story (D13) is two ways to do something.** Two paths is more surface than one. Mitigation: the two paths serve different lifecycles (transient vs. persistent); a single path that supported both would be uglier, not simpler. The README and the Notify `Attachment` XML docs both explain the distinction.

## Alternatives Considered

### Put blob storage in `HoneyDrunk.Data`

Considered. Data is the Grid's persistence-store host; conceptually blobs are "persisted data."

Rejected. Persistence stores and blob stores have meaningfully different semantic properties: durability characteristics, access patterns (transactional vs. byte-streaming), failure modes, cost shape, scaling shape (Data scales with row count and query complexity; Files scales with byte volume and bandwidth). Mixing them confuses the boundary. The Grid pattern of one substrate-host Node per concern (Vault for secrets, Data for persistence, Audit for audit records, Transport for messaging, Cache for cache backings, Files for blobs) keeps the boundaries crisp.

### Put blob storage in `HoneyDrunk.Notify`

Considered. Notify already handles attachments as provider-direct payloads; extending it to durably persist them is a small-looking move.

Rejected. Notify's identity is **delivery, not storage** — that boundary was deliberately committed in [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md) when orchestration was moved out of Notify into Communications. Pulling storage *into* Notify would invert that boundary decision in the opposite direction. Notify owns the wire to the provider; Files owns the bytes. The two are composable (D13) without conflating identities.

### No Node yet — first app rolls its own

Considered, and explicitly evaluated against the charter's architecture-as-procrastination check. The argument: the first app (Hearth) implements its own blob layer; only extract it when a second consumer appears.

Rejected per D4 (full pros/cons table) and D15 (charter sanity check). The procrastination cut goes the other way: building a bespoke layer in Hearth is the procrastination, not building the substrate. The substrate cost is one ADR + one scaffold packet; the cost of not building it is N×bespoke-implementations across N consumers, plus the rip-out work to consolidate them later. The first usable iteration of Hearth is the forcing function; the standup convention is to commit substrate *before* the first packet, not bundled with it.

### Single Node for blobs + structured data ("HoneyDrunk.Storage")

Considered. One Node for *all* persistence — relational, blob, key-value — would reduce Node count and centralize "where data lives."

Rejected. The Grid has multiple persistence shapes (Data for structured, Vault for secrets, Cache for cache, Files for blobs, Audit's data store for audit records) and the Node-per-concern pattern is established across eight prior standups. Re-litigating that pattern here for a count argument would re-open a settled question without new evidence. The boundaries are crisper with one substrate Node per shape than with one mega-Node.

### Defer to the first feature packet — bundle the Files standup with Hearth's first media packet

Considered. The argument: standup work is dead weight until the first feature implementation is ready to land, so why not bundle them?

Rejected per the standup-ADR convention set 2026-04-19 (`feedback_adr_before_scaffold`). Bundling scaffold work into a feature packet conflates substrate decisions with feature decisions; the reviewer agent and the scope agent both work better when the two are separated. The convention is well-established across Cache, Audit, Operator, Agents, Knowledge, Memory, Evals, Flow, Sim, and Notify Cloud standups, and has not produced a problem case. Following it again here is the right call.

### Use Azure Files (SMB) or Azure NetApp Files instead of Blob Storage

Considered. SMB-shape storage offers POSIX-like semantics and may feel familiar.

Rejected. The Grid's access pattern is web-shaped (HTTP GET/PUT with signed URLs, REST API, CDN-fronted reads) and not POSIX-shaped (no consumer needs file-handle, lock, rename semantics). Azure Blob Storage's REST API matches the access pattern exactly; SMB would be the wrong shape for every consumer named. Azure NetApp Files is enterprise-priced for workloads neither the Grid nor any PDR has signaled.
