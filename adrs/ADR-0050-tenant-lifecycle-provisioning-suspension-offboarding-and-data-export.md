# ADR-0050: Tenant Lifecycle: Provisioning, Suspension, Offboarding, and Data Export

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has tenancy *primitives* and tenancy *aspirations*, but no committed tenancy *lifecycle*. The gap is no longer theoretical — multiple downstream decisions are blocked on it.

What exists today:

- **ADR-0026 (Tenancy Primitives, Accepted)** defines `TenantId` as a 26-character ULID prefixed `tnt_`, the internal `tnt_internal` sentinel for first-party Grid work, intake mechanics for inbound `tenant.id` headers, and the boundary-plumbing rules for propagating `tenant.id` across HTTP, Service Bus, audit, and Observe contexts. **ADR-0026 explicitly stops at the boundary plumbing.** The questions of how a `TenantId` comes into being, what states it can be in, who can change those states, and what happens when it goes away are deferred — to "a future tenant-lifecycle ADR." This is that ADR.
- **ADR-0006 (Per-Node Key Vaults)** establishes that each Node has its own Key Vault and that tenant-scoped secrets are namespaced inside it. Provisioning a tenant implies provisioning (or partitioning into) those Vault namespaces, but the *when*/*how* is undefined.
- **ADR-0019 (Communications boundary refactor)** moves orchestration out of Notify into `HoneyDrunk.Communications`. Tenant-lifecycle workflows are orchestration by any reasonable definition; the ADR did not yet have a customer to orchestrate for, so the slot stayed empty.
- **ADR-0030 (Grid-Wide Audit Substrate, Accepted)** commits to an append-only-by-interface audit log with 730-day retention per ADR-0040 D3. Tenant lifecycle events (created, suspended, offboarded, erased) are first-class audit events. Crucially, **audit is append-only.**
- **ADR-0031 (Audit Standup, Proposed)** carries the implementation work for the Audit Node.
- **ADR-0036 (DR Tiers)** classifies tenant data as Tier 0 / Tier 1 depending on Node. RPO/RTO commitments to tenants don't exist until tenants exist.
- **ADR-0042 (Idempotency Contract, Proposed)** introduces `IIdempotencyStore`. Lifecycle workflows must be idempotent end to end — re-running provisioning must not double-allocate quota or double-bill.
- **ADR-0049 (Tenant Data Isolation, Proposed)** decides the per-tenant partition/schema model. Provisioning instantiates a partition; offboarding deletes one. The two ADRs interlock.
- **Invariant 47 (Audit is append-only by interface)** forbids deletion paths through any `IAuditWriter` surface. There is no `DeleteAuditRecord(...)` and there will never be one.

The forcing functions for deciding this now:

- **ADR-0027 (Notify.Cloud, Proposed)** presumes paying tenants exist. The ADR cannot move past Proposed without a definition of how a paying tenant comes into being and how one stops being one.
- **ADR-0037 (Billing, Proposed)** presumes a subscription lifecycle — `trialing`, `active`, `past_due`, `unpaid`, `canceled` — and a `HoneyDrunk.Billing` Node that doesn't exist yet. Subscription state must map onto Grid tenant state, and the mapping is undefined.
- **PDR-0002 (Notify.Cloud commercial offering)** is explicitly blocked on this ADR. Pricing, packaging, and sales motion all depend on knowing what "a customer" is operationally.
- **GDPR Article 17 / CCPA right-to-delete are statutory.** The first EU-resident user who exercises right-to-erasure cannot be answered with "the audit substrate is append-only, sorry." The collision between **Invariant 47 (audit is append-only)** and **GDPR Art. 17 (data must be erased on request)** is the central architectural decision in this ADR. It cannot be deferred to a future ADR because the deferral itself is non-compliant — GDPR requires that the erasure path be designed in, not retrofitted.
- **The first prospect for Notify.Cloud is in conversation.** Operationally, we need a way to take their money and provision them in the next 60 days.

This ADR commits the tenant lifecycle as an enumerated state machine, the v1 provisioning model (self-serve sign-up with manual approval gate), the orchestration boundary (a workflow in `HoneyDrunk.Communications`), the suspension and offboarding semantics, the data export contract, and — most importantly — the **pseudonymization-based resolution to the GDPR vs append-only collision** (D6).

## Decision

### D1 — The tenant state machine

Tenants exist in exactly one of seven enumerated states. Transitions are explicit, audited, and initiated by named actors.

| State | Description | Billing | API access | Data access | Audit ingest |
|-------|-------------|---------|------------|-------------|--------------|
| **Prospect** | Pre-signup record. Created when a lead submits the Notify.Cloud interest form or is added by ops. No tenant ID yet — held as a `prospect_id`. | None | None | None | N/A |
| **Trialing** | Provisioned tenant inside the trial window (default 14 days). Full feature access, capped quotas. | Stripe `trialing` subscription, no charges | Full (within quota) | Full | Yes |
| **Active** | Paying tenant in good standing. | Stripe `active`, monthly invoice posted | Full (within plan quota) | Full | Yes |
| **PastDue** | Payment failed; grace period in effect (default 7 days). | Stripe `past_due`, retries scheduled | Full | Full | Yes |
| **Suspended** | Grace period exceeded, or tenant manually suspended for ToS violation. | Stripe `unpaid` or paused | Rejected (`HTTP 402 Payment Required` for payment-driven; `HTTP 403 Forbidden` for ToS-driven) | Read-only via support workflow only | Yes (required for compliance) |
| **Offboarding** | Tenant or ops initiated termination; in 30-day grace window before purge. | Subscription canceled, no further invoices | Rejected (`HTTP 410 Gone`) | Read-only export window | Yes |
| **Closed** | Grace window elapsed; tenant data hard-deleted (per D6 pseudonymization model). | Closed | Permanent `HTTP 410 Gone` | None | Audit retains pseudonymous tokens only |

Valid transitions form a directed graph (cycles are deliberate where re-instatement is allowed):

```
Prospect ──approve──> Trialing ──convert──> Active
                          │                    │
                          │                    ├──payment_fail──> PastDue ──cure──> Active
                          │                    │                       │
                          │                    │                       └──grace_exceeded──> Suspended
                          │                    │
                          │                    ├──tos_violation──> Suspended
                          │                    │
                          │                    └──customer_request──> Offboarding
                          │
                          └──trial_expired_no_convert──> Offboarding

Suspended ──reinstate──> Active        (ops-initiated, e.g., payment recovered or appeal upheld)
Suspended ──escalate──> Offboarding    (ops-initiated, terminal path)
Offboarding ──t+30──> Closed           (automatic, scheduled)
Closed                                  (terminal)
```

The initiator of each transition is recorded in the audit event:

| Transition | Initiator | Mechanism |
|------------|-----------|-----------|
| `Prospect → Trialing` | Ops (manual approval per D2) | Studios admin console |
| `Trialing → Active` | Customer (self-serve) or billing webhook | Stripe `customer.subscription.updated` |
| `Active → PastDue` | Billing webhook | Stripe `invoice.payment_failed` |
| `PastDue → Active` | Billing webhook | Stripe `invoice.payment_succeeded` |
| `PastDue → Suspended` | Scheduled job | After grace window (default 7d) |
| `Active → Suspended` | Ops | ToS enforcement, manual |
| `Suspended → Active` | Ops | Reinstatement, manual |
| `Active → Offboarding` | Customer (self-serve) or ops | Customer support form or Studios admin console |
| `Suspended → Offboarding` | Ops | Escalation, manual |
| `Trialing → Offboarding` | Scheduled job | Trial expired without conversion |
| `Offboarding → Closed` | Scheduled job | T+30 from offboarding entry |

State is persisted in the `HoneyDrunk.Billing` Node (per ADR-0037, once standup completes) with a read-replica view in `HoneyDrunk.Auth` for fast access-check decisions. Until Billing is scaffolded, state lives in a `Tenants` table in `HoneyDrunk.Auth` as the interim home; the Billing-standup ADR-0037 packet picks up the migration.

### D2 — Provisioning model (v1): self-serve sign-up with manual approval

Three candidate models were considered:

| Model | Friction | Abuse risk | Ops load | Verdict |
|-------|----------|------------|----------|---------|
| **Ops-driven** (no self-serve) | Highest | Lowest | Highest | Rejected — does not scale past the first 5 customers |
| **Self-serve + manual approval** | Medium | Low | Low (one approval click per signup) | **Selected for v1** |
| **Pure self-serve auto-provision** | Lowest | Highest (spam signups, prompt-injection abuse, free-tier mining) | Lowest | Deferred to a follow-up ADR after Notify.Cloud has 50+ paying tenants and abuse-detection signal is calibrated |

**v1 commitment:** prospective customers submit a sign-up form (email, company, intended use case, expected volume). The submission creates a `Prospect` record and emits a notification to ops. An ops operator (the developer, in practice) reviews the prospect — checks for obvious abuse signals, validates the use case against ToS, optionally requests a brief intro call — and either approves (transitioning to `Trialing` and triggering D3) or rejects (with a reason recorded in audit).

The manual gate is justified by:

- **Low expected v1 volume.** Notify.Cloud is targeting design-partner and small-team customers in the first 6 months. Approval load is < 5/week.
- **High abuse risk.** A notification API with free credits is a phishing-launch platform if abused. Manual review at signup is meaningfully cheaper than reactive abuse handling and brand reputation damage post-incident.
- **Reversibility.** Auto-provision can be enabled later (a follow-up ADR, after abuse-detection signal is calibrated) by removing the approval gate. Going the other way — pulling back from auto-provision to manual — is reputationally costly. Start conservative.

The Stripe Checkout signup form (per ADR-0037 D-?) handles payment-method capture at the trial-start moment (no charge during trial, but card on file). This is itself an abuse deterrent.

### D3 — Provisioning steps (idempotent, ordered, with failure recovery)

Approval triggers a workflow that executes these steps. Each step is **idempotent per ADR-0042's `IIdempotencyStore` contract** — re-running the workflow with the same `prospect_id` produces the same `tenant_id` and the same downstream artifacts without double-allocating.

| # | Step | Owner Node | Idempotency key | Cross-ref |
|---|------|------------|-----------------|-----------|
| 1 | Allocate `TenantId` (26-char ULID, `tnt_` prefix) | Auth | `provision:{prospect_id}:tenant_id` | ADR-0026 |
| 2 | Create tenant Key Vault namespace (or partition into shared Vault per D-? policy) | Vault | `provision:{tenant_id}:vault` | ADR-0006 |
| 3 | Provision Auth tenant scope (tenant record, RBAC scope root) | Auth | `provision:{tenant_id}:auth_scope` | ADR-0006 |
| 4 | Assign initial owner role to signup user | Auth | `provision:{tenant_id}:owner_role:{user_id}` | ADR-0006 |
| 5 | Provision per-tenant data partition (per ADR-0049 isolation model) | Data | `provision:{tenant_id}:partition` | ADR-0049 |
| 6 | Allocate Notify quota record (plan defaults from Billing) | Notify | `provision:{tenant_id}:quota` | ADR-0027 |
| 7 | Create billing customer + subscription (Stripe `customer.create` + trial subscription) | Billing | `provision:{tenant_id}:billing` | ADR-0037 |
| 8 | Emit `TenantProvisioned` event to Audit | Communications | `provision:{tenant_id}:audit` | ADR-0030 |
| 9 | Send welcome email with portal credentials and getting-started link | Communications → Notify | `provision:{tenant_id}:welcome_email` | ADR-0019 |

**Failure recovery:** the workflow is hosted by `HoneyDrunk.Communications` per D8 and uses a durable workflow primitive (the orchestrator runtime, choice deferred to the Communications standup work — Dapr Workflow and Azure Durable Functions are the two candidates). Step failure halts the workflow; the durable state lets operators re-trigger from the failing step. Steps before the failure are not re-executed (they're idempotent if they were, but they're not re-invoked) — the workflow resumes from the failed step.

A `provision_failed` state on the `Prospect` record is set if all retries exhaust; ops gets a notification and decides whether to manually unblock or roll back. **Rollback (steps 1–8) is supported** via a sibling `DeprovisionPartial` workflow; step 7's Stripe customer is left in place (Stripe records are cheap and don't violate any contract).

The workflow's correlation ID is the `prospect_id` for steps 1–4 and the `tenant_id` for steps 5–9. All steps emit OTLP spans into the same trace per ADR-0040.

### D4 — Suspension semantics

Suspension is a **read-restrict, write-block, audit-continue** posture. Specifically:

| Subsystem | Suspended behavior | Rationale |
|-----------|--------------------|-----------|
| **API calls (write)** | Rejected. `HTTP 402 Payment Required` for payment-driven suspension; `HTTP 403 Forbidden` for ToS-driven suspension. Response body carries a structured `suspension_reason` code and a support contact link. | The status code communicates remediation path to the calling system without leaking sensitive reason details to opportunistic probes. |
| **API calls (read)** | Same rejection by default. **Exception:** a narrow "read-only support workflow" path (ops-initiated, audited) lets support pull tenant data on the tenant's behalf — e.g., to produce a final report before offboarding. | Customers locked out of read paths for billing reasons sometimes legitimately need to retrieve their own data to cure the issue. The ops-mediated path balances "no free use during suspension" against "we're not holding their data hostage." |
| **Data access (tenant's own portal)** | Blocked at the gateway; portal shows the suspension reason and remediation steps (update payment, contact support). | Same posture as API. |
| **Audit ingestion** | **Continues unchanged.** Audit events generated by ops/system actions on a suspended tenant (suspension itself, payment retries, eventual reinstatement or offboarding) must be captured. | Compliance and forensic continuity are non-negotiable; suspension is itself an audit-worthy event chain. |
| **Billing** | Subscription paused at Stripe (no further invoice generation during suspension). Existing balance owed is preserved. | "Paused" not "frozen" because reinstatement should not require re-creating the Stripe customer. |
| **Backup / DR retention** | Continues per ADR-0036 DR tier of the affected data. Suspension does not relax DR commitments. | The data still exists; loss of it during suspension is still loss. |
| **Notify quota** | Frozen at zero. Quota counters are not reset. | Cleanest re-instatement semantics. |
| **Scheduled jobs (tenant-scoped)** | Disabled (do not enqueue). | No silent background work for a non-paying tenant. |

**Grace period durations (defaults, configurable per plan tier):**

- `Active → PastDue` to `PastDue → Suspended`: **7 days** of payment retries (Stripe Smart Retries handles the cadence).
- `Suspended → Offboarding` (auto-escalation if not reinstated): **30 days**.
- `Offboarding → Closed`: **30 days** (D5).

Total elapsed from first payment failure to data deletion under the default settings: **7 + 30 + 30 = 67 days.** The 67-day window is deliberately long enough that no customer loses data because they missed a credit card email while on vacation, and short enough that we're not indefinitely warehousing the data of customers who have ghosted.

**Customer communication cadence during suspension:**

| Day | Event | Channel | Sender |
|-----|-------|---------|--------|
| T+0 (payment fail) | "Payment failed; we'll retry over the next 7 days. Action: update card." | Email + portal banner | Communications → Notify |
| T+3 (PastDue) | Reminder email; portal banner persists. | Email | Communications → Notify |
| T+7 (PastDue → Suspended) | "Account suspended. Update payment to restore. Data preserved for 30 days." | Email + portal | Communications → Notify |
| T+15 (Suspended, halfway) | Reminder + offer to export data via support. | Email | Communications → Notify |
| T+27 (Suspended, near offboarding) | Final warning — 3 days until offboarding starts. | Email | Communications → Notify |
| T+37 (Offboarding T+0) | "Offboarding initiated. Download your data within 30 days." | Email with export link | Communications → Notify |
| T+52 (Offboarding T+15) | Reminder of export window. | Email | Communications → Notify |
| T+64 (Offboarding T+27) | Final warning — 3 days until permanent deletion. | Email | Communications → Notify |
| T+67 (Closed) | "Account closed. Data permanently deleted." | Email | Communications → Notify |

All emails carry an unambiguous remediation link (update card → Stripe Billing Portal; download data → signed export URL per D7; reinstate → ops contact). Tone is direct and non-punitive — the goal is to give the customer every reasonable chance to cure.

**Reinstatement edge cases:**

- **Stripe automatic recovery during `Suspended` state.** If Stripe Smart Retries succeeds after `PastDue → Suspended` (this can happen if the bank approves a previously-declined retry), the `invoice.payment_succeeded` webhook fires. The Grid handles this by **moving to `Active`** automatically — the customer's payment is good, suspension was the response to a bad-payment signal, that signal is now reversed.
- **Reinstatement after ToS suspension** requires explicit ops action (Studios console), not webhook-driven. ToS violations aren't automatically curable.
- **Reinstatement after voluntary offboarding** is supported during the 30-day Offboarding window via ops action only (the customer must email support; we want a brief conversation to confirm intent). Post-`Closed`, no reinstatement — new signup.

### D5 — Offboarding flow

Offboarding is the explicit "we are parting ways" state. Three entry paths:

- **Customer-initiated self-serve:** the tenant portal has a "Close account" action. Confirms intent (typed account name, like GitHub's repo-delete confirmation), schedules transition to `Offboarding`. Confirmation email sent.
- **Customer-initiated via support:** customer emails support; ops triggers the transition via Studios admin console. Same downstream behavior.
- **Ops-initiated:** ToS termination or extended non-payment escalation. Same downstream behavior, different `offboarding_reason` recorded.

On entry to `Offboarding` state at `T+0`:

1. Subscription canceled at Stripe (`subscription.cancel` with `at_period_end=false`; no further invoices).
2. API access switches to `HTTP 410 Gone` for writes; read paths remain available **for export only** (D7).
3. The customer's offboarding email includes a one-click data export link (per D7) valid for the full 30-day grace window.
4. **Pseudonymization runs at `T+0` for any PII in the audit-adjacent tables** (D6). The pseudonymous tokens are stable; the PII map is preserved until `T+30` so that the customer can still access their own data via the export path.
5. Audit emits `TenantOffboarding` with the reason.

At `T+30` (offboarding grace window elapsed), state transitions to `Closed`:

1. Hard-delete the per-tenant data partition (per ADR-0049 isolation guarantees the deletion is bounded to the tenant).
2. Hard-delete the tenant Key Vault namespace; the Vault soft-delete window (Azure default 90 days) provides a recovery-from-mistake buffer for ops, but the keys are permanently inaccessible to the tenant.
3. Hard-delete the **PII↔pseudonymous-token map** (D6). This is the load-bearing deletion that satisfies GDPR.
4. Mark Auth tenant scope as `closed`; revoke all credentials.
5. Notify quota record deleted.
6. Stripe customer retained (Stripe records are minimal and useful for finance/audit; no PII beyond what Stripe itself is the controller for).
7. Audit emits `TenantClosed`. The audit substrate now contains only pseudonymous references to the closed tenant (D6).

**Re-instatement after `Offboarding` is allowed** until `T+30`; after `Closed` it is not — re-instatement post-`Closed` is functionally a new tenant (new `tenant_id`).

### D6 — GDPR Article 17 / right-to-erasure vs Audit append-only — the central decision

**The collision:**

- **Invariant 47** says: the audit substrate is append-only by interface. No `IAuditWriter.Delete(...)` exists. No path through the API allows a written audit record to be modified or deleted.
- **GDPR Article 17** says: data subjects have the right to obtain erasure of personal data concerning them, on request, without undue delay. CCPA §1798.105 says materially the same thing for California residents.
- **Naïve readings collide head-on:** if a tenant's audit log contains `user@example.com` as an actor identifier, and that user exercises right-to-erasure, the email must be removed — but the audit substrate forbids removal.

**The resolution:** **pseudonymization at the audit boundary, with the resolvable map living in an erasable store.**

GDPR Art. 4(5) defines pseudonymisation as "the processing of personal data in such a manner that the personal data can no longer be attributed to a specific data subject without the use of additional information, provided that such additional information is kept separately and is subject to technical and organisational measures to ensure that the personal data are not attributed to an identified or identifiable natural person." The European Data Protection Board has consistently held that **destruction of the re-identification key constitutes effective erasure of the pseudonymous data** for Art. 17 purposes — the residual pseudonymous tokens are no longer "personal data" because they can no longer be attributed to a data subject.

This ADR commits the Grid to that posture:

1. **Audit substrate stores only pseudonymous tokens.** Every actor reference in an audit record is a `pseudo_tenant_token` (opaque 32-character random string, namespaced per tenant) and a `pseudo_user_token` (same shape, namespaced per user). Email addresses, IP addresses, real names, phone numbers — **none of these appear in audit records.** Free-text fields (`event_description`, etc.) are scrubbed by the audit ingestion pipeline using the same regex processor as the PII-scrubbing pipeline from ADR-0045 D7 / ADR-0040 D9, and rejected (not silently scrubbed — the emitter is buggy if it tried) if a known PII pattern is detected.

2. **The PII ↔ pseudo-token map lives in an erasable store.** Two map surfaces:
   - **`HoneyDrunk.Auth.IdentityMap`** — a Grid-level table mapping `pseudo_user_token` ↔ `user_id` (the canonical Grid `PrincipalId` per ADR-0026) ↔ user PII (email, name). Single table, single owner Node (Auth), governed by GDPR-compliant retention rules.
   - **The tenant's own data partition** — additional context (e.g., the user's display name within that tenant's scope) lives in the tenant partition, which is itself deleted on tenant closure per D5.

3. **On user-level erasure request (GDPR Art. 17 for an individual user):**
   - Delete the row for that `pseudo_user_token` in `HoneyDrunk.Auth.IdentityMap`.
   - Delete any tenant-scoped PII rows referencing that `user_id` across tenant partitions.
   - **Do not touch the audit substrate.** The audit records continue to reference `pseudo_user_token`, which is now permanently unresolvable.
   - Emit a `UserErased` audit event referencing the (now-orphaned) `pseudo_user_token` and a `gdpr_request_id` for legal traceability. The audit substrate is happy to record the erasure event; it never had the PII to begin with.

4. **On tenant-level erasure request (full tenant closure per D5):**
   - All steps above, plus deletion of the tenant Key Vault namespace, the tenant data partition, and the `pseudo_tenant_token ↔ tenant_id ↔ tenant metadata` rows in the Auth-side identity map.
   - Audit records referencing the `pseudo_tenant_token` remain; they are now permanently unresolvable.

5. **What the audit substrate retains post-erasure:**
   - The pseudonymous tokens (unresolvable, no longer personal data per GDPR Art. 4(5)).
   - The structural shape of the event (timestamp, action type, resource type, outcome).
   - The fact that *an* erasure happened (the `UserErased` / `TenantClosed` event itself).
   - Enough structural integrity to satisfy forensic-reconstruction needs ("a deletion happened at this time on this resource") without the personal identity attached.

6. **What this requires from existing Nodes:**
   - **ADR-0030 D-? (Audit interface contract)** is amended: the audit writer interface accepts only `pseudo_*_token` shapes for actor/subject fields, and rejects raw email/IP/PII patterns at the boundary. Compile-time type enforcement where possible (`PseudoUserToken` value type, not `string`); runtime rejection where not.
   - **ADR-0049 D6 (Tenant data isolation, deletion semantics)** is amended to require that the tenant partition deletion also triggers identity-map row deletion in Auth.
   - The Audit Node never holds the PII↔token map. It never has reverse-lookup capability. The append-only property is preserved on the audit substrate; the erasability property is satisfied at the (separate) identity map.

**Pseudonymous token shape (concrete):**

```
pseudo_user_token   ::= "pu_" + 32-char base32 (no padding)   // e.g., pu_7Q3K9XYZWMNV4HRTB8LPS2E5DACFJG6Y
pseudo_tenant_token ::= "pt_" + 32-char base32 (no padding)   // e.g., pt_K8MTNQR2YFV4XPHWLDS3CABE7J96GZUY
```

Tokens are generated at user/tenant creation time by `HoneyDrunk.Auth` using a CSPRNG; they are stable for the lifetime of the user/tenant mapping in the identity map, and become permanently orphaned post-erasure. They are NOT derived from the underlying identifier (no hash, no HMAC) — derivation would re-create a re-identification path for anyone with knowledge of the underlying ID and the derivation function, which would defeat the erasure property. They are random and stored in the map.

**Legal posture statement (for the records-retention BDR to reference when filed):** the Grid's GDPR compliance position is that pseudonymous tokens in the audit substrate, post-deletion of the corresponding identity-map row, are no longer personal data within the meaning of GDPR Art. 4(1) because they cannot be attributed to an identified or identifiable natural person without information that has been destroyed. This position is consistent with EDPB Guidelines 01/2025 on pseudonymisation and with the German Federal Data Protection Commissioner's published guidance. **The position has not been litigated for HoneyDrunk specifically**; engagement with privacy counsel before Notify.Cloud GA is a follow-up.

This is the central architectural commitment of this ADR. Without it, the Grid cannot lawfully serve EU-resident users. With it, **append-only audit and right-to-erasure coexist** because they operate on different data: audit holds tokens; the map holds PII; the map is erasable.

**What the audit substrate does NOT do, by design:**
- Maintain reverse-lookup tables (`pseudo_token → real_identity`). Even if held in a separate store, this would re-create the GDPR problem.
- Permit deletion of audit records themselves (Invariant 47 stands).
- Permit modification of audit records after write (Invariant 47 stands).

Reverse-lookup for legitimate operational use (e.g., "who was the user that triggered this incident?") goes through the identity map *if and only if the map still contains the mapping*. Post-erasure, the question is no longer answerable — which is the GDPR-compliant outcome.

### D7 — Data export contract

Tenants own their data. Offboarding (and any time during the tenant lifecycle) must produce a complete export of tenant-scoped data.

**Format:** A single ZIP archive containing:
- `manifest.json` — version, tenant ID, export timestamp, included tables, record counts, schema version.
- `data/*.json` — one JSON file per logical entity type, NDJSON-formatted (one record per line) for streaming-friendly import.
- `data/*.csv` — parallel CSV per relevant table, for non-developer-friendly inspection (spreadsheet open).
- `schema/*.json` — JSON schema documents for each entity type (so the customer can validate/process the export with off-the-shelf tools).
- `README.md` — explains the structure, the schema versions, and the format guarantees.

**Scope:** **Tenant-scoped data only.** Cross-tenant aggregates, system telemetry, audit records, and any data the tenant is not the controller for are excluded. Specifically excluded:
- The audit substrate (the tenant is not the controller; audit holds pseudonymous tokens anyway).
- Pulse / Observe telemetry.
- Stripe billing records (the customer can export those directly from Stripe).
- Any data belonging to other tenants (obviously).

**Delivery:** A signed Azure Blob Storage URL, **valid for 7 days from generation**. The URL is delivered:
- Via the tenant portal's "Download export" action (synchronous link generation).
- Via email to the tenant owner's verified address (asynchronous, when export size requires server-side generation).

**Trigger:** Self-serve via the tenant portal (Notify.Cloud admin console). Rate-limited to **one export per tenant per 24 hours** to prevent abuse (compute cost and storage cost).

**Tenant-side encryption (optional, v2):** for higher-tier customers, the export can be encrypted with a customer-managed KMS key wrap (BYOK). The ZIP body is symmetric-encrypted; the symmetric key is wrapped with the customer's KMS-managed key. v1 ships unencrypted-at-rest-in-blob (the signed URL itself is the access control; the blob lifetime is 7 days). v2 is deferred to a follow-up ADR if customers ask.

**Audit trail:** The export itself is audited. A `TenantDataExported` event records: `pseudo_tenant_token`, requesting `pseudo_user_token`, timestamp, blob name, record-count summary, success/failure. The audit event references the export, not the export contents.

**Offboarding-window exports:** during the 30-day `Offboarding` grace window, the tenant portal remains accessible **for export purposes only**. The portal UX is reduced to a single-action "Download my data" screen. After `T+30`, the portal returns `HTTP 410 Gone` and the data is no longer recoverable.

### D8 — Inter-Node coordination: the workflow lives in HoneyDrunk.Communications

The provisioning, suspension, offboarding, and erasure workflows each span 5–9 Nodes (per D3's step list). They need durable orchestration: long-running, retry-on-step, compensation-on-failure, observable end-to-end.

Three placement candidates:

| Candidate | Pro | Con | Verdict |
|-----------|-----|-----|---------|
| **A dedicated `HoneyDrunk.TenantLifecycle` Node** | Clean single-responsibility scope; explicit boundary | New Node, new standup work, new Vault namespace, more Grid weight | Rejected — too much weight for a workflow that fits within an existing orchestration Node |
| **A step in `HoneyDrunk.Operator`** | Operator already exists for ops-driven automation | Operator's scope is operational tooling (cron jobs, ops console), not customer-facing orchestration | Rejected — wrong layer; muddies Operator's purpose |
| **A workflow hosted in `HoneyDrunk.Communications`** | ADR-0019 already designates Communications as the orchestration boundary for cross-Node decision/orchestration; tenant lifecycle is decision/orchestration by definition | Adds workflow surface to Communications | **Selected** |

The choice is consistent with ADR-0019 D-?: "Communications owns decisions about what should happen and when, across Nodes; Notify owns intake and delivery mechanics." Tenant provisioning is "what should happen and when"; the actual sends (welcome email, suspension notice, etc.) are delegated to Notify. The split is clean.

**Implementation note (deferred to the Communications-side standup work):** the durable workflow runtime choice (Dapr Workflow vs Azure Durable Functions vs a roll-your-own using `HoneyDrunk.Kernel`'s idempotency + the audit substrate as a state log) is left to the Communications-side execution packet. Whatever the runtime, the workflow shape is the one defined in D3 / D5.

### D9 — Tooling (v1)

**The Studios admin console** is the v1 ops surface for tenant lifecycle. Specifically:

- Prospect approval queue (D2): list pending prospects, view details, approve / reject with reason.
- Tenant directory: filter by state, search by name/ID, view tenant overview.
- Per-tenant actions: suspend (with reason), reinstate, escalate to offboarding, force-close.
- Audit timeline per tenant (read-only view of audit events filtered by `pseudo_tenant_token`).
- Manual triggers for provisioning-retry, deprovisioning, export-on-behalf-of.

**A CLI is NOT shipped in v1.** Rationale: the admin console is sufficient for v1 volume (< 50 actions/week), and avoiding the CLI keeps the ops surface auditable through a single UI (every CLI invocation would need its own audit-trail plumbing). A CLI is a fast follow if/when ops volume requires it (target: revisit at 100 tenants).

The admin console lives in the Studios surface, behind a role-gated route (`role:platform_admin`, per ADR-0006's RBAC). Two-factor on the operator account is required (enforced by Auth).

### D10 — Audit retention exception (out of scope here, referenced)

Under what circumstances may pseudonymous audit records themselves be deleted?

This ADR establishes the architectural posture that **the audit substrate is append-only and retains pseudonymous tokens indefinitely** (subject to ADR-0040 D3's 730-day retention floor for sensitive audit data).

Audit records that have been resident for >730 days may be transitioned to colder storage per ADR-0040 D3, but **deletion** of audit records is a separate question governed by:

- **Statute-of-limitations expiry** (varies by jurisdiction and event type).
- **Legal hold release** (when a hold has been placed and is later released).
- **Records-retention policy** (a future BDR; the studio doesn't have a written records-retention policy yet).

This ADR explicitly **defers** the question of when (if ever) pseudonymous audit records may be deleted to a future records-retention BDR. The current commitment is: indefinite retention of pseudonymous audit records, no exception path through any code interface, the only legitimate deletion path being out-of-band operator action (database-level) under a future-BDR-governed policy.

The point: **no `IAuditWriter.Delete(...)` exists, including for pseudonymous records.** If the records-retention BDR ever permits time-bounded deletion, it will be implemented as out-of-band scheduled jobs at the storage layer, not as an interface on the audit substrate. Invariant 47 remains intact at the code-surface level.

### D11 — Phased rollout

- **Phase 1 (Weeks 1–3) — State machine and primitives.** Implement the seven-state enumeration in `HoneyDrunk.Auth` (interim home, per D1); persist transitions; emit audit events for each transition. Pseudonymous-token generation in audit writer (D6); identity map table in Auth. Unit + integration tests per ADR-0047 tiers 1 and 2a.
- **Phase 2 (Weeks 3–6) — Provisioning workflow in Communications.** Host the D3 provisioning workflow in Communications. Wire steps 1–8; step 9 (welcome email) lands as Notify integration. Studios admin console: prospect approval queue + tenant directory.
- **Phase 3 (Weeks 6–8) — Suspension semantics.** Wire suspension gates at the API gateway (per D4 status codes). Stripe webhook handling for `payment_failed` → `PastDue`. Scheduled job for `PastDue → Suspended` grace window expiry. Studios console: suspension action.
- **Phase 4 (Weeks 8–11) — Offboarding + export.** Wire offboarding state transitions, T+30 scheduled purge, data export generation pipeline. Customer-facing portal flow for self-serve close. Per-tenant export rate limiter.
- **Phase 5 (Weeks 11–13) — Erasure flow.** User-level GDPR Art. 17 path: API + ops console action. Verify the identity-map deletion + audit-substrate preservation behavior end-to-end with a dedicated canary.
- **Phase 6 (Ongoing) — Hardening and follow-ups.** Auto-provision follow-up ADR (after 50+ tenants and abuse signal calibration). BYOK export encryption follow-up (when customer asks). Records-retention BDR (when legal counsel is engaged).

Each phase is a discrete go/no-go.

### D12 — Relationship to existing ADRs and PDRs

- **ADR-0026 (Tenancy Primitives)** — extended. The "future tenant-lifecycle ADR" referenced in ADR-0026 is this ADR. Token format, intake mechanics, and propagation rules from ADR-0026 are unchanged.
- **ADR-0006 (Per-Node Key Vaults)** — extended. Provisioning step 2 (D3) instantiates Vault namespaces per the existing pattern; offboarding step (D5) deletes them.
- **ADR-0019 (Communications boundary)** — extended. Tenant lifecycle workflow is hosted in Communications per D8, consistent with ADR-0019's orchestration-boundary commitment.
- **ADR-0027 (Notify.Cloud, Proposed)** — unblocked. Notify.Cloud now has a defined "what is a tenant" answer and can move forward.
- **ADR-0030 (Audit Substrate)** — extended via D6. Audit interface gains pseudonymous-token-only typing for actor/subject fields. Append-only property fully preserved.
- **ADR-0031 (Audit Standup)** — extended. Standup work now includes the pseudonymous-token writer contract.
- **ADR-0036 (DR Tiers)** — referenced. Tenant data tier classifications are unchanged; suspension does not relax DR; closed-tenant data is gone (no further DR commitments).
- **ADR-0037 (Billing, Proposed)** — unblocked. The subscription-state ↔ tenant-state mapping is committed in D1.
- **ADR-0042 (Idempotency Contract)** — consumed. Provisioning steps use `IIdempotencyStore` per D3.
- **ADR-0049 (Tenant Data Isolation, Proposed)** — interlocks. Provisioning instantiates the partition (D3 step 5); offboarding deletes it (D5); identity-map deletion is coordinated (D6).
- **PDR-0002 (Notify.Cloud commercial)** — unblocked.

## Consequences

### Affected Nodes

- **HoneyDrunk.Auth** — gains the interim `Tenants` state-machine table (until Billing standup migrates it), the `IdentityMap` table (pseudonymous-token ↔ PII), the identity-map deletion path for erasure flows, the role assignment step for provisioning, the read-replica view of tenant state for fast access checks.
- **HoneyDrunk.Vault** — provisioning step (create tenant namespace) and offboarding step (delete tenant namespace) become standard lifecycle hooks; the existing `IVault` surface accommodates without contract changes.
- **HoneyDrunk.Data** — tenant-partition create/delete operations become lifecycle-driven (per ADR-0049 interlock); export pipeline emits NDJSON + CSV per partition.
- **HoneyDrunk.Notify** — welcome email, suspension notice, offboarding confirmation, export-ready email, all become Notify intake calls from the Communications workflow.
- **HoneyDrunk.Communications** — hosts the tenant lifecycle workflows (provisioning, suspension, offboarding, erasure). New surface area but architecturally consistent with ADR-0019.
- **HoneyDrunk.Audit** — interface extended to accept only `PseudoTenantToken` / `PseudoUserToken` value types in actor/subject fields; PII rejection at the boundary; new event types (`TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased`).
- **HoneyDrunk.Billing** (not yet scaffolded; introduced by ADR-0037) — once standup completes, owns the tenant-state record canonically; Stripe webhook handling drives state transitions.
- **HoneyDrunk.Studios** — admin console additions per D9: prospect queue, tenant directory, per-tenant action surface, audit timeline view.
- **HoneyDrunk.Architecture** — `catalogs/contracts.json` gains `PseudoTenantToken`, `PseudoUserToken` value types under Audit's published contracts; `repos/HoneyDrunk.Auth/integration-points.md` gains the identity-map description; `constitution/feature-flow-catalog.md` gains the tenant lifecycle flow.

### Invariants

Adds two; amends none directly:

- **Invariant: audit substrate actor/subject fields accept only pseudonymous tokens.** Compile-time enforcement via value types where possible; runtime rejection at the audit-writer boundary for any PII-shaped input. Preserves Invariant 47 (append-only) while enabling GDPR Art. 17 compliance via the separate erasable identity map.
- **Invariant: every tenant exists in exactly one of the seven enumerated states; transitions are audited and initiator-attributed.** State machine integrity is a compile-time enum + runtime transition guard.

(Final invariant numbers assigned at constitution update; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **The Notify.Cloud go-live path is unblocked.** PDR-0002 and ADR-0027 can move toward acceptance now that the "what is a tenant" answer exists.
- **GDPR / CCPA exposure is materially reduced.** The pseudonymization-based resolution (D6) is the recognized-best-practice posture for reconciling immutable audit logs with right-to-erasure. The remaining exposure is operational (we still need to *implement* the boundary enforcement correctly) but no longer architectural.
- **Provisioning is gated on manual approval at v1.** Approval load is small (< 5/week expected) but real. The operator (the developer) is the bottleneck; this is acceptable for the early customer-acquisition window and revisited at follow-up ADR.
- **A new orchestration runtime joins the Grid.** Communications-hosted workflows require a durable-workflow primitive (choice deferred); the operational surface (workflow inspection, retry, replay) is new tooling the operator learns. The Studios admin console exposes the workflow status read path.
- **The 30-day offboarding window means up to 30 days of warehoused offboarded-tenant data.** Storage cost is modest at v1 volume. Customers occasionally regret offboarding and the window provides clean re-instatement; the trade-off favors the customer.
- **The 67-day total window (PastDue → Suspended → Offboarding → Closed) is intentional generosity.** Customers do not lose data because they missed an email; bad actors don't get to mine free credits forever. Defensible from both directions.
- **Audit storage continues to grow indefinitely** (per D10 deferral). Cost projection per ADR-0040 D10's budget envelope remains comfortable at v1 volume; revisited if/when records-retention BDR commits time-bounded deletion.
- **The Auth Node grows in importance.** Auth is already Core-tier; gaining the identity map elevates its DR posture (per ADR-0036) further — identity-map loss is a Tier 0 incident because it disables PII-resolution for active tenants. RPO/RTO for Auth must be tightened in the Auth-side execution work.
- **Pseudonymous tokens are not human-readable.** Operators investigating an audit timeline see opaque tokens, not "user@example.com". The Studios console resolves tokens to PII *for active mappings* (via the identity map) but cannot resolve post-erasure. This is the intended GDPR-compliant behavior; ops tooling makes the resolution clear-cut in the active case.

### Follow-up Work

- Implement the seven-state enumeration and persistence (Phase 1; Auth-side packet).
- Implement `PseudoUserToken` / `PseudoTenantToken` value types and the audit-writer boundary enforcement (Phase 1; Audit-side packet, interlocks with ADR-0031 standup work).
- Implement the identity-map table and deletion paths in Auth (Phase 1; Auth-side packet).
- Implement the provisioning workflow in Communications (Phase 2; Communications-side packet).
- Choose the durable-workflow runtime for Communications (Phase 2; spike + decision, possibly a sub-ADR if Dapr/Durable Functions debate gets meaty).
- Author the Studios admin console pages (Phases 2, 3, 4; Studios-side packets).
- Wire Stripe webhook handlers in Billing (when Billing scaffolds per ADR-0037; Phase 3).
- Implement the data export pipeline (Phase 4; Data-side + Communications-side packets).
- Implement the offboarding scheduled job and T+30 purge (Phase 4; Communications-side packet, with cross-Node deletion coordination per ADR-0049).
- Implement the user-level GDPR Art. 17 path (Phase 5; Auth-side + Communications-side packets).
- Author the GDPR-erasure canary (Phase 5; verifies identity-map deletion + audit-substrate token retention end-to-end).
- File the follow-up ADR for auto-provisioning (Phase 6; after abuse-detection signal is calibrated).
- File the records-retention BDR (Phase 6; requires legal counsel engagement).
- File the follow-up ADR for BYOK export encryption (Phase 6; on customer demand).
- Update `constitution/invariants.md` with the two new invariants.
- Update `constitution/feature-flow-catalog.md` with the tenant lifecycle flow.
- Update `catalogs/contracts.json` with the pseudonymous-token value types.

## Alternatives Considered

### Delete from the audit substrate on erasure (the "obvious" but wrong answer)

The simplest possible mental model: when a user invokes Art. 17, delete every audit record that mentions them. Rejected on multiple grounds:

- **Violates Invariant 47** (audit is append-only by interface). Adding a `Delete` path to the audit-writer surface re-opens every prior decision that depended on append-only-ness — including the entire forensic-reconstruction property of audit, including the "did we tamper with the audit log" question, including SOC2 / ISO27001 audit-trail integrity requirements.
- **Operationally fragile.** "Delete every record that mentions this user" is a query against an append-only log. Even if the deletion succeeded, the surrounding records that *reference* the deleted records (causal chains, "user A took action X which triggered user B's action Y") now have dangling references and lose forensic integrity.
- **Not actually required by GDPR.** Art. 4(5)'s pseudonymization carve-out and EDPB guidance make destruction-of-the-map a recognized erasure mechanism. The "delete the record" reading is a naïve interpretation; the pseudonymization interpretation is the legally-tested one.
- **Architecturally regressive.** Years of "audit is append-only" patterns and tooling would have to be unwound. Pseudonymization is additive: it preserves everything we already have and adds a small interface constraint.

Rejected with strong conviction.

### Encrypt PII at rest with a per-tenant key, throw away the key on erasure

A v2-credible option for higher-tier customers (referenced in D7's BYOK export discussion as a related concept). The mechanism: every PII field is encrypted at rest with a per-tenant KMS key; on erasure, the key is destroyed; the ciphertext becomes permanently unreadable.

Considered as an alternative to D6's pseudonymization-and-map approach. Pros:

- Cryptographically definitive: ciphertext-without-key is unrecoverable in a way nobody disputes.
- Simpler conceptual model: no separate identity map, no separate token namespace.
- Stronger story for customers with very-high-sensitivity data (healthcare, financial, government).

Rejected as v1 default:

- **More moving parts at every Node.** Every Node that touches tenant PII needs envelope encryption at the storage layer. The boundary surface is huge (every database column, every blob, every cache, every log) and easy to leak through (a misconfigured cache layer that decrypts-and-stores-plaintext defeats the entire model).
- **Performance cost.** Per-field encryption with HSM-backed key wrap adds latency to every read. At v1 volume this is fine; at scale it's a tax to amortize.
- **Audit substrate impedance mismatch.** Encrypting PII in audit records means the operational read paths (Studios console rendering an audit timeline) need decryption — and the decryption fails post-erasure, which is the intended behavior, but the failure surface needs handling everywhere.
- **The pseudonymization model gets us the same GDPR posture at lower complexity.** When the EDPB has already blessed pseudonymization-with-key-destruction, layering full envelope encryption on top is paying twice for the same compliance property.

Held as a **v2 follow-up for higher-tier customers** (Compliance-tier or Enterprise plan, in pricing language not yet committed). The v1 pseudonymization approach satisfies GDPR for all customers; the v2 envelope-encryption approach offers a cryptographic strengthening for customers who specifically want it. A future ADR commits the v2 mechanism if customer demand materializes.

### Tombstone records in the audit substrate (delete PII, leave structural shell)

A middle-ground option: when erasure is invoked, overwrite the PII fields of audit records with `[REDACTED]` markers, leaving timestamp/action/structural fields intact. Rejected:

- **Still a write into the audit substrate from outside the append-only `IAuditWriter` surface.** Either we add a tombstone interface (violates Invariant 47) or we do out-of-band writes (bypasses the interface and the constraint, defeating the integrity property).
- **Pseudonymization (D6) is strictly better:** the audit substrate never had the PII in the first place, so there's nothing to redact. No special tombstone path, no special interface, no Invariant 47 carve-out. The PII lived in the (erasable) identity map, which is the thing being deleted.

Rejected as architecturally inferior to D6.

### Use Stripe's customer record as the canonical tenant identity

Considered as a cost-savings measure: Stripe already provides customer records, email, payment method, subscription state; why not lean on Stripe as the source of truth and avoid building the identity map ourselves? Rejected:

- **Stripe holds payment-related identity, not Grid identity.** Users without payment methods (free-tier prospects, trial users pre-payment-capture) wouldn't have Stripe records.
- **Cross-tenant users (one user in multiple tenants) don't map cleanly to Stripe's customer model.** Stripe customers are per-account; Grid users can belong to multiple tenants. The identity model needs Grid-native shape.
- **Stripe is a vendor we want to be able to swap.** Locking Grid identity to Stripe customer IDs creates a hard dependency on Stripe persistence. The current approach (Stripe customer is a downstream reference, not a primary key) preserves portability.

Rejected.

### Defer the GDPR question to "we'll figure it out when an EU user shows up"

Rejected emphatically. GDPR's Privacy-by-Design (Art. 25) requires the erasure path to be designed in, not retrofitted under a 30-day response deadline. Discovering "oh, we can't actually erase that user because our audit substrate is append-only" *after* receiving an Art. 17 request is the worst possible time to discover it. The pseudonymization model is cheap to commit now and impossibly expensive to retrofit later.

### Pure self-serve auto-provisioning at v1 (no manual approval gate)

Considered (and is the implied posture of "real SaaS"). Rejected for v1 per D2:

- **Notification APIs with free credits are high-abuse targets.** Phishing campaigns, spam, prompt-injection-driven email-generation abuse — the playbook for abusing a "free trial of a notification API" is well-developed.
- **Manual review at < 5 signups/week is cheap.** The cost of an approval is ~2 minutes of operator attention; the cost of an abuse incident (account compromise, reputational damage, deliverability score loss per ADR-0038) is days of operator attention plus customer trust.
- **The gate is removable.** Going manual → automatic is easy when signal supports it. Going automatic → manual after an abuse incident is reputationally costly.

Deferred to a follow-up ADR after 50+ tenants and calibrated abuse-detection signal.

### A single combined "Onboarding" state instead of `Prospect → Trialing` split

Considered. Pros: one fewer state, simpler diagram. Rejected: the **approval gate** (D2) is a meaningful boundary — `Prospect` records don't have a `tenant_id`, don't have Vault namespaces, don't consume Grid resources. Collapsing them into a single "Onboarding" state would create either premature resource allocation (allocate the tenant before approval) or a state with no tenant_id (which then violates the every-tenant-has-an-id invariant in places that don't expect it). The split is load-bearing.

### A dedicated `HoneyDrunk.TenantLifecycle` Node

Discussed in D8. Rejected because it adds Grid weight (new Node, new standup, new Vault, new repo, new agent file) for a workflow that fits cleanly inside Communications. If the workflow surface grows (10+ distinct lifecycle workflows, each spanning many Nodes), revisit.

### Skip the data export contract; offer "contact support for your data"

Rejected. Self-serve data export is table-stakes for SaaS in 2026 and is a GDPR Art. 20 (right to data portability) requirement for EU users. Building it as a one-off support workflow is more total work than building it as a self-serve feature, with worse customer experience.

### A 7-day or 14-day offboarding window instead of 30

Considered. 7-day is industry-standard for B2C; 30-day is industry-standard for B2B SaaS. Notify.Cloud's customer profile is B2B/developer-tools; 30 days is appropriate. Customers re-instate occasionally; 30 days is generous without warehousing data indefinitely.

### Make audit retention configurable per tenant

Rejected. The 730-day audit retention floor (per ADR-0040 D3) exists for Grid-wide compliance and forensic-reconstruction guarantees; per-tenant variability would create a swiss-cheese audit surface where some tenants have records and others don't, defeating the substrate's purpose. Tenant-facing exports (D7) cover the "give me my data" need; audit is a separate substrate for Grid-internal purposes.

### Persist tenant state in Billing from day one (skip the Auth interim)

Considered. Cleaner long-term home (D1's eventual target). Rejected because `HoneyDrunk.Billing` is not yet scaffolded; introducing it as a hard dependency for the tenant state machine would block Phase 1 on a much larger standup wave. The interim Auth-side persistence is cheap and well-bounded; the migration to Billing when ADR-0037 standup completes is one packet, the data model is small, and the read-replica view in Auth survives the migration (becomes downstream of Billing instead of canonical).

### Use a vendor identity-management product (Auth0, WorkOS, Frontegg) for the identity map

Considered. Vendor IDPs handle the user identity layer well and include some GDPR-erasure tooling. Rejected:

- **The identity map is more than user identity** — it's also the tenant-scope mapping, the pseudonymous-token table, and the link to Grid-internal IDs. Vendor IDPs solve the user-auth slice but don't solve the multi-tenancy + pseudonymization slice.
- **Vendor lock-in for a load-bearing component.** The identity map is the single most security-sensitive store in the Grid (post-pseudonymization, it's where all the PII concentrates). A vendor outage or contract change would be catastrophic in a way that Grid-internal-managed storage isn't.
- **Existing Auth Node already provides the substrate.** We have `HoneyDrunk.Auth`; adding the identity map there is one table and one set of CRUD endpoints. The vendor path would add a contract, an integration, and a per-user cost line.

Reconsidered if Notify.Cloud reaches enterprise-customer scale where SSO/SCIM and federated identity become first-order requirements; even then, the IDP would sit alongside the Grid identity map rather than replacing it.

### Synchronous export generation only (no async / email-delivered path)

Considered as a simplification (just generate the ZIP on click, return as download). Rejected for scaling: tenant data partitions can grow to gigabytes; generating a multi-GB ZIP synchronously during an HTTP request times out request budgets and degrades the portal experience. Hybrid (sync for small exports, async-with-email for large) is the v1 path; the threshold for sync-vs-async is implementation-time-decided based on partition size at request time.

### Hard-delete on the same day as offboarding entry (no 30-day grace)

Rejected. The grace window protects against:
- Accidental offboarding (customer clicked "close account" without meaning to).
- Customer regret (they decide to come back after closing).
- Forgotten data export (the customer didn't pull their data before closing and needs it).

The 30-day window costs us bounded storage (the partition that was going to be deleted anyway, held for a month) and buys defensibility against "you deleted my data the same day I cancelled and I lost everything I needed" complaints. The trade-off heavily favors the grace window.
