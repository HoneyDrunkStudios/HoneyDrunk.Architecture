# Dispatch Plan — ADR-0052: Cost Governance, Budget Alerts, and Kill-Switches

**Initiative:** `adr-0052-cost-governance`
**ADR:** ADR-0052 (Proposed → Accepted via packet 00)
**Sector:** Ops / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0052 commits the Grid's cost-governance substrate: five named cost categories with per-category soft/hard caps; alert thresholds; per-category kill-switches (in-process for AI inference, out-of-process Azure-suspend for infra, GitHub-native for CI, none for SaaS/domain); per-tenant and per-agent attribution; Cosmos-backed persistence with 13-month retention and an in-memory cache for the hot-path cap-check; monthly auto-generated reports in `generated/cost-reports/`; App Insights anomaly detection (5x hour-over-hour, 3x day-over-day); time-bounded audited operator overrides; dev/prod separation; and a seven-phase rollout where Phase 1 ships the ledger substrate and Phase 4 is the explicit "this is the dangerous one" kill-switch enablement step.

This initiative delivers **Phase 1 of the rollout plus the AI-inference half of Phase 4**: the contract surface in `HoneyDrunk.Kernel.Abstractions` (relocating from the seed `HoneyDrunk.AI.Abstractions.ICostLedger`); the v1 Cosmos-backed implementation in `HoneyDrunk.AI` with in-memory cache; the dispatcher kill-switch wiring; the `business/context/cost-budgets.json` config file with D2 defaults; the `generated/cost-reports/` directory + format spec; the `review` agent's `cost-config` and `cost-kill-switch-retry` categories; the three new cost-governance invariants; and a rollout playbook for the Operator-side surfaces this initiative does NOT build.

**The Operator-side surfaces are explicitly deferred.** ADR-0018 (Operator standup) is Proposed; the `HoneyDrunk.Operator` repo is at seed/0.0.0 with no scaffolded code. Every surface ADR-0052 names that lives in Operator — the aggregator for Azure Cost Management / GitHub / vendor APIs, the Container Apps auto-suspend job, the `hd cost` CLI, the "Cost" dashboard view, the App Insights anomaly Bicep, the Communications + Notify alert wiring — waits on ADR-0018's standup and is named in the playbook (packet 09) for re-decomposition once the gate fires.

**9 packets across 5 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.AI`) and adding a Kernel-Abstractions surface to a third (`HoneyDrunk.Kernel` — via packet 03). All 9 are `Actor=Agent`, 0 `Actor=Human`. Several packets carry Human Prerequisites: human release-tags on Kernel and AI at wave boundaries (the standard "agents merge, humans tag" pattern), Cosmos provisioning + Managed Identity RBAC for packet 05, recommended deploy-pilot sequencing for packet 06, and per-provider API key spending limits + dev/prod Azure resource separation as Gate-0 / Gate-1 items in packet 09.

## Trigger

ADR-0052 is Proposed with no scope. The forcing functions from the ADR's Context: **the AI-sector standup wave (ADR-0016 through ADR-0025)** is the single largest cost-risk increase in the Grid's history — every new AI Node multiplies the surface where token spend can leak; **Codex and cloud agents are already running today**, with no per-run cap; **the studio is bootstrapped** with no FinOps oversight, no investor pool, and a runway materially exposed to a five-figure surprise bill; **the first runaway loop is too late** — manual attention is detection, not prevention. ADR-0052 is positioned as the most urgent of the cross-cutting ADRs in the 0048–0052 batch precisely because cost-governance failure is a one-shot, irrecoverable event.

## Scope Detection

**Multi-repo.** ADR-0052 touches `HoneyDrunk.Kernel` (the contract relocation per D7), `HoneyDrunk.AI` (the v1 implementation + dispatcher kill-switch wiring + Phase-1 stub-then-replace), and `HoneyDrunk.Architecture` (acceptance, catalog registration, budget config, report format, review-agent rules, playbook). Three repos at the code/governance level; the playbook references work in five more (`HoneyDrunk.Operator`, `HoneyDrunk.Communications`, `HoneyDrunk.Notify`, `HoneyDrunk.Observe`, future `HoneyDrunk.Billing`) but does not build any of them.

**Contract is replace, not extend.** The seed `HoneyDrunk.AI.Abstractions.ICostLedger` (two-member, inference-only) is replaced by the wider `HoneyDrunk.Kernel.Abstractions.ICostLedger` (five-member, multi-source, category-scoped). Packet 04 deletes the AI-side type and migrates every provider call site. The AI Node is at seed status with no external consumer of the old contract — the replacement is acceptable as an additive minor bump on the AI solution because no out-of-repo pin exists.

**No new-Node scaffolding from this initiative.** Every target repo at the code level is a live (or seed but standing-up) Node. The Operator Node is named heavily in the playbook (packet 09) but the standup itself is ADR-0018's scope, not this initiative's. Per the Memory note `feedback_adr_before_scaffold`, standup work gets its own ADR; this initiative respects that.

## Wave Diagram

### Wave 1 (Governance + catalog + config + report format — all Architecture-side, parallel where blocked-by allows)
- [ ] **00** — Architecture: Accept ADR-0052, add the three cost-governance invariants (numbers **90, 91, 92** — pre-reserved within the 12-ADR batch; the file's verified current maximum is 49), register the initiative. `Actor=Agent`. Blocked by: nothing.
- [ ] **01** — Architecture: register the cost-governance contracts under `honeydrunk-kernel` in `catalogs/contracts.json`; mark the existing AI-side `ICostLedger` as relocating; record the D7 implementation home + D13 cross-ADR notes. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: create `business/context/cost-budgets.json` with the D2 defaults / D10 anomaly thresholds / D12 dev overlay; author the tuning policy doc. `Actor=Agent`. Blocked by: 00.
- [ ] **07** — Architecture: create `generated/cost-reports/` with `_format.md` + a worked example. `Actor=Agent`. Blocked by: 00.
- [ ] **08** — Architecture: add `cost-config` and `cost-kill-switch-retry` review categories to `.claude/agents/review.md`. `Actor=Agent`. Blocked by: 00, 02.

> **Invariant numbering.** The current verified maximum in `constitution/invariants.md` is **49**. Invariant numbers **90, 91, 92** are pre-reserved as part of a 12-ADR batch; if any invariant above 49 lands from outside this batch before packet 00 merges, shift this block upward, never reuse a number.

### Wave 2 (The Kernel contract — depends on Wave 1's catalog)
- [ ] **03** — Kernel: add `ICostLedger`, `CostEvent`, `CostCategory`, `CostSource`, `CostEnvironment`, `BudgetExceededException`, `BudgetOverride`, `IBudgetConfigProvider`, `BudgetConfig`, `CostQuery` to `HoneyDrunk.Kernel.Abstractions`. `Actor=Agent`. Blocked by: 00, 01. **Version-bumping packet for `HoneyDrunk.Kernel` in this initiative** — bumps `0.8.0` → `0.9.0` if ADR-0042's Kernel work has been released, or appends to an in-progress ADR-0042 version (see Cross-Initiative Coordination below).

### Wave 3 (AI-side contract reconciliation — depends on Wave 2 + human release tag)
- [ ] **04** — AI: delete the seed `HoneyDrunk.AI.Abstractions.ICostLedger` / `InferenceCost` / `CostSummary`; point `HoneyDrunk.AI.Abstractions` at the new Kernel contract; migrate every provider call site from `RecordAsync(InferenceCost)` to `RecordCostAsync(CostEvent)`; rewrite `DefaultCostLedger` as a Phase-1 non-durable stub. `Actor=Agent`. Blocked by: 03 (+ human release of the new `HoneyDrunk.Kernel.Abstractions` to NuGet). **Version-bumping packet for `HoneyDrunk.AI` in this initiative** — bumps `0.1.0` → `0.2.0`.

### Wave 4 (AI-side v1 implementation — depends on Wave 3 + human release tag + Cosmos provisioning)
- [ ] **05** — AI: implement the Cosmos-backed `CostLedger` with in-memory cache; implement `BudgetConfigProvider` reading `cost-budgets.json`; add the `CostLedgerCacheRefreshService`; create the Cosmos provisioning Bicep. `Actor=Agent`. Blocked by: 02, 04 (+ human release of `HoneyDrunk.AI` packet 04 to NuGet so the stub is replaceable — actually moot since this is same-solution, but the Wave-3→4 cycle still needs the in-progress version state to be merged; + the Cosmos account human-provisioned per environment). **Appends** to packet 04's in-progress version (invariant 27).

### Wave 5 (Dispatcher kill-switch wiring + Operator-side playbook — depends on Wave 4 ledger + earlier waves)
- [ ] **06** — AI: wire the AI dispatcher to call `IsHardCapBreachedAsync` before each call; throw `BudgetExceededException` synchronously on breach; capture via `IErrorReporter`; ship the kill-switch canary in `HoneyDrunk.AI.Tests.Canaries`. `Actor=Agent`. Blocked by: 05. **Appends** to the AI in-progress version (invariant 27).
- [ ] **09** — Architecture: author the Operator-side rollout playbook (every surface gated on ADR-0018 standup); remove the relocating AI-side `ICostLedger` entry from `catalogs/contracts.json`. `Actor=Agent`. Blocked by: 00, 01, 02, 07. (Independent of code packets 03–06 — could run as early as Wave 2, grouped here for tidy filing. The catalog cleanup half is conditionally gated on packet 04's merge — see Cross-Cutting Concerns.)

Packets within a wave run in parallel where the `dependencies:` allow. Wave 1 has five parallel-eligible packets (00 unblocks 01, 02, 07; 02 unblocks 08; the four Architecture packets land in any order after their respective blockers). Wave 5 has packets 06 and 09 — packet 06 is the AI Node's last code packet; packet 09 is purely Architecture and is grouped here for tidy filing but could land earlier.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0052](./00-architecture-adr-0052-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Cost-governance catalog + relocation record](./01-architecture-cost-governance-catalog-and-relocation-record.md) | Architecture | Agent | 1 | 00 |
| 02 | [`cost-budgets.json` + tuning policy](./02-architecture-cost-budgets-config-and-tuning-policy.md) | Architecture | Agent | 1 | 00 |
| 03 | [Kernel cost-governance contracts](./03-kernel-cost-governance-contracts.md) | Kernel | Agent | 2 | 00, 01 |
| 04 | [AI `ICostLedger` relocation to Kernel](./04-ai-icostledger-relocation-to-kernel.md) | AI | Agent | 3 | 03 |
| 05 | [Cosmos-backed `CostLedger` v1](./05-ai-cosmos-backed-cost-ledger-implementation.md) | AI | Agent | 4 | 02, 04 |
| 06 | [Dispatcher kill-switch wiring](./06-ai-dispatcher-kill-switch-wiring.md) | AI | Agent | 5 | 05 |
| 07 | [`generated/cost-reports/` directory + format](./07-architecture-cost-reports-directory-and-format.md) | Architecture | Agent | 1 | 00 |
| 08 | [`review.md` cost-config + retry rules](./08-architecture-review-agent-cost-config-and-retry-rules.md) | Architecture | Agent | 1 | 00, 02 |
| 09 | [Operator-side rollout playbook + catalog cleanup](./09-architecture-operator-side-rollout-playbook.md) | Architecture | Agent | 5 | 00, 01, 02, 07 |

## Cross-Initiative Coordination

### `HoneyDrunk.Kernel` solution versioning vs ADR-0042

The `adr-0042-idempotency` initiative also targets `HoneyDrunk.Kernel` (its packets 02/04/07 bump the solution `0.7.0` → `0.8.0` for the idempotency contract surface). ADR-0052's Kernel work (packet 03 here) wants `0.8.0` → `0.9.0` as a follow-on minor bump.

**The order matters and is enforced by check-at-edit-time, not by `dependencies:` edges** (the two initiatives are independent at the contract level; only the version line couples them):
- If ADR-0042's Kernel packets have all merged and `HoneyDrunk.Kernel` is at the released `0.8.0`, **packet 03 bumps** `0.8.0` → `0.9.0`.
- If an ADR-0042 Kernel version bump is still in-progress (unreleased), **packet 03 appends** to that in-progress version entry and does not bump again (invariant 27).

Packet 03 documents the check and records the case in the PR. The expected case is "ADR-0042's Kernel work is released" — ADR-0042 is sequenced before ADR-0052 by topic priority (idempotency lands before cost governance per the ADR Context).

### `HoneyDrunk.AI` scaffold gate

`HoneyDrunk.AI` is at v0.1.0 with seed status — the ADR-0016 Phase-1 scaffold packet (`HoneyDrunk.AI#2`) has not been executed. **Packets 05 and 06 require the AI Node to be scaffolded enough to host a Cosmos client, an `IHostedService`, and the `IBudgetConfigProvider` consumption.** Packet 04 is lighter — it can land against the seed state because it only deletes types and migrates call sites.

**If the AI scaffold has not landed by the time Wave 3 → 4 boundary is reached**, the Wave-3 packet (04) still merges (no scaffolding needed), but packets 05 and 06 wait. The dispatch plan flags this as the initiative's biggest gate. The operator may need to file the AI scaffold packet (ADR-0016 Phase 1) before Wave 4 can proceed.

### ADR-0040 / ADR-0045 cross-references (`IErrorReporter`)

Packet 06 calls `IErrorReporter.CaptureException` on hard-cap breach (problem group `Honeydrunk.Cost.HardCapBreach`). The `IErrorReporter` facade ships in ADR-0045's initiative (currently being scoped — ADR-0045 is Proposed; its initiative is `adr-0045-grid-wide-error-tracking`). **Packet 06 expects `IErrorReporter` to exist in `HoneyDrunk.Telemetry.Abstractions`** at the version that ships ADR-0045's packet 02.

If ADR-0045's `IErrorReporter` facade is not yet on the NuGet feed when packet 06 runs, packet 06's executor should:
- Check `HoneyDrunk.AI`'s existing `HoneyDrunk.Telemetry.Abstractions` reference at edit time; if the facade is there, use it.
- If not, ship the breach event via the next-best mechanism: structured `ILogger` log at `Error` level + the `BudgetExceededException` propagation. Document the gap in the packet's PR description and flag a follow-on packet to wire `IErrorReporter` once ADR-0045 ships.

This is a soft cross-initiative dependency — both initiatives are scopable independently — but they share a sequencing concern that the executor surfaces at runtime.

### ADR-0018 Operator standup gate

Every surface in packet 09's playbook is gated on the Operator standup. ADR-0018 is **Proposed**; the playbook does not advance it. A future ADR-0018 acceptance initiative will be the trigger for re-decomposing the playbook into Operator-side packets.

## Human Release at Wave Boundaries — Agents Never Tag

Three waves cross repo boundaries that require human release-tags on NuGet:

- **Wave 2 → Wave 3 boundary** — after packet 03 (Kernel) merges, a human tags/releases `HoneyDrunk.Kernel` at the new version so packet 04 (AI) can compile against the new `HoneyDrunk.Kernel.Abstractions`. The tag carries both packages in the solution (Kernel + Kernel.Abstractions).
- **Wave 3 → Wave 4 boundary** — packets 04 and 05 share the `HoneyDrunk.AI` solution; the in-progress version entry started by packet 04 is appended-to by packet 05. The Wave-4 release is a single `HoneyDrunk.AI` solution-wide tag after packet 05 merges. (Wave 4 is intra-solution; no cross-solution release-tag gate between packets 04 and 05 themselves.)
- **Wave 4 → Wave 5 boundary** — packet 06 also targets the `HoneyDrunk.AI` solution and appends to packets 04/05's in-progress version. The single solution-wide tag at the end of packet 06 closes the AI work in this initiative. The human tag happens after packet 06 merges; the version is the same one packets 04/05 ramp to. No two-step tag.

The pattern is the standard "agents merge code, humans tag and release" boundary from `adr-0042-idempotency`'s dispatch plan.

## Phase-1 Multiplier Posture — Operator-Tunable

ADR-0052 D14 Phase 1 names "intentionally loose initial caps ($5000 / $10000 across all categories) so the kill-switch does not fire spuriously while baselines are being established." This initiative implements that posture via the **Phase-1 multiplier** on `BudgetConfigProvider` (packet 05):

- `CostLedger:PhaseOneMultiplier:Dev` defaults to **10** (dev caps inflated 10x — so dev burn must be 10x the D2 dev cap to trigger).
- `CostLedger:PhaseOneMultiplier:Staging` defaults to **10**.
- `CostLedger:PhaseOneMultiplier:Prod` defaults to **1** (prod caps at the D2 values from day one — prod is exposed to fewer test spikes than dev).

The Phase-3 flip (D14 Phase 3) is to set the dev/staging multipliers to 1, after one month of Phase-1 baseline. The flip is **operator-driven via App Configuration**, not a code change. Packet 09's playbook names the flip as deferred-follow-up item #10 with the recommended observation period.

## Initial Caps vs Phase-1 Multiplier — the Two Knobs

Both the multiplier and the cap values are operator-tunable, but they have different change paths:

- **The caps** live in `business/context/cost-budgets.json` (packet 02). Changes go through the **slow PR path** with `review` agent gating (`cost-config` category, packet 08). The audit trail is the git history.
- **The Phase-1 multiplier** lives in App Configuration. Changes are **operator-driven**, immediate, and not in this initiative's PR scope. The runtime picks them up on the next config refresh.

The two knobs are independent: the operator may flip the multiplier without changing the caps, or tune the caps without touching the multiplier. The `cost-config` review category gates only the cap changes; the multiplier flip is a config-management decision outside the JSON file.

## Phase 4 Pilot — Deploy-Side Sequencing

ADR-0052 D14 Phase 4 ("kill-switch enablement") is the dangerous phase — it changes runtime behaviour from logging to throwing. The phased posture in the ADR is to pilot on AI inference for one week before extending to other categories. This initiative ships the runtime change (packet 06); the pilot is a deployment concern.

The recommended deploy sequence is documented in packet 06's PR description:
1. Deploy packet 06's runtime to **dev** with the Phase-1 multiplier at 10 (cap effectively loose).
2. Observe for one week. False breaches in dev are expected to be near-zero; the dev cap is inflated 10x.
3. Flip the multiplier to 1 in dev. Observe for one more week. False breaches now indicate either a real budget event (good — the system works) or a defect in the ledger / cache / config (bad — investigate).
4. Deploy packet 06's runtime to **prod**. The Phase-1 multiplier is 1 in prod from day one. Real breaches in prod are the system doing its job.

The operator may compress or extend the schedule based on observed behaviour. The PR's `CostLedger:KillSwitch:Enabled` App Configuration value is a safety hatch — flipping it `false` bypasses the interceptor in case Phase 4 itself has a defect.

## Cross-Cutting Concerns

### Operator-side surfaces are out of scope by design

This is named loudly in every relevant packet. ADR-0052 commits a Grid-wide substrate, but this initiative ships only the foundation layer (contracts + AI-side implementation + AI-side dispatcher wiring) plus the Architecture-repo governance. **Every Operator-hosted surface — the aggregator polling Azure Cost Management / GitHub Actions / vendor APIs; the Container Apps auto-suspend job; the `hd cost` CLI; the "Cost" dashboard view; the App Insights anomaly Bicep; the Communications + Notify alert wiring — waits on ADR-0018 (Operator standup) and is named in packet 09's playbook.**

This is consistent with the Memory note `feedback_adr_before_scaffold`: standup work gets its own ADR; do not bundle scaffold into feature packets. ADR-0018 is the standup; this initiative is the foundation; the future Operator-side cost-governance initiative is the standup follow-on.

### AI Node scaffold gate

`HoneyDrunk.AI` is at v0.1.0 / seed. Packets 05 and 06 require the AI Node to be scaffolded enough to host a Cosmos client and a `HostedService`. If the AI scaffold has not landed by Wave 3 → 4 boundary, packets 05 and 06 wait. The operator may need to file the AI scaffold packet (ADR-0016 Phase 1) before Wave 4 can proceed. The dispatch plan flags this as the initiative's biggest gate.

### `IErrorReporter` cross-initiative dependency

Packet 06 expects `IErrorReporter` from `HoneyDrunk.Telemetry.Abstractions` (shipped by ADR-0045's initiative). If ADR-0045 has not landed by packet 06's run time, the executor uses the structured-log fallback documented in packet 06.

### Replace, not extend — the AI-side `ICostLedger`

The seed `HoneyDrunk.AI.Abstractions.ICostLedger` is removed in packet 04. The contract has no out-of-repo consumer (the AI Node is at seed status); the removal is an additive minor bump on the AI solution. If a downstream consumer somewhere does pin on the old contract, the bump may break it — the operator should grep the workspace for `HoneyDrunk.AI.Abstractions.ICostLedger` usage before packet 04 merges. The most likely consumers are the four AI provider packages, which packet 04 migrates.

### Cosmos as the v1 backing — and the AI Node's first persistence dependency

Packet 05 introduces Cosmos into `HoneyDrunk.AI` for the first time. The provisioning is a Human Prerequisite (portal click per the Memory `feedback_portal_over_cli` note). The cost of the ledger's Cosmos consumption is itself an Azure-infra line item; the future Operator aggregator picks it up and writes it back to the ledger as a recursive line. This is fine — the recursion closes at the aggregator's daily polling cadence.

### Site sync

No site-sync flag. ADR-0052 is internal Ops infrastructure — no public-facing Studios website content changes.

### Catalog cleanup in packet 09 is conditionally gated on packet 04

Packet 09's catalog cleanup (removing the AI-side `ICostLedger` entry from `contracts.json`) is conditionally gated on packet 04 having merged. If packet 04 is unmerged when packet 09 runs, the cleanup is deferred and noted in the PR. The playbook half of packet 09 ships regardless.

## Rollback Plan

- **Packets 00–02, 07, 08, 09 (governance / catalog / config / docs):** revert the PR. ADR returns to Proposed; the three invariants, the catalog entries, the budget config file, the report format, the review-agent rules, and the playbook are removed. No runtime impact.
- **Packet 03 (Kernel contracts):** revert the PR; the `HoneyDrunk.Kernel` solution rolls back the version bump. The contracts are additive — no consuming Node depends on them until it composes them, so the revert is contained to `HoneyDrunk.Kernel`. Packets 04+ would fail to compile against the new Kernel version, so revert packet 04 first if packet 04 has already merged.
- **Packet 04 (AI relocation):** revert the PR; the seed `HoneyDrunk.AI.Abstractions.ICostLedger` returns; provider call sites return to the old `RecordAsync(InferenceCost)` shape; `DefaultCostLedger` returns to its old implementation. The AI solution version rolls back. The seed contract has no external consumer; the revert is contained.
- **Packet 05 (Cosmos backing):** revert the PR; `DefaultCostLedger` returns to the stub (or to whatever packet 04 left). The Cosmos container the human provisioned remains but is unused — the operator can manually delete it from the portal. No runtime impact on call sites since the stub answers `IsHardCapBreachedAsync = false` for every category.
- **Packet 06 (dispatcher kill-switch wiring):** revert the PR; the AI dispatcher returns to pre-Phase-4 behaviour (no cap check on the hot path). The kill-switch is inert; the cap-check answer is correct but no call site consumes it. **Operational escape hatch:** `CostLedger:KillSwitch:Enabled=false` in App Configuration disables the interceptor without code revert — a one-config-value change, no redeploy.
- **Backend-level escape hatch:** ADR-0052 D11's override CLI (gated on Operator standup) is the architectural rollback for the kill-switch firing wrongly — issue an override for the affected category, investigate, and revert if the breach was a defect. The override is audited; the revert is recoverable.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

**Before pushing:** there are no cross-initiative `Architecture#<n>` placeholders in this initiative — every `dependencies:` array uses `packet:NN` (within-folder) edges only. Safe to push as soon as the packets are written.

The cross-initiative cross-references that are *not* `dependencies:` edges (the ADR-0042 version-state check on Kernel, the ADR-0016 AI scaffold gate, the `IErrorReporter` from ADR-0045) are documented as Cross-Initiative Coordination notes rather than as edges — they are check-at-edit-time concerns, not packet-ordering concerns.
