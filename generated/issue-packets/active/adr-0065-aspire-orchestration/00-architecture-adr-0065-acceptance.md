---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ops", "docs", "adr-0065", "wave-1"]
dependencies: []
adrs: ["ADR-0065"]
accepts: ["ADR-0065"]
wave: 1
initiative: adr-0065-aspire-orchestration
node: honeydrunk-architecture
---

# Accept ADR-0065 — flip status, add the two Aspire invariants, register the initiative

## Summary
Flip ADR-0065 (Multi-Service Local Dev Orchestration and .NET Aspire Stance) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the two new Aspire invariants ADR-0065 commits in its "New Invariants" section to `constitution/invariants.md` at the reserved invariant numbers `{N1}`/`{N2}` (claimed in `constitution/invariant-reservations.md`), and register the `adr-0065-aspire-orchestration` initiative in `initiatives/active-initiatives.md`.

**Invariant reservation.** ADR-0065 adds two invariants. The block size is **2**. Per the reservation protocol in `constitution/invariant-reservations.md`, this packet claims the next free block above the current ceiling. At packet-authoring time the ADR-0064 reservation (74–77) sits at the top, so ADR-0065's block is **78–79** — `{N1} = 78`, `{N2} = 79`. **Verify at execution time** by reading `constitution/invariant-reservations.md` immediately before editing: if another packet 00 has merged ahead of this one and shifted the ceiling, claim the next free pair and update every `{N1}`/`{N2}` placeholder in this packet plus the corresponding row in `invariant-reservations.md` (the row for ADR-0065 was added in this same PR — shift its `Range` column to the new pair).

## Context
ADR-0065 decides the Grid's local-dev orchestrator: `.NET Aspire`, two-tier AppHost shape (per-Node + per-scenario `HoneyDrunk.Workshop`), per-Node resource modeling, opt-in Pulse dual-emit, deliberate separation of production deployment authoring (`HoneyDrunk.Standards` + curated Bicep stays the authority — Aspire's generator is never the production path), Standards-hosted template + extension methods, incremental per-Node migration (Notify first), Container Apps Jobs cross-reference, real dev Service Bus (no in-process shim), and "Aspire not in CI." It was authored 2026-05-23 as part of an Ops/cross-cutting batch of decisions and has had no scope until now.

The forcing functions from ADR-0065's Context: **the Notify (Functions + Worker) + Pulse.Collector dev deploy is imminent** — the first time the user will run multiple Grid services together locally; whatever pattern ships first becomes the de-facto Grid pattern. **The AI-sector standup wave (ADR-0016 through ADR-0025) queues nine Nodes behind it** that each need a local-dev story; without a Grid-wide stance now, each of those Nodes' first feature packets re-litigates the question. **ADR-0015** commits Container Apps as production hosting and Aspire models that platform cleanly. **Pulse OTLP integration (ADR-0010, ADR-0040)** wants the Aspire dashboard and Pulse to consume the same OTLP stream where it matters.

The ADR decides:
- **D1** — adopt `.NET Aspire` as the Grid's local-dev orchestrator (local-dev only).
- **D2** — two-tier AppHost shape: one `{Node}.AppHost` per containerized Node for solo work; one per-scenario AppHost in `HoneyDrunk.Workshop` for cross-Node integration work.
- **D3** — resource modeling: project resources for `.NET` processes, container resources for emulators (Cosmos, Azurite, Redis), connection-string resources for non-emulated dev services (Service Bus, Key Vault, App Configuration). Aspire's built-in OTLP receiver wired by default.
- **D4** — Pulse integration: default ships OTLP to Aspire dashboard only; opt-in `AddPulseCollector()` fan-out to a local Pulse.Collector for Pulse-iteration scenarios.
- **D5** — production deployment is **separate** from Aspire. `HoneyDrunk.Standards` shared workflows + per-Node curated Bicep stays the production authority (per ADR-0015). Aspire-generated Bicep is never the production path.
- **D6** — Standards alignment: AppHost project template + `HoneyDrunkAspireExtensions.AddGridTelemetry` + default emulator/dev-resource wiring extensions (`AddGridCosmosEmulator`, `AddGridAzurite`, `AddGridServiceBusDev`, `AddGridKeyVaultDev`, `AddGridAppConfigDev`). Versioned per ADR-0035.
- **D7** — incremental per-Node migration: Notify first; Pulse second; Communications third (when its worker arrives); AI-sector seed Nodes adopt at first feature packet, not at standup; library-only Nodes (Kernel, Vault, Transport, Standards, Auth, Web.Rest, Data) get no AppHost.
- **D8** — Container Apps Jobs cross-reference: local pattern is a project-with-timer hosted service inside the AppHost; production runs the same entry point under a Container Apps Job definition. The future Container Apps Jobs ADR is the authority.
- **D9** — Windows-first matrix: real dev Service Bus (`sb-hd-dev`, Basic tier, one topic per Grid topic, per-session subscriptions) — no in-process broker shim. The InMemory broker's semantics differ from ASB in load-bearing ways.
- **D10** — Aspire is not in CI. CI keeps unit tests + Tier 2b container-based integration tests + InMemory test doubles. `Aspire.Hosting.Testing` is a future follow-up for ADR-0047.

ADR-0065 is a **policy / orchestration** ADR. The concrete code — the AppHost projects in Notify and Pulse, the Standards template + extension methods, the dev Service Bus namespace, the Workshop standup ADR — lands in `HoneyDrunk.Standards`, `HoneyDrunk.Notify`, `HoneyDrunk.Pulse`, and Architecture infra walkthroughs in this initiative. The Workshop Node standup is a deliberately separate follow-up ADR (memory note: new-Node scaffolding gets its own ADR). Every other packet references ADR-0065's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0065-multi-service-local-dev-orchestration-aspire.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0065 row Status column to Accepted.
- `constitution/invariants.md` — add the two new Aspire invariants (see Proposed Implementation for exact text), numbered `{N1}` and `{N2}` (the reserved pair from `constitution/invariant-reservations.md`; **78–79** at packet-authoring time — verify before edit).
- `constitution/invariant-reservations.md` — the reservation row for ADR-0065 lands in the **same PR** as this packet (the row was added in the packet-set commit; if a collision happened in the interim, shift the range column and the body's `{N1}`/`{N2}` numbers together).
- `initiatives/active-initiatives.md` — register the `adr-0065-aspire-orchestration` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0065 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0065 index row in `adrs/README.md` to Accepted.
3. **Re-verify the invariant reservation.** Open `constitution/invariant-reservations.md` and confirm the ADR-0065 row's `Range` column. At packet-authoring time it reads `78–79`. If a parallel packet 00 has merged and consumed that pair, the row will need to shift upward — apply the same shift to every `{N1}`/`{N2}` placeholder in this packet body and in any downstream packet that hardcodes the numbers. The verified pair becomes `{N1}` and `{N2}` for the remaining steps.
4. Add two new invariants to `constitution/invariants.md`. The text, taken verbatim-in-substance from ADR-0065's "New Invariants" section:
   - **Invariant `{N1}` — Every multi-process containerized Node ships an Aspire AppHost project as its local-dev inner loop.** A multi-process containerized Node is a deployable Node with more than one runtime entry point. Single-process Nodes may ship an AppHost optionally; multi-process Nodes must. The AppHost is the canonical answer to "how do I run this locally." Library-only Nodes (Kernel, Vault, Transport, Standards, Auth, Web.Rest, Data) have no runtime and are exempt. See ADR-0065 D2, D7.
   - **Invariant `{N2}` — Aspire-generated infrastructure templates (Bicep, ARM) are never used as the production deployment authority.** Production deployment authoring stays in `HoneyDrunk.Standards` shared workflows and each Node's curated Bicep per ADR-0015. Aspire's generator is allowed for sandbox experimentation but never checked into a production deployment path. See ADR-0065 D5.
   - Place these in a new `## Local-Dev Orchestration Invariants` section after the existing topical groupings (the file's convention groups invariants by topic — Dependency, Context, Secrets, Packaging, Testing, AI, Communications, Audit, etc.; local-dev orchestration is a new cross-cutting topic and warrants its own section). The numbers are `{N1}` and `{N2}` from step 3 — do not reuse, do not gap.
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0065-multi-service-local-dev-orchestration-aspire.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md` (the ADR-0065 row's `Range` column reflects the consumed pair; if a parallel packet 00 has shifted the ceiling, this row shifts too — see Proposed Implementation step 3)
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0065 header reads `**Status:** Accepted`
- [ ] The ADR-0065 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the two new Aspire invariants (every multi-process containerized Node ships an Aspire AppHost; Aspire-generated templates never used as the production deployment authority) under a new `## Local-Dev Orchestration Invariants` section, each citing ADR-0065
- [ ] The two new invariants take the reserved pair `{N1}`/`{N2}` from `constitution/invariant-reservations.md` (78–79 at authoring; shift if collided)
- [ ] `constitution/invariant-reservations.md` carries the ADR-0065 row with `Range` matching the consumed pair, and the file's "Current ceiling" line reflects the new next-free number
- [ ] `initiatives/active-initiatives.md` registers the `adr-0065-aspire-orchestration` initiative with a packet checklist
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)
- [ ] No tech-stack.md edit in this packet (tech-stack updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0065 D1 — Adopt .NET Aspire as the Grid's local-dev orchestrator (local-dev only).** Aspire is native .NET, ships an OTLP-emitting dashboard, integrates with Pulse, models Container Apps reasonably, and carries low ceremony for a solo dev with AI agents.

**ADR-0065 D2 — Two-tier AppHost shape.** Per-Node AppHost (`{Node}.AppHost`) for solo work; per-scenario AppHost in a new `HoneyDrunk.Workshop` Node for cross-Node scenarios.

**ADR-0065 D5 — Production deployment is separate.** Aspire's generator is allowed for sandbox use; it is never the production deployment authority. `HoneyDrunk.Standards` + curated Bicep stays the authority.

**ADR-0065 D7 — Migration is incremental, per-Node, no big-bang.** Notify first, Pulse second, Communications third (when its worker arrives); AI-sector seed Nodes adopt at first feature packet; library-only Nodes get no AppHost.

**ADR-0065 New Invariants section.** Exactly two new invariants: (1) every multi-process containerized Node ships an Aspire AppHost project; (2) Aspire-generated infrastructure templates are never the production deployment authority.

## Constraints
- **Acceptance precedes flip.** ADR-0065 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbering — read the reservation registry first.** The canonical source for the next-free invariant number is `constitution/invariant-reservations.md`, not `constitution/invariants.md`. At packet-authoring time the ADR-0065 row claims the pair **78–79** (`{N1} = 78`, `{N2} = 79`). At execution time, re-read the registry: if a parallel packet 00 has merged and shifted the ceiling, the ADR-0065 row's `Range` column will need to shift up to the new next-free pair, and every `{N1}`/`{N2}` placeholder in this packet (plus any downstream packet that hardcoded the numbers) shifts with it. Never reuse a claimed number, never gap.
- **New section.** The two Aspire invariants are a new cross-cutting topic; create a `## Local-Dev Orchestration Invariants` section rather than appending to an unrelated section.
- **No tech-stack.md edit here.** ADR-0065's "Catalog and Reference Updates Required" lists a tech-stack.md update — that lands in packet 01, not here.

## Labels
`chore`, `tier-3`, `ops`, `docs`, `adr-0065`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0065 to Accepted, add the two Aspire invariants to `constitution/invariants.md`, and register the Aspire-orchestration initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0065 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0065 Multi-Service Local Dev Orchestration rollout, Wave 1.
- ADRs: ADR-0065 (primary), ADR-0008 (initiative/packet conventions), ADR-0015 (Container Apps — referenced by the second invariant), ADR-0035 (Standards versioning — referenced by D6).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0065 stays Proposed until this PR merges.
- Read `constitution/invariant-reservations.md` before editing `constitution/invariants.md`; use the ADR-0065 row's reserved pair `{N1}`/`{N2}` (78–79 at authoring) under a new `## Local-Dev Orchestration Invariants` section. If a collision shifted the pair, update every `{N1}`/`{N2}` placeholder here and in downstream packets together with the registry row.
- Do not edit `infrastructure/reference/tech-stack.md` in this packet — that is packet 01's scope.

**Key Files:**
- `adrs/ADR-0065-multi-service-local-dev-orchestration-aspire.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
