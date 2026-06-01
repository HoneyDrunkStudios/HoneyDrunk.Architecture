---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0086", "wave-1"]
dependencies: []
adrs: ["ADR-0086", "ADR-0044", "ADR-0079"]
accepts: ["ADR-0086"]
wave: 1
initiative: adr-0086-pull-based-local-worker-grid-review
node: honeydrunk-architecture
---

# Accept ADR-0086 — pull-based local worker is the Grid Review Runner; append supersession notes to ADR-0044 and ADR-0079

## Summary
Flip ADR-0086 (Pull-Based Local Worker as the Grid Review Runner) from Proposed to Accepted. Append "Superseded in part by ADR-0086" amendment notes to ADR-0044 (D1 transport + D5 default-runtime substrate) and ADR-0079 (D1 Reviewer 3 transport + D2 Reviewer 4 substrate). Register the `adr-0086-pull-based-local-worker-grid-review` initiative in `initiatives/active-initiatives.md`. Add the ADR-0086 row to `adrs/README.md`. Mark the still-open ADR-0044 fan-out (Architecture#182, packet 11 of that initiative) as superseded — replaced by this initiative's packet 09 with the new `runner: local-worker` default.

## Context
ADR-0086 keeps the load-bearing discipline of ADR-0044 (context-loading contract, twenty-category rubric, `.honeydrunk-review.yaml` per-repo config, authorship classification, PR-size discipline, multi-perspective on high-risk Nodes, post-merge sampling audit, advisory posture) and changes only the **transport** and the **execution substrate**. The agent-prompt file `.claude/agents/review.md` is unchanged.

This packet is the acceptance gate — every subsequent packet in this initiative references ADR-0086's D1–D12 as live rules. **No constitutional invariant is added** (the existing invariants 52/53 from ADR-0044 are preserved with their "requests" mechanism redefined; reconciliation is `hive-sync`'s job per ADR-0014, not this packet's). **ADR-0081 is NOT edited** in this packet — its D1 Implementation Notes review-webhook-bridge bullet is flagged as Follow-up Work belonging to ADR-0081's own acceptance/amendment cycle (ADR-0086 Follow-up Work and Phase-A scope are explicit on this; ADR-0081 is still Proposed). **`.claude/agents/review.md` is NOT edited** — the substrate change is invisible to the prompt (ADR-0086 D1, Follow-up Work). **`constitution/invariants.md` is NOT edited** — invariant-number reconciliation is `hive-sync`'s mandate per ADR-0014 (ADR-0086 Invariants section is explicit on this).

This is a docs/governance-only packet. No code, no workflow, no .NET project. `Actor=Agent`.

## Scope
- `adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — append the ADR-0086 row (Accepted, 2026-05-26, Meta) at the end of the existing table; update the ADR-0044 row description to note ADR-0086 supersession; update the ADR-0079 row description to note ADR-0086 supersession.
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md` — add an `> **Superseded in part by ADR-0086.**` amendment note near the top (after Status, before Context) recording D1 (transport rewritten as pull-based local-worker; OpenClaw removed from review path) and D5 (default runtime substrate is now Codex CLI + Claude Code CLI under the local worker, not OpenClaw/Codex).
- `adrs/ADR-0079-multi-perspective-pr-review-stack.md` — add an `> **Superseded in part by ADR-0086.**` amendment note near the top (after Status, before Context) recording D1 Reviewer 3 transport (same Codex CLI execution, triggered via the pull-based local worker rather than via OpenClaw) and D2 Reviewer 4 (runs through the local worker via Claude Code CLI under Max **today**; the June 15 2026 dependency and the Claude-Code-on-the-web GitHub integration are removed from the Grid Review Runner's design).
- `initiatives/active-initiatives.md` — register the `adr-0086-pull-based-local-worker-grid-review` initiative with the wave structure and packet checklist for this folder. Mark the ADR-0044 initiative's Architecture#182 (packet 11 of ADR-0044) as **superseded** by ADR-0086 packet 09 with a one-line pointer.

## Proposed Implementation

1. Edit the ADR-0086 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Append an ADR-0086 row to `adrs/README.md`'s index table. Title: "Pull-Based Local Worker as the Grid Review Runner". Date: 2026-05-26. Sector: Meta. Description: a one-sentence summary noting the supersession of ADR-0044 D1/D5 and ADR-0079 D1 Reviewer 3 / D2 Reviewer 4.
3. Update the ADR-0044 row's description in `adrs/README.md` with a brief "Superseded in part by ADR-0086 (transport + default runtime substrate)" pointer.
4. Update the ADR-0079 row's description in `adrs/README.md` with a brief "Superseded in part by ADR-0086 (Reviewer 3 transport, Reviewer 4 substrate)" pointer.
5. Add the amendment note to `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md`. Place it after the existing Status header, before the Context section — match the amendment-note convention used by ADR-0044's own ADR-0079 amendment note (if present from the ADR-0079 acceptance packet) or by other amended ADRs in the repo. Text body:

   > **Superseded in part by ADR-0086 (2026-05-26).** D1's GitHub Actions trigger rail + signed webhook → OpenClaw transport is rewritten as a pull-based local worker (cheap Action emits label + queue comment; local worker on the home server polls and runs the agent under Codex CLI + Claude Code CLI subscription auth). D5's default subscription-backed runtime moves from OpenClaw/Codex to local Codex CLI + Claude Code CLI. D2 (context-loading contract), D3 (twenty-category rubric), D4 (`.honeydrunk-review.yaml` — with the `runner` enum updated per ADR-0086 D5), D6 (authorship classification), D7 (PR-size discipline), D8 (multi-perspective for high-risk Nodes — substrate moves to local worker), D9 (post-merge sampling audit — substrate moves to local worker), D10 (relationship to ADR-0011 — preserved), D11 (phase clock reset per ADR-0086 D11) are otherwise preserved. See ADR-0086 D12 for the full relationship table.

6. Add the amendment note to `adrs/ADR-0079-multi-perspective-pr-review-stack.md`. Place it after the Status header, before the Context section. Text body:

   > **Superseded in part by ADR-0086 (2026-05-26).** D1 Reviewer 3 (Codex via OpenClaw) is superseded transport-wise: same Codex CLI execution against the operator's ChatGPT Pro allotment, triggered via the pull-based local worker rather than via OpenClaw. D2 Reviewer 4 (Anthropic's native Claude Code on the web GitHub integration, post June 15 2026) is superseded: Reviewer 4 runs through the local worker via Claude Code CLI under Claude Max **today**. The June 15 dependency and the Claude-Code-on-the-web GitHub integration are removed from the Grid Review Runner's design. D3 (substantive-PR classifier safe-list), D4–D5 (Greptile/Codex-OOTB watch list), D6 (cost ceiling), D7 (Invariant 53 satisfaction via dual-model execution — now Codex CLI + Claude Code CLI, both under subscription auth, both under the local worker), D8 (auth-precedence gotcha — enforced at the worker env boundary), D9 (out-of-scope items) are preserved. See ADR-0086 D12 for the full relationship table.

7. Register the initiative in `initiatives/active-initiatives.md`. Place it after the existing ADR-0044/ADR-0079 entries (Code Review Stack is the closest topical neighbor). List the ten packets in this folder, organized into the three waves (Phase A / Phase B / Phase C) from ADR-0086 D11. Note the supersession of ADR-0044 Architecture#182 (packet 11 of ADR-0044) as a sibling bullet in the ADR-0044 initiative entry: mark Architecture#182 superseded by ADR-0086 packet 09.

## Affected Files
- `adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md`
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md`
- `adrs/ADR-0079-multi-perspective-pr-review-stack.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] `.claude/agents/review.md` is NOT edited (ADR-0086 D1; ADR's Follow-up Work explicit).
- [x] `constitution/invariants.md` is NOT edited (ADR-0086 Invariants section; reconciles via `hive-sync` per ADR-0014).
- [x] `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md` D1's review-webhook-bridge bullet is NOT edited (ADR-0086 Follow-up Work explicit; ADR-0081 is still Proposed and its edit belongs to its own acceptance/amendment cycle).

## Acceptance Criteria
- [ ] ADR-0086 header reads `**Status:** Accepted`
- [ ] An ADR-0086 row exists in `adrs/README.md`'s index, appended at the end of the existing table, status Accepted, with a one-sentence description noting the supersession of ADR-0044 D1/D5 and ADR-0079 D1 Reviewer 3 / D2 Reviewer 4
- [ ] The ADR-0044 row's description in `adrs/README.md` carries a brief "Superseded in part by ADR-0086 (transport + default runtime substrate)" pointer
- [ ] The ADR-0079 row's description in `adrs/README.md` carries a brief "Superseded in part by ADR-0086 (Reviewer 3 transport, Reviewer 4 substrate)" pointer
- [ ] ADR-0044 carries a `> **Superseded in part by ADR-0086 (2026-05-26).**` note near the top (after Status, before Context) with the body text in the Proposed Implementation step 5
- [ ] ADR-0079 carries a `> **Superseded in part by ADR-0086 (2026-05-26).**` note near the top (after Status, before Context) with the body text in the Proposed Implementation step 6
- [ ] `initiatives/active-initiatives.md` registers the `adr-0086-pull-based-local-worker-grid-review` initiative with the wave/packet structure
- [ ] `initiatives/active-initiatives.md`'s ADR-0044 entry marks Architecture#182 (ADR-0044 packet 11) as superseded by ADR-0086 packet 09, with a one-line pointer
- [ ] `.claude/agents/review.md` is unchanged
- [ ] `constitution/invariants.md` is unchanged
- [ ] `adrs/ADR-0081-home-server-for-openclaw-and-local-agent-infrastructure.md` is unchanged
- [ ] CHANGELOG.md updated with an entry noting ADR-0086 acceptance and the supersession edits

## Human Prerequisites
None.

## Dependencies
None. This is the first packet in the initiative.

## Referenced ADR Decisions

**ADR-0086 D1** — Pull-based local worker is the canonical Grid Review Runner transport. The inbound webhook is removed; the Cloudflare Tunnel for review traffic is removed; OpenClaw is removed from the review path entirely. Execution moves to the local worker, which runs under the operator's existing Codex CLI / Claude Code CLI subscription sessions. `.claude/agents/review.md` is unchanged.

**ADR-0086 D5** — `.honeydrunk-review.yaml` `runner:` field changes shape: `local-worker` (new default), `api-ci` (preserved), `openclaw-codex` (removed). Breaking schema change; impact is small because per ADR-0044 D11 Phase 1 only HoneyDrunk.Architecture has been opted in to date.

**ADR-0086 D8** — Reviewer 4 is committed to the local-CLI path (superseding ADR-0079 D2): runs through the same local worker using Claude Code CLI under Claude Max subscription, today. The June 15 2026 dependency and the web-integration surface are removed from the Grid Review Runner's design.

**ADR-0086 D10** — Decommission OpenClaw on the review path at Phase A → Phase B cutover. Non-review OpenClaw/Honeyclaw jobs (`hive-sync`, Lore sourcing, Lore ingest, Lore signal review) continue only until their equivalent ADR-0086 runner job specs are smoke-tested and cut over.

**ADR-0086 D11** — Phased rollout resets ADR-0044 D11's clock. Phase A: HoneyDrunk.Architecture pilot. Phase B: enable on the other repos that ADR-0044's Phase 2 had reached. Phase C: all 12 live Nodes; multi-perspective activates once `review_risk_class` is populated per ADR-0044 D8 (preserved).

**ADR-0086 D12** — Relationship to prior ADRs: full supersession/preservation table covering ADR-0011, ADR-0044, ADR-0079, ADR-0081.

**ADR-0086 Follow-up Work** — Explicitly: do not edit `.claude/agents/review.md`; do not edit `constitution/invariants.md`; do not edit ADR-0081 D1's review-webhook-bridge bullet in this acceptance pass.

## Constraints
- **Acceptance precedes flip.** ADR-0086 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Do not edit `.claude/agents/review.md`.** ADR-0086 D1 and Follow-up Work are explicit — the substrate change is invisible to the prompt. The agent file is the source of truth per ADR-0007 and is consumed by both the (removed) OpenClaw path and the (new) local-worker path identically.
- **Do not edit `constitution/invariants.md`.** ADR-0086's Invariants section is explicit: no new invariants are required; ADR-0044's invariants 52/53 are preserved with "requests" redefined to "lands in the GitHub-native queue, processed by the local worker"; ADR-0079's preserved invariants are unchanged. Reconciliation is `hive-sync`'s mandate per ADR-0014.
- **Do not edit ADR-0081 D1's Implementation Notes review-webhook-bridge bullet.** ADR-0086 Follow-up Work flags this as a one-line edit belonging to ADR-0081's own acceptance/amendment cycle. ADR-0081 is still Proposed; do not touch its body.
- **Supersession notes are short pointers, not rewrites.** ADR-0044 and ADR-0079 bodies are otherwise untouched. The full relationship table lives in ADR-0086 D12; the amendment notes point readers there.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0086`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0086 to Accepted, append supersession amendment notes to ADR-0044 and ADR-0079, update the ADR index, and register the initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0086 so the pull-based local-worker build packets can reference its decisions as live rules.
- Feature: ADR-0086 Pull-Based Local Worker rollout, Phase A.
- ADRs: ADR-0086 (primary), ADR-0044 (superseded in part), ADR-0079 (superseded in part), ADR-0081 (referenced; not edited), ADR-0014 (reconciliation discipline).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0086 stays Proposed until this PR merges.
- `.claude/agents/review.md` is not edited.
- `constitution/invariants.md` is not edited.
- ADR-0081 is not edited.
- Supersession notes are short pointers; bodies of ADR-0044/ADR-0079 are otherwise untouched.

**Key Files:**
- `adrs/ADR-0086-pull-based-local-worker-grid-review-runner.md`
- `adrs/ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md`
- `adrs/ADR-0079-multi-perspective-pr-review-stack.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

**Contracts:** None.
