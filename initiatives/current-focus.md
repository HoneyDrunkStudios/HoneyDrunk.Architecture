# Current Focus

The ranked priority list for the HoneyDrunk Grid — what the team (human + agents) should work on next, **in order**.

**Last reviewed:** 2026-05-21
**Review cadence:** weekly (per ADR-0043 briefing)
**Related:** per-initiative detail in [active-initiatives.md](active-initiatives.md); quarterly horizon in [roadmap.md](roadmap.md).

Rank is strict ordinal — no ties. Edit ranks directly in this table; the order *is* the decision. Cap is the top 10; everything tracked but lower lives in **Future / Watch** below.

## Ranked Priorities

| # | Item | Type | Status | Why now | Exit criteria | Blocked by |
|---|------|------|--------|---------|---------------|------------|
| 1 | Invariant 15 amendment | packet | Not started | ADR-0047 states its Invariant 15 amendment is "committed to `constitution/invariants.md`" but it is not — a live contradiction with the soon-to-land Tier 2b Testcontainers pattern. Surgical. | `constitution/invariants.md` carries the amended Invariant 15 wording + the two new ADR-0047 invariants; `hive-sync` drift report clean | None |
| 2 | Land ADR-0047 — Testing Patterns | adr-acceptance + packet | Proposed | Foundation. Every test written from now uses whatever stack is in `Directory.Build.props`; retrofit cost grows linearly with test count. Cheapest while the test surface is small. | ADR-0047 Accepted; unit stack (xUnit + NSubstitute + AwesomeAssertions + coverlet) is the `Directory.Build.props` default; Moq→NSubstitute and FluentAssertions→AwesomeAssertions migrations complete across all Node repos; CI green | None |
| 3 | Land ADR-0044 — Cloud Code Review | adr-acceptance + packet | Proposed | The review gate catches defects in everything downstream. Landing it before the AI-sector standup wave produces real PR volume is the difference between catching defects at PR time vs incident time. | ADR-0044 Accepted; `job-review-agent.yml` MVP running on every non-draft Architecture-repo PR | None |
| 4 | Deploy Notify + Pulse to dev | initiative (ADR-0015) | In progress (2/5) | In-flight operational work; dev-environment bring-up. Was the prior primary focus and still real. | `Notify#3`, `Notify#4`, `Pulse#3` closed; all three services running on `cae-hd-dev` | Pulse container image gated on upstream Ubuntu `sed` CVE-2026-5958 |
| 5 | Land ADR-0043 — Backlog Generation | adr-acceptance + packet | Proposed | Closes the loop on accepted ADRs auto-generating implementation packets. ADR-0047/0044 acceptances give the Strategic source immediate work. | ADR-0043 Accepted; `generated/issue-packets/proposed/` directory + Strategic source live | None |
| 6 | Land ADR-0046 — Specialist Review Agents | adr-acceptance + packet | Proposed | Establishes the specialist-agent pattern. The `cfo` agent has retroactive value on every cost-touching ADR/PDR. | ADR-0046 Accepted; `.claude/agents/cfo.md` authored; `agent-capability-matrix.md` updated | None |
| 7 | ADR-0044 D3 rubric rollout | packet | Not started | The 20-category rubric must land in `review.md` and the upstream agent files for ADR-0044/0046 to function as designed. | `.claude/agents/review.md` carries the 20-category rubric; `scope` / `adr-composer` / `pdr-composer` / `refine` / `node-audit` reference ADR-0044 D3 | #3 (Land ADR-0044) |
| 8 | Archive / exit-criteria review | initiative | Pending | Multiple rollouts are 100% closed; leaving them in active tracking inflates apparent active work. | ADR-0005/0006, ADR-0009, ADR-0014, Lore, Vault.Rotation, Kernel Adoption Alignment, ADR-0030 moved to `archived-initiatives.md` | None |
| 9 | ADR-0010 Phase 2 scoping | initiative | Watch | Gated. Start only when there is a concrete external-project observation need and a live application-code caller for cost-first routing. | Phase 2 packets scoped once the trigger fires | No concrete trigger yet |
| 10 | AI-sector standup readiness (Agent Kit) | initiative | Watch | Foundation for AI-powered Grid workflows — Capabilities, Agents, Memory. Gated on the AI-sector standup ADRs (0017–0025) moving toward acceptance. | Capabilities / Agents / Memory standup packets scoped | AI-sector standup ADR acceptance |

## Future / Watch

Tracked but below the active top-10. Promote into the table when a forcing function fires.

- **Commercial / substrate ADRs (0034–0042, 0045)** — all Proposed; each gated on a forcing function: 0034/0035 on first external NuGet consumer; 0036 on first paying tenant; 0037 on Notify Cloud GA; 0038 on first non-Studio sender; 0040/0045 on AI-sector trace volume; 0041/0042 on AI-sector standup. See `initiatives/proposed-adrs.md`.
- **Canary test coverage expansion** — broaden canary coverage across Node boundaries; folds into ADR-0047's canary formalization (D8) once that ADR is Accepted.
- **HoneyHub Phase 2+** — orchestration, projections, UI. Future commitment per ADR-0003.

## How to use this file

- The **rank** column is the decision. Reorder rows to re-prioritize; the table is the source of truth.
- **Type** is one of `adr-acceptance`, `packet`, `initiative`, `operational`, `housekeeping`.
- **Why now** must justify the rank — if it can't, the item probably isn't a top-10 priority.
- **Exit criteria** must be concrete and observable, not "feels done."
- Reviewed weekly at the ADR-0043 briefing; bump `Last reviewed` on every pass so stale-priority rot is visible.
- Per-initiative detail (packet checklists, board links, scope) lives in [active-initiatives.md](active-initiatives.md), not here.
