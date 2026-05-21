# Drift Report

Tracked automatically by the hive-sync agent. Items listed here are
inconsistencies between Accepted decisions and the rest of the Architecture
repo. The agent surfaces these - it does not fix them. Resolution is the
scope/adr-composer/human's responsibility.

Last synced: 2026-05-21 (post-PR-#162/#164 ADR-0034–0047 reconciliation)

## Invariants Named in ADRs but Missing from `invariants.md`

_No drift detected._ ADRs 0034–0047 are all Proposed; none introduce
new invariants that have landed in `constitution/invariants.md` yet.
Each ADR's invariant section will be reconciled at acceptance time per
the standing rule that invariants land with acceptance, not proposal.

## Capability Matrix Rows with No Agent File

_No drift detected._

## Agent Files with No Capability Matrix Row

_No drift detected._

## Catalog Schema Drift (ADRs 0034–0047)

These are catalog field/file additions implied by the 14 newly Proposed
ADRs. None should land until the parent ADR is Accepted; surfacing
them here so the cascade is visible.

| ADR | Implied Catalog Change | Status | Detail | First Surfaced |
|-----|------------------------|--------|--------|----------------|
| ADR-0034 | New file `catalogs/package-feeds.json` | Not created | ADR-0034 names this as the approved-feeds registry. File does not yet exist. | 2026-05-21 |
| ADR-0034 | Per-Node package metadata fields (`feed`, `repository_url`, `source_link`, `deterministic_build`, `signed`) | Not added | No fields on `catalogs/nodes.json` yet capture publish-feed/signing posture per Node. | 2026-05-21 |
| ADR-0035 | Per-Node `abstractions_version` / API-baseline tracking | Not added | ADR-0035 mandates `Microsoft.CodeAnalysis.PublicApiAnalyzers` + API-diff job; no catalog surface yet for ABI baseline state. | 2026-05-21 |
| ADR-0036 | `dr_tier` field on `catalogs/grid-health.json` Node entries (T0/T1/T2) | Not added | ADR-0036 explicitly names this field. T0 candidates per ADR: Vault, Audit, Notify Cloud tenant identity/billing. | 2026-05-21 |
| ADR-0036 | `last_dr_drill` field on `catalogs/grid-health.json` | Not added | ADR-0036 mandates missed-drill freeze on tier-affecting tenant onboarding; requires catalog surface to enforce. | 2026-05-21 |
| ADR-0037 | Future `honeydrunk-billing` Node entry in `catalogs/nodes.json` | Not added | ADR-0037 introduces `HoneyDrunk.Billing` (owns `IBillingEventEmitter` → Stripe Meter Events pipe + `HoneyDrunk.Billing.Webhooks`). No catalog entry yet — correctly deferred until acceptance. | 2026-05-21 |
| ADR-0037 | `IBillingEventEmitter` ownership migration in `catalogs/contracts.json` | Pending | Today `IBillingEventEmitter` lives under `honeydrunk-kernel` (per ADR-0026). ADR-0037 moves runtime implementation to Billing. Catalog must reconcile Kernel-defines vs Billing-implements at ADR-0037 acceptance. | 2026-05-21 |
| ADR-0038 | New `IDeliverabilityFeedbackSink` interface under `honeydrunk-notify` in `catalogs/contracts.json` | Not added | ADR-0038 freezes this contract in `Notify.Abstractions`. | 2026-05-21 |
| ADR-0039 | `license` field on every Node in `catalogs/nodes.json` | Not added | ADR-0039 explicitly names this field. Defaults: MIT for OSS Nodes, FSL-1.1-MIT for revenue Nodes (Notify.Cloud), MIT for SDKs, proprietary for private Nodes. ADR-0039 also states "hive-sync reconciles" — agent must add this responsibility on acceptance. | 2026-05-21 |
| ADR-0040 | OTel/App Insights configuration field cluster on `catalogs/nodes.json` or `grid-health.json` (`app_insights_resource`, `otlp_endpoint`, `sampling_rule`) | Not added | ADR-0040 pivots backend to Azure Monitor + App Insights; per-Node retention class needed (90d standard vs 730d audit-sourced). | 2026-05-21 |
| ADR-0040 | Retention class on `catalogs/contracts.json` signal entries (`retention_days`) | Not added | Required to enforce the 90d/730d split at the contract/signal layer. | 2026-05-21 |
| ADR-0041 | New file `models.json` in `HoneyDrunk.AI` repo (not Architecture) + `IModelRegistry`/`ModelRegistration` in `catalogs/contracts.json` under `honeydrunk-ai` | Not added | Registry file lives in the AI Node, but the contracts catalog must register the new interfaces and the `ModelCapabilityDeclaration` augmentation. | 2026-05-21 |
| ADR-0042 | New Kernel contracts: `IGridMessageEnvelope.IdempotencyKey`, `IIdempotencyStore`, `IdempotentMessageHandler<T>` in `catalogs/contracts.json` under `honeydrunk-kernel` | Not added | ADR-0042 is a hard prerequisite for ADR-0037 and load-bearing for ADR-0036's T2 failover. | 2026-05-21 |
| ADR-0044 | `review_risk_class` field on `catalogs/grid-health.json` Node entries | Not added | ADR-0044 explicitly names this field for the high-risk-Node multi-perspective requirement. | 2026-05-21 |
| ADR-0045 | `IErrorReporter` interface under `honeydrunk-observe` in `catalogs/contracts.json` | Not added | ADR-0045 freezes this contract; provider-slot pattern parallel to existing Observe connectors. | 2026-05-21 |
| ADR-0045 | Notify's existing Sentry integration migration tracker | Not surfaced | ADR-0045 migrates Notify off Sentry to App Insights via a parallel-output window. No initiative file yet — acceptance work, not current drift. | 2026-05-21 |
| ADR-0046 | New `.claude/agents/` files: `cfo.md`, `a11y.md`, `security.md`, `performance.md`, `ai-safety.md` + matching `constitution/agent-capability-matrix.md` rows | Not added | ADR-0046 phased rollout (`cfo` → `security` → `performance` → `ai-safety` → `a11y`). Agent files land at acceptance/phase boundaries, not at proposal. | 2026-05-21 |
| ADR-0047 | Per-Node `coverage_target` field on `catalogs/grid-health.json` (cross-references `dr_tier` from ADR-0036) | Not added | ADR-0047 ties coverage targets to ADR-0036 DR tiers (T0 85/80, T1 75/70, T2 60/55). Coupled to ADR-0036 catalog work. | 2026-05-21 |

## Cross-ADR Dependencies and References

| Item | Detail | First Surfaced |
|------|--------|----------------|
| ADR-0034 + ADR-0035 codependency | ADR-0034 and ADR-0035 "land together" per both ADR texts. Acceptance should be a single coordinated initiative, not two parallel scope packets. | 2026-05-21 |
| ADR-0040 + ADR-0045 codependency | ADR-0045 declares "same App Insights resource per ADR-0040 — no new vendor". ADR-0045 cannot accept before ADR-0040; surface as a sequencing constraint at scope time. | 2026-05-21 |
| ADR-0042 prerequisite chain | ADR-0042 is a hard prerequisite for ADR-0037 (idempotent Stripe billing) and load-bearing for ADR-0036's T2 failover claim. Acceptance order: ADR-0042 → ADR-0037; ADR-0042 → ADR-0036 (or accept jointly). | 2026-05-21 |
| ADR-0034 author-signing dependency on BDR-0001 | ADR-0034 D-author-signing gates package signing on BDR-0001 (mailbox/entity finalization). BDR-0001 is Accepted but Sunbiz amendment still in flight before Oct 2026; signing is therefore gated, not blocked, but cannot start at ADR-0034 acceptance. | 2026-05-21 |
| ADR-0046 reference to ADR-0044 D3 | ADR-0046 cites ADR-0044 D3 "upstream-awareness clause" as binding specialist agents at ADR/PDR/packet drafting time, not only PR review. Tight coupling — ADR-0046 cannot accept independently of ADR-0044. | 2026-05-21 |
| ADR-0047 dependency on ADR-0036 | ADR-0047 coverage thresholds are keyed off ADR-0036 DR tiers. ADR-0036 should accept first (or jointly) so the threshold table has a referent. | 2026-05-21 |
| ADR-0033 / ADR-0040 / ADR-0041 reference `business/context/` | ADR-0040 and ADR-0041 implicitly reference cost-aware reasoning rooted in studio-level operational context. `business/context/` currently holds only `entity.md`; no vendor cost tables, no AI-spend ledger. Not a blocker — surface as a follow-up for `business/context/`. | 2026-05-21 |

## Issue Packet Manifest Drift

| Path | Issue | Detail | First Surfaced |
|------|-------|--------|----------------|
| `generated/issue-packets/active/adr-0010-observe-ai-routing-phase-1/04-ai-add-routing-contracts.md` | HoneyDrunk.AI#1 | Manifest references a packet file that no longer exists; a `.superseded.md` packet for the same original scope remains and is separately filed as HoneyDrunk.AI#3. Human/scope agent should reconcile duplicate open issues before executing ADR-0010/ADR-0016 AI work. | 2026-05-18 |
| `generated/issue-packets/active/standalone/2026-05-20-actions-file-packets-body-length-precheck.md` | HoneyDrunkStudios/HoneyDrunk.Actions#83 | Standalone packet was filed (Actions#83) the day after `file-packets.sh` tripped GitHub's 65536-character body limit on ADR-0031 packets 03/04. Open/closed state could not be verified this run (GitHub API not reachable from the sync environment — see Auth Issues below). If Actions#83 is closed, the packet should move to `completed/standalone/` and the manifest entry pruned per the 30-day rule; if still open, leave active. Human/scope agent confirms once API access is restored. | 2026-05-21 |

## Nodes in `nodes.json` with Missing GitHub Repos

| Node | Repo URL | Detail | First Surfaced |
|------|----------|--------|----------------|
| HoneyDrunk.Studios | https://github.com/HoneyDrunkStudios/HoneyDrunk.Studios | `gh repo view` could not resolve the repository. Catalog may point at the wrong repo name or the repo may be missing/private beyond current token scope. | 2026-05-07 |
| HoneyDrunk.Evals | https://github.com/HoneyDrunkStudios/HoneyDrunk.Evals | `gh repo view` could not resolve the repository. Catalog lists the Node, but the GitHub repo is not present/resolvable. | 2026-05-07 |
| HoneyDrunk.Sim | https://github.com/HoneyDrunkStudios/HoneyDrunk.Sim | `gh repo view` could not resolve the repository. Catalog lists the Node, but the GitHub repo is not present/resolvable. | 2026-05-07 |

### Auth Issues (token-scope problems, not drift)

| Issue | Detail | First Surfaced |
|-------|--------|----------------|
| GitHub API unreachable | This run could not reach `api.github.com` or invoke `gh` — the sync environment exposes only a git-proxy endpoint, so Step 1b (issue-state pre-query), Step 1f (Hive board query), and the Step 12 GitHub-repo existence checks could not refresh their data. The packet lifecycle (Step 10), completed-manifest pruning (Step 11), and non-initiative board reconciliation (Step 8) were therefore skipped for this run; all other initiative-tracking edits are sourced from in-repo annotations already reconciled by the 2026-05-21 hive-sync run on main (#156). Re-run hive-sync once API access is restored. | 2026-05-21 |

## Nodes Named in ADRs but Missing from `nodes.json`

| Node | Detail | First Surfaced |
|------|--------|----------------|
| HoneyDrunk.Billing | Introduced by ADR-0037 (Payment and Billing Integration). Owns `IBillingEventEmitter` runtime + `HoneyDrunk.Billing.Webhooks`. Not yet in `catalogs/nodes.json` — correctly deferred until ADR-0037 acceptance, surfaced here for visibility. | 2026-05-21 |
