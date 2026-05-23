# ADR-0065: Multi-Service Local Dev Orchestration and .NET Aspire Stance

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** Ops / cross-cutting

## Context

[`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) line 152 names .NET Aspire as a Q2–Q3 2026 target with explicit framing: "Local dev orchestration for the multi-service Grid. Launches Pulse.Collector, Notify, backing infra in one command. Built-in dashboard for traces/logs/metrics, service discovery, and health aggregation. Complements Kernel's own service discovery for inner-loop dev." Q2 is right now.

The forcing function: the **Notify (Functions + Worker) + Pulse.Collector** dev deploy is the first time the user will run multiple Grid services together locally. Until now, every Node has been a single-process inner loop — Vault, Kernel, Communications run as one process per `dotnet run`. Notify breaks that shape; Notify's intake (Azure Functions) and worker (Azure Functions or hosted service) are two processes, and Pulse.Collector is a third the user wants live to observe Notify's OTLP emission while iterating. Three processes by hand on a Windows box with `launchSettings.json` is doable but ugly; once Operator ([ADR-0018](./ADR-0018-stand-up-honeydrunk-operator-node.md)), Agents ([ADR-0020](./ADR-0020-stand-up-honeydrunk-agents-node.md)), Memory ([ADR-0022](./ADR-0022-stand-up-honeydrunk-memory-node.md)), and HoneyHub ([ADR-0002](./ADR-0002-honeyhub-command-center.md), [ADR-0003](./ADR-0003-honeyhub-control-plane.md)) queue in behind, the by-hand story compounds.

The decision is undecided across multiple paths:

- **.NET Aspire** — Microsoft's native .NET local-dev orchestrator. AppHost project models projects, containers, and Azure resources as resources; provides a dashboard for traces/logs/metrics; integrates with OTLP collectors.
- **docker-compose** — language-agnostic, mature, but a step away from the .NET-native tooling the studio's stack is built on.
- **Per-Node `launchSettings.json` + manual orchestration** — status quo, no new tooling.
- **Ad-hoc PowerShell scripts** that launch N processes and tail their logs.

The forcing functions for deciding now:

- **Notify's first multi-service dev deploy is imminent.** Without a decision, the user invents the shape ad-hoc; whatever ships first becomes the de-facto pattern.
- **The AI-sector standup wave** ([ADR-0016](./ADR-0016-stand-up-honeydrunk-ai-node.md) through [ADR-0025](./ADR-0025-stand-up-honeydrunk-sim-node.md)) introduces nine Nodes that will each need a local-dev story. If the wave's first feature packets each invent their own inner-loop pattern, the Grid ends up with N inner-loop patterns and the cleanup cost compounds.
- **[ADR-0015](./ADR-0015-container-hosting-platform.md)** commits Azure Container Apps as the production hosting platform. Aspire models Container Apps reasonably and the local model maps cleanly to the production shape — if the studio is going to use Aspire anywhere, the value is highest when the local model and the production model are aligned.
- **Pulse OTLP integration** ([ADR-0010](./ADR-0010-observation-layer.md), [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md)). Pulse exposes an OTLP receiver; Aspire ships an OTLP-emitting dashboard. The local-dev story for "see my service's traces while I iterate" wants both the Aspire dashboard and Pulse, ideally the same OTLP stream consumed by both.
- **Service Bus has no Azurite-equivalent local emulator.** Per [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md), Service Bus is the Grid's broker for cross-Node messaging. Local-dev for Service-Bus-using Nodes (Communications, Notify, future Flow) needs a decision.
- **Container Apps Jobs (a future ADR, referenced as TBD)** is the platform for scheduled and cron-triggered work; it does not run locally. The Aspire AppHost can model timer-triggered hosted services as project resources; the local pattern needs to be aligned with the production pattern.
- **The studio is one developer on Windows** (memory). Aspire runs on Windows. Cosmos emulator runs on Windows. The path is feasible.

This ADR commits the Aspire stance, the AppHost shape, the resource-modeling rules, the Pulse integration, the production-deployment posture, the Standards alignment, the migration path for existing Nodes, the cross-reference with Container Apps Jobs, and the Service-Bus-local resolution.

## Decision

### D1 — Adopt .NET Aspire as the Grid's local-dev orchestrator

`.NET Aspire` is the Grid's committed local-dev orchestrator. It is **local-dev only** — see D5; Aspire is not a production deployment authority.

Alternatives explicitly rejected:

- **Per-Node `launchSettings.json` only, no orchestrator.** Status quo. Acceptable for single-process Nodes; collapses when multi-process Nodes (Notify, future Operator/Agents composites) arrive. Already collapsing for the imminent Notify dev deploy. Rejected.
- **docker-compose per Node, no Aspire.** Works, but a step away from the .NET-native tooling the studio's stack is built on. docker-compose has no native dashboard for .NET traces/logs/metrics; the studio would have to integrate one (Jaeger, Grafana, etc.) separately. Aspire's dashboard ships ready. Rejected.
- **Ad-hoc PowerShell scripts.** Works for the first one or two scenarios; collapses past three. Rejected.
- **Tye / k3d / Tilt / Skaffold.** Considered. Each has merits; none is .NET-native. Tye is effectively deprecated in favor of Aspire. Skaffold and Tilt are Kubernetes-first. The native .NET tool with first-party Microsoft support for the production target ([ADR-0015](./ADR-0015-container-hosting-platform.md) — Container Apps, also Microsoft) is the right alignment.

The reasoning summary: Aspire is native .NET, integrates with Pulse OTLP, models Container Apps reasonably, gives a dashboard for tracking running replicas, and carries low ceremony for a solo dev with AI agents. The first failure mode worth calling out: Aspire is a young product (GA in 2024) and its API will evolve. The mitigation is that nothing this ADR commits is irreversible — if Aspire turns out wrong, the AppHost projects are thin (a Program.cs and a project file each) and replacing them with docker-compose or PowerShell scripts is a per-Node migration, not a Grid cascade.

### D2 — AppHost shape: one per Node for solo work, one per scenario for cross-Node work

The AppHost story is two-tier:

**Per-Node AppHost** — each containerized Node's repo includes a `{Node}.AppHost` project alongside its main solution. The AppHost models that Node's processes, its dependencies (Service Bus, Cosmos, Vault, Cache backing, etc.), and the minimal set of other Grid Nodes the Node needs to run end-to-end. The default `dotnet run --project {Node}.AppHost` launches the Node's local inner loop.

Per-Node AppHosts ship alongside their Node. Notify's AppHost models Notify Functions + Notify Worker + Service Bus + Cosmos + Vault + Pulse.Collector. Communications' AppHost models Communications + Notify + Service Bus + Cosmos. Each AppHost is **the inner-loop story for that Node**.

**Per-scenario AppHost** — cross-Node scenarios that combine multiple Nodes for integration work live in a dedicated `HoneyDrunk.Workshop` repo. The Workshop carries one AppHost per scenario:

- `Workshop.Notify-Plus-Communications.AppHost` — full email-orchestration loop.
- `Workshop.Agents-Plus-Memory-Plus-AI.AppHost` — full agent-with-memory-with-inference loop.
- `Workshop.Full-Local-Grid.AppHost` — every containerized Node at once (the "show me the whole Grid running locally" scenario; honest acknowledgement that this is heavy and used rarely).

The Workshop is a separate lightweight Node (effectively an integration-test/dev-scenario repository). Its catalog entry mirrors `HoneyDrunk.Architecture`'s shape — a Meta-sector Node with no production runtime, no NuGet packages, no Azure resources. The first scenario AppHosts land when the first cross-Node scenario requires them.

Alternatives rejected:

- **One central AppHost in `HoneyDrunk.Architecture`.** Considered. Architecture is the Grid's command center, but it does not host code that builds against Grid Nodes — it hosts catalogs, ADRs, and agent definitions. Adding AppHosts to Architecture would require Architecture to take build-time dependencies on every Node it composes, breaking Architecture's documentation-Node shape. Rejected.
- **One AppHost per Node only, no per-scenario AppHosts.** Considered. The per-Node AppHost can compose other Nodes by reference. The problem: scenario AppHosts capture *intent* (this combination is a useful inner-loop scenario), not just the dependency graph. Communications' AppHost is "what Communications needs to run end-to-end"; the cross-Node scenario AppHost is "what the user is iterating on right now across multiple Nodes." Both have value. Rejected the one-tier story.

### D3 — Resource modeling

Per-Node AppHosts model the following resource types:

- **Project resource** — the Node's main process (e.g., Notify Functions, Notify Worker). The Aspire `IDistributedApplicationBuilder.AddProject<T>` form.
- **Container resource** — emulators and infrastructure that runs as a container. The Cosmos Emulator is the primary one; per below, the Service Bus emulator does not exist.
- **Connection-string resource** — for resources that do not run locally (real dev Service Bus, real dev Key Vault; see D9). Aspire models these as configuration values resolved from local environment or developer secrets.
- **OTLP receiver** — Aspire's built-in dashboard registers an OTLP endpoint automatically; project resources are configured to ship to it by default.

Specifics per common dependency:

- **Service Bus.** Per D9 — real dev Azure Service Bus namespace, one per dev session via separate topics. Aspire models the connection string; the real namespace serves.
- **Cosmos DB.** The Cosmos Emulator (Linux container, well-supported by Aspire). Runs in Docker Desktop on the user's Windows box. Aspire's `AddCosmos` resource handles container lifecycle.
- **Vault / Key Vault.** Real dev Key Vault, per Invariant 17 (one Key Vault per Node per environment). Aspire models the connection (the URI) and the local dev session authenticates via Azure CLI / Visual Studio sign-in. No emulator; Key Vault is not emulated, and faking it locally would defeat the rotation discipline. The dev Key Vault is provisioned at the time the first Node needs one per the [`feedback_provision_when_needed`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/feedback_provision_when_needed.md) preference.
- **App Configuration.** Real dev App Configuration, per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md). Same shape as Vault — no emulator, real dev resource, dev session auth.
- **Storage.** Azurite (Microsoft's blob/queue/table emulator). Local container via Aspire.
- **Redis / cache backing.** Aspire's `AddRedis` runs a Redis container locally. Per [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md), the first distributed-cache backing's choice is per-workload; when the first backing is Redis, the local container shape is in place.

The general rule: **emulate the dependency when a faithful local emulator exists** (Cosmos, Azurite, Redis); **use a real dev resource when the emulator is unfaithful or absent** (Service Bus, Key Vault, App Configuration). Aspire models both shapes uniformly; the developer sees one AppHost regardless.

### D4 — Pulse integration: dual-emit to Aspire dashboard and (opt-in) local Pulse.Collector

Aspire's dashboard exposes its own OTLP endpoint at a well-known local port. By default, every project resource is configured to ship OTLP to it; the dashboard is the zero-config local-dev observability surface.

For Pulse-iteration scenarios (the user is working on Pulse itself, or iterating on a Notify feature whose tail-end ends up in Pulse), the AppHost has an opt-in flag that **also** ships OTLP to a local Pulse.Collector instance. The flag — `AddPulseCollector(opt: true)` — adds Pulse.Collector as a project resource to the AppHost, configures it to listen on its own OTLP port, and configures other project resources to fan out (ship OTLP to both Aspire's endpoint and Pulse.Collector's).

The default is **Aspire dashboard only**. The reasoning: most local-dev work does not need Pulse-aware observability; the Aspire dashboard is faster to set up and easier to read for routine iteration. Opt-in dual-emit is for the cases where Pulse-aware semantics are what the user is iterating on.

Production behavior is unchanged: production ships OTLP to the real Pulse.Collector via [ADR-0040](./ADR-0040-telemetry-backend-and-retention.md). Aspire's dashboard is never in the production path.

### D5 — Production deployment: separate from Aspire

Aspire can generate Bicep / ARM templates for Container Apps deployment via `azd` (Azure Developer CLI). The studio **does not adopt that path**. Production deployment authoring stays in `HoneyDrunk.Standards`' shared workflows and each Node's curated Bicep files per [ADR-0015](./ADR-0015-container-hosting-platform.md).

The reasoning:

- **[ADR-0015](./ADR-0015-container-hosting-platform.md) commits Container Apps with Bicep-by-hand in `HoneyDrunk.Standards`.** Bicep is the production source of truth. Aspire's generated Bicep would either need to be diffed against the curated Bicep every release (operational burden) or supersede the curated Bicep (giving up the production control plane). Neither is the right shape.
- **Aspire is a young product evolving fast.** Coupling production deployment to Aspire's generator would make every Aspire-generator change a production-release event. Decoupling is safer.
- **The studio's production posture is curated and reviewed**, per [ADR-0012](./ADR-0012-grid-cicd-control-plane.md). Aspire-generated Bicep is good enough for "spin up a sandbox quickly" but not for production review. Curated Bicep stays.

Aspire is the **local-dev** authority. The production-authoring authority is `HoneyDrunk.Standards` + per-Node Bicep. The two are intentionally separate.

### D6 — Standards alignment: AppHost template, default OTLP wiring, default emulator wiring

[`HoneyDrunk.Standards`](https://github.com/HoneyDrunkStudios/HoneyDrunk.Standards) gains a small set of Aspire-related shared assets:

- **AppHost project template** — `HoneyDrunk.Standards.Templates/AspireAppHost` — produces a `{Node}.AppHost` scaffold with the analyzer/EditorConfig wiring per Invariant 26 and the default OTLP/dashboard setup.
- **OTLP wiring extension method** — `HoneyDrunkAspireExtensions.AddGridTelemetry(IResourceBuilder<T>)` — applies the dual-emit pattern from D4 when called.
- **Default emulator/dev-resource wiring extensions** — `AddGridCosmosEmulator`, `AddGridAzurite`, `AddGridServiceBusDev` (connection-string resource pointing at the dev namespace), `AddGridKeyVaultDev`, `AddGridAppConfigDev`. Each is a thin convenience over Aspire's native APIs that applies the Grid's naming and configuration conventions consistently.

New Nodes adopting Aspire pull the template from Standards and get a working baseline; existing Nodes pull the extension methods piecemeal as they migrate (D7).

The Standards additions are versioned per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) — the Aspire wiring extensions are public surface, subject to the same SemVer rules as every other Standards export.

### D7 — Migration path: incremental, per-Node, no big-bang

Existing Nodes with `launchSettings.json` (Notify, Pulse, Vault.Rotation, Communications, etc.) migrate to Aspire **incrementally**. The order:

1. **Notify** is the first migrant. Notify is the first multi-service deploy; Notify's AppHost lands as part of the Notify+Pulse dev-deploy work.
2. **Pulse** migrates next, because Notify's AppHost composes Pulse.Collector and the Pulse repo benefits from carrying the canonical Pulse.Collector AppHost.
3. **Communications** migrates when its first cross-process workload arrives (probably when it gains a worker process for cadence enforcement).
4. **The AI-sector seed Nodes** ([ADR-0016](./ADR-0016-stand-up-honeydrunk-ai-node.md) through [ADR-0025](./ADR-0025-stand-up-honeydrunk-sim-node.md)) adopt Aspire on their **first feature packet** rather than at standup. Standup scaffolds remain `launchSettings.json`-only (consistent with the empty-scaffold convention); the AppHost arrives with the first feature work because that is when multi-process composition becomes a real concern.
5. **Single-process library-only Nodes** (Kernel, Vault, Transport, Standards, Auth, Web.Rest, Data) do **not** get AppHosts. They have no runtime; there is nothing for an AppHost to launch. Their inner loop stays `dotnet test`.

The migration is opportunistic: when a Node's developer is already in the Node's repo for other work, the AppHost migration can ride along. There is no Grid-wide migration deadline.

### D8 — Cross-reference with Background Jobs (Container Apps Jobs ADR, future)

Per the tech-stack reference, Container Apps Jobs is the planned platform for scheduled and cron-triggered work. Container Apps Jobs **do not run locally** — there is no Container Apps Jobs emulator. Under Aspire, the local-dev pattern for a Container-Apps-Job-deployed workload is:

- **Local:** the job runs as a project resource (a hosted service with a timer or an explicit entry point) inside the AppHost. The AppHost can configure a `RunOnStartup` flag for jobs that run once on launch, or a `Cron` parameter that delegates to a `Cronos`-style scheduler inside the project.
- **Production:** the same code, but deployed as a Container Apps Job via curated Bicep (per D5 / [ADR-0015](./ADR-0015-container-hosting-platform.md)). The job's entry point is the same; the scheduling is moved from the local cron-in-project to the Container Apps Jobs definition.

The convention: a Container Apps Job project's `Program.cs` carries an `IsLocalDev` branch that wires up the in-process scheduling; in production, the branch is skipped and the Container Apps Jobs platform invokes the entry point on its own cadence. This is a small per-job convention, not a Grid-wide invariant.

This decision is recorded here, but the **definitive** Container Apps Jobs ADR (when it lands) is the authority; this ADR commits the Aspire-local shape such that the future Jobs ADR has a compatible local-dev story. The two ADRs cross-reference each other.

### D9 — Windows-first: real dev Service Bus, not an in-process broker shim

The studio is on Windows (memory). The matrix:

- **Aspire on Windows** — fully supported, first-party.
- **Cosmos Emulator on Windows** — supported in Linux-container mode through Docker Desktop. The newer Windows-native mode is also available; the AppHost uses the Linux-container mode for cross-platform consistency.
- **Azurite on Windows** — fully supported, Linux container.
- **Service Bus on Windows** — **no emulator exists**. Microsoft has not shipped one. The matrix is real Azure Service Bus or in-process broker shim.

The decision: **real dev Service Bus**. One dev namespace (`sb-hd-dev`) is provisioned at the time the first ASB-using Node needs it (per the [`feedback_provision_when_needed`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/feedback_provision_when_needed.md) preference). The namespace carries one topic per Grid topic; developers use one Service Bus subscription per dev session (named by user / machine / process), so concurrent dev sessions do not interfere. Aspire's `AddGridServiceBusDev` extension (per D6) resolves the connection string from local user-secrets and creates the per-session subscription on AppHost launch.

The in-process broker shim alternative (use `HoneyDrunk.Transport.InMemory` for local dev) was considered and rejected for one reason: the InMemory broker has materially different semantics from Service Bus (delivery ordering, dead-letter handling, message lock duration, prefetch). Developing against InMemory locally and Service Bus in production means a class of bugs that pass local CI and fail in production — exactly the failure mode local-dev orchestration is supposed to prevent.

The cost: a dev Service Bus namespace incurs Azure cost (~$10/month for the Basic tier; per the [`feedback_default_cheapest_azure_tier`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/feedback_default_cheapest_azure_tier.md) preference, Basic is the right starting tier — Standard only when a concrete feature requires per-message scheduling, topic-with-subscription filters, or larger message size). The cost is recorded explicitly; the discipline benefit is real.

### D10 — Aspire is not in CI

CI ([ADR-0012](./ADR-0012-grid-cicd-control-plane.md), [ADR-0032](./ADR-0032-pr-validation-policy-coverage-gate-and-nuget-flagging.md)) does not use Aspire. CI runs:

- **Unit tests** — fast, in-process, no orchestration. Per Invariant 50.
- **Integration tests** — use `HoneyDrunk.Transport.InMemory`, `InMemorySecretStore`, and other test doubles per Invariant 15. No Aspire.
- **Container-based integration tests (Tier 2b per [ADR-0047](./ADR-0047-testing-patterns-and-tooling.md))** — Testcontainers-style; spin up the necessary container per test fixture. No Aspire.

The reasoning: Aspire is an inner-loop orchestrator. CI needs deterministic, fast, ephemeral test runs. Aspire's value (dashboard, hot-reload, manual-iteration ergonomics) is the wrong shape for CI. The two patterns coexist — Aspire for inner-loop, CI's own test machinery for build-time validation.

A future testing-patterns follow-up may explore using the AppHost as a fixture-builder for E2E tests (`Aspire.Hosting.Testing` exists for this purpose). That is not committed here; it is a follow-up if the testing patterns ADR ([ADR-0047](./ADR-0047-testing-patterns-and-tooling.md)) chooses to adopt it.

## Consequences

### Affected Nodes

- **`HoneyDrunk.Notify`** — first migrant. Gains a `Notify.AppHost` project; the multi-service inner loop (Functions + Worker + Pulse.Collector + ASB connection + Cosmos emulator) lands as part of the Notify dev-deploy work.
- **`HoneyDrunk.Pulse`** — second migrant. Gains a `Pulse.AppHost` project; the Pulse.Collector OTLP receiver, the dashboard, and the local backing infrastructure compose into a single launch.
- **`HoneyDrunk.Communications`** — third migrant when its worker process arrives.
- **`HoneyDrunk.Standards`** — gains the AppHost project template and the Aspire extension methods per D6. First Standards release after this ADR adds the new exports.
- **`HoneyDrunk.Operator`, `HoneyDrunk.Agents`, `HoneyDrunk.Memory`, `HoneyDrunk.Knowledge`, `HoneyDrunk.Evals`, `HoneyDrunk.Flow`, `HoneyDrunk.Sim`, `HoneyDrunk.AI`** — each gains an AppHost at first-feature-packet time per D7. Standup scaffolds (already shipped or in flight per [ADR-0016](./ADR-0016-stand-up-honeydrunk-ai-node.md) through [ADR-0025](./ADR-0025-stand-up-honeydrunk-sim-node.md)) are not retroactively given AppHosts; the first feature packet introduces it.
- **`HoneyDrunk.Workshop`** (new, lightweight, Meta sector) — hosts the per-scenario AppHosts per D2. First Workshop scenario lands when the first cross-Node integration scenario calls for it.
- **`HoneyDrunk.Notify.Cloud`** ([ADR-0027](./ADR-0027-stand-up-honeydrunk-notify-cloud-node.md)) — when scaffolded, its AppHost models the wrapper + Notify + Communications + Service Bus + Cosmos + Stripe-test endpoint. The wrapper's first dev-deploy is the second multi-service composition after the Notify+Pulse pair.
- **`HoneyDrunk.Kernel`, `HoneyDrunk.Vault`, `HoneyDrunk.Transport`, `HoneyDrunk.Auth`, `HoneyDrunk.Web.Rest`, `HoneyDrunk.Data`** — no AppHosts (library-only Nodes per D7).
- **`HoneyDrunk.Cache`** ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) — no AppHost at standup (no runtime); future backings are libraries that consuming Nodes' AppHosts compose, not Nodes with their own AppHosts.
- **`HoneyDrunk.Audit`** ([ADR-0031](./ADR-0031-stand-up-honeydrunk-audit-node.md)) — gains an AppHost at first-feature-packet time when its query API becomes runnable.
- **`HoneyDrunk.Lore`** — gains an AppHost when its ingest service becomes a runnable workload (today the ingest is a Claude Code skill, not a runtime; an AppHost would land if/when it becomes a service).

### New Invariants

This ADR commits two new invariants (final numbers assigned at acceptance):

- **Invariant — every multi-process containerized Node (deployable Node with more than one runtime entry point) ships an Aspire AppHost project as its local-dev inner loop.** Single-process Nodes may ship an AppHost optionally; multi-process Nodes must. The AppHost is the canonical answer to "how do I run this locally."
- **Invariant — Aspire-generated infrastructure templates (Bicep, ARM) are never used as the production deployment authority.** Production deployment authoring stays in `HoneyDrunk.Standards` shared workflows and each Node's curated Bicep per [ADR-0015](./ADR-0015-container-hosting-platform.md).

The second invariant is the production guardrail. It prevents drift between Aspire's evolving generator output and the curated production posture.

### Operational Consequences

- **The user's first multi-service local-dev experience is structured rather than ad-hoc.** Notify's AppHost is the first thing the user runs after this ADR + the Notify-dev-deploy work; the experience sets the expectation for every Node that follows.
- **A dev Service Bus namespace runs continuously**, costing ~$10/month at Basic tier. This is a known recurring cost recorded against the studio's Azure budget per [ADR-0052](./ADR-0052-cost-governance-budget-alerts-and-kill-switches.md). Acceptable given the discipline benefit (no class of "InMemory works, ASB fails" bugs).
- **Docker Desktop is a hard prerequisite on the user's box.** The Cosmos emulator, Azurite, and Redis containers all require it. The user runs Docker Desktop already; the dependency is real but not new.
- **Aspire version evolution is a recurring concern.** Each Aspire release brings shape changes; the Standards-hosted extension methods (D6) absorb churn so per-Node AppHosts stay stable. A breaking Aspire release would force a Standards update + a coordinated per-Node refresh.
- **The Pulse-iteration dual-emit pattern (D4)** is the user's window into the studio's own observability surface during local dev. When iterating on Pulse-specific features (telemetry retention, trace enrichment, custom Pulse semantics), the dual-emit lets the user see the trace in both Aspire's general-purpose dashboard and Pulse's specific lens simultaneously.
- **The `HoneyDrunk.Workshop` Node is a new lightweight repo.** It carries no NuGet packages and no production runtime; its CI runs the AppHosts in a non-launching syntax-check mode (Aspire offers a `Aspire.Hosting.Testing` mode that validates the AppHost compiles and resolves resources without actually launching them). The repo's standup is a separate ADR follow-up; this ADR commits the role.
- **Container Apps Jobs and Aspire coexist** per D8. The local-dev pattern for a job is a project-with-timer; the production pattern is a Container Apps Job definition. The two share the entry point but not the scheduling mechanism. This is the pattern the future Container Apps Jobs ADR locks down; this ADR records the local-dev side.

### Catalog and Reference Updates Required

This ADR identifies the updates required at acceptance. The updates themselves are filed as scope-agent-dispatched packets, not authored in this ADR text:

- [`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) — update line 152 (the .NET Aspire row) to reflect "Adopted as the Grid's local-dev orchestrator per ADR-0065. Local-dev only; production deployment via curated Bicep per ADR-0015." Move from Q2–Q3 2026 to "Adopted."
- [`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) — add a row noting that the dev Service Bus namespace is provisioned when first needed and runs at Basic tier; reference [ADR-0028](./ADR-0028-event-driven-architecture-and-messaging.md) for the topic strategy.
- [`catalogs/nodes.json`](../catalogs/nodes.json) — add `honeydrunk-workshop` Node entry (Meta sector, lightweight, no NuGet packages) when the Workshop standup ADR ships.
- [`catalogs/relationships.json`](../catalogs/relationships.json) — Workshop entry with `consumes` listing whichever Nodes its scenario AppHosts compose (variable per scenario; documented per AppHost).
- [`catalogs/grid-health.json`](../catalogs/grid-health.json) — Workshop entry once it exists.
- [`constitution/sectors.md`](../constitution/sectors.md) — Meta sector table adds Workshop with the "local-dev scenario AppHosts" responsibility.
- [`constitution/invariants.md`](../constitution/invariants.md) — add the two new invariants listed above with final numbers assigned at acceptance.
- [`initiatives/roadmap.md`](../initiatives/roadmap.md) — add the Aspire adoption initiative with the Notify-first / Pulse-second / Communications-third migration order.
- [`repos/HoneyDrunk.Workshop/`](../repos/) — folder created by the Workshop standup ADR (a separate follow-up) with `overview.md`, `boundaries.md`, `invariants.md`.

### Follow-up Work

- File the Notify+Pulse dev-deploy packet: includes the `Notify.AppHost` project as part of the work.
- File the Standards packet that adds the AppHost project template and the Aspire extension methods (D6). Standards version bumps per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md); the extension methods are new public surface, additive, minor bump.
- File the Pulse migration packet (gives Pulse a `Pulse.AppHost`; aligns the Pulse dev-deploy with the Notify+Pulse story).
- File the `HoneyDrunk.Workshop` standup ADR as a separate paired follow-up.
- File the dev Service Bus namespace provisioning packet (one Basic-tier `sb-hd-dev` namespace; per-session subscription convention documented).
- File the dev Key Vault provisioning packet when the first Node's AppHost needs it (per [`feedback_provision_when_needed`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/feedback_provision_when_needed.md), this rides with the Notify AppHost).
- Author the Container Apps Jobs ADR (planned; this ADR commits the Aspire-local pattern such that the Jobs ADR has a compatible local-dev shape).
- Update `.claude/agents/scope.md` — packets that introduce new multi-process Nodes must include an AppHost project in their solution structure.
- Update `.claude/agents/review.md` per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — new PR-review checklist item: multi-process Node PRs must include or update the AppHost; Aspire-generated Bicep must not be checked into production deployment paths.
- Confirm Aspire's current version (at acceptance time) and pin the Standards templates to it. Aspire breaking changes are absorbed by Standards updates per the per-Node migration ergonomics.

## Alternatives Considered

### Stay with per-Node `launchSettings.json` + manual orchestration

Considered. Status quo for every single-process Node today; no new tooling cost.

Rejected per D1. Collapses at the first multi-process Node (Notify, imminent). Even if Notify could be muddled through by hand, the AI-sector wave behind it (nine Nodes) compounds the cost. The right time to commit an orchestrator is before the first multi-process deploy, not after several.

### docker-compose per Node, no Aspire

Considered. Mature, language-agnostic, well-understood. Works on Windows via Docker Desktop.

Rejected per D1. docker-compose has no native dashboard for .NET traces/logs/metrics; the studio would integrate one separately. docker-compose's resource model is container-only — a .NET project must be containerized to be modeled, which forces every Node's inner loop to go through Docker build + run, slowing the iteration cycle. Aspire models projects directly without requiring containerization for local dev, keeping the inner loop fast.

### Tilt / Skaffold / k3d

Considered. Kubernetes-centric inner-loop tools.

Rejected. The Grid runs on Container Apps, not Kubernetes ([ADR-0015](./ADR-0015-container-hosting-platform.md)). Adopting Kubernetes-centric local-dev tooling for a non-Kubernetes production target inverts the alignment value. If the production target were Kubernetes, the calculus changes; it is not.

### Aspire as the production deployment authority too (use `azd up`)

Considered. Aspire's generator can produce Bicep for Container Apps; `azd up` deploys the AppHost-modeled Grid to Azure.

Rejected per D5. The studio's production posture is curated and reviewed; Aspire's generator output is fast but not curated. Coupling production deployment to Aspire's evolving generator would make every Aspire release a production-release event. The split — Aspire for local-dev, curated Bicep for production — keeps both surfaces controlled.

### One central AppHost in `HoneyDrunk.Architecture`

Considered. Architecture is the Grid's command center; a single AppHost there would be the single answer to "show me the Grid."

Rejected per D2. Architecture is a documentation/catalog Node, not a code-building Node. It does not take build-time dependencies on the Grid Nodes it catalogs; adding AppHosts would invert that. The per-Node AppHost for solo Node work + the per-scenario AppHost in `HoneyDrunk.Workshop` for cross-Node work is the right two-tier shape.

### One AppHost per Node only; no per-scenario AppHosts

Considered. Per-Node AppHosts can compose other Nodes by reference; a per-Node AppHost is the only abstraction needed.

Rejected. Scenarios are intent — "this combination is the inner loop I'm iterating on right now" — and intent does not have a natural home in any one Node's repo. The Workshop Node captures intent without forcing it into a Node where it does not belong.

### In-process broker shim for local dev (`HoneyDrunk.Transport.InMemory` everywhere)

Considered. The InMemory broker exists; using it locally avoids the dev Service Bus cost.

Rejected per D9. The InMemory broker's semantics differ from Service Bus in load-bearing ways (ordering, dead-letter, lock duration, prefetch). A bug class that passes local CI and fails in production is exactly what local-dev orchestration is supposed to prevent. The dev Service Bus cost (~$10/month Basic tier) is worth it.

### Azurite + a custom ASB shim package

Considered. There are community Service Bus shim implementations that emulate ASB semantics in-process more faithfully than the studio's own InMemory broker.

Rejected. Community shims have varying faithfulness, varying maintenance, and a recurring update cost. Real dev ASB is the highest-fidelity option and the simplest to reason about. If a future shim becomes credible (Microsoft ships a first-party emulator, for example), this ADR is amended; until then, real dev ASB is the call.

### Adopt Aspire only for Notify; defer the Grid-wide stance

Considered. Notify is the first multi-service deploy; adopt for Notify and decide the Grid-wide question when more Nodes need it.

Rejected. Adopting per-Node without a Grid-wide stance means each Node's first multi-service deploy re-litigates the question. The pattern this ADR is trying to prevent is exactly N independent inner-loop patterns. Better to decide Grid-wide now, even though most Nodes do not need the AppHost yet, so the convention is in place when each Node arrives at its first multi-service moment.

### Use Aspire's CI mode for integration tests

Considered. `Aspire.Hosting.Testing` allows the AppHost to host integration test fixtures.

Rejected for v1 per D10. The current Testing ADR ([ADR-0047](./ADR-0047-testing-patterns-and-tooling.md)) commits to Tier 2b container-based integration tests; Aspire integration is a follow-up consideration. Adopting Aspire in CI without a measured comparison risks a CI shape change without clear benefit. Recorded here as a future follow-up if and when the Testing ADR chooses to escalate.

### Make AppHosts mandatory for every Node, including library-only ones

Considered. Uniform convention; every Node has an AppHost.

Rejected per D7. Library-only Nodes (Kernel, Vault, Transport, Auth, Standards) have no runtime; nothing for the AppHost to launch. Forcing the convention adds ceremony without benefit. The "multi-process containerized Nodes must have an AppHost; single-process Nodes may; library-only Nodes do not" rule is the right granularity.

### Use `dotnet user-secrets` for all Aspire-resolved local resource connection strings

Considered. The .NET-standard local-secrets mechanism for connection strings.

Accepted but flagged here as the convention rather than as a separate alternative. Aspire's `AddGridServiceBusDev` and similar extensions read from `dotnet user-secrets`; the studio commits to that mechanism for any dev resource that requires authentication.

### Treat HoneyDrunk.Workshop as a new sector instead of placing it in Meta

Considered. A "Dev" sector for local-dev tooling.

Rejected. Sector inflation is real cost; a single Node does not warrant its own sector. Meta already houses Architecture (the catalog of the Grid) and Studios (the public face of the Grid); Workshop (the local-dev composition of the Grid) is naturally adjacent to both.

### Build a HoneyHub local-dev integration into the Aspire dashboard

Considered. HoneyHub ([ADR-0002](./ADR-0002-honeyhub-command-center.md), [ADR-0003](./ADR-0003-honeyhub-control-plane.md)) is the Grid's command center; the Aspire dashboard and HoneyHub overlap conceptually (both surface "what's running where").

Deferred. HoneyHub is the production command center; the Aspire dashboard is the local-dev surface. Cross-integration is a follow-up if a real workflow shape demands it; speculative integration now would couple two evolving surfaces. The two stay separate at v1; if HoneyHub's Phase 2 work makes the integration valuable, a follow-up ADR commits the shape.

### Adopt Aspire's "Azure Functions" project resource for Notify's Functions process

Accepted. Aspire ships first-party support for Azure Functions project resources; Notify's Functions process composes via `AddAzureFunctionsProject<T>`. Recorded here so the Notify migration packet uses the supported pattern from day one.
