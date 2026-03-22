# HoneyHub — Integration Points

HoneyHub integrates with every repo in the Grid as a read-only context provider.

## Outbound (HoneyHub → Repos)

| Target | Artifact | Purpose |
|--------|----------|---------|
| Any repo | Issue packets | Structured GitHub Issues generated from templates |
| HoneyDrunk.Studios | Site-sync packets | Content updates for the website |
| Any repo | ADR references | Link ADRs to implementation issues |

## Inbound (Repos → HoneyHub)

| Source | What | Purpose |
|--------|------|---------|
| Any repo | Version bumps | Update `catalogs/nodes.json` versions |
| Any repo | New packages | Add entries to `catalogs/modules.json` |
| Any repo | Breaking changes | Trigger ADR and cascade assessment |
