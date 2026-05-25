---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "ops", "canary", "adr-0052", "wave-5"]
dependencies: ["packet:05"]
adrs: ["ADR-0052"]
accepts: ["ADR-0052"]
wave: 5
initiative: adr-0052-cost-governance
node: honeydrunk-ai
---

# Wire ILlmDispatcher to call IsHardCapBreachedAsync and throw BudgetExceededException before each call

## Summary
Wire the AI Node's chat / inference dispatcher (the dispatcher that ADR-0052 calls `ILlmDispatcher` and that the existing AI surface exposes as `IChatClient` / `IEmbeddingGenerator`) to call `ICostLedger.IsHardCapBreachedAsync(CostCategory.AiInference)` **before** each model call; throw `BudgetExceededException` synchronously if the cap is breached and no active override is in effect. Add the kill-switch canary that exercises the throw and verifies callers cannot retry, and add per-call attribution wiring so `AgentId` / `AgentRunId` / `TenantId` flow into the recorded `CostEvent`. This packet satisfies invariant 91 (`ILlmDispatcher` checks the ledger before each call) and closes the ADR-0052 D14 Phase 4 transition from "log a warning" to "throw `BudgetExceededException`."

## Context
ADR-0052 D4 specifies the AI-inference kill-switch shape exactly:
- The check is on the **hot path** of every LLM call. The `IsHardCapBreachedAsync` read is served from an in-memory cache (packet 05) so latency is sub-microsecond at v1 call volume.
- If month-to-date is at or above the hard cap (and no override is active), the dispatcher throws `BudgetExceededException` **synchronously**. The LLM call is never made.
- The exception carries the category, the cap, the actual, and a correlation id so the caller's error surface (ADR-0045) clusters them under one problem id.
- `BudgetExceededException` is **sealed** and **non-transient**. Callers must not retry; the exception means "this category is closed for the rest of the billing window or until an operator override engages." Retry loops that swallow the exception and try again immediately defeat the kill-switch. The `review` agent gains a catch-and-retry detection rule (packet 08).

The kill-switch is **per-category, Grid-wide** at v1 — a misbehaving agent burning the AI inference cap halts **all** agents, not just the offender (D4). Per-agent enforcement is named as future work; the dimensions (D6) are captured here so a future ADR can add per-agent enforcement without changing the storage shape.

**ADR-0052 D14 Phase 4 — the dangerous phase.** ADR-0052 calls Phase 4 ("kill-switch enablement") explicitly the dangerous one: it changes runtime behaviour from logging to throwing. The phased posture in the ADR is to pilot on AI inference for one week before extending to Azure infra (which the Operator aggregator handles, not this packet) and validating GitHub-native CI limit. **This packet ships the throw** — the operator's pilot week is a deployment-sequencing concern (deploy to dev first, observe for one week, then prod). The packet stages the runtime change but does not force the deploy.

**Existing AI dispatcher surface.** At edit time, `HoneyDrunk.AI.Abstractions` exposes `IChatClient` (chat completion, aligned with `Microsoft.Extensions.AI`) and `IEmbeddingGenerator`. ADR-0052 refers to "`ILlmDispatcher`" — that is the **role**, not a separately-named type. The dispatcher pattern in the AI Node is the routed-through-`IModelRouter`-and-into-provider chain. The cap check happens at the routing seam, before any provider call. **Pick the chokepoint at edit time:** ideally the `IModelRouter` implementation (`DefaultModelRouter` or whatever the standup landed) or a small decorator around it. Document the decision in the implementation: "the kill-switch check lives at \<chokepoint\>; any future LLM-call path that bypasses \<chokepoint\> must add its own check."

**Per-call attribution wiring.** Packet 04 migrated providers to call `RecordCostAsync(CostEvent)`. The `TenantId` / `AgentId` / `AgentRunId` fields on the event come from ambient context — `IGridContext` (or whatever the Kernel context contract is at edit time). Verify that the providers populate them; if any provider has them as `null` because the standup hadn't plumbed them through, fix it here. The attribution must be in place at the moment the event is recorded — historical events cannot be backfilled with attribution (D5).

**Override priority over the cap check.** `IsHardCapBreachedAsync` (packet 05) already honours active overrides — when an override is active and unexpired, it returns `false`. The dispatcher does not need to separately query the override; one call answers "can this call go through." Document that the override is the operator's emergency / planned escape (D11) and the dispatcher's check honours it implicitly.

**Operator-side D14 Phase 4 follow-ons are not in this packet.** The Container Apps auto-suspend job (Azure-infra kill-switch), the GitHub-native CI limit policy mirror, and the daily roll-up / threshold pings / breach push notifications all wait on the ADR-0018 Operator scaffold. They are named in packet 09 (the playbook), not this one. This packet is the AI-side half of Phase 4: AI inference goes from "log warning" to "throw `BudgetExceededException`" in-process.

**Phase 4 pilot semantics.** ADR-0052 D14 names a one-week observation on AI inference before extending to other categories. This packet ships the runtime change; the observation is a deployment concern (deploy to dev, observe, then prod). Document the recommended deploy sequence in the PR description: deploy to dev with the Phase-1 multiplier (packet 05) set to 10x so the cap is effectively very loose; observe for false breaches; flip the multiplier to 1x; observe; deploy to prod. The flip is operator-driven via App Configuration — not a code change.

**Repo-state gate.** This packet, like packet 05, requires the AI Node to be scaffolded. If the ADR-0016 scaffold has not landed, this packet sits behind it. The dispatch plan flags both packets 05 and 06 as gated on the AI scaffold.

## Scope
- `HoneyDrunk.AI` runtime — wire the kill-switch check into the dispatcher chokepoint:
  - A `CostKillSwitchInterceptor` (or the equivalent decorator / interceptor pattern the AI Node already uses) that wraps the routing chokepoint and calls `IsHardCapBreachedAsync` before each call; throws `BudgetExceededException` if breached.
  - Updates to the DI composition so the interceptor / decorator runs on every chat-completion and embedding path.
- A per-call attribution check — ensure every provider call site recording a `CostEvent` populates `TenantId`, `AgentId`, `AgentRunId` from ambient context (`IGridContext`); add the context plumbing if missing.
- The kill-switch canary in `HoneyDrunk.AI.Tests.Canaries` (or the existing AI canary project at edit time) — exercises the breach path end-to-end, asserts `BudgetExceededException` is thrown, asserts the exception is `sealed`, asserts retry policies do not re-invoke after the throw, asserts the message body never reaches the provider.
- Unit tests for the interceptor logic.
- The AI solution version-bumped or appended-to per invariant 27 (the third packet on the AI solution in this initiative).
- Per-package CHANGELOG entries for the AI runtime; no entries on other packages.
- Repo-level `CHANGELOG.md`.

## Proposed Implementation
1. **Identify the chokepoint.** At edit time, look at the AI Node's dispatcher composition. The pattern that gives the simplest single check is one of:
   - A decorator over `IModelRouter` (likely cleanest if the standup uses a single router).
   - A decorator over `IChatClient` and `IEmbeddingGenerator` at the abstraction layer.
   - A pipeline step in whatever invocation pipeline the AI Node already has.
   Pick the option that yields one check per LLM call (not per-provider duplication; not at the abstraction layer where a non-LLM call might hit it). Document the choice in the implementation file's header comment.
2. **`CostKillSwitchInterceptor`** — implements the chosen seam. Before each call:
   - Call `await costLedger.IsHardCapBreachedAsync(CostCategory.AiInference, ct)`.
   - If `true`, retrieve the cap and the month-to-date for the diagnostic (`var cap = (await budgetConfigProvider.GetAsync(ct)).Categories[CostCategory.AiInference].HardCap`; `var actual = await costLedger.GetMonthToDateAsync(CostCategory.AiInference, ct)`).
   - Throw `new BudgetExceededException(CostCategory.AiInference, cap, actual, gridContext.CorrelationId)`.
   - Otherwise, await the inner call as normal.
   The interceptor does not log the cap-not-breached path (it is the hot path). It logs the breach via structured event (an `IErrorReporter` call per ADR-0045 — see step 6).
3. **`BudgetExceededException` flow through `IErrorReporter`.** Per ADR-0045 / invariant 90, the breach is captured-as-error: emit a structured event through `IErrorReporter` (the facade ADR-0045 ships) with the problem-group key `Honeydrunk.Cost.HardCapBreach`. The event carries the category, the cap, the actual, the correlation id, and the (tenant, agent, agent-run) attribution if available. **Do this even though the exception will propagate** — the `IErrorReporter` capture is the persistent record (ADR-0045 D8 capture-vs-log policy applies).
4. **Per-call attribution check.** Audit every provider's call site (touched by packet 04) and verify the `CostEvent` records `TenantId`, `AgentId`, `AgentRunId` from `IGridContext` (or the equivalent ambient-context contract). If any field is hardcoded to `null` because the standup didn't plumb the context through, fix it. Add an XML-doc note on the recording call: "Attribution dimensions come from `IGridContext`; backfilling unattributed historical events is impossible by design (ADR-0052 D5)."
5. **DI composition update.** Register the interceptor / decorator in `ServiceCollectionExtensions` so every `IChatClient` / `IEmbeddingGenerator` (or `IModelRouter`) resolution goes through it. The composition pattern depends on the chosen chokepoint; document the order in the registration.
6. **The kill-switch canary.** In `HoneyDrunk.AI.Tests.Canaries` (or the existing AI canary project — invariant 14 names canary projects as cross-Node-boundary validators; the cap-check-before-provider-call is exactly such a boundary):
   - Compose a test dispatcher with a `CostLedger` seeded to month-to-date `$5000` (or any value above the test cap), the test cap configured at `$1500`, no active override.
   - Invoke an `IChatClient.GetResponseAsync(...)` call (or the equivalent chat-completion entry) via the composed dispatcher.
   - Assert: a `BudgetExceededException` is thrown synchronously.
   - Assert: the type `BudgetExceededException` is `sealed` (reflection assertion).
   - Assert: the inner provider was never called (use a counting test double or a spy).
   - Assert: an `IErrorReporter.CaptureException` was called with problem group `Honeydrunk.Cost.HardCapBreach` (use NSubstitute against the `IErrorReporter`).
   - Assert: after the throw, an immediate second invocation (no `try`/`catch`-retry — but a fresh call site repeating the operation) also throws — there is no transient backoff. Use a `Policy<>` that retries on `Exception` and verify the policy did NOT swallow `BudgetExceededException`. Confirm via a second test that a default retry-policy library wired against the call would throw on the first attempt, never retry.
   - Assert: with an active `BudgetOverride` covering the test category, the same dispatcher invocation does NOT throw — the override is honoured.
   No external services (invariant 15); no `Thread.Sleep` (invariant 51) — use `TimeProvider`.
7. **Unit tests for the interceptor.** Cover the cap-not-breached path (call proceeds), cap-breached + no-override path (throws), cap-breached + active-override path (call proceeds), override-expired path (throws again). Verify the `IErrorReporter` capture happens on every breach.
8. **Append-only version handling.** This packet is the third packet on the `HoneyDrunk.AI` solution in this initiative (packets 04 and 05 preceded). Per invariant 27, append to packet 04's version entry — no second bump in the same initiative. The CHANGELOG line accumulates entries for packets 04, 05, 06.
9. **CHANGELOG.** `HoneyDrunk.AI/CHANGELOG.md` gets an entry: "`CostKillSwitchInterceptor` wired at the `<chokepoint>` seam — `IsHardCapBreachedAsync` is called before every LLM dispatch; `BudgetExceededException` thrown synchronously on breach (sealed, non-transient); active overrides honoured. Closes ADR-0052 D14 Phase 4 AI-inference enablement. Operator-side phase-4 surfaces (Azure-infra auto-suspend, GitHub-native limit mirror, daily roll-up, threshold pings, breach push) are gated on the ADR-0018 Operator standup — named in the playbook." Repo-level `CHANGELOG.md` appended.

## Affected Files
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/CostKillSwitchInterceptor.cs` (new — or the equivalent decorator file name per the chosen chokepoint)
- `HoneyDrunk.AI/src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — DI composition update
- Provider source — any attribution-plumbing fix
- `HoneyDrunk.AI.Tests.Canaries/` — the kill-switch canary (and the project itself if it does not yet exist)
- AI unit-test project(s) — interceptor tests
- `HoneyDrunk.AI/CHANGELOG.md`; repo-level `CHANGELOG.md`

## NuGet Dependencies
- **`HoneyDrunk.AI`** — no new direct dependency beyond what packet 05 added; the implementation uses types already pulled in by `HoneyDrunk.Kernel.Abstractions` (packet 03) and the `IErrorReporter` from `HoneyDrunk.Telemetry.Abstractions` (which the AI Node likely already references for Pulse traces — confirm at edit time; if not, add the reference at the version that ships ADR-0045 packet 02).
- **Canary project** — the Grid test stack (xUnit v2 + NSubstitute + AwesomeAssertions + coverlet per ADR-0047 D1). If the canary project does not yet exist as a `HoneyDrunk.AI.Tests.Canaries` `.csproj`, create it; new projects include `HoneyDrunk.Standards` (`PrivateAssets: all`, invariant 26) and a brief `README.md` (invariant 12 for new test projects is informational; a brief README is sufficient).

## Boundary Check
- [x] All edits in `HoneyDrunk.AI`. ADR-0052 D4 names the in-process AI-inference kill-switch and places it in the AI Node.
- [x] No edit to `HoneyDrunk.Kernel` — the contract was packet 03; this packet consumes it.
- [x] No edit to `HoneyDrunk.AI.Abstractions` — the contract relocation was packet 04.
- [x] Azure-infra kill-switch / Container Apps auto-suspend is NOT in this packet — it lives in `HoneyDrunk.Operator` (gated on ADR-0018 standup).
- [x] No Bicep / IaC change in this packet; the App Insights alert rules for D10 anomaly detection are gated on Operator-side IaC (packet 09 plays them out).

## Acceptance Criteria
- [ ] A `CostKillSwitchInterceptor` (or named equivalent) is wired at the AI dispatcher chokepoint; the chokepoint is documented in the implementation file's header
- [ ] Before each LLM call, the interceptor calls `IsHardCapBreachedAsync(CostCategory.AiInference)`; if `true`, throws `BudgetExceededException` synchronously, never calling the inner provider
- [ ] An active `BudgetOverride` causes the cap check to pass; the call proceeds (verified by `IsHardCapBreachedAsync` returning `false` under override, which is packet 05's behaviour — this packet's responsibility is to honour the answer it gets)
- [ ] On breach, `IErrorReporter.CaptureException` is called with problem group `Honeydrunk.Cost.HardCapBreach`, carrying category, cap, actual, correlation id, and (tenant, agent, agent-run) attribution if available
- [ ] Every provider call site recording a `CostEvent` populates `TenantId`, `AgentId`, `AgentRunId` from `IGridContext` (or the equivalent); no hardcoded `null` where the context has the value
- [ ] The kill-switch canary in `HoneyDrunk.AI.Tests.Canaries` asserts: throws on breach; type is sealed; provider never called; `IErrorReporter` capture happens; default retry policy does NOT retry; override honoured
- [ ] Unit tests cover the interceptor's four states (not-breached, breached-no-override, breached-override-active, override-expired)
- [ ] No `Thread.Sleep` in tests (invariant 51); use `TimeProvider`
- [ ] The `HoneyDrunk.AI` solution version is unchanged from packets 04/05 (this packet appends to the in-progress version entry; invariant 27)
- [ ] `HoneyDrunk.AI/CHANGELOG.md` has an appended entry under the in-progress version; no per-package CHANGELOG entries on other packages
- [ ] Repo-level `CHANGELOG.md` appended
- [ ] The solution builds; all tests (unit + canary) pass; the `pr-core.yml` tier-1 gate passes

## Human Prerequisites
- [ ] **Recommended deploy sequence captured in the PR description.** Deploy to dev with the Phase-1 multiplier from packet 05 set to 10x (so the cap is effectively very loose); observe for false breaches for one week per the ADR-0052 D14 Phase-4 pilot guidance; flip the multiplier to 1x in App Configuration; observe for one more week; deploy to prod. The flip is operator-driven via App Configuration — not a code change. The PR description records this recommended sequence; the operator may compress or extend it based on observed behaviour.
- [ ] **App Configuration value `CostLedger:KillSwitch:Enabled` in each environment.** Default `true` in dev (so the throw is exercised), default `true` in prod after the pilot. A `false` setting bypasses the interceptor as a safety hatch in case Phase-4 itself goes wrong. Document the setting and its semantics in the PR. The default-on-in-prod posture is consistent with ADR-0052 D14 Phase 4 — the kill-switch is the policy from day one of Phase 4 — but the safety hatch exists in case the interceptor has a defect.

## Referenced ADR Decisions
**ADR-0052 D4 — In-process kill-switch for AI inference.** `ILlmDispatcher` checks `ICostLedger.GetMonthToDate(CostCategory.AiInference)` (read as `IsHardCapBreachedAsync` in the D7 preview) against the configured hard cap before each call. If at or above the hard cap, the dispatcher throws `BudgetExceededException` synchronously — the LLM call is never made. The exception carries category, cap, actual, correlation id. The cost ledger read is on the hot path of every LLM call. Performance impact is sub-microsecond on a hot ledger via in-memory aggregation.

**ADR-0052 D4 — `BudgetExceededException` no-retry contract.** The exception is **not transient**. Callers must not retry; the exception means "this category is closed for the rest of the billing window or until an operator override engages." Retry loops that swallow this exception defeat the kill-switch. The exception type is sealed and the documentation calls out the no-retry contract; the `review` agent gains a category check for "code catches `BudgetExceededException` and retries" as a defect (packet 08).

**ADR-0052 D4 — Per-category, Grid-wide, not per-agent at v1.** A misbehaving agent burning the AI inference cap halts all agents, not just the offender. Per-agent enforcement is named as future work; the dimensions are captured here so a future ADR can add it without changing storage shape.

**ADR-0052 D6 — Attribution dimensions on writes.** `AgentId` reuses the ADR-0051 identifier shape; `AgentRunId` is the per-invocation correlation. Both come from `IGridContext` (or the equivalent). Attribution at write time or never — historical events cannot be backfilled.

**ADR-0052 D11 — Override semantics.** The interceptor honours an active override implicitly via `IsHardCapBreachedAsync`'s answer.

**ADR-0052 D14 Phase 4 — Kill-switch enablement.** The highest-risk single change in the rollout because it changes runtime behaviour. Pilot on AI inference first; observe for one week; extend to other categories (Operator-side, not this packet). The pilot is deployment-side; this packet ships the runtime.

**Invariant 91 (this initiative, packet 00) — `ILlmDispatcher` checks the cost ledger against the hard cap before each call.** This packet satisfies invariant 91. The integration test required per ADR-0047 D4 is the canary added in this packet.

**ADR-0045 — `IErrorReporter` capture.** Breach events flow through `IErrorReporter` problem-grouped as `Honeydrunk.Cost.HardCapBreach` so the operator sees them in the same App Insights Failures blade as application errors.

## Constraints
> **Invariant 91 — `ILlmDispatcher` checks the cost ledger against the hard cap before each LLM call.** This packet satisfies the invariant; the cap check is on the hot path; failure to short-circuit when breached is a budgeting defect. Integration test required per ADR-0047 D4 (the canary in this packet).

> **Invariant 15 — Unit tests no external services.** The interceptor unit tests use a fake `ICostLedger` and a counting test double for the inner provider.

> **Invariant 27 — One-solution-one-version.** Append to packet 04's in-progress version; no second bump in this initiative.

> **Invariant 51 — No `Thread.Sleep` in tests.** Use `TimeProvider` for time-driven assertions.

- **`BudgetExceededException` is propagated, not swallowed.** The interceptor catches no exception; it propagates the throw to the caller. The `IErrorReporter.CaptureException` runs **before** the throw (in the same try block, or via finally — pick the pattern that matches the AI Node's existing `IErrorReporter` use).
- **No retry inside the interceptor.** The interceptor never re-checks the cap after a throw — the cap is closed for the billing window.
- **Choose the chokepoint once.** Do not split the cap check across multiple seams; multiple checks mean multiple defects. Pick the single seam that catches every LLM call and document it.
- **Pilot is operator-driven.** The interceptor ships enabled by default; the App Configuration flag is a safety hatch, not a default-off.

## Labels
`feature`, `tier-2`, `ai`, `ops`, `canary`, `adr-0052`, `wave-5`

## Agent Handoff

**Objective:** Wire the cost-ledger kill-switch check into the AI dispatcher chokepoint so every LLM call checks `IsHardCapBreachedAsync(CostCategory.AiInference)` and throws `BudgetExceededException` synchronously on breach. Add the canary that proves the throw, the sealed type, the no-retry contract, and the override-honoured behaviour.

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Satisfy invariant 91 — `ILlmDispatcher` checks the ledger before each call. Close the AI-inference half of ADR-0052 D14 Phase 4.
- Feature: ADR-0052 Cost Governance rollout, Wave 5.
- ADRs: ADR-0052 D4/D6/D11/D14 (primary), ADR-0045 (`IErrorReporter` surface for breach capture), ADR-0047 (canary pattern).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:05` — the v1 `CostLedger` ships the `IsHardCapBreachedAsync` answer this packet consumes.

**Constraints:**
- Choose the chokepoint once; document it.
- Throw `BudgetExceededException` synchronously; never retry.
- `IErrorReporter.CaptureException` runs on every breach.
- Active overrides are honoured implicitly via `IsHardCapBreachedAsync`.
- Append to the in-progress version (invariant 27); no second bump.
- Use `TimeProvider`; no `Thread.Sleep` in tests (invariant 51).

**Key Files:**
- `HoneyDrunk.AI/src/HoneyDrunk.AI/Cost/CostKillSwitchInterceptor.cs` (or named equivalent)
- `HoneyDrunk.AI/src/HoneyDrunk.AI/ServiceCollectionExtensions.cs` — DI update
- `HoneyDrunk.AI.Tests.Canaries/` — the kill-switch canary
- Provider source — attribution plumbing audit / fixes
- `HoneyDrunk.AI/CHANGELOG.md`; repo-level `CHANGELOG.md`

**Contracts:** No new contracts. Consumes `ICostLedger`, `CostCategory`, `BudgetExceededException` from `HoneyDrunk.Kernel.Abstractions`; consumes `IErrorReporter` from `HoneyDrunk.Telemetry.Abstractions` (ADR-0045).
