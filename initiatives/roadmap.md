# Roadmap

High-level roadmap for the HoneyDrunk Grid.

**Last Updated:** 2026-05-25

For the near-term ranked priority list, see [current-focus.md](current-focus.md); this roadmap is the quarterly horizon.

The studio is currently building three product threads in 2026 — **Notify Cloud** (PDR-0002, the Grid's first commercial trial), **Curiosities** (PDR-0008, discovery-first city app), and **HoneyHub** (PDR-0009, the operator's internal daily-driver workspace) — on top of the substrate. The first game thread begins in 2027. Per the [charter](../constitution/charter.md), foundation work is real work, *and* it has to serve the workshop rather than consume it; ADRs on this roadmap are filtered to those that materially move the substrate forward for the product threads in flight. AI-sector standup ADRs (0017–0025) and other future-tense surfaces live in **Future** until a real consumer pulls them in.

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

- [ ] **Code Review Pipeline (ADR-0011)** — ADR-0011 Accepted 2026-05-25; SonarQube Cloud rollout completed across all 12 .NET-active Grid repos (Kernel, Transport, Vault, Auth, Web.Rest, Data, Notify, Pulse, Communications, AI, Audit, Observe) the same day; `job-sonarcloud.yml` reusable workflow + `agent-run.yml` packet-link injection shipped in HoneyDrunk.Actions; org-level GitHub ruleset created in Evaluate mode to require `SonarCloud Code Analysis` on the 12 onboarded repos. Closure pending three gate-cleanup items (Sonar Overview coverage diagnosis, legacy findings triage, hotspot review on Communications + Observe) before flipping the ruleset to Active and archiving the initiative.
- [ ] **ADR-0012 Grid CI/CD Control Plane — In Progress** — `adr-0012-grid-cicd-control-plane`: tracked_workflows catalog, grid-health aggregator, caller-permissions audit, Node 20 action bump.
- [ ] **ADR-0033 environment-gated trigger packets** — unblocks Notify/Pulse dev deploy under ADR-0015
- [ ] **ADR-0043 Backlog Generation — Phase 1 kickoff** — closes the ADR → packet auto-generation loop; Strategic source feeds on ADR acceptances
- [ ] **ADR-0015 Container Apps Rollout — underway** *(2/5 issues closed; walkthroughs + reusable deploy workflow complete; Notify/Pulse release work remains; underwrites Notify Cloud deploy substrate)*
- [ ] **Archive / exit-criteria review** — sweep closed rollouts (ADR-0005/0006, 0009, 0014, 0030, 0032, Lore, Vault.Rotation, Kernel Adoption) into `archived-initiatives.md`

**Product**

- [ ] **Notify Cloud (PDR-0002) — multi-tenant scaffolding kickoff** — first commercial trial on the Grid; ADR-0027 Node standup, Stripe wiring scoped, tenant isolation at gateway/queue/Vault layers begun
- [ ] **Curiosities (PDR-0008) — Phase 0 content spike + loop prototype** — pick launch district, build curated-content pipeline against open data + AI-assisted enrichment, produce ~25 reviewed POIs to measure real per-POI cost; tests Kill Criterion 1 before any significant mobile investment
- [ ] **HoneyHub (PDR-0009) — direction accepted, agent-dispatch ADR drafted** — accept PDR-0009 as a peer to PDR-0001 (internal-daily-driver fitness as first-class success criterion); draft the agent-dispatch service ADR named in §G (placement, auth, repo-cloning model, sandboxing, PR-opening contract) so Q3 read-layer work has a known dispatch target *(per PDR-0009 §"Rollout — Phased Approach" Phase 1)*

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
- [ ] **HoneyHub — read layer + generic Node shell** *(PDR-0009 Phase 2)* — read layer over Architecture repo catalogs + frontmatter (SSG-generated static JSON viable for v1); generic per-Node management page composed from `nodes.json` + `grid-health.json` + GitHub; ADR/PDR/initiative/packet list views with filters; no dispatch actions yet
- [ ] **Lore → Grid use-case bridge — author the ADR** — formalize HoneyDrunk.Lore's mandate as the durable operator-memory archive that survives Claude/Codex/Copilot session boundaries (per [`generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md`](../generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md) §2.3); land first consumer wiring (Honeyclaw or another agent path) so the flat-file wiki stops being write-only

**Foundation / Substrate**

- [ ] **ADR-0043 Backlog Generation — Phase 1 ship** — Strategic source event-driven on ADR acceptance + Reactive source for drift; `generated/issue-packets/proposed/` directory live
- [ ] **ADR-0046 Specialist Review Agents — Phase 1** — `cfo` agent authored and retroactively invoked against cost-touching PRs; `agent-capability-matrix.md` updated
- [ ] **ADR-0047 Phase 2 — Tier 2a integration CI** — `job-integration-tests.yml` live in Actions and wired into `pr-core.yml`; closes ADR-0011 Gap 1
- [ ] **ADR-0079 Multi-Perspective PR Review Stack — Acceptance** — substantive-PR classifier defined; per-PR cost ceiling committed; ADR-0044 amended with billing-path discipline *(Reviewer 4 path unlocked 2026-06-15 by Claude Max Agent SDK launch)*
- [ ] **ADR-0010 Phase 2 (first useful increment)** — HoneyDrunk.Observe.Connectors.GitHub (webhook receiver + repo health checks), cost-first IRoutingPolicy implementation in HoneyDrunk.AI, routing policies loaded from Azure App Configuration
- [ ] Cross-repo canary test automation via Actions workflows

**Business operations**

- [ ] **BDR-0001 Mailbox switch — execution complete by 2026-09-30** *(hard deadline)* — VPM live and verified, Sunbiz Articles of Amendment filed, IRS Form 8822-B filed (60-day window from address change), Chase business banking updated, FL DOR updated if applicable, vendor address book refreshed, iPostal1 cancelled after ≥30 days of verified forwarding

## Q4 2026 (Oct–Dec)

**Product**

- [ ] **Notify Cloud — pricing tiers + first decision point** — Stripe metered billing live; charter §"Commercial trials" decision (keep active / drop to maintenance / sunset gracefully) based on customer signal from Q3 beta
- [ ] **Curiosities — Phase 2 content pipeline hardening + Atlas season** — repeatable district-pack build process, editorial review queue, first Yearly Atlas season ("what you uncovered this year"), print-on-demand pipeline live
- [ ] **HoneyHub — dispatch actions via PRs** *(PDR-0009 Phase 3)* — "New ADR," "New PDR," "Scope," "Refine," "Netrunner," "Site-sync" buttons open draft PRs through the agent-dispatch service; agent-dispatch service ADR Accepted before this phase ships; optimistic UI + inline PR-state visibility

**Foundation / Substrate**

- [ ] **Auth — Multi-tenant identity federation** *(forcing function: Notify Cloud tenant model in production)*
- [ ] **Grid v0.5 planning** — Next contract evolution based on Notify Cloud production learnings
- [ ] **HoneyDrunk.Operator** — Human oversight, approval gates, circuit breakers, cost controls, audit trail *(gated on first AI-sector consumer that needs policy enforcement)*
- [ ] **HoneyDrunk.Evals** — Prompt evaluation, regression testing, model comparison *(gated on first ship-blocking eval need from Notify Cloud or Curiosities AI surfaces)*
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
