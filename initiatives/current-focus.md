# Current Focus

The ranked priority list for the HoneyDrunk Grid — what the team (human + agents) should work on next, **in order**.

**Last reviewed:** 2026-05-23
**Review cadence:** weekly (per ADR-0043 briefing)
**Related:** per-initiative detail in [active-initiatives.md](active-initiatives.md); quarterly horizon in [roadmap.md](roadmap.md).

Rank is strict ordinal — no ties. Edit ranks directly in this table; the order *is* the decision. Cap is the top 10; everything tracked but lower lives in **Future / Watch** below.

## Ranked Priorities

| # | Item | Type | Status | Phase | Why now | Exit criteria | Blocked by |
|---|------|------|--------|-------|---------|---------------|------------|
| 1 | Harden ADR-0044 Phase 1 transport + prepare Phase 2 | packet | In progress | **Phase 1→2 gate** | Phase 1 is live in Architecture through artifact + OpenClaw cron/poll. Before broad fan-out, close the remaining transport/tracking gaps and land Actions-side discipline checks. | Webhook delivery provisioned/verified or cron fallback explicitly retained; stale/superseded ADR-0044 issues reconciled; Actions#85/#86 landed so authorship/labels exist before Node rollout | None |
| 2 | ADR-0033 environment-gated trigger packets | packet | Open | n/a | Direct blocker on #3; actionable now. Promoted so the blocker is visible in its own right rather than buried in #3's "Blocked by" cell. | `Notify#19`, `Notify#20`, `Pulse#18` closed | None |
| 3 | Deploy Notify + Pulse to dev | initiative (ADR-0015) | In progress | **2/5 packets** | In-flight operational work; customer-relevant dev-environment bring-up. | `Notify#3`, `Notify#4`, `Pulse#3` closed; all three services running on `cae-hd-dev` | #2 (ADR-0033 trigger packets); Pulse image also gated on upstream Ubuntu `sed` CVE-2026-5958 (not actionable — wait on upstream) |
| 4 | Land ADR-0043 — Backlog Generation (Phase 1) | adr-acceptance + packet | Proposed | **Phase 1 of 4** | Closes the loop on accepted ADRs auto-generating implementation packets. ADR-0047/0044 acceptances will feed the Strategic source immediately. | ADR-0043 Accepted; Phase 1 (Strategic source event-driven on ADR acceptance + Reactive source for drift) shipped; `generated/issue-packets/proposed/` directory live | None |
| 5 | ADR-0047 Phase 2 — Tier 2a integration CI | initiative (ADR-0047) | Not started | **Phase 2 of 6** (Phase 1 complete; tracked in `active-initiatives.md`) | Foundational substrate. Closes ADR-0011 Gap 1; unblocks ADR-0042 contract tests; gives ADR-0044 D3 cat 11 (Testing Quality) something concrete to enforce. | `job-integration-tests.yml` live in Actions and wired into `pr-core.yml`; integration-test scaffold template for `scope` agent authored; `.claude/agents/review.md` Testing Quality checklist per ADR-0047 D13 | None |
| 6 | Land ADR-0046 — Specialist Review Agents (Phase 1) | adr-acceptance + packet | Proposed | **Phase 1 of 5** | Establishes the specialist-agent pattern. The `cfo` agent has retroactive value on every cost-touching ADR/PDR. | ADR-0046 Accepted; Phase 1 (`.claude/agents/cfo.md` authored + retroactively invoked against PR #162) shipped; `agent-capability-matrix.md` updated | None |
| 7 | ADR-0044 D3 severity/rubric reconciliation | packet | In progress | n/a | The rubric is now in review and authoring surfaces; the remaining Architecture-side cleanup is keeping severity taxonomy and trackers aligned so the reviewer stays consistent. | `copilot/pr-review-rules.md` maps all 20 D3 categories to Block / Request Changes / Suggest; ADR-0044 initiative tracking reflects merged work | #1 (ADR-0044 Phase 1→2 gate) |
| 8 | Archive / exit-criteria review | housekeeping | Pending | n/a | Multiple rollouts are 100% closed; leaving them in active tracking inflates apparent active work. | ADR-0005/0006, ADR-0009, ADR-0014, ADR-0030, ADR-0032, Lore, Vault.Rotation, Kernel Adoption Alignment moved to `archived-initiatives.md` | None |
| 9 | ADR-0010 Phase 2 — Observe + AI routing scoping | initiative (ADR-0010) | Watch | **Phase 2 of 3** (Phase 1 complete; Phase 3 blocked on HoneyHub Phase 1) | Gated. Start only when there is a concrete external-project observation need and a live application-code caller for cost-first routing. | Phase 2 packets scoped once the trigger fires | No concrete trigger yet |
| 10 | AI-sector standup readiness (Agent Kit) | initiative | Watch | **0/9 standup ADRs Accepted** (ADRs 0017–0025) | Foundation for AI-powered Grid workflows — Capabilities, Agents, Memory. Gated on AI-sector standup ADRs moving toward acceptance. | Capabilities / Agents / Memory standup packets scoped | AI-sector standup ADR acceptance |

## Type Legend

The `Type` column must use exactly one of these values (combinations like `adr-acceptance + packet` are allowed when a row covers acceptance *and* a discrete shipping packet — the common case for ADRs whose Phase 1 is a single packet).

| Type | When to use | Example |
|------|-------------|---------|
| `adr-acceptance` | Accept a Proposed ADR (`adrs/ADR-*.md`). Often paired with that ADR's Phase 1 implementation. | "Land ADR-0044 — Cloud Code Review (Phase 1)" |
| `pdr-acceptance` | Accept a Proposed PDR (`pdrs/PDR-*.md`). | "Land PDR-0008 — Curiosities" |
| `bdr-acceptance` | Accept a Proposed BDR (`business/decisions/BDR-*.md`) — Business Decision Records, same shape as ADRs/PDRs but scoped to operations. | "Land BDR-0002 — Mailbox provider switch" |
| `packet` | One or a few discrete GitHub issue packets, not part of a tracked multi-packet initiative. | "ADR-0033 environment-gated trigger packets" |
| `initiative` | Multi-packet rollout tracked in `active-initiatives.md`. Annotate the governing ADR/PDR in parentheses, e.g. `initiative (ADR-0015)`. | "Deploy Notify + Pulse to dev" |
| `operational` | Non-decision-driven ops work (deploys, incident response, infra bring-up) where no ADR/PDR/BDR governs the activity. | "Rotate Vault signing keys" |
| `housekeeping` | Repo hygiene, archives, doc cleanups, drift fixes. | "Archive / exit-criteria review" |

## Future / Watch

Tracked but below the active top-10. Promote into the table when a forcing function fires.

- **Commercial / substrate ADRs (0034–0042, 0045, 0046)** — all Proposed, but scope packets filed 2026-05-22/23 (#240–#269) so the implementation backlog is sized. Each ADR is gated on a forcing function: 0034/0035 on first external NuGet consumer; 0036 on first paying tenant; 0037 on Notify Cloud GA; 0038 on first non-Studio sender; 0040/0045 on AI-sector trace volume; 0041/0042 on AI-sector standup. See `initiatives/proposed-adrs.md`.
- **Newly proposed ADRs 0048–0057** (drafted 2026-05-23) — tracked in `proposed-adrs.md`; promote into the table only after triage.
- **Canary test coverage expansion** — broaden canary coverage across Node boundaries; folds into ADR-0047's canary formalization (D8). ADR is Accepted; the D8 implementation packets are part of the ADR-0047 Phase 6 / follow-up scope.
- **HoneyHub Phase 2+** — orchestration, projections, UI. Future commitment per ADR-0003.

## How to use this file

- The **rank** column is the decision. Reorder rows to re-prioritize; the table is the source of truth.
- **Always exactly 10 items.** When one ships or is removed, refill by promoting the highest-justified candidate from the **Promotion sources** below. Never run with fewer than 10 — an empty slot is a missed prioritization decision, not a virtue.
- **Promotion sources**, in the order netrunner consults them:
  1. **Future / Watch** below — items already tracked here whose forcing function has fired
  2. `proposed-adrs.md` — Proposed ADRs/PDRs in **Pending Flip** or **In Progress** that warrant attention
  3. ADR-0043 backlog generation output (when its Phase 1 lands): Strategic / Reactive / Tactical / Opportunistic packets
  4. Open Hive board items not currently tracked anywhere on this list or in F/W
  5. Operator's idea backlog (raised verbally; capture into Future / Watch first, then promote if justified)
- **Future / Watch is not fixed-size.** Promoting an item *out* of F/W does not require backfilling F/W with a new item — F/W can shrink. F/W grows organically when new ADRs/PDRs/BDRs are proposed, items are demoted from top-10, or new work is identified. Its purpose is visibility into tracked-but-not-active work, not a fixed bench. If F/W is empty *and* the other promotion sources are empty *and* the top-10 still has 10 items, the system is genuinely caught up — flag it as a finding rather than padding F/W with filler.
- **Each row is a single phase or actionable item**, not a whole multi-phase rollout. If Phase 1 of an ADR ships and Phase 2 isn't top-10-urgent, **drop the ADR off the list entirely** — phase tracking lives in [active-initiatives.md](active-initiatives.md), not here. Phase 2 can return to the list later if a forcing function fires.
- **Items can be** ADR acceptances, PDR acceptances, BDR acceptances, individual packets, multi-packet initiatives, or one-off operational/housekeeping work. The table is not ADR-only. See **Type Legend** below for the canonical list.
- **Phase** shows the specific phase or progress slice this row represents (e.g., `Phase 2 of 6`, `2/5 packets`, `0/9 standup ADRs`) or `n/a` for non-phased items. Full phase tracking is in [active-initiatives.md](active-initiatives.md); this cell is just a quick orientation hint.
- **Why now** must justify the rank — if it can't, the item probably isn't a top-10 priority.
- **Exit criteria** must be concrete and observable, not "feels done."
- **Blockers get promoted.** If item X is blocked by item Y and Y is itself actionable, **Y is its own row higher than X**, and X's "Blocked by" cell references Y by rank (e.g., `#2`). Non-actionable blockers (upstream CVEs, "no concrete trigger yet") stay in X's "Blocked by" cell only.
- Reviewed weekly at the ADR-0043 briefing; bump `Last reviewed` on every pass so stale-priority rot is visible.
- Per-initiative detail (packet checklists, board links, scope) lives in [active-initiatives.md](active-initiatives.md), not here.
