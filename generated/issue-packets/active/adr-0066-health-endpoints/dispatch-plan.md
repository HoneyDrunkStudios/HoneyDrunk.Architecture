# Dispatch Plan — ADR-0066: Health, Readiness, and Liveness Endpoint Contract

**Initiative:** `adr-0066-health-endpoints`
**ADR:** ADR-0066 (Proposed → Accepted via packet 00)
**Sector:** Core / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0066 commits the Grid-wide health-endpoint contract: three uniformly-named endpoints (`/health/live`, `/health/ready`, `/health`), the IETF `application/health+json` response shape on `/health`, empty-body 200/503 on the probe endpoints, `IHealthContributor` aggregation with worst-status-wins + critical-degraded escalation, Container Apps probe defaults, the `ReadinessPolicy` model (`Required` / `OptionalReported` / `NotReadinessRelevant`), an auth posture (probes anonymous, `/health` auth-required), a PII rule for contributor messages, an implementation home in `HoneyDrunk.Kernel`, and Pulse telemetry contribution per probe.

This initiative delivers: ADR acceptance + three new invariants (`{N1}/{N2}/{N3}`, claimed in `invariant-reservations.md` — currently 80–82) + catalog registration + Kernel/Notify integration-points docs (Architecture); the `ReadinessPolicy` enum + IETF response DTOs in `HoneyDrunk.Kernel.Abstractions`; the `MapHoneyDrunkHealthEndpoints` extension + aggregator + IETF response writer + per-contributor timeout + Pulse telemetry in `HoneyDrunk.Kernel` runtime, plus the Functions-host helper in the new pinned optional sibling package `HoneyDrunk.Kernel.Hosting.Functions`; the `docs/Health.md` amendment in the Kernel repo; the Pulse.Collector amendment to call the Kernel helper; the Notify amendment introducing a `NotifyHealthContributorAdapter` bridge and amending `NotifyHealthEndpointsExtensions` and `HealthFunction`; the Notify follow-up that amends contributors to implement `IHealthContributor` directly and removes the Notify-private interface; per-Node Container Apps probe walkthroughs across the live deployables; the `review.md` and `security` specialist checklist updates; and the deploy-workflow readiness-gate switch from `/health` to `/health/ready` in `HoneyDrunk.Actions`.

**11 packets across 6 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Kernel`, `HoneyDrunk.Pulse`, `HoneyDrunk.Notify`, `HoneyDrunk.Actions`). All 11 are `Actor=Agent`, 0 `Actor=Human`. Several packets carry Human Prerequisites — upstream Kernel NuGet publishing (Wave 3→4 boundary), portal-side Container App probe configuration (packet 08), deploy-workflow validation (packet 10), and an `[Obsolete]` deprecation window between packets 06 and 07 — but the *code* work in each packet is fully delegable.

## Trigger

ADR-0066 was authored 2026-05-23. The forcing functions from the ADR's Context:
- **ADR-0015 committed Container Apps for every containerized deployable Node.** Container Apps probes consume the health endpoints. Without a Grid-wide contract every new containerized Node's probe configuration drifts. The revision-mode-Multiple rollback seam (invariant 36) gates on a health probe outcome — that probe needs a defined contract.
- **Operator (ADR-0018), Agents (ADR-0020), HoneyHub (ADR-0002 / ADR-0003) are about to land.** Each is a containerized deployable Node; each will pick whatever shape exists at standup. Settling the shape before they pick prevents three more divergences from the Pulse-and-Notify drift.
- **Notify Cloud GA carries a tenant-facing health expectation.** Per ADR-0027 tenants integrating against Notify Cloud will treat unanticipated `5xx` responses as outages; the readiness gate is what protects them from being routed to a starting-up revision before its dependencies are reachable.
- **AI-sector standup wave (ADR-0016 through ADR-0025)** introduces nine Nodes that emit substantial telemetry to Pulse. Pulse export readiness is a credible "should I be in rotation" signal that needs a defined policy slot.
- **Telemetry contribution.** ADR-0010 and ADR-0040 treat probe outcomes as a candidate signal source; nothing today lets Pulse observe them in a structured way.

The empirical evidence is in the ADR Context audit: Pulse.Collector's three endpoints return static placeholders; Notify aggregates contributors via a Notify-private `INotifyHealthContributor` interface that does not unify with Kernel's `IHealthContributor`; the Kernel-shipped `IHealthContributor` is implemented (lifecycle contributor) but not consumed by any endpoint outside Notify's local fork. Two Nodes is enough to demonstrate the drift problem.

## Scope Detection

**Multi-repo, multi-Node.** The contract lands in `HoneyDrunk.Kernel.Abstractions` (the zero-dependency contract layer — same precedent as `IGridContext`, `TenantId`, the lifecycle hooks, and ADR-0042's idempotency surface), the runtime endpoints + aggregator in `HoneyDrunk.Kernel`, and amendments fan out to `HoneyDrunk.Pulse.Collector`, `HoneyDrunk.Notify.Hosting.AspNetCore`, and `HoneyDrunk.Notify.Functions`. `HoneyDrunk.Architecture` carries the governance (acceptance, three invariants, catalog, integration-points, infrastructure walkthroughs, agent-rubric update). `HoneyDrunk.Actions` carries the deploy-workflow readiness-gate switch.

**Contract is additive — no forced downstream cascade.** The new contracts (`ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry`, `MapHoneyDrunkHealthEndpoints`, `HealthFunctionExtensions`) are *additive* to `HoneyDrunk.Kernel.Abstractions` and the `HoneyDrunk.Kernel` runtime. Per ADR-0066's Cascade-impact section and ADR-0035, this is an additive minor bump (`HoneyDrunk.Kernel` `0.7.0` → `0.8.0`), not a breaking change. Downstream Nodes that consume `HoneyDrunk.Kernel.Abstractions` are not *forced* to update — they adopt the contract when their own health-endpoint code is amended.

This initiative amends only the **two existing deployable Nodes the ADR D11 names** (Pulse.Collector, Notify Worker + Functions). Notify.Cloud, Operator, Agents, HoneyHub, Audit, Communications all compose the helper at their own standup — those are deliberately **out of scope** here (see Cross-Cutting Concerns).

**Cross-initiative version coordination with ADR-0042.** ADR-0042 packet 02 also bumps `HoneyDrunk.Kernel` to `0.8.0`. If both initiatives run concurrently they share the `0.8.0` line. The first-to-merge owns the bump; the second appends to the in-progress `[0.8.0]` CHANGELOG entry without re-bumping. Packet 02 of this initiative carries the explicit coordination guidance.

**No new-Node scaffolding.** Every target repo is a live, scaffolded Node. No empty cataloged repo is touched; no standup ADR is needed.

## Wave Diagram

### Wave 1 (No Dependencies — governance + catalog)
- [ ] **00** — Architecture: Accept ADR-0066, add the three health-endpoint invariants (`{N1}/{N2}/{N3}`, claimed in `constitution/invariant-reservations.md`; the block is currently **80, 81, 82**), insert the ADR-0066 row into `adrs/README.md`, register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: register the health-endpoint contract surface in the Grid catalogs + integration-points docs. `Actor=Agent`. Blocked by: 00.

> **Invariant numbering.** The block for ADR-0066's three new invariants (`{N1}/{N2}/{N3}`) is reserved in `constitution/invariant-reservations.md`, currently claiming **80, 81, 82**. If another ADR's packet 00 races and merges first, shift the ADR-0066 reservation row to the new contiguous triple and update every `{N1}/{N2}/{N3}` placeholder in this initiative's packets. Never reuse a claimed number.

### Wave 2 (Depends on Wave 1 — contract foundation)
- [ ] **02** — Kernel: add `ReadinessPolicy`, `HealthCheckResponse`, `HealthCheckEntry`, and the contributor-registration shape to `HoneyDrunk.Kernel.Abstractions`. `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Kernel` (`0.7.0` → `0.8.0`)** — see Cross-Initiative Coordination with ADR-0042 below.

### Wave 3 (Depends on Wave 2 — runtime + docs, parallel)
- [ ] **03** — Kernel: add `MapHoneyDrunkHealthEndpoints` (ASP.NET Core), `HealthFunctionExtensions` (Functions host), the aggregator with worst-status-wins + critical-degraded escalation + per-contributor timeout, the IETF response writer, and the Pulse telemetry contribution to the `HoneyDrunk.Kernel` runtime. `Actor=Agent`. Blocked by: 02.
- [ ] **04** — Kernel: amend `HoneyDrunk.Kernel/docs/Health.md` with the ADR-0066 endpoint contract, `ReadinessPolicy` model, aggregation rules, Container Apps probe defaults, telemetry, and migration notes. `Actor=Agent`. Blocked by: 03.

### Wave 4 (Depends on Wave 3 — Node rollouts, parallel)
- [ ] **05** — Pulse: amend `Pulse.Collector/Endpoints/HealthEndpoints.cs` to call `MapHoneyDrunkHealthEndpoints`; register contributors with `ReadinessPolicy`; wire host auth for `/health`. `Actor=Agent`. Blocked by: 03.
- [ ] **06** — Notify: introduce `NotifyHealthContributorAdapter`, amend `NotifyHealthEndpointsExtensions` and `HealthFunction` to use the Kernel helpers, mark `INotifyHealthContributor` and its friends `[Obsolete]`. `Actor=Agent`. Blocked by: 03.

### Wave 5 (Depends on Wave 4 — Notify reconciliation closure)
- [ ] **07** — Notify: amend contributors to implement `IHealthContributor` directly; remove `INotifyHealthContributor`, `NotifyHealthEvaluator`, `NotifyHealthReport`, `NotifyHealthStatus`, `NotifyHealthContributorAdapter`. `Actor=Agent`. Blocked by: 06. Honour the ADR-0035 60-day `[Obsolete]` deprecation window (or document a tighter window).

### Wave 6 (Infra walkthroughs + agent updates + deploy gate — parallel)
- [ ] **08** — Architecture: per-Node Container Apps probe walkthroughs in `repos/HoneyDrunk.{Node}/` for Pulse, Notify, and the planned Notify.Cloud/Operator/Agents/HoneyHub. `Actor=Agent`. Blocked by: 00, 03.
- [ ] **09** — Architecture: amend `.claude/agents/review.md` and (conditionally) `.claude/agents/security.md` with the ADR-0066 checklist. `Actor=Agent`. Blocked by: 00.
- [ ] **10** — Actions: switch the Container Apps deploy workflow's readiness-gate probe from `/health` to `/health/ready` (anonymous, empty-body). `Actor=Agent`. Blocked by: 03.

Packets within a wave run in parallel. **Wave-3 packets 03 and 04** share the Kernel solution: 03 is the runtime code; 04 amends the docs. Land 03 first so 04's docs reference live code. **Wave-4 packets 05 and 06** are independent — different repos. **Wave-6 packets 08, 09, 10** are independent — different docs targets / different repos.

Packet 02 is the version-bumping packet for `HoneyDrunk.Kernel`; packets 03, 04 append to the in-progress `[0.8.0]` CHANGELOG. Packet 05 bumps `HoneyDrunk.Pulse` one minor version. Packet 06 bumps `HoneyDrunk.Notify` one minor version; packet 07 bumps Notify again (the removal completes the reconciliation per the ADR-0035 deprecation-window pattern).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0066](./00-architecture-adr-0066-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Health-endpoint contract catalog](./01-architecture-health-endpoint-catalog.md) | Architecture | Agent | 1 | 00 |
| 02 | [Kernel `ReadinessPolicy` + IETF response shape](./02-kernel-readiness-policy-and-response-shape.md) | Kernel | Agent | 2 | 00 |
| 03 | [Kernel health-endpoints runtime](./03-kernel-health-endpoints-runtime.md) | Kernel | Agent | 3 | 02 |
| 04 | [Kernel `docs/Health.md` amendment](./04-kernel-docs-health-md-amendment.md) | Kernel | Agent | 3 | 03 |
| 05 | [Pulse.Collector adopt Kernel helper](./05-pulse-collector-adopt-kernel-helper.md) | Pulse | Agent | 4 | 03 |
| 06 | [Notify bridge adapter + adopt Kernel helper](./06-notify-bridge-adapter-and-adopt-kernel-helper.md) | Notify | Agent | 4 | 03 |
| 07 | [Notify remove private contributor interface](./07-notify-remove-private-contributor-interface.md) | Notify | Agent | 5 | 06 |
| 08 | [Container Apps probe walkthroughs](./08-architecture-container-apps-probe-walkthroughs.md) | Architecture | Agent | 6 | 00, 03 |
| 09 | [Review + security specialist checklist](./09-architecture-review-agent-and-security-specialist-checklist.md) | Architecture | Agent | 6 | 00 |
| 10 | [Deploy-workflow readiness-gate switch](./10-actions-deploy-workflow-readiness-gate-switch.md) | Actions | Agent | 6 | 03 |

## Version Bumps

- **`HoneyDrunk.Kernel`** — packet 02 is the first packet on the solution in this initiative; it bumps every non-test `.csproj` to the same new **minor** version `0.7.0` → `0.8.0` (new feature: the health-endpoint contract surface; additive, no break). Packets 03 and 04 append to the in-progress `[0.8.0]` CHANGELOG only (invariant 27). Per-package CHANGELOGs: `HoneyDrunk.Kernel.Abstractions` gets an entry from packet 02; `HoneyDrunk.Kernel` gets an entry from packet 03 (runtime types) and packet 04 (docs note in the repo-level CHANGELOG; the per-package CHANGELOG is unchanged by docs).
- **`HoneyDrunk.Pulse`** — packet 05 bumps the whole solution one minor version (`0.3.0` → `0.4.0`; the wire shape changes — probes empty body, `/health` IETF, auth-required). Confirm current version at execution time.
- **`HoneyDrunk.Notify`** — packet 06 bumps the whole solution one minor version. Packet 07 bumps again (the removal completes the reconciliation per the ADR-0035 deprecation-window pattern). Confirm current versions at execution time.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/docs edits only.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution; workflow YAML edits only. CHANGELOG entry if the Actions repo carries one.

## Cross-Initiative Coordination with ADR-0042

ADR-0042 (Idempotency) and ADR-0066 (Health endpoints) both add additive contracts to `HoneyDrunk.Kernel.Abstractions` and both want the `0.7.0` → `0.8.0` minor bump. Coordination rule:

- **First-to-merge owns the bump.** Whichever initiative's Kernel-Abstractions packet (ADR-0042 packet 02 or ADR-0066 packet 02) merges first executes the version bump in its commit.
- **Second-to-merge appends to the in-progress `[0.8.0]` CHANGELOG entry** without re-bumping. Per invariant 27 the solution must not partially overlap a single version line via parallel bumps — the second initiative's PR is rebased onto the first's merge and references the already-bumped `0.8.0` version.
- **Coordinate at execution time.** The operator sequences ADR-0042 and ADR-0066 deliberately — both can ship in the same `0.8.0` line if landed in the same wave window; if separated by waves, the later initiative may target `0.9.0` instead. State the chosen sequencing in each initiative's packets at execution time.

This is a soft sequencing concern, not a hard blocker. Neither ADR-0042 nor ADR-0066 depends on the other; the version-line-share is purely a CHANGELOG-and-version-bump coordination, not a contract dependency.

## Cross-Cutting Concerns

### Web.Rest is mentioned but has no current `/health` code

ADR-0066 D11 Affected Nodes lists `HoneyDrunk.Web.Rest` as adopting the Kernel helper. A scan at packet-authoring time found **no health-endpoint code in the Web.Rest repo** — Web.Rest is a library/abstractions Node providing `Web.Rest.Abstractions` and `Web.Rest.AspNetCore` for downstream callers; it does not host a `/health` endpoint itself. The ADR's "Web.Rest amends its existing `/health` shape" framing is anticipatory — it applies when a Web.Rest consumer Node first wires its own endpoint via the Web.Rest pipeline.

**No Web.Rest amendment packet exists in this initiative.** When Web.Rest's first deployable consumer (likely a future Node that uses `Web.Rest.AspNetCore`'s default pipeline) lands, that consumer's standup or feature packet will call `MapHoneyDrunkHealthEndpoints` from Kernel — same as Pulse.Collector and Notify.Worker do in this initiative. Web.Rest itself needs no code change; its existing abstractions are unaffected.

If at a future point Web.Rest grows a deployable host (e.g. a Web.Rest sample API hosted in production), that host's first PR would compose the Kernel helper; the work is small and lives outside this initiative.

### Audit, Communications, and the planned Nodes are out of scope

ADR-0066 D11 Affected Nodes also names `HoneyDrunk.Audit`, `HoneyDrunk.Communications`, `HoneyDrunk.Notify.Cloud`, `HoneyDrunk.Operator`, `HoneyDrunk.Agents`, `HoneyHub`, and "all future containerized deployable Nodes" as composing the helper. This initiative does **not** wire them, by design:

- **`HoneyDrunk.Audit`** — composes the helper at its existing standup follow-up (ADR-0031). Audit's health-endpoint code is part of its deploy-time host composition; the ADR-0066 contract is consumed there.
- **`HoneyDrunk.Communications`** — Communications is an in-process orchestration layer above Notify (per ADR-0019 / ADR-0028 D4). It does not have its own HTTP-fronted deployable surface at v1 — it composes inside Notify.Cloud's host (ADR-0028 D4). When Notify.Cloud composes the helper at standup, it picks up Communications' contributors as well.
- **`HoneyDrunk.Notify.Cloud`, `Operator`, `Agents`, `HoneyHub`** — standup ADRs (ADR-0027, ADR-0018, ADR-0020, ADR-0002/0003). Each composes the Kernel helper at standup time; this initiative ships the contract those standups consume. Packet 08 adds infrastructure walkthrough stubs where the `repos/{Node}/` folder exists.

This initiative ships **the contract, the runtime, the docs, and conforms the two existing deployable Nodes** (Pulse.Collector, Notify Worker + Functions). Every other consumer adopts the shipped contract in its own track. This keeps the initiative bounded and consistent with the Grid's standup-gets-its-own-ADR rule.

### Notify reconciliation sequencing — bridge then remove

ADR-0066 D9's three-stage reconciliation:
1. **Packet 06** introduces `NotifyHealthContributorAdapter` and marks `INotifyHealthContributor` and friends `[Obsolete]`. Existing Notify contributor implementations are wrapped in the adapter and registered as `IHealthContributor`. Notify ships in a transitional state — the Notify-private surface still exists but the endpoints go through the Kernel aggregator.
2. **Packet 07** amends each `INotifyHealthContributor` implementation to implement `IHealthContributor` directly and removes the Notify-private surface (the interface, the evaluator, the report, the status enum, the adapter).

Packets 06 and 07 are split because the removal is a public-API breaking event (`INotifyHealthContributor` is removed) and ADR-0035 mandates an `[Obsolete]` deprecation window of at least 60 days. The bridge in packet 06 keeps Notify's aggregate CHANGELOG from being a breaking event during the window — the contributors keep their existing `INotifyHealthContributor` shape and compile against an unchanged contract until packet 07's removal.

The operator decides whether to honour the 60-day default or document a tighter window in packet 07's PR.

### Auth scheme wiring is a per-Node concern

ADR-0066 D6 makes `/health` auth-required. The mechanics of wiring an auth scheme per Node are **not** ADR-bound — each deployable Node's host composition wires the scheme it prefers (the Studios-internal token, a tenant-administrator token, an Azure Monitor scrape credential).

Packets 05 and 06 ask each Node's executor to confirm the host has an auth scheme wired so `/health` resolves to `401` for unauthenticated requests. If the wiring is non-trivial in a given Node, that Node's packet flags it and proposes a follow-up — but does **not** ship the Node with `/health` anonymous on the assumption "we'll add auth later." Invariant `{N2}` is a hard rule.

### Deploy-workflow change is environment-independent but sequencing matters

Packet 10 changes the readiness-gate probe target from `/health` to `/health/ready` in the deploy workflow. The change is environment-independent (`/health/ready` exists on every revision — both the old placeholder and the new Kernel-helper version expose the path) and can land in any order relative to packets 05 and 06.

**But:** if packet 10 lands and the workflow rolls a new revision whose code is from before packet 05/06, the probe will hit the old `/health/ready` (which returns `{ "status": "Ready" }` JSON, not empty body) — the workflow consumes the status code, not the body, so this still works. The contract drift is cosmetic during the transitional window. After packets 05/06 deploy in every environment, the contract is fully consistent.

The operator should validate the deploy gate after each Node's amendment ships. Packet 10's Human Prerequisites cover this.

### Container App YAML lives in HoneyDrunk.Actions, not in deployable repos

ADR-0066 D5's probe configuration is a Container App YAML concern. ADR-0015 names `job-deploy-container-app.yml` (in `HoneyDrunk.Actions`) as the reusable Container Apps deploy workflow. The probe values are inputs to that workflow.

**This initiative does NOT touch Container App YAML directly.** Packet 08 documents the probe defaults in each Node's infrastructure walkthrough (`repos/{Node}/`); packet 10 amends the deploy workflow's readiness-gate probe target. The actual portal-side application of the probe values to each Container App is a Human Prerequisite in packet 08.

### Deferred follow-ups (explicitly out of scope)

- **Web.Rest health-endpoint adoption** — Web.Rest has no deployable host today; the helper is composed by Web.Rest consumers, not Web.Rest itself.
- **Audit Node health-endpoint composition** — handled in Audit's standup / follow-up track (ADR-0031).
- **Communications health-endpoint composition** — composed inside Notify.Cloud's host per ADR-0028 D4; the Notify.Cloud standup track owns it.
- **Notify.Cloud, Operator, Agents, HoneyHub** — each standup ADR cites ADR-0066 as a prerequisite for its health-endpoint canary; each composes the helper at standup time.
- **Tenant-facing status page** — ADR-0066 D11 out-of-scope. Composes against the `/health` shape this initiative ships when it lands.
- **Cross-Node aggregate health dashboard** — ADR-0066 D11 out-of-scope. Consumes the Pulse telemetry signals packet 03 emits; future Pulse work.
- **Synthetic monitoring** — ADR-0066 D11 — external probes (Azure Monitor synthetic, Pingdom) hit the same endpoints with no additional plumbing.
- **Per-tenant readiness** — ADR-0066 D11 out-of-scope. Application-layer tenant-rate-limit concern.
- **`/api/v1/status` tenant-visible SLA signal** — ADR-0066 D11 — separate future decision.

### Site sync

No site-sync flag. ADR-0066 is internal Core-sector infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packets 00–01 (governance/catalog):** revert the PR. ADR returns to Proposed; the three invariants and the catalog entries are removed. No runtime impact.
- **Packet 02 (Kernel contracts):** revert the PR; the `HoneyDrunk.Kernel` solution rolls back `0.8.0` → `0.7.0`. The contracts are additive — no consuming Node depends on them at runtime until it composes them, so the revert is contained to `HoneyDrunk.Kernel`.
- **Packet 03 (Kernel runtime):** revert the PR; the endpoint helper / aggregator / response writer / Functions-host helper leave the `HoneyDrunk.Kernel` runtime. Additive — the revert is contained to `HoneyDrunk.Kernel`.
- **Packet 04 (docs):** revert the PR; the docs roll back. No runtime impact.
- **Packet 05 (Pulse.Collector):** revert the PR; Pulse.Collector's hand-rolled static endpoints return; the version rolls back. `/health/ready` returns the placeholder `200 OK { "status": "Ready" }` JSON; the deploy workflow (if packet 10 has shipped) probes `/health/ready` and still gets `200`, so the gate continues to work. If `/health` was made auth-required and an external monitoring scrape was hitting it, that scrape returns to anonymous fetch — note the temporary security regression.
- **Packet 06 (Notify bridge):** revert the PR; Notify's hand-rolled endpoint extension and `HealthFunction` return; the Notify-private surface is no longer marked `[Obsolete]`; the version rolls back. Notify's old behaviour is restored (probe endpoints return `{ "status": "..." }` JSON; `/health/ready` aggregates via `NotifyHealthEvaluator`); the deploy workflow probes `/health/ready` and continues to work.
- **Packet 07 (Notify removal):** revert the PR; the removed types come back as commits; the bridge adapter returns; contributors return to implementing `INotifyHealthContributor`. This revert is the most surgical of the seven — it leaves Notify in the transitional state from packet 06 rather than the closed-reconciliation state.
- **Packet 08 (infrastructure walkthroughs):** revert the PR; the walkthroughs roll back. The portal-side Container App probe values stay where the operator applied them; no runtime impact from the revert (the docs were guidance, not enforcement).
- **Packet 09 (review agent / security specialist):** revert the PR; the rubric checklist rolls back. PR reviews stop checking the ADR-0066 invariants explicitly until re-applied; the invariants themselves stay live in `constitution/invariants.md`.
- **Packet 10 (deploy-workflow):** revert the PR; the deploy workflow probes `/health` again. **If `/health` has become auth-required (post-packet-05/06 deploy)**, the deploy gate will return `401` and block deploys — DO NOT revert packet 10 in isolation if packets 05/06 have already deployed in any environment. Roll back packets 05/06 first (or supply an auth credential to the deploy probe temporarily).

The most coupled rollback is: if Invariant `{N2}` ships and the Pulse/Notify amendments deploy, the deploy workflow's `/health` probe stops working. The order-of-operations remedy is to land packet 10 before deploys cut over to the new `/health` behaviour — and packet 10 is in the same wave as the Node amendments precisely to keep this coordinated.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
