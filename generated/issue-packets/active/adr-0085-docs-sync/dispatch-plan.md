# Dispatch Plan: Grid-Wide Documentation Currency Agent (ADR-0085)

**Date:** 2026-05-26 (initial scope).
**Trigger:** ADR-0085 (Grid-Wide Documentation Currency Agent `docs-sync`) — Proposed 2026-05-26; scoped same day per user request for decomposition into actionable packets.
**Type:** Multi-phase single-repo initiative. Every packet targets `HoneyDrunk.Architecture`. Cross-repo *write* authority is the subject of Phases 2–5; the artifacts that grant and bound that authority all live in Architecture (the agent file, capability matrix, OpenClaw schedule, dispatch report directory, optional invariants).
**Sector:** Meta (governance + agent definitions).
**Status:** **Draft — pending ADR-0085 acceptance.** These packets live under `generated/issue-packets/proposed/adr-0085-docs-sync/` per ADR-0043 D3 (the `proposed/` landing zone — agents never self-promote to `active/`). The packets are not filed as GitHub Issues until a human triages this initiative into `active/` (per ADR-0043 D5 weekly briefing) and packet 01's PR merges to flip ADR-0085 to Accepted.
**Site sync required:** No. `docs-sync` produces per-repo Markdown reconciliation and a per-run report in the Architecture repo; nothing public-facing on the Studios site today.
**Rollback plan:** Every packet is docs/governance/agent-definition only (no .NET project, no runtime code, no public API change). Each reverts cleanly via `git revert`. The phased rollout (D8) is itself the blast-radius control — Phase 1 ships report-only authority (no write surface in other repos), and each subsequent phase widens authority by one bounded category. The per-repo kill switch is the OpenClaw schedule itself: pausing the schedule (or skipping the agent's scheduled run) immediately silences the reconciler with zero per-repo configuration.

## Summary

ADR-0085 commits a **scheduled, full-sweep, write-authorized central agent (`docs-sync`)** that detects documentation drift Grid-wide and reconciles it via per-repo PRs. It composes with the `proposed/` packet pipeline (editorial findings fall back into `proposed/`) and extends the "central agent writes directly to its target repo" pattern already established by `hive-sync` (Architecture-only) and `site-sync` (Studios website).

This initiative ships **eight packets across six waves** mapped 1:1 to ADR-0085 D8's six phases, with the Phase-1 GitHub-App work split into two packets: `01a` — portal-only App + KV + secrets + RBAC provisioning (`Actor=Human`, no commits) — and `01b` — walkthrough doc authored against the IDs/names 01a captures (`Actor=Agent`). The split honors the rule that human portal work and agent doc work belong in separate Actor=… packets.

## Phase ↔ Wave mapping

ADR-0085 D8's six phases map directly to six waves. Each phase is a **discrete observe-before-broaden gate** — Phase 1's exit criterion ("OpenClaw can invoke the agent, the App token mints correctly, the report format is useful, the false-positive rate on accuracy checks is acceptable") gates Phase 2's PR-authority grant; missing it stops the rollout.

## Wave Diagram

### Wave 1 — Phase 1: Agent definition, matrix wiring, report-only mode

Packet 01 first (the acceptance flip + agent definition + capability matrix + report directory + OpenClaw schedule). Packet 01a (`Actor=Human` portal work) runs in parallel with 01 because its only soft dependency on 01 is the ADR-accepted state; the App provisioning is portal-only and does not need any committed code from 01 to start. Packet 01b (`Actor=Agent` walkthrough doc) follows 01a once 01a's hand-off note is captured.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0085**, author `.claude/agents/docs-sync.md`, add capability-matrix row, seed `generated/docs-sync-reports/`, register OpenClaw Friday scheduled trigger — [`01-architecture-adr-0085-acceptance-and-agent-definition.md`](01-architecture-adr-0085-acceptance-and-agent-definition.md)
- [ ] `HoneyDrunk.Architecture` (`Actor=Human`, portal-only, no commits): Register `docs-sync` GitHub App on the org, store private key + App ID + installation ID in `kv-hd-docs-sync-prod`, wire RBAC + diagnostics + rotation, capture the hand-off note — [`01a-architecture-docs-sync-github-app-registration.md`](01a-architecture-docs-sync-github-app-registration.md)
  - Blocked by: `packet:01` (soft — ADR accepted, agent definition lives in repo before its credentials are wired).
- [ ] `HoneyDrunk.Architecture` (`Actor=Agent`): Author `infrastructure/walkthroughs/docs-sync-github-app-registration.md` documenting the App + Vault + secrets + RBAC + rotation disposition packet 01a performed, against the concrete values captured in 01a's hand-off note — [`01b-architecture-docs-sync-github-app-walkthrough-doc.md`](01b-architecture-docs-sync-github-app-walkthrough-doc.md)
  - Blocked by: `packet:01` (hard — agent definition + capability-matrix row exist before the walkthrough cross-links them), `packet:01a` (hard — hand-off note must be available).

**Wave 1 exit criterion (Phase 1 go/no-go):** OpenClaw can invoke `docs-sync` on the Friday slot, the App installation token mints correctly when manually exercised, the agent produces a useful per-run report at `generated/docs-sync-reports/{YYYY-MM-DD}.md` covering D3 categories 1, 2, 3, 4 (existence + version drift + symbol drift + catalog reference drift) for every in-scope repo, and the false-positive rate on the accuracy checks is acceptable to the operator. **If this bar is missed, Wave 2 does not start.**

### Wave 2 — Phase 2: Cross-repo PR authority enabled for mechanical fixes (version drift only)

Runs after the Phase-1 go decision. Packet 02.

- [ ] `HoneyDrunk.Architecture`: Grant `docs-sync` cross-repo PR authority, auto-fix scoped to version drift (D3 #2) only — [`02-architecture-docs-sync-phase-2-version-drift-auto-pr.md`](02-architecture-docs-sync-phase-2-version-drift-auto-pr.md)
  - Blocked by: `packet:01` (**hard** — agent definition + report directory must exist), `packet:01a` (**hard** — App must mint installation tokens so the agent can `gh pr create` against target repos), `packet:01b` (**hard** — walkthrough doc cross-referenced from packet 02's body must exist).

**Wave 2 exit criterion (Phase 2 go/no-go):** `pr-core` PR-metadata gates pass on every docs-sync PR (`Authorship: agent-claude-code` + `Out-of-band reason:` pointing at the report path), the `chore/docs-sync-{YYYY-MM-DD}` branch-naming convention works (including the reuse-an-open-branch rule from D7), idempotency holds across two consecutive weekly runs, and the operator's PR-review workload is acceptable.

### Wave 3 — Phase 3: Broaden auto-fix to catalog references and dead links

Runs after the Phase-2 go decision. Packet 03.

- [ ] `HoneyDrunk.Architecture`: Expand `docs-sync` auto-fix scope to catalog-reference drift (D3 #4) and dead intra-repo Markdown links — [`03-architecture-docs-sync-phase-3-catalog-and-dead-links.md`](03-architecture-docs-sync-phase-3-catalog-and-dead-links.md)
  - Blocked by: `packet:02` (**hard** — Phase-2 PR pipeline observed working before scope expands).

**Wave 3 exit criterion (Phase 3 go/no-go):** Catalog-reference rewrites (e.g., `HoneyDrunk.Old` → `HoneyDrunk.New`) and dead intra-repo Markdown link rewrites land cleanly with zero false-positive regressions over four weekly runs; categories 3, 5, and 6 remain report-only.

### Wave 4 — Phase 4: Add dependency-graph and agent-instruction drift detection

Runs after the Phase-3 go decision. Packet 04.

- [ ] `HoneyDrunk.Architecture`: Add dependency-graph drift (D3 #5) and agent-instruction drift (D3 #6) detection — report-only + fallback `proposed/` packet path — [`04-architecture-docs-sync-phase-4-dependency-and-agent-drift-detection.md`](04-architecture-docs-sync-phase-4-dependency-and-agent-drift-detection.md)
  - Blocked by: `packet:03` (**hard** — Phase-3 catalog-reference rewrites observed working; Phase 4 categories share the catalog-driven reasoning).

**Wave 4 exit criterion (Phase 4 go/no-go):** Categories 5 and 6 emit findings into the run report at an acceptable false-positive rate; fallback `proposed/` packets for editorial findings dedup correctly per D7; the report is the validation surface before any auto-fix authority is considered for these categories.

### Wave 5 — Phase 5: Skeleton README generation for missing-required-artifact `block` findings

Runs after the Phase-4 go decision. Packet 05. This is the highest-judgment auto-fix category; it lands last so the operator has trust calibration from Phases 2–3.

- [ ] `HoneyDrunk.Architecture`: Enable skeleton README auto-generation for repos with `*.csproj` projects missing a root `README.md` — [`05-architecture-docs-sync-phase-5-skeleton-readme-generation.md`](05-architecture-docs-sync-phase-5-skeleton-readme-generation.md)
  - Blocked by: `packet:04` (**hard** — Phase-4 observation completes before highest-judgment auto-fix lands).

**Wave 5 exit criterion (Phase 5 go/no-go):** Generated skeletons carry the `<!-- docs-sync generated skeleton; please review -->` marker, are gated on file non-existence (idempotent), and humans accept or modify them rather than discarding them wholesale.

### Wave 6 — Phase 6: Cadence finalization + invariant decision + Authorship-enum revisit

Runs after the Phase-5 go decision, no earlier than 90 days after Phase 1 went live (so the cadence observation has enough data). Packet 06.

- [ ] `HoneyDrunk.Architecture`: Finalize Friday cadence + decide D9 invariants A/B/C + decide whether to add `agent-docs-sync` to `pr-core.yml` Authorship enum — [`06-architecture-docs-sync-phase-6-cadence-and-invariants.md`](06-architecture-docs-sync-phase-6-cadence-and-invariants.md)
  - Blocked by: `packet:05` (**hard** — all five auto-fix phases observed before final cadence + invariant decisions).

**Wave 6 exit criterion (Phase 6 go/no-go):** Friday cadence confirmed (or adjusted with rationale); D9 candidates A/B/C decided (each individually accepted or rejected with rationale); Authorship-enum decision recorded (status-quo `agent-claude-code` + OOB-reason kept, or follow-up packet against `HoneyDrunk.Actions` filed to add `agent-docs-sync`). Initiative reaches `Done`; all packets archive per ADR-0008 D10.

## Operational Risks

The phased rollout (D8) bounds the worst case, but several operational risks are non-zero and worth naming explicitly:

- **PR queue saturation in Phase 2+.** Once the agent gains cross-repo PR authority (Phase 2 onward), every weekly run that finds version drift opens one PR per affected repo. Across 20+ Grid repos, a "stale weekend" could produce a wave of PRs that overwhelms the operator's PR-review queue. Mitigations: the agent reuses the open weekly branch per D7's branch-reuse rule (so a stale repo doesn't accumulate parallel PRs week over week); the three-consecutive-failures backoff (D7) stops auto-pushing to stuck PRs and converts them to `proposed/` packets for triage; the operator can pause the OpenClaw schedule for one week at any time.
- **Branch-name collision risk.** The agent's `chore/docs-sync-{YYYY-MM-DD}` branch convention could collide with an operator-authored branch using a coincidentally identical name (unlikely but non-zero). The agent's branch-reuse logic will treat a coincidentally-named branch as "the prior week's docs-sync PR" and try to push to it. Mitigation: the agent should verify the branch was created by the docs-sync identity (App-bound author) before reusing; if author doesn't match, open a fresh branch with a `-{N}` suffix.
- **Three-strike-blast-radius gap.** The three-consecutive-failed-runs backoff (D7) kicks in only after the third failure. The first three weekly runs against a broken target repo each open a PR; if `pr-core` fails on all three, the operator has three PR-review interruptions before the backoff silences the agent. This is a deliberate trade-off (the alternative — stop after one failure — risks silencing the agent prematurely on transient failures), but the non-zero blast radius is worth naming.
- **Phase-6 cadence-change risk.** The Phase-6 cadence-finalization packet (06) can change the weekly cadence based on 90-day observation. If the new cadence is daily or more frequent, the PR-queue-saturation risk grows linearly. Mitigations: Phase 6 records the rationale for any cadence change; the operator retains the OpenClaw-pause kill-switch.

## Out-of-scope items from ADR-0085

- **Compiling/executing fenced code snippets in READMEs** — explicitly deferred per D2 scope carve-out (future ADR; requires a compiler/shell/HTTP execution surface the agent does not own at v1).
- **Prose-quality / grammar / style** (Vale-class) — orthogonal; no packet here.
- **In-product OpenAPI rendering** — ADR-0075 D1 (Scalar); not docs-sync's surface.
- **Per-Node Docusaurus sites** — ADR-0075 D2; not docs-sync's surface.
- **Studios marketing site** — `site-sync` agent's surface per ADR-0075 D3.
- **Architecture repo's internal tracking files** (`initiatives/`, `catalogs/`, board reconciliation) — `hive-sync`'s surface per ADR-0014.
- **XML doc comments on public APIs** — Invariant 13, enforced by `HoneyDrunk.Standards` analyzers at build time.
- **Event-driven supplemental runs** on ADR acceptance — deferred per ADR-0085 D6 (the weekly full sweep covers within 7 days; event-driven is a future strict superset).
- **No `HoneyDrunk.Actions` change at v1** — Affected Nodes section of ADR-0085 explicitly defers any `pr-core.yml` Authorship-enum change to Phase 6.

## After filing — board fields and blocking relationships

Once a human triages this initiative into `active/` and the packets are filed:

- For each issue: `gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>`, then set Status, Wave (1–6), Initiative=`adr-0085-docs-sync`, Node=`honeydrunk-architecture`, Tier, Actor. **Actor=Human** for packet 01a only (it carries the `human-only` label — entire work item is portal-only provisioning); every other packet (including the new 01b) is `Actor=Agent`.
- Blocking relationships are wired from the `dependencies:` frontmatter of each packet via `addBlockedBy` (the filing pipeline handles this automatically). The chain:
  - `01a` ← `01` (soft)
  - `01b` ← `01` (hard), `01b` ← `01a` (hard)
  - `02`  ← `01` (hard), `02` ← `01a` (hard), `02` ← `01b` (hard)
  - `03`  ← `02` (hard)
  - `04`  ← `03` (hard)
  - `05`  ← `04` (hard)
  - `06`  ← `05` (hard)

## Notes

- **`proposed/` landing zone (ADR-0043 D3).** This initiative folder lives under `generated/issue-packets/proposed/adr-0085-docs-sync/`. A human triages it into `active/` at the next weekly briefing (ADR-0043 D5) — agents do not self-promote.
- **Acceptance precedes flip.** ADR-0085 stays Proposed until packet 01's PR merges. Packet 01 carries the `accepts: ["ADR-0085"]` field that triggers `hive-sync`'s ADR auto-flip per ADR-0014 D7 (Step 9) once all the initiative's packets reach `Done`.
- **One PR per repo per initiative discipline.** Every packet in this initiative produces a PR against `HoneyDrunk.Architecture`. The "one PR per repo per initiative" convention from operator memory is respected by virtue of every packet shipping its own focused PR with a single concern; there are no cross-repo packets in this initiative (the *agent* opens cross-repo PRs at runtime per its own initiative — that is a separate concern from the initiative shipping the agent).
- **PR metadata for every packet's implementation PR:** `Authorship: agent-claude-code` (per ADR-0044 D6 — Claude Code is the execution surface) + `Packet: HoneyDrunkStudios/HoneyDrunk.Architecture#<issue-number>` once filed. No `Out-of-band reason:` since each PR is packet-linked.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7 / invariant 25). It is updated at wave boundaries (especially after each phase's go/no-go) as the historical record.

## Archival

Per ADR-0008 D10, when every packet reaches `Done` on The Hive and all six phase exit criteria are met, the entire `active/adr-0085-docs-sync/` folder moves to `completed/adr-0085-docs-sync/` in a single commit (via `hive-sync`'s packet-lifecycle move per invariant 37). Polish-phase follow-up packets, when scoped (e.g., event-driven supplemental runs, code-example correctness, Authorship-enum addition), live in new initiative folders — not appended here.
