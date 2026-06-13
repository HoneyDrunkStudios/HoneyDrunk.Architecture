# Work Items

Generated artifacts that describe work to be executed across HoneyDrunk repos. Governed by **ADR-0008: Work Tracking and Execution Flow** and invariants 23–25.

## Layout

```
work-items/
├── proposed/
│   └── {YYYY-MM-DD}-{target-repo-short}-{description}.md
├── active/
│   ├── {initiative-slug}/
│   │   ├── dispatch-plan.md
│   │   ├── handoff-{wave-or-purpose}.md        (zero or more)
│   │   ├── 01-{target-repo-short}-{description}.md
│   │   ├── 02-...
│   │   └── 15-...
│   └── standalone/
│       └── {YYYY-MM-DD}-{target-repo-short}-{description}.md
└── completed/
    └── {initiative-slug}/                       (closed packets, same structure)
```

## What each artifact is for

| Artifact | Purpose | Mutable? |
|---|---|---|
| **Work item** | The spec for one unit of work in one repo | No (invariant 24) |
| **Dispatch plan** (`dispatch-plan.md`) | Initiative narrative: waves, dependencies, rollback, exit criteria | Yes, at wave boundaries only |
| **Handoff** (`handoff-*.md`) | Public surface Wave N+1 may assume from Wave N | No |

**Live state lives on the org Project board, never in these files.** Per invariant 24, packets are immutable specs. Per invariant 25, dispatch plans are narratives, not live trackers.

## Lifecycle

1. **Backlog generation** may produce agent-authored packet candidates into `proposed/` per ADR-0043.
2. **Human triage** promotes selected packets from `proposed/` to `active/`.
3. **Scope agent** produces already-approved execution packets + dispatch plan + handoffs into `active/{initiative-slug}/` when the operator explicitly scopes active work.
4. **Packet-filing script** files each active packet as a GitHub Issue in its target repo.
5. **Org Project board** auto-adds the issues via the `repo:HoneyDrunkStudios/*` filter.
6. **Execution** — cloud or local agent picks up items when `Status` → `Ready`, opens PRs.
7. **Completion** — when a filed issue closes, `hive-sync` moves that packet from `active/` to `completed/` and updates `filed-work-items.json` in the same PR.

**Packet lifecycle is issue-driven.** Closed packet files live under `completed/`; open packet files remain under `active/`. Dispatch plans move once the initiative has no active packet files left.

## Naming conventions

### Inside an initiative folder
- `dispatch-plan.md` — fixed name
- `handoff-{wave-or-purpose}.md` — e.g. `handoff-wave2-core-nodes-bootstrap-migration.md`
- `{NN}-{target-repo-short}-{kebab-description}.md` — numeric prefix is execution order from the dispatch plan, not date

### Standalone packets
- `{YYYY-MM-DD}-{target-repo-short}-{kebab-description}.md` — date prefix since there's no enclosing initiative to provide order

## Folder rules

- `proposed/` — generated or draft packets awaiting human selection. Agents never self-promote these to `active/`.
- `active/` — every initiative currently in flight, plus `active/standalone/` for one-offs
- `completed/` — closed work items and completed initiative dispatch plans, moved by `hive-sync` only
- `ls active/` answers "what rollouts are in flight?" at the filesystem level

## References

- [ADR-0008: Work Tracking and Execution Flow](../../adrs/ADR-0008-work-tracking-and-execution-flow.md) — full decision, particularly D6 (lifecycle), D7 (artifact responsibilities), and D10 (file layout)
- [ADR-0043: Continuous Backlog Generation Strategy](../../adrs/ADR-0043-continuous-backlog-generation-strategy.md) — proposed packet inbox and backlog source automation
- [constitution/invariants.md](../../constitution/invariants.md) — invariants 23–25, 108, and 109
