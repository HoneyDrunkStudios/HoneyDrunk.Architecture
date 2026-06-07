# HoneyDrunk.HoneyHub - Integration Points

## Runtime Dependencies at v1

HoneyHub has zero live runtime Grid-Node dependencies at v1. The cockpit is a static PWA plus a local bridge. The bridge runs on the user's machine or runner host and drives local tools.

## Planned Grid Integrations

| System | Direction | Status | Purpose |
|---|---|---|---|
| Architecture repo | HoneyHub reads | Planned | Structural read backend for the later PDR-0009 Dev-surface layer. HoneyHub reads decisions and catalogs as a derived index, never as authoritative writer. |
| HoneyDrunk.AI | HoneyHub consumes | Planned | `IRoutingPolicy` / `IModelRouter` contract for the Phase 3 routing engine. |
| ADR-0052 / ADR-0016 cost-rate surface | HoneyHub reads | Planned | Rate source for derived USD values. |
| ADR-0086 runner host | Hosts bridge | Operational relationship | Solo-mode local bridge host. This is not a package edge. |

## External Runtime Dependencies

- Official Claude Code CLI for `claude.local`.
- Official Codex CLI for `codex.local` in Phase 3+.
- Official GitHub Copilot CLI for `copilot.local` in Phase 3+.
- Git and GitHub CLI for artifacts such as branches and PRs.
- Tailscale for the default mobile relay path.

## Downstream Consumers

None at v1.
