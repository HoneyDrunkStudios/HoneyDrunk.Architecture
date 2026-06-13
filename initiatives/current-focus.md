# Current Focus

The ranked priority list for the HoneyDrunk Grid. As of this pass, the Grid has only three active priority lanes:

1. **HoneyHub**
2. **Notify Cloud**
3. **Curiosities**

Everything else is supporting work, reconciliation, or watch. A substrate task is only current-focus material when it directly unblocks one of those three lanes, and its lane must be named.

**Last reviewed:** 2026-06-13
**Review cadence:** weekly
**Related:** per-initiative detail in [active-initiatives.md](active-initiatives.md); quarterly horizon in [roadmap.md](roadmap.md); lane trackers in [programs/honeyhub.md](programs/honeyhub.md), [programs/notify-cloud.md](programs/notify-cloud.md), and [programs/curiosities.md](programs/curiosities.md).

Rank is strict ordinal. Edit ranks directly in this table; the order is the decision. Target band is 10-15 items, but never pad with non-lane work.

## Ranked Priorities

| # | Lane | Item | Type | Status | Phase | Due | Why now | Exit criteria | Blocked by |
|---|------|------|------|--------|-------|-----|---------|---------------|------------|
| 1 | HoneyHub | Distribution 90 Wave 2 - HoneyHub launch checkpoint | initiative | In progress | Wave 2 | 2026-06-23 (target) | HoneyHub has shipped enough to stop being an internal-only artifact. The launch checkpoint removes the remaining "is this stranger-grade?" uncertainty before the first public tag, demo, and distribution loop. | Routing #33, agent-discovery rework, and Sonar #35 either closed or explicitly waived; checkpoint notes recorded in the Distribution 90 metrics log | None |
| 2 | HoneyHub | HoneyHub v0.1.0 public release + demo package | initiative | In progress | Wave 3 | 2026-07-15 (target) | The lead product lane needs a public artifact: tag, release notes, README, and a short demo that shows the local agent cockpit doing real work. Distribution is now part of the product, not a side quest. | `HoneyDrunk.HoneyHub` v0.1.0 tagged; release notes and stranger-grade README live; 2-minute demo produced; launch post drafted | #1 |
| 3 | HoneyHub | HoneyHub BYOK cloud-execution waitlist probe | initiative + product validation | In progress | Wave 2 | 2026-07-15 (target) | This is the fastest validation of whether HoneyHub can become more than a local cockpit without violating the firm BYOK-only cloud boundary. It also creates the first measurable demand signal. | Waitlist page live with concrete price, reserve action, analytics, and pre-set 30-day threshold recorded before go-live | #1 |
| 4 | HoneyHub | Loop Console scoping slice | packet | Planned | P6 discovery | 2026-08-15 (target) | Loop engineering is now HoneyHub-related only: the product question is how the cockpit lets the operator define, launch, watch, and approve loops. Scope the surface before more autonomous-loop substrate drifts into its own lane. | A lightweight Loop Console scope note exists in the HoneyHub program tracker with user jobs, minimal views, dependencies, and what is explicitly not in v1 | #2 |
| 5 | HoneyHub | Evals publish as the Tier-B loop gate | adr-acceptance + initiative | Accepted; scaffold pushed | AI-seed standup | 2026-08-31 (target) | Evals stays current only because HoneyHub's Loop Console needs a trustworthy gate before loops can run with less operator babysitting. This is not an independent AI-sector priority. | Operator Abstractions published; Evals scaffold merged; `HoneyDrunk.Evals 0.1.0` tagged and published; first gate documented for loop use | Operator Abstractions `0.1.0` publish |
| 6 | Notify Cloud | Notify Cloud go/slip decision | initiative + product decision | In progress | Distribution 90 Wave 2 | 2026-06-23 (target) | PDR-0002 cannot keep a 2026-09-15 launch shape by inertia. Commit to the date with the first scaffold underway, or slip it with a dated PDR amendment. | Decision recorded: "go" with scaffolding scope and landing-page next steps, or "slip" with PDR-0002 amendment and new date | None |
| 7 | Notify Cloud | File ADR-0027 Notify Cloud Node scaffold packet | housekeeping + packet | Anomaly: packet has no filed issue state | Precursor | 2026-07-15 (target) | The Cloud Node standup cannot execute while `06-notify-cloud-node-scaffold.md` is not represented as a filed issue. This is the concrete unblocker for the kickoff slice. | `06-notify-cloud-node-scaffold.md` filed as a GitHub issue and reflected in `proposed-adrs.md`/Hive state | None |
| 8 | Notify Cloud | Accept the PDR-0002 kickoff slice and ADR-0027 Node path | pdr-acceptance + initiative | Proposed / In progress | Kickoff | 2026-07-31 (target) | Notify Cloud is the first commercial trial. Now that the dev deploy and IaC foundation are done enough for the lane, the next work is tenant-isolation and Cloud Node shape, not more generic infrastructure. | ADR-0027 accepted or explicitly amended; Cloud Node context current; gateway/queue/Vault tenant-isolation spike scoped | #6, #7 |
| 9 | Notify Cloud | Tenant, billing, and API substrate narrowed to first-beta needs | packet + adr-scope | Planned | Beta prep | 2026-08-31 (target) | Billing, identity, API versioning, rate limits, sender identity, and package distribution are only priorities where they serve the first beta tenant. Narrow the beta slice so cross-cutting ADRs do not sprawl. | A first-beta dependency cut exists naming only the required ADR packets for signup, API key issuance, client package, metered billing, and deliverability | #8 |
| 10 | Curiosities | PDR-0008 Phase 0 content spike | pdr-acceptance + packet | Proposed | Phase 0 | 2026-08-15 (target) | Curiosities earns its place by testing the biggest kill risk first: can one dense district produce interesting, safe, reviewed POIs at a sane per-POI cost? | Launch district picked; open-data source list and license notes captured; about 25 reviewed POIs produced; per-POI cost and quality notes recorded | None |
| 11 | Curiosities | Curiosities content safety and licensing policy | packet | Planned | Phase 0 guardrail | 2026-08-15 (target) | The app points people at real places. Safety and licensing rules must exist before generated or scraped place content becomes a product artifact. | Allowed/disallowed POI rules, source licensing checklist, review rubric, and exclusion examples committed beside the Curiosities tracker | #10 |
| 12 | Curiosities | Lightweight unlock-loop prototype | packet | Planned | Phase 0 prototype | 2026-09-15 (target) | The content spike only matters if the embodied loop works. A small prototype tests question marks, GPS/manual unlock, place cards, and collection without committing to the full mobile build. | Prototype demonstrates map, locked point, unlock, place card, and collection book over the Phase 0 POI set; notes from real walks captured | #10, #11 |
| 13 | All lanes | Archive/reconcile sweep for lane clarity only | housekeeping | Pending | Reconcile | 2026-07-15 (target) | Archive work is allowed only to reduce planning noise around HoneyHub, Notify Cloud, and Curiosities. It should not compete with product work unless stale state is misleading agents. | Shipped initiatives moved or marked ready for archive; ADR-0091/0092 and ADR-0077 bookkeeping reconciled; no new substrate work promoted unless it names a lane blocker | None |

## Future / Watch

Tracked work below the active band. Promote only when it directly unblocks HoneyHub, Notify Cloud, or Curiosities.

- **Generic AI-sector standups** - Watch unless HoneyHub needs them for Loop Console, routing, or agent-cockpit work. Evals is currently promoted because it is the Tier-B loop gate.
- **Generic testing, review, idempotency, schema, and CI initiatives** - Watch unless a named lane cannot ship without the specific slice.
- **Generic commercial substrate** - Watch unless it is on the Notify Cloud first-beta path.
- **Consumer-app substrate** - Watch unless it is on the Curiosities Phase 0/Phase 1 path.
- **Historical rollouts and completed foundation work** - Archive or reconcile when stale state confuses the three-lane priority view.

## How to Use This File

- The rank column is the decision.
- The lane column is mandatory. Valid values are `HoneyHub`, `Notify Cloud`, `Curiosities`, or `All lanes` for archive/reconcile work that keeps the lane view honest.
- Substrate does not get its own lane. If the lane is not obvious, the work is not current focus.
- Due dates are targets unless marked hard.
- Exit criteria must be observable.
- Blockers that are actionable should be promoted above the blocked item.
