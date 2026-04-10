# Issue Packets

Generated artifacts that describe work to be executed across HoneyDrunk repos. Governed by **ADR-0008: Work Tracking and Execution Flow** and invariants 23–25.

## Layout

```
issue-packets/
├── active/
│   ├── {initiative-slug}/
│   │   ├── dispatch-plan.md
│   │   ├── handoff-{wave-or-purpose}.md        (zero or more)
│   │   ├── 01-{target-repo-short}-{description}.md
│   │   ├── 02-...
│   │   └── 15-...
│   └── standalone/
│       └── {YYYY-MM-DD}-{target-repo-short}-{description}.md
└── archive/
    └── {initiative-slug}/                       (frozen, same structure)
```

## What each artifact is for

| Artifact | Purpose | Mutable? |
|---|---|---|
| **Issue packet** | The spec for one unit of work in one repo | No (invariant 24) |
| **Dispatch plan** (`dispatch-plan.md`) | Initiative narrative: waves, dependencies, rollback, exit criteria | Yes, at wave boundaries only |
| **Handoff** (`handoff-*.md`) | Public surface Wave N+1 may assume from Wave N | No |

**Live state lives on the org Project board, never in these files.** Per invariant 24, packets are immutable specs. Per invariant 25, dispatch plans are narratives, not live trackers.

## Lifecycle

1. **Scope agent** produces packets + dispatch plan + handoffs into `active/{initiative-slug}/`
2. **Packet-filing script** files each packet as a GitHub Issue in its target repo
3. **Org Project board** auto-adds the issues via the `repo:HoneyDrunkStudios/*` filter
4. **Execution** — cloud or local agent picks up items when `Status` → `Ready`, opens PRs
5. **Archival** — when every packet in the initiative reaches `Done` and the dispatch plan's exit criteria are met, move the entire `active/{slug}/` folder to `archive/{slug}/` in one commit

**Partial archival is forbidden.** An initiative is either wholly active or wholly archived.

## Naming conventions

### Inside an initiative folder
- `dispatch-plan.md` — fixed name
- `handoff-{wave-or-purpose}.md` — e.g. `handoff-wave2-core-nodes-bootstrap-migration.md`
- `{NN}-{target-repo-short}-{kebab-description}.md` — numeric prefix is execution order from the dispatch plan, not date

### Standalone packets
- `{YYYY-MM-DD}-{target-repo-short}-{kebab-description}.md` — date prefix since there's no enclosing initiative to provide order

## Folder rules

- `active/` — every initiative currently in flight, plus `active/standalone/` for one-offs
- `archive/` — completed initiatives, moved as a whole
- `ls active/` answers "what rollouts are in flight?" at the filesystem level

## References

- [ADR-0008: Work Tracking and Execution Flow](../../adrs/ADR-0008-work-tracking-and-execution-flow.md) — full decision, particularly D6 (lifecycle), D7 (artifact responsibilities), and D10 (file layout)
- [constitution/invariants.md](../../constitution/invariants.md) — invariants 23–25
