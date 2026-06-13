---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Kernel
labels: ["feature", "tier-2", "core", "adr-0069", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0069"]
wave: 2
initiative: adr-0069-currency-handling
node: honeydrunk-kernel
---

# Add Money, CurrencyCode, and the JSON converter to HoneyDrunk.Kernel.Abstractions

## Summary
Add the ADR-0069 currency-handling surface to `HoneyDrunk.Kernel.Abstractions`: the `Money` record (carrying `decimal Amount` and a `CurrencyCode`), the `CurrencyCode` record struct with ISO 4217 alpha-3 validation and per-currency metadata, the arithmetic / comparison operators that throw on currency mismatch, the `Round` method with banker's rounding default, the machine-readable `ToString`, the `MoneyJsonConverter` (System.Text.Json), the two exception types (`CurrencyMismatchException`, `UnknownCurrencyCodeException`), and a canary test suite pinning arithmetic, rounding, serialization, currency-mismatch behavior, and validator behavior. This is the version-bumping packet for the `HoneyDrunk.Kernel` solution.

## Context
ADR-0069 commits the Grid's internal representation of monetary values: a `Money` record carrying `decimal Amount` and a validated `CurrencyCode`. The placement (per D1) is `HoneyDrunk.Kernel.Abstractions` because Kernel is the zero-dependency contract layer every Node already consumes — the same placement precedent as `TenantId`, `CorrelationId`, and `BillingEvent`. ADR-0026 D5 froze `BillingEvent` count-only; ADR-0069 D7 preserves that frozen shape — `Money` is a **separate, additive primitive** in Kernel.Abstractions, not a field on `BillingEvent`. The Stripe boundary (ADR-0037) converts to/from minor units at the Stripe adapter; the Grid's internal representation is `decimal` (D1's rationale).

`HoneyDrunk.Kernel` is a live Node currently at v0.7.0 (.NET 10.0), two packages: `HoneyDrunk.Kernel.Abstractions` (zero-dependency contracts) and `HoneyDrunk.Kernel` (runtime). This packet is the **first packet on the `HoneyDrunk.Kernel` solution in this initiative** — per invariant 27 it bumps every non-test `.csproj` to the same new minor version (`0.7.0` → `0.8.0` — additive new types, no break). Confirm the current solution version at edit time — if another initiative has already bumped past `0.7.0`, take the next minor over whatever is on `main`.

**Cross-initiative version-bump note (ADR-0042 race).** ADR-0042 (Idempotency Contract — `adr-0042-idempotency`) also targets the `HoneyDrunk.Kernel` solution and is sequenced as a `0.7.0` → `0.8.0` minor bump. Both ADR-0042 packet 02 and **this** packet bump the Kernel solution from `0.7.0` to `0.8.0` independently — they are racing on the same version. Coordination procedure for the executor at edit time:

1. Read `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` to determine the live source-of-truth version.
2. Read `repos/HoneyDrunk.Kernel/active-work.md` (in `HoneyDrunk.Architecture`) — the cross-initiative coordinator file that tracks in-progress version windows on the Kernel solution.
3. **Case A — Kernel is still `0.7.0`:** this packet opens the `0.8.0` version entry on every `CHANGELOG.md` (repo-level and `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` and `HoneyDrunk.Kernel/CHANGELOG.md`). Bump every non-test `.csproj` to `0.8.0`. Record "opened 0.8.0" in the PR description and update `active-work.md`.
4. **Case B — Kernel is already `0.8.0` and unreleased (ADR-0042 landed first):** append this packet's surface (`Money`, `CurrencyCode`, `MoneyJsonConverter`, the two exception types) to the in-progress `0.8.0` CHANGELOG entries. No version-bump commit needed (already at `0.8.0`). Record "appended to in-progress 0.8.0" in the PR description.
5. **Case C — Kernel `0.8.0` has been tagged/released:** take the next minor (`0.9.0`). Open a new version entry on every CHANGELOG, bump every non-test `.csproj` to `0.9.0`. Record "took 0.9.0" in the PR description and update `active-work.md`.

The two initiatives are independent in content (idempotency contract surface vs currency primitive); the only coupling is solution-version sequencing.

System.Text.Json is part of the BCL — using it in Kernel.Abstractions does not introduce a HoneyDrunk runtime dependency. Per invariant 1, only `Microsoft.Extensions.*` abstractions are permitted; System.Text.Json is fine because it is the BCL serializer (no foreign package), and `JsonConverter<T>` lives in `System.Text.Json` not `Microsoft.Extensions.*`. Read this as an intentional carve-out for serialization concerns — the converter is a contract artifact, shipped alongside the type, mirroring how `TenantId` ships its own JSON handling.

## Scope
- `HoneyDrunk.Kernel.Abstractions` — new contract types:
  - `Money` — `public sealed record Money(decimal Amount, CurrencyCode CurrencyCode)`. Operators (`+`, `-`, scalar `*`, scalar `/`, `<`, `<=`, `>`, `>=`). **No `==`/`!=` override** — record-default value equality stands. Static factories (`Money.Zero(CurrencyCode)`, `Money.Usd(decimal)`, `Money.Eur(decimal)`, etc.). Instance methods (`Round`, `ToString`). **No `[JsonConverter]` attribute** (Abstractions stays STJ-free).
  - `CurrencyCode` — `public readonly record struct CurrencyCode`. Construction validates ISO 4217 alpha-3 (uppercase) against the seed list (D4). Per-currency metadata: default decimals (2 for fiat, 3 for JOD/BHD/KWD/OMR/TND, 0 for JPY), display name, optional currency symbol. Static well-known values: `CurrencyCode.Usd`, `Eur`, `Gbp`, `Jpy`, `Cad`, `Aud`, `Chf`.
  - `CurrencyMismatchException` — `public sealed class CurrencyMismatchException : InvalidOperationException`. Thrown by `Money` arithmetic and comparison operators on currency mismatch (D2).
  - `UnknownCurrencyCodeException` — `public sealed class UnknownCurrencyCodeException : ArgumentException`. Thrown by `CurrencyCode` construction with an unknown code (D4).
  - `MoneyJsonConverter` — `public sealed class MoneyJsonConverter : JsonConverter<Money>`. **Lives in `HoneyDrunk.Kernel` (runtime), not `HoneyDrunk.Kernel.Abstractions`** — System.Text.Json converters are serialization logic, and invariant 1 keeps Abstractions to contracts (`Microsoft.Extensions.*` + BCL types only; no runtime serialization classes). Implements the D9 shape: read/write `{"amount": "string", "currency": "USD"}`. Callers register it explicitly via `JsonSerializerOptions.Converters.Add(new MoneyJsonConverter())`. No `[JsonConverter]` attribute on `Money` (which lives in Abstractions and must stay free of STJ runtime types).
- All non-test `.csproj` files in the solution version-bumped together (one commit, invariant 27).
- `HoneyDrunk.Kernel.Abstractions` package `CHANGELOG.md` and `README.md` updated.
- Repo-level `CHANGELOG.md` gets a new version entry.
- Canary test suite (per ADR-0069's follow-up list, item 2): the canary lives wherever the existing Kernel.Abstractions canary suite lives (`HoneyDrunk.Kernel.Tests` for now; per ADR-0047 the long-term home is `*.Tests.Canaries`), pinning:
  - `Money` arithmetic (sum/diff/scalar-mul/scalar-div preserves currency; cross-currency `+`/`-`/comparison throws `CurrencyMismatchException`)
  - `Money.Zero(CurrencyCode)` semantics; `Money.Zero(USD) == Money.Zero(EUR)` returns `false` via record-default equality — see "Required ADR Amendment to D2" in packet 00; the ADR's "throws on cross-currency `==`" wording is dropped because overriding the record `==` operator to throw breaks `HashSet<Money>`, `Dictionary<Money>`, and EF change-tracking equality (any consumer that hashes/compares `Money` values across currencies would explode at a `GetHashCode`/`Equals` call site that should be safe)
  - `Round(2, MidpointRounding.ToEven)` banker's-rounding result on documented boundary cases (e.g. `12.025m → 12.02m`); `Round(2, AwayFromZero)` traditional-accounting result for the same input
  - Per-currency default decimals via `CurrencyCode` metadata (JPY = 0, USD = 2, JOD = 3 in the test data — JOD is acceptable to test against even though it is not in the Phase-1 seed list, by adding it to the test-only validator; or restrict the test to seed-list currencies)
  - JSON round-trip via `MoneyJsonConverter` produces `{"amount": "123.45", "currency": "USD"}` with `amount` as a **string**, deserializes back to a `Money` with the same `Amount` and `CurrencyCode` (D9)
  - JSON deserialization where `amount` is a JSON number rejects with a deserialization exception (D9: "amount is a JSON string, not a JSON number")
  - `CurrencyCode("usd")` and `CurrencyCode("ZZZ")` both throw `UnknownCurrencyCodeException` (case-sensitivity and unknown-code rejection per D4)
  - `Money.ToString()` produces `"123.45 USD"`, `"1234.50 EUR"`, `"1000 JPY"` (invariant culture, currency-default decimals, single-space separator per D8)

## Proposed Implementation
1. **`CurrencyCode`** — `public readonly record struct CurrencyCode`. One field, the validated uppercase code. Constructor calls a static validator that checks the input is in the seed list (`USD`, `EUR`, `GBP`, `JPY`, `CAD`, `AUD`, `CHF`); reject input with `UnknownCurrencyCodeException` on mismatch. Per-currency metadata lives in a static table keyed by code: each entry holds default decimals, display name, optional symbol. Expose `DefaultDecimals` and `DisplayName` as read-only properties on `CurrencyCode` (lookup-on-read). Static well-known values: `CurrencyCode.Usd`, `Eur`, `Gbp`, `Jpy`, `Cad`, `Aud`, `Chf` (per D4). The validator is small and hand-maintained — no third-party currencies package (per D4's "hand-maintained list is the cheapest viable choice" and the Alternatives Considered rejection).

2. **`Money`** — `public sealed record Money(decimal Amount, CurrencyCode CurrencyCode)`. Implement:
   - **Operators** — `+`, `-` (both throw `CurrencyMismatchException` if operands' `CurrencyCode` differ); scalar `*` and `/` taking a `decimal` (preserve the operand's currency); `<`, `<=`, `>`, `>=` throw `CurrencyMismatchException` on cross-currency operands per D2. **`==` / `!=` are NOT overridden** — record-default value equality stands. `Money(0m, USD) == Money(0m, EUR)` is `false` (both fields are compared; currency differs; result is `false`). This is a deliberate departure from the ADR's "comparison across currencies throws" wording for `==`: overriding `==` to throw would break `HashSet<Money>`, `Dictionary<Money>`, EF change-tracking equality, and every implicit `Equals`/`GetHashCode` call site that should be safe (these never throw on built-in record types, and an unobservable hashing operation throwing would cascade in places impossible to predict). The throw discipline is preserved where it belongs — arithmetic and ordering comparisons (`<`/`<=`/`>`/`>=`) — and is recorded in packet 00 as a **Required ADR Amendment to D2**. XML-doc `Money` and `==` to note the deliberate choice and reference the amendment.
   - **Static factories** — `Money.Zero(CurrencyCode)`, `Money.Usd(decimal)`, `Money.Eur(decimal)`, `Money.Gbp(decimal)`, `Money.Jpy(decimal)`, `Money.Cad(decimal)`, `Money.Aud(decimal)`, `Money.Chf(decimal)`. No `Money.Zero` without a currency (per D2 — "zero in what?").
   - **`Round(int decimals, MidpointRounding mode = MidpointRounding.ToEven)`** — banker's rounding default per D3. The `decimals` argument is mandatory; provide a `Round()` overload that picks the currency's default-decimals from the `CurrencyCode` metadata.
   - **`ToString()`** — return `$"{Amount.ToString($"F{CurrencyCode.DefaultDecimals}", CultureInfo.InvariantCulture)} {CurrencyCode.Code}"` per D8. Example outputs: `"123.45 USD"`, `"1234.50 EUR"`, `"1000 JPY"`.
   - XML-doc every public member (invariant 13).
   - **Do NOT annotate `Money` with `[JsonConverter(typeof(MoneyJsonConverter))]`.** Adding `[JsonConverter]` to a type in `HoneyDrunk.Kernel.Abstractions` would require `MoneyJsonConverter` to live in Abstractions — and a System.Text.Json converter is **runtime serialization logic**, not a contract. Per invariant 1, Abstractions is contract-only. `MoneyJsonConverter` ships in the `HoneyDrunk.Kernel` runtime package (see step 5 below); callers register it explicitly via `JsonSerializerOptions.Converters.Add(...)`. Packet 05 wires it into `HoneyDrunk.Web.Rest`'s `JsonOptionsDefaults.Configure`.

3. **`CurrencyMismatchException`** — `public sealed class CurrencyMismatchException : InvalidOperationException`. Constructor takes the two mismatched `CurrencyCode` values; message reads `"Cannot operate on Money values with mismatched currencies: {left} vs {right}. No implicit FX conversion is performed (ADR-0069 D2)."`.

4. **`UnknownCurrencyCodeException`** — `public sealed class UnknownCurrencyCodeException : ArgumentException`. Constructor takes the offending string code; message reads `"'{code}' is not a recognized ISO 4217 alpha-3 currency code in the Grid's seed list (ADR-0069 D4)."`.

5. **`MoneyJsonConverter`** — `public sealed class MoneyJsonConverter : JsonConverter<Money>`. **Located in the `HoneyDrunk.Kernel` runtime package** (`HoneyDrunk.Kernel/Serialization/MoneyJsonConverter.cs` or the repo's existing serialization folder; create one if absent). Keeping STJ runtime classes out of `HoneyDrunk.Kernel.Abstractions` preserves invariant 1 (Abstractions has no runtime classes; STJ converters are runtime logic, even if `System.Text.Json` itself is in the BCL). Callers consume `MoneyJsonConverter` by referencing `HoneyDrunk.Kernel` (the runtime) and registering it explicitly in their `JsonSerializerOptions` — packet 05 does this in `HoneyDrunk.Web.Rest.AspNetCore.Serialization.JsonOptionsDefaults.Configure`.
   - `Write` emits `{"amount": "{Amount as string, invariant culture, currency-default decimals}", "currency": "{Code}"}`.
   - `Read` parses `amount` as a JSON string and rejects JSON-number `amount` values with a `JsonException`. Parse the string via `decimal.Parse(s, NumberStyles.Number, CultureInfo.InvariantCulture)`; parse `currency` via `new CurrencyCode(s)` (which throws on invalid). Field order in JSON is not significant.

6. **Canary tests** — add to the existing test project (per the repo's convention). At least the cases listed in the "Scope" section above. Pin the conventions ADR-0069 commits as canaries (ISO 4217 alpha-3 uppercase, no implicit FX, JSON `amount` as string).

7. **Version bump** — bump every non-test `.csproj` in `HoneyDrunk.Kernel/HoneyDrunk.Kernel.slnx` to the new minor. **At edit time, read `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` to determine the current source-of-truth version**; if it is still `0.7.0`, bump to `0.8.0`; if ADR-0042's packet 02 has already landed and the solution is at `0.8.0`, append this initiative's surface to the in-progress `0.8.0` CHANGELOG entry rather than opening a new version (invariant 27's "one solution-wide bump per release window"); if `0.8.0` has been tagged/released, take the next minor (`0.9.0`). Coordinate via `repos/HoneyDrunk.Kernel/active-work.md` — both ADR-0042 and ADR-0069 are racing on the same Kernel solution version, so check that coordinator before opening or appending a CHANGELOG version entry. Record which case applied in the PR description. Add a repo-level CHANGELOG entry. Add a per-package CHANGELOG entry to `HoneyDrunk.Kernel.Abstractions` (real changes — `Money`, `CurrencyCode`, the two exception types). Add a per-package CHANGELOG entry to `HoneyDrunk.Kernel` (real change — `MoneyJsonConverter` ships in the runtime package, see step 5).

8. Update `HoneyDrunk.Kernel.Abstractions/README.md` — the public API surface gained the currency primitives; document them in the public-API section.

## Affected Files
- `HoneyDrunk.Kernel.Abstractions/` — new contract type files (one per type per the repo's existing file-per-type convention): `Money.cs`, `CurrencyCode.cs`, `CurrencyMismatchException.cs`, `UnknownCurrencyCodeException.cs`, plus the per-currency metadata table.
- `HoneyDrunk.Kernel/` — new `MoneyJsonConverter.cs` (in a serialization folder); converter lives in the runtime package, not Abstractions (invariant 1).
- `HoneyDrunk.Kernel.Abstractions/HoneyDrunk.Kernel.Abstractions.csproj` — version bump.
- `HoneyDrunk.Kernel/HoneyDrunk.Kernel.csproj` — version bump (now a real-change bump — adds `MoneyJsonConverter`).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `HoneyDrunk.Kernel.Abstractions/README.md`.
- `HoneyDrunk.Kernel/CHANGELOG.md` — entry for `MoneyJsonConverter`.
- Repo-level `CHANGELOG.md`.
- `repos/HoneyDrunk.Kernel/active-work.md` (in `HoneyDrunk.Architecture` — the cross-initiative coordinator) — referenced for the ADR-0042 race; updated if the executor lands first vs. appends.
- `HoneyDrunk.Kernel.Tests` — canary test suite for `Money`, `CurrencyCode`, arithmetic, rounding, JSON serialization, validator.

## NuGet Dependencies
- **`HoneyDrunk.Kernel.Abstractions`** — no new HoneyDrunk `PackageReference`. Per invariant 1, Abstractions takes only `Microsoft.Extensions.*` abstractions; the BCL is implicit. `Money` and `CurrencyCode` do **not** reference `System.Text.Json` at all (no `[JsonConverter]` attribute) — STJ stays out of Abstractions. `HoneyDrunk.Standards` is already referenced (`PrivateAssets: all`).
- **`HoneyDrunk.Kernel`** — no new `PackageReference`. `System.Text.Json` is in the BCL framework reference (`net10.0`); `MoneyJsonConverter` consumes `JsonConverter<T>` from the BCL — no package added.
- The unit-test project follows the repo's existing test stack; no new packages introduced.

## Boundary Check
- [x] `Money`, `CurrencyCode`, and the JSON converter are Kernel contracts per ADR-0069 D1/D9. The ADR's explicit placement maps here.
- [x] No dependency on any other HoneyDrunk runtime package (invariant 4 — DAG; Kernel at the root).
- [x] No modification of `BillingEvent` (ADR-0026 D5 frozen shape; ADR-0069 D7 explicit).
- [x] No modification of existing Kernel public types.

## Acceptance Criteria
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `Money` as a `public sealed record Money(decimal Amount, CurrencyCode CurrencyCode)`
- [ ] `HoneyDrunk.Kernel.Abstractions` exposes `CurrencyCode` as a `public readonly record struct` with construction-time ISO 4217 alpha-3 validation against the D4 seed list (USD, EUR, GBP, JPY, CAD, AUD, CHF)
- [ ] `CurrencyCode` exposes `DefaultDecimals` and `DisplayName` from the per-currency metadata table
- [ ] Static well-known `CurrencyCode` values (`Usd`, `Eur`, `Gbp`, `Jpy`, `Cad`, `Aud`, `Chf`) are present
- [ ] `Money` ships arithmetic operators (`+`, `-`, scalar `*`, scalar `/`) that throw `CurrencyMismatchException` on cross-currency operands
- [ ] `Money` ships ordering operators (`<`, `<=`, `>`, `>=`) that throw `CurrencyMismatchException` on cross-currency operands
- [ ] `Money` does **NOT** override `==`/`!=`; record-default value equality stands (cross-currency `==` returns `false`, never throws — preserves `HashSet<Money>` / `Dictionary<Money>` / EF tracking semantics; recorded as Required ADR Amendment to D2 in packet 00)
- [ ] `Money.Zero(CurrencyCode)` exists; `Money.Zero` without a currency does NOT exist
- [ ] `Money.Round(int decimals, MidpointRounding mode = MidpointRounding.ToEven)` uses banker's rounding by default; the `AwayFromZero` opt-in works; `Truncate`/`Math.Floor` is NOT exposed as a `Round` mode
- [ ] `Money.ToString()` returns locale-independent `"123.45 USD"`-style output using invariant culture and the currency's default decimal places
- [ ] `MoneyJsonConverter` reads/writes `{"amount": "string", "currency": "USD"}`; `amount` is **always** a JSON string; `amount` as a JSON number rejects with `JsonException`
- [ ] `MoneyJsonConverter` lives in `HoneyDrunk.Kernel` (runtime), NOT `HoneyDrunk.Kernel.Abstractions` — invariant 1 keeps Abstractions STJ-free
- [ ] `Money` is NOT annotated with `[JsonConverter(typeof(MoneyJsonConverter))]` (would force the converter into Abstractions); callers register the converter explicitly in their `JsonSerializerOptions`
- [ ] `CurrencyMismatchException` and `UnknownCurrencyCodeException` are public, sealed, and inherit from `InvalidOperationException` / `ArgumentException` respectively
- [ ] `BillingEvent` is NOT modified (ADR-0026 D5 frozen shape preserved per ADR-0069 D7)
- [ ] All new public types have XML documentation (invariant 13)
- [ ] `HoneyDrunk.Kernel.Abstractions` has zero new runtime `PackageReference` on any HoneyDrunk package (invariant 1) and zero references to `System.Text.Json` types (no `[JsonConverter]` attribute, no converter class)
- [ ] Every non-test `.csproj` in the solution is at the same new minor version in one commit (invariant 27). At edit time the executor checks `HoneyDrunk.Kernel.csproj`'s version and `repos/HoneyDrunk.Kernel/active-work.md` — if ADR-0042 has already opened `0.8.0`, this packet appends to that in-progress version entry rather than opening a new one
- [ ] Repo-level `CHANGELOG.md` has a new (or appended) version entry dated to the merge, listing the currency-handling surface
- [ ] `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md` has an entry describing `Money`, `CurrencyCode`, and the two exception types
- [ ] `HoneyDrunk.Kernel/CHANGELOG.md` has an entry describing `MoneyJsonConverter` (real change — converter lives in the runtime package)
- [ ] `HoneyDrunk.Kernel.Abstractions/README.md` documents the new currency-handling surface in the public-API section
- [ ] The canary test suite pins: arithmetic & currency-mismatch throw; rounding mode behavior; `ToString` output; JSON serialization shape (amount-as-string, currency-as-ISO-uppercase); JSON deserialization rejects amount-as-number; `CurrencyCode` validation (lowercase rejected, unknown code rejected)
- [ ] The `pr-core.yml` tier-1 gate and the Kernel contract-shape canary pass — the new contracts are additive, paired with the version bump

## Human Prerequisites
None. (Per the dispatch plan: a human releases the `HoneyDrunk.Kernel` package after this packet merges so downstream consumers — AI Node in packet 03, Web.Rest in packet 05 — can compile against the new version. That release step is captured in the Wave 2→3 handoff and in packet 03's Human Prerequisites, not here.)

## Referenced ADR Decisions
**ADR-0069 D1 — `Money` shape and placement.** `public sealed record Money(decimal Amount, CurrencyCode CurrencyCode)` in `HoneyDrunk.Kernel.Abstractions`. Static helpers — `Money.Zero(CurrencyCode)`, `Money.Usd(decimal)`, etc. `ToString()` returns `"123.45 USD"` (machine-readable, locale-independent). Records drop the `I`.

**ADR-0069 D2 (with amendment) — currency-mismatch arithmetic throws.** `+`, `-` (cross-currency) throw `CurrencyMismatchException`; scalar `*`/`/` preserve currency; **ordering** comparison (`<`/`<=`/`>`/`>=`) across currencies throws; `Money.Zero(CurrencyCode)` is the only construction shortcut without an amount. **Amendment (recorded in packet 00):** the ADR's "`==` across currencies throws" wording is dropped — `==`/`!=` are NOT overridden, record-default value equality stands (cross-currency `==` returns `false`). Overriding record `==` to throw would break `HashSet<Money>`, `Dictionary<Money>`, EF tracking, and every implicit `Equals`/`GetHashCode` call; the throw discipline stays on arithmetic and ordering, where it is observable and intentional.

**ADR-0069 D3 — banker's rounding default.** `Round(int decimals, MidpointRounding mode = MidpointRounding.ToEven)`. Default is banker's rounding. `AwayFromZero` is an explicit opt-in for traditional accounting rounding. Truncation is not supported as a `Round` mode — `Math.Floor` on `Amount` + reconstruct is the deliberate-awkwardness path.

**ADR-0069 D4 — `CurrencyCode` validation.** ISO 4217 alpha-3, uppercase, validated against a hand-maintained seed list (USD, EUR, GBP, JPY, CAD, AUD, CHF). Per-currency metadata: default decimals (2 for fiat, 3 for JOD/BHD/KWD/OMR/TND, 0 for JPY), display name. Unknown codes throw `UnknownCurrencyCodeException`. Adding a currency is a Kernel.Abstractions minor bump (additive enum-like value per ADR-0035 D4).

**ADR-0069 D8 — `ToString` is machine-readable.** Invariant culture, no thousands separators, amount formatted to the currency's default decimals, currency code uppercase, single-space separator. Round-trip parseable. Locale-aware formatting lives at the presentation layer.

**ADR-0069 D9 — JSON serialization.** `{"amount": "123.45", "currency": "USD"}`. `amount` is a JSON string (precision preservation); `currency` is uppercase ISO alpha-3; no `decimals` field. `MoneyJsonConverter` ships in `HoneyDrunk.Kernel` (runtime) as the canonical converter — **not** in `HoneyDrunk.Kernel.Abstractions` (invariant 1 keeps Abstractions free of runtime classes). The ADR's "ships in `HoneyDrunk.Kernel.Abstractions`" wording is corrected here on placement; the shape and discipline are unchanged.

**ADR-0069 D7 — `BillingEvent` unchanged.** `BillingEvent` carries `Quantity` and `UnitOfMeasure` only; no `Money` field added. ADR-0026 D5's frozen shape is preserved.

**ADR-0026 D5 (referenced) — `BillingEvent` is count-and-meter.** Frozen shape. The live `HoneyDrunk.Kernel.Abstractions/Tenancy/BillingEvent.cs` record carries `Units` (long) and `OperationKey` (string) for the count-and-meter fields (the ADR text says `Quantity`/`UnitOfMeasure` — the implementation diverged to `Units`/`OperationKey` and is the source of truth). Do not modify.

**ADR-0035 D1 / pre-1.0 disclaimer (referenced) — minor bump.** New `Money`/`CurrencyCode` public surface is additive; minor bump on the pre-1.0 Kernel.Abstractions package.

## Constraints
- **Invariant 1 — Abstractions have zero runtime dependencies AND zero runtime logic.** `HoneyDrunk.Kernel.Abstractions` carries `Money`, `CurrencyCode`, and the two exception types (contracts and value-type construction validators). It does **NOT** carry `MoneyJsonConverter` (that is runtime serialization logic) and `Money` is **NOT** annotated with `[JsonConverter]` (which would force the converter into Abstractions). `MoneyJsonConverter` ships in `HoneyDrunk.Kernel` (runtime). System.Text.Json is BCL, but the converter class is logic — invariant 1 separates the two.
- **Invariant 4 — DAG.** Kernel is at the root. No reference to any other HoneyDrunk runtime package.
- **Invariant 13 — XML docs on every public API.** Enforced by `HoneyDrunk.Standards` analyzers.
- **Invariant 27 — all projects in a solution share one version.** Every non-test `.csproj` in the solution gets the same minor bump in one commit. Partial bumps are forbidden. Confirm current solution version at edit time — if another initiative (e.g. ADR-0042) has already moved past `0.7.0`, take the next minor over `main`'s actual state.
- **Invariant 12 — per-package CHANGELOGs only for packages with functional changes.** `HoneyDrunk.Kernel.Abstractions` gets an entry (`Money`, `CurrencyCode`, exceptions); `HoneyDrunk.Kernel` gets an entry (`MoneyJsonConverter` — real change, the converter now ships from the runtime package).
- **Records drop the `I`.** `Money`, `CurrencyCode` are records / record structs — no `I` prefix.
- **`BillingEvent` is untouched.** ADR-0026 D5 frozen; ADR-0069 D7 explicit. Do not amend the `BillingEvent` record or its catalog entry.
- **No `Money.Zero` (no-arg).** D2 forbids zero-without-currency. `Money.Zero(CurrencyCode)` is the only shortcut without an amount.
- **No truncation as a `Round` mode.** D3 — callers wanting truncation use `Math.Floor` on `Amount` and reconstruct, deliberately awkward.
- **No third-party currency package.** D4 alternatives — `NodaMoney`, `Money.NET` and similar are rejected at the Grid's scale. Hand-maintained seed list only.

## Labels
`feature`, `tier-2`, `core`, `adr-0069`, `wave-2`

## Agent Handoff

**Objective:** Add `Money`, `CurrencyCode`, `MoneyJsonConverter`, the two exception types, the arithmetic/rounding/serialization surface, and the canary tests to `HoneyDrunk.Kernel.Abstractions`. Bump the `HoneyDrunk.Kernel` solution to the next minor version.

**Target:** `HoneyDrunk.Kernel`, branch from `main`.

**Context:**
- Goal: Ship the currency-handling primitive every other packet in this initiative depends on.
- Feature: ADR-0069 Currency Handling and Money Representation rollout, Wave 2 (the foundation).
- ADRs: ADR-0069 D1/D2/D3/D4/D7/D8/D9 (primary), ADR-0026 D5 (BillingEvent unchanged), ADR-0035 (additive minor bump), ADR-0008 (packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0069 Accepted before its contracts are built against it.

**Constraints:**
- Abstractions stay zero-HoneyDrunk-dependency and zero-runtime-logic (invariant 1). `Money` carries no `[JsonConverter]` attribute; `MoneyJsonConverter` lives in `HoneyDrunk.Kernel` (runtime), not Abstractions.
- Records drop the `I`; `Money` and `CurrencyCode` are records / record structs.
- `BillingEvent` is NOT modified — ADR-0026 D5 frozen shape preserved per ADR-0069 D7.
- Bump every non-test `.csproj` in the solution in one commit (invariant 27). At edit time, check `HoneyDrunk.Kernel.csproj`'s current version and `repos/HoneyDrunk.Kernel/active-work.md` for the ADR-0042 race (see Context section, three-case procedure). Record which case applied in the PR description.
- Do **NOT** override `==` / `!=` on `Money`. Record-default value equality stands — cross-currency `==` returns `false`, never throws. Overriding would break `HashSet<Money>`, `Dictionary<Money>`, EF equality, every implicit `Equals`/`GetHashCode`. The throw discipline stays on arithmetic (`+`/`-`) and ordering (`<`/`<=`/`>`/`>=`). Packet 00 records this as a **Required ADR Amendment to D2**.
- JSON `amount` is **always** a string; reject `amount` as a JSON number on deserialize (D9 precision discipline).
- No `Money.Zero` (no-arg) — D2 forbids zero-without-currency. No truncation as a `Round` mode — D3. No third-party currency package — D4.

**Key Files:**
- `HoneyDrunk.Kernel.Abstractions/` — new files for `Money`, `CurrencyCode`, `CurrencyMismatchException`, `UnknownCurrencyCodeException`, per-currency metadata table. **No** `MoneyJsonConverter` here.
- `HoneyDrunk.Kernel/` — new `MoneyJsonConverter.cs` (in a serialization folder).
- `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`, `README.md`; `HoneyDrunk.Kernel/CHANGELOG.md`; repo-level `CHANGELOG.md`.
- `repos/HoneyDrunk.Kernel/active-work.md` (Architecture repo) — read for the ADR-0042 race coordination; update with the chosen case.
- Every non-test `.csproj` for the version bump.
- `HoneyDrunk.Kernel.Tests` — canary suite for `Money` arithmetic, rounding, JSON, validator.

**Contracts:**
- `Money` (new record in `HoneyDrunk.Kernel.Abstractions`) — `(decimal Amount, CurrencyCode CurrencyCode)`. Arithmetic + ordering operators / static factories / `Round` / `ToString`. No `==` override; no `[JsonConverter]` attribute.
- `CurrencyCode` (new record struct in `HoneyDrunk.Kernel.Abstractions`) — ISO 4217 alpha-3 validated. Per-currency metadata. Static well-known values.
- `CurrencyMismatchException`, `UnknownCurrencyCodeException` (new exception types in `HoneyDrunk.Kernel.Abstractions`).
- `MoneyJsonConverter` (new class in `HoneyDrunk.Kernel` runtime, NOT Abstractions) — System.Text.Json converter for the D9 shape; callers register explicitly.
