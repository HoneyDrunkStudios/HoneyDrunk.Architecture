# ADR-0069: Currency Handling and Money Representation

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Core (Kernel.Abstractions) · Ops (first consumers: Billing, Notify Cloud) · cross-cutting

## If Accepted — Required Follow-Up Work in Architecture Repo

Accepting this ADR creates Kernel.Abstractions, Billing, and cross-Node obligations that must be completed as follow-up issue packets (do not accept and leave the catalogs stale):

- [ ] Kernel.Abstractions packet — introduce `Money` (record) and `CurrencyCode` (record struct or static-validated string wrapper, per D4) in `HoneyDrunk.Kernel.Abstractions.Money/`; ship the ISO 4217 alpha-3 validator with the major-currency seed list from D4
- [ ] Kernel.Abstractions packet — add canary tests pinning `Money` arithmetic, rounding mode (D3), serialization (D9), and the currency-mismatch throw behavior (D2)
- [ ] Kernel.Abstractions versioning — confirm with [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) D1 that this is a minor bump (new public types added, no existing surface change); pre-1.0 Kernel.Abstractions per ADR-0035's pre-1.0 disclaimer
- [ ] Billing packet — adopt `Money` in invoice records and any audit-event field that carries a monetary outcome (per D7 — `BillingEvent` does **not** carry `Money` directly)
- [ ] Audit packet — confirm the `monetary_value` + `currency_code` two-field convention for money-changing audit events per D11; update [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) emitter conventions documentation
- [ ] Cost-governance packet — confirm [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)'s in-memory cost-rate cache is denominated in USD per D10; document the FX conversion deferral
- [ ] Web.Rest / SDK packet — adopt the JSON serialization shape from D9 (`amount` as string, `currency` as ISO 4217 alpha-3); cross-reference [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D14-equivalent for serialization conventions
- [ ] Architecture packet — update [`catalogs/contracts.json`](../catalogs/contracts.json) with the new Kernel.Abstractions `Money` surface
- [ ] Scope agent flips Status → Accepted after the Kernel.Abstractions surface ships at 0.x with the canary suite passing

## Context

[ADR-0037](./ADR-0037-payment-and-billing-integration.md) picked Stripe as the Grid's sole payment processor. Stripe handles external currency presentation (Checkout/Customer Portal in the buyer's currency), multi-currency tax via Stripe Tax, and the FX conversion at the Stripe boundary. ADR-0037 does **not** decide how money is represented **inside** the Grid — every reference to monetary values in that ADR is either a Stripe identifier (price ID, subscription ID, customer ID) or implicit USD.

The current Grid state, audited at the time of this ADR:

- **`BillingEvent` (Kernel.Abstractions, frozen by [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D5)** — carries `Quantity` and `UnitOfMeasure` but no money type. The shape is a count-and-meter primitive, not a price primitive. ADR-0037 D2 confirms that the Stripe Meter Events endpoint is the destination and Stripe owns the price mapping. So far so consistent.
- **[ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) cost-rate cache** — names a cached per-model cost-rate table in the AI Node. The denomination is implicit; the cache is "cost in dollars per million tokens" without an explicit currency code. Today this is fine (the AI providers Stripe, OpenAI, Anthropic, etc. all bill in USD); tomorrow it is a bug waiting for a non-USD provider.
- **Audit emits that record monetary outcomes** (per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)) — "subscription renewed for $X," "refund issued for $Y," "credit applied for $Z" — have no committed convention for how the monetary value is recorded.
- **Consumer-app PDRs ([PDR-0003 Lately](../pdrs/PDR-0003-lately.md), [PDR-0005 Hearth](../pdrs/PDR-0005-hearth.md), [PDR-0006 Currents](../pdrs/PDR-0006-currents.md), [PDR-0007 Arcadia](../pdrs/PDR-0007-arcadia.md), [PDR-0008 Curiosities](../pdrs/PDR-0008-curiosities.md))** — every consumer-app PDR includes a paid tier or subscription price. Today there is no Grid-side place those prices live; tomorrow each consumer app invents a `decimal price` field with no currency code.
- **Revenue dashboards and finance-relevant reports** — the simplest revenue report ("how much did Notify Cloud earn in May") needs a money type. Today it would use `decimal` directly.

Without an ADR, each Node will use `decimal` directly with no currency code, and the first multi-currency event (or first audit-of-money emission) will be painful. The cost of letting drift accumulate across N Nodes is N rewrites later. The first multi-currency surface — likely a non-US Notify Cloud tenant who pays in EUR via Stripe's local-currency presentation — surfaces this gap in the worst possible place (the billing pipe).

The forcing functions for deciding this now:

- **Notify Cloud GA** is the first commercial product that emits money-changing events. The audit shape for "subscription renewed for $X" is needed before the first paying tenant signs up.
- **The cost-governance cache ([ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md))** is operationally live in the AI Node today with an implicit-USD denomination. The fix is cheap now; the fix is expensive once a non-USD provider lands.
- **Consumer-app PDRs are pre-implementation.** The first consumer-app PDR that scaffolds a price catalog needs the money type already to exist; deferring this ADR until then bundles substrate work into the feature packet.
- **[ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) precedent.** The Grid's pattern is to commit cross-cutting primitives in Kernel.Abstractions once, not invent them per Node. `Money` is the same shape of primitive as `TenantId` and follows the same playbook.

This ADR commits the internal representation, the arithmetic semantics, the serialization shape, the multi-currency stance, and the cost-ledger denomination.

## Decision

### D1. `Money` is a Kernel.Abstractions record carrying `decimal Amount` and a `CurrencyCode`

A new public record `Money` lives in `HoneyDrunk.Kernel.Abstractions.Money` (or a similarly-named namespace settled by the implementation packet). Pinned shape:

```csharp
public sealed record Money(decimal Amount, CurrencyCode CurrencyCode)
{
    // Arithmetic operators (D2) throw on currency mismatch.
    // Static helpers — Money.Zero(CurrencyCode), Money.Usd(decimal), Money.Eur(decimal), etc.
    // ToString() returns "123.45 USD" (machine-readable, locale-independent — D8).
}
```

The Grid-wide naming rule (per `project_naming_rule_records`) holds: it is `Money`, not `IMoney`. It is a record (drops the `I`); arithmetic methods on the type are static-or-instance helpers, not interface members.

**Why `decimal Amount` rather than `long` minor units:**

- **.NET-idiomatic.** `decimal` is the .NET primitive for monetary arithmetic; the BCL's monetary patterns assume it. Pulling in `long` minor units introduces a foreign convention that every consumer site must remember and convert.
- **Fractional-currency support.** Some currencies (Bahraini dinar, Tunisian dinar) have three minor-unit decimals, not two. Some currencies (gold-tied tokens, future crypto) have more. `decimal` supports arbitrary fractional precision up to 28-29 significant digits; `long` minor units requires an explicit per-currency minor-unit count and conversion math everywhere.
- **Serialization correctness.** Decimal serialization as a string (D9) preserves precision; `long` minor units require the consumer to also know the minor-unit divisor. The two-field shape `(amount, currency)` is self-contained.
- **Fewer arithmetic bugs.** Minor-unit arithmetic ("multiply by 100, then divide by 100") is a well-known source of off-by-one rounding errors. Decimal arithmetic with explicit `D3` rounding (per D3 below) is more legible and less bug-prone.
- **Stripe boundary conversion.** Stripe's wire format is minor units (cents for USD, etc.). The conversion to/from minor units happens **at the Stripe adapter boundary** in `HoneyDrunk.Billing.Stripe` (per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D2 / D9), not in `Money` itself. The Grid's internal representation is decimal; the wire format with Stripe is minor units; the adapter handles the conversion.

**Why a value type / record over two raw fields (`decimal Amount` + `string CurrencyCode`):**

- **Currency mismatch is a compile-time-aware concern.** A `Money(123.45m, "USD") + Money(67.89m, "EUR")` should be a runtime error (per D2). Two raw fields make it trivially easy to add two amounts from different currencies and get a meaningless `decimal` back; a `Money` record makes the operation throw.
- **Single value to thread through interfaces.** A `decimal` + `string` pair on every method signature is noise; a `Money` parameter is one. Refactoring a price-receiving method to be currency-aware later (e.g., add a `decimal` and forget the `string`) is a known regression pattern; the single-type shape forecloses it.
- **Audit-event field convention can still split it on the wire.** D11 commits that audit events use two fields (`monetary_value` + `currency_code`) for queryability, even though the in-memory type is a record. The on-the-wire shape and the in-memory shape are deliberately different where audit query patterns favor the split.

### D2. `Money` arithmetic throws on currency mismatch — no implicit FX

`Money` ships arithmetic operators (`+`, `-`, scalar `*`, scalar `/`) and comparison operators (`==`, `!=`, `<`, `<=`, `>`, `>=`). Every binary operator that takes two `Money` operands **throws** `CurrencyMismatchException` if the two operands' `CurrencyCode` values differ.

```csharp
var usd = new Money(100m, CurrencyCode.Usd);
var eur = new Money(50m, CurrencyCode.Eur);
var sum = usd + eur; // throws CurrencyMismatchException
```

Scalar operations (`Money * decimal`, `Money / decimal`) preserve the currency code:

```csharp
var tax = new Money(100m, CurrencyCode.Usd) * 0.07m; // Money(7.00m, USD)
```

Comparison across currencies also throws:

```csharp
var isMore = usd > eur; // throws CurrencyMismatchException
```

**No implicit FX conversion.** A `Money(100m, USD) + Money(50m, EUR)` is not a meaningful operation without a conversion rate, a conversion timestamp, and a source for the rate. Performing the conversion implicitly would either pin to a hardcoded rate (silently wrong over time) or require a runtime FX service call from inside an arithmetic operator (architecturally wrong — operators should not do I/O). The caller must convert one operand to the other's currency explicitly via an FX service; the FX service does not yet exist in the Grid (D5).

**`Money.Zero(CurrencyCode)`** is the only construction shortcut that does not require an amount; it is useful for accumulator patterns. `Money.Zero` without a currency is **not provided** — zero in what? The currency-mismatch rule still applies to zero values; `Money.Zero(USD) == Money.Zero(EUR)` throws.

### D3. Rounding mode — banker's rounding (`MidpointRounding.ToEven`) is the default

Monetary arithmetic in the Grid uses **banker's rounding** (`MidpointRounding.ToEven`, .NET's default for `decimal.Round`) as the default rounding mode. The default is exposed as a method:

```csharp
public Money Round(int decimals, MidpointRounding mode = MidpointRounding.ToEven);
```

The `decimals` parameter:

- **Fiat currencies** default to 2 decimal places (`Round(2)` is the most common call site).
- **Three-decimal currencies** (Bahraini dinar, Tunisian dinar, Omani rial — JOD, BHD, KWD, OMR, TND) default to 3. The default-decimals lookup is part of the `CurrencyCode` validator in D4.
- **Crypto / token currencies** (if the Grid ever supports them) use a higher precision; the per-currency default is set in the validator.

**Why banker's rounding:**

- **Stripe uses it.** Stripe's documented rounding behavior is banker's rounding for monetary operations. Aligning the Grid with the upstream billing system reduces "the invoice line and the Grid-side audit emit are off by $0.01" reconciliation work.
- **.NET default.** `decimal.Round(value, decimals)` without a mode argument is banker's rounding. The Grid's choice aligns with the language default; consumers writing arithmetic do not have to remember "set the mode."
- **Statistically unbiased.** Over many rounding operations, banker's rounding does not introduce a systematic upward or downward bias the way HalfAwayFromZero does. Useful in aggregate-revenue reporting where rounding bias accumulates.

**`HalfAwayFromZero` (traditional accounting rounding) is supported as an explicit opt-in.** Callers that need traditional accounting rounding (e.g., an invoice line that the customer sees, where banker's rounding of `$0.025 → $0.02` reads as "you charged me less than the math says") pass `MidpointRounding.AwayFromZero` explicitly. The default-vs-explicit split is documented at the `Round` method.

**Truncation (financial pessimism, always round down for the customer)** is **not** a supported rounding mode at the `Money.Round` level. Callers that want truncation use `Math.Floor` on the underlying `decimal` and reconstruct a `Money` — the deliberate awkwardness signals that truncation is an unusual choice. Stripe Tax handles truncation behavior on the buyer-facing invoice; the Grid does not.

### D4. ISO 4217 validation — `CurrencyCode` is a validated value

`CurrencyCode` is a small value type (record struct or static-validated string wrapper) that holds an ISO 4217 alpha-3 currency code (uppercase). Construction validates against a known list:

```csharp
public readonly record struct CurrencyCode(string Code)
{
    public CurrencyCode(string code)
        : this(Validate(code)) { }

    private static string Validate(string code) { /* throws if invalid */ }

    public static readonly CurrencyCode Usd = new("USD");
    public static readonly CurrencyCode Eur = new("EUR");
    public static readonly CurrencyCode Gbp = new("GBP");
    public static readonly CurrencyCode Jpy = new("JPY");
    public static readonly CurrencyCode Cad = new("CAD");
    public static readonly CurrencyCode Aud = new("AUD");
    public static readonly CurrencyCode Chf = new("CHF");
    // ... extensible
}
```

**Seed list of supported currencies at Phase 1** (the realistic set for a Florida-registered studio at MVP):

- **USD** — United States Dollar (the default per D6)
- **EUR** — Euro
- **GBP** — Pound Sterling
- **JPY** — Japanese Yen (zero decimals)
- **CAD** — Canadian Dollar
- **AUD** — Australian Dollar
- **CHF** — Swiss Franc

**Construction with an unknown code throws** `UnknownCurrencyCodeException` at the point of construction. The validator is open to extension — adding a currency is a Kernel.Abstractions minor bump per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) D4 (new enum-like values are additive). The fail-fast posture forecloses "we got a malformed currency code from a downstream system and silently treated it as USD."

**Where the validator lives:** in Kernel.Abstractions, as a static list. The list is small (the Grid does not need ISO 4217's full 180-currency catalog at MVP) and tightly maintained. The case for pulling in a third-party currencies NuGet package is reconsidered if the Grid genuinely needs the long tail (e.g., the studio expands into emerging markets); at MVP, a hand-maintained list is the cheapest viable choice.

**Each currency's metadata** — default decimal places, currency symbol (where unambiguous; the validator deliberately does not promise that the symbol uniquely identifies the currency — multiple currencies share `$`), display name — lives alongside the `CurrencyCode` definitions. The metadata is used by D3's `Round` default-decimals lookup and (optionally) by D8's display formatter.

### D5. Multi-currency stance — the Grid is multi-currency aware but not multi-currency converting

The Grid stores monetary values **in the currency the event was denominated in** at the point of the event. No conversion-at-write happens.

- **Stripe owns currency presentation.** Customers see prices in their local currency via Stripe Checkout / Customer Portal. Stripe Tax handles VAT / GST / sales tax at the buyer's jurisdiction.
- **Stripe owns FX at the boundary.** When a EUR-paying customer settles an invoice, Stripe converts (or holds the EUR balance) according to the Studio's Stripe configuration. The Grid receives a webhook event with the **settled currency and amount**, and stores that as `Money(amount, currency)` — the original-denomination record.
- **No FX conversion inside the Grid.** A subscription invoice in EUR is stored as `Money(123.45m, CurrencyCode.Eur)` in the Billing buffer (per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D2). It does not get converted to USD at write time, ever.
- **Aggregate-revenue reporting that requires a single denomination** (e.g., "total May revenue in USD-equivalent") performs the FX conversion **at read time**, against an FX rate service (not yet committed by any ADR — out of scope here), and **records the conversion's timestamp and rate** alongside the converted value. The original `Money` is preserved; the converted value is a derivative.

This stance — multi-currency aware, multi-currency converting deferred — is the cheapest viable approach for the Studio's scale and matches Stripe's own internal model. The FX-rate service is a future-state concern triggered by the first revenue dashboard that needs unified denomination; the trigger is not present today.

### D6. Default currency — USD

For products with a single fixed price, the **default currency is USD**. The Studio is registered in Florida (per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D6 and `project_azure_decisions` for the entity context). USD is the Studio's primary denomination; revenue dashboards and the operator-facing finance surfaces present in USD by default.

Stripe Tax handles non-US buyer presentation; the Stripe Checkout flow shows the buyer their local currency where Stripe's locale detection succeeds. The **Grid-side price record** is still USD.

PDRs that justify a non-USD default for a specific product override the default in their PDR text (e.g., a consumer app launched in the EU first might denominate in EUR). The default is not a hard rule; it is the no-PDR-override fallback.

### D7. `BillingEvent` does **not** carry `Money` — the split between meter events and invoice records

[ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) D5 froze `BillingEvent`'s shape with `Quantity` and `UnitOfMeasure` but no money type. This ADR **preserves that shape**.

**Why `BillingEvent` stays count-and-meter, not money:**

- **Stripe owns the price.** Per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D2, `BillingEvent` is the upstream meter input. The downstream Stripe Meter Events endpoint multiplies the count by the per-meter price (configured in Stripe) to produce invoice lines. The Grid does not duplicate the price; the meter event is purely a count.
- **The price changes; the count does not.** A tier reprice in Stripe should not invalidate historical `BillingEvent` records. If `BillingEvent` carried a price, every reprice would have to either fork the meter event schema or stale-pin to the old price. Keeping `BillingEvent` count-only avoids that.
- **Source of truth is Stripe for monetary outcomes.** The invoice line in Stripe is the system of record for "what was the customer billed." The Grid's audit emit (per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)) records the monetary outcome **as seen in the Stripe webhook**, not as computed by the Grid.
- **No additive bump required for [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md).** Because `BillingEvent` is unchanged, the frozen shape stays intact. `Money` is purely additive new surface in Kernel.Abstractions; this ADR does not bump `BillingEvent`'s shape and does not trigger a Kernel.Abstractions major version per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) D1.

**Where `Money` appears:**

- **Invoice records** in `HoneyDrunk.Billing` (after the Stripe webhook lands). The invoice carries `Money` per line item and per total.
- **Audit events that record monetary outcomes** — `SubscriptionRenewed { tenant_id, monetary_value, currency_code, ... }`, `RefundIssued { ..., monetary_value, currency_code, ... }`, `QuotaOverageBilled { ..., monetary_value, currency_code, ... }`. Per D11 the wire shape is two fields; the in-memory type held by the emitter is `Money`.
- **Consumer-app price catalogs** (PDR-0003 through PDR-0008). Each consumer app's price catalog carries `Money` per product variant.
- **Internal cost ledger** (per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md), per D10 below).
- **Public API payloads** that surface prices to the client (e.g., a Notify Cloud `GET /v1/account/tier` response that includes the tier's monthly price). Per D9 the JSON shape is `{"amount": "...", "currency": "..."}`.

### D8. Display formatting — `Money.ToString()` is machine-readable, locale-aware formatting lives at the presentation layer

`Money.ToString()` returns a **locale-independent, machine-readable** string:

```csharp
new Money(123.45m, CurrencyCode.Usd).ToString()  // "123.45 USD"
new Money(1234.5m,  CurrencyCode.Eur).ToString()  // "1234.50 EUR"
new Money(1000m,    CurrencyCode.Jpy).ToString()  // "1000 JPY"
```

Format rules:

- Amount uses invariant culture (`.` decimal separator, no thousands separators).
- Amount is formatted to the currency's default decimal places (per D4 metadata).
- Currency code is uppercase ISO 4217 alpha-3, separated from the amount by a single space.

**Why machine-readable, not locale-aware, by default:**

- **Logs, audit emits, telemetry, debug output.** Every internal write of a `Money` to a log line should be unambiguous and grep-able. Locale-aware output (`$123.45` vs. `123,45 €`) is operator-confusing and locale-dependent.
- **Round-trip parseable.** A future `Money.Parse("123.45 USD")` can reconstruct the original value; locale-aware output cannot.
- **Distinct from presentation formatting.** Customer-facing displays — the Studio website, mobile app price labels, invoice PDFs — use a separate presentation-layer formatter that consults the user's locale preference and the currency's symbol metadata. The presentation-layer formatter reads the user's stored preference (explicit) or defaults to a culture-neutral form like `Money.ToString()` if no preference is recorded.

**The presentation layer's locale-aware formatter** lives outside `Money` (in Web.Rest, in the mobile SDK, in the per-product UI). It is not a Kernel concern. The Grid's discipline (per `feedback_default_cheapest_azure_tier`-style "no infer from headers") is that the presentation layer reads the user's **explicit** locale preference; inference from `Accept-Language` alone is a fallback, not the default.

### D9. JSON serialization — `amount` as a string, `currency` as the ISO code

The committed JSON shape for `Money` in API payloads and any persisted JSON record:

```json
{
  "amount": "123.45",
  "currency": "USD"
}
```

Field rules:

- **`amount` is a JSON string, not a JSON number.** JSON's number type is a double-precision float in many parsers; precision loss on decimal amounts (especially for crypto-scale precision or for currencies like JPY where the amount can grow into the millions without decimals) is a known correctness bug. The string shape forecloses the precision-loss class entirely.
- **`currency` is the ISO 4217 alpha-3 code, uppercase.**
- **No `decimals` or `precision` field.** The currency code implies the decimals (per D4 metadata); the consumer that wants to render the amount in a specific number of decimal places looks up the currency's metadata.

The shape is committed as the canonical SDK-side parsing target per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D8. SDK clients deserialize `Money` to their language-idiomatic equivalent (a .NET `Money` record, a Python `decimal.Decimal` + currency string, a JavaScript object with `amount` as a `BigDecimal`-equivalent or string).

System.Text.Json converter for `Money` ships in Kernel.Abstractions; the converter handles both serialization and deserialization with the shape above. Custom converters (e.g., a converter that emits `amount` as a number for legacy clients) are not provided — drift on the shape would break SDK clients per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md).

### D10. Cost ledger is USD; FX conversion at read-time if and when a non-USD provider appears

[ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)'s in-memory cost-rate cache is **denominated in USD** at Phase 1. The cache value type is updated to `Money` (rather than raw `decimal`), with `CurrencyCode.Usd` as the implicit constructor.

The current AI providers (OpenAI, Anthropic, Azure OpenAI, etc.) all bill in USD. The discipline is to record the denomination explicitly (as `Money(rate, CurrencyCode.Usd)`) rather than relying on the implicit assumption — this forecloses the "we added a EUR-billed provider and silently treated its rates as USD" bug.

If and when a non-USD-billed provider appears, the cost-rate cache holds the provider's rates in their billing currency. The cost ledger's aggregate (e.g., "total spend this month") performs FX conversion at read time against an FX-rate service (not yet committed — D5's deferred concern). The conversion's timestamp and rate are recorded with the aggregate.

This matches D5's multi-currency-aware-but-not-converting stance: the Grid stores in the source currency, converts at the boundary when an aggregate requires it.

### D11. Audit shape for money-changing events — two fields, not one serialized `Money`

[ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) audit emits that record monetary outcomes use a **two-field convention**:

```json
{
  "event_type": "SubscriptionRenewed",
  "tenant_id": "01HXXX...",
  "monetary_value": "29.99",
  "currency_code": "USD",
  "correlation_id": "..."
}
```

Field rules:

- **`monetary_value`** — the amount as a JSON string (matching D9's serialization discipline for precision preservation).
- **`currency_code`** — the ISO 4217 alpha-3 code, uppercase.
- The two fields are top-level on the audit event, not nested inside a `money` object.

**Why two fields, not one nested object:**

- **Audit-query patterns favor flat fields.** A query like "total monetary outcomes for tenant X in USD this month" reads `monetary_value` and `currency_code` as separate columns / fields. A nested object requires JSON-path queries on every audit-store backend, which are slower and more backend-specific.
- **Backend-agnostic.** The audit substrate per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) does not commit a specific backend; SQL, Cosmos, and search-index backends all favor flat fields for indexability.
- **In-memory and on-the-wire shapes are deliberately different.** The in-memory type held by the emitter is `Money`; the on-the-wire / on-disk shape in audit is the two flat fields. The emitter is responsible for the projection. This is the same shape of deliberate-mismatch that ADR-0010 / [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) already use for tracing-vs-audit envelopes.

### D12. Out of scope

The following are explicitly **not** decided by this ADR:

- **FX rate service.** The Grid does not commit an FX-rate source today. When the first multi-currency aggregate is needed (likely a revenue dashboard), an FX-rate ADR commits the provider (a candidate is open.er-api.com, ECB rates, or a paid service like Open Exchange Rates) and the conversion-timestamp discipline.
- **Multi-currency tax handling.** Stripe Tax owns this per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D6. The Grid does not compute VAT, GST, or sales tax internally.
- **Crypto / token currency support.** `Money` is decimal-flexible enough to support arbitrary precision, but the Grid does not commit a crypto-billing posture today. If the consumer-app PDRs ever introduce token-denominated transactions, a follow-up ADR amends `CurrencyCode`'s validator to add the relevant token codes (and likely commits a separate "tokens are not fiat" boundary discipline).
- **Historical FX rate storage.** If aggregate revenue reporting needs reproducibility ("what did the May 2026 EUR→USD conversion produce on the day the report was first generated?"), a historical-FX-rate store is needed. Deferred until the requirement materializes.
- **Per-tenant currency preference.** Today, the buyer's currency is determined by Stripe at checkout. A future "I want to see my invoices in CAD even though I pay in USD" tenant preference is a deferred concern.
- **Subunit / minor-unit storage.** Per D1 the Grid stores in major units (`decimal`); the conversion to minor units happens at the Stripe adapter boundary. No part of the Grid persists `long` minor units.
- **Invoice PDF generation, receipt formatting, customer-facing payment UI.** Stripe Checkout and Customer Portal own this per [ADR-0037](./ADR-0037-payment-and-billing-integration.md) D1 / D7. The Grid does not generate invoices.

## Consequences

### Affected Nodes

- **HoneyDrunk.Kernel.Abstractions** — gains `Money` (record) and `CurrencyCode` (record struct) in a new namespace. Additive surface; per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) D1 a minor bump on the pre-1.0 Kernel.Abstractions package.
- **HoneyDrunk.Kernel** — gains the System.Text.Json converter for `Money` (per D9) and any reference implementations (e.g., `Money.Round`, `Money.Zero`, arithmetic operators). Additive.
- **HoneyDrunk.Billing** — adopts `Money` in invoice records, the Stripe-webhook-derived monetary fields, and the buffer's per-event monetary outcomes (the count-only `BillingEvent` is unchanged; the *invoice record* downstream of the Stripe webhook carries `Money`).
- **HoneyDrunk.Notify.Cloud** — adopts `Money` in the tenant tier-price field (`NotifyCloudTenantTier`'s monthly base fee). Per [ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md) D5 the tier's price is *configured in Stripe*; the Grid-side mirror is informational, and `Money` is the type.
- **HoneyDrunk.Audit** — adopts the two-field convention from D11 for money-changing audit events. The emitter side projects `Money` into `monetary_value` + `currency_code`.
- **HoneyDrunk.AI** (cost-governance cache per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md)) — adopts `Money` in the cost-rate cache value type. USD-only at Phase 1 per D10.
- **HoneyDrunk.Web.Rest** — adopts the D9 JSON serialization shape for any Money-carrying response.
- **Consumer-app Nodes** (PDR-0003 through PDR-0008, designed but not yet scaffolded) — adopt `Money` in their price catalogs and subscription state.
- **catalogs/contracts.json** — gains a `Money` entry under Kernel.Abstractions.

### Invariants

No new Grid-wide invariants are introduced. Implicit conventions that the implementation must hold:

- **Currency code is always uppercase ISO 4217 alpha-3.** Enforced at `CurrencyCode` construction per D4.
- **No implicit FX conversion.** Enforced by D2's currency-mismatch throw.
- **JSON `amount` is a string, never a number.** Enforced by the System.Text.Json converter in Kernel.Abstractions.
- **Audit money fields are split (`monetary_value` + `currency_code`).** Enforced at the emitter projection per D11.

These read as **conventions enforced by canary tests** rather than new lines in `constitution/invariants.md`. If the scope agent judges any of them invariant-class at acceptance time, the numbering is added then; the proposed text here treats them as committed conventions.

### Reconciliation with prior ADRs

- **[ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md) `BillingEvent` shape.** Per D7, **no additive bump** is required. `BillingEvent` stays count-and-meter; `Money` is a separate primitive that lives alongside, not inside, the billing-event surface. The frozen shape is preserved.
- **[ADR-0037](./ADR-0037-payment-and-billing-integration.md) Stripe boundary.** D2's "Stripe owns the price" stance is reinforced. The Grid stores Stripe-derived monetary outcomes as `Money(amount, currency)` at the webhook boundary; no internal price computation duplicates Stripe.
- **[ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md) cost-rate cache.** Per D10, the cache value type is updated from implicit-`decimal` to explicit `Money(rate, CurrencyCode.Usd)`. The change is operationally invisible at Phase 1 (USD-only) but forecloses the silent-USD-assumption class of bugs.
- **[ADR-0030](./ADR-0030-grid-wide-audit-substrate.md) emitter conventions.** Per D11, money-changing audit emits use the two-field convention. Audit's own catalog documentation is updated; no contract change to `IAuditLog`.
- **[ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) compatibility.** The new `Money` and `CurrencyCode` types are net-new public surface in Kernel.Abstractions. Per D1 of ADR-0035 this is a minor bump on a pre-1.0 package, which carries no compatibility promise. The Kernel.Abstractions canary suite extends to cover the new surface and its arithmetic / serialization invariants.

### Operational Consequences

- **Every monetary value across the Grid now needs a currency code.** Existing places where a raw `decimal` was used as money (the cost cache, the implicit-USD consumer-app stubs, any audit emit that records a monetary value) are migrated to `Money`. The migration is mechanical (each call site picks `CurrencyCode.Usd` as the default per D6) but is real work.
- **Banker's rounding may produce results that differ from the customer's mental model.** $0.025 rounds to $0.02 under banker's rounding (even); a customer expecting traditional accounting rounding might read this as "I was undercharged." Mitigation: customer-facing invoices use Stripe's own rounding behavior (which is also banker's), so the discrepancy never reaches the customer at the surface. Internal aggregates use banker's; customer-facing presentations match Stripe.
- **The seed currency list (D4) is small.** Adding a currency requires a Kernel.Abstractions minor bump and a canary test. This is intentional friction — currencies should not be added speculatively — but does mean a new market entry has a small substrate-side cost.
- **Multi-currency aggregates require FX conversion that the Grid does not yet provide.** Today: there is no Grid-side need (USD-only). Tomorrow: the first non-USD revenue line triggers the FX-rate-service ADR.
- **The two-field audit convention (D11) means audit-query consumers join `monetary_value` and `currency_code` separately.** The query convenience favors this; the in-memory `Money` round-trip favors a single object. The split is deliberate.

### Follow-up Work

- Kernel.Abstractions ships `Money` and `CurrencyCode` with the seed list, validator, arithmetic / rounding / serialization behavior, and the canary suite.
- Kernel ships the System.Text.Json converter and any helpers (`Money.Zero(CurrencyCode)`, etc.).
- Billing adopts `Money` in invoice records and Stripe-webhook-derived monetary fields.
- AI Node cost-rate cache migrates to `Money(rate, CurrencyCode.Usd)` per D10.
- Audit catalog documents the D11 two-field convention; emitters that record monetary outcomes adopt it.
- Web.Rest adopts the D9 JSON serialization shape; the SDK templates per [ADR-0057](./ADR-0057-public-http-api-versioning-and-client-sdk-strategy.md) D8 carry the same shape.
- Consumer-app PDRs (PDR-0003 through PDR-0008) adopt `Money` in their price-catalog scaffolding (when scaffolding lands; the ADR pre-stages the type for them).
- Watch list: FX-rate-service ADR (triggered by the first non-USD aggregate requirement); per-tenant currency preference (triggered by the first customer who asks).

## Alternatives Considered

### `decimal` + ISO 4217 string code as two separate fields (no value type)

Considered. Every method that takes money takes two parameters; every record that holds money has two fields. No new Kernel.Abstractions primitive.

Rejected. The currency-mismatch throw is impossible without a value type — `decimal + decimal` always succeeds, with the bug being silent on cross-currency addition. The refactoring path (add a `decimal`, forget the currency string) is a known regression pattern. The single-type shape is cheaper to maintain across the Grid's lifetime.

### `long` minor-units + ISO 4217 string code (Stripe's wire format)

Considered. Stripe's API uses minor units; mirroring the wire format internally avoids the boundary conversion.

Rejected per D1's rationale. .NET-idiomatic decimal handling, fractional-currency support, fewer arithmetic bugs, cleaner serialization. The boundary conversion at the Stripe adapter is cheap and isolated; pushing it across the entire Grid would be more expensive.

### `Money` as a struct (not a record)

Considered. A `readonly struct` for stack allocation and zero-allocation arithmetic.

Rejected on legibility grounds. Records compose more naturally with the rest of the Grid's value-type idioms (`TenantId`, `CorrelationId`, `BillingEvent`, etc.). The performance benefit of struct allocation is not measurable at the Grid's scale; the legibility benefit of record syntax is real. The seed list of `CurrencyCode.Usd`, `CurrencyCode.Eur`, etc. is a `record struct` per D4 — the small-value type *is* a struct where the allocation matters.

### Default rounding mode is `MidpointRounding.AwayFromZero` (traditional accounting)

Considered. "Round half up" is the traditional accounting convention and the most intuitive for non-statistician users.

Rejected per D3's rationale — Stripe uses banker's rounding, .NET's `decimal.Round` default is banker's rounding, and statistical unbiasedness matters in aggregate. Traditional accounting rounding is supported as an explicit opt-in (`MidpointRounding.AwayFromZero`) for the small set of contexts where it is wanted (customer-facing invoice lines if those ever bypass Stripe).

### Multi-currency conversion at write time (always store in USD)

Considered. Convert every monetary value to USD at the moment it is recorded; the Grid is internally USD-only.

Rejected per D5. Conversion at write time pins the conversion rate to the moment of write, which is wrong for revenue reporting (the rate at "now" is not the rate at "the end of the reporting period"). Conversion at write time also loses the original currency, which is wrong for compliance (tax obligations are in the original currency for the buyer's jurisdiction). Multi-currency aware (store in source, convert at read) is the right boundary.

### Include `Money` directly inside `BillingEvent`

Considered. `BillingEvent` already carries `Quantity` and `UnitOfMeasure`; adding `Money` makes it a complete metered-revenue event.

Rejected per D7. Stripe owns the price; `BillingEvent` is the meter input, not the meter output. Including `Money` would either duplicate Stripe (and stale on reprice) or require the Grid to compute prices that Stripe already computes. The split — meter event count-only, invoice line money-bearing — is the right boundary. Additionally, this preserves [ADR-0026](./ADR-0026-grid-multi-tenant-primitives.md)'s frozen `BillingEvent` shape without requiring a major bump.

### Use a third-party money / currency NuGet package

Considered. Packages like `NodaMoney` or `Money.NET` exist and provide a `Money` type with similar shape.

Rejected for the Grid's scale. The Grid's `Money` is ~200 lines of straightforward C#; a third-party dependency would pull in features the Grid does not need (full ISO 4217 catalog, locale-aware formatting at the type level, FX conversion adapters) and would couple the Grid's monetary discipline to an external maintenance cadence. The Kernel-owned implementation is the cheapest viable maintenance posture and aligns with the Grid's "tight surface, hand-maintained" stance on cross-cutting primitives. Reconsidered if and when a Grid Node needs features the local implementation does not provide.

### Locale-aware `Money.ToString()` by default (use `CultureInfo`)

Considered. `Money.ToString()` reads `CultureInfo.CurrentCulture` and produces a locale-formatted string by default.

Rejected per D8. The Grid is a server-side product whose `CultureInfo.CurrentCulture` is meaningless (the server's culture, not the user's). Locale-aware default formatting produces server-locale output everywhere, which is misleading. Machine-readable default formatting (`"123.45 USD"`) is unambiguous, log-friendly, and round-trip parseable. Locale-aware presentation is the presentation layer's job, with the user's explicit preference as input.
