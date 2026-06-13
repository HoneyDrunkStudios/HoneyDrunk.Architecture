# Handoff — Wave 1 → Wave 2: the Kernel cost-governance contracts

**Initiative:** `adr-0052-cost-governance`
**Wave transition:** Wave 1 (governance + catalog + config + report format + review rules) → Wave 2 (Kernel contracts)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 landed

- **Packet 00** — ADR-0052 flipped to **Accepted**. Three new invariants added to `constitution/invariants.md` under a new `## Cost Governance Invariants` section, numbered **90, 91, 92** (pre-reserved for ADR-0052; current verified max in the file is 49):
  1. **90** — Every cost-producing operation in the Grid is recorded as a `CostEvent` in the cost ledger (dispatcher + aggregator code paths must produce an event for every dollar of external spend; CI check enforces).
  2. **91** — `ILlmDispatcher` checks the cost ledger against the hard cap before each LLM call (the hot-path check; `BudgetExceededException` is sealed and non-transient; catch-and-retry is a defect).
  3. **92** — Operator overrides of cost caps are audited (references invariant 47 / ADR-0030 — does not restate the Audit retention/tagging contract).
- **Packet 01** — Cost-governance contracts registered under `honeydrunk-kernel` in `catalogs/contracts.json`: `ICostLedger`, `CostEvent`, `CostCategory`, `BudgetExceededException`, `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery`. The existing AI-side `ICostLedger` entry under `honeydrunk-ai` is marked as relocating (not deleted — packet 09 removes it after packet 04 ships). D7 implementation-home and D13 cross-ADR notes recorded as cross-cutting policy notes.
- **Packet 02** — `business/context/cost-budgets.json` created with the ADR-0052 D2 defaults (AI inference $500/$1500; Azure infra $300/$800; SaaS $200 soft-only; domain/cert $25 soft-only; GitHub Actions $50/$150), the D10 anomaly thresholds (5.0 / 3.0), the D12 dev overlay, and the per-category owners block (`oleg` for all five at v1). The tuning policy doc records the slow-PR-path vs fast-override-CLI boundary.
- **Packet 07** — `generated/cost-reports/_format.md` ships the canonical monthly report format with stable level-2 heading anchors per D9's seven sections; an `EXAMPLE.md` worked example renders the shape with plausible placeholder data.
- **Packet 08** — `.claude/agents/review.md` carries the new `cost-config` and `cost-kill-switch-retry` review categories; both severity `block`. `pr-review-rules.md` maps them.

ADR-0052's decisions are now live rules. The contracts the catalog already advertises are added in code in packet 03.

## What Wave 2 must deliver (packet 03)

Build the cost-governance contract surface in **`HoneyDrunk.Kernel`** (live Node):

- **`HoneyDrunk.Kernel.Abstractions`** — add `ICostLedger`, `CostEvent`, `CostCategory`, `CostSource`, `CostEnvironment`, `BudgetExceededException`, `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery`. Pure records / interfaces / enums / sealed exception — zero HoneyDrunk runtime dependencies (invariant 1).
- This is the **version-bumping packet for `HoneyDrunk.Kernel` in this initiative**.

## Interface signatures for downstream packets

`ICostLedger` — the shape packets 04/05/06 (and the future Operator aggregator + future Billing) consume:
```
public interface ICostLedger
{
    ValueTask RecordCostAsync(CostEvent evt, CancellationToken ct);
    ValueTask<decimal> GetMonthToDateAsync(CostCategory category, CancellationToken ct);
    ValueTask<bool> IsHardCapBreachedAsync(CostCategory category, CancellationToken ct);
    ValueTask<BudgetOverride?> GetActiveOverrideAsync(CostCategory category, CancellationToken ct);
    IAsyncEnumerable<CostEvent> QueryAsync(CostQuery query, CancellationToken ct);
}
```

`CostEvent` — record carrying:
- `CostCategory Category` (enum: `AiInference` / `AzureInfrastructure` / `ThirdPartySaas` / `DomainCertRegistrar` / `GitHubActionsMinutes`)
- `decimal Amount` (USD; validate non-negative)
- `DateTimeOffset Timestamp`
- `CostSource Source` (discriminated: `LlmInferenceSource` / `AzureInfraSource` / `SaasSource` / `CiSource` / `DomainSource`)
- `CostEnvironment Environment` (enum: `Prod` / `Dev` / `Staging` / `Local` — `Local` events are written to Cosmos for visibility but exempt from caps per D12)
- `string CorrelationId` (validate non-empty)
- `TenantId? TenantId` (ADR-0026; reuse the Kernel `TenantId` type if it exists, otherwise `string?`)
- `string? AgentId` (D6; reuses ADR-0051's identifier shape)
- `string? AgentRunId` (D6 per-invocation correlation)

`BudgetExceededException` — `public sealed class : Exception`. Carries `CostCategory Category`, `decimal HardCap`, `decimal MonthToDate`, `string CorrelationId`. Override `Message` to include category / cap / actual. XML-doc states: "Non-transient. Callers must not retry; catching and retrying within the same billing window is a defect detected by the `review` agent (`cost-kill-switch-retry` category from packet 08). The top-level loop carve-out from ADR-0052 D4 is the only sanctioned catch — log a structured event, write checkpoint state to Audit, exit cleanly."

`BudgetOverride` — record: `CostCategory Category`, `string OperatorPrincipalId`, `string Reason`, `DateTimeOffset IssuedAt`, `DateTimeOffset ExpiresAt`, `DateTimeOffset? RevokedAt`. Time-bounded; permanent overrides do not exist (D11).

`IBudgetConfigProvider` — single member: `ValueTask<BudgetConfig> GetAsync(CancellationToken)`. XML-doc points at the Vault `IConfigProvider` source path per ADR-0016 D5.

`BudgetConfig` — record: `IReadOnlyDictionary<CostCategory, BudgetCategoryConfig> Categories`, `IReadOnlyDictionary<CostCategory, BudgetCategoryConfig> DevOverlay`, `IReadOnlyDictionary<CostCategory, string> Owners`. Nested `BudgetCategoryConfig`: nullable `SoftCap` / `HardCap`, `KillSwitch` posture string (`"in_process"` / `"azure_suspend"` / `"github_native"` / `"none"`), anomaly thresholds.

`CostQuery` — record with nullable filters and required date range.

## Version-state check — read carefully

The `HoneyDrunk.Kernel` solution is also touched by the `adr-0042-idempotency` initiative (its packets 02 / 04 / 07 bump `0.7.0` → `0.8.0` for the idempotency contract surface). **At packet 03's edit time, the executor must check:**

- If ADR-0042's Kernel packets have all merged and `HoneyDrunk.Kernel` is at the **released** `0.8.0`, **packet 03 bumps** the solution `0.8.0` → `0.9.0` (minor — additive new contract surface, no break). Add new `[0.9.0]` entries to the repo-level `CHANGELOG.md` and `HoneyDrunk.Kernel.Abstractions/CHANGELOG.md`.
- If an ADR-0042 Kernel version bump is still **in-progress (unreleased)**, packet 03 **appends** to that in-progress version entry and does NOT bump again (invariant 27).

The expected case is "ADR-0042's Kernel work is released" — ADR-0042 is sequenced before this initiative by topic priority. Verify and record in the PR.

## Frozen / do-not-touch

- **`HoneyDrunk.AI.Abstractions.ICostLedger`** (the seed two-member interface) — do NOT modify from packet 03. The AI-side relocation is packet 04, in the AI repo, on its own commit.
- **`HoneyDrunk.Transport`** — Kernel does not depend on Transport (invariant 4 DAG; Transport depends on Kernel, never the reverse). No reference.
- **`HoneyDrunk.Data`** — Kernel does not depend on Data. The Cosmos persistence lives in `HoneyDrunk.AI` per D7, not in Kernel.
- **Existing Kernel context contracts** (`IGridContext`, `TenantId`, `CorrelationId`, etc.) — `CostEvent` reuses the existing `TenantId` type if Kernel exposes one; do not fork a parallel primitive.

## Invariants binding Wave 2

- **Invariant 1** — `HoneyDrunk.Kernel.Abstractions` has zero runtime dependencies on other HoneyDrunk packages; only `Microsoft.Extensions.*` abstractions permitted. No Cosmos SDK, no App Insights SDK, no Azure type in the contract. The new types use only BCL types.
- **Invariant 4** — the dependency graph is a DAG; Kernel is at the root. No reference to `HoneyDrunk.AI`, `HoneyDrunk.Transport`, `HoneyDrunk.Data`, or any other HoneyDrunk runtime package.
- **Invariant 8** — secrets never in telemetry. `CostSource` carries structured forensics data (provider id, model id, token counts, resource id, meter name) — no prompt text, no completion text, no API key. The XML docs state this.
- **Invariant 13** — every new public member has XML documentation.
- **Invariant 27** — all projects in a solution share one version and move together. Packet 03 is the bumping packet (or the appending packet — see the version-state check). Partial bumps are forbidden.
- **Invariant 51** — no `Thread.Sleep` in tests; use `TimeProvider`.
- **Naming rule** — records drop the `I` (`CostEvent`, `CostSource`, `BudgetOverride`, `BudgetConfig`, `CostQuery`); interfaces keep it (`ICostLedger`, `IBudgetConfigProvider`); enums (`CostCategory`, `CostEnvironment`) follow standard enum naming; the exception type `BudgetExceededException` is a class (Exception subclass) — no `I` prefix.

## Acceptance gate for Wave 2

Packet 03's PR passes the `pr-core.yml` tier-1 gate. `HoneyDrunk.Kernel.Abstractions` ships the cost-governance contract surface; `HoneyDrunk.Kernel` (runtime) gets the alignment bump but no functional change and no per-package CHANGELOG entry. The unit tests cover record construction / equality / `BudgetExceededException` sealedness / `CostEvent.Amount` validation.

**Human package release at the Wave 2 → Wave 3 boundary — agents never tag.** Packet 04 (AI Node) builds against the `HoneyDrunk.Kernel.Abstractions` version that ships packet 03. After packet 03 merges, a human must tag/release `HoneyDrunk.Kernel` at its new version (`0.9.0` or the in-progress ADR-0042 version) so packet 04 can compile.

The Wave 3 packet (04) is the AI-side relocation: delete the seed `HoneyDrunk.AI.Abstractions.ICostLedger`, migrate every AI provider call site, rewrite `DefaultCostLedger` as a Phase-1 stub against the new Kernel contract.
