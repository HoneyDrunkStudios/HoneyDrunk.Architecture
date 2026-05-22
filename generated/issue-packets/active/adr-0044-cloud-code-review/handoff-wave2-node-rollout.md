# Handoff: Wave 1 → Wave 2 (Phase 1 → Phase 2 — Node rollout)

**Read once at the Wave 1 → Wave 2 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## Precondition — the Phase-1 go/no-go decision

Wave 2 does **not** start until packet 06b's Phase-1 exit criterion is met and documented:

> The OpenClaw/Codex Grid Review Runner's verdicts on real `HoneyDrunk.Architecture` PRs are at least as useful as the manual `review` agent's; the request path is reliable; reviewed-head-SHA tracking prevents duplicate work; incremental model cost stays near zero.

If that bar is missed, **stop** — do not file Wave 2. Re-scope the OpenClaw runner (packet 02b), `job-review-request.yml` (packet 03b), or the rubric (packet 04) and re-run Phase 1.

## What Wave 1 delivered (upstream changes Wave 2 builds on)

- **ADR-0044 is Accepted** (packet 01). Its two new invariants are live in `constitution/invariants.md`; the ADR-0011 amendment note is recorded. D1-D11 are now binding rules, not proposals.
- **The OpenClaw/Codex Grid Review Runner runtime is documented/configured** (packet 02b). v1 does not require an Anthropic API key. Local `gh` auth is acceptable; webhook/GitHub App credentials are optional and narrowly scoped if used.
- **`job-review-request.yml` exists in HoneyDrunk.Actions** (packet 03b) — a reusable trigger rail that validates skip/enable rules, emits a review request payload, and delivers it to OpenClaw or leaves durable pickup state. It never invokes a model API directly.
- **`.claude/agents/review.md` carries the full D3 twenty-category rubric** (packet 04) with per-category execution detail and severity mappings.
- **The `.honeydrunk-review.yaml` v1 schema doc exists** at `copilot/review-config-schema.md` (packet 05b), with `runner: openclaw-codex` as the default.
- **The Architecture repo is enabled and piloted** (packet 06b) — `.honeydrunk-review.yaml` (`enabled: true`, `runner: openclaw-codex`) + a `pr-review.yml` caller. The Phase-1 quality, reliability, and near-zero incremental-cost evidence is recorded in packet 06b's PR body.

## Contracts Wave 2 consumes

- **`job-review-request.yml`** — callable via `workflow_call` at a pinned ref. Wave 2's per-Node `pr-review.yml` callers invoke it. Confirm the pinned ref before filing packet 11.
- **`.honeydrunk-review.yaml` v1 schema** — `enabled` (required), `runner`, `severity_floor`, `skip_paths`, `cost_cap_per_pr_usd`. Documented in `copilot/review-config-schema.md`. Each of the 10 fan-out Nodes authors one in packet 11.
- **The five D6 authorship classes** — `human`, `agent-codex`, `agent-copilot`, `agent-claude-code`, `mixed`. `authorship-check` (packet 07) validates the `Authorship:` line against exactly these.
- **The twenty D3 category names/numbering** as authored in `review.md` — packets 09, 10, 12 must reuse them verbatim. Divergence is the anti-pattern D3 warns against.

## Wave 2 objectives (Phase 2 — D11)

1. **`authorship-check` + `pr-size-check` into `pr-core.yml`** (packet 07) — authorship classification becomes mandatory Grid-wide; PR-size discipline activates warnings-only. `> 800` stays warnings-only in Phase 2 — leave the documented single-point toggle for Phase 3 (packet 14).
2. **Seed `large-pr`, `audit-sample`, `skip-review` labels Grid-wide** (packet 08) via the existing labels-as-code fan-out.
3. **Roll the D3 rubric into the upstream authoring agents** (packet 09) — `scope`, `adr-composer`, `pdr-composer`, `refine`, `node-audit`. With packet 04, this discharges `current-focus.md` priority #7.
4. **Amend the execution-surface prompts** (packet 10) — Codex/Copilot/Claude Code emit the `Authorship:` line + commit trailer and surface the brief D3 authoring checklist.
5. **Enable the OpenClaw/Codex reviewer on the 10 remaining live .NET Nodes** (packet 11) — `.honeydrunk-review.yaml` (`enabled: true`, `runner: openclaw-codex`) + `pr-review.yml` caller per repo. The fan-out is exactly the 10 .NET Node repos in packet 11's `target_repos`: Kernel, Transport, Vault, Auth, Web.Rest, Data, Notify, Communications, Pulse, Actions. **`HoneyDrunk.Observe` is OUT** (Seed, not a live Node); `HoneyDrunk.Architecture` is OUT (already enabled in Phase 1); `HoneyDrunk.Studios` is OUT (TypeScript, onboarded separately). **Private revenue (`.Cloud`) Nodes are excluded from the default rollout** — confirm the exclusion list against `catalogs/nodes.json` / ADR-0027 D2.
6. **Verify `pr-review-rules.md` severity coverage** across all twenty D3 categories (packet 12).

## Constraints carried into Wave 2

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. `authorship-check` joins that gate; `pr-size-check` is warnings-only in Phase 2 and does not gate; the Grid Review Runner itself stays advisory and non-required.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled — `review.md`'s context-loading list must remain a superset of `scope.md`'s. Packet 09 edits `scope.md`'s D3 section; do not touch its context-loading list.

> **Invariant 8 / 9:** No Anthropic API key is required for v1. If webhook/GitHub App credentials are used, they live in Vault/secret storage; never echoed in logs, never committed.

- **Phase 2 is gated on a documented Phase-1 "go".** No Wave 2 filing before that decision is recorded.
- **Private revenue Nodes excluded by default** (ADR-0044 Operational Consequences).
- **The reviewer is advisory** — never a required check on any Node.
- **Use the exact D3 category names from `review.md`** in packets 09, 10, 12.

## Acceptance signal for Wave 2 → Wave 3

All 10 fan-out Nodes enabled with `runner: openclaw-codex` (Observe/Architecture/Studios excluded; private revenue Nodes excluded); authorship classification mandatory and green Grid-wide; PR-size discipline visible; the D3 rubric present in all seven agent files (`review.md` + the six upstream); `pr-review-rules.md` covers all twenty categories. Then make the Phase-2 → Phase-3 go decision before filing Wave 3 (packets 13-14). Note: Wave 3's packet 14 (D8 activation) is hard-gated on packet 13 (`review_risk_class`) — that data dependency cannot be short-circuited.
