# Handoff — Wave 2 → Wave 3: Consumer Adoption (AI cost ledger, Audit convention, Web.Rest converter)

**Initiative:** `adr-0069-currency-handling`
**Wave transition:** Wave 2 (Money in Kernel.Abstractions) → Wave 3 (consumer adoption)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 and Wave 2 landed

- **Packet 00** — ADR-0069 flipped to **Accepted**. **No numbered invariants added.** ADR-0069's four committed conventions (currency code is always uppercase ISO 4217 alpha-3; no implicit FX conversion; JSON `amount` is a string, never a number; audit money fields are split into `monetary_value` + `currency_code`) are canary-enforced per the ADR's own framing — not numbered in `constitution/invariants.md`. If a later operator judges any invariant-class at execution time, it is added then, not in this initiative.
- **Packet 01** — the `Money`/`CurrencyCode`/`CurrencyMismatchException`/`UnknownCurrencyCodeException` surface registered in `catalogs/contracts.json` and `catalogs/relationships.json` under `honeydrunk-kernel`. `consumes_detail["honeydrunk-kernel"]` extended for `honeydrunk-ai` (`Money`, `CurrencyCode`) and `honeydrunk-web-rest` (`Money`) — anticipating Wave 3.
- **Packet 02** — `HoneyDrunk.Kernel.Abstractions` ships `Money(decimal Amount, CurrencyCode CurrencyCode)`, `CurrencyCode` (readonly record struct with ISO 4217 alpha-3 validation against the seed list USD, EUR, GBP, JPY, CAD, AUD, CHF), `CurrencyMismatchException`, `UnknownCurrencyCodeException`. `HoneyDrunk.Kernel` runtime ships `MoneyJsonConverter` (the System.Text.Json converter for the D9 shape) — **not** Abstractions; the converter is runtime logic and invariant 1 keeps Abstractions STJ-free. `Money` carries **no** `[JsonConverter]` attribute. Arithmetic operators (`+`, `-`) and ordering operators (`<`, `<=`, `>`, `>=`) throw `CurrencyMismatchException` on cross-currency operands. **`==`/`!=` are NOT overridden** — record-default value equality stands; cross-currency `==` returns `false` (recorded as Required ADR Amendment to D2 in packet 00; overriding `==` would break `HashSet<Money>`/`Dictionary<Money>`/EF tracking equality). `Round(int decimals, MidpointRounding mode = MidpointRounding.ToEven)` uses banker's rounding by default; `AwayFromZero` is supported as an explicit opt-in. `ToString()` returns `"123.45 USD"`-style invariant-culture output. The canary suite pins arithmetic + currency-mismatch throws, rounding mode, JSON shape (including the negative case — amount-as-number rejects), `CurrencyCode` validation (lowercase rejected, unknown rejected), and `ToString` output. The `HoneyDrunk.Kernel` solution is at the new minor version (likely `0.8.0`, modulo ADR-0042's race — three-case procedure in packet 02; PR description records which case applied).
- **`BillingEvent` is unchanged.** ADR-0026 D5's frozen count-and-meter shape is preserved per ADR-0069 D7. The Audit Node's `IAuditLog`/`AuditEntry` contracts are also unchanged.

ADR-0069's decisions are now live rules. The implementation is shipped. Wave 3 adopts.

## What Wave 3 must deliver (packets 03, 04, 05)

Three packets, runnable in parallel:

- **Packet 03 (`Actor=Agent`)** — `HoneyDrunk.AI`: migrate `InferenceCost.EstimatedCost` (record field) and `CostSummary.TotalCost` (record field) from `decimal` to `Money`, with `CurrencyCode.Usd` as the Phase-1 denomination per ADR-0069 D10. Update `DefaultCostLedger.GetSummaryAsync` to aggregate `Money`. Bump the `HoneyDrunk.AI` solution one minor. **Requires the Kernel package release — see Human Prerequisite below.**
- **Packet 04 (`Actor=Agent`)** — `HoneyDrunk.Architecture`: document the D11 two-field convention (`monetary_value` + `currency_code`) in `repos/HoneyDrunk.Audit/boundaries.md` and add a cross-reference paragraph to ADR-0030. No code change in `HoneyDrunk.Audit` — `AuditEntry.Metadata` is already `string→string`. No Kernel-package dependency; runnable as soon as packet 00 lands.
- **Packet 05 (`Actor=Agent`)** — `HoneyDrunk.Web.Rest`: register `MoneyJsonConverter` in the default JSON options seam and add a round-trip canary plus an amount-as-number negative canary that pins ADR-0069 D9. **Requires the Kernel package release — see Human Prerequisite below.**

## Human Prerequisite at the wave boundary — agents never tag

Wave 3 packets 03 and 05 compile against `HoneyDrunk.Kernel.Abstractions` at the new minor version shipped by packet 02. That NuGet artifact exists on the package feed **only after a human pushes a git release tag** on `HoneyDrunk.Kernel`. Agents merge code; humans tag and publish.

**Procedure (human step at the Wave 2→3 boundary):**

1. Confirm packet 02's PR is merged to `main`.
2. Confirm the `HoneyDrunk.Kernel` solution version in `main`'s csproj files matches the new minor (record which version — `0.8.0` was the expected target, but ADR-0042's parallel bump may have moved it; the actual on-`main` version is what gets tagged).
3. Tag the release on `HoneyDrunk.Kernel` per the repo's release procedure (typically a `v{X.Y.Z}` git tag pushed to `main`, triggering the release workflow that publishes to the package feed).
4. Confirm the package is queryable on the feed (NuGet.org or the org feed Web.Rest/AI pull from).
5. Update packets 03 and 05's csproj `PackageReference` `Version` values to the actual published version (likely the same as the planned minor, but confirm).

**Until the human release step completes, packets 03 and 05 are blocked from execution** even though they are filed as unblocked-by-packet-02-merge in the dispatch graph. The dispatch graph models PR-level blocking; the package-feed availability is a real-world blocker outside Git.

Packet 04 has no Kernel-package dependency and can run as soon as packet 00 has landed — i.e. immediately at Wave 1 close, in parallel with everything else.

## Critical context for Wave 3 execution

### Packet 03 — AI cost ledger

- **Current shape (today on `HoneyDrunk.AI` `main`):**
  ```csharp
  public sealed record InferenceCost(string ProviderId, string ModelId, int InputTokens, int OutputTokens, decimal EstimatedCost, string OperationCorrelationId);
  public sealed record CostSummary(string Scope, DateTimeOffset Since, DateTimeOffset Until, decimal TotalCost, int TotalCalls);
  ```
- **Target shape:**
  ```csharp
  public sealed record InferenceCost(string ProviderId, string ModelId, int InputTokens, int OutputTokens, Money EstimatedCost, string OperationCorrelationId);
  public sealed record CostSummary(string Scope, DateTimeOffset Since, DateTimeOffset Until, Money TotalCost, int TotalCalls);
  ```
- **`DefaultCostLedger.GetSummaryAsync`** currently sums `entry.Cost.EstimatedCost` via LINQ `.Sum()`. Replace with a `Money`-respecting `Aggregate`. **Seed selection (spelled out):** on empty scope, seed `Money.Zero(CurrencyCode.Usd)`; on non-empty scope, seed `Money.Zero(scoped[0].Cost.EstimatedCost.CurrencyCode)` so the fold returns the same currency the entries carry. Cross-currency aggregation within a non-empty scope **must** throw `CurrencyMismatchException` (per ADR-0069 D2/D5) — that throw is the deliberate load-bearing signal that the deferred FX-rate service is needed. XML-doc it.
- **Every call site** in `HoneyDrunk.AI` that constructs `InferenceCost(...)` or reads `cost.EstimatedCost` / `summary.TotalCost` must be updated in the same commit. Search across `src/HoneyDrunk.AI*/` and `tests/`. The breaking shape change is acceptable under ADR-0035's pre-1.0 disclaimer; the solution-wide minor bump (invariant 27) reflects it.
- **Downstream-impact scope confirmed at packet-authoring time (2026-05-24) — no external consumers.** A Grid-wide search confirmed every `HoneyDrunk.AI.Abstractions` `PackageReference` and every `InferenceCost`/`CostSummary`/`ICostLedger` symbol reference is inside the `HoneyDrunk.AI` solution. No external Node (Capabilities, Operator, Agents, Memory, Knowledge, Evals) consumes the cost ledger today. The breaking change is therefore self-contained to the AI solution and is updated in one commit. Packet 03 carries the full downstream-impact list in its body.
- **Release-notes guidance.** When the human releases the `HoneyDrunk.AI` solution after packet 03 merges, the release notes flag the `Money` adoption as a breaking pre-1.0 shape change, list the call-site update pattern (`new InferenceCost(..., Money.Usd(decimalCost), ...)`), and link back to ADR-0069 D10. Future Nodes adopting `HoneyDrunk.AI.Abstractions` look for this in the release notes.
- **Per-package CHANGELOG:** `HoneyDrunk.AI.Abstractions` and `HoneyDrunk.AI` get entries (real changes). Provider packages and the worker (alignment bumps only) get no per-package CHANGELOG entry (invariant 12).
- **No `Money.Zero` (no-arg).** D2 forbids it. The aggregator seed is `Money.Zero(CurrencyCode.Usd)`.

### Packet 04 — Audit convention doc

- **No code change.** The current `AuditEntry.Metadata` shape is `IReadOnlyDictionary<string, string>?`. The two-field convention lands as `metadata["monetary_value"] = money.Amount.ToString("F{decimals}", InvariantCulture)` + `metadata["currency_code"] = money.CurrencyCode.Code`. No `IAuditLog` change, no `AuditEntry` change, no catalog change. The ADR-0031 D8 / invariant 49 Audit contract-shape canary stays green by construction.
- **Documentation deliverables:** the `repos/HoneyDrunk.Audit/boundaries.md` "Money-changing audit events" section and a cross-reference paragraph in `adrs/ADR-0030-grid-wide-audit-substrate.md`. Do not flip ADR-0030's Status; do not edit any ADR-0030 decision. Cross-reference only.
- **Precision discipline.** `monetary_value` is always a JSON-string-shaped metadata value (Audit's `Metadata` map already enforces this; document the rule for any future emitter that builds the metadata dictionary). Mirrors ADR-0069 D9's amount-as-string discipline.

### Packet 05 — Web.Rest converter wiring

- **Explicit registration is required.** `Money` carries no `[JsonConverter]` attribute (the converter lives in the `HoneyDrunk.Kernel` runtime, not Abstractions, per invariant 1). Every consumer that uses `JsonSerializerOptions` must register `MoneyJsonConverter` explicitly. Web.Rest does this once in `HoneyDrunk.Web.Rest.AspNetCore/Serialization/JsonOptionsDefaults.cs`'s `Configure(JsonSerializerOptions)` method — that seam already exists today and is consumed grid-wide via `JsonOptionsDefaults.SerializerOptions`. No "deferred" branch; no new seam.
- **The registration is one line:** inside `JsonOptionsDefaults.Configure`, append `options.Converters.Add(new MoneyJsonConverter());` after the existing `JsonStringEnumConverter` registration. Add the `using HoneyDrunk.Kernel.Serialization;` import.
- **Canary cases:**
  - Round-trip: `Money(123.45m, CurrencyCode.Usd)` → JSON → back; assert the JSON is exactly `{"amount":"123.45","currency":"USD"}` (modulo whitespace) and the deserialized value equals the original. Use `JsonOptionsDefaults.SerializerOptions`.
  - Negative — amount-as-number rejects: hand-build `{"amount":123.45,"currency":"USD"}` (no quotes around amount); assert deserialization throws `JsonException`. This pins ADR-0069 D9's amount-as-string discipline as a Web.Rest-side guarantee.
- **No new endpoint.** This packet is forward-compatibility wiring only. The first Web.Rest endpoint to surface a price comes in its own packet, in a future track (likely a consumer-app PDR's first build).

## Frozen / do-not-touch

- **`BillingEvent`** (in `HoneyDrunk.Kernel.Abstractions`) — ADR-0026 D5's frozen count-and-meter shape, preserved per ADR-0069 D7. Do NOT add a `Money` field; do NOT modify the shape; do NOT trigger any major bump on Kernel.Abstractions.
- **`IAuditLog` and `AuditEntry`** (in `HoneyDrunk.Audit.Abstractions`) — unchanged. The two-field audit convention is an emitter projection rule against the existing `Metadata` map. The Audit contract-shape canary (ADR-0031 D8 / invariant 49) stays green by construction.
- **Existing Kernel.Abstractions surface** (`IGridContext`, `TenantId`, `CorrelationId`, `BillingEvent`, etc.) — unchanged. Packet 02 added new types; it did not modify existing ones.

## Invariants binding Wave 3

- **Invariant 27** — every non-test `.csproj` in a solution shares one version and moves together. Packets 03 and 05 each bump their solution one minor version in one commit. Partial bumps are forbidden.
- **Invariant 12** — per-package CHANGELOGs only for packages with functional changes. Packet 03: `HoneyDrunk.AI.Abstractions` and `HoneyDrunk.AI` get entries; provider packages and the worker get none. Packet 05: `HoneyDrunk.Web.Rest.AspNetCore` (and the canary project if functional) gets an entry; everywhere else no per-package CHANGELOG entry.
- **Invariant 13** — XML docs on every new or modified public API. Packet 03 updates the XML docs on `InferenceCost`/`CostSummary`/`DefaultCostLedger.GetSummaryAsync` (including the deliberate cross-currency-throw documentation). Packet 05 documents any new converter-registration extension.
- **Invariant 1 (referenced)** — `HoneyDrunk.Kernel.Abstractions` is the canonical zero-dependency contracts package; downstream Nodes' Abstractions packages may take a `PackageReference` on it. Packet 03 does so (`HoneyDrunk.AI.Abstractions` → `HoneyDrunk.Kernel.Abstractions` for `Money` and `CurrencyCode`). Packet 05 takes a `PackageReference` on `HoneyDrunk.Kernel` (runtime, not Abstractions) because `MoneyJsonConverter` lives in the runtime — invariant 1 keeps Abstractions free of runtime classes, so the converter cannot be in `HoneyDrunk.Kernel.Abstractions`. Both directions are permitted: invariant 1 binds Kernel.Abstractions itself, not downstream packages' references.
- **No `Money.Zero` (no-arg)** — D2. Phase-1 aggregator seeds are `Money.Zero(CurrencyCode.Usd)`.
- **Cross-currency throw is deliberate** — D5. Do not silently convert; do not catch and swallow. The throw is the load-bearing signal for the deferred FX-rate service.

## Wave 3 acceptance gate

Each Wave 3 packet's PR passes the relevant gates:

- **Packet 03** — `HoneyDrunk.AI`'s `pr-core.yml` tier-1 gate; any contract-shape canary on `HoneyDrunk.AI.Abstractions`; the new unit tests covering the USD-only happy path and the mixed-currency `CurrencyMismatchException` path.
- **Packet 04** — `HoneyDrunk.Architecture`'s docs-lint or equivalent (if present); no runtime test.
- **Packet 05** — `HoneyDrunk.Web.Rest`'s `pr-core.yml` tier-1 gate; the canary project's round-trip + amount-as-number-rejects tests pass.

Once all three Wave 3 packets land, the initiative's exit criteria are met:

- `Money`/`CurrencyCode` shipped in `HoneyDrunk.Kernel.Abstractions` with the canary suite green.
- AI cost ledger explicitly USD-denominated per ADR-0069 D10.
- Audit two-field convention documented per ADR-0069 D11 (no code change needed).
- Web.Rest default JSON options carry the canonical D9 shape; the canary pins it.
- ADR-0069 stays Accepted; no follow-up packets in this initiative.

Subsequent consumer adoption (Billing standup, Notify Cloud standup, consumer-app PDR scaffolding) happens in each consumer's own track, consuming the contract this initiative shipped.
