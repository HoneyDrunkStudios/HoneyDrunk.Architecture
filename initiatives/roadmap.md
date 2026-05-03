# Roadmap

High-level roadmap for the HoneyDrunk Grid.

**Last Updated:** 2026-05-03

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

- [ ] **Config & Secrets Rollout (ADR-0005/0006) — packet rollout complete** *(15/15 issues closed; ready for archive/exit-criteria review)*
- [x] **Package Scanning Rollout (ADR-0009) — complete** *(8/8 issues closed; ready for archive review)*
- [ ] **Hive Sync Rollout (ADR-0014) — implementation PR ready** *(1/6 issues closed; Packet 01 merged. Packets 02-06 are implemented together in the final rollout PR: packet lifecycle, board-items tracking, Proposed ADR/PDR queue, auto-acceptance + README sync, and drift detection)*
- [ ] **ADR-0015 Container Apps Rollout — underway** *(2/5 issues closed; walkthroughs + reusable deploy workflow complete; Notify/Pulse release work remains)*
- [ ] Pulse — Production hardening, Grafana dashboard templates, finalize 0.1.0 release
- [ ] Notify — Azure Functions deployment, finalize 0.1.0 release *(packages built, deployment blocked on Azure infrastructure)*
- [ ] HoneyDrunk.AI — Model/provider abstraction, OpenAI + Anthropic providers, Pulse telemetry
- [ ] **ADR-0010 Phase 1 (Observation Layer & AI Routing contracts)** *(0/3 issues closed; scoped 2026-04-18 — Observe side ready to file, AI routing deferred pending HoneyDrunk.AI standup ADR)*
- [ ] HoneyDrunk.Capabilities — Tool registry, discovery, permissioning, initial tool descriptors
- [ ] HoneyDrunk.Agents — Agent runtime, lifecycle, execution context, tool/memory interfaces
- [ ] HoneyDrunk.Memory — Agent memory contracts, InMemory provider, Agents integration
- [ ] **HoneyDrunk.Lore Bring-Up — underway** *(4/6 issues closed; scheduled ingest and OpenClaw setup remain)*
- [ ] HoneyHub — Initial scaffolding, project orchestration, creator dashboard foundations
- [ ] Studios website — Architecture documentation pages, version tracking

## Q3 2026 (Jul–Sep)

- [ ] **ADR-0010 Phase 2 (first useful increment)** — HoneyDrunk.Observe.Connectors.GitHub (webhook receiver + repo health checks), cost-first IRoutingPolicy implementation in HoneyDrunk.AI, routing policies loaded from Azure App Configuration
- [ ] HoneyDrunk.Knowledge — Document ingestion, RAG pipelines, Azure AI Search provider
- [ ] HoneyDrunk.Flow — Workflow engine, multi-step pipelines, agent chaining, compensation
- [ ] HoneyDrunk.Lore — Initial scaffolding, raw ingestion, LLM compilation, wiki maintenance
- [ ] HoneyDrunk.Agents — Multi-agent orchestration, federated memory, deterministic seeds
- [ ] HoneyHub — AI-assisted workflows, Signal integration, collaborative dashboards
- [ ] Grid v0.5 planning — Evaluate WebSocket/SignalR transport, gRPC support
- [ ] Cross-repo canary test automation via Actions workflows

## Q4 2026 (Oct–Dec)

- [ ] Grid v0.5 — Next contract evolution based on production learnings
- [ ] Data — Cosmos DB provider exploration
- [ ] Auth — Multi-tenant identity federation
- [ ] HoneyDrunk.Operator — Human oversight, approval gates, circuit breakers, cost controls, audit trail
- [ ] HoneyDrunk.Evals — Prompt evaluation, regression testing, model comparison
- [x] ~~HoneyDrunk.Tools~~ — Scrapped; scanning logic moved to HoneyDrunk.Actions composite actions

## Future

- ADR-0010 Phase 3 — Observe → HoneyHub event routing; HoneyHub-consumed routing-policy outcomes as plan-adjustment signals (gated on HoneyHub Phase 1 being live)
- HoneyDrunk.Sim — Simulation, plan evaluation, risk analysis (when agents operate at scale)
- HoneyDrunk.Gateway — API gateway with built-in Grid context
- HoneyDrunk.Jobs — Background job scheduling with Grid integration
- HoneyDrunk.Cache — Distributed caching abstraction
- HoneyNet — BreachLab.exe, Sentinel, ethical hacking labs
- HoneyPlay — Draft.API, PlayKit, narrative AI
- Cyberware — Simulation orchestrator, embodied agents
- Forge — Asset registry, import pipeline, marketplace
