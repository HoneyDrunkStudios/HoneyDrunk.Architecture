# Handoff: Wave 1 → Wave 2 (Phase 1 → Phase 2 — Node rollout)

**Read once at the Wave 1 → Wave 2 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## Precondition — the Phase-1 go/no-go decision

Wave 2 does **not** start until packet 06's Phase-1 exit criterion is met and documented:

> The cloud-wired `review` agent's verdicts on real `HoneyDrunk.Architecture` PRs are at least as useful as the local `review` agent's, at acceptable cost (the $40-100/month Grid-wide projection holding pro-rata for one repo).

If that bar is missed, **stop** — do not file Wave 2. Re-scope `job-review-agent.yml` (packet 03) or the rubric (packet 04) and re-run Phase 1.

## What Wave 1 delivered (upstream changes Wave 2 builds on)

- **ADR-0044 is Accepted** (packet 01). Its two new invariants are live in `constitution/invariants.md`; the ADR-0011 amendment note is recorded. D1-D11 are now binding rules, not proposals.
- **The cross-repo-checkout GitHub App and the Anthropic API key exist in Vault** (packet 02). Secret names: `review-agent-github-app-id`, `review-agent-github-app-private-key`, `review-agent-github-app-installation-id`, `review-agent-anthropic-api-key`. The App has **Contents: Read** on `HoneyDrunk.Architecture` only.
- **`job-review-agent.yml` exists in HoneyDrunk.Actions** (packet 03) — a reusable `workflow_call` workflow that checks out the target repo + `HoneyDrunk.Architecture`, runs `.claude/agents/review.md` via the Claude Agent SDK, posts an advisory PR comment, and honors the D5 cost guardrails. It exits without API spend when a repo has no `.honeydrunk-review.yaml` or `enabled: false`.
- **`.claude/agents/review.md` carries the full D3 twenty-category rubric** (packet 04) with per-category execution detail and severity mappings.
- **The `.honeydrunk-review.yaml` v1 schema doc exists** at `copilot/review-config-schema.md` (packet 05).
- **The Architecture repo is enabled and piloted** (packet 06) — `.honeydrunk-review.yaml` (`enabled: true`) + a `pr-review.yml` caller. The Phase-1 cost and quality data is recorded in packet 06's PR body.

## Contracts Wave 2 consumes

- **`job-review-agent.yml`** — callable via `workflow_call` at a pinned ref. Wave 2's per-Node `pr-review.yml` callers invoke it. Confirm the pinned ref before filing packet 11.
- **`.honeydrunk-review.yaml` v1 schema** — `enabled` (required), `severity_floor`, `skip_paths`, `model`, `cost_cap_per_pr_usd`. Documented in `copilot/review-config-schema.md`. Each Node authors one in packet 11.
- **The five D6 authorship classes** — `human`, `agent-codex`, `agent-copilot`, `agent-claude-code`, `mixed`. `authorship-check` (packet 07) validates the `Authorship:` line against exactly these.
- **The twenty D3 category names/numbering** as authored in `review.md` — packets 09, 10, 12 must reuse them verbatim. Divergence is the anti-pattern D3 warns against.

## Wave 2 objectives (Phase 2 — D11)

1. **`authorship-check` + `pr-size-check` into `pr-core.yml`** (packet 07) — authorship classification becomes mandatory Grid-wide; PR-size discipline activates warnings-only. `> 800` stays warnings-only in Phase 2 — leave the documented single-point toggle for Phase 3 (packet 14).
2. **Seed `large-pr`, `audit-sample`, `skip-review` labels Grid-wide** (packet 08) via the existing labels-as-code fan-out.
3. **Roll the D3 rubric into the upstream authoring agents** (packet 09) — `scope`, `adr-composer`, `pdr-composer`, `refine`, `node-audit`. With packet 04, this discharges `current-focus.md` priority #7.
4. **Amend the execution-surface prompts** (packet 10) — Codex/Copilot/Claude Code emit the `Authorship:` line + commit trailer and surface the brief D3 authoring checklist.
5. **Enable the cloud reviewer on the 12 live Nodes** (packet 11) — `.honeydrunk-review.yaml` (`enabled: true`) + `pr-review.yml` caller per repo. **Private revenue (`.Cloud`) Nodes are excluded from the default rollout** — confirm the exclusion list against `catalogs/nodes.json` / ADR-0027 D2.
6. **Verify `pr-review-rules.md` severity coverage** across all twenty D3 categories (packet 12).

## Constraints carried into Wave 2

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. `authorship-check` joins that gate; `pr-size-check` is warnings-only in Phase 2 and does not gate; the review agent itself stays advisory and non-required.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled — `review.md`'s context-loading list must remain a superset of `scope.md`'s. Packet 09 edits `scope.md`'s D3 section; do not touch its context-loading list.

> **Invariant 8 / 9:** The Anthropic key and GitHub App credentials live in Vault; never echoed in logs, never committed.

- **Phase 2 is gated on a documented Phase-1 "go".** No Wave 2 filing before that decision is recorded.
- **Private revenue Nodes excluded by default** (ADR-0044 Operational Consequences).
- **The reviewer is advisory** — never a required check on any Node.
- **Use the exact D3 category names from `review.md`** in packets 09, 10, 12.

## Acceptance signal for Wave 2 → Wave 3

All 12 live Nodes enabled (private revenue Nodes excluded); authorship classification mandatory and green Grid-wide; PR-size discipline visible; the D3 rubric present in all seven agent files (`review.md` + the six upstream); `pr-review-rules.md` covers all twenty categories. Then make the Phase-2 → Phase-3 go decision before filing Wave 3 (packets 13-14). Note: Wave 3's packet 14 (D8 activation) is hard-gated on packet 13 (`review_risk_class`) — that data dependency cannot be short-circuited.
