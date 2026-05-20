# Dispatch Plan: ADR-0028 Event-Driven Architecture and Messaging

**Date:** 2026-05-20
**Trigger:** ADR-0028 (Event-Driven Architecture and Messaging — Use-Case-First Backing Selection) Proposed — pins the use-case → backing matrix, disambiguates Pulse signals from domain events, confirms Communications → Notify is in-process at v1, and commits the Grid to Service Bus + Storage Queue + Event Grid system topics + cron + in-process domain events as the six event-driven backings.
**Type:** Multi-packet, cross-repo. Three packets land in `HoneyDrunk.Architecture` (Transport integration-points, Transport boundaries, Pulse boundaries); one lands in `HoneyDrunk.Communications` (in-process dispatch boundary confirmation).
**Sector:** Core (Transport) · Ops (Communications, Notify, Pulse)
**Site sync required:** No.
**Rollback plan:** All four packets are documentation-only — no code semantics change. Rollback is `git revert` per PR if a packet's edit turns out to be wrong shape. The ADR itself stays Proposed until packets 01–03 merge; if a showstopper surfaces during packet review, the ADR is still Proposed and there is no code-state to unwind. Packet 04 is the Communications-side documentation of an already-shipped in-process design (ADR-0019 D5 settled the dependency direction); reverting that packet would only undo a doc clarification, not behavior.

## Summary

ADR-0028's "If Accepted" checklist enumerates four concrete cross-repo edits that must land before Status flips to Accepted. Each is a discrete documentation packet against the relevant repo's boundary or integration-points file. The deferred `catalogs/contracts.json` update for `IEventPublisher` (custom-topic shape) is **not** scoped in this initiative — D6 defers it explicitly until a future custom-topic use case materializes.

- **P1** (`01-architecture-transport-integration-points-matrix`) — Adds the D2 use-case → backing matrix to `repos/HoneyDrunk.Transport/integration-points.md`. The Transport repo becomes the authoritative developer-facing reference for "which backing for which use case." Architecture-repo edit; ADR-0028's primary acceptance gate.
- **P2** (`02-architecture-transport-boundaries-scope-clarification`) — Updates `repos/HoneyDrunk.Transport/boundaries.md` to clarify Transport is the abstraction layer for **async commands and durable pub/sub only** — telemetry signals (Pulse), CI cron (Actions), and reactive resource events (Event Grid system topics) are explicitly out of Transport's scope. Encodes the negative-form of D2 (use cases #4, #5, #6 are not Transport) into the boundary doc.
- **P3** (`03-architecture-pulse-boundaries-signals-vs-events`) — Updates `repos/HoneyDrunk.Pulse/boundaries.md` with D3's "Pulse signals are not domain events" disambiguation. Closes the most-conflated concept in the Grid's messaging surfaces.
- **P4** (`04-communications-notify-sender-boundary`) — Updates Communications repo documentation to confirm D4's settled principle: `ICommunicationOrchestrator` → `INotificationSender` is in-process at v1, with the Service Bus migration path documented as a future seam (via the existing `ITransportPublisher` abstraction). The implementation already ships per ADR-0019 D5; this packet documents the boundary so future readers don't reinvent it.

All four packets carry `accepts: ADR-0028` in frontmatter so hive-sync auto-flips ADR-0028 Status → Accepted once all four issues close.

**Excluded from this initiative (per the ADR and user direction):**
- `catalogs/contracts.json` update for `IEventPublisher` (custom-topic shape) — deferred per D6 until a future custom-topic use case lands; flagged here, not scoped.
- New invariants (telemetry-vs-events; no-raw-broker-SDK-calls) — the ADR proposes them but their landing in `constitution/invariants.md` is a separate scope-agent acceptance-time edit, not packet-driven.
- Any code change in Transport, Pulse, Notify, or Communications. This ADR is a boundary/decision codification; no shipped behavior changes.

## Execution Model

Two waves. Filing is un-gated — all four packets file in one pass; the `dependencies:` frontmatter wires the blocking chain at filing time.

### Wave 1 — Architecture-repo doc edits (run first, all parallel)

The three Architecture-repo doc edits are independent at the packet level — none blocks the others. They can land in any order or in parallel. They edit different files (Transport's `integration-points.md`, Transport's `boundaries.md`, Pulse's `boundaries.md`).

- [ ] `HoneyDrunk.Architecture`: Add D2 use-case → backing matrix to `repos/HoneyDrunk.Transport/integration-points.md` — [`01-architecture-transport-integration-points-matrix.md`](01-architecture-transport-integration-points-matrix.md)
- [ ] `HoneyDrunk.Architecture`: Clarify Transport scope in `repos/HoneyDrunk.Transport/boundaries.md` — [`02-architecture-transport-boundaries-scope-clarification.md`](02-architecture-transport-boundaries-scope-clarification.md)
- [ ] `HoneyDrunk.Architecture`: Add D3 signals-vs-events disambiguation to `repos/HoneyDrunk.Pulse/boundaries.md` — [`03-architecture-pulse-boundaries-signals-vs-events.md`](03-architecture-pulse-boundaries-signals-vs-events.md)

**Wave 1 exit criteria:**
- `repos/HoneyDrunk.Transport/integration-points.md` carries the use-case → backing matrix from D2.
- `repos/HoneyDrunk.Transport/boundaries.md` carries the "async commands and durable pub/sub only" scope clarification with explicit out-of-scope items (telemetry signals, CI cron, reactive resource events).
- `repos/HoneyDrunk.Pulse/boundaries.md` carries the explicit "Pulse signals are not domain events" sentence with the negative-form rules from D3.

### Wave 2 — Communications-side documentation (run after Wave 1)

The Communications-side boundary documentation depends on the Transport-side scope being authoritative first — Communications references "the Transport abstraction" as the migration path, so Transport's own boundary doc needs to be settled before Communications can point at it. Single packet.

- [ ] `HoneyDrunk.Communications`: Confirm in-process `INotificationSender` boundary and document Service Bus migration path — [`04-communications-notify-sender-boundary.md`](04-communications-notify-sender-boundary.md)

**Wave 2 exit criteria:**
- Communications repo's `README.md` (or equivalent boundary section) explicitly states that `ICommunicationOrchestrator` → `INotificationSender` is in-process at v1.
- The migration path to Service Bus (via the existing `ITransportPublisher` abstraction, host-time composition) is documented as the v2 seam.
- The Notify intake → Notify worker queue is documented as the first async hop, separate from any Transport-mediated path.

## ADR Acceptance Gate

Every packet in this initiative carries `accepts: ADR-0028` in frontmatter. The hive-sync agent auto-flips ADR-0028 Status → Accepted when all four filed issues close. No manual ADR-flip edit is part of any packet's acceptance criteria — the auto-flip is the mechanism.

The user's direction also specifies: do **not** touch `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `adrs/README.md`, `catalogs/*.json`, or any other shared index file. The ADR file header itself is auto-flipped by hive-sync; everything else is out-of-scope for this initiative.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board, the entire `active/adr-0028-event-driven-architecture/` folder is moved to `completed/adr-0028-event-driven-architecture/` in a single commit. Partial archival is forbidden.

## Notes

- **No code packets.** Every shipped behavior referenced by this ADR already exists (Transport's providers, Pulse's OTel pipeline, Communications' in-process `INotificationSender` call, Notify's internal queue, Data's Outbox, Vault rotation's Event Grid plumbing). This ADR is a boundary-and-decision codification — the work is documenting the existing choices so future readers (and agents) don't reinvent them. The four packets here all edit doc files; none touch `.cs`, `.csproj`, or any code surface.
- **Deferred items explicitly flagged.** Custom Event Grid topics (D6), per-flow schema versioning, the static analyzer for "no raw broker SDK calls," and Notify Cloud's external webhook story are all named in the ADR as deferred. None are scoped here; the ADR itself is the tracking surface for those future ADRs.
- **The two proposed invariants (telemetry-vs-events; no-raw-broker-SDK-calls) are not landed by these packets.** They are listed in the ADR's "New invariants (proposed for `constitution/invariants.md`)" section. Their addition to the constitution is a scope-agent acceptance-time edit, not a packet's job — and per the user's direction this initiative does not touch `constitution/invariants.md`. If the user wants the invariants landed, that is a separate one-packet pass after ADR-0028 flips Accepted.
- **Catalog state.** No `catalogs/*.json` edits in this initiative. `catalogs/contracts.json`'s existing four Transport contracts (`ITransportPublisher`, `ITransportConsumer`, `IMessageHandler`, `ITransportEnvelope`) are already correct; the `IEventPublisher` entry for D6's deferred custom-topic shape is **not** added here. `catalogs/relationships.json` already captures Pulse → Transport (`PulseIngested`) and Communications → Notify edges; no new edges are introduced.
- **CHANGELOG conventions across the two affected repos differ on purpose.** Architecture CHANGELOG uses rolling `## Unreleased` — that is the repo convention for catalog/docs nodes (Architecture is not a deployable). Packets 01/02/03 correctly append to `## Unreleased` per this convention. Packet 04's Communications repo is a deployable and follows the no-Unreleased rule: the new section is dated (`## 0.2.1 - 2026-05-20`, bracket-free to match the existing `## 0.2.0 - 2026-05-18` header), and the existing `## Unreleased` entries in the Communications CHANGELOG must be folded into the new dated section before the PR ships.
- **Self-containment.** Each packet inlines the D-section text it depends on (D2 matrix, D3 disambiguation, D4 in-process decision) so the executing agent never needs to open the ADR file. Invariant 23 and 32 are inlined where relevant; ADR-0019 D5 is inlined in P4 because Communications already settled the dependency direction there.
