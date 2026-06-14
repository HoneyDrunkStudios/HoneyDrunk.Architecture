---
name: Superseded Work Item
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Notify
labels: ["superseded", "adr-0048", "schema"]
dependencies: []
adrs: ["ADR-0048"]
wave: 4
initiative: adr-0048-schema-evolution
node: honeydrunk-notify
superseded: true
---

# Superseded: Notify retroactive migration annotation

This packet is superseded by the ADR-0048 SQL project/DACPAC revision.

Do not execute the prior EF migration annotation scope. The Grid no longer uses EF migration classes, rollback attributes, or `dotnet ef migrations script` as the production schema deployment path. Notify adoption should instead land as a Node-owned SQL project packet that adds `HoneyDrunk.Notify.Database`, SQL schema files, a DACPAC build, a SQL project README, `RollbackStrategy` PR metadata, and a DACPAC round-trip test.

The already-filed issue for this packet should be closed as superseded once this Architecture correction merges.
