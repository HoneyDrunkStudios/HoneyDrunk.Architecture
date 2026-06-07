# HoneyDrunk.HoneyHub - Active Work

## Current Initiative

`honeyhub-v1` is in progress. It stands up the Agent Cockpit Node and ships the Phase 2 first slice.

## Resolved Standup Class

HoneyHub uses `node_class: studios-typescript-native`, the dedicated ADR-0082 class for a TypeScript web UI plus native bridge in one workspace.

Standup implications:

- Dual Node and Cargo workspace.
- Self-contained `pr.yml`.
- Required main checks after shared Actions TypeScript/Rust support lands: `PR / Node Workspace` and `PR / Rust Workspace`.
- No `pr-core.yml`.
- No NuGet or HoneyDrunk.Standards requirement.
- No org secret required by default.

## Packet Sequence

- Packet 01: Architecture catalog/context registration.
- Packet 02: Human repo setup reconciliation.
- Packet 03: HoneyHub scaffold.
- Packet 10: Actions repo-to-node mapping.
- Packet 04: Bridge core.
- Packet 05: Pairing and allowlists.
- Packet 06: Claude Code adapter.
- Packet 07: Local store and notifications.
- Packet 08: Minimal run screen.
- Packet 09: Phase 3+ outline.

## Provisional Seams

- Exact desktop-shell toolkit, code signing, and auto-update.
- Mobile relay mechanism: Tailscale is the v1 default; a HoneyHub dumb-pipe relay is gated.
- Routing placement: live `HoneyDrunk.AI` `IModelRouter` call versus app-side policy-config copy.
- Embedded local-store engine: SQLite-class default.
- Retention-window defaults for unpinned transcripts and durable records.
- Bridge language remains Rust by default, but the ADR-0090 session contract is the stable boundary.
