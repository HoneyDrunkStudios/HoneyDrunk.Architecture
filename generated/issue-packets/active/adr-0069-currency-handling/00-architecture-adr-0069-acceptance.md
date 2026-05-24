---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0069", "wave-1"]
dependencies: []
adrs: ["ADR-0069"]
accepts: ["ADR-0069"]
wave: 1
initiative: adr-0069-currency-handling
node: honeydrunk-architecture
---

# Accept ADR-0069 — flip status, register the initiative, record the four currency conventions

## Summary
Flip ADR-0069 (Currency Handling and Money Representation) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, and register the `adr-0069-currency-handling` initiative in `initiatives/active-initiatives.md`. ADR-0069 deliberately introduces **no new numbered Grid-wide invariants**; the four conventions it commits (currency code is always uppercase ISO 4217 alpha-3; no implicit FX conversion; JSON `amount` is a string, never a number; audit money fields are split into `monetary_value` + `currency_code`) are enforced by canary tests in the Kernel.Abstractions implementation packet, not by lines in `constitution/invariants.md`.

## Context
ADR-0069 was authored 2026-05-23 and commits the Grid's internal representation of monetary values: a `Money` record carrying `decimal Amount` and a validated `CurrencyCode`, arithmetic that throws on currency mismatch, banker's rounding as the default mode, multi-currency-aware-but-not-converting storage, USD as the default currency, machine-readable `ToString`, and a JSON serialization shape of `{"amount": "...", "currency": "..."}` with `amount` as a string. ADR-0026 D5 froze `BillingEvent` count-only; ADR-0069 D7 preserves that — `Money` is a separate, additive primitive in `HoneyDrunk.Kernel.Abstractions`, not a field on `BillingEvent`. ADR-0037 (Stripe) is the upstream price authority; ADR-0069 stores Stripe-derived monetary outcomes at the webhook boundary. ADR-0052's in-memory cost-rate cache is updated from implicit-`decimal` to explicit `Money(rate, CurrencyCode.Usd)` per D10. ADR-0030 audit emits adopt the D11 two-field convention.

The ADR decides:
- **D1** — `Money` is a `HoneyDrunk.Kernel.Abstractions` record carrying `decimal Amount` and a `CurrencyCode`. Naming rule: `Money` (record, no `I`); `CurrencyCode` is a `readonly record struct` validated at construction.
- **D2** — arithmetic operators throw `CurrencyMismatchException` on mismatch; comparisons across currencies also throw; no implicit FX; `Money.Zero(CurrencyCode)` is the only construction shortcut without an amount.
- **D3** — banker's rounding (`MidpointRounding.ToEven`) is the default for `Money.Round(int decimals, MidpointRounding mode = MidpointRounding.ToEven)`. `AwayFromZero` is supported as an explicit opt-in; truncation is deliberately *not* a `Money.Round` mode.
- **D4** — `CurrencyCode` validates an ISO 4217 alpha-3 code (uppercase) at construction. Seed list: USD, EUR, GBP, JPY, CAD, AUD, CHF. Unknown codes throw `UnknownCurrencyCodeException`. Per-currency metadata (default decimals — 2 for fiat, 3 for JOD/BHD/KWD/OMR/TND, 0 for JPY) lives alongside the codes.
- **D5** — multi-currency aware, not multi-currency converting; Stripe owns presentation and FX at the boundary; aggregate-revenue reporting that needs a single denomination converts at read-time and records timestamp + rate; the FX-rate service is out of scope and deferred to a future ADR.
- **D6** — default currency is USD (Florida-registered Studio); per-product non-USD defaults are PDR-overridable.
- **D7** — `BillingEvent` does **not** carry `Money` (ADR-0026 D5's frozen count-and-meter shape preserved). `Money` appears in invoice records, audit emits that record monetary outcomes, consumer-app price catalogs, the AI cost ledger, and Web.Rest payloads.
- **D8** — `Money.ToString()` returns a locale-independent, machine-readable string (`"123.45 USD"`). Locale-aware formatting lives at the presentation layer, reading the user's explicit locale preference.
- **D9** — JSON serialization shape: `{"amount": "123.45", "currency": "USD"}`. `amount` is a JSON string (precision preservation); `currency` is the ISO 4217 alpha-3 code uppercase; no `decimals` field. A System.Text.Json converter ships in `HoneyDrunk.Kernel.Abstractions`.
- **D10** — the ADR-0052 in-memory cost-rate cache is denominated in USD at Phase 1; the cache value type is updated to `Money(rate, CurrencyCode.Usd)`.
- **D11** — audit emits that record monetary outcomes use a two-field convention — `monetary_value` (JSON string) and `currency_code` (ISO alpha-3) — flat on the audit event, not nested. In-memory is `Money`; the emitter projects to the two fields.
- **D12** — explicitly deferred: FX-rate service, multi-currency tax handling (Stripe Tax owns), crypto/token currencies, historical FX rate storage, per-tenant currency preference, subunit/minor-unit storage, invoice/receipt UI.

ADR-0069 is a **policy / contract** ADR. The concrete code — `Money` and `CurrencyCode` in Kernel.Abstractions with arithmetic / rounding / serialization / canary suite, the AI Node cost-ledger migration to D10, the Audit emitter convention documentation, the Web.Rest converter wiring — lands in implementation packets (02–05). Catalog registration lands in packet 01. Every other packet references ADR-0069's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Required ADR Amendment to D2 — `==` is NOT overridden

ADR-0069 D2 reads "comparisons across currencies also throws" and explicitly cites `Money.Zero(USD) == Money.Zero(EUR)` as throwing. **The implementation in packet 02 drops the `==` throw and keeps record-default value equality.** The amendment, made at acceptance time:

- **`+`, `-`, scalar `*`, scalar `/`** — throw `CurrencyMismatchException` on cross-currency operands. Unchanged.
- **`<`, `<=`, `>`, `>=`** — throw `CurrencyMismatchException` on cross-currency operands. Unchanged.
- **`==`, `!=`** — **NOT overridden.** Record-default value equality stands. `Money(0m, USD) == Money(0m, EUR)` returns `false` (both fields are compared; currencies differ; result is `false`).

The reason for the amendment: overriding `==` on a record to throw breaks the .NET equality contract in places that should be safe. `Equals(object?)`, `GetHashCode()`, `HashSet<Money>`, `Dictionary<Money, T>`, EF Core change-tracking, and every implicit equality call in LINQ all hit `==` semantics. A throwing `==` would explode at a `Contains`, a dictionary lookup, a tracked-entity comparison — places where the caller has no way to anticipate that two values of different currencies happen to be in the same collection. The throw discipline belongs on arithmetic and ordering (where the operation is observable, intentional, and the caller is choosing to combine values), not on equality (which is silent and called everywhere).

Effect on ADR-0069: when scope rolls forward, the operator amends D2's "comparisons across currencies also throws" wording to "**ordering** comparisons across currencies throws; `==`/`!=` use record-default value equality (cross-currency `==` returns `false`)." This is recorded here as a follow-up ADR edit to apply alongside (or after) the acceptance flip; the implementation in packet 02 reflects the amended discipline.

## On invariants — none added; four conventions enforced by canaries

ADR-0069's Consequences/Invariants section is explicit: **"No new Grid-wide invariants are introduced."** Four implicit conventions are committed:

1. Currency code is always uppercase ISO 4217 alpha-3 (enforced at `CurrencyCode` construction in packet 02).
2. No implicit FX conversion (enforced by D2's currency-mismatch throw in packet 02).
3. JSON `amount` is a string, never a number (enforced by the `MoneyJsonConverter` shipped from `HoneyDrunk.Kernel` runtime in packet 02 — not `HoneyDrunk.Kernel.Abstractions`; the converter is runtime logic per invariant 1).
4. Audit money fields are split into `monetary_value` + `currency_code` (enforced at the emitter projection, documented in packet 04 against `repos/HoneyDrunk.Audit/` boundaries / ADR-0030 emitter conventions).

The ADR's own text reads: *"these read as conventions enforced by canary tests rather than new lines in `constitution/invariants.md`. If the scope agent judges any of them invariant-class at acceptance time, the numbering is added then; the proposed text here treats them as committed conventions."* This scope-time judgment is **no new numbered invariants** — packet 02's canary suite covers conventions 1, 2, 3 by construction; convention 4 is an Audit-emitter projection responsibility documented in packet 04 against the existing `IAuditLog` contract (which has not changed). If a later ADR or operator decides any of the four warrants a numbered invariant, it is appended then under the existing `## Audit Invariants` (for convention 4) or a new section (for conventions 1–3) — not in this packet.

## Scope
- `adrs/ADR-0069-currency-handling-and-money-representation.md` — flip `**Status:** Proposed` to `**Status:** Accepted`. **Also amend D2** to record that `==`/`!=` are NOT overridden (record-default value equality stands; the throw discipline applies to arithmetic and ordering comparisons only). See "Required ADR Amendment to D2" above. Either inline-edit D2's wording or append an "Amended at acceptance" note under the D2 paragraph — preserve the original text alongside the amendment so the audit trail is visible. Update D9's converter-placement line to read "ships in `HoneyDrunk.Kernel` (runtime)" not `HoneyDrunk.Kernel.Abstractions`, with an analogous "Amended at acceptance" note (the converter is runtime logic; invariant 1 keeps Abstractions free of it).
- `adrs/README.md` — update the ADR-0069 row Status column to Accepted.
- `initiatives/active-initiatives.md` — register the `adr-0069-currency-handling` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0069 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. **Amend D2** in the same ADR — record that `==`/`!=` are NOT overridden; the throw discipline applies to arithmetic (`+`/`-`) and ordering comparisons (`<`/`<=`/`>`/`>=`) only. Preserve the original wording with an "Amended at acceptance" note. Cross-reference the "Required ADR Amendment to D2" section in this packet for the rationale.
3. **Amend D9** in the same ADR — record that `MoneyJsonConverter` ships in `HoneyDrunk.Kernel` (runtime), not `HoneyDrunk.Kernel.Abstractions`. Preserve the original wording with an "Amended at acceptance" note.
4. Update the ADR-0069 index row in `adrs/README.md` to Accepted.
5. Do **not** edit `constitution/invariants.md`. ADR-0069's conventions are canary-enforced (see "On invariants" above).
6. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0069-currency-handling-and-money-representation.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0069 header reads `**Status:** Accepted`
- [ ] ADR-0069 D2 is amended (inline or "Amended at acceptance" note) to record that `==`/`!=` are NOT overridden; throw discipline applies to arithmetic and ordering comparisons only
- [ ] ADR-0069 D9 is amended (inline or "Amended at acceptance" note) to record that `MoneyJsonConverter` ships in `HoneyDrunk.Kernel` (runtime), not `HoneyDrunk.Kernel.Abstractions`
- [ ] The ADR-0069 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` is **not** modified in this packet (the four ADR-0069 conventions are canary-enforced, per the ADR's own framing)
- [ ] `initiatives/active-initiatives.md` registers the `adr-0069-currency-handling` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0069 D1 — `Money` placement.** A new public record `Money` lives in `HoneyDrunk.Kernel.Abstractions.Money`. Pinned shape: `public sealed record Money(decimal Amount, CurrencyCode CurrencyCode)`. `Money` is a record (drops the `I`); `CurrencyCode` is a `readonly record struct` (no `I`). Static helpers — `Money.Zero(CurrencyCode)`, `Money.Usd(decimal)`, `Money.Eur(decimal)`, etc.

**ADR-0069 Consequences — Invariants.** *"No new Grid-wide invariants are introduced. Implicit conventions that the implementation must hold: currency code is always uppercase ISO 4217 alpha-3; no implicit FX conversion; JSON `amount` is a string, never a number; audit money fields are split (`monetary_value` + `currency_code`). These read as conventions enforced by canary tests rather than new lines in `constitution/invariants.md`."*

**ADR-0026 D5 (referenced) — `BillingEvent` frozen shape.** The live `HoneyDrunk.Kernel.Abstractions/Tenancy/BillingEvent.cs` record carries `Units` (long) and `OperationKey` (string) as the count-and-meter fields (the ADR text says `Quantity`/`UnitOfMeasure` — the implementation diverged to `Units`/`OperationKey` and is the source of truth). No money type on the record. ADR-0069 D7 preserves the frozen shape — `Money` is a separate primitive, not a `BillingEvent` field. Acceptance of ADR-0069 does not trigger a `BillingEvent` major bump.

**ADR-0035 D1 / pre-1.0 disclaimer (referenced) — additive minor bump.** New `Money` and `CurrencyCode` public types in `HoneyDrunk.Kernel.Abstractions` are net-new surface, additive, no break — a minor bump on the pre-1.0 Kernel.Abstractions package. Packet 02 owns the bump.

## Constraints
- **Acceptance precedes flip.** ADR-0069 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Do not edit `constitution/invariants.md`.** ADR-0069 deliberately adds no numbered invariants; the four committed conventions are enforced by canary tests in the Kernel.Abstractions implementation packet (02) and by the audit-emitter projection documented in packet 04.
- **Do not modify `BillingEvent`.** ADR-0026 D5's frozen shape is preserved; ADR-0069 D7 is explicit on this. No change to `HoneyDrunk.Kernel.Abstractions.BillingEvent`.
- **Initiative slug ≤ 39 chars.** `adr-0069-currency-handling` is 26 chars — well within the limit. Do not lengthen.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0069`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0069 to Accepted and register the currency-handling initiative. Do not add any numbered invariants — the ADR's four conventions are canary-enforced.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0069 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0069 Currency Handling and Money Representation rollout, Wave 1.
- ADRs: ADR-0069 (primary), ADR-0026 (BillingEvent frozen shape — preserved), ADR-0035 (additive minor-bump policy — packet 02 owns the bump), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0069 stays Proposed until this PR merges.
- Do not edit `constitution/invariants.md`. The four conventions ADR-0069 commits are canary-enforced, not numbered invariants. If a later operator judges any of them invariant-class, it is appended then — not in this packet.
- Do not modify `BillingEvent` or any other existing Kernel.Abstractions surface (ADR-0069 is purely additive; ADR-0026 D5 stays frozen).

**Key Files:**
- `adrs/ADR-0069-currency-handling-and-money-representation.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
