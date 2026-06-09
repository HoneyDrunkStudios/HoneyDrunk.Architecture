# Roadmap

High-level roadmap for the HoneyDrunk Grid.

**Last Updated:** 2026-06-09

For the near-term ranked priority list, see [current-focus.md](current-focus.md); this roadmap is the quarterly horizon.

The studio is currently building three product threads in 2026 — **HoneyHub** (now the lead thread; v1 re-scoped per PDR-0011 to the **Agent-Cockpit** wedge — govern/monitor local AI coding-agent sessions — with the internal daily-driver workspace of PDR-0009 sequenced as a later layer), **Notify Cloud** (PDR-0002, the Grid's first commercial trial, re-sequenced behind the **ADR-0077** IaC consolidation its cloud bring-up composes on), and **Curiosities** (PDR-0008, discovery-first city app) — on top of the substrate. The first game thread begins in 2027. Per the [charter](../constitution/charter.md), foundation work is real work, *and* it has to serve the workshop rather than consume it; ADRs on this roadmap are filtered to those that materially move the substrate forward for the product threads in flight. AI-sector standup ADRs (0017–0025) and other future-tense surfaces live in **Future** until a real consumer pulls them in. A new substrate thread — **loop engineering (ADR-0093, Accepted; Tier-A substrate shipped 2026-06-09)** — cuts across all three product threads: it is how one operator runs many product build and maintenance loops in parallel. The Tier-A substrate (doctrine + `loops/` LDR registry + six backfilled LDRs) is landed and at exit-review; the autonomy ladder pulls **HoneyDrunk.Evals (ADR-0023)** forward from Future as the Tier-B gate that makes those loops autonomous (the operator-not-the-per-step-bottleneck unlock).

## Q1 2026 (Jan–Mar)

- [x] Kernel 0.4.0 — Context model stabilization, static mappers, DI guard
- [x] Transport 0.4.0 — Kernel vNext integration, fail-fast envelope validation
- [x] Vault 0.2.0 — Full provider implementations, canary tests
- [x] Auth 0.2.0 — Vault-backed keys, policy evaluator, startup validation
- [x] Web.Rest 0.2.0 — Exception mapping, correlation mismatch warnings
- [x] Data 0.3.0 — Architecture overhaul, canary coverage
- [x] Pulse 0.1.0 — Multi-backend sinks, Pulse.Collector (wrapping up)
- [x] Notify 0.1.0 — Email/SMS providers, queue backends (wrapping up)
- [x] Architecture repo — Command center bootstrap, catalog convergence with website

## Q2 2026 (Apr–Jun)

**Foundation / Substrate** *(structurally important to the workshop, per charter §"What this charter licenses")*

- [x] **Code Review Pipeline (ADR-0011) — completed 2026-05-28** — `adr-0011-code-review-pipeline`: ADR-0011 Accepted 2026-05-25; SonarQube Cloud rollout shipped across all 12 .NET-active Grid repos (Kernel, Transport, Vault, Auth, Web.Rest, Data, Notify, Pulse, Communications, AI, Audit, Observe); `job-sonarcloud.yml` reusable workflow + `agent-run.yml` packet-link injection live in HoneyDrunk.Actions; initial-scan findings (Reliability, Maintainability, Security Hotspots on Communications/Observe) triaged; org-level GitHub ruleset for `SonarCloud Code Analysis` enforced (Active) on the 12 onboarded repos.
- [x] **ADR-0012 Grid CI/CD Control Plane — completed 2026-05-27** — `adr-0012-grid-cicd-control-plane`: tracked_workflows catalog, grid-health aggregator, caller-permissions audit, and Node 20 action bump shipped.
- [x] **ADR-0082 Canonical Node Standup Procedure — deliverables completed 2026-05-29** — `adr-0082-node-standup`: ADR-0082 Accepted (PR #505); invariant 102 + `## Standup Procedure Invariants` section in `constitution/invariants.md`; `constitution/node-standup.md` (PR #508); all six `infrastructure/walkthroughs/` node-standup + org-secret-repo-binding walkthroughs (PR #510). *(All 8 GitHub issues closed 2026-05-29; initiative archived to [archived-initiatives.md](archived-initiatives.md).)*
- [x] **ADR-0080 Vendor Lock-In Posture — Accepted 2026-05-30** — `adr-0080-vendor-lockin`: invariants 99–101 live; `governance/vendor-postures/{azure,github}.md` stubs shipped (PR #515). Archived to [archived-initiatives.md](archived-initiatives.md).
- [x] **ADR-0083 Sensitive Inventory & External-SaaS Credential Rotation — Accepted 2026-05-30** — `adr-0083-external-saas-credentials`: invariant 103 live; `infrastructure/reference/sensitive-inventory.md` + rotation walkthroughs + onboarding hook landed; `external-credentials-check.yml` drift-detection workflow live in Actions; closing PRs #528 (Architecture) + #174 (Actions) merged. Ready for archive. *(The OpenClaw row retired under ADR-0088 after secret deletion.)*
- [x] **ADR-0084 Discord as Operator-Alerts Surface — Accepted 2026-05-31** — `adr-0084-discord-alerts`: invariant 107 live; `constitution/alert-routing.md` + `job-discord-notify.yml` seam + Phase 1 credential-escalation emitter shipped (PRs #551/#178/#180). Phase 3/4 vendor-webhook emitters deferred (substrate-gated on ADR-0088 teardown + ADR-0086 runner decision).
- [x] **ADR-0052 Cost Governance, Budget Alerts, Kill-Switches — Accepted 2026-05-30** — `adr-0052-cost-governance`: invariants 104–106 live; `cost-budgets.json` + `generated/cost-reports/` format + review-agent cost gating shipped (PR #517). Wave-1 governance complete; residual gate map lives in `initiatives/active-initiatives.md`; AI-side ledger impl + `ICostLedger` Kernel relocation (Architecture#355) remain gated on the AI Node scaffold + a human Kernel release.
- [x] **ADR-0088 Decommission OpenClaw — completed 2026-06-02** — accepted; Architecture PR #554 and Actions PR #182 merged; runtime/tunnel/reference/governance cleanup done; `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` deleted; issue #527 closed; invariant-103 cleanup removed the inventory row, rotation walkthrough, and node-standup matrix row. Ready for archive / exit-criteria review.
- [x] **ADR-0033 environment-gated trigger packets — completed 2026-06-01** — unblocked Notify/Pulse dev deploy trigger model under ADR-0015 *(3/3 issues closed; ADR-0033 Accepted)*
- [x] **ADR-0077 Infrastructure-as-Code (Bicep) consolidation — Accepted (amended 2026-06-02); done and tested** — the amended ADR (invariants 90–92) stands up the new `HoneyDrunk.Infrastructure` repo (`modules/` + `platform/` + `nodes/`); module registry dropped, deploy/lint pipeline stays in Actions per ADR-0012. Forcing function: the ADR-0015 dev deploy proved the hand-provisioning pain (apps built live via `az rest`). Notify Cloud's cloud bring-up composes on the reproducible provisioning this delivers. **Per operator the Bicep IaC work is fully done and tested.** *(19/19 issues closed; implementation-notes hold; `HoneyDrunk.Infrastructure` already registered in `nodes.json` — catalog residual folded into the reconcile sweep, current focus #9)*
- [ ] **ADR-0043 Backlog Generation — Phase 1 kickoff** — ADR **Accepted**; automation substrate (generated surfaces, invariants, agent prompts, ADR-0086 job specs) landed. Residual is the first live run: register scheduled tasks on the runner host + execute the first Strategic source run. Closes the ADR → packet auto-generation loop; Strategic source feeds on ADR acceptances. *(current focus #3 — due 2026-07-15 target)*
- [ ] **ADR-0093 Loop Engineering — substrate (Tier A) — Accepted; substrate shipped 2026-06-09** — ADR-0093 **Accepted**; the Tier-A substrate landed directly on branch `claude/work-prioritization-6t11r8` (commit 4f3baf6, not via PR): doctrine `constitution/loop-engineering.md`, the `loops/` LDR catalog + `LDR-TEMPLATE.md`, and six backfilled LDRs (`loop-0001`–`loop-0006`) for the loops the Grid already runs. The generalization of ADR-0043: how the operator runs many product loops in parallel. Now at exit-review. Higher autonomy tiers gated — **Tier B on Evals (ADR-0023, pulled to Q3)**, the build-loop gate on ADR-0032, autonomy routing on ADR-0087; the HoneyHub Loop Console on HoneyHub v1 (ADR-0091/0092). *(current focus #1 — due 2026-06-15 target — Tier-A exit-review)*
- [x] **ADR-0015 Container Apps Rollout — completed 2026-06-04** *(5/5 issues closed; ready for archive/exit-criteria review; underwrites Notify Cloud deploy substrate)*
- [ ] **Archive / exit-criteria review + decision-record reconcile sweep** — sweep closed rollouts (ADR-0005/0006, 0009, 0014, 0030, 0032, Lore, Vault.Rotation, Kernel Adoption) into `archived-initiatives.md`; also absorbs two operator-confirmed bookkeeping reconciliations: flip **ADR-0091/0092** to Accepted against the shipped HoneyHub v1 cockpit, and register **`HoneyDrunk.Infrastructure`** in `nodes.json` + file ADR-0077 repo-scaffold packet 11 (the catalog residual of the fully-done-and-tested IaC work). *(current focus #9 — due 2026-06-15 target)*

**Product**

- [ ] **Notify Cloud (PDR-0002) — multi-tenant scaffolding kickoff** — first commercial trial on the Grid; ADR-0027 Node standup, Stripe wiring scoped, tenant isolation at gateway/queue/Vault layers begun. **Re-sequenced behind ADR-0077** — the Notify dev deploy substrate is done, and ADR-0077's reproducible Bicep provisioning is now Accepted and **fully done and tested** per operator, so the cloud bring-up rides it rather than more hand-provisioning. Its actionable precursor is filing the ADR-0027 Notify Cloud Node scaffold packet (current focus #7). **Program tracker:** [programs/notify-cloud.md](programs/notify-cloud.md). *(current focus #8 — due 2026-07-31 target — kickoff slice only)*
- [ ] **Curiosities (PDR-0008) — Phase 0 content spike + loop prototype** — pick launch district, build curated-content pipeline against open data + AI-assisted enrichment, produce ~25 reviewed POIs to measure real per-POI cost; tests Kill Criterion 1 before any significant mobile investment
- [ ] **HoneyHub v1 — Agent Cockpit & Usage Governance (PDR-0011) — LEAD product thread** — v1 re-scoped from the internal read-layer (PDR-0009, now a later layer) to the Agent-Cockpit wedge: govern/monitor local Codex/Claude Code/Copilot sessions (transcripts, token/model governance, mobile monitoring), product-testable on the operator's day-job agent pain ahead of Notify Cloud commercial readiness. PDR-0011 Accepted; the deliverable is promoting the **local-runner-bridge ADR** (the PDR-0009 §G dispatch answer — web/PWA → secure local runner bridge → local agent/git/gh, built on the ADR-0086 substrate) from draft to a numbered, Accepted ADR — **done: the bridge ADR is now ADR-0090, Accepted.** Per operator, **HoneyHub v1 has shipped**; the only residual is reconciliation bookkeeping — the standup ADRs **ADR-0091/0092** are conceptually accepted and only un-flipped, so flipping them to match the shipped cockpit folds into the reconcile sweep, not a standalone build row. **Program tracker:** [programs/honeyhub.md](programs/honeyhub.md) (the live cross-ADR dependency map, per ADR-0089). *(current focus #9 — reconcile sweep — ADR-0091/0092 acceptance reconciliation)*
- [ ] **HoneyDrunk.HoneyHub Standup + Phase 2 (ADR-0090/0091/0092)** — Stand up the Agent Cockpit Node (mixed TS PWA + Rust bridge); Phase 2 ships the Rust bridge core + secure pairing + one backend adapter (Claude Code) + minimal React run screen + local DispatchSession store. Lead near-term build thread per PDR-0011. *(6/10 issues closed)*

**Business operations**

- [ ] **BDR-0001 Mailbox switch — execution kickoff** — VPM signup, USPS Form 1583, mail-forwarding setup *(sequenced; full execution completes Q3 by 2026-09-30 hard deadline)*

**Shipped (Q1/Q2 closure)**

- [ ] **Config & Secrets Rollout (ADR-0005/0006)** *(15/15 issues closed; ready for archive/exit-criteria review)*
- [x] **Package Scanning Rollout (ADR-0009)** *(8/8 issues closed; ready for archive review)*
- [x] **Hive Sync Rollout (ADR-0014)** *(6/6 issues closed; ready for archive/exit-criteria review)*
- [x] Pulse — v0.3.0 Kernel-aligned package release complete; production deployment / Grafana templates remain under ADR-0015
- [x] Notify — v0.3.0 Kernel-aligned package release complete; Azure Functions/Worker deployment remains under ADR-0015
- [x] HoneyDrunk.Communications — v0.2.0 Kernel-abstractions-only runtime/abstractions release complete
- [x] HoneyDrunk.AI — Model/provider abstraction stand-up complete *(ADR-0016 Architecture#72/#73 and AI#2 closed; runtime/provider follow-ups remain future scope)*
- [x] **ADR-0010 Phase 1 (Observation Layer & AI Routing contracts)** *(Architecture#35/#36 and Observe#2 closed; AI routing contracts satisfied by ADR-0016 AI#2 / PR #5; Phase 2 implementation remains future scope)*
- [x] **ADR-0030 Grid-Wide Audit Substrate — Capability Acceptance** *(2/2 packet issues closed; ready for archive/exit-criteria review; standup is the separate ADR-0031 initiative)*
- [x] **ADR-0032 PR Validation Policy — Coverage Gate & NuGet Flagging** *(12/12 packet issues closed; ADR remains Proposed until `accepts:` frontmatter is reconciled or manually flipped)*
- [x] **Kernel Adoption Alignment** *(11/11 packet issues closed; package baseline reconciled to Kernel 0.7.0; ready for archive/exit-criteria review)*
- [x] **HoneyDrunk.Lore Bring-Up** *(6/6 issues closed; flat-file LLM wiki live; ready for archive/exit-criteria review)*

## Q3 2026 (Jul–Sep)

**Product**

- [ ] **Notify Cloud — first external customer / beta** *(PDR-0002 first-revenue milestone)* — REST API + `HoneyDrunk.Notify.Client` NuGet package GA; tenant signup + API key issuance live; first paying or free-tier external developer wired up
- [ ] **Curiosities — Phase 1 launch-district v1** *(PDR-0008)* — expand to 50–100 reviewed POIs with safety-reviewed metadata; wire walk-memory backbone (auto-detected walks → Mochi chapters); add discovery atlas surface; test paid district pack or Founding Explorer tier; measure Kill Criteria 2–4
- [ ] **HoneyHub — read layer + generic Node shell** *(PDR-0009 Phase 2; the later read-layer behind the v1 cockpit)* — read layer over Architecture repo catalogs + frontmatter (SSG-generated static JSON viable for v1); generic per-Node management page composed from `nodes.json` + `grid-health.json` + GitHub; ADR/PDR/initiative/packet list views with filters; no dispatch actions yet
- [ ] **Lore → Grid use-case bridge — author the ADR** — formalize HoneyDrunk.Lore's mandate as the durable operator-memory archive that survives Claude/Codex/Copilot session boundaries (per [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) §2.3); land first consumer wiring (Honeyclaw or another agent path) so the flat-file wiki stops being write-only

**Foundation / Substrate**

- [ ] **ADR-0043 Backlog Generation — Phase 1 ship** — Strategic source event-driven on ADR acceptance + Reactive source for drift; `generated/issue-packets/proposed/` directory live
- [ ] **ADR-0023 Evals standup — the loop-autonomy gate (pulled forward from Q4)** — stand up `HoneyDrunk.Evals` (Abstractions `IEvaluator`/`IEvalScorer`/`IEvalSuite`/`IEvalTarget` + InMemory) as the ADR-0093 Tier-B gate that lets loops run without the operator as the per-step bottleneck. New forcing function: loop engineering, not just a product-eval need; stands up independently of the other 8 AI Nodes. Scaffold packets 01–04 + dispatch-plan authored; the `04-evals-node-scaffold.md` packet needs an issue filed first (current focus #11). *(current focus #2 — due 2026-08-31 target — highest-leverage new build now that HoneyHub v1 has shipped and ADR-0077 IaC is done and tested)*
- [ ] **ADR-0093 Loop Engineering — Tier B (eval-gated loops)** — with Evals as the gate, promote selected backfilled loops from Tier A (human-gated) to Tier B (eval-gated); this is the slice that actually unlocks parallel product build/maintenance loops.
- [ ] **ADR-0046 Specialist Review Agents — Phase 1** — `cfo` agent authored and retroactively invoked against cost-touching PRs; `agent-capability-matrix.md` updated. *(current focus #5 — due 2026-07-15 target)*
- [ ] **ADR-0047 Phase 2 — Tier 2a integration CI** — `job-integration-tests.yml` live in Actions and wired into `pr-core.yml`; closes ADR-0011 Gap 1; prerequisite for a trustworthy ADR-0093 build-loop gate. *(current focus #4 — due 2026-07-31 target)*
- [x] **ADR-0079 Multi-Perspective PR Review Stack — Acceptance** — substantive-PR classifier defined; per-PR cost ceiling committed; ADR-0044 amended with billing-path discipline *(Reviewer 4 path unlocked 2026-06-15 by Claude Max Agent SDK launch)* *(ADR accepted; 5/5 accepting packet issues closed)*
- [ ] **ADR-0010 Phase 2 (first useful increment)** — HoneyDrunk.Observe.Connectors.GitHub (webhook receiver + repo health checks), cost-first IRoutingPolicy implementation in HoneyDrunk.AI, routing policies loaded from Azure App Configuration
- [ ] Cross-repo canary test automation via Actions workflows

**Business operations**

- [ ] **BDR-0001 Mailbox switch — execution complete by 2026-09-30** *(hard deadline)* — VPM live and verified, Sunbiz Articles of Amendment filed, IRS Form 8822-B filed (60-day window from address change), Chase business banking updated, FL DOR updated if applicable, vendor address book refreshed, iPostal1 cancelled after ≥30 days of verified forwarding

## Q4 2026 (Oct–Dec)

**Product**

- [ ] **Notify Cloud — pricing tiers + first decision point** — Stripe metered billing live; charter §"Commercial trials" decision (keep active / drop to maintenance / sunset gracefully) based on customer signal from Q3 beta
- [ ] **Curiosities — Phase 2 content pipeline hardening + Atlas season** — repeatable district-pack build process, editorial review queue, first Yearly Atlas season ("what you uncovered this year"), print-on-demand pipeline live
- [ ] **HoneyHub — dispatch actions via PRs** *(PDR-0009 Phase 3)* — "New ADR," "New PDR," "Scope," "Refine," "Netrunner," "Site-sync" buttons open draft PRs through the local-runner-bridge dispatch service (the v1 cockpit ADR once promoted from draft to numbered Accepted ADR); optimistic UI + inline PR-state visibility

**Foundation / Substrate**

- [ ] **Auth — Multi-tenant identity federation** *(forcing function: Notify Cloud tenant model in production)*
- [ ] **Grid v0.5 planning** — Next contract evolution based on Notify Cloud production learnings
- [ ] **HoneyDrunk.Operator** — Human oversight, approval gates, circuit breakers, cost controls, audit trail *(gated on first AI-sector consumer that needs policy enforcement)*
- [ ] **HoneyDrunk.Evals** — Prompt evaluation, regression testing, model comparison — **pulled forward to Q3** as the ADR-0093 Tier-B loop-autonomy gate (loop engineering is an earlier forcing function than the product-eval need). The original driver *(first ship-blocking eval need from Notify Cloud or Curiosities AI surfaces)* still applies as a second consumer.
- [ ] **Lore — Birdclaw optional X sourcing lane** *(gated on Q3 Lore → Grid bridge ADR landing first consumer wiring; until ingestion has a real downstream destination, expanding capture lanes is write-only churn)* — adds Birdclaw as a targeted, opt-in capture lane for X/Twitter signals via JSON→raw converter; website/RSS remains the default automated path; per [standalone Birdclaw packet](../generated/issue-packets/active/standalone/2026-05-24-lore-birdclaw-optional-x-sourcing-lane.md)
- [ ] Data — Cosmos DB provider exploration *(deferrable — only pull forward if a production workload pressures the relational default)*
- [x] ~~HoneyDrunk.Tools~~ — Scrapped; scanning logic moved to HoneyDrunk.Actions composite actions

## 2027

**Product**

- [ ] **First game thread — kickoff** — begin writing the studio's first game; PDR drafted to lock in genre, loop, and platform scope before code (HoneyPlay's Draft.API / PlayKit / narrative-AI substrate from Long-horizon experiments is the natural home, but the PDR makes the call); sequenced after the 2026 product threads have shipped enough signal to commit creative capacity

**Foundation / Substrate**

- [ ] **Grid v0.5/0.6 evolution** — substrate updates driven by Notify Cloud production learnings, Curiosities content-pipeline learnings, and HoneyHub dispatch-action learnings from 2026
- [ ] **HoneyHub Phase 4–5** *(PDR-0009)* — per-Node operational tabs (Pulse first earner), products on the same shell (Hearth/Curiosities/Notify Cloud at native fidelity)

## Future

*Items here are tracked but not on a quarterly schedule. Promote into a quarter when a forcing function fires (a real consumer pulls them in). Per charter §forbids #2, the substrate must serve the workshop — these stay in Future until they have a use-case caller.*

**AI sector — gated on real consumer demand**

- HoneyDrunk.Knowledge — Document ingestion, RAG pipelines, Azure AI Search provider *(forcing function: Lore→Grid bridge ADR in Q3 establishes the first non-toy Knowledge consumer; until then InMemory contract is enough)*
- HoneyDrunk.Capabilities — Tool registry, discovery, permissioning, initial tool descriptors
- HoneyDrunk.Agents — Agent runtime, lifecycle, execution context, tool/memory interfaces
- HoneyDrunk.Memory — Agent memory contracts, InMemory provider, Agents integration
- HoneyDrunk.Flow — Workflow engine, multi-step pipelines, agent chaining, compensation
- HoneyDrunk.Sim — Simulation, plan evaluation, risk analysis (when agents operate at scale)

**Platform / commercial — gated on Notify Cloud signal**

- HoneyHub external-platform pitch *(PDR-0001 §C)* — "operating system for any software project" remains the long-term commercial direction, but external-tenant adoption stays Future. PDR-0009 commits the internal-daily-driver half of HoneyHub to 2026; the external-platform half re-promotes only when internal-use signal warrants and a customer-shaped surface emerges.
- ADR-0010 Phase 3 — Observe → HoneyHub event routing (gated on HoneyHub Phase 2 read layer landing in Q3 2026)
- HoneyDrunk.Gateway — API gateway with built-in Grid context
- HoneyDrunk.Jobs — Background job scheduling with Grid integration
- HoneyDrunk.Cache — Distributed caching abstraction

**Consumer apps — sequenced behind Notify Cloud + Curiosities**

- Hearth (PDR-0005) — Personal-growth-as-a-town journaling app; per PDR-0008 §I "remains the recorded first consumer-facing app on the Grid" sequenced after Notify Cloud and before Curiosities, but Curiosities Phase 0/1 is the active product thread; Hearth's queue position re-decided once Curiosities Phase 1 lands a signal
- Studios website — Architecture documentation pages, version tracking *(de-prioritized; build-in-public is a side effect of the work, not the work — charter §forbids #3)*

**Long-horizon experiments**

- HoneyNet — BreachLab.exe, Sentinel, ethical hacking labs
- HoneyPlay — Draft.API, PlayKit, narrative AI
- Cyberware — Simulation orchestrator, embodied agents
- Forge — Asset registry, import pipeline, marketplace
