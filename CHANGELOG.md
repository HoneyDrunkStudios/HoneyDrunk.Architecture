# Changelog

## Unreleased

- Accepted ADR-0010 Phase 1 in Architecture: registered `honeydrunk-observe` across catalogs, added Observe repo context, finalized Observation invariants 29-30, refreshed sector boundaries, and kept AI routing contract catalog alignment without touching package code.
- Registered ADR-0016 HoneyDrunk.AI architecture prerequisites: corrected the AI contract catalog to D3 (`ICostLedger` instead of stale `IInferenceResult`), replaced retired `Providers.Local` references with `Providers.InMemory`, clarified AI emits telemetry consumed by Pulse without a Pulse runtime dependency, added invariants 44-46 for downstream AI coupling, App Config-sourced AI rates/policies, and the AI contract-shape canary, and dropped invariant 28's stale ADR-0010 Proposed qualifier, and flipped ADR-0016 to Accepted in the ADR index/proposed-ADR tracker.
- Reconciled Architecture catalogs and trackers to the Kernel Adoption Alignment release baseline: Kernel 0.7.0, Transport 0.6.0, Vault 0.5.0, Auth 0.4.0, Web.Rest 0.5.0, Data 0.6.0, Notify 0.3.0, Pulse 0.3.0, and Communications 0.2.0.
- Moved closed Kernel Adoption and consolidation packets from `active/` to `completed/` and updated `filed-packets.json` paths while preserving still-open packet issues in `active/`.
- Added ADR-0033 for the environment-gated deploy-trigger model for deployable Nodes.
- Scoped the Kernel Adoption Alignment initiative with per-repo packets for Kernel, Transport, Vault, Auth, Web.Rest, Data, Vault.Rotation, Notify, Pulse, Communications, and Architecture catalog reconciliation.
- Reconciled Pulse's canonical Node ID from legacy `pulse` to `honeydrunk-pulse` across architecture catalogs and naming conventions.
- Accept ADR-0030 (Grid-Wide Audit Substrate). Register `honeydrunk-audit` Node across nodes.json/relationships.json/contracts.json/grid-health.json/modules.json with four new edges (Audit→Kernel, Audit→Data, Auth→Audit planned, Operator→Audit planned). Add Core-sector Audit row. Mark Operator's `IAuditLog` as relocated to `honeydrunk-audit`. (ADR-0018's pre-existing 2026-05-16 amendment recording the `IAuditLog`/`AuditEntry` relocation and Operator's reclassification to consumer-not-owner was verified unchanged — not modified by this PR.) Create `repos/HoneyDrunk.Audit/` context folder. ADR-0030 flipped Proposed → Accepted; ADR-0031 standup remains Proposed (separate initiative).
- Renamed the legacy initiative sync agent to `hive-sync` and moved the runtime contract from GitHub Actions/Anthropic to OpenClaw scheduled/manual execution.
- Added Hive Sync packet lifecycle handling for `active/` → `completed/` moves and `filed-packets.json` path reconciliation.
- Added Hive Sync non-initiative board tracking via `initiatives/board-items.md` and Hive Sync invariants.
- Added ADR/PDR acceptance reconciliation, `accepts:` packet frontmatter guidance, README Status/Date sync, and `initiatives/proposed-adrs.md`.
- Added Hive Sync drift reporting via `initiatives/drift-report.md`.
