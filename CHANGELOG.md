# Changelog

## Unreleased

- Accept ADR-0030 (Grid-Wide Audit Substrate). Register `honeydrunk-audit` Node across nodes.json/relationships.json/contracts.json/grid-health.json/modules.json with four new edges (Audit→Kernel, Audit→Data, Auth→Audit planned, Operator→Audit planned). Add Core-sector Audit row. Mark Operator's `IAuditLog` as relocated to `honeydrunk-audit`. (ADR-0018's pre-existing 2026-05-16 amendment recording the `IAuditLog`/`AuditEntry` relocation and Operator's reclassification to consumer-not-owner was verified unchanged — not modified by this PR.) Create `repos/HoneyDrunk.Audit/` context folder. ADR-0030 flipped Proposed → Accepted; ADR-0031 standup remains Proposed (separate initiative).
- Renamed the legacy initiative sync agent to `hive-sync` and moved the runtime contract from GitHub Actions/Anthropic to OpenClaw scheduled/manual execution.
- Added Hive Sync packet lifecycle handling for `active/` → `completed/` moves and `filed-packets.json` path reconciliation.
- Added Hive Sync non-initiative board tracking via `initiatives/board-items.md` and Hive Sync invariants.
- Added ADR/PDR acceptance reconciliation, `accepts:` packet frontmatter guidance, README Status/Date sync, and `initiatives/proposed-adrs.md`.
- Added Hive Sync drift reporting via `initiatives/drift-report.md`.
