---
name: Architecture Catalog
type: architecture-catalog
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0050", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0050"]
wave: 1
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-architecture
---

# Register the tenant lifecycle in the Grid catalogs and feature-flow catalog

## Summary
Register the ADR-0050 tenant-lifecycle artifacts in the Grid catalogs: add `PseudoUserToken`, `PseudoTenantToken`, and the `TenantState` enum to `catalogs/contracts.json` under their owning Nodes; record the new Auth↔Audit identity-map relationship and the Communications↔Auth/Vault/Data/Notify workflow relationships in `catalogs/relationships.json`; add the tenant lifecycle flow to `constitution/feature-flow-catalog.md`; describe the `IdentityMap` in `repos/HoneyDrunk.Auth/integration-points.md`.

## Context
ADR-0050 is now Accepted (packet 00). Its decisions are live rules. The Grid catalogs and the feature-flow catalog are the canonical readout of the Grid's contracts, relationships, and operational flows — they must reflect ADR-0050's commitments so downstream artifacts (dependency-graph rendering, ADR cross-references, the Studios `/grid` visualization, future review-agent context loads) can consume them.

Specifically, ADR-0050 introduces:

- **New value types** — `PseudoUserToken` (`pu_` + 32-char base32) and `PseudoTenantToken` (`pt_` + 32-char base32). These are **Audit-owned** contract types in `HoneyDrunk.Audit.Abstractions` (D6). They are issued by Auth at user/tenant creation time and consumed by every audit emission — they are the type-level boundary that enforces invariant 78.
- **A new enum** — `TenantState` with the seven values `Prospect`, `Trialing`, `Active`, `PastDue`, `Suspended`, `Offboarding`, `Closed`. Owned by Auth (the interim home per D1; eventual canonical home is Billing).
- **A new Auth-owned table surface** — the `IdentityMap` (described in detail in `repos/HoneyDrunk.Auth/integration-points.md`): `pseudo_user_token ↔ user_id ↔ user PII` and `pseudo_tenant_token ↔ tenant_id ↔ tenant metadata`. Two columns per direction; one Auth-owned table.
- **A new feature flow** — the tenant lifecycle flow, spanning Auth (state machine, identity map) → Communications (workflow orchestration) → Vault (per-tenant namespace) → Data (per-tenant partition) → Notify (welcome/suspension/offboarding emails) → Audit (lifecycle event emission).
- **New relationship edges** — Auth depends on Audit (already exists per ADR-0030 + v0.5.0 wiring; verify, do not duplicate). Communications depends on Auth, Vault, Data, Notify, Audit (the workflow composes all of them).

This packet is **catalog/documentation only** — no code, no contracts beyond what's documented in the catalog files. The actual `PseudoUserToken` / `PseudoTenantToken` value types land in packet 02 (Audit); the `TenantState` enum and tables land in packet 03 (Auth).

## Scope
- `catalogs/contracts.json` — add `PseudoUserToken` and `PseudoTenantToken` under `honeydrunk-audit`'s published contracts (kind: `value-type`, package: `HoneyDrunk.Audit.Abstractions`, since: the version packet 02 ships). Add `TenantState` under `honeydrunk-auth`'s published contracts (kind: `enum`, package: `HoneyDrunk.Auth.Abstractions`, since: the version packet 03 ships).
- `catalogs/relationships.json` — verify the Auth→Audit edge already exists; add Communications→Auth, Communications→Vault, Communications→Data, Communications→Notify, Communications→Audit edges (kind: `runtime` or `composition` per the existing schema). Do not duplicate edges.
- `constitution/feature-flow-catalog.md` — add a new "Tenant Lifecycle" flow describing the provisioning sequence (D3 steps), the suspension flow (D4), the offboarding flow (D5), and the erasure flow (D6 user-level / tenant-level).
- `repos/HoneyDrunk.Auth/integration-points.md` — add the `IdentityMap` description: the table's purpose, its columns (pseudonymous-token, identity, PII), its retention posture (PII-erasable on Art. 17 / tenant closure), and its security posture (most-PII-concentrated store in the Grid).

## Proposed Implementation
1. **`catalogs/contracts.json`** — open the file and confirm its schema. Add entries:
   - Under `honeydrunk-audit` → published contracts: `PseudoUserToken` (record, opaque string `Value` prefixed `pu_`, 32-char base32 payload after the prefix) and `PseudoTenantToken` (record, opaque string `Value` prefixed `pt_`). Both records, no derivation from underlying IDs (random; stored in the IdentityMap). Reference ADR-0050 D6.
   - Under `honeydrunk-auth` → published contracts: `TenantState` (enum, seven values: `Prospect`, `Trialing`, `Active`, `PastDue`, `Suspended`, `Offboarding`, `Closed`). Reference ADR-0050 D1.
   - The `since` version for each entry is the version packet 02 / packet 03 ships. If those packets have not yet established the new versions at execution time of this packet, leave the `since` field as a placeholder (`"TBD"` or the next-minor version per the dispatch plan's Version Bumps section) and note in the PR that the value is to be reconciled before catalog readout consumption.

2. **`catalogs/relationships.json`** — open the file and confirm its schema. Add Communications→Auth, Communications→Vault, Communications→Data, Communications→Notify edges (the workflow composes these). Audit→Auth (already exists per v0.5.0 audit wiring) — verify, do not duplicate. The edge kind matches the existing schema (likely `runtime` or `composes`).

3. **`constitution/feature-flow-catalog.md`** — append a new "Tenant Lifecycle" section. Structure it as four sub-flows:
   - **Provisioning flow (D3):** Prospect approval → Auth allocates `TenantId` + `PseudoTenantToken` → Vault creates namespace → Auth provisions tenant scope + owner role → Data provisions per-tenant partition (per the eventual Tenant-Data-Isolation ADR — currently a no-op contract seam) → Notify allocates quota → Billing creates customer + subscription (when scaffolded; currently deferred) → Communications emits `TenantProvisioned` audit event → Communications → Notify sends welcome email.
   - **Suspension flow (D4):** Stripe webhook (`invoice.payment_failed`) → Billing emits state transition `Active → PastDue` (when scaffolded; currently scoped to Auth state machine only) → 7-day grace timer → `PastDue → Suspended` → API gateway returns 402 / 403 / 410 (deferred follow-up) → Communications emits `TenantSuspended` audit event → Notify sends suspension email.
   - **Offboarding flow (D5):** Customer self-serve close → Communications workflow → Stripe subscription cancel → API switches to 410 Gone for writes; export-only reads → Communications emits `TenantOffboarding` audit event → 30-day grace → T+30 purge: hard-delete tenant partition + Vault namespace + IdentityMap row → Communications emits `TenantClosed` audit event.
   - **Erasure flow (D6 user-level):** GDPR Art. 17 request → Auth deletes `IdentityMap` row for the `pseudo_user_token` → tenant-scoped PII rows deleted across partitions → audit substrate UNTOUCHED (its records reference the now-orphaned `pseudo_user_token`) → Communications emits `UserErased` audit event with `gdpr_request_id`.

   Each sub-flow lists the participating Nodes and the order of operations. Cross-reference ADR-0050's D-sections inline.

4. **`repos/HoneyDrunk.Auth/integration-points.md`** — add an `## IdentityMap` section describing:
   - **Purpose:** the PII↔pseudonymous-token resolution table; the load-bearing store for GDPR Art. 17 compliance (its erasability is what makes the pseudonymization model work).
   - **Shape (per D6):** two logical mappings in one table (or two tables — implementation choice in packet 03): `pseudo_user_token ↔ user_id ↔ user PII (email, name)` and `pseudo_tenant_token ↔ tenant_id ↔ tenant metadata`.
   - **Lifecycle:** tokens issued at user/tenant creation via CSPRNG (NOT derived — derivation would defeat the erasure property); stable for the lifetime of the mapping; permanently orphaned in the audit substrate post-erasure.
   - **Erasability:** the table is the canonical erasable store for the Grid's pseudonymization model. On Art. 17 / tenant closure, the corresponding row is hard-deleted. The audit substrate is **never** touched (it never had the PII — invariant 47 + 78 are preserved simultaneously).
   - **Security posture:** post-pseudonymization, this is the single most security-sensitive store in the Grid (all PII concentrates here). Auth's DR posture for this table is **Tier 0** per ADR-0036 — identity-map loss is an outage-class incident.

## Affected Files
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `constitution/feature-flow-catalog.md`
- `repos/HoneyDrunk.Auth/integration-points.md`

## NuGet Dependencies
None. This packet touches only Markdown / JSON governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] The `catalogs/relationships.json` edges I add describe relationships ADR-0050 introduces; no relationship not specified in the ADR is added.

## Acceptance Criteria
- [ ] `catalogs/contracts.json` carries `PseudoUserToken` and `PseudoTenantToken` under `honeydrunk-audit` and `TenantState` under `honeydrunk-auth`, each with the correct ADR-0050 D-reference; the schema of the catalog file is preserved (existing schema-validation tooling, if any, passes)
- [ ] `catalogs/relationships.json` carries the Communications→Auth, Communications→Vault, Communications→Data, Communications→Notify, Communications→Audit edges; existing edges (Auth→Audit) are not duplicated; the schema of the file is preserved
- [ ] `constitution/feature-flow-catalog.md` carries the new "Tenant Lifecycle" flow with the four sub-flows (provisioning, suspension, offboarding, erasure), each cross-referencing ADR-0050's D-sections
- [ ] `repos/HoneyDrunk.Auth/integration-points.md` carries the `## IdentityMap` section describing the PII↔pseudonymous-token resolution table, its erasability, and its Tier 0 DR posture
- [ ] No invariant change in this packet (invariants land in packet 00); no code change
- [ ] The `pr-core.yml` tier-1 gate passes (Markdown lint, JSON validity)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0050 D1 — Seven-state tenant enumeration; persistence in Auth interim, Billing canonical.** The `Tenants` table in Auth (interim) carries the `TenantState` enum. The catalog records `TenantState` under `honeydrunk-auth`.

**ADR-0050 D6 — Pseudonymization at the audit boundary; the IdentityMap.** The `PseudoUserToken` / `PseudoTenantToken` value types live in `HoneyDrunk.Audit.Abstractions` and are consumed by every audit emission. The PII↔token map lives in `HoneyDrunk.Auth.IdentityMap`. The catalog records the token value types under `honeydrunk-audit`; `repos/HoneyDrunk.Auth/integration-points.md` describes the IdentityMap.

**ADR-0050 D8 — Communications hosts the tenant-lifecycle workflow.** The workflow composes Auth, Vault, Data, Notify, Audit. The catalog records the corresponding relationship edges.

**ADR-0050 D3 — Provisioning steps.** Used as the source-of-truth ordering for the "Provisioning flow" sub-flow in `feature-flow-catalog.md`.

**ADR-0050 D4 / D5 / D6 — Suspension, offboarding, erasure flows.** Used as the source-of-truth ordering for the corresponding sub-flows.

## Constraints
- **Preserve catalog schemas.** Do NOT introduce new keys, restructure objects, or rename existing fields in `catalogs/contracts.json` or `catalogs/relationships.json` — append entries to existing arrays/maps following the file's prevailing shape. If a schema change is genuinely needed for the new entry types, file a follow-up packet rather than inlining the change here.
- **`since` versions may be placeholders.** If packet 02 / packet 03 have not yet established the new `HoneyDrunk.Audit` and `HoneyDrunk.Auth` versions at execution time of this packet, set `since` to a placeholder (`"TBD"`) and note in the PR that the value is to be reconciled before catalog readout consumption. Alternatively, the executor may sequence: land packet 02 → land packet 03 → land packet 01 (in which case `since` is concrete). The dispatch plan permits either order — packet 01's `dependencies:` is `[work-item:00]` only.
- **No duplicate edges.** The Auth→Audit edge exists (verified by the v0.5.0 wiring per `ADR-0031`); do not add it again.
- **The Communications→{Auth, Vault, Data, Notify} edges are workflow-composition edges**, not contract-package edges. If `catalogs/relationships.json` distinguishes those kinds, use the workflow/composition kind.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0050`, `wave-1`

## Agent Handoff

**Objective:** Register the tenant-lifecycle artifacts in the Grid catalogs and the feature-flow catalog; describe the IdentityMap in Auth's integration-points doc.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make ADR-0050's contracts and relationships discoverable in the canonical Grid readout.
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 1.
- ADRs: ADR-0050 D1/D3/D4/D5/D6/D8 (primary), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0050 Accepted; the invariants are live before the catalog entries reference them.

**Constraints:**
- Preserve the existing schemas in `catalogs/contracts.json` and `catalogs/relationships.json` — append entries; do not restructure.
- `since` versions may be `"TBD"` if packet 02 / packet 03 have not yet established the new versions.
- Do not duplicate the existing Auth→Audit edge.
- The IdentityMap description in `repos/HoneyDrunk.Auth/integration-points.md` must call out its Tier 0 DR posture (its loss is an outage-class incident) and its erasability (the load-bearing store for GDPR Art. 17 compliance).

**Key Files:**
- `catalogs/contracts.json`
- `catalogs/relationships.json`
- `constitution/feature-flow-catalog.md`
- `repos/HoneyDrunk.Auth/integration-points.md`

**Contracts:** None changed. Catalog readouts updated only.
