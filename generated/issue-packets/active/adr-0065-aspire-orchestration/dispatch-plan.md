# Dispatch Plan — ADR-0065: Multi-Service Local Dev Orchestration and .NET Aspire Stance

**Initiative:** `adr-0065-aspire-orchestration`
**ADR:** ADR-0065 (Proposed → Accepted via packet 00)
**Sector:** Ops / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0065 decides the Grid's local-dev orchestrator: `.NET Aspire`, two-tier AppHost shape (per-Node + per-scenario `HoneyDrunk.Workshop` in a separate standup ADR), per-Node resource modeling, opt-in Pulse dual-emit, deliberate separation from production deployment authoring (`HoneyDrunk.Standards` + curated Bicep stays the production authority), Standards-hosted template + extension methods, incremental per-Node migration (Notify first, Pulse second), Container Apps Jobs cross-reference for the future Jobs ADR, real dev Service Bus (no in-process shim), and "Aspire not in CI."

This initiative delivers: ADR acceptance + the two new Aspire invariants + initiative registration (Architecture); tech-stack.md update + scope.md/review.md agent-file updates (Architecture); the AppHost project template and the Grid Aspire extension methods in `HoneyDrunk.Standards`; the `sb-hd-dev` Service Bus namespace provisioning walkthrough + execution (Architecture, Human); and the first two per-Node AppHosts — `HoneyDrunk.Notify.AppHost` (first migrant) and `HoneyDrunk.Pulse.AppHost` (second migrant, owning the canonical Pulse.Collector composition).

**6 packets across 4 waves**, targeting **4 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Standards`, `HoneyDrunk.Notify`, `HoneyDrunk.Pulse`). 5 `Actor=Agent` (00, 01, 02, 04, 05), 1 `Actor=Human` (03 — Service Bus namespace provisioning, portal work).

## Trigger

ADR-0065 is Proposed with no scope. The forcing functions from the ADR's Context:

- **Notify (Functions + Worker) + Pulse.Collector dev deploy is imminent.** The first multi-service local-dev composition in the Grid. Without a decision, whatever pattern ships first becomes the de-facto Grid pattern.
- **The AI-sector standup wave (ADR-0016 through ADR-0025)** queues nine Nodes that each need a local-dev story. Without a Grid-wide stance now, each Node's first feature packet re-litigates the question and the Grid ends up with N inner-loop patterns.
- **ADR-0015** commits Container Apps as production hosting; Aspire models that platform cleanly — the local model and the production model can align if the orchestrator choice lands now.
- **Pulse OTLP integration (ADR-0010, ADR-0040)** wants the Aspire dashboard and Pulse to consume the same OTLP stream for Pulse-iteration scenarios.

The ADR needs decomposition into actionable packets.

## Scope Detection

**Multi-repo.** ADR-0065 touches `HoneyDrunk.Standards` (the AppHost template + Grid Aspire extension methods per D6), `HoneyDrunk.Notify` (the first migrant per D7), `HoneyDrunk.Pulse` (the second migrant per D7, carrying the canonical Pulse.Collector AppHost per D4), and `HoneyDrunk.Architecture` (the governance, the two new invariants, the catalog/reference updates, the dev Service Bus walkthrough). No cascade to consuming Nodes beyond Notify/Pulse — the AppHost is per-Node and the Standards extensions are pulled piecemeal as each Node migrates (D7 opportunistic migration). Communications, Notify Cloud, Audit, the AI-sector Nodes, and Workshop are all named in the ADR but are explicitly **out of scope for this initiative** (see Cross-Cutting Concerns).

## Wave Diagram

### Wave 1 (governance + reference updates — parallel)
- [ ] **00** — Architecture: Accept ADR-0065, add the two Aspire invariants, register the initiative. `Actor=Agent`.
- [ ] **01** — Architecture: Update `tech-stack.md`, `.claude/agents/scope.md`, `.claude/agents/review.md` for the Aspire stance. `Actor=Agent`. Blocked by: 00.

### Wave 2 (Standards foundation)
- [ ] **02** — Standards: Author the AppHost project template + Grid Aspire extension methods (`AddGridTelemetry`, `AddGridCosmosEmulator`, `AddGridAzurite`, `AddGridServiceBusDev`, `AddGridKeyVaultDev`, `AddGridAppConfigDev`). `Actor=Agent`. Blocked by: 00. **Version-bumping packet for `HoneyDrunk.Standards`.**

### Wave 3 (infra provisioning, Human)
- [ ] **03** — Architecture: Author the dev Service Bus provisioning walkthrough, provision `sb-hd-dev` (Basic tier), **and provision the dev App Configuration resource** by executing the existing `app-configuration-provisioning.md` for `env=dev`. `Actor=Human`. Blocked by: 00. (Independent of packet 02 — runs in parallel with Wave 2 in practice, but lives in Wave 3 because it is the second human gate alongside the Standards human release of packet 02.)

### Wave 4 (first migrants, parallel)
- [ ] **04** — Notify: Add `HoneyDrunk.Notify.AppHost` (first migrant — Functions + Worker + Cosmos Emulator + Azurite + dev ASB + dev Key Vault + dev App Configuration; opt-in Pulse dual-emit). `Actor=Agent`. Blocked by: 02, 03. **Version-bumping packet for `HoneyDrunk.Notify`.**
- [ ] **05** — Pulse: Add `HoneyDrunk.Pulse.AppHost` (second migrant — composes the existing `HoneyDrunk.Pulse.Collector` project + dev Key Vault + dev App Configuration). `Actor=Agent`. Blocked by: 02. **Pulse.Collector already exists** (`HoneyDrunk.Pulse/Pulse.Collector/HoneyDrunk.Pulse.Collector.csproj`, `Microsoft.NET.Sdk.Web`, OTLP receiver) — no new Collector host is introduced. **First packet on the Pulse solution in this initiative — bumps if no ADR-0040 Pulse packet has bumped the in-progress version, otherwise appends to the in-progress version (invariant 27).**

Packets within a wave run in parallel. Wave-4 packets 04 and 05 are independent — different repos, no shared solution — and run in parallel. Packet 04 is `Blocked by: 02, 03` (needs both the Standards extensions and the dev ASB namespace); packet 05 is `Blocked by: 02` only (Pulse's AppHost does not consume ASB locally — Pulse.Collector receives OTLP, not ASB messages). Packet 03 (Human) can in practice run alongside packet 02 (both depend only on packet 00); they sit in nominal Wave 2 / Wave 3 for tidy filing but the `dependencies:` frontmatter is the real ordering signal.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0065](./00-architecture-adr-0065-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [tech-stack + scope/review agent updates](./01-architecture-tech-stack-and-agent-updates.md) | Architecture | Agent | 1 | 00 |
| 02 | [Standards AppHost template + Grid Aspire extensions](./02-standards-aspire-template-and-extensions.md) | Standards | Agent | 2 | 00 |
| 03 | [Dev Service Bus walkthrough + `sb-hd-dev` + dev App Configuration](./03-architecture-dev-service-bus-walkthrough.md) | Architecture | Human | 3 | 00 |
| 04 | [Notify.AppHost (first migrant)](./04-notify-add-apphost.md) | Notify | Agent | 4 | 02, 03 |
| 05 | [Pulse.AppHost (second migrant, canonical Pulse.Collector composition)](./05-pulse-add-apphost.md) | Pulse | Agent | 4 | 02 |

## Version Bumps

- **`HoneyDrunk.Standards`** — packet 02 is the first packet on the solution; it bumps every non-test `.csproj` to the same new minor version. New public surface (the Aspire extensions + the AppHost template) — additive minor bump per ADR-0035.
- **`HoneyDrunk.Notify`** — packet 04 is the only Notify packet in this initiative; it bumps the whole solution one minor version (new project added — functional change). Confirm Notify's current version at execution time and bump to the next minor.
- **`HoneyDrunk.Pulse`** — packet 05 is the first Pulse packet in this initiative. Sibling-initiative coordination: if ADR-0040 Pulse packets are mid-flight at execution time and have already bumped the in-progress Pulse version, packet 05 appends to that version's CHANGELOG rather than double-bumping. If ADR-0040 work is fully released, packet 05 is the bumping packet. The PR description records which case applies.
- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/doc/walkthrough edits only.

## Cross-Cutting Concerns

### Workshop standup is a separate ADR — deliberate deferral

ADR-0065 D2 names a new lightweight `HoneyDrunk.Workshop` Node (Meta sector) that hosts per-scenario AppHosts. ADR-0065 Follow-up Work: "File the `HoneyDrunk.Workshop` standup ADR as a separate paired follow-up." The user's standing preference is "New-Node scaffolding gets its own ADR; don't bundle scaffold into feature packets" (memory note `feedback_adr_before_scaffold`). This initiative therefore **does not**:

- Add `honeydrunk-workshop` to `catalogs/nodes.json`, `catalogs/relationships.json`, or `catalogs/grid-health.json`.
- Add a Workshop row to `constitution/sectors.md`.
- Create `repos/HoneyDrunk.Workshop/` with `overview.md`, `boundaries.md`, `invariants.md`.
- Create the GitHub repo `HoneyDrunk.Workshop` or its initial scaffold.

All of those land via the Workshop standup ADR (TBD ADR number; the operator drafts it as a follow-up). When the Workshop standup lands, its first scenario AppHost is the first useful cross-Node integration scenario at the time (likely Notify + Communications full email-orchestration loop per D2, but the standup ADR makes the concrete first-scenario choice).

### Communications migration is opportunistic — out of scope here

ADR-0065 D7 names Communications as the third migrant, "when its worker process arrives (probably when it gains a worker process for cadence enforcement)." Today Communications is in-process per ADR-0028 D4. Migrating Communications is a forcing-function-triggered event, not a planned packet. **This initiative ships no Communications AppHost.** When Communications gains a worker process, the migration packet is filed against that work — likely as part of a Communications feature initiative — and consumes the `HoneyDrunk.Standards.Aspire` extensions this initiative ships.

### AI-sector seed Nodes adopt at first feature packet — out of scope here

ADR-0065 D7 explicitly defers AI-sector AppHost adoption to the **first feature packet** of each seed Node, rather than at standup. This initiative does not pre-create AppHosts for `HoneyDrunk.AI`, `HoneyDrunk.Agents`, `HoneyDrunk.Memory`, `HoneyDrunk.Knowledge`, `HoneyDrunk.Evals`, `HoneyDrunk.Flow`, `HoneyDrunk.Sim`, `HoneyDrunk.Operator`. Each AI-sector Node's first feature packet adopts the Standards extensions when its multi-process moment arrives.

### Library-only Nodes get no AppHost — out of scope here

ADR-0065 D7's final rule: single-process library-only Nodes (Kernel, Vault, Transport, Standards, Auth, Web.Rest, Data) have no runtime and therefore no AppHost. This initiative does not attempt to create AppHosts for those Nodes. (Standards is the home of the *extensions and template*, not an AppHost consumer.)

### Notify Cloud, Audit, Lore — out of scope here, mentioned in the ADR

- **Notify Cloud (ADR-0027)** — when scaffolded, its AppHost models the wrapper + Notify + Communications + Service Bus + Cosmos + Stripe-test endpoint. Not in this initiative; rides with the Notify Cloud standup or first-feature work.
- **Audit (ADR-0031)** — gains an AppHost at first-feature-packet time when its query API becomes runnable. Not in this initiative.
- **Lore** — gains an AppHost if/when its ingest becomes a service (today it is a Claude Code skill). Not in this initiative.

### Coordination with ADR-0040 (Telemetry Backend) — Pulse-solution version-bump

ADR-0040's Pulse packets (`adr-0040-telemetry-backend` initiative, packets 03/04/05/07) extend `HoneyDrunk.Telemetry.Sink.AzureMonitor` and may be mid-flight at the time this initiative's packet 05 (Pulse.AppHost) executes. Per invariant 27 (one version across the solution), the first un-released packet on the Pulse solution bumps the version; subsequent packets append to the in-progress version's CHANGELOG. Packet 05 records at execution time which case applies and either bumps or appends accordingly. No `dependencies:` edge is wired between the two initiatives — they are siblings on the Pulse solution, and the version-bump rule self-coordinates.

### Coordination with ADR-0066 (Health / Readiness / Liveness Endpoints) — soft

ADR-0066 (Health / Readiness / Liveness Endpoints) is named in the recent ADR batch (2026-05-23). The Aspire dashboard surfaces health/readiness signals from project resources via standard `.NET` health-check conventions. If ADR-0066 lands and ships health-check contracts, future Aspire AppHost packets may compose those contracts; this initiative does not. No `dependencies:` edge.

### `dotnet user-secrets` is the canonical dev-secrets mechanism

ADR-0065 Alternatives Considered (Accepted) — `dotnet user-secrets` is the convention for any dev resource that requires authentication, used by `AddGridServiceBusDev` and similar extensions. The dev Service Bus walkthrough (packet 03) and the Notify AppHost packet (04) both document the seeding command. No separate packet codifies this convention; it is an inline convention recorded across the packets that use it.

### Aspire SDK version pin — recorded at execution time

ADR-0065 Follow-up Work: "Confirm Aspire's current version (at acceptance time) and pin the Standards templates to it. Aspire breaking changes are absorbed by Standards updates per the per-Node migration ergonomics." Packet 02 pins the Aspire SDK version at execution time; the PR description records the version. Future Aspire bumps land as `HoneyDrunk.Standards` minor/major releases.

### Site sync

No site-sync flag. ADR-0065 is internal Ops infrastructure — no public-facing Studios website content changes.

## Rollback Plan

- **Packets 00–01 (governance/reference):** revert the PR. ADR returns to Proposed; the two invariants are removed; tech-stack.md, scope.md, review.md revert. No runtime impact.
- **Packet 02 (Standards extensions + template):** revert the PR; the `HoneyDrunk.Standards` solution version rolls back one minor. The new packages (`HoneyDrunk.Standards.Aspire`, `HoneyDrunk.Standards.Templates.AspireAppHost`) leave the solution. Per-Node AppHost packets (04, 05) become unbuildable until packet 02 is re-applied or replaced.
- **Packet 03 (dev Service Bus provisioning):** the `sb-hd-dev` namespace can be deleted in the Azure Portal; the walkthrough doc can be reverted. Low cost (~$10/month while running), easily reversed. If Notify's AppHost is in production-use locally and depends on the namespace, the rollback breaks Notify's local-dev — coordinate with packet 04.
- **Packet 04 (Notify.AppHost):** revert the PR; the new `HoneyDrunk.Notify.AppHost` project leaves the solution. Notify's existing `launchSettings.json` composition is untouched by this packet, so Notify's pre-AppHost local-dev experience is restored. The solution version rolls back.
- **Packet 05 (Pulse.AppHost):** revert the PR; the new `HoneyDrunk.Pulse.AppHost` project leaves the solution. The existing `HoneyDrunk.Pulse.Collector` project is untouched by this packet, so a revert leaves Pulse's runtime exactly as it was. The solution version rolls back if this was the bumping packet.
- **Operational escape hatch:** Aspire is local-dev only (D5). Production deployments are entirely unaffected by any rollback in this initiative.

## Filing

Filing is automated. On push to `main`, `file-packets.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.
