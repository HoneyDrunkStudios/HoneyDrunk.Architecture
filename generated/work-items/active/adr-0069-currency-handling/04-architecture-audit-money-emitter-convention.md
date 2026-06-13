---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0069", "wave-3"]
dependencies: ["work-item:00"]
adrs: ["ADR-0069", "ADR-0030"]
wave: 3
initiative: adr-0069-currency-handling
node: honeydrunk-architecture
---

# Document the audit money-emitter two-field convention (monetary_value + currency_code)

## Summary
Document ADR-0069 D11's two-field convention for money-changing audit events — `monetary_value` (JSON string) and `currency_code` (ISO 4217 alpha-3 uppercase), flat on the audit event, not nested inside a `money` object — in `repos/HoneyDrunk.Audit/boundaries.md` (or the equivalent emitter-conventions location) and in the ADR-0030 emitter-conventions section. No code change in `HoneyDrunk.Audit`: `AuditEntry.Metadata` is already a `IReadOnlyDictionary<string, string>` map, so the two-field convention is a **projection responsibility for emitters** that record monetary outcomes — they project an in-memory `Money` into `metadata["monetary_value"]` + `metadata["currency_code"]` at emit time, with no contract change to `IAuditLog`.

## Context
ADR-0069 D11 commits the audit shape for money-changing events:

```json
{
  "event_type": "SubscriptionRenewed",
  "tenant_id": "01HXXX...",
  "monetary_value": "29.99",
  "currency_code": "USD",
  "correlation_id": "..."
}
```

`monetary_value` is the amount as a JSON string (matching D9's serialization discipline for precision preservation); `currency_code` is the ISO 4217 alpha-3 code, uppercase. The two fields are **top-level / flat on the audit event**, not nested inside a `money` object. The rationale (per D11):

- Audit-query patterns favor flat fields — a query like "total monetary outcomes for tenant X in USD this month" reads `monetary_value` and `currency_code` as separate columns / fields. A nested object requires JSON-path queries on every audit-store backend.
- Backend-agnostic — the audit substrate per ADR-0030 does not commit a specific backend; SQL, Cosmos, and search-index backends all favor flat fields for indexability.
- The in-memory type held by the emitter is `Money`; the on-the-wire / on-disk shape in audit is two flat fields. The emitter is responsible for the projection.

**Why no code change in `HoneyDrunk.Audit` is needed.** The current `AuditEntry` record (in `HoneyDrunk.Audit.Abstractions`) is:

```csharp
public sealed record AuditEntry(
    AuditEntryId Id,
    DateTimeOffset OccurredAt,
    string Actor,
    string EventName,
    AuditCategory Category,
    AuditOutcome Outcome,
    AuditTarget Target,
    TenantId TenantId,
    string? CorrelationId = null,
    AuditOperation Operation = AuditOperation.None,
    IReadOnlyList<AuditChange>? Changes = null,
    IReadOnlyDictionary<string, string>? Metadata = null,
    string? Reason = null)
```

`Metadata` is already a `string → string` map. The two-field convention lands as `Metadata["monetary_value"] = money.Amount.ToString("F{decimals}", InvariantCulture)` and `Metadata["currency_code"] = money.CurrencyCode.Code`. **No change to `IAuditLog`, `AuditEntry`, or any other `HoneyDrunk.Audit.Abstractions` contract.** The Audit Node's `IAuditLog` contract-shape canary (per ADR-0031 D8 / invariant 49) stays green by construction.

The convention is a **documentation deliverable**: the location where emitters look for "how do I record a money-changing audit event" — `repos/HoneyDrunk.Audit/boundaries.md` (or the equivalent emitter conventions location in the repo's Architecture-side documentation) and the corresponding section in ADR-0030 (which already exists as a reference point for Audit-emitter conventions per the ADR's own follow-up list).

This is a docs/governance packet. No code, no .NET project, no catalog schema change.

## Scope
- `repos/HoneyDrunk.Audit/boundaries.md` — add a "Money-changing audit events" section documenting the D11 two-field convention. Include the JSON example, the `Money → Metadata["monetary_value"] + Metadata["currency_code"]` projection sketch, the rationale (flat-field queryability, backend-agnosticism), and the invariant that `monetary_value` is always a JSON string (precision discipline, mirroring ADR-0069 D9).
- `repos/HoneyDrunk.Audit/overview.md` — if the overview lists "what an emitter writes" or "what fields appear on an `AuditEntry`," add a one-line note pointing at the boundaries-file section for money-changing emits.
- `adrs/ADR-0030-grid-wide-audit-substrate.md` — if the ADR has an "Emitter Conventions" section (the ADR's "Follow-Up" list mentions emitter conventions), add a note referencing ADR-0069 D11. If no such section exists, add a brief paragraph under Consequences or as a new "Money-changing emit convention" subsection. **Do not flip ADR-0030's status; do not edit any of its decisions.** This is a referencing edit only.
- `catalogs/contracts.json` and `relationships.json` — **not edited.** The two-field convention is an emitter projection rule, not a new contract. `IAuditLog`/`AuditEntry` are unchanged.

## Proposed Implementation
1. **`repos/HoneyDrunk.Audit/boundaries.md`** — append a new section "Money-changing audit events (ADR-0069 D11)" containing:
   - A short rationale paragraph naming why money is split into two fields (flat-field queryability, backend-agnosticism, in-memory `Money` projection at emit time).
   - The JSON shape example (the block from ADR-0069 D11 — `event_type`, `tenant_id`, `monetary_value`, `currency_code`, `correlation_id`).
   - The mapping rule: emitter projects an in-memory `Money(amount, currency)` into `AuditEntry.Metadata` with two keys — `metadata["monetary_value"]` carrying `amount.ToString("F{currency-default-decimals}", InvariantCulture)` (a JSON-string-shaped value to match ADR-0069 D9 precision discipline), and `metadata["currency_code"]` carrying `currency.Code` (uppercase ISO 4217 alpha-3).
   - The discipline rule: `monetary_value` is **always** a string-shaped metadata value (Audit's `Metadata` is `string → string` so this is automatic, but flag it as the precision-preservation invariant for any future emitter that constructs the metadata dictionary).
   - A reference to the four currently-named example event types from ADR-0069 D7: `SubscriptionRenewed`, `RefundIssued`, `QuotaOverageBilled`, plus the generic "any audit event that records a monetary outcome." These are illustrative; the convention applies to all money-changing events.
2. **`repos/HoneyDrunk.Audit/overview.md`** — if it already enumerates emitter conventions or `AuditEntry.Metadata` patterns, add a single line: "Money-changing emits use the two-field convention — `monetary_value` + `currency_code` — see `boundaries.md` and ADR-0069 D11." If no such enumeration exists, skip this file edit.
3. **`adrs/ADR-0030-grid-wide-audit-substrate.md`** — add a brief paragraph noting the D11 cross-reference. Recommended location: a "Money-changing emit convention" subsection under Consequences or a paragraph appended to the existing emitter-conventions discussion. Wording should be of the form: *"Money-changing audit events use the two-field convention committed by ADR-0069 D11 — `monetary_value` (JSON string) and `currency_code` (ISO 4217 alpha-3 uppercase) — projected from the in-memory `Money` value at emit time. See ADR-0069 for the rationale and the precision-preservation discipline."* **Do not flip ADR-0030's status.** **Do not edit any of ADR-0030's decisions.** This is a cross-reference addition only.
4. **No code change.** `HoneyDrunk.Audit.Abstractions.AuditEntry.Metadata` is already `IReadOnlyDictionary<string, string>`. `IAuditLog` is unchanged. The ADR-0031-D8 contract-shape canary stays green.
5. **No catalog change.** `IAuditLog` and `AuditEntry` are already registered; the two-field convention is an emitter projection rule, not a new contract surface.

## Affected Files
- `repos/HoneyDrunk.Audit/boundaries.md`
- `repos/HoneyDrunk.Audit/overview.md` (only if a relevant enumeration exists)
- `adrs/ADR-0030-grid-wide-audit-substrate.md`

## NuGet Dependencies
None. This packet touches only Markdown documentation; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, boundary, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in `HoneyDrunk.Audit` — the two-field convention lands as `Metadata["monetary_value"]` + `Metadata["currency_code"]` against the existing `AuditEntry.Metadata : IReadOnlyDictionary<string, string>` shape.
- [x] No edit to any `IAuditLog`-bearing contract; the ADR-0031 D8 / invariant 49 contract-shape canary stays green.

## Acceptance Criteria
- [ ] `repos/HoneyDrunk.Audit/boundaries.md` has a "Money-changing audit events" section documenting the D11 two-field convention, with: (a) the rationale, (b) the JSON shape example, (c) the `Money → Metadata["monetary_value"] + Metadata["currency_code"]` projection rule, (d) the precision-preservation invariant for `monetary_value`
- [ ] `adrs/ADR-0030-grid-wide-audit-substrate.md` has a cross-reference paragraph noting the ADR-0069 D11 convention
- [ ] ADR-0030's Status is **unchanged** (this packet does not flip it; only the cross-reference is added)
- [ ] No decision in ADR-0030 is edited (only the cross-reference is added)
- [ ] No edit to `HoneyDrunk.Audit.Abstractions`, `AuditEntry`, `IAuditLog`, or any catalog file
- [ ] No invariant change (the convention is canary-class, not invariant-class — per packet 00's "On invariants" framing)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0069 D11 — Two-field convention.** Money-changing audit events use `monetary_value` (JSON string) + `currency_code` (ISO 4217 alpha-3 uppercase), top-level on the audit event, not nested. In-memory the emitter holds a `Money`; on-the-wire the audit substrate stores the two flat fields. The split is deliberate — query patterns and backend-agnosticism — and the in-memory-vs-on-wire mismatch mirrors the same shape-mismatch ADR-0030 already uses for tracing-vs-audit envelopes.

**ADR-0069 D9 (referenced) — Amount as JSON string.** `monetary_value` matches the precision-preservation discipline of D9 — always a string-shaped value, never a JSON number.

**ADR-0069 D7 (referenced) — Example money-changing events.** `SubscriptionRenewed`, `RefundIssued`, `QuotaOverageBilled` are the illustrative event types named by the ADR. The convention applies to every audit event that records a monetary outcome.

**ADR-0030 (referenced) — `IAuditLog`/`AuditEntry` shape unchanged.** The two-field convention lands as `Metadata["monetary_value"]` + `Metadata["currency_code"]` against the existing `AuditEntry.Metadata : IReadOnlyDictionary<string, string>`. No `IAuditLog` contract change.

**ADR-0031 D8 / invariant 49 (referenced) — Audit contract-shape canary.** "The HoneyDrunk.Audit Node CI must include a contract-shape canary for the full `HoneyDrunk.Audit.Abstractions` public surface. Shape drift on `IAuditLog`, `IAuditQuery`, `AuditEntry`, or the supporting query/category/outcome/target/change value types is a build failure unless paired with an intentional version bump." This packet does not modify any of those types, so the canary stays green.

## Constraints
- **No code change.** The convention is documentation only; the existing `AuditEntry.Metadata` map carries the two-field convention without any contract change.
- **Do not flip ADR-0030's Status.** This is a cross-reference addition to ADR-0030, not a re-acceptance.
- **Do not edit any ADR-0030 decision.** Add the cross-reference paragraph only.
- **Do not edit `catalogs/contracts.json` or `relationships.json`.** `IAuditLog`/`AuditEntry` are unchanged. The Audit Node's catalog entries stay as-is.
- **Do not add a new invariant.** Per packet 00's "On invariants" framing, ADR-0069's four conventions are canary-enforced; the audit projection convention is the emitter's responsibility, documented in the boundaries file, not numbered in `constitution/invariants.md`.
- **Precision discipline.** The `monetary_value` projection uses `Amount.ToString("F{decimals}", InvariantCulture)` so the metadata-value string carries the full decimal precision. Document this in the boundaries-file section.

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0069`, `wave-3`

## Agent Handoff

**Objective:** Document ADR-0069 D11's two-field convention for money-changing audit events in the Audit boundaries file and as a cross-reference in ADR-0030. No code change; no catalog change.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the projection rule discoverable for every emitter that records a monetary outcome — Billing (future), Notify Cloud (future), Web.Rest's subscription/refund endpoints (future), and any audit emit that records `SubscriptionRenewed`, `RefundIssued`, `QuotaOverageBilled`, or similar.
- Feature: ADR-0069 Currency Handling rollout, Wave 3 — audit-emitter convention.
- ADRs: ADR-0069 D11 (primary), ADR-0030 (audit substrate — cross-reference), ADR-0031 D8 / invariant 49 (Audit contract-shape canary stays green by construction — no contract change).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0069 Accepted before its D11 convention is documented as a live rule.

**Constraints:**
- No code change. The convention lands as `Metadata["monetary_value"]` + `Metadata["currency_code"]` against the existing `AuditEntry.Metadata` map. Do not touch `IAuditLog`, `AuditEntry`, or any catalog file.
- Do not flip ADR-0030's status; do not edit its decisions. Cross-reference only.
- Do not add a numbered invariant. Per packet 00, ADR-0069's conventions are canary-enforced; convention 4 (audit two-field shape) is an emitter responsibility documented in the boundaries file.
- `monetary_value` precision discipline: `Amount.ToString("F{decimals}", InvariantCulture)` so the metadata-value string preserves the full decimal precision — mirroring ADR-0069 D9.

**Key Files:**
- `repos/HoneyDrunk.Audit/boundaries.md`
- `adrs/ADR-0030-grid-wide-audit-substrate.md`
- `repos/HoneyDrunk.Audit/overview.md` (only if a relevant enumeration exists)

**Contracts:** None changed. `IAuditLog` and `AuditEntry` are unchanged. The ADR-0031 D8 / invariant 49 canary stays green.
