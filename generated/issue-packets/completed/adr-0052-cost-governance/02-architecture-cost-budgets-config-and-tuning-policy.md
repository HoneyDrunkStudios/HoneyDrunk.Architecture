---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "docs", "adr-0052", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0052"]
accepts: ["ADR-0052"]
wave: 1
initiative: adr-0052-cost-governance
node: honeydrunk-architecture
---

# Create business/context/cost-budgets.json with the D2 defaults and the tuning policy doc

## Summary
Create `business/context/cost-budgets.json` carrying the ADR-0052 D2 per-category soft/hard caps and the D10 anomaly thresholds, plus the D12 dev-environment overlay. Author the tuning policy doc that describes the slow PR path (this file) and the fast override path (D11 `hd cost unlock` CLI, future) so the operator and the `review` agent know how to handle changes to this file.

## Context
ADR-0052 D2 commits the per-category budget caps and names `business/context/cost-budgets.json` as the canonical configuration file. The file is **production-critical**: a mis-edit could disable the kill-switch (raise the hard cap to infinity) or trigger spurious shutdowns (drop the hard cap below current month-to-date). The PR-review flow on this file is therefore a production-config review.

ADR-0052 D2 specifies the v1 defaults:

| Category | Soft cap | Hard cap | Notes |
|---|---|---|---|
| AI inference | $500 | $1500 | Grid-wide across all models and providers |
| Azure infrastructure | $300 | $800 | Sum across Container Apps, App Insights, Vault, storage, etc. |
| Third-party SaaS | $200 | — | Soft only (no programmatic kill-switch for SaaS subscriptions) |
| Domain / cert / registrar | $25 | — | Soft only (annual renewals amortized) |
| GitHub Actions minutes | $50 | $150 | GitHub-native spending limit enforces |

D14 Phase 1 says "**initial caps are intentionally loose** ($5000 / $10000 across all categories) so the kill-switch does not fire spuriously while baselines are being established." This packet seeds the D2 defaults but the runtime loader (packet 05) will compose them with a Phase-1 multiplier or load a Phase-1 override file — the runtime behaviour is configured by the operator at Phase 3 (D14) per the tuning policy. **This packet ships the D2 final-state defaults**, not the Phase-1 loose caps; the Phase-1 multiplier is a deployment concern documented in the playbook (packet 09).

D10 anomaly thresholds: hour-over-hour 5x, day-over-day 3x. The thresholds are per-category configurable; the file carries them as the canonical defaults that the App Insights alert Bicep (future, gated on Operator standup) reads.

D12 dev caps: $50/$100 AI inference, $25/$50 Azure infra, $25/$50 GitHub Actions. Production caps do not include dev burn. The file carries a `dev` overlay block.

**Where the file lives.** ADR-0052 D2: `business/context/cost-budgets.json` (new file, sibling to the vendor list referenced in the drift report). The `business/context/` directory holds BDR-style and policy-adjacent records — match the existing per-file shape in that directory at edit time. If `business/context/` does not yet exist as a directory (the drift report notes its absence), create it with a brief `README.md` describing its purpose (BDR records + cross-cutting policy config). Check at edit time.

**Tuning policy.** ADR-0052 D2: "Changes to the file are tracked by git, reviewed via the standard PR flow, and audited. The PR flow is the **slow path** for changing caps — it preserves a permanent record of 'the cap was raised on this date, by this PR, with this reasoning.' The fast path (D11 override CLI) is for emergencies; the PR flow is for considered policy changes. Mixing them by allowing CLI to mutate `cost-budgets.json` directly would erode the audit trail and is explicitly forbidden." This packet records that policy as a doc next to the file (or in the established `business/context/` policy-notes location).

**No code in this packet.** The runtime loader for the config file lives in `HoneyDrunk.AI` (packet 05) consuming `IBudgetConfigProvider` (cataloged in packet 01, built in packet 03). This packet ships the config data and the policy doc only.

**`review` agent follow-up flagged.** ADR-0052's Follow-up Work names "Add a `cost-config` review category to `.claude/agents/review.md` per ADR-0044 D3, covering the production-critical nature of `business/context/cost-budgets.json` changes." That edit lands in packet 08, not here — but this packet's policy doc points forward to the `review` category that gates edits to this file.

## Scope
- `business/context/cost-budgets.json` — new file carrying the D2 default soft/hard caps, the D10 anomaly thresholds, and the D12 dev overlay.
- A tuning policy doc next to the file (or in the `business/context/` policy-notes location) describing the slow PR path and the fast override path.
- If `business/context/` does not yet exist as a directory, create it with a brief `README.md` describing its purpose.

## Proposed Implementation
1. **`business/context/cost-budgets.json`** — JSON document with the shape (final shape decided at edit time to match the `IBudgetConfigProvider` deserialization in packet 03; the structure below is the canonical content):
   ```
   {
     "_meta": {
       "schema_version": 1,
       "source_adr": "ADR-0052",
       "currency": "USD",
       "window": "monthly",
       "last_tuned": null,
       "note": "Production-critical config — see ./cost-budgets-tuning-policy.md."
     },
     "categories": {
       "ai_inference":          { "soft_cap": 500,  "hard_cap": 1500, "kill_switch": "in_process",      "anomaly_hour_over_hour": 5.0, "anomaly_day_over_day": 3.0 },
       "azure_infrastructure":  { "soft_cap": 300,  "hard_cap":  800, "kill_switch": "azure_suspend",   "anomaly_hour_over_hour": 5.0, "anomaly_day_over_day": 3.0 },
       "third_party_saas":      { "soft_cap": 200,  "hard_cap": null, "kill_switch": "none",            "anomaly_hour_over_hour": 5.0, "anomaly_day_over_day": 3.0 },
       "domain_cert_registrar": { "soft_cap":  25,  "hard_cap": null, "kill_switch": "none",            "anomaly_hour_over_hour": 5.0, "anomaly_day_over_day": 3.0 },
       "github_actions":        { "soft_cap":  50,  "hard_cap":  150, "kill_switch": "github_native",   "anomaly_hour_over_hour": 5.0, "anomaly_day_over_day": 3.0 }
     },
     "dev_overlay": {
       "ai_inference":         { "soft_cap":  50, "hard_cap": 100 },
       "azure_infrastructure": { "soft_cap":  25, "hard_cap":  50 },
       "github_actions":       { "soft_cap":  25, "hard_cap":  50 }
     },
     "owners": {
       "ai_inference":         "oleg",
       "azure_infrastructure": "oleg",
       "third_party_saas":     "oleg",
       "domain_cert_registrar":"oleg",
       "github_actions":       "oleg"
     }
   }
   ```
   The exact JSON-key naming is finalized to match `BudgetConfig` deserialization in packet 03; check there at edit time. The category keys above (`ai_inference`, etc.) map onto `CostCategory.AiInference` etc. — pick the casing convention `BudgetConfig` uses.
2. **`business/context/cost-budgets-tuning-policy.md`** (or the established cross-cutting policy-notes location) — describe:
   - The slow path (this file, PR-reviewed) is the only mechanism that mutates persistent caps.
   - The fast path (D11 `hd cost unlock` CLI on the Operator Node, future) issues time-bounded overrides — it does **not** mutate this file.
   - Direct database writes to `BudgetOverride` are forbidden (invariant 92).
   - Permanent overrides do not exist — re-engagement is the safer default (D11).
   - Cap-raise PRs must justify the change in the PR description (the audit value is "the cap was raised on this date, by this PR, with this reasoning").
   - The `review` agent has a `cost-config` review category (packet 08, future) that treats edits to this file as production-config changes.
3. **`business/context/README.md`** — only if the directory does not yet exist. Brief: the directory holds BDR-style records and cross-cutting policy configuration the Grid runtime consumes (cost budgets, vendor list, etc.). Editing is PR-only.
4. **CHANGELOG.** `HoneyDrunk.Architecture` is not a versioned .NET solution; the repo-level `CHANGELOG.md` is appended to under the in-progress Unreleased / dated section per the repo convention.

## Affected Files
- `business/context/cost-budgets.json` (new)
- `business/context/cost-budgets-tuning-policy.md` (new — or an entry in the established cross-cutting policy-notes location)
- `business/context/README.md` (new, only if the directory does not yet exist)
- Repo-level `CHANGELOG.md`

## NuGet Dependencies
None. JSON config and Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly. `business/context/` is an Architecture-repo directory.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency. The runtime loader for this file lives in `HoneyDrunk.AI` (packet 05); this packet ships the data only.

## Acceptance Criteria
- [ ] `business/context/cost-budgets.json` exists with the D2 defaults: AI inference $500/$1500, Azure infra $300/$800, SaaS $200 soft-only, domain/cert $25 soft-only, GitHub Actions $50/$150
- [ ] The file carries the D10 anomaly thresholds (5.0 hour-over-hour, 3.0 day-over-day) per category, as configurable defaults
- [ ] The file carries the D12 `dev_overlay` block: AI inference $50/$100, Azure infra $25/$50, GitHub Actions $25/$50
- [ ] The file carries an `owners` block with `oleg` as the v1 owner for every category (D1)
- [ ] The file's category key naming matches the `BudgetConfig` deserialization shape from packet 03 (resolve at edit time — the catalog entry in packet 01 names the contract `BudgetConfig`)
- [ ] A tuning policy doc (sibling to the JSON file, or in the established policy-notes location) describes the slow PR path vs the fast override path; states that direct `BudgetOverride` database writes are forbidden (invariant 92); states that no permanent override exists (D11); states the `review` agent's future `cost-config` category gates edits
- [ ] If `business/context/` did not exist as a directory before this packet, it now exists with a brief `README.md`
- [ ] Repo-level `CHANGELOG.md` carries an entry naming the new files

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0052 D2 — Budget tiers and alert thresholds.** Per-category monthly soft caps (alert only) and hard caps (alert + kill-switch). Defaults: AI inference $500/$1500, Azure infra $300/$800, SaaS $200 soft-only, domain/cert $25 soft-only, GitHub Actions $50/$150. The values live in `business/context/cost-budgets.json`. Changes go through git-tracked PR review. The split between soft and hard is intentional: soft is a warning, hard is an action; the 3x gap is a heuristic per-category-tunable.

**ADR-0052 D10 — Anomaly detection thresholds.** Hour-over-hour 5x spike in cost-event volume or value; day-over-day 3x spike in summed cost value. Per-category configurable. AI inference has higher natural variance than Azure infra; tune per category as actuals accumulate.

**ADR-0052 D12 — Dev caps on a separate subscription (or tagged resource group).** Dev defaults: AI inference $50/$100, Azure infra $25/$50, GitHub Actions $25/$50. Production caps do not include dev burn. Dev follows the same enforcement posture (D4) — hard cap fires the kill-switch, alerts go through the same Notify channel, overrides require the same audit.

**ADR-0052 D11 — Operator unlock policy.** Override CLI is `hd cost unlock <category> --reason "<text>" --duration <hours>` on HoneyDrunk.Operator. Time-bounded (default 24h). Audited via `IAuditLog` per ADR-0030. **Does not mutate `cost-budgets.json`.** No permanent override.

**ADR-0052 Operational Consequences — `cost-budgets.json` becomes production-critical.** A mis-edit could disable the kill-switch or trigger spurious shutdowns. The PR-review flow on this file is a production-config review; the `review` agent (per ADR-0044) treats it accordingly. The cost-config review category lands in packet 08.

## Constraints
- **No code in this packet.** The runtime loader is in `HoneyDrunk.AI` (packet 05). This packet ships data + policy doc only.
- **D2 defaults — not the Phase-1 loose caps.** Ship the D2 final-state numbers. The Phase-1 loose-cap multiplier is a deployment concern named in the playbook (packet 09), not a different config file.
- **Match the `BudgetConfig` deserialization shape.** The JSON keys (`ai_inference`, etc.) map onto `CostCategory.AiInference`. The casing convention is decided in packet 03 (`BudgetConfig`); check at edit time and match. Do not invent a parallel naming.
- **Tuning policy makes the audit boundary explicit.** The doc must state that the JSON file is the slow path, the CLI is the fast path, the two never blur, and direct `BudgetOverride` writes are forbidden (invariant 92).

## Labels
`feature`, `tier-2`, `ops`, `docs`, `adr-0052`, `wave-1`

## Agent Handoff

**Objective:** Create `business/context/cost-budgets.json` with the ADR-0052 D2 defaults / D10 anomaly thresholds / D12 dev overlay, and author the tuning policy doc that records the slow-PR-path vs fast-override-path boundary.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Seed the canonical cost-budget configuration the runtime loader (packet 05) will consume, with the tuning policy clearly documented so future edits land via PR review.
- Feature: ADR-0052 Cost Governance rollout, Wave 1.
- ADRs: ADR-0052 D1/D2/D10/D11/D12 (primary), ADR-0030 (Audit — the audit boundary the policy doc references).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0052 should be Accepted before its config defaults are committed.

**Constraints:**
- D2 defaults, not Phase-1 loose caps.
- JSON keys match the packet-03 `BudgetConfig` shape (resolve at edit time).
- Tuning policy makes the slow-PR vs fast-CLI boundary explicit; states that direct `BudgetOverride` writes are forbidden (invariant 92); no permanent override.

**Key Files:**
- `business/context/cost-budgets.json`
- `business/context/cost-budgets-tuning-policy.md` (or the established policy-notes location)
- `business/context/README.md` (only if the directory does not yet exist)

**Contracts:** None. Config and docs only.
