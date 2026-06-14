---
name: Superseded Work Item
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["superseded", "adr-0048", "schema"]
dependencies: []
adrs: ["ADR-0048"]
wave: 4
initiative: adr-0048-schema-evolution
node: honeydrunk-standards
superseded: true
---

# Superseded: Standards rollback attribute

This packet is superseded by the ADR-0048 SQL project/DACPAC revision.

Do not add a shared C# rollback attribute. Rollback posture is declared as PR-body metadata (`RollbackStrategy: ForwardSchemaChange` or `RollbackStrategy: NonRollback`) and documented in the Node-owned SQL project README. No Standards runtime package is needed for this policy.

The already-filed issue for this packet should be closed as superseded once this Architecture correction merges.
