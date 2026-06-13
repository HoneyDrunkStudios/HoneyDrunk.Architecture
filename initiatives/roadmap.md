# Roadmap

High-level roadmap for the HoneyDrunk Grid.

**Last Updated:** 2026-06-13

For the near-term ranked priority list, see [current-focus.md](current-focus.md). This roadmap is the quarterly horizon.

The 2026 roadmap now has three active product lanes:

1. **HoneyHub** - lead product thread and distribution wedge.
2. **Notify Cloud** - first commercial trial.
3. **Curiosities** - discovery-first city-app bet.

Foundation work remains real work, but it is no longer roadmapped as its own priority lane. A substrate item belongs on this roadmap only when it directly unblocks HoneyHub, Notify Cloud, or Curiosities.

## Q1 2026 (Jan-Mar)

**Foundation already shipped**

- [x] Kernel 0.4.0 - context model stabilization, static mappers, DI guard
- [x] Transport 0.4.0 - Kernel vNext integration, fail-fast envelope validation
- [x] Vault 0.2.0 - provider implementations and canary tests
- [x] Auth 0.2.0 - Vault-backed keys, policy evaluator, startup validation
- [x] Web.Rest 0.2.0 - exception mapping and correlation mismatch warnings
- [x] Data 0.3.0 - architecture overhaul and canary coverage
- [x] Pulse 0.1.0 - multi-backend sinks and collector seed
- [x] Notify 0.1.0 - email/SMS providers and queue backends
- [x] Architecture repo - command center bootstrap and catalog convergence

## Q2 2026 (Apr-Jun)

**HoneyHub**

- [x] **HoneyHub v1 Agent Cockpit shipped** - local agent cockpit wedge under PDR-0011; ADR-0090/0091/0092 are the governing decisions.
- [ ] **Distribution 90 Wave 2 checkpoint** - launch-readiness checkpoint, BYOK waitlist page, and concrete demand probe. *(current focus #1-#3)*
- [ ] **Decision-record reconciliation** - close ADR-0091/0092 and HoneyHub registration bookkeeping where stale state still misleads agents. *(current focus #13)*

**Notify Cloud**

- [x] **Notify + Pulse dev deploy substrate** - Container Apps rollout closed enough to underwrite the Cloud lane.
- [x] **ADR-0077 Bicep IaC consolidation** - done and tested per operator; kept only as Notify Cloud bring-up support, not an independent roadmap lane.
- [ ] **Notify Cloud go/slip decision** - commit to the 2026-09-15 path or record the slip with a dated PDR-0002 amendment. *(current focus #6)*
- [ ] **ADR-0027 Cloud Node precursor** - file the missing scaffold packet so the Node standup can execute. *(current focus #7)*

**Curiosities**

- [ ] **Curiosities lane activation** - create the lane tracker and make Phase 0 visible as a first-class priority, while keeping PDR-0008's build-risk posture intact. *(current focus #10-#12)*

**Shipped or archive-only support**

- [x] Code Review Pipeline (ADR-0011)
- [x] Grid CI/CD Control Plane (ADR-0012)
- [x] Canonical Node Standup Procedure (ADR-0082)
- [x] Vendor Lock-In Posture (ADR-0080)
- [x] Sensitive Inventory and External-SaaS Credential Rotation (ADR-0083)
- [x] Discord as Operator-Alerts Surface (ADR-0084)
- [x] Cost Governance, Budget Alerts, Kill-Switches (ADR-0052)
- [x] Decommission OpenClaw (ADR-0088)
- [x] Container Apps Rollout (ADR-0015)
- [x] HoneyDrunk.Lore Bring-Up
- [x] Kernel Adoption Alignment

## Q3 2026 (Jul-Sep)

**HoneyHub**

- [ ] **HoneyHub v0.1.0 public release** - tag, changelog, stranger-grade README, and public demo. *(current focus #2)*
- [ ] **HoneyHub BYOK cloud-execution validation** - measure the waitlist against the pre-set threshold. *(current focus #3)*
- [ ] **HoneyHub Loop Console scoping** - define the operator surface for loop definition, heartbeat, approval, and cost. *(current focus #4)*
- [ ] **Evals publish as HoneyHub loop gate** - ship only the slice needed to let HoneyHub gate loop runs. *(current focus #5)*
- [ ] **HoneyHub read layer + generic Node shell** - PDR-0009 Phase 2 layer behind the shipped cockpit: catalog/frontmatter read layer, per-Node management pages, ADR/PDR/initiative/packet list views, no dispatch actions yet.

**Notify Cloud**

- [ ] **Notify Cloud kickoff slice** - accept or amend the ADR-0027 Node path, scope tenant isolation, and start the Cloud wrapper. *(current focus #8)*
- [ ] **Notify Cloud first-beta dependency cut** - narrow identity, API, billing, client package, sender identity, rate-limit, and packaging work to exactly what first beta needs. *(current focus #9)*
- [ ] **Notify Cloud first external customer / beta** - REST API, `HoneyDrunk.Notify.Client` preview/GA path, tenant signup, API key issuance, and the first paying or free-tier external developer.

**Curiosities**

- [ ] **Curiosities Phase 0 content spike** - pick one launch district and produce about 25 reviewed POIs from open data plus AI-assisted enrichment. *(current focus #10)*
- [ ] **Curiosities safety/licensing guardrail** - publish the allowed/disallowed POI and source-licensing review rules before content is treated as product. *(current focus #11)*
- [ ] **Curiosities lightweight unlock-loop prototype** - map, question marks, GPS/manual unlock, place card, and collection book over the Phase 0 POI set. *(current focus #12)*

## Q4 2026 (Oct-Dec)

**HoneyHub**

- [ ] **HoneyHub dispatch actions via PRs** - "New ADR," "New PDR," "Scope," "Refine," "Netrunner," and "Site-sync" actions opening draft PRs through the local-runner bridge.
- [ ] **HoneyHub individual desktop tier** - desktop layout, personal usage analytics, and per-repo/per-task reporting if the v0.1 release and BYOK probe justify it.

**Notify Cloud**

- [ ] **Notify Cloud pricing tiers + decision point** - Stripe metered billing live; apply PDR-0002's commercial-trial decision matrix: keep active, drop to maintenance, or sunset gracefully.
- [ ] **Notify Cloud production hardening** - tenant safety, deliverability feedback, incident posture, and cost controls only as required by live beta/paid usage.

**Curiosities**

- [ ] **Curiosities Phase 1 launch-district v1** - expand to 50-100 reviewed POIs, wire the walk-memory backbone, add the discovery atlas surface, test paid district pack or Founding Explorer tier, and measure kill criteria 2-4.
- [ ] **Curiosities Phase 2 content pipeline hardening** - repeatable district-pack build process, editorial review queue, and first Yearly Atlas season if Phase 1 earns it.

## 2027

**HoneyHub**

- [ ] **HoneyHub Phase 4-5** - operational tabs, product surfaces on the same shell, and external-platform exploration only after internal-use signal warrants it.

**Notify Cloud**

- [ ] **Grid v0.5/0.6 evolution from Notify Cloud learnings** - contract and substrate changes driven by real tenants, not abstract platform desire.

**Curiosities**

- [ ] **District/city expansion** - only after the curated product works in one dense district.

**First game thread**

- [ ] **Kickoff** - begin the studio's first game after the three 2026 lanes have shipped enough signal to commit creative capacity.

## Future / Watch

Items here are tracked but not on the quarterly schedule. Promote only when HoneyHub, Notify Cloud, or Curiosities pulls them in.

**HoneyHub-gated support**

- Operator, Capabilities, Agents, Memory, Knowledge, Flow, Sim - only when the HoneyHub cockpit, Loop Console, or dispatch path needs the slice.
- ADR-0010 Observe -> HoneyHub event routing - gated on HoneyHub read layer landing.
- Specialist review agents - gated on HoneyHub loop/review needs.

**Notify Cloud-gated support**

- Identity, Files, Billing, API versioning, rate limiting, sender identity, currency handling, package distribution, disaster recovery, incident response - only the first-beta slice promotes.
- Auth multi-tenant identity federation - forcing function is Notify Cloud tenant model in production.

**Curiosities-gated support**

- Identity, Files, Web.UI, frontend-stack reconciliation, prompt/persona registry, content safety, map/content pipeline, and mobile stack work - promote only when Phase 0/1 needs them.

**Off-lane ideas**

- Hearth, Lately, Currents, Studios website expansion, HoneyNet, HoneyPlay, Cyberware, Forge, and generic platform-commercial theses stay Future until one of the three lanes creates a concrete reason to pull them forward.
