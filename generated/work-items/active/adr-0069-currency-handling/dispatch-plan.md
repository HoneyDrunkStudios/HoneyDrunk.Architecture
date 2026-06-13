# Dispatch Plan — ADR-0069: Currency Handling and Money Representation

**Initiative:** `adr-0069-currency-handling`
**ADR:** ADR-0069 (Proposed → Accepted via packet 00)
**Sector:** Core (Kernel.Abstractions) · Ops (cost ledger, audit emit) · cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0069 commits the Grid's internal representation of monetary values: a `Money` record (`decimal Amount` + `CurrencyCode`) in `HoneyDrunk.Kernel.Abstractions`, arithmetic that throws on currency mismatch, banker's rounding as the default mode, ISO 4217 alpha-3 validation against a hand-maintained seed list (USD, EUR, GBP, JPY, CAD, AUD, CHF), machine-readable `ToString`, a `MoneyJsonConverter` with `{"amount": "string", "currency": "ISO"}` shape, USD as the Studio's default, multi-currency-aware-but-not-converting storage, and a two-field convention (`monetary_value` + `currency_code`) for money-changing audit emits. `BillingEvent` (ADR-0026 D5 frozen count-and-meter shape) is preserved — `Money` is a separate, additive primitive, not a `BillingEvent` field.

This initiative delivers: ADR acceptance + initiative registration (no new numbered invariants — the four committed conventions are canary-enforced per the ADR's own framing); catalog registration of the `Money`/`CurrencyCode` surface under `honeydrunk-kernel`; the implementation + canary suite in `HoneyDrunk.Kernel.Abstractions`; the AI Node cost-ledger migration to `Money(rate, CurrencyCode.Usd)` per D10; documentation of the D11 two-field convention in `HoneyDrunk.Audit`'s boundaries file and as an ADR-0030 cross-reference; and a forward-compatibility wiring of the `MoneyJsonConverter` into Web.Rest's default JSON options with a D9-shape canary.

**6 packets across 3 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.AI`, `HoneyDrunk.Web.Rest`). All 6 are `Actor=Agent`, 0 `Actor=Human`. Packets 03 and 05 carry a Human Prerequisite — the human git-tag/release of the `HoneyDrunk.Kernel` solution after packet 02 merges so packets 03 and 05 can compile against the new `Money` surface.

## Trigger

ADR-0069 is Proposed with no scope. Forcing functions from the ADR's Context: **Notify Cloud GA** is the first commercial product that emits money-changing events; the audit shape for "subscription renewed for $X" is needed before the first paying tenant signs up. **The ADR-0052 cost-governance cache** is operationally live in `HoneyDrunk.AI` today with an implicit-USD denomination (concrete location: `InferenceCost.EstimatedCost` and `CostSummary.TotalCost` are `decimal` with implicit-USD semantics); the fix is cheap now, expensive once a non-USD provider lands. **Consumer-app PDRs** (PDR-0003 through PDR-0008) are pre-implementation, every PDR has a paid tier or subscription price, and the first scaffolded price catalog needs the `Money` type pre-staged. **ADR-0026 precedent** — the Grid's pattern is to commit cross-cutting primitives in Kernel.Abstractions once (`TenantId`, `BillingEvent`); `Money` follows the same playbook. The ADR needs decomposition into actionable packets.

## Scope Detection

**Multi-repo.** The contract lands in `HoneyDrunk.Kernel.Abstractions` (the zero-dependency contract layer every Node already consumes — same precedent as `TenantId` and `BillingEvent`); the cost-ledger migration is local to `HoneyDrunk.AI`; the audit-emitter convention is a documentation deliverable in `HoneyDrunk.Architecture` (no code change in `HoneyDrunk.Audit` because `AuditEntry.Metadata` is already a `string→string` map); the Web.Rest wiring is a forward-compatibility wiring in `HoneyDrunk.Web.Rest` with a D9-shape canary. `HoneyDrunk.Architecture` carries the governance (acceptance, catalog, audit-convention doc) packets.

**Contract is additive — no forced downstream cascade.** `Money`, `CurrencyCode`, `MoneyJsonConverter`, and the two exception types are net-new additive surface in `HoneyDrunk.Kernel.Abstractions`. Per ADR-0035 D1 and ADR-0069's own Operational Consequences, this is an additive minor bump on the pre-1.0 Kernel.Abstractions package — not a breaking change. Downstream Nodes that consume `HoneyDrunk.Kernel.Abstractions` are not *forced* to update; they adopt `Money` when their own monetary fields are amended. **`BillingEvent` is deliberately not touched** — ADR-0026 D5's frozen shape is preserved per ADR-0069 D7.

**Adopters in this initiative: AI and Web.Rest only.** ADR-0069's Affected Nodes list names HoneyDrunk.Billing (a future Node — does not exist in catalogs/nodes.json today), HoneyDrunk.Notify.Cloud (a future Node — also not in nodes.json today, ADR-0027 is its standup ADR), HoneyDrunk.Audit (code change is unnecessary because `Metadata` is already a free-form map), consumer-app Nodes per PDR-0003 through PDR-0008 (all pre-scaffolding), and HoneyDrunk.AI / HoneyDrunk.Web.Rest. This initiative wires only the **two adopters that exist today as live Nodes with concrete Money-bearing code**: HoneyDrunk.AI (the operationally-live cost ledger per D10) and HoneyDrunk.Web.Rest (the forward-compatible converter wiring per D9). Every other named consumer adopts the type in its own track — see "Out of scope" below.

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node. No empty cataloged repo is touched; no standup ADR is needed.

## Wave Diagram

### Wave 1 (governance + catalog — no dependencies)
- [ ] **00** — Architecture: Accept ADR-0069, register the initiative. **No numbered invariants added** — ADR-0069's four conventions are canary-enforced per the ADR's own framing. `Actor=Agent`.
- [ ] **01** — Architecture: register the `Money`/`CurrencyCode` contract surface in the Grid catalogs (`contracts.json`, `relationships.json`). `Actor=Agent`. Blocked by: 00.

### Wave 2 (the foundation)
- [ ] **02** — Kernel: add `Money`, `CurrencyCode`, `MoneyJsonConverter`, the two exception types, arithmetic / rounding / serialization / canary suite to `HoneyDrunk.Kernel.Abstractions`. **Version-bumping packet for `HoneyDrunk.Kernel`.** `Actor=Agent`. Blocked by: 00.

### Wave 3 (consumers, parallel)
- [ ] **03** — AI: migrate `InferenceCost.EstimatedCost` and `CostSummary.TotalCost` from `decimal` to `Money(amount, CurrencyCode.Usd)` per ADR-0069 D10. **Version-bumping packet for `HoneyDrunk.AI`.** `Actor=Agent`. Blocked by: 02. Human Prerequisite: Kernel package release.
- [ ] **04** — Architecture: document the D11 two-field convention (`monetary_value` + `currency_code`) in `repos/HoneyDrunk.Audit/boundaries.md` and as an ADR-0030 cross-reference. **No code change** — `AuditEntry.Metadata` is already `string→string`. `Actor=Agent`. Blocked by: 00.
- [ ] **05** — Web.Rest: wire `MoneyJsonConverter` into the default JSON options seam and pin the D9 shape with a round-trip + amount-as-number-rejects canary. **Version-bumping packet for `HoneyDrunk.Web.Rest`.** `Actor=Agent`. Blocked by: 02. Human Prerequisite: Kernel package release.

Packets within a wave run in parallel. Wave 3 packets 03, 04, 05 are independent — different repos / different concerns. Packet 04 depends only on packet 00 and could run as early as Wave 2; it is grouped into Wave 3 for tidy filing alongside the other consumers. The `dependencies:` frontmatter is the real ordering signal — 04 unblocks as soon as 00 lands.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0069](./00-architecture-adr-0069-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Money / CurrencyCode contract catalog](./01-architecture-money-contract-catalog.md) | Architecture | Agent | 1 | 00 |
| 02 | [Money, CurrencyCode, JSON converter, canary suite](./02-kernel-money-and-currency-code.md) | Kernel | Agent | 2 | 00 |
| 03 | [AI cost ledger → `Money(rate, USD)`](./03-ai-cost-ledger-money-adoption.md) | AI | Agent | 3 | 02 |
| 04 | [Audit money-emitter two-field convention](./04-architecture-audit-money-emitter-convention.md) | Architecture | Agent | 3 | 00 |
| 05 | [Web.Rest converter wiring + D9 canary](./05-web-rest-money-json-converter-wiring.md) | Web.Rest | Agent | 3 | 02 |

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 02 is the first packet on the solution in this initiative. It bumps every non-test `.csproj` to the same new minor version. The csproj files show `0.7.0` today, suggesting `0.8.0` as the next minor. The runtime package (`HoneyDrunk.Kernel`) also gains the `MoneyJsonConverter` class (real-change bump, not alignment) — `MoneyJsonConverter` lives in the runtime, not Abstractions, per invariant 1.
  - **Cross-initiative version sequencing with ADR-0042 (race).** ADR-0042 (`adr-0042-idempotency`) also targets `HoneyDrunk.Kernel` as a `0.7.0` → `0.8.0` minor bump (packet 02 of that initiative). The two packets are racing on the same version. Three-case procedure at execution time (codified in packet 02's Context section): **Case A** — Kernel still at `0.7.0`, open `0.8.0`; **Case B** — Kernel already at unreleased `0.8.0` (ADR-0042 landed first), append surface to in-progress `0.8.0` entries, no new bump; **Case C** — `0.8.0` released, take `0.9.0`. The executor reads `HoneyDrunk.Kernel.csproj` and `repos/HoneyDrunk.Kernel/active-work.md` (in Architecture) at edit time and records the chosen case in the PR description.
- **`HoneyDrunk.AI`** — packet 03 bumps the solution one minor version (the breaking field-type change on `InferenceCost.EstimatedCost` and `CostSummary.TotalCost` is acceptable as a minor bump under ADR-0035's pre-1.0 disclaimer; Directory.Build.props shows `0.1.0` today). Confirm the actual on-`main` version at execution time.
- **`HoneyDrunk.Web.Rest`** — packet 05 bumps the solution one minor version (new converter behavior on the default JSON options; csproj files show `0.5.0` today). Confirm at execution time.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/docs edits only (packets 00, 01, 04).

## Cross-Cutting Concerns

### Invariants — none added; four conventions enforced by canaries

ADR-0069's Consequences/Invariants section is explicit: **"No new Grid-wide invariants are introduced."** The four committed conventions — currency code is always uppercase ISO 4217 alpha-3; no implicit FX conversion; JSON `amount` is a string, never a number; audit money fields are split (`monetary_value` + `currency_code`) — read as "conventions enforced by canary tests rather than new lines in `constitution/invariants.md`." Packet 00 explicitly does not edit `constitution/invariants.md`. Packet 02's canary suite covers the first three conventions by construction; packet 04 documents the fourth as an emitter projection rule against the existing `AuditEntry.Metadata` map. If a later operator judges any of the four invariant-class at packet-time, the numbering is added then under the appropriate existing section (or a new section) — not in this initiative.

### `BillingEvent` is unchanged — ADR-0026 D5 frozen shape preserved

`HoneyDrunk.Kernel.Abstractions.BillingEvent` (the count-and-meter primitive ADR-0026 D5 froze) is **not modified** by any packet in this initiative. ADR-0069 D7 is explicit: `BillingEvent` carries `Quantity` and `UnitOfMeasure` only; `Money` is a separate, additive primitive that lives alongside, not inside, the billing-event surface. Per ADR-0035 D1 this avoids any major bump on Kernel.Abstractions. The Stripe boundary owns price computation per ADR-0037 D2; the Grid stores the Stripe-derived monetary outcome at the webhook boundary (Billing Node — a future Node, not in this initiative's scope).

### Adopters explicitly out of scope (deliberate deferral)

ADR-0069's Affected Nodes list and Follow-up Work section name several consumers. This initiative does **not** wire them, by design:

- **HoneyDrunk.Billing** — does not exist as a Node today (not in `catalogs/nodes.json`). ADR-0037 commits Stripe as the payment processor; the Billing Node's standup is its own ADR and its own initiative (a future track). When Billing is scaffolded, its invoice-record and Stripe-webhook-derived monetary fields adopt `Money` as a first-build concern — ADR-0069 D7 already names the shape.
- **HoneyDrunk.Notify.Cloud** — does not exist as a separate Node today (not in `catalogs/nodes.json`). ADR-0027 is its standup ADR; the standup is its own initiative. The `NotifyCloudTenantTier.MonthlyBaseFee` is `Money` when Notify Cloud scaffolds — a first-build concern in that track.
- **Consumer-app Nodes (PDR-0003 through PDR-0008)** — all pre-implementation. Their price-catalog scaffolding adopts `Money` from the first commit. Pre-staging the type (this initiative does) is the right move; pre-building the consumer-app catalogs is not.
- **HoneyDrunk.Audit** — no code change needed because `AuditEntry.Metadata` is already a `string → string` free-form map. The two-field convention is an emitter projection rule, documented in packet 04 against the existing contract surface. The ADR-0031 D8 / invariant 49 Audit contract-shape canary stays green by construction. If a future ADR judges the two-field shape canary-class for Audit specifically, that canary lives in `HoneyDrunk.Audit` and is added then.
- **FX-rate service** — explicitly deferred per ADR-0069 D5 / D12. The deferred-service signal is the deliberate `CurrencyMismatchException` thrown by `DefaultCostLedger.GetSummaryAsync` when entries span multiple currencies (packet 03 documents this as the load-bearing failure mode).
- **Per-tenant currency preference, historical FX rate storage, crypto/token support, minor-unit storage, invoice/receipt UI** — all explicitly deferred per ADR-0069 D12. Not in scope here.

This initiative ships the **contract, the canary, and the two operationally-live adopters (AI cost ledger, Web.Rest converter wiring)**. Every other consumer adopts the shipped contract in its own track. This keeps the initiative bounded and consistent with the Grid's "new-Node standup gets its own ADR; don't bundle into feature packets" rule.

### Human package release at the Wave 2→3 boundary — agents never tag

Wave 3 packets 03 and 05 compile against `HoneyDrunk.Kernel.Abstractions`'s new `Money`/`CurrencyCode` surface (packet 02). The NuGet artifact exists on the package feed **only after a human pushes a git release tag** on `HoneyDrunk.Kernel` — agents merge code but never tag or publish. One human release step gates Wave 3:

- **Wave 2→3 boundary** — after packet 02 has merged, a human tags/releases the `HoneyDrunk.Kernel` solution at the new version (the tag carries `HoneyDrunk.Kernel.Abstractions` at the new minor from packet 02). Wave 3 packets 03 and 05 cannot build against unpublished packages.

This is surfaced in packets 03 and 05's Human Prerequisites and in the Wave 2→3 handoff.

### Required ADR Amendment to D2 — `==` is NOT overridden

ADR-0069 D2 reads "comparisons across currencies also throws" and cites `Money.Zero(USD) == Money.Zero(EUR)` as throwing. **The implementation in packet 02 drops the `==` throw and keeps record-default value equality** — overriding record `==` to throw breaks `HashSet<Money>`, `Dictionary<Money>`, EF Core change-tracking equality, and every implicit `Equals`/`GetHashCode` call site that should be safe. The throw discipline stays on **arithmetic** (`+`, `-`) and **ordering** (`<`, `<=`, `>`, `>=`) — where the operation is observable and intentional — not on equality. Cross-currency `==` returns `false`.

Packet 00 records this as a Required ADR Amendment, edits ADR-0069 D2's wording inline (or as an "Amended at acceptance" note that preserves the original text), and adds an analogous D9 amendment (the `MoneyJsonConverter` ships in `HoneyDrunk.Kernel` runtime, not `HoneyDrunk.Kernel.Abstractions`, per invariant 1).

### `Money.Zero` (no-arg) is deliberately absent — D2

ADR-0069 D2 forbids zero-without-currency. `Money.Zero(CurrencyCode)` is the only construction shortcut without an amount. Every place a seed value is needed (notably `DefaultCostLedger.GetSummaryAsync`'s aggregator seed in packet 03) uses `Money.Zero(CurrencyCode.Usd)` at Phase 1. Packets 02, 03, 05 each restate this constraint explicitly.

### Truncation is not a `Round` mode — D3

Banker's rounding (`MidpointRounding.ToEven`) is the default; `AwayFromZero` is supported as an explicit opt-in; **truncation is not a supported `Round` mode**. Callers wanting truncation use `Math.Floor` on `Money.Amount` and reconstruct — the deliberate awkwardness signals that truncation is an unusual choice. Stripe Tax handles customer-facing truncation per ADR-0037; the Grid does not need it internally.

### Site sync

No site-sync flag. ADR-0069 is internal Core infrastructure — no public-facing Studios website content changes. (Future consumer-app PDRs that surface prices to website visitors will be their own site-sync concerns.)

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR-0069 returns to Proposed; the `Money` catalog entries are removed. No runtime impact.
- **Packet 02 (Kernel contracts):** revert the PR. The `HoneyDrunk.Kernel` solution version rolls back. The contracts are additive — no consuming Node depends on them at runtime until it composes them, so the revert is contained to `HoneyDrunk.Kernel`. The canary suite leaves the test project.
- **Packet 03 (AI cost ledger):** revert the PR. The `HoneyDrunk.AI` solution version rolls back. `InferenceCost.EstimatedCost` returns to `decimal` (implicit-USD); `CostSummary.TotalCost` returns to `decimal`. `DefaultCostLedger` returns to its `decimal`-summing aggregator. No external consumer of `HoneyDrunk.AI.Abstractions` was forced to migrate; the revert is contained. The reverted-to state is the pre-D10 implicit-USD baseline — still operationally correct (every current AI provider bills in USD), just not denomination-explicit.
- **Packet 04 (audit convention doc):** revert the PR. The boundaries-file section and the ADR-0030 cross-reference are removed. Documentation only — no runtime impact.
- **Packet 05 (Web.Rest converter wiring):** revert the PR. The `HoneyDrunk.Web.Rest` solution version rolls back. The converter registration is removed from `JsonOptionsDefaults.Configure`; the canary tests are removed from the canary project. Because `Money` carries no `[JsonConverter]` attribute (per packet 02's invariant-1 placement of the converter in the `HoneyDrunk.Kernel` runtime), the revert means Web.Rest's default options no longer carry `MoneyJsonConverter` and any `Money` payload serialization would fall back to default record serialization (`{"Amount": 123.45, "CurrencyCode": {...}}`) — but since no Web.Rest endpoint surfaces `Money` today, there is no production impact from the revert.
- **Cross-currency throw escape hatch:** D5's deliberate failure mode (`CurrencyMismatchException` from mixed-currency aggregation) is *not* a rollback candidate — it is the load-bearing signal that the deferred FX-rate service is needed. If the throw causes operational pain in production (which it cannot today — every AI provider is USD), the fix is the FX-rate-service ADR, not a revert.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

All `dependencies:` edges in this initiative use the `work-item:NN` schema and resolve within this initiative folder — no cross-initiative `{Repo}#N` edges are needed (the ADR-0042 Kernel-version sequencing is captured as narrative in this dispatch plan and in packet 02's Context, not as a hard `dependencies:` edge — the two initiatives' Kernel packets are coordinated at execution time per invariant 27, not pre-wired at filing time).
