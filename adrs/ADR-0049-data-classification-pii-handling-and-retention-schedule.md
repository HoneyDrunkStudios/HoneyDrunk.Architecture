# ADR-0049: Data Classification, PII Handling, and Retention Schedule

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has accumulated a working set of data-handling decisions distributed across several ADRs, but no canonical taxonomy unifies them:

- **ADR-0030 D3** binds `IAuditLog` emitters to redact "sensitive fields" before append, and **ADR-0030 D4** commits the audit substrate to a retention class "distinct from Pulse/observability retention" — but neither defines what a sensitive field *is*, nor states the actual retention number.
- **ADR-0040 D3** commits three telemetry retention windows (90 days for traces/logs, 93 days for metrics, 730 days for Audit-sourced logs) — and **ADR-0040 D9** lists specific PII categories ("prompt text, completion text, recipient email addresses, message bodies") that must not flow through observability — but the list is observability-scoped and not portable to other channels.
- **ADR-0036 D1** defines three durability tiers (T0/T1/T2) with retention-shaped properties (LTR windows, point-in-time-restore windows, soft-delete windows) — but **ADR-0036 D7** explicitly defers the data-subject-deletion-vs-backup-retention reconciliation to "a future ADR."
- **ADR-0045 D7** repeats the PII-scrubbing rule for the error channel, deferring to ADR-0040 D9's mechanism.
- **Invariant 47** mandates that "data-change details that include sensitive fields must be redacted before append" — but **defines "sensitive field" nowhere in the constitution.** The reviewer has no rubric, the scope agent has no template, and the `security` specialist agent (per ADR-0046 D2) has no canonical reference to cite.
- **PDR-0003 (Lately), PDR-0005 (Hearth), PDR-0006 (Currents), PDR-0008 (Curiosities)** all describe consumer-facing applications that will collect personal data (names, emails, behavioral telemetry, journal entries, location, photos). None of these PDRs can move to `scope`-agent-driven packet generation without a Grid-wide data-classification rubric — the per-app packets would each invent their own taxonomy and the drift would be permanent.
- **BDR-0001** establishes the Studio as a Florida LLC with US-only physical presence — but **Notify.Cloud's** existing tenants and the Studios-product target market both include EU/UK individuals. The applicable regulatory floor is therefore the union: **GDPR + UK-GDPR + CCPA/CPRA + Florida-specific statutes** (Florida Information Protection Act, FIPA, and the Florida Digital Bill of Rights, which takes effect 2026-07-01).

The forcing functions for deciding this now:

- **PDR-driven packet generation is blocked.** The four consumer-product PDRs cannot proceed to `scope` packets without a canonical classification. Authoring them per-product produces irreconcilable drift.
- **Invariant 47 is hollow.** The reviewer agent (ADR-0044 D3 category 9 Security) and the `security` specialist (ADR-0046 D2) can't enforce a redaction rule that has no definition of what to redact.
- **ADR-0036 D7's deferred reconciliation is overdue.** Notify Cloud GA (ADR-0027) will inevitably receive a data-subject-deletion request from an EU recipient; the response procedure cannot be improvised.
- **The AI-sector standup wave** (ADR-0016 through ADR-0025) introduces Nodes (Memory, Knowledge) whose entire purpose is durable storage of user-attributable content. They need a classification scheme from day one of their standup canaries.
- **Florida Digital Bill of Rights effective 2026-07-01** introduces consumer rights to access, correction, deletion, and portability for Florida residents above a threshold of business activity. The threshold currently exempts the Studio, but the architecture commitments authored now should not require a re-architecture if the threshold drops or the Studio crosses it.

This ADR commits the canonical four-tier classification taxonomy, the PII sub-taxonomy with explicit GDPR Article 9 mapping, the retention-schedule table per data class, the field-level marking mechanism, the boundary-redaction rules, the right-to-erasure policy principle (with the audit-append-only conflict named and deferred to ADR-0050), the v1 data-residency commitment, the ownership and review duties, and the inventory artifact that makes Grid-wide classification visible.

It does **not** decide tenant-lifecycle mechanics (creation, suspension, deletion, export workflow), which are ADR-0050's scope. The two ADRs are siblings: this one defines what data exists and how it must be handled; ADR-0050 defines the lifecycle operations on it.

## Decision

### D1 — Classification taxonomy: four tiers (Public / Internal / Confidential / Restricted)

Every datum the Grid stores, processes, or transmits is classified into exactly one of four tiers. Classification governs access scope, allowable storage backings, cross-boundary movement, and whether the datum can appear in observability/audit channels.

| Tier | Definition | Examples | Who can see | Allowed storage | Crosses sector boundary? |
|------|------------|----------|-------------|-----------------|--------------------------|
| **Public** | Information intentionally published or designed to be world-readable. No confidentiality requirement. | Marketing copy on Studios site; published NuGet package versions; open-source repo contents; ADRs in this repo; public API documentation. | Anyone, including unauthenticated visitors. | Any backing, including GitHub repos and the public Studios CDN edge. | Yes, unrestricted. |
| **Internal** | Operational information not intended for public consumption but whose accidental disclosure is non-harmful. | Grid telemetry aggregates with no tenant attribution; canary results; build logs; non-tenant Pulse signals; CI workflow logs; the Studio's internal Slack/operator-channel content (per ADR-0040 D8). | Studio operator and authenticated agents. Not customers, not unauthenticated parties. | Any Studio-controlled backing (Azure, GitHub private repos, Vault metadata). Not external SaaS without DPA. | Within Studio operational boundary only. Does not cross into customer-attributable channels. |
| **Confidential** | Tenant- or customer-attributable operational data whose disclosure would harm the customer, the tenant, or the Studio's commercial position. | Tenant configuration, tenant-attributable telemetry with `tenant.id` dimension, tenant operational dashboards, message metadata (sender, recipient, channel) without message body, billing line items, Stripe customer IDs, Notify Cloud per-tenant message counts. | The owning tenant and authorized Studio operators. Cross-tenant visibility is a boundary violation. | Tenant-isolated backings per ADR-0026 (tenant-scoped Vault per ADR-0006, tenant-partitioned Data per ADR-0036, tenant-dimensioned App Insights per ADR-0040 D5). | Only across boundaries that preserve tenant isolation. Never into Internal-tier channels. |
| **Restricted** | Personal data (PII per D2), authentication secrets, payment instruments, health/biometric data, message bodies, model prompts/completions containing user content, journal entries, location traces, photo/audio payloads. | Recipient email addresses (Notify), customer names (Studios product onboarding), authentication tokens, Stripe payment method IDs, journal entry text (PDR-0008 Curiosities), location traces (PDR-0006 Currents), photo uploads (PDR-0003 Lately). | The data subject themselves, the owning tenant's authorized operators on a least-privilege basis, and Studio operators only when a documented operational reason requires it (incident response, billing dispute, legal hold). Default-deny for everyone else. | Encrypted at rest in tenant-isolated backings. Forbidden in observability/telemetry channels (per ADR-0040 D9). Audit channel allowed only with explicit redaction-by-policy per D5. | Only across boundaries explicitly designed for Restricted data. Forbidden across all other boundaries. Never into Internal or Public channels under any circumstance. |

The four tiers are **ordered**: Public ⊂ Internal ⊂ Confidential ⊂ Restricted in terms of handling rigor. A higher-tier datum can always be handled at a higher tier (over-classification is safe); the converse is a boundary violation.

**The classification is of the field, not the record.** A `User` record can contain `Public` fields (e.g., display handle for a public profile), `Confidential` fields (e.g., last-login timestamp), and `Restricted` fields (e.g., email, password hash) all in the same persisted object. The field-level marking discipline (D4) makes this concrete.

**When classification is unclear, default to Restricted.** The cost of over-classification is operational friction; the cost of under-classification is a privacy incident. The `security` specialist (ADR-0046 D2) breaks ties on review.

### D2 — PII sub-taxonomy: PII / Sensitive PII / Pseudonymous

Restricted-tier data that pertains to an identifiable natural person is further sub-classified for handling-rule precision. The sub-taxonomy aligns with GDPR's "personal data" / "special category" split (Articles 4 and 9) and CCPA/CPRA's "personal information" / "sensitive personal information" split.

| Sub-class | Definition | Examples | Regulatory triggers | Additional handling |
|-----------|------------|----------|---------------------|---------------------|
| **PII** | Personal data that identifies or could identify a natural person, by itself or in combination. | Name, email, postal address, phone number, IP address, device identifier, behavioral telemetry tied to an identified person, photos that include faces. | GDPR Article 6 lawful-basis required; CCPA "personal information"; FIPA "personal information." | Encrypted at rest; access logged; deletion-on-request supported (D6); cross-border transfer requires an Article 46 mechanism (Standard Contractual Clauses) if the data subject is in EU/UK and the storage is non-EEA. |
| **Sensitive PII** | Personal data whose disclosure causes elevated harm — government identifiers, financial account credentials, biometric data, precise geolocation, health data, sexual-orientation data, religion, political-opinion data, racial/ethnic-origin data, trade-union membership, children's data (under 13 US / under 16 EU). | Social Security number, passport number, driver's license number, bank account number, full payment card number (PAN), fingerprint template, exact GPS coordinates over time, journal text describing health condition, biometric face-recognition embedding. | **GDPR Article 9 "special category"** (explicit consent or one of the narrow Article 9(2) bases required); CCPA "sensitive personal information"; FIPA mandatory breach notification thresholds. | Encrypted at rest **with tenant-scoped keys** (per ADR-0006 KEK separation, when implemented); access requires a documented operational reason logged via `IAuditLog`; forbidden in any AI training/inference channel without explicit consent; **forbidden in the audit channel's data-change details** even after redaction policy (D5) — only the redacted token may appear. |
| **Pseudonymous identifier** | An opaque identifier scoped to the Grid that maps to a PII subject only via a separate, controlled mapping table. | `PrincipalId` (ULID per ADR-0026), `TenantId`, hashed email used as an idempotency key, `user.id` custom dimension on App Insights telemetry (per ADR-0040 D9), agent-execution correlation IDs. | Not directly regulated as PII **as long as the mapping table is held separately and access-controlled.** GDPR Article 4(5) recognizes pseudonymization as a risk-mitigation measure but does not exempt the underlying personal data. | Permitted in observability, audit-record bodies, agent traces, and analytical exports. The mapping table itself is Restricted/PII and lives in the per-Node identity store (D6). The pseudonymous-token-in-audit, PII-in-erasable-store pattern is the load-bearing mechanic for D6 right-to-erasure. |

The **Article 9 special-category trigger** is the load-bearing distinction the existing ADRs do not make. ADR-0040 D9's PII-scrubbing list (prompts, completions, recipient emails, message bodies) sits at the **PII** level; nothing in the existing ADR set acknowledges that a Curiosities (PDR-0008) journal entry describing a health condition is **Sensitive PII** with an Article 9 trigger that requires explicit consent collection, not the implicit Article 6(1)(b) "necessary for the contract" basis the rest of the data set sits on.

**Children's data** is called out as Sensitive PII because of COPPA (US, under 13), GDPR Article 8 (EU, under 16 or as low as 13 per member-state law), and the Florida Digital Bill of Rights' explicit prohibition on selling or processing minor data for targeted advertising. None of the consumer PDRs currently target minors; **adding a minor-facing surface is a Restricted-class architectural change** that requires its own ADR.

### D3 — Retention schedule

Per data class, the canonical retention. Override mechanism is named where a class supports per-tenant or per-Node deviation; deletion mechanism is named so the procedure exists before the first delete request lands.

| Data class | Default retention | Override mechanism | Deletion mechanism | Audit-trail requirement | Cross-reference |
|------------|-------------------|---------------------|--------------------|--------------------------|------------------|
| **Telemetry — traces** | 90 days | None at v1 (single-workspace policy) | Per-workspace age-based purge (App Insights native) | None — telemetry retention is operational, not regulatory | ADR-0040 D3 |
| **Telemetry — metrics** | 93 days | None at v1 | App Insights native age-based purge | None | ADR-0040 D3 |
| **Telemetry — logs (standard)** | 90 days | None at v1 | Log Analytics workspace age-based purge | None | ADR-0040 D3 |
| **Telemetry — logs (Audit-sourced)** | 730 days (2 years) | Per-Node `dr_tier` may extend; never shorten | Custom-table age-based purge | None (the audit *records* in the Audit Node carry the audit trail; these logs are the operational fan-out) | ADR-0040 D3, ADR-0030 D4 |
| **Audit records (security/activity)** | **730 days minimum**; T0 tenants extended to 7 years | Per-tenant contract may extend (commercial decision; record in BDR) | Append-only; deletion only via the pseudonymous-token-rotation pattern in D6 | The audit channel IS the audit trail; meta-audit (who queried) is also `IAuditLog`-emitted | ADR-0030 D4 |
| **Audit records (data-change)** | **730 days minimum**; T0 tenants extended to 7 years | Same as security/activity | Same as security/activity | Same as security/activity | ADR-0030 D3, D4 |
| **Error events** | 90 days (within App Insights workspace) | None at v1 | App Insights native | None — error events are operational | ADR-0045 D1, D7 |
| **Application data — tenant operational (Confidential)** | Per-Node default: indefinite while tenant active; 90 days post-tenant-deletion grace window | Per-tenant contract may shorten; ADR-0050 governs the lifecycle event triggers | Tenant-lifecycle deletion per ADR-0050; per-record deletion via the Node's domain surface | Every deletion via `IAuditLog` data-change entry | ADR-0026, ADR-0050 (sibling) |
| **Application data — Restricted (PII)** | While tenant/user active and consent valid; deletion within 30 days of consent withdrawal or erasure request | Tenant lifecycle (ADR-0050); explicit consent withdrawal | Erasable-store deletion (D6); pseudonymous tokens in audit retained | Erasure request and execution both audit-trailed via `IAuditLog` | This ADR D6, ADR-0050 |
| **Application data — Sensitive PII** | Minimum necessary; explicit purpose-limitation deletion when purpose served | Explicit per-purpose deletion; consent withdrawal triggers immediate deletion | Same as Restricted PII; additional confirmation (operator + automated) before processing erasure | Mandatory audit entry on every read and every write, not only deletion | This ADR D6 |
| **Backups — T0 (Vault, Audit, Notify Cloud tenant identity)** | Per ADR-0036 D2: 1-year LTR weekly; 35-day point-in-time-restore window | Per-tenant contract may NOT shorten (T0 floor) | Backup age-based expiry on Azure-native schedule; backups in retention window are exempt from immediate erasure per Article 17(3) | None at backup level; restore-drill outcomes logged (ADR-0036 D3) | ADR-0036 D1, D2 |
| **Backups — T1 (Notify, Memory, Knowledge)** | Per ADR-0036 D2: 90-day weekly LTR; 35-day point-in-time-restore | Same as T0 | Same as T0 | None at backup level | ADR-0036 D1, D2 |
| **Backups — T2 (Pulse history, Flow, Evals, dev/staging)** | Per ADR-0036 D2: 90-day monthly LTR; 7-day point-in-time-restore | Same | Same | None | ADR-0036 D1, D2 |
| **Build/CI logs (Internal)** | 90 days (GitHub Actions native) | None | GitHub-native | None | ADR-0011 |
| **Restore-drill logs (Internal)** | 7 years (paper-trail for compliance audits) | None | Manual purge after 7 years | None | ADR-0036 D3 |
| **`generated/incidents/` (Internal)** | Indefinite (this repo) | None | Never auto-deleted | None | CLAUDE.md |

**The 7-year T0 audit extension is the regulatory floor** for SOC 2 Type II and most financial-services-adjacent commitments. v1 Notify Cloud is not a financial-services product, but the Studio's commercial trajectory (per BDR-0001) and the cost of retroactively re-architecting audit retention if a tenant contract requires 7 years both argue for the higher floor on T0 from the start. T1 and T2 stay at 730 days (matching ADR-0030's already-committed minimum).

**Backups in retention windows are not subject to immediate erasure** per GDPR Article 17(3) (compliance with legal obligations / public-interest exemption) and the corresponding US privacy-law backup carve-outs. The procedure: on receipt of an erasure request, the active-store record is deleted within 30 days; the backup-resident copy expires on the backup's documented retention cycle and is not used for any purpose other than restore during that window. The DPA template (deferred per ADR-0036 D7) must state this explicitly.

### D4 — Field-level marking: `[Classification]` and `[PiiField]` attributes

Classification is **declared at the field level in code**, not centrally registered. The mechanism: two .NET attributes in `HoneyDrunk.Kernel.Abstractions`.

```
[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter)]
public sealed class ClassificationAttribute : Attribute
{
    public ClassificationAttribute(DataClass classification);
    public DataClass Classification { get; }
}

[AttributeUsage(AttributeTargets.Property | AttributeTargets.Field | AttributeTargets.Parameter)]
public sealed class PiiFieldAttribute : Attribute
{
    public PiiFieldAttribute(PiiCategory category);
    public PiiCategory Category { get; }   // Pii | SensitivePii | Pseudonymous
    public string? Purpose { get; set; }   // GDPR Article 5(1)(b) purpose-limitation tag
}

public enum DataClass { Public, Internal, Confidential, Restricted }
public enum PiiCategory { Pii, SensitivePii, Pseudonymous }
```

Usage example:

```
public sealed record Recipient(
    [Classification(DataClass.Restricted)]
    [PiiField(PiiCategory.Pii, Purpose = "notify:delivery")]
    string EmailAddress,

    [Classification(DataClass.Restricted)]
    [PiiField(PiiCategory.SensitivePii, Purpose = "billing:invoice")]
    string? TaxIdentifier,

    [Classification(DataClass.Confidential)]
    TenantId Tenant,

    [Classification(DataClass.Restricted)]
    [PiiField(PiiCategory.Pseudonymous, Purpose = "audit:correlation")]
    PrincipalId Subject
);
```

**Consumers of the attributes:**

- **Log scrubbers** in `HoneyDrunk.Observe.AzureMonitor` (per ADR-0040 D9's `LogRecordProcessor`) — reflect over emitted log payloads; any property carrying `[PiiField(Pii | SensitivePii)]` is replaced with a redaction marker (`***[email]`) before the Azure Monitor exporter ships the log line.
- **Audit redactor** in `HoneyDrunk.Audit` (per ADR-0030 D3) — on `AuditEntry` data-change emit, the `Before`/`After` payloads are walked; `[PiiField(Pii)]` fields become their pseudonymous-token form (D6); `[PiiField(SensitivePii)]` fields are replaced with a sentinel `[REDACTED:sensitive]`; `[PiiField(Pseudonymous)]` is emitted as-is. This makes Invariant 47's "sensitive field" mandate concrete and enforceable.
- **Error reporter** in `HoneyDrunk.Observe.AzureMonitor`'s `IErrorReporter` backing (per ADR-0045 D7) — exception context dictionaries and custom dimensions are walked; same scrubbing as logs.
- **Export jobs** (data-subject access requests, tenant data exports per ADR-0050) — `[PiiField]`-marked fields are inventoried into the export manifest so the operator can confirm completeness before delivery.
- **Test canaries** — every Node ships a redaction canary (per the PII-scrubbing canary follow-up named in ADR-0040 and ADR-0045) that constructs sample payloads with `[PiiField]`-marked fields, sends them through the log/audit/error paths, and asserts the output is properly redacted. A canary failure blocks the package release per ADR-0034.

**Why attributes and not naming convention:** naming conventions (`*Email`, `_pii_*`) are fragile — they fail on aliased types, on records reshaped at boundaries, and on transitive payloads inside `Dictionary<string, object>` bags. Attributes are reflection-discoverable, type-checkable by analyzers, and explicit at the point of declaration. The cost is a one-line annotation per field; the benefit is mechanical enforceability.

**Analyzer rule:** `HoneyDrunk.Analyzers` (the standard analyzer package consumed via `Directory.Build.props`) ships a rule that flags **unmarked properties on types in `Restricted`-classified contexts** — specifically, properties on records persisted by `HoneyDrunk.Data` repositories or shipped through `HoneyDrunk.Audit`'s `AuditEntry.DataChange`. Unmarked is an error; explicit `[Classification(DataClass.Public)]` is the way to opt out. This catches "developer added a new field and forgot to classify it" at compile time.

### D5 — Redaction at boundaries — extension of existing ADRs

This ADR does not re-litigate the redaction rules already committed by ADRs 0030, 0040, and 0045. It **extends** them by binding their previously-implicit "sensitive field" concept to the D4 marking mechanism. The boundary-by-boundary rules:

| Boundary | Existing rule | Extension from this ADR |
|----------|---------------|--------------------------|
| **Telemetry (traces)** | ADR-0040 D9: no prompt/completion/email/message body in trace attributes | Enforced by the `SpanProcessor` walking attribute payloads and dropping any `[PiiField(Pii \| SensitivePii)]`-marked dimension. The Evals carve-out (ADR-0040 D9) keeps its `evals.sensitive=true` exception. |
| **Telemetry (logs)** | ADR-0040 D9: same forbidden list | `LogRecordProcessor` walks structured log properties; `[PiiField]` triggers replacement with redaction marker. Unstructured log message templates are scanned by a fallback regex (emails, phone shapes, JWT shapes, card numbers) per ADR-0045 D7. |
| **Telemetry (errors)** | ADR-0045 D7: exception messages and custom dimensions stripped of common PII patterns | Extended: exception's `Data` dictionary and `ErrorContext.Tags` are walked; any key whose value type carries `[PiiField]` is redacted. The exception's `StackTrace` is **never** considered PII (stack frames are code, not data). |
| **Audit (`AuditEntry.DataChange`)** | ADR-0030 D3: "sensitive fields must be redacted before append" — undefined | **Defined** by D4: `[PiiField(Pii)]` → pseudonymous token; `[PiiField(SensitivePii)]` → `[REDACTED:sensitive]`; `[PiiField(Pseudonymous)]` → as-is. The Audit Node's append path runs the redactor unconditionally; emitters that submit pre-walked `Before`/`After` may also do so, but the Audit Node defends in depth. |
| **Audit (`AuditEntry.Metadata`)** | ADR-0030 D3 (implicit) | The `Metadata` dictionary is walked for `[PiiField]` markers via boxed-value reflection; values that present as raw strings without source-type metadata fall through and are emitter-responsibility. |
| **Export jobs / DSAR** | None | New: export jobs reflect over all `[PiiField]`-marked fields belonging to the subject's `PrincipalId`; the export manifest lists each field by name, classification, and source Node. This is the **inverse** of redaction — exports must be complete, not scrubbed. |
| **Cross-sector message envelopes (Transport)** | ADR-0028 (implicit) | Message bodies crossing a sector boundary must declare their classification in the envelope header. Restricted-class messages crossing a Confidential-only boundary fail validation at the broker layer. |
| **NuGet package contents** | ADR-0034 (implicit) | Source code and package contents are Public by construction; the analyzer rule (D4) catches accidentally committed test fixtures with realistic PII. |

The **defense-in-depth principle** matters: redaction is enforced both at the emitter (where the developer has type knowledge) and at the boundary (where the framework has reflection knowledge). Neither alone is sufficient; either alone, plus the analyzer rule, would leak on misuse.

### D6 — Right to erasure: policy principle, mechanics in ADR-0050

GDPR Article 17, UK-GDPR Article 17, CCPA 1798.105, and the Florida Digital Bill of Rights all grant a data subject the right to request erasure of their personal data. The mechanics of how a tenant or consumer-app user submits this request, how the request is routed, and how the Studio confirms completion are **ADR-0050's scope** (Tenant Lifecycle). This ADR commits the **policy principle** that ADR-0050 must implement against.

**The audit-append-only conflict.** ADR-0030 D4 mandates append-only-by-interface — there is no `Delete` method on `IAuditLog`. An erasure request that deleted the audit record would violate this. The Grid resolves the conflict via **pseudonymous tokens in the audit record + a separately-erasable PII↔token map**:

- **`AuditEntry.Actor` and `AuditEntry.Target`** carry `PrincipalId` and `TenantId` (pseudonymous identifiers per D2), never raw email addresses or names.
- The **`PrincipalId` ↔ identity map** (email, name, profile data) lives in the per-Node identity store (`HoneyDrunk.Auth`'s user store for Studio products; the per-app onboarding store for consumer products per the relevant PDR), which is `Restricted`-classified and supports per-record erasure.
- On erasure: the identity-store row is deleted; the audit record retains the `PrincipalId` token, which now resolves to **nothing**. The audit history "user did X at time T" remains intact and forensically useful; the PII binding "this user was alice@example.com" is gone.
- `[PiiField(Pii)]` fields in `AuditEntry.Metadata` and `AuditEntry.DataChange.Before/After` are stored **as pseudonymous tokens at emit time** (D5), not as their raw values. The token-to-value map sits in the same erasable identity store. Same erasure mechanic.

This pattern is the resolution to the long-standing "GDPR says delete, audit says never delete" tension. The audit record contains no personal data **after** erasure; the audit record contained no personal data **before** erasure either (it always contained tokens). The change is solely in the identity store.

**The exception:** `[PiiField(SensitivePii)]` fields are **never** emitted to the audit channel even as tokens. Article 9 special-category data cannot appear in the audit record's data-change body at all; the audit entry records *that* a Sensitive PII field was changed (field name, classification, source Node), not the values. This is stricter than the `Pii` case and is mandatory.

ADR-0050 will commit: the request-receipt channel (email? portal? both?), the operator-acknowledgment SLA (15 days max per GDPR), the per-Node deletion orchestration, the verification-of-deletion procedure, and the backup-window communication to the data subject.

### D7 — Data residency: Azure US East at v1

The v1 Grid is hosted entirely in **Azure US East 2** (the existing single-region posture per ADR-0029's implicit choice). All Confidential and Restricted data — including tenant data, user PII, audit records, telemetry, backups — resides in US East 2 at v1.

**The implications for EU/UK data subjects:**

- The Studio is the data controller (or processor, depending on the product) for EU/UK personal data hosted in the US.
- Under GDPR/UK-GDPR, this is a "transfer to a third country" requiring an Article 46 mechanism. The Studio uses the EU **Standard Contractual Clauses (2021 module 2 controller-to-processor; module 4 processor-to-controller as applicable)** plus the UK ICO's International Data Transfer Addendum.
- The Data Processing Agreement (DPA) template referenced by ADR-0036 D7 and not yet authored must incorporate SCCs by reference. This is a **deferred follow-up** of this ADR.
- The Studio publishes a **Transfer Impact Assessment (TIA)** for the US East 2 hosting choice; v1 TIA asserts US adequacy via the EU-US Data Privacy Framework (DPF) certification, conditional on the Studio enrolling in DPF. DPF enrollment is a **follow-up** (annual $250 fee + compliance attestation); until enrolled, the Studio relies on SCCs alone.

**Non-US tenancy requires a future ADR.** A tenant requirement for EU-hosted data, Australian-hosted data, or any other residency posture forces a multi-region architecture decision (data plane partitioning, cross-region replication semantics, per-region Vault). That decision is large enough to be its own ADR and is **out of scope here**. v1 commits the single-region US posture; subsequent ADRs may amend.

**Within the US**, the Florida nexus (per BDR-0001) makes FIPA the applicable state breach-notification statute; Florida Digital Bill of Rights' effective date (2026-07-01) introduces the access/correction/deletion/portability rights at the threshold the Studio does not currently cross. The Studio commits to honoring those rights even below the threshold as a posture choice; the cost of doing so is bounded by D6's mechanics existing anyway for GDPR purposes.

### D8 — Owners and reviewers

**Classification assignment is the responsibility of the field's author.** Every PR adding a new persisted field, a new `AuditEntry` payload shape, a new API request/response field, or a new telemetry attribute must apply `[Classification]` and (if applicable) `[PiiField]` at the point of declaration. The analyzer rule (D4) catches omissions; the reviewer catches mis-classifications.

**Review duties:**

- The generalist **`review` agent** (per ADR-0044 D3 category 9 Security) flags missing or visibly-wrong classifications as part of every PR review. This is a low-precision first pass.
- The specialist **`security` agent** (per ADR-0046 D2) is invoked for any PR touching:
  - A new `[PiiField]` declaration of category `SensitivePii`.
  - A change to a field's classification (downgrade Restricted → Confidential is a red flag; promotion is fine).
  - A new boundary that handles Restricted-class data (a new HTTP endpoint, a new message envelope shape, a new audit event family).
  - A new Node that will store user-attributable data (consumer-app standup PDRs).
- The specialist **`database` agent** (named as a follow-up candidate per ADR-0046 D9; promoted to v1 roster by this ADR's follow-up work) is invoked for any PR touching:
  - SQL project/DACPAC schema changes on `HoneyDrunk.Data`-backed stores.
  - Index design on PII-bearing tables (an index on `email` makes erasure easier; a composite index that locks in field placement makes it harder).
  - Retention-policy configuration changes on Cosmos containers, App Insights workspaces, or storage accounts.

**The `security` and `database` agents author packets and ADRs upstream too**, per ADR-0046 D5 (upstream-awareness). A consumer-app PDR (PDR-0003 et al.) progressing to `scope`-driven packets is a `security`-agent moment: the rubric is whether the packet adequately commits to the D1–D6 disciplines before code is written.

**The Studio operator is the final approver** for any PR that downgrades a field's classification, that introduces a new SensitivePii field, or that changes the retention policy on a regulated-class data store. None of these can land on agent approval alone.

### D9 — Inventory artifact: `catalogs/data-classification.json`

Field-level classification lives near the code (D4); Grid-wide visibility requires a catalog. A new file at `catalogs/data-classification.json` enumerates, per Node, the public surface that carries classified data — the contracts (per `catalogs/contracts.json`) that pass through Restricted-class fields, the audit-emit shapes, the API request/response shapes, the persisted-record types.

The catalog does not duplicate every field of every record — that would be both unmaintainable and redundant with the source-of-truth code. It declares the **summary surface**: which contracts touch which classification tiers, which PII categories are present per Node, what the highest-classification fanout looks like across the Grid.

Schema sketch:

```
{
  "version": "1.0",
  "generated_at": "2026-05-22T00:00:00Z",
  "nodes": {
    "HoneyDrunk.Notify": {
      "highest_classification": "Restricted",
      "pii_categories": ["Pii"],
      "sensitive_pii": false,
      "contracts": [
        { "name": "INotifyDispatcher.SendAsync", "request_class": "Restricted", "fields": ["RecipientEmail:Pii"] },
        { "name": "AuditEntry(NotifySent)", "class": "Confidential", "fields": ["RecipientPrincipalId:Pseudonymous"] }
      ],
      "stores": [
        { "name": "DeliveryAttempts", "class": "Restricted", "retention_class": "tenant-active" }
      ]
    }
    // ... per Node
  }
}
```

`hive-sync` (per ADR-0014) reconciles the catalog against the source code's `[Classification]` and `[PiiField]` attributes on every nightly run, treating drift as a finding. The catalog is the operator's "where does PII flow in my Grid" surface; it answers the question that today requires reading every Node's source code.

The catalog **does not** carry per-record retention configuration (that lives in the per-Node deployment configuration) or per-tenant deviations (that lives in the tenant contract / BDR record). It is a Grid-wide classification overview, not a Grid-wide policy engine.

### D10 — Phased rollout

- **Phase 1 (Week 1–2) — Attributes and analyzer.** Author `[Classification]`, `[PiiField]`, `DataClass`, `PiiCategory` in `HoneyDrunk.Kernel.Abstractions`. Author the analyzer rule. Ship as part of `Kernel` v0.8.0. Existing fields are `[Classification(DataClass.Internal)]` by default (compatibility); the analyzer surfaces unclassified surface as warnings, not errors, for the first 30 days.
- **Phase 2 (Week 2–4) — Backfill existing Nodes.** Walk every persisted record type, every `AuditEntry` shape, every API contract across the live 12 Nodes; apply correct classifications. The `security` specialist drives this Node-by-Node; the `scope` agent authors per-Node packets.
- **Phase 3 (Week 3–4) — Redactor integrations.** Wire the attribute-aware redactor into `HoneyDrunk.Observe.AzureMonitor`'s `LogRecordProcessor` and `IErrorReporter` backing. Wire the attribute-aware redactor into `HoneyDrunk.Audit`'s append path. Ship the PII-scrubbing canaries that were follow-ups of ADR-0040 and ADR-0045.
- **Phase 4 (Week 4–6) — Catalog and `hive-sync` reconciliation.** Author `catalogs/data-classification.json` schema; populate from the Phase 2 backfill output; wire `hive-sync` reconciliation rule. Flip the Phase 1 analyzer warnings to errors at the 30-day mark.
- **Phase 5 (Month 2–3) — DPA, TIA, DPF.** Author the DPA template incorporating SCCs (closes the ADR-0036 D7 deferred work). Author the v1 TIA. Enroll in EU-US Data Privacy Framework (operator action; $250/year). These are the **commercial/legal artifacts** that the architectural decisions in this ADR enable; without them, the architecture commitments are unprovable to a customer.
- **Phase 6 (When PDR-0003/0005/0006/0008 standup begins) — Consumer-app onboarding stores.** Each consumer-app PDR's `scope`-driven packet wires its onboarding store as Restricted-class, applies the D4 attributes from day one, registers itself in `catalogs/data-classification.json`. The standup canary includes a redaction-canary surface (validates that the onboarding flow produces correctly-classified records).

Each phase is a discrete go/no-go.

### D11 — Relationship to ADR-0030, ADR-0036, ADR-0040, ADR-0045, ADR-0046, ADR-0050

- **ADR-0030** — extended. ADR-0030 D3 mandates "sensitive fields must be redacted before append" without definition; D4 of this ADR defines them and D5 binds the audit append path to the attribute-aware redactor.
- **ADR-0036** — extended. ADR-0036 D7 deferred the data-subject-deletion / backup-retention reconciliation; D3 of this ADR commits the retention schedule and D6 commits the erasure policy that, with ADR-0050, closes the deferred work.
- **ADR-0040** — extended. ADR-0040 D9 lists forbidden PII patterns in observability; D5 of this ADR binds those patterns to the field-marking discipline and adds the analyzer + canary enforcement.
- **ADR-0045** — extended. ADR-0045 D7 defers PII rules to ADR-0040 D9; D5 of this ADR makes both concrete via the attribute-aware redactor.
- **ADR-0046** — extended. ADR-0046 D2's `security` specialist gains a canonical rubric (D8 of this ADR); the `database` specialist is promoted from D9 follow-up candidate to v1 roster as a consequence.
- **ADR-0050 (sibling, not yet authored)** — depends on this ADR. ADR-0050's tenant-lifecycle mechanics (create / suspend / export / delete) implement against the classification taxonomy (D1), the PII sub-taxonomy (D2), the erasure policy principle (D6), and the inventory catalog (D9) that this ADR commits.
- **Invariant 47** — extended. The "sensitive field" reference becomes concrete: a sensitive field is one marked `[PiiField(SensitivePii)]` per D4. The invariant text is amended to reference this ADR.

## Consequences

### Affected Nodes

- **HoneyDrunk.Kernel** — gains `[Classification]`, `[PiiField]`, `DataClass`, `PiiCategory` in `HoneyDrunk.Kernel.Abstractions`. Version bump to 0.8.0.
- **HoneyDrunk.Analyzers** (existing analyzer package) — gains the unmarked-field analyzer rule.
- **HoneyDrunk.Observe** — `HoneyDrunk.Observe.AzureMonitor`'s `LogRecordProcessor` and `IErrorReporter` backing extended to consume the attributes for redaction.
- **HoneyDrunk.Audit** — append path extended to walk `AuditEntry.DataChange` and `AuditEntry.Metadata` payloads against the attributes; sensitive-PII-in-audit becomes a hard rejection at the append surface.
- **HoneyDrunk.Notify, HoneyDrunk.Notify.Cloud (future), HoneyDrunk.Communications, HoneyDrunk.Vault, HoneyDrunk.Data, HoneyDrunk.Auth** — Phase 2 backfill applies attributes to every persisted/transmitted field. Net code change is small (annotations) but the surface is broad.
- **HoneyDrunk.Memory, HoneyDrunk.Knowledge** (AI-sector, Seed) — standup ADRs (ADR-0022, ADR-0021) gain a classification rubric requirement; their first canaries include the redaction surface.
- **Consumer-app Nodes** (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0008 Curiosities) — Phase 6 onboarding stores wired correctly from day one. **PDR-to-scope blockage cleared.**
- **HoneyDrunk.Architecture** — `catalogs/data-classification.json` added; `catalogs/contracts.json` gains classification annotations on contracts; `constitution/invariants.md` amends Invariant 47 to reference this ADR.
- **HoneyDrunk.Studios** (this repo's Studio operations) — `business/` gains the DPA template, the TIA template, and the DPF enrollment artifact location after Phase 5.

### Invariants

Amends one and adds three:

- **Amends Invariant 47.** The phrase "sensitive fields" becomes ", as defined by ADR-0049 D2 (`[PiiField(SensitivePii)]`),". Otherwise unchanged. The Audit-append redaction mandate is preserved and made enforceable.
- **Adds: every persisted field, every public API contract field, and every `AuditEntry` payload field carries a `[Classification]` attribute.** Unmarked fields on records inside Restricted-class contexts are a CI gate failure (analyzer rule per D4).
- **Adds: `[PiiField(SensitivePii)]`-marked fields never appear in the audit channel, even as redaction-tokens.** The Audit Node rejects appends whose `Before`/`After` payload reflection surfaces a `SensitivePii` marker. Only the field-name-and-class metadata may appear.
- **Adds: Restricted-class data never leaves the v1 Azure US East 2 region.** Cross-region replication for backups (per ADR-0036 D2 geo-redundant storage choices) stays within the US Azure footprint. Any Node that needs non-US storage forces an ADR amendment.

(Final invariant numbering assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **Phase 2 backfill is the largest one-time cost.** Annotating every persisted/transmitted field across 12 live Nodes is mechanical but broad. Per-Node packets via the `scope` agent are the execution mechanism; the `security` specialist reviews the Node-by-Node classification outputs.
- **The analyzer rule will surface unclassified surface as warnings for 30 days, errors after.** Some Nodes will discover fields they should not have been storing at all (e.g., a debug field capturing a full request body). That is a *finding*, not a regression; treat as such.
- **The pseudonymous-token-at-audit-emit pattern (D6) requires the per-Node identity store to support `PrincipalId` lookup at audit-emit time.** For most Nodes this is trivial (the user is already known via `IGridContext` per ADR-0026). For non-tenant-attributable audit events (system actions, scheduled jobs), the actor is the Node's managed identity, which is itself a pseudonymous identifier with no PII binding.
- **DPF enrollment is annual paperwork ($250).** The operator owns this; missing the enrollment renewal does not break the architecture but does invalidate the TIA's adequacy argument.
- **Consumer-app PDRs unblocked.** The four PDRs (0003, 0005, 0006, 0008) can now move to `scope`-driven packet generation with a canonical classification scheme. This is the load-bearing operational unblock.
- **The classification catalog (D9) becomes the "where is my PII" answer.** Operator-facing visibility into Restricted-data fanout was previously only available by reading source code; now it's a single JSON file.
- **DPA/TIA artifacts are commercial requirements, not architectural.** They are named here because the architecture commitments enable them, but their authoring is operator work. A signed enterprise contract that requires a DPA will block on Phase 5 completion if it precedes it.
- **Florida Digital Bill of Rights (2026-07-01) compliance is free** if D6 mechanics are in place, because Florida's rights are a subset of GDPR's that the architecture supports anyway.

### Follow-up Work

- Add `[Classification]`, `[PiiField]`, `DataClass`, `PiiCategory`, and supporting types to `HoneyDrunk.Kernel.Abstractions` (Phase 1).
- Author the unclassified-field analyzer rule in `HoneyDrunk.Analyzers` (Phase 1).
- Per-Node backfill packets via `scope` agent (Phase 2; one packet per Node).
- Extend `HoneyDrunk.Observe.AzureMonitor`'s `LogRecordProcessor` and `IErrorReporter` backing with attribute-aware redaction (Phase 3).
- Extend `HoneyDrunk.Audit`'s append path with attribute-aware redaction and SensitivePii rejection (Phase 3).
- Ship the PII-scrubbing canaries deferred from ADR-0040 and ADR-0045 (Phase 3).
- Author `catalogs/data-classification.json` schema and initial population (Phase 4).
- Wire `hive-sync` reconciliation rule for the catalog (Phase 4).
- Author the DPA template incorporating SCCs (Phase 5; closes ADR-0036 D7 deferred work).
- Author the v1 Transfer Impact Assessment (Phase 5).
- Operator action: enroll in EU-US Data Privacy Framework (Phase 5).
- Promote the `database` specialist agent from ADR-0046 D9 candidate to v1 roster; author `.claude/agents/database.md` (Phase 4–5).
- Update `constitution/invariants.md` with the Invariant 47 amendment and three new invariants.
- Update `.claude/agents/security.md` with the canonical D1–D6 rubric.
- Update `.claude/agents/review.md` D3 category 9 with the classification-completeness checklist.
- Open sibling ADR-0050 (Tenant Lifecycle) which consumes this ADR's policy principle for its mechanics.

## Alternatives Considered

### Classify ad-hoc per Node (the status quo)

Considered. Today every Node makes its own implicit decisions about what is PII, what gets redacted, how long to keep things. Rejected because:

- **Invariant 47 is unenforceable without a canonical definition.** The status quo means the invariant is decorative; the redaction discipline is whatever each Node's author chose to implement.
- **The four consumer-product PDRs cannot proceed.** Each would invent its own classification, the drift would compound, and a Grid-wide reconciliation later would be a migration not a refactor.
- **Audit redaction is already broken at the boundary.** ADR-0030 D3 mandates "redact sensitive fields" against an undefined concept of sensitive; the audit substrate is appending whatever emitters submit, with no defense in depth.
- **Regulatory exposure scales with per-Node drift.** A GDPR erasure request that lands on the Studio today has no defined fulfillment path; the response would be improvised.

The status quo is the explicit "drift wins" option. Rejected as the foundational reason for this ADR.

### Three-tier classification (Public / Internal / Confidential) without a Restricted tier

Considered. Some organizations use a three-tier model where PII sits within Confidential. Rejected because:

- The handling rules for tenant-attributable operational data (Confidential) and for user PII (Restricted) are **materially different** — different storage rules, different observability rules, different retention rules, different erasure obligations. Conflating them under one tier means the rules either over-protect operational data or under-protect PII.
- Audit-channel rules specifically diverge: Confidential data is fine in audit records; Restricted requires the pseudonymous-token pattern. A three-tier scheme has nowhere clean to encode this.

The four-tier model is the minimum granularity that admits the necessary distinctions.

### Five-tier classification (add Public / Internal / Confidential / Restricted / Top-Secret)

Considered. Some defense-aligned schemes use a fifth tier above Restricted. Rejected because the Grid does not currently handle data that meaningfully exceeds Restricted (Sensitive PII per Article 9 is the highest sensitivity in scope). Adding a tier without a clear distinction produces classification ambiguity; deferred to a future ADR amendment if-and-when the Grid acquires a use case (e.g., government contracts, secrets-protection regimes).

### Naming-convention-based field marking (`*Email`, `_pii_*`) instead of attributes

Considered. Cheaper to retrofit (no Kernel change). Rejected because:

- **Fragile under refactoring.** Aliased types, records reshaped at boundaries, transitive payloads inside `Dictionary<string, object>` all defeat naming conventions.
- **Not analyzer-checkable in a meaningful way.** A naming convention can be linted but cannot express "the value of this property is PII regardless of name."
- **Doesn't survive serialization round-trips.** The same datum serialized to JSON and rehydrated loses the naming intent at the type system level.

Attributes are reflection-discoverable, declarative, type-aware. The marginal cost (one annotation per field) is bounded; the structural benefit is large.

### Central registry of classifications outside the code

Considered (a centralized YAML or JSON file declaring which fields of which types are classified at which tier). Rejected because:

- **Drift between code and registry is inevitable.** Adding a new field in code requires remembering to update the registry; the registry is not where the developer is working.
- **No analyzer enforcement at compile time.** Drift is detected only at runtime, by which point the field may have shipped.
- **The catalog in D9 is the right place for Grid-wide visibility**, but the per-field declaration belongs in the code.

The split (attributes in code, catalog summary in this repo) is the right shape.

### Defer right-to-erasure mechanics entirely to ADR-0050 (no policy principle here)

Considered. ADR-0050's scope is large enough to make a clean separation easy. Rejected because the **audit-append-only conflict is a policy question, not a mechanics question.** The decision to resolve it via pseudonymous tokens at audit-emit time has to be committed here so that the audit-redactor work (Phase 3) and the per-Node identity-store design constraints (Phase 6) are correctly scoped. Leaving the conflict to ADR-0050 would force ADR-0050 to retrofit changes onto Audit Node code that this ADR's Phase 3 already shipped.

The split: this ADR commits the **principle** (pseudonymous-token-in-audit, PII-in-erasable-store); ADR-0050 commits the **operational mechanics** (request channel, SLA, per-Node deletion orchestration, verification).

### Adopt SOC 2 Type II's retention floor (7 years for all audit data)

Considered. The conservative regulatory floor. Rejected for non-T0 audit data because:

- **Cost grows linearly with retention.** Storing 7 years of T1/T2 audit logs costs ~3.5× storing 2 years.
- **Forensic value decays.** The marginal forensic value of a 6-year-old non-financial audit record is low; the marginal cost of storing it is non-zero.
- **GDPR storage-limitation principle (Article 5(1)(e))** cuts against indefinite retention without a stated purpose. Two years is the documented floor for incident reconstruction; 7 years is justified only for the regulated-financial use cases T0 anticipates.

The split (T0 = 7 years, T1/T2 = 2 years) is the cost/risk balance.

### Multi-region data residency from v1

Considered. Several enterprise tenants will require EU-hosted data. Rejected as out-of-scope here because:

- **The Grid is single-region today.** Multi-region is a large architectural decision (data plane partitioning, cross-region replication semantics, per-region Vault) and properly its own ADR.
- **SCCs + DPF (D7) provide a lawful basis for v1 single-region US hosting** for EU/UK data subjects.
- **No current tenant contract requires non-US hosting.** The first such contract triggers the multi-region ADR.

Recorded as a known future ADR. v1 commits the single-region posture with the legal-instrument fallback.

### Adopt a third-party data-classification tool (BigID, OneTrust, Privacera)

Considered. Mature commercial tooling exists for data-classification scanning, DSAR automation, and DPA management. Rejected at v1 because:

- **Cost.** All three are enterprise-priced ($30K+/year minimum) — order-of-magnitude over the entire current Grid observability + DR + audit budget combined.
- **Surface area mismatch.** These tools are designed for large legacy data estates with hundreds of tables across heterogeneous backings. The Grid's surface fits in a single JSON catalog and a small set of attribute declarations.
- **Vendor relationship overhead.** Per the cost-aware pattern of ADR-0040 / ADR-0045 / ADR-0046, adding a vendor is a deliberate decision; one is not warranted here.

Reconsidered when the Grid's data surface or the regulatory exposure (e.g., entering healthcare or financial-services markets) justifies the spend.
