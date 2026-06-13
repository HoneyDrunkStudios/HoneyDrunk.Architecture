# Dispatch Plan — ADR-0074: Testing Library Stack

**Initiative:** `adr-0074-testing-stack`
**ADR:** ADR-0074 (Proposed → Accepted via packet 00)
**Sector:** Meta / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0074 is an **amendment / specification** ADR. It does not change the library picks committed by ADR-0047 D2 (xUnit + NSubstitute + AwesomeAssertions + coverlet); it promotes the picks' rationale (Moq's 2023 SponsorLink stewardship incident, FluentAssertions v8's October 2024 commercial relicensing, xUnit's `IClassFixture` model and parallel-test posture) from prose inside ADR-0047 into a standalone, frontmatter-citable decision. The picks themselves are unchanged.

This initiative is correspondingly small. It delivers: the ADR acceptance flip + the ADR-0047 amendment note + the ADR index row; the review-agent rubric citation update so the testing-quality category cites ADR-0074 alongside ADR-0047; the `HoneyDrunk.Standards` README + props-fragment header citation update so the standalone library-pick ADR is reachable from the consumption surface; and the operator-facing stewardship-event watch list in `business/context/` documenting the four ADR-0074 Follow-up Work items.

**4 packets across 2 waves**, targeting **2 repos** (`HoneyDrunk.Architecture` × 3, `HoneyDrunk.Standards` × 1). 4 `Actor=Agent`, 0 `Actor=Human`. No human prerequisites.

## Trigger

ADR-0074 is Proposed with no scope. The forcing functions (from the ADR's Context):

- The library-pick rationale has stewardship-and-licensing reasoning that deserves first-class citation. Burying it in ADR-0047 D2's prose under-cites it.
- Every new Node-standup ADR (ADR-0059, ADR-0060, ADR-0061, ADR-0071) cites the testing-library stack in `Directory.Build.props`; a canonical ADR is the right citation target.
- The .NET ecosystem's library trajectory continues to surface trust events; a standalone ADR creates the policy frame to evaluate the next event under, rather than re-litigating ad hoc.
- The `review` agent's testing-quality category per ADR-0044 D3 category 11 enforces the committed stack at PR time; pinning the libraries as a citable ADR makes the reviewer's check unambiguous.

## Scope Detection

**Multi-repo, narrow.** ADR-0074 touches `HoneyDrunk.Architecture` (acceptance, the ADR-0047 amendment note, the ADR index row, the review-agent rubric citation update, the stewardship watch list) and `HoneyDrunk.Standards` (the README and shared test-stack props fragment citation update — the package set is unchanged). No Node-runtime change, no contract change, no abstraction package version bump. The migration heavy lifting (FluentAssertions→AwesomeAssertions, Moq→NSubstitute) already lives in **ADR-0047's initiative** (packets 04 and 05) — this initiative does **not** repeat that work. ADR-0074 D6's opportunistic-migration discipline is the steady-state posture *after* the ADR-0047 campaign migrations complete.

## What this initiative deliberately does NOT do

- **Does not migrate code.** The campaign migrations are ADR-0047's packets 04 and 05. ADR-0074 D6 (opportunistic-migration discipline) is documented at acceptance and in the `HoneyDrunk.Standards` README citation update — but no new migration packets fan out here.
- **Does not add new invariants.** ADR-0074's Consequences/Invariants section says explicitly: *"If the scope agent judges any of these invariant-class at acceptance time, numbering is added then."* This scope agent's judgment is **no new invariant** — the rules ADR-0074 names (new tests use the canonical stack; no new Moq; no new FluentAssertions v8+; test-project naming per ADR-0047 D4) are already enforced by ADR-0047 invariants 50/51 and the review-agent rubric (ADR-0044 D3 category 11). Adding parallel invariant entries would duplicate enforcement without improving it.
- **Does not bump xUnit to v3.** ADR-0074 D1 commits v2.x today. The v3 migration is named in the watch list (packet 03) but its trigger has not fired.
- **Does not amend Node-standup ADRs (0059, 0060, 0061, 0071) to cite ADR-0074 directly.** Those ADRs are themselves Proposed and currently carry no ADR-0047 citation. They will cite ADR-0074 when each of *them* gets scoped and the scaffold packets are authored — the test-stack citation lives most naturally in each Node-standup's scaffolding packet, not in a fanned-out citation-update packet here. This is a deferred follow-up, not an obligation of this initiative.
- **Does not add `boundaries.md` "grandfathered per ADR-0074 D6" notes** to any Node repo. A workspace scan finds zero Grid Node repos currently carrying Moq or FluentAssertions `PackageReference` entries (ADR-0047 packets 04 / 05 are the campaign migrations; the only `FluentAssertions` hit anywhere is `TheHive/HoneyDrunk.Testing/`, a non-Grid external testing helper). The "grandfathered note" follow-up in ADR-0074's Follow-up Work is a no-op today — if a future Node-standup ADR opts to inherit existing FluentAssertions v7 / SponsorLink-free Moq usage (permitted per D6), the grandfather note lands in that Node-standup's packet, not here.

## Wave Diagram

### Wave 1 (governance — sequencing root)
- [ ] **00** — Architecture: Accept ADR-0074, add the ADR index row, append the `Amended by ADR-0074` section to ADR-0047, register the initiative. `Actor=Agent`. Blocked by: none.

### Wave 2 (citation surface updates — parallel; depend only on packet 00)
- [ ] **01** — Architecture: Cite ADR-0074 in the `.claude/agents/review.md` Testing Quality category (header + the Framework and package regressions subsection; add an xUnit-v3 flag-line). `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Standards: Cite ADR-0074 in `HoneyDrunk.Standards/README.md` and the shared test-stack props fragment header comment. `Actor=Agent`. Blocked by: 00.
- [ ] **03** — Architecture: Author the testing-stack stewardship-event watch list in `business/context/`. `Actor=Agent`. Blocked by: 00.

Wave 2's three packets are independent — packet 01 (review rubric), packet 02 (Standards docs/props), packet 03 (operator context) can land in parallel.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0074](./00-architecture-adr-0074-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [review.md ADR-0074 citation](./01-architecture-review-md-adr-0074-citation.md) | Architecture | Agent | 2 | 00 |
| 02 | [Standards README + props citation](./02-standards-readme-and-props-adr-0074-citation.md) | Standards | Agent | 2 | 00 |
| 03 | [Stewardship-event watch list](./03-architecture-testing-stack-stewardship-watchlist.md) | Architecture | Agent | 2 | 00 |

## Cross-Initiative Dependencies

**None.** ADR-0074 references ADR-0047 (which is already Accepted), ADR-0044 (Accepted), ADR-0011 (Proposed but not blocking — the amendment-precedent reference is a citation only), and the Node-standup ADRs (0059/0060/0061/0071 — currently Proposed but not blocking; no edge needed). No `Architecture#<n>` cross-initiative edges; no Human Prerequisites pointing at a cross-initiative artifact.

## Coordination with ADR-0047

ADR-0074 amends ADR-0047 D2 by promotion. The amendment is **additive** — ADR-0047's Status remains Accepted; the picks named in ADR-0047 D2 are unchanged; the migrations driven by ADR-0047's packets 04 and 05 continue under ADR-0047's authority. ADR-0074's value is two-fold:

1. **Citation surface.** Future Node-standup ADRs, the review-agent rubric, and `HoneyDrunk.Standards`'s test-stack documentation all gain a standalone-citable ADR for the library-pick rationale — they no longer have to point readers at ADR-0047 D2's prose to recover the SponsorLink / FluentAssertions-v8 reasoning.
2. **Policy frame for future events.** A standalone ADR creates the framework to evaluate the next .NET test-library stewardship event under, rather than re-relitigating from scratch. The watch list (packet 03) is the operator-readable surface where that framework lands.

ADR-0047's initiative continues to own the testing patterns (the four-tier pyramid, the per-tier coverage thresholds, the integration-tier split, the E2E framework choice, the canary patterns) and the campaign migrations. ADR-0074 owns the library-pick rationale + the migration discipline + the watch list. Both ADRs coexist and cite each other.

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/doc edits only (packets 00, 01, 03). No solution-version move.
- **`HoneyDrunk.Standards`** — packet 02 is a docs + header-comment change only. No `PackageReference` added/removed/version-shifted; per invariant 27 (test projects excluded from the solution version) and per invariant 12 (per-package CHANGELOG only for packages with actual changes), this work-item:
  - Updates repo-level `CHANGELOG.md` with a docs/chore line under the in-progress version.
  - Updates per-package CHANGELOG only if the shared props fragment ships inside a versioned package (per ADR-0047 packet 01's chosen mechanism). Otherwise no per-package CHANGELOG entry — no noise.
  - Does not move the solution version (no public-API change).

## Cross-Cutting Concerns

### Site sync

No site-sync flag. ADR-0074 is internal Meta infrastructure — no public-facing Studios website content changes. The library-pick rationale is operator-and-agent-facing, not customer-facing.

### Coordination with `hive-sync`

Packet 01 (review rubric citation update) touches `.claude/agents/review.md` — the same file `hive-sync`'s drift detector tracks per ADR-0044 packet 17. The change is a citation-only edit (no new category, no severity escalation, no rule text change) and should not register as a drift event in the detector's catalog ↔ agent-file reconciliation. If a false-positive drift fires after this packet lands, the fix is to refresh the drift baseline, not to revert the citation.

### Coordination with future Node-standup ADRs (ADR-0059, ADR-0060, ADR-0061, ADR-0071)

ADR-0074's Context names each of these as a citation consumer:

> Every new Node scaffold packet (HoneyDrunk.Identity per ADR-0060, HoneyDrunk.Files per ADR-0061, HoneyDrunk.Cache per ADR-0059, HoneyDrunk.Web.UI per ADR-0071) cites the testing-library stack in its `Directory.Build.props`. A canonical ADR is the right citation target.

These ADRs are themselves Proposed and not yet scoped. When each gets scoped, its scaffolding packet should cite **ADR-0074** (not ADR-0047) for the test-library stack — the citation point lives most naturally in each Node-standup's scaffold packet, where the consuming `Directory.Build.props` lands, rather than as a fanned-out citation-update packet here. This is a **deferred follow-up handled by each Node-standup's own scope**, not an obligation of this initiative.

### Coordination with ADR-0047 packets 04 / 05 (campaign migrations)

ADR-0047 packets 04 (FluentAssertions→AwesomeAssertions) and 05 (Moq→NSubstitute) are the **campaign-style** migrations across every Node repo. ADR-0074 D6 establishes the **opportunistic-migration** posture for everything outside those campaign packets. The two postures co-exist cleanly:

- Inside ADR-0047 packets 04 / 05: campaign migration. Every Node repo with FluentAssertions or Moq usage gets a per-repo issue at filing time.
- Outside packets 04 / 05 (now, going forward): opportunistic. New tests use the canonical stack; existing usage migrates when a file is touched for other reasons.

ADR-0074's acceptance does not change ADR-0047's campaign packets' execution.

## Rollback Plan

- **Packet 00 (acceptance).** Revert the PR. ADR-0074 returns to Proposed; the `Amended by ADR-0074` section is removed from ADR-0047; the ADR-0074 row is removed from `adrs/README.md`; the initiative entry in `active-initiatives.md` is removed. No runtime impact. No invariant impact (this packet committed no new invariants). The remaining packets 01–03 should not be filed if this packet is reverted (they cite an Accepted ADR-0074); if they have already landed they should also be reverted to avoid dangling citations.
- **Packet 01 (review.md citation).** Revert the PR. The Testing Quality category reverts to citing only ADR-0047; the SponsorLink / FluentAssertions-v8 navigation gain is lost; the xUnit-v3 flag-line is removed. No rule change reverts (only citation reverts).
- **Packet 02 (Standards README + props).** Revert the PR. The README and props-fragment header revert to citing only ADR-0047. No `PackageReference` move; no version bump; consumers unaffected.
- **Packet 03 (stewardship watch list).** Revert the PR. The operator note disappears; the operator's recovery path for the next stewardship event reverts to re-deriving the rationale from scratch (the cost ADR-0074 was specifically designed to avoid).
- **Initiative-level escape hatch.** If ADR-0074 is judged a poor abstraction (e.g. the standalone-citation gain doesn't justify the ADR's existence), revert all four packets and supersede ADR-0074 with a new ADR explaining the reversal. ADR-0047 D2 then remains the sole home of the library-pick rationale — the substrate is recoverable.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

No cross-initiative `{Repo}#N` placeholders to substitute — all dependencies are intra-folder `work-item:NN` edges. The folder is safe to push to `main` as-is.
