# Dispatch Plan — ADR-0050: Tenant Lifecycle (Provisioning, Suspension, Offboarding, Data Export)

**Initiative:** `adr-0050-tenant-lifecycle`
**ADR:** ADR-0050 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0050 commits the Grid's tenant lifecycle: a seven-state enumeration, the v1 self-serve-with-manual-approval provisioning model, idempotent provisioning steps spanning 5–9 Nodes, suspension semantics and grace windows, the offboarding flow with a 30-day window, the data export contract, and — most importantly — the **pseudonymization-based resolution to the collision between GDPR Article 17 (right to erasure) and Invariant 47 (audit is append-only)** (D6). The ADR is large (6 phases, ~13 weeks) and touches Architecture, Audit, Auth, Communications, Data, Notify, Studios.

This initiative delivers **Phase 1 in full** (the load-bearing foundation: state machine, identity map, pseudonymous-token contracts in Audit, audit-boundary PII rejection, catalog registration), **Phase 2's Communications scaffold** (the provisioning workflow runtime seam, prospect-approval intake), **Phase 4's data export pipeline foundation** (the ZIP/manifest builder and signed-URL emit, rate-limited), and **Phase 5's GDPR erasure canary specification**. Phases 3 (suspension API gates + Stripe webhooks), the T+30 offboarding purge scheduler, the full erasure path wiring, and the Studios admin console **are deferred to follow-up packets** named explicitly in Deferred Follow-ups below — each turns on a dependency this initiative does not bring (a scaffolded Billing Node, a decided durable-workflow runtime, a Studios admin-console standup, ADR-0049's tenant data isolation decision).

**9 packets across 5 waves**, targeting **6 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Audit`, `HoneyDrunk.Auth`, `HoneyDrunk.Communications`, `HoneyDrunk.Data`, `HoneyDrunk.Studios`). All 9 are `Actor=Agent`. Packets 03 and 06 carry Human Prerequisites — Azure Blob container provisioning for exports, Auth/Vault namespace touches — but the code work itself is fully delegable.

## Trigger

ADR-0050 is Proposed with no scope. The forcing functions (from the ADR's Context):

- **ADR-0027 (Notify.Cloud, Proposed)** cannot move past Proposed without a definition of "what is a paying tenant." PDR-0002's commercial offering is explicitly blocked on this ADR.
- **ADR-0037 (Billing, Proposed)** presumes a subscription-state ↔ tenant-state mapping that does not yet exist. D1 commits that mapping.
- **GDPR Article 17 / CCPA right-to-delete are statutory.** The first EU-resident user who exercises right-to-erasure cannot be answered with "the audit substrate is append-only, sorry." The collision between Invariant 47 (audit append-only) and the erasure right is the **central architectural decision** in this ADR and cannot be deferred without non-compliance.
- **The first prospect for Notify.Cloud is in active conversation.** Operationally, the Grid needs a way to take their money and provision them in the next 60 days.

## Scope Detection

**Multi-repo, multi-Node.** The decision lands across:

- **`HoneyDrunk.Architecture`** — governance (acceptance, two invariants), catalog registration (`catalogs/contracts.json`, `catalogs/relationships.json`, `constitution/feature-flow-catalog.md`, `repos/HoneyDrunk.Auth/integration-points.md`), GDPR erasure canary specification (a Markdown document under `constitution/` describing the canary's verification shape — the actual canary code lives in a Phase-5 follow-up).
- **`HoneyDrunk.Audit`** — `PseudoTenantToken` and `PseudoUserToken` value types in `HoneyDrunk.Audit.Abstractions`; amendment of `AuditEntry.Actor` (currently `string`) and `AuditEntry.TenantId` to accept pseudonymous tokens (and reject raw PII at the boundary); new audit event names (`TenantProvisioned`, `TenantSuspended`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased`). **Breaking change for any current emitter of raw `string Actor` — managed via the same boundary-enforcement pattern.**
- **`HoneyDrunk.Auth`** — the interim seven-state `Tenants` table (until Billing standup migrates it), the `IdentityMap` table mapping `pseudo_user_token` ↔ `user_id` ↔ user PII and `pseudo_tenant_token` ↔ `tenant_id` ↔ tenant metadata, pseudonymous-token issuance at user/tenant creation, the identity-map deletion path for erasure flows.
- **`HoneyDrunk.Communications`** — the prospect-approval intake (creates `Prospect` records, notifies ops), the tenant-lifecycle workflow runtime seam (`ITenantLifecycleWorkflow` contract — the workflow steps from ADR-0050 D3 in a runtime-agnostic shape), the provisioning workflow scaffold composing the existing Auth/Vault/Notify boundaries. **Does NOT pick the durable-workflow runtime** (Dapr Workflow vs Azure Durable Functions per ADR-0050 D8 — deferred to a spike packet in a follow-up).
- **`HoneyDrunk.Data`** — the data export pipeline scaffold: `ITenantDataExporter` contract; a runtime that walks tenant-partitioned tables, emits NDJSON + CSV + manifest.json + schema/*.json + README.md into a ZIP, uploads to Azure Blob, returns a 7-day signed URL; per-tenant rate limiter (one export per 24 hours).
- **`HoneyDrunk.Studios`** — *not in this initiative.* The D9 admin console (prospect queue, tenant directory, per-tenant actions) is deferred until Studios scaffolds its admin-console area; expressing it as a packet here would require Studios decisions ADR-0050 does not make. Listed under Deferred Follow-ups.

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node.

## Cross-Initiative and Cross-ADR Dependencies

ADR-0050 references several ADRs in flight:

- **ADR-0026 (Tenancy Primitives, Accepted)** — the load-bearing primitive. `TenantId`, the `tnt_` prefix, the 26-char ULID, the boundary-plumbing rules already exist. ADR-0050 builds on these without changing them.
- **ADR-0030 (Audit Substrate, Accepted)** — extended via D6. The `IAuditLog` interface keeps its shape; the value types it accepts are tightened (raw `string` → `PseudoUserToken` / `PseudoTenantToken`). Invariant 47 is **preserved**, not broken.
- **ADR-0031 (Audit Standup, Accepted)** — Audit `v0.1.0` and Auth `v0.5.0` are both published. Packet 02 builds on the live Audit Abstractions surface.
- **ADR-0042 (Idempotency Contract, Proposed)** — D3's provisioning steps are "idempotent per ADR-0042's `IIdempotencyStore` contract." This is a **soft dependency**: this initiative's Communications workflow scaffold (packet 05) defines step seams the workflow runtime *can* wrap with `IdempotentMessageHandler<T>` when ADR-0042 lands and the runtime is chosen. Packets here do not require ADR-0042 to be Accepted — the workflow scaffold is idempotency-pattern-aware in its contract shape (each step has a deterministic idempotency key shape per D3) but does not compose `IIdempotencyStore` directly.
- **ADR-0049 (data discrepancy — flagged).** ADR-0050 repeatedly references "ADR-0049 (Tenant Data Isolation)" — but the actual ADR-0049 in the repo is **"Data Classification, PII Handling, and Retention Schedule"** (the per-tenant partition/schema-isolation model is not decided in ADR-0049). This is a **discrepancy in ADR-0050's text**, not a packet-design problem here. The implication for this initiative: the data export pipeline (packet 06) walks tenant-scoped tables but does **not** assume a particular per-tenant partition or schema model — it consumes whatever the `HoneyDrunk.Data` tenant-scoping primitives already provide (`TenantId` filter on repositories per ADR-0026), and a future Tenant-Data-Isolation ADR can amend partition mechanics without breaking the export contract.
- **ADR-0037 (Billing, Proposed)** — names the eventual canonical home of the tenant-state record. This initiative explicitly ships the **interim** Auth-side persistence (D1); the migration to Billing is a Phase-3/Phase-6 follow-up bound to ADR-0037 standup. The read-replica view in Auth survives the migration.
- **ADR-0027 (Notify.Cloud, Proposed)** — unblocked by this initiative; downstream of it.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0050, add the two new invariants (**78**, **79** — pre-reserved as part of a 12-ADR batch), register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the tenant-lifecycle catalogs (contracts.json: `PseudoUserToken`, `PseudoTenantToken`, `TenantState` enum; `feature-flow-catalog.md`: the tenant lifecycle flow; `relationships.json`: Auth→Audit identity-map dep, Communications→Auth/Vault/Data/Notify workflow deps; `repos/HoneyDrunk.Auth/integration-points.md`: the identity-map description). `Actor=Agent`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — the audit pseudonymous-token foundation)
- [ ] **02** — Audit: add `PseudoTenantToken` / `PseudoUserToken` value types to `HoneyDrunk.Audit.Abstractions`; amend `AuditEntry` and `AuditTarget` to accept pseudonymous tokens for actor/tenant fields; runtime PII rejection at the audit-writer boundary; register the new tenant-lifecycle event names. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Audit`** — breaking change for current raw-string `Actor` emitters; the breaking surface is intentional and matches D6's compile-time-type-enforcement requirement.

### Wave 3 (Depends on Wave 2 — Auth state machine + identity map; parallel with Communications scaffold)
- [ ] **03** — Auth: implement the seven-state `Tenants` table, the `IdentityMap` table (pseudonymous-token ↔ PII), pseudonymous-token issuance at user/tenant creation, the identity-map deletion path. Tenant-state read-replica view stays in Auth (D1 interim home). `Actor=Agent`. Blocked by: 02. **Version-bumping packet for `HoneyDrunk.Auth`.**
- [ ] **04** — Architecture: author the GDPR erasure canary specification — a Markdown document under `constitution/` describing the canary's verification shape (provision a test tenant + user; invoke erasure; assert: identity-map row deleted, tenant partition deleted, audit substrate retains pseudonymous tokens, `UserErased` event emitted referencing the orphaned token). The **canary implementation** is a Phase-5 follow-up packet against Auth/Audit/Communications once the erasure path is wired end-to-end. `Actor=Agent`. Blocked by: 00.

### Wave 4 (Depends on Wave 3 — Communications workflow scaffold + Data export scaffold; parallel)
- [ ] **05** — Communications: implement the `ITenantLifecycleWorkflow` contract in `HoneyDrunk.Communications.Abstractions`, the prospect-approval intake (creates `Prospect` records, notifies ops via the existing `INotificationSender` seam), and the provisioning workflow scaffold composing the D3 step seams. Runtime is in-process placeholder; the durable-workflow runtime choice is a separate spike packet (deferred follow-up). `Actor=Agent`. Blocked by: 03. **Version-bumping packet for `HoneyDrunk.Communications`.**
- [ ] **06** — Data: implement the `ITenantDataExporter` contract and runtime — walks tenant-scoped repositories filtering by `TenantId`, emits NDJSON + CSV + manifest.json + schema/*.json + README.md into a ZIP, uploads to Azure Blob, returns a 7-day signed URL, rate-limited to one export per tenant per 24 hours. `Actor=Agent`. Blocked by: 03. **Version-bumping packet for `HoneyDrunk.Data`.**

### Wave 5 (Depends on Wave 4 — audit-event emitter wiring; closes the foundation)
- [ ] **07** — Audit: wire emitters in Auth and Communications for the seven new tenant-lifecycle event names (`TenantProvisioned`, `TenantSuspended`, `TenantReinstated`, `TenantOffboarding`, `TenantClosed`, `TenantDataExported`, `UserErased`) using the new pseudonymous-token signatures. Auth emits at state-machine transitions; Communications emits at workflow milestones. `Actor=Agent`. Blocked by: 05, 06. **Touches `HoneyDrunk.Auth` and `HoneyDrunk.Communications` — but both repos are already version-bumped by packets 03 and 05; this packet appends to their in-progress CHANGELOGs per invariant 27.** Land as **two PRs** (one per repo), the Communications PR `Blocked by` the Auth PR for clean wave coherence — file the packet under Audit's initiative track only for routing; the actual code lands in Auth and Communications. (The packet's `target_repo` is `HoneyDrunkStudios/HoneyDrunk.Audit` for board-routing purposes, but the implementing PRs land in Auth and Communications — see the packet body's "Cross-Repo PR Note.")

> **Sequencing note for packet 07.** Packet 07's code physically lives in Auth and Communications, not in Audit. The packet's `target_repo` is set to **Auth** (the primary emitter) for board routing; the Communications portion is a sibling PR explicitly called out in the packet body. This deviates slightly from the one-packet-one-repo pattern in service of treating the seven new event names as a coherent rollout — the alternative (splitting into 07-auth and 07-comms) is acceptable if the executor prefers, but the dispatch plan tracks it as one logical unit.

> **Invariant numbering.** The current verified maximum in `constitution/invariants.md` is **51**. Invariant numbers **78, 79** are pre-reserved for ADR-0050 as part of a 12-ADR batch. If any invariant above 51 lands from outside this batch before packet 00 merges, shift this block upward, never reuse a number.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0050](./00-architecture-adr-0050-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Tenant-lifecycle catalog + feature-flow](./01-architecture-tenant-lifecycle-catalog.md) | Architecture | Agent | 1 | 00 |
| 02 | [Audit pseudonymous-token types + boundary rejection](./02-audit-pseudonymous-token-types-and-boundary.md) | Audit | Agent | 2 | 00 |
| 03 | [Auth tenant-state table + IdentityMap](./03-auth-tenant-state-and-identity-map.md) | Auth | Agent | 3 | 02 |
| 04 | [GDPR erasure canary specification](./04-architecture-gdpr-erasure-canary-spec.md) | Architecture | Agent | 3 | 00 |
| 05 | [Communications tenant-lifecycle workflow scaffold](./05-communications-tenant-lifecycle-workflow-scaffold.md) | Communications | Agent | 4 | 03 |
| 06 | [Data tenant-data export pipeline](./06-data-tenant-data-export-pipeline.md) | Data | Agent | 4 | 03 |
| 07 | [Tenant-lifecycle audit event emitters](./07-auth-and-communications-tenant-lifecycle-audit-emitters.md) | Auth (+ Communications) | Agent | 5 | 05, 06 |

## Version Bumps

- **`HoneyDrunk.Audit`** — packet 02 is the first packet on the solution in this initiative; it bumps every non-test `.csproj` to the same new **minor** version (additive contracts: new value types, new event-name constants; the `AuditEntry` amendments are a typed-narrowing rather than a member rename — D6 calls for "compile-time type enforcement where possible; runtime rejection where not"). Packet 07's Audit emission wiring touches Audit only if new helpers are needed; otherwise it appends to no Audit CHANGELOG. Confirm current Audit version at execution time (the v0.1.0 release was the standup; check if a follow-up bump has shipped).
- **`HoneyDrunk.Auth`** — packet 03 bumps the solution one minor version (new `Tenants` table, new `IdentityMap` table, new pseudonymous-token issuance — additive). Packet 07's Auth portion appends to the in-progress CHANGELOG (invariant 27).
- **`HoneyDrunk.Communications`** — packet 05 bumps the solution one minor version (new `ITenantLifecycleWorkflow` contract in Abstractions, new workflow runtime scaffold in the runtime package). Packet 07's Communications portion appends to the in-progress CHANGELOG.
- **`HoneyDrunk.Data`** — packet 06 bumps the solution one minor version (new `ITenantDataExporter` contract + runtime).
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/doc edits only.

## Cross-Cutting Concerns

### Pseudonymous-token boundary enforcement is a typed-narrowing, not a rename

`AuditEntry.Actor` is currently `string` (verified in `HoneyDrunk.Audit/src/HoneyDrunk.Audit.Abstractions/AuditEntry.cs`). ADR-0050 D6 requires the audit substrate accept only `PseudoUserToken` / `PseudoTenantToken` shapes for actor/subject fields. The implementation pattern is **typed-narrowing with a transitional accommodation**:

- Packet 02 introduces `PseudoUserToken` and `PseudoTenantToken` value types and a new constructor overload on `AuditEntry` that accepts them.
- The existing `string Actor` overload remains for *one minor version* with runtime PII rejection at the audit-writer boundary (the writer rejects strings matching email/IP/phone regex patterns).
- A future packet (Phase-1 follow-up) marks the `string` overload `[Obsolete]` once the in-Grid emitters have migrated.
- A future packet (Phase-1 follow-up) removes the `string` overload entirely once the obsoletion window closes.

This is **additive in v0.2.0** (no break for current callers; new types available), and the type-level enforcement of D6 is achieved over two more minor versions. The alternative — straight breaking-rename in v0.2.0 — would block Auth (already an emitter via the v0.5.0 wiring) from compiling against the new Audit until packet 03 + 07 land. The phased approach is consistent with ADR-0050 D6's "compile-time type enforcement where possible; runtime rejection where not" wording.

### "ADR-0049 (Tenant Data Isolation)" is a citation error in ADR-0050

ADR-0050 repeatedly cites **"ADR-0049 (Tenant Data Isolation)"** as the source of per-tenant partition/schema model decisions. The actual ADR-0049 in the repo is **"Data Classification, PII Handling, and Retention Schedule"** — a different decision. The per-tenant data-partition/schema-isolation model is **not yet decided** anywhere.

The impact on this initiative:

- **Provisioning step 5 (D3) — "Provision per-tenant data partition (per ADR-0049 isolation model)."** Until the actual Tenant-Data-Isolation ADR lands, packet 05's Communications scaffold defines step 5 as `IProvisionTenantPartition` with a no-op runtime that emits a structured "partition provisioned" log entry. When the partition model is decided, a follow-up packet implements the real partition allocation behind the same contract.
- **Offboarding step 1 (D5) — "Hard-delete the per-tenant data partition."** Same pattern: a contract-level seam, no-op runtime until the partition model is decided.
- **Packet 06 (Data export)** — the export walks tenant-scoped repositories filtering by `TenantId` per ADR-0026's primitives (which exist today). It does NOT assume a particular partition layout. When a partition model lands, the export may want amendment to walk partition-aware, but the v1 contract is partition-agnostic.

**This citation error should be corrected in ADR-0050 itself** — but that is a documentation-coherence amendment outside this initiative's scope. The follow-ups list a packet for the ADR-0050 text correction once the Tenant-Data-Isolation ADR exists.

### Durable-workflow runtime is deferred behind the seam

ADR-0050 D8 explicitly defers the durable-workflow runtime choice (Dapr Workflow vs Azure Durable Functions vs roll-your-own using `HoneyDrunk.Kernel`'s idempotency + the audit substrate as a state log). Packet 05's Communications scaffold encodes this deferral correctly: the `ITenantLifecycleWorkflow` contract describes step ordering and per-step idempotency keys (D3) but the **runtime** is an in-process placeholder backed by `Task.Run` + the audit substrate as the state log. When the durable runtime is chosen (a separate spike packet in a follow-up), the runtime is swapped behind the contract.

This is the correct decision for now. A workflow runtime selection is itself a load-bearing ADR-level call and should not be smuggled into this initiative.

### Suspension API gates and Stripe webhooks are out of scope here

ADR-0050 Phase 3 wires:
- Suspension gates at the API gateway (return 402 Payment Required / 403 Forbidden / 410 Gone per state).
- Stripe webhook handling for `invoice.payment_failed`, `invoice.payment_succeeded`, `customer.subscription.updated`.
- The `PastDue → Suspended` grace-window scheduled job.

**None of these land in this initiative.** Reasons:

- Stripe webhook handling is `HoneyDrunk.Billing`'s job per D1 and ADR-0037 — and `HoneyDrunk.Billing` is **not yet scaffolded**. Wiring Stripe webhooks into Auth as an interim home would create a structural compromise this initiative declines.
- The suspension gateway gates need an authoritative tenant-state read path — Auth provides the read-replica per D1, which packet 03 builds. But the **gateway code itself** (which Node hosts it? Web.Rest? a per-Node middleware?) is an undecided architectural question — D1 says "the read-replica view in `HoneyDrunk.Auth` for fast access-check decisions," but doesn't decide whether the gate is in Auth.AspNetCore middleware, in each Node's ASP.NET pipeline, or in a future API-gateway Node.
- The grace-window scheduled job needs a scheduled-job substrate — Operator currently runs cron-job-style things; or this could be a Communications workflow timer. Undecided.

These are listed under Deferred Follow-ups.

### The Studios admin console is out of scope here

ADR-0050 D9 commits the Studios admin console as the v1 ops surface (prospect queue, tenant directory, per-tenant actions, audit timeline view, role-gated `role:platform_admin` route). This is a Studios change — and Studios is the Next.js website Node, not a .NET Node. The admin-console area does not currently exist in `HoneyDrunk.Studios` (the site renders Nodes, ADRs, sectors, roadmap — public-facing content). Adding a role-gated admin area requires:

- A Studios authentication story (admin console behind `role:platform_admin` per D9 — this presumes Studios has identity, which it doesn't yet for read-write surfaces).
- The Studios admin-console UX (page designs, data-fetch from Auth/Communications).
- A Studios↔Auth integration (or Studios↔Communications) for the prospect queue + tenant directory.

**This is a Studios-track set of decisions and should be its own initiative.** Listed under Deferred Follow-ups.

### Site sync

No site-sync flag. ADR-0050 is internal Core/cross-cutting infrastructure — no public-facing Studios website content changes in this initiative. (The eventual D9 admin-console area in Studios IS a Studios change, but it's deferred per the previous concern.)

## Deferred Follow-ups (explicitly out of scope)

- **Stripe webhook handlers + `HoneyDrunk.Billing` standup** — the canonical tenant-state home per D1. Bound to ADR-0037 standup track.
- **Suspension API gates** — 402/403/410 gateway responses per D4. Needs an architectural call on gateway placement. Phase 3.
- **`PastDue → Suspended` grace-window scheduled job** — needs a scheduled-job substrate decision. Phase 3.
- **T+30 offboarding-to-closed purge scheduler** — same scheduled-job substrate concern. Phase 4.
- **Full GDPR Art. 17 erasure flow wiring** — the user-level erasure API + ops console action + cross-Node deletion coordination. Phase 5. The **canary specification** lands in packet 04; the canary **implementation** is a Phase-5 follow-up.
- **The Studios admin console** — D9. Needs its own initiative (Studios identity, admin-area UX, Auth/Communications integration).
- **Durable-workflow runtime spike** — Dapr Workflow vs Azure Durable Functions vs roll-your-own. D8. A spike packet, possibly a sub-ADR if the comparison gets meaty. Communications-side.
- **Migration from Auth-interim tenant-state to `HoneyDrunk.Billing`** — bound to ADR-0037 standup. D1 names this as a one-packet migration with the read-replica view in Auth becoming downstream of Billing.
- **Tenant-Data-Isolation ADR** — the per-tenant partition/schema model ADR-0050 cites as "ADR-0049" (a citation error). When this ADR is authored, the Communications workflow's step 5 (provision partition) and offboarding's step (delete partition) get real runtimes behind their existing contract seams. Also: amend ADR-0050's "ADR-0049" references to point at the correct ADR number.
- **BYOK encrypted export (v2)** — D7's customer-managed-KMS-key wrap. On customer demand.
- **Records-retention BDR** — D10's deferred question: when (if ever) may pseudonymous audit records be deleted. Requires legal counsel engagement.
- **Auto-provisioning follow-up ADR** — D2's "remove the manual approval gate after 50+ tenants and calibrated abuse signal."

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the two invariants and the catalog entries are removed. No runtime impact.
- **Packet 02 (Audit pseudonymous tokens):** revert the PR; the new value types and `AuditEntry` overload leave Abstractions; the Audit solution version rolls back. The runtime PII-rejection at the writer boundary disappears. **Current emitters (Auth v0.5.0) continue to work** because the existing `string Actor` overload is retained during the transitional window — so a revert does not break Auth's current emission.
- **Packet 03 (Auth tenant-state + IdentityMap):** revert the PR; the `Tenants` and `IdentityMap` tables disappear (drop the migration); Auth's solution version rolls back. **Caution:** if any rows have been written to either table on a deployed environment, the rollback must preserve them out-of-band (export → re-import on re-apply) or accept their loss. Tag the rollback decision in the revert PR.
- **Packet 04 (canary spec):** revert the PR. The Markdown specification leaves `constitution/`. No runtime impact.
- **Packet 05 (Communications workflow scaffold):** revert the PR; the `ITenantLifecycleWorkflow` contract and the workflow scaffold leave Communications; the solution version rolls back. The prospect-approval intake disappears — ops would need an out-of-band path to receive prospect signups (a manual support-form workflow) until re-applied.
- **Packet 06 (Data export):** revert the PR; the `ITenantDataExporter` contract and runtime leave Data; the solution version rolls back. No customer-facing impact until the export was offered (no customer is offboarding under this initiative).
- **Packet 07 (audit emitters):** revert the PRs (Auth and Communications); the new event-name emissions stop. **No data loss** — audit records already written remain; only new emissions stop.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
