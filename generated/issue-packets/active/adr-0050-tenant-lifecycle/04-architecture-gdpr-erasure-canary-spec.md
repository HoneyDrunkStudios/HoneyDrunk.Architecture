---
name: Architecture Doc
type: architecture-doc
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0050", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0050"]
wave: 3
initiative: adr-0050-tenant-lifecycle
node: honeydrunk-architecture
---

# Author the GDPR erasure canary specification

## Summary
Author a specification document under `constitution/` describing the GDPR Art. 17 erasure canary — the test that verifies the ADR-0050 D6 pseudonymization-based erasure resolution actually works end-to-end (identity-map row deletion + tenant-partition deletion + audit substrate retains the now-orphaned pseudonymous tokens + `UserErased` event emitted referencing the orphaned token). The canary **implementation** lands later as a Phase-5 follow-up packet against Auth + Audit + Communications once the erasure path is wired end-to-end; this packet ships the **specification** so the specification is reviewable now, ahead of the implementation packets, and the implementing agent has an executable contract to satisfy.

## Context
ADR-0050 D6 commits the pseudonymization-based resolution to the GDPR-vs-append-only collision. The Consequences / Follow-up Work section explicitly names: *"Author the GDPR-erasure canary (Phase 5; verifies identity-map deletion + audit-substrate token retention end-to-end)."*

A canary specification is a Markdown document, not test code. It describes:

- **What the canary verifies** — the load-bearing properties of the D6 resolution.
- **The setup** — what test fixtures (a test tenant, a test user, a test audit record stream) the canary requires.
- **The act** — what erasure call(s) the canary makes.
- **The assertions** — what the canary checks after erasure.
- **Where the canary runs** — which CI gate(s) and against which backings (in-memory for `pr-core.yml`; durable in a deferred integration pipeline if/when the durable backings land).
- **What the canary does NOT verify** — explicit non-goals, so the canary's scope is bounded.

This specification is the **contract** the eventual canary implementation must satisfy. Authoring it now (before implementation) lets the operator review the verification shape independently of code, and lets the Phase-5 implementing agent treat it as an unambiguous specification rather than re-derive the canary from the ADR text.

Per the per-conversation memory note "no ADR numbers in docs or comments" — the canary spec document does NOT reference "ADR-0050" inline in its body content. It is *about* ADR-0050's D6 resolution, but the text uses the actual rule names ("pseudonymous-token boundary," "identity-map erasability") rather than ADR-number citations. The packet frontmatter (`adrs: ["ADR-0050"]`) and this packet body retain the citation for filing-pipeline purposes; the document this packet creates does not embed ADR numbers in its narrative.

This is a docs-only packet. No code, no workflow, no .NET project.

## Scope
- **New file:** `constitution/gdpr-erasure-canary.md` — the canary specification document. Approximately 2-4 pages.

## Proposed Implementation

Create `constitution/gdpr-erasure-canary.md` with the following sections. The text below is a **specification of the specification** — the executor authors the actual Markdown content following this structure, using clear prose at each section.

### Section 1 — Purpose

The canary verifies that the Grid's GDPR Art. 17 erasure mechanism actually works: that a user erasure call (a) destroys the PII↔pseudonymous-token mapping, (b) leaves the audit substrate untouched, (c) emits a verifiable record that the erasure occurred. This is the central architectural commitment of the tenant-lifecycle decision; a regression here is a legal-compliance regression, not just an operational regression.

The canary runs continuously (in `pr-core.yml`, and in a deferred integration pipeline against durable backings) so a regression is caught at the PR boundary, never in production.

### Section 2 — Setup (Arrange)

The canary's setup:

1. Compose a Grid host with:
   - An `ITenantStore` (in-memory implementation from the Auth-side packet)
   - An `IIdentityMap` (in-memory implementation from the Auth-side packet)
   - An `IAuditLog` (in-memory implementation from the existing Audit package)
2. Create a test tenant via `ITenantStore.CreateProspectAsync(...)`. Capture: the `TenantId`, the issued `PseudoTenantToken`.
3. Create a test user via `IIdentityMap.CreateUserIdentityAsync(userId: "test-user-001", email: "canary@example.test", displayName: "Canary Test User", ct)`. Capture: the issued `PseudoUserToken`.
4. Emit a small fixed stream of audit events (10 entries — enough to verify retention; not so many the test is slow) referencing the test user. Each event uses `AuditEntry.CreatePseudonymous(...)` with the test user's `PseudoUserToken` and the test tenant's `PseudoTenantToken`. Cover a variety of `AuditCategory` values (authentication, authorization, action) and outcomes.
5. **Verify the setup succeeded** — assert `IIdentityMap.ResolveUserAsync(token)` returns the test user's identity (the mapping exists pre-erasure). Assert `IAuditQuery.Search(...)` returns the 10 audit entries.

### Section 3 — Act

The act is a single call:

```
await identityMap.EraseUserAsync(testUserToken, gdprRequestId: "canary-test-request-001", ct);
```

### Section 4 — Assertions (the verification surface)

After the erasure call:

1. **Identity-map row deletion (load-bearing):**
   - `IIdentityMap.ResolveUserAsync(testUserToken)` returns `null`.
   - `IIdentityMap.ResolveByUserIdAsync("test-user-001")` returns `null`.
   - These are the two directions of resolution; both must lose the mapping.

2. **Audit substrate retention (load-bearing — the GDPR-compliant outcome):**
   - `IAuditQuery.Search(...)` filtered by the test user's `PseudoUserToken` still returns the original 10 audit entries.
   - Each returned `AuditEntry`'s `ActorToken` matches the test user's `PseudoUserToken` exactly.
   - **No audit entry has been mutated, deleted, or redacted.** This is the proof that invariant 47 (audit append-only) is preserved through the erasure.
   - **The audit entries' `ActorToken` is now permanently unresolvable** — `IIdentityMap.ResolveUserAsync(entry.ActorToken)` returns `null` for every entry, confirming that re-identification is no longer possible.

3. **Erasure idempotency:**
   - A second call to `IIdentityMap.EraseUserAsync(testUserToken, ...)` returns successfully (no exception thrown).
   - The audit substrate is still untouched (still 10 entries).

4. **`UserErased` event emission (verified at implementation packet time, not Phase 1):**
   - When the Phase-5 erasure-workflow packet wires the actual API surface that composes `IIdentityMap.EraseUserAsync` with `IAuditLog.Append(UserErased)`, the canary additionally asserts: `IAuditQuery.Search(category: AuditCategory.Action, eventName: AuditEvents.UserErased)` returns an entry whose `ActorToken` matches the now-orphaned token and whose metadata carries the `gdprRequestId`.
   - **In Phase-1 / this initiative's scope, the canary asserts steps 1–3 only.** The `UserErased` emission assertion is added when the workflow wiring lands.

5. **Tenant-level erasure (extension of the canary):**
   - The same shape applies to `IIdentityMap.EraseTenantAsync(testTenantToken, ...)`: the `TenantIdentityMap` row is deleted; audit entries referencing the `PseudoTenantToken` are retained but unresolvable.
   - A complete canary covers both user-level and tenant-level erasure paths.

### Section 5 — Non-goals (what this canary does NOT verify)

Explicit non-goals — keeping the canary's scope bounded:

- **Does not verify cross-Node deletion.** Per the ADR, full tenant closure includes deleting the tenant data partition, deleting the Vault namespace, and revoking credentials. The canary verifies the **identity-map / audit-substrate boundary** — not the cross-Node deletion chain. A separate offboarding integration test verifies cross-Node deletion when the relevant packets land.
- **Does not verify the durable backings.** This canary runs against in-memory implementations. A deferred integration-test pipeline verifies against durable Auth-side storage when the durable backing lands.
- **Does not verify external-party erasure** (Stripe customer deletion, external IDP deletion). Stripe customer retention is the customer's responsibility per the ADR. External IDP integration is deferred.
- **Does not measure timing.** GDPR's "without undue delay" is interpreted as "within the 30-day response window the regulation contemplates"; the canary verifies the erasure mechanism works, not its latency under load.
- **Does not test concurrent erasure with active emission.** If the audit pipeline is mid-emit for the user being erased, the race-condition outcome is "the in-flight emission may land in the audit substrate with the now-orphaned token, which is the GDPR-compliant outcome." The canary does not stress this race — it's a property of the design, not a test concern.

### Section 6 — Where the canary runs

- **Tier 1 (PR gate, `pr-core.yml`):** runs against in-memory implementations. Adds < 1 second to the build. Lives in the test project of whichever repo owns the integration shape (likely `HoneyDrunk.Communications.Tests.Canaries` or `HoneyDrunk.Audit.Tests.Canaries` — the implementing packet decides).
- **Tier 2 (integration pipeline, deferred):** runs against the durable Auth backing when that lands. Verifies the load-bearing properties survive the persistence layer.
- **Production canary (out of scope):** running a canary against a production-ish environment is a more elaborate exercise (synthetic-tenant lifecycle, controlled erasure) and is a deferred operational concern.

### Section 7 — Implementation packet

The canary implementation is a **deferred follow-up packet** in this initiative's Deferred Follow-ups list. The packet's target_repo is one of `HoneyDrunk.Audit`, `HoneyDrunk.Auth`, or `HoneyDrunk.Communications` — the implementing agent decides based on which test project naturally hosts the integration shape. The packet's acceptance criteria are derived directly from this specification (sections 2–5).

The implementing packet does NOT require this specification document to be amended. The specification is immutable in the sense that the canary's verification shape is committed; if the implementing packet finds the spec needs refinement, that's a separate amendment packet.

## Affected Files
- `constitution/gdpr-erasure-canary.md` (new)

## NuGet Dependencies
None. This packet is documentation only.

## Boundary Check
- [x] The file lives under `constitution/` — the home of cross-cutting Grid-wide rules and specifications. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `constitution/gdpr-erasure-canary.md` exists with the seven-section structure (Purpose, Setup, Act, Assertions, Non-goals, Where it runs, Implementation packet)
- [ ] The Assertions section explicitly carries the four load-bearing assertions: (1) identity-map row deletion in both resolution directions, (2) audit substrate retention with unresolvable tokens, (3) erasure idempotency, (4) `UserErased` event emission (deferred to the implementing packet's scope)
- [ ] The Non-goals section explicitly lists cross-Node deletion, durable backings, external-party erasure, timing, and concurrent-emission races as out of scope
- [ ] The document's narrative does NOT embed ADR-0050 number citations in body prose (per the memory rule); rule names are spelled out ("pseudonymous-token boundary," "identity-map erasability")
- [ ] The document references invariant 47 (audit append-only) and invariant 78 (audit substrate accepts only pseudonymous tokens; PII rejected at the boundary) by their full text or by name, not by number
- [ ] No code change; no test change; no catalog change in this packet

## Human Prerequisites
None.

## Referenced ADR Decisions

**ADR-0050 D6 — Pseudonymization at the audit boundary; identity-map erasability.** The audit substrate stores only pseudonymous tokens; the PII↔token map is erasable; destruction of the map row is the GDPR Art. 17 erasure mechanism. The canary specification ships a verifiable test of this commitment.

**ADR-0050 Follow-up Work — "Author the GDPR-erasure canary (Phase 5; verifies identity-map deletion + audit-substrate token retention end-to-end)."** This packet is the specification step of that follow-up. The implementation is a deferred follow-up packet.

**Invariant 47 (referenced, by full text) — Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry.** The canary's load-bearing assertion #2 is the proof that invariant 47 survives the erasure mechanism.

**Invariant 78 (this initiative) — Audit substrate actor and subject fields accept only pseudonymous tokens; PII rejected at the boundary; PII↔token map lives in an erasable store.** The canary's load-bearing assertions #1 and #2 together are the proof that invariant 78 holds end-to-end.

## Constraints
- **No ADR number citations in the document body prose.** Per the memory rule "no ADR numbers in docs or comments," the specification document refers to rule names and full invariant text rather than "ADR-0050" or "invariant 78" mid-sentence. The packet frontmatter and this packet body retain numbered citations for filing-pipeline purposes.
- **Specification, not implementation.** This packet authors the canary's verification contract. It does NOT add a test project, test files, or any C# code. The implementation is a deferred packet.
- **The four load-bearing assertions are immutable in the specification.** Implementation may extend (e.g. add the `UserErased` emission assertion when the workflow lands) but may not weaken or remove the four.
- **No site-sync flag.** This is internal compliance documentation; no Studios website surface change.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0050`, `wave-3`

## Agent Handoff

**Objective:** Author the GDPR Art. 17 erasure canary specification as a Markdown document under `constitution/`.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ship the verification-shape contract for the eventual canary implementation, so the spec is reviewable independently and the implementing agent has an unambiguous executable contract.
- Feature: ADR-0050 Tenant Lifecycle rollout, Wave 3.
- ADRs: ADR-0050 D6 (the central commitment the canary verifies), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0050 Accepted; invariants 78 and 79 live before the canary spec references them.

**Constraints:**
- No ADR numbers in document body prose. Use rule names ("audit substrate accepts only pseudonymous tokens," "identity-map erasability") instead.
- Specification only — no code, no test project, no .csproj.
- The four load-bearing assertions (identity-map row deletion, audit substrate retention with unresolvable tokens, erasure idempotency, `UserErased` event emission) are the immutable core of the canary's verification shape.
- The Non-goals section explicitly bounds the canary's scope.

**Key Files:**
- `constitution/gdpr-erasure-canary.md` (new — the entire deliverable)

**Contracts:** None changed. This is a specification document.
