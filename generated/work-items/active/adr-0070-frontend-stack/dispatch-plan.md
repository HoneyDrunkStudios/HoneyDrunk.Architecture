# Dispatch Plan — ADR-0070: Frontend Platform Stack

**Initiative:** `adr-0070-frontend-stack`
**ADR:** ADR-0070 (Proposed → Accepted via packet 00)
**Sector:** Creator / cross-cutting (Meta from a governance lens; touches every consumer-facing surface)
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0070 commits the Grid to three frontend toolchains: **React + TypeScript** for consumer-facing web (Vite default, Next.js when SSR/SSG justifies), **Blazor** for admin surfaces that meet D2's "simple enough" test (~15 views, ~30 components, CRUD-shaped, internal/operator-facing), and **React Native + Expo** for mobile (one codebase for iOS and Android). D4 acknowledges and accepts the three-toolchain DX tax. D5 routes cross-stack design assets through ADR-0071's paired Web.UI Node. D6 explicitly defers DX-baseline `make` semantics, mobile E2E tool selection, state-management library choice, build-tool choice within React, native-feature escape hatches, designer tooling, and frontend-side i18n.

The ADR is **policy-only** — it commits boundaries, not code. Concrete code (Web.UI's tokens/CSS/component packages, the Notify Cloud Blazor admin, per-PDR scaffolding) lands in the **paired ADR-0071 initiative** and in **per-PDR scaffolding packets** that cite ADR-0070's stack constraints. This initiative ships only the policy substrate.

This initiative delivers: ADR acceptance (no numbered invariants — the four stack rules are scoping conventions per the ADR's explicit instruction); the scope-agent quality-checklist update so future packets are checked against ADR-0070 at packet-authoring time; the review-agent rubric update so PRs are checked at review time; the charter-aware draft sync so cluster 7.7 (mobile platform direction) reads RESOLVED and cluster 4.1 (DX-baseline) reads with the expanded per-stack scope; and the operator-judgment packet that surfaces the conflict between ADR-0070 D3 and PDR-0005 / PDR-0008's native-Swift+Kotlin commitments.

**6 packets across 3 waves**, all targeting **`HoneyDrunk.Architecture`**. 5 `Actor=Agent`, 1 `Actor=Human` (packet 04 — the consumer-PDR reconciliation requires operator architectural judgment). Packet 05 is a Wave 3 mini-check that re-counts the Notify Cloud admin surface against ADR-0070 D2's "simple enough" thresholds and either confirms the assertion or surfaces the divergence.

## Trigger

ADR-0070 is Proposed with no scope. Forcing functions (from the ADR's Context):

- The Hearth and Lately PDRs are next-build candidates; the signup flow needs a frontend the day it lands.
- Notify Cloud admin UI is imminent (PDR-0002 GA scope).
- The paired Web.UI Node (ADR-0071) has no target stack to ship components against without ADR-0070's commitment.
- AI-multiplier-bet stack selection: React+TS, .NET, native are the three gradients with meaningful AI-assistance leverage; alternatives outside that gradient (Flutter, Elm, Vue/Svelte/Solid) deliver less per token of agent attention.

## Scope Detection

**Single-repo, multi-concern.** Every packet targets `HoneyDrunk.Architecture` — the ADR, the agent definitions, the charter-aware draft, the PDRs. No other repo is touched. This initiative is a clean single-repo policy roll.

Per-PDR scaffolding packets that consume ADR-0070's stack constraints (the Hearth scaffold, the Lately scaffold, the Curiosities scaffold, the Notify Cloud admin Blazor scaffold) are **separate downstream initiatives**, not part of this folder. ADR-0070's role is to bind the policy; consumer adoption happens per-PDR.

## Wave Diagram

### Wave 1 (No dependencies — governance)

- [ ] **00** — Architecture: Accept ADR-0070, register the initiative. No invariants added (per ADR-0070's explicit "scoping conventions, not numbered invariants" instruction). `Actor=Agent`.

### Wave 2 (Depends on Wave 1 — policy binding, parallel)

- [ ] **01** — Architecture: Add the frontend-stack-compliance check to `.claude/agents/scope.md` (Quality Checklist + Self-Containment Rule). `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: Add the frontend-stack-compliance check to `.claude/agents/review.md` (Architectural integrity rubric). `Actor=Agent`. Blocked by: 00.
- [ ] **03** — Architecture: Update `generated/adr-drafts/2026-05-23-charter-aware-adr-and-node-candidates.md` to mark cluster 7.7 RESOLVED, annotate cluster 7.8 (paired with ADR-0070/0071), and expand cluster 4.1's DX-baseline scope to a per-stack matrix. `Actor=Agent`. Blocked by: 00.

### Wave 3 (Depends on Wave 1 — operator decision + threshold re-check)

- [ ] **04** — Architecture: Reconcile PDR-0003/0005/0006/0008 with ADR-0070 D3. PDR-0003 (Lately) aligns; PDR-0006 (Currents) inherits; **PDR-0005 (Hearth) and PDR-0008 (Curiosities, via PDR-0004) conflict** — both commit to native Swift+Kotlin, which ADR-0070 D3 rejects. `Actor=Human` — the operator picks Path A (carve out an exception in ADR-0070), Path B (amend the PDRs), or Path C (annotate the exception without amending the ADR). Blocked by: 00.
- [ ] **05** — Architecture: Re-check the Notify Cloud admin surface against ADR-0070 D2's "simple enough" thresholds (~15 views, ~30 interactive components). The ADR cites Notify Cloud as the in-policy Blazor example without a measured count. If the count is comfortably within D2, close the packet. If borderline or over, file an `Actor=Human` follow-up packet for amend-D2 / switch-to-React / per-surface-exception. `Actor=Agent`. Blocked by: 00.

Packets within a wave run in parallel. Wave 3 (packets 04 and 05) is not gated on Wave 2 — both depend only on packet 00. Packet 04 is grouped into Wave 3 because its closure depends on a human action that may take days to weeks; packet 05 is grouped into Wave 3 because its disposition may trigger an `Actor=Human` follow-up (the count-itself is agent work, but a borderline-or-over outcome triggers an operator step). Packets 01, 02, 03 can land before either Wave 3 packet is resolved; the agent enforcement surfaces are valuable even while the conflicts are being adjudicated, because they catch *future* out-of-policy authoring while the existing conflicts are being processed.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0070](./00-architecture-adr-0070-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [scope.md frontend-stack check](./01-architecture-scope-agent-stack-checklist.md) | Architecture | Agent | 2 | 00 |
| 02 | [review.md frontend-stack rubric](./02-architecture-review-agent-stack-rubric.md) | Architecture | Agent | 2 | 00 |
| 03 | [Charter-aware draft sync](./03-architecture-charter-aware-draft-sync.md) | Architecture | Agent | 2 | 00 |
| 04 | [Consumer-PDR stack reconciliation (`Actor=Human`)](./04-architecture-consumer-pdr-stack-reconciliation.md) | Architecture | Human | 3 | 00 |
| 05 | [Notify Cloud admin D2 re-count](./05-architecture-notify-cloud-admin-d2-recount.md) | Architecture | Agent | 3 | 00 |

## ADR-0071 Pairing

ADR-0070 and ADR-0071 are explicitly paired. ADR-0071's acceptance checklist includes:

> Confirm the paired ADR-0070 is Accepted (Web.UI's stack constraints derive from there)

Packet 00 of this initiative unblocks ADR-0071's acceptance. The ADR-0071 Web.UI standup initiative is **separately filed** — it does not live in this folder. The two initiatives are sequential: ADR-0070 Accepted first (this initiative), then ADR-0071 Accepted (separate initiative), then the Web.UI Node scaffold packet.

The dependency direction is one-way: ADR-0071 depends on ADR-0070's acceptance. ADR-0070 does not depend on ADR-0071 — ADR-0070 is the policy ADR; ADR-0071 is the implementation Node for the cross-stack design system D5 names.

**Soft cross-initiative dependency (recorded for transparency, not encoded in `dependencies:` frontmatter):** ADR-0071's acceptance gates on packet 00 of *this* initiative landing on `main`. The ADR-0071 initiative's own packets reference this gate in their bodies — no `dependencies:` array entry crosses initiative folders (per the "No cross-initiative placeholders" rule under Filing below). If ADR-0071's acceptance packet is in flight when packet 00 here merges, the ADR-0071 packet may proceed; if ADR-0071's packet is in flight before packet 00 here lands, the operator holds the merge until this initiative's packet 00 is on `main`.

## What This Initiative Does NOT Deliver

- **The Web.UI Node scaffold.** ADR-0071's separately-filed initiative ships the tokens + CSS + first React component pack. Not in this folder.
- **The Notify Cloud admin Blazor scaffold.** The Notify Cloud scaffold packet (already part of `adr-0027-notify-cloud-standup`, packet 06) already specifies Blazor Server per ADR-0027 D3 — which aligns with ADR-0070 D2. No edit to that packet is needed; ADR-0070 ratifies the existing choice.
- **Per-PDR consumer-app scaffolding.** Each consumer PDR (Hearth, Lately, Currents, Curiosities) gets its own scaffolding initiative. Those packets cite ADR-0070's stack constraints; the citations are enforced by the scope-agent check this initiative's packet 01 installs.
- **The DX-baseline ADR.** The charter-aware draft cluster 4.1 names this as a future ADR with per-stack `make` semantics. ADR-0070 expands its scope (per-stack matrix); the ADR itself is filed separately.
- **The mobile-E2E ADR.** ADR-0047 named mobile E2E as an unresolved gap; ADR-0070 D6 pins RN+Expo as the platform but defers the testing-tool choice. Maestro is the strong default; commitment lives in the mobile-E2E ADR named in ADR-0047.
- **Per-PDR mobile build pipeline configuration.** Expo EAS Build configuration lands when the first mobile PDR enters scaffolding — per-PDR, not in this initiative.
- **Catalog updates.** `catalogs/*.json` has no schema slot for "default frontend stack." Per-Node `stack` fields on `catalogs/nodes.json` continue to track at the existing per-row granularity. No edit here.
- **Numbered invariants in `constitution/invariants.md`.** Per ADR-0070's explicit instruction, the four stack rules are scoping conventions, not numbered invariants. Packet 00's acceptance criteria positively check that `constitution/invariants.md` is not edited.

## Notes

- **Initiative slug length:** `adr-0070-frontend-stack` is 23 characters, comfortably under the 39-char limit for `initiative:` frontmatter and the 50-char limit for the derived `initiative-<slug>` GitHub label.
- **Status flip.** ADR-0070 stays Proposed for the duration of scoping. Packet 00 flips Status → Accepted. No other packet flips the ADR.
- **PDR conflict (packet 04).** Two consumer PDRs (PDR-0005 Hearth, PDR-0008 Curiosities via PDR-0004) commit to native Swift+Kotlin and explicitly reject RN. ADR-0070 D3 commits the opposite. The conflict is real and surfaces an architectural-judgment decision the operator must make. Packet 04 is `Actor=Human` for this reason. The follow-up execution packet (whichever path the operator picks) is `Actor=Agent` and is separately filed.
- **Notify Cloud admin Blazor alignment is presumed correct, verified by packet 05.** Per ADR-0027 packet 06 (the Notify Cloud scaffold), the admin UI uses Blazor Server. ADR-0070 D2's "first concrete Blazor consumer is Notify Cloud" assertion is asserted-not-measured; packet 05 re-counts the surface against the ~15/~30 thresholds. If comfortably within, no reconciliation is needed. If borderline or over, packet 05 triggers an `Actor=Human` follow-up to either amend D2, switch Notify Cloud to React, or annotate a per-surface exception.
- **Studios is already correct.** `repos/HoneyDrunk.Studios/overview.md` already references ADR-0070 and ADR-0071 in its Stack rationale and Relationship to Web.UI sections. No reconciliation packet needed.
- **AI-assistance gradient.** ADR-0070's reasoning leans heavily on the AI-multiplier bet (per-token-of-agent-attention productivity). The scope-agent check (packet 01) and review-agent rubric (packet 02) encode this reasoning so future stack-selection ADRs (e.g., the Svelte/Solid/Qwik question if it returns in 2028) are checked against the gradient.

## Rollback Plan

- **Packet 00 (acceptance):** revert the PR. ADR-0070 returns to Proposed. No runtime impact; downstream packets in this initiative cannot land until 00 re-lands. The paired ADR-0071's acceptance also rolls back (its checklist gate re-engages).
- **Packets 01–02 (agent rubric updates):** revert the PR. Future packets and PRs are no longer checked against the ADR-0070 policy at packet-authoring / PR time. The ADR is still accepted (packet 00 stands); only the enforcement surface is removed. Acceptable as a temporary state if the rubric language needs revision.
- **Packet 03 (charter-aware draft sync):** revert the PR. The draft re-reads as if the mobile-platform question were unresolved. Pure docs revert; no runtime impact.
- **Packet 04 (operator-decision packet):** there is nothing to revert at packet 04's own closure — the packet itself produces no edits. The follow-up execution packet (whichever path the operator picked) reverts as a separate PR if needed.
- **Packet 05 (Notify Cloud D2 re-count):** there is nothing to revert at packet 05's own closure — the packet records a count. If it triggered a follow-up `Actor=Human` packet, that follow-up reverts as a separate PR if needed.
- **Backend-level rollback:** ADR-0070's "If MAUI's 2027–2028 trajectory closes the gap meaningfully (Microsoft has invested significantly), this ADR is revisable" language and the equivalent Flutter / Svelte / Solid revisitation clauses are the architectural rollback paths for the *policy itself*. Each is a future-ADR amendment, not a revert.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo` (`HoneyDrunkStudios/HoneyDrunk.Architecture` for all 6), adds it to The Hive (project #4), sets the board fields from frontmatter (including `Actor=Human` for packet 04 via the `human-only` label), and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

**No cross-initiative placeholders.** All `dependencies:` entries are `work-item:NN` (same-folder) — none reference other initiatives or pre-filed issues. Safe to push as a single batch.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board, the entire `active/adr-0070-frontend-stack/` folder moves to `archive/adr-0070-frontend-stack/` in a single commit. Partial archival is forbidden.

The `hive-sync` agent moves individual closed packet files from `active/` to `completed/` per invariant 37 — that is per-packet lifecycle. Initiative-level archival is the post-completion sweep after the whole folder reaches `Done`. Packet 04's `Actor=Human` closure happens at operator decision; the follow-up execution packet (separately filed) is not part of this initiative folder's archival.
