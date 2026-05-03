# Changelog

## Unreleased

- Renamed the legacy initiative sync agent to `hive-sync` and moved the runtime contract from GitHub Actions/Anthropic to OpenClaw scheduled/manual execution.
- Added Hive Sync packet lifecycle handling for `active/` → `completed/` moves and `filed-packets.json` path reconciliation.
- Added Hive Sync non-initiative board tracking via `initiatives/board-items.md` and Hive Sync invariants.
- Added ADR/PDR acceptance reconciliation, `accepts:` packet frontmatter guidance, README Status/Date sync, and `initiatives/proposed-adrs.md`.
- Added Hive Sync drift reporting via `initiatives/drift-report.md`.
