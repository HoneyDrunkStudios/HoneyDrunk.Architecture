# Dispatch Plan: Cloud Code Review (ADR-0044)

**Date:** 2026-05-22 (initial scope).
**Trigger:** ADR-0044 (Grid-Aware Cloud Code Review and AI-Authored PR Discipline) — Proposed 2026-05-21; scoped 2026-05-22 ahead of formal acceptance (priority #3 on `current-focus.md`).
**Type:** Multi-repo (HoneyDrunk.Architecture + HoneyDrunk.Actions + the 10 remaining live .NET Nodes via packet 11's fan-out).
**Sector:** Meta (governance + agent definitions) + Ops (CI workflows in HoneyDrunk.Actions).
**Status:** **Draft — pending ADR-0044 acceptance.** These packets are NOT to be filed as GitHub Issues until ADR-0044 is Accepted (packet 01 is the mechanically-coupled acceptance flip). Filing is the `file-issues` agent's job, post-acceptance.
**Site sync required:** No. ADR-0044 produces CI tooling and governance docs; nothing public-facing on the Studios site today.
**Rollback plan:** Every Architecture-repo packet (01, 02, 04, 05, 06, 09, 10, 12, 13, 15, 17) is docs/catalog/YAML and reverts cleanly via `git revert`. The Actions-repo workflow packets (03, 07, 08, 14, 16) are additive — `job-review-agent.yml`, `job-audit-sample.yml`, and the new `pr-core.yml` jobs are reverted by removing them. Packet 11 (the 10-Node cross-repo fan-out) reverts per repo: setting a Node's `.honeydrunk-review.yaml` to `enabled: false` (or removing it) makes the reviewer go silent on that repo immediately — the enabled gate is the per-repo kill switch. The phased rollout (D11) is itself the blast-radius control — each phase is a discrete go/no-go.

## Summary

ADR-0044 fills an empty slot: "automatic Grid-aware LLM reviewer." It cloud-wires the existing local `review` agent (`.claude/agents/review.md`) into a GitHub Action, adds AI-authored PR discipline (authorship classification, PR-size caps, multi-perspective review for high-risk Nodes, post-merge sampling audit), and binds a twenty-category review rubric as the Grid's shared authoring + review standard. It amends ADR-0011 (reverses the local-only posture, renders the CodeRabbit rejection moot).

This initiative ships **seventeen packets across four waves** mapped 1:1 to ADR-0044 D11's four phases. Packets 01 and 02 were authored in a prior scope pass; packets 03-17 are added here.

## Phase ↔ Wave mapping

ADR-0044 D11's four phases map directly to the four waves. Each phase is a **discrete go/no-go** — Phase 1's exit criterion ("cloud verdicts at least as useful as the local agent's, at acceptable cost") gates Phase 2; missing it stops the rollout.

## Wave Diagram

### Wave 1 — Phase 1: MVP on the Architecture pilot repo

Packet 01 first (the acceptance flip). Then 02-05 in parallel; 06 after 03/04/05.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0044** — flip status, finalize the two new invariants, ADR-0011 amendment note, register the initiative — [`01-architecture-adr-0044-acceptance.md`](01-architecture-adr-0044-acceptance.md)
- [ ] `HoneyDrunk.Architecture`: **[Actor=Human]** Create the cross-repo-checkout GitHub App + provision the Anthropic API key in Vault — [`02-architecture-create-review-agent-github-app.md`](02-architecture-create-review-agent-github-app.md)
  - Blocked by: `packet:01` (soft).
- [ ] `HoneyDrunk.Actions`: Build `job-review-agent.yml` — the cloud-wired Grid-aware reviewer (D1/D2/D4/D5) — [`03-actions-job-review-agent-workflow.md`](03-actions-job-review-agent-workflow.md)
  - Blocked by: `packet:01` (soft), `packet:02` (**hard** — credentials).
- [ ] `HoneyDrunk.Architecture`: Update `review.md` with the D3 twenty-category rubric execution detail — [`04-architecture-review-md-twenty-category-rubric.md`](04-architecture-review-md-twenty-category-rubric.md) — **`current-focus.md` priority #7 (review.md half)**
  - Blocked by: `packet:01` (soft).
- [ ] `HoneyDrunk.Architecture`: Author the `.honeydrunk-review.yaml` v1 schema doc — [`05-architecture-review-config-schema-doc.md`](05-architecture-review-config-schema-doc.md)
  - Blocked by: `packet:01` (soft).
- [ ] `HoneyDrunk.Architecture`: Enable the cloud reviewer on the Architecture repo (Phase 1 pilot) — [`06-architecture-enable-review-phase-1-pilot.md`](06-architecture-enable-review-phase-1-pilot.md)
  - Blocked by: `packet:03` (hard), `packet:04` (hard), `packet:05` (soft).

**Wave 1 exit criterion (Phase 1 go/no-go):** the cloud-wired reviewer's verdicts on real Architecture-repo PRs are at least as useful as the local `review` agent's, at acceptable cost ($40-100/month Grid-wide projection holding). **If this bar is missed, Wave 2 does not start.**

### Wave 2 — Phase 2: Rollout to the 10 remaining live .NET Nodes + discipline foundations

Runs after the Phase-1 go decision. Packets 07-12.

- [ ] `HoneyDrunk.Actions`: Add `authorship-check` + `pr-size-check` jobs to `pr-core.yml` (D6/D7, warnings-only) — [`07-actions-authorship-and-pr-size-checks.md`](07-actions-authorship-and-pr-size-checks.md)
  - Blocked by: `packet:01` (soft).
- [ ] `HoneyDrunk.Actions`: Seed `large-pr`, `audit-sample`, `skip-review` labels Grid-wide — [`08-actions-seed-review-labels-grid-wide.md`](08-actions-seed-review-labels-grid-wide.md)
  - Blocked by: `packet:07` (soft).
- [ ] `HoneyDrunk.Architecture`: Roll the D3 rubric into the upstream authoring agents (`scope`/`adr-composer`/`pdr-composer`/`refine`/`node-audit`) — [`09-architecture-d3-rubric-upstream-agent-rollout.md`](09-architecture-d3-rubric-upstream-agent-rollout.md) — **`current-focus.md` priority #7 (upstream half)**
  - Blocked by: `packet:04` (**hard** — same category names/numbering).
- [ ] `HoneyDrunk.Architecture`: Amend execution-surface prompts — emit `Authorship:` line + surface the D3 authoring checklist — [`10-architecture-execution-surface-authorship-and-rubric.md`](10-architecture-execution-surface-authorship-and-rubric.md)
  - Blocked by: `packet:04` (hard), `packet:07` (soft).
- [ ] 10 live .NET Nodes (cross-repo, tracked from `HoneyDrunk.Architecture`): Enable the cloud reviewer on the 10 remaining live .NET Nodes — [`11-cross-repo-enable-review-ten-nodes.md`](11-cross-repo-enable-review-ten-nodes.md)
  - Blocked by: `packet:06` (**hard** — Phase-1 go), `packet:07` (hard), `packet:08` (hard), `packet:09` (soft), `packet:10` (soft).
- [ ] `HoneyDrunk.Architecture`: Verify `pr-review-rules.md` severity coverage across all twenty D3 categories — [`12-architecture-pr-review-rules-severity-coverage.md`](12-architecture-pr-review-rules-severity-coverage.md)
  - Blocked by: `packet:04` (hard).

**Wave 2 exit criterion (Phase 2 go/no-go):** all 10 fan-out Nodes enabled (Architecture already piloted; Studios and Observe excluded; private revenue Nodes excluded); authorship classification mandatory and passing across the Grid; PR-size discipline visible (warnings-only); the D3 rubric present in all seven agent files; Phase-2 review quality reviewed before Phase 3.

### Wave 3 — Phase 3: Discipline tightening

Runs after the Phase-2 go decision. Packets 13-14. **D8 is data-gated on packet 13.**

- [ ] `HoneyDrunk.Architecture`: Add the `review_risk_class` field to `catalogs/grid-health.json` — [`13-architecture-review-risk-class-catalog-field.md`](13-architecture-review-risk-class-catalog-field.md)
  - Blocked by: `packet:01` (soft).
- [ ] `HoneyDrunk.Actions`: Activate D8 multi-perspective review for high-risk-Node PRs + flip `pr-size-check` `> 800` to auto-comment — [`14-actions-d8-multi-perspective-review.md`](14-actions-d8-multi-perspective-review.md)
  - Blocked by: `packet:03` (hard), `packet:13` (**hard — D8 activation is explicitly gated on `review_risk_class` landing**).

**Wave 3 exit criterion (Phase 3 go/no-go):** `review_risk_class` populated; D8 escalation firing correctly on high-risk-Node PRs; `> 800` PR-size auto-comment live.

### Wave 4 — Phase 4: Sampling audit + polish

Runs after the Phase-3 go decision. Packets 15-17.

- [ ] `HoneyDrunk.Architecture`: Create `generated/post-merge-audits/` with a README — [`15-architecture-post-merge-audits-directory.md`](15-architecture-post-merge-audits-directory.md)
  - Blocked by: `packet:01` (soft).
- [ ] `HoneyDrunk.Actions`: Build the D9 `audit-sample` post-merge labeling + audit job — [`16-actions-audit-sample-post-merge-job.md`](16-actions-audit-sample-post-merge-job.md)
  - Blocked by: `packet:03` (soft), `packet:08` (hard), `packet:15` (hard).
- [ ] `HoneyDrunk.Architecture`: Wire `hive-sync` to detect D3↔agent-file drift — [`17-architecture-hive-sync-d3-drift-detection.md`](17-architecture-hive-sync-d3-drift-detection.md)
  - Blocked by: `packet:04` (hard), `packet:09` (hard).

**Wave 4 exit criterion (Phase 4 go/no-go):** D9 sampling audit running; audit reports landing in `generated/post-merge-audits/`; `hive-sync` drift detection live. ADR-0044's polish features (per-path config overrides, learnings, output-formatter improvements per D11) are **explicitly not scoped here** — each is its own follow-up packet against observed v1-v3 gaps.

## Out-of-scope items from ADR-0044

- **Per-path `path_instructions`-style config overrides** — D4/D11 explicitly defer to a v2 polish phase. No packet here.
- **Learnings-from-prior-reviews and output-formatter polish** — D11 Phase 4 polish; each its own follow-up packet against observed gaps.
- **The ADR-0011 amendment record / supersession note** — partially handled by packet 01's ADR-0011 amendment note; a fuller supersession record is a small follow-up if the human wants one.
- **HoneyDrunk.Studios (TypeScript) onboarding** — evaluated separately from the .NET-shaped fan-out (packet 11).
- **Private revenue (`.Cloud`) Node enablement** — excluded from the default v1 rollout per ADR-0044 Operational Consequences; explicit opt-in only.

## `current-focus.md` priority #7 correspondence

`current-focus.md` priority #7 ("ADR-0044 D3 rubric rollout", gated on #3 = ADR-0044 landing) maps to **packet 04** (the `review.md` twenty-category rubric) **and packet 09** (the upstream `scope`/`adr-composer`/`pdr-composer`/`refine`/`node-audit` D3 sections). Packet 10 (execution-surface prompts) is the third leg of D3's upstream-awareness clause and belongs to the same priority-#7 family. These three packets together discharge priority #7.

## `gh` CLI Commands — file post-acceptance only

**Do not run these until ADR-0044 is Accepted (packet 01 merged).** The `file-issues` agent files them.

```bash
PACKETS="generated/issue-packets/active/adr-0044-cloud-code-review"

# Wave 1 — Phase 1
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Accept ADR-0044 — cloud code review, finalize new invariants, register initiative" --body-file $PACKETS/01-architecture-adr-0044-acceptance.md --label "chore,tier-3,meta,docs,adr-0044,wave-1"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Create review-agent GitHub App and provision Anthropic key in Vault" --body-file $PACKETS/02-architecture-create-review-agent-github-app.md --label "chore,tier-2,meta,docs,infrastructure,human-only,adr-0044,wave-1"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions --title "Build job-review-agent.yml — cloud-wired Grid-aware reviewer" --body-file $PACKETS/03-actions-job-review-agent-workflow.md --label "ci,tier-3,ops,adr-0044,wave-1"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Update review.md with the D3 twenty-category rubric" --body-file $PACKETS/04-architecture-review-md-twenty-category-rubric.md --label "docs,tier-2,meta,adr-0044,wave-1"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Author the .honeydrunk-review.yaml v1 schema doc" --body-file $PACKETS/05-architecture-review-config-schema-doc.md --label "docs,tier-1,meta,adr-0044,wave-1"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Enable the cloud reviewer on HoneyDrunk.Architecture (Phase 1 pilot)" --body-file $PACKETS/06-architecture-enable-review-phase-1-pilot.md --label "ci,tier-2,meta,adr-0044,wave-1"

# Wave 2 — Phase 2
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions --title "Add authorship-check and pr-size-check jobs to pr-core.yml" --body-file $PACKETS/07-actions-authorship-and-pr-size-checks.md --label "ci,tier-2,ops,adr-0044,wave-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions --title "Seed large-pr, audit-sample, skip-review labels Grid-wide" --body-file $PACKETS/08-actions-seed-review-labels-grid-wide.md --label "chore,tier-1,ops,adr-0044,wave-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Roll the D3 rubric into the upstream authoring agents" --body-file $PACKETS/09-architecture-d3-rubric-upstream-agent-rollout.md --label "docs,tier-2,meta,adr-0044,wave-2"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Amend execution-surface prompts — Authorship line + D3 authoring checklist" --body-file $PACKETS/10-architecture-execution-surface-authorship-and-rubric.md --label "docs,tier-2,meta,adr-0044,wave-2"
# Packet 11 is a multi-repo unit — file as a tracking issue in HoneyDrunk.Architecture with 10 child issues (one per .NET Node in its target_repos), or as 10 sibling issues (dispatch decides). Observe/Architecture/Studios are NOT in the fan-out.
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Verify pr-review-rules.md severity coverage across all twenty D3 categories" --body-file $PACKETS/12-architecture-pr-review-rules-severity-coverage.md --label "docs,tier-1,meta,adr-0044,wave-2"

# Wave 3 — Phase 3
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Add the review_risk_class field to catalogs/grid-health.json" --body-file $PACKETS/13-architecture-review-risk-class-catalog-field.md --label "docs,tier-2,meta,adr-0044,wave-3"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions --title "Activate D8 multi-perspective review for high-risk-Node PRs" --body-file $PACKETS/14-actions-d8-multi-perspective-review.md --label "ci,tier-2,ops,adr-0044,wave-3"

# Wave 4 — Phase 4
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Create generated/post-merge-audits/ directory with a README" --body-file $PACKETS/15-architecture-post-merge-audits-directory.md --label "docs,tier-1,meta,adr-0044,wave-4"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions --title "Build the D9 audit-sample post-merge labeling and audit job" --body-file $PACKETS/16-actions-audit-sample-post-merge-job.md --label "ci,tier-2,ops,adr-0044,wave-4"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Wire hive-sync to detect D3 / agent-file drift" --body-file $PACKETS/17-architecture-hive-sync-d3-drift-detection.md --label "docs,tier-1,meta,adr-0044,wave-4"
```

## After filing — board fields and blocking relationships

For each issue: `gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>`, then set Status, Wave (1-4), Initiative=`adr-0044-cloud-code-review`, Node, Tier, Actor. **Actor=Human** for packet 02 only (it carries the `human-only` label); every other packet is `Actor=Agent` (packets with substantial Human Prerequisites — 03, 06, 11, 16 — keep `Actor=Agent` because the code/doc critical path is delegable).

Blocking relationships to wire via `addBlockedBy` (30 edges across packets 02-17; packet 11's five blockers are wired on its tracking issue, and each of its 10 child issues inherits them):

- `02` ← `01` (soft)
- `03` ← `01` (soft), `03` ← `02` (hard)
- `04` ← `01` (soft)
- `05` ← `01` (soft)
- `06` ← `03` (hard), `06` ← `04` (hard), `06` ← `05` (soft)
- `07` ← `01` (soft)
- `08` ← `07` (soft)
- `09` ← `04` (hard)
- `10` ← `04` (hard), `10` ← `07` (soft)
- `11` ← `06` (hard), `11` ← `07` (hard), `11` ← `08` (hard), `11` ← `09` (soft), `11` ← `10` (soft)
- `12` ← `04` (hard)
- `13` ← `01` (soft)
- `14` ← `03` (hard), `14` ← `13` (hard)
- `15` ← `01` (soft)
- `16` ← `02` (hard), `16` ← `03` (soft), `16` ← `08` (hard), `16` ← `15` (hard)
- `17` ← `04` (hard), `17` ← `09` (hard)

## Notes

- **Acceptance precedes flip.** ADR-0044 stays Proposed until packet 01's PR merges. These packets are draft/pending-acceptance — not filed as Issues until then.
- **Phases are go/no-go gates.** Per ADR-0044 D11, each wave's exit criterion gates the next. Phase 1's miss stops the rollout — packet 06 carries the Phase-1 decision.
- **D8 is data-gated.** D8 multi-perspective review (packet 14) cannot activate until `review_risk_class` lands (packet 13). The dispatch order reflects this hard dependency.
- **Packet 11 is a 10-repo unit.** It is the one multi-repo packet, filed as a coordination/tracking issue in `HoneyDrunk.Architecture` with 10 child issues (or 10 sibling issues). In scope: the 10 .NET Node repos in its `target_repos` frontmatter. Explicitly OUT: `HoneyDrunk.Observe` (Seed, not a live Node), `HoneyDrunk.Architecture` (already enabled in Phase 1), `HoneyDrunk.Studios` (TypeScript, onboarded separately). The Grid has 12 live Nodes; this fan-out is those 12 minus the two already-handled/excluded. Each per-Node work unit is small and identical.
- **GitHub App permission.** Packet 02 provisions the review-agent GitHub App with **Contents: Write** on `HoneyDrunk.Architecture` from the start (a developer decision, recorded in packet 02). The write scope serves packet 16's post-merge audit-commit step; provisioning it up front avoids a second mid-rollout portal pass. Packet 16 therefore takes a hard `packet:02` dependency. The scope is confined to the single architecture repo.
- **`current-focus.md` priorities #3 and #7** are discharged by this initiative (see the priority-#7 correspondence section above and packet 01's `current-focus.md` bookkeeping note). When all 17 packets reach `Done` and all four phase exit criteria are met, both priorities should be marked complete and dropped from the ranked list at the next ADR-0043 weekly briefing.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries (especially after each phase's go/no-go) as the historical record.

## Archival

Per ADR-0008 D10, when every packet reaches `Done` on The Hive and all four phase exit criteria are met, the entire `active/adr-0044-cloud-code-review/` folder moves to `archive/adr-0044-cloud-code-review/` in a single commit. Polish-phase follow-up packets, when scoped, live in a new initiative folder — not appended here.
