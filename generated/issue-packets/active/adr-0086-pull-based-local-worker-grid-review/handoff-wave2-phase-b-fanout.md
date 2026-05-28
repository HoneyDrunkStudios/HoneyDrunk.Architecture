# Handoff: Wave 1 → Wave 2 (Phase A → Phase B)

**Read once at the Wave 1 → Wave 2 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## Precondition — the Phase A go/no-go decision

Wave 2 does **not** start until packet 07's Phase A exit criterion is met and documented:

> The pull-based local worker's verdicts on real `HoneyDrunk.Architecture` PRs are at least as useful as the manual `.claude/agents/review.md` invocation; reliable polling and claim semantics (the head-SHA invalidation pre- and post-flight checks deterministically handle pushes mid-review; stale-claim sweep recovers from worker crashes); marginal LLM cost stays at $0/PR under subscription auth (no `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` set in the worker environment).

The seven verification items in packet 07's Acceptance Criteria are the canonical record. The Phase A go decision is in packet 07's PR body.

If that bar is missed, **stop** — do not file Wave 2. Re-scope the worker (packet 03), the workflow rewrite (packet 05), the GitHub App provisioning (packet 02), or the schema doc (packet 04), and re-run Phase A.

## What Wave 1 delivered (upstream changes Wave 2 builds on)

- **ADR-0086 is Accepted** (packet 01). Its D1–D12 are now binding rules. ADR-0044 and ADR-0079 carry "Superseded in part by ADR-0086" amendment notes near the top. `initiatives/active-initiatives.md` registers `adr-0086-pull-based-local-worker-grid-review` and marks ADR-0044 Architecture#182 as superseded.
- **The existing ADR-0044 review-agent GitHub App is audited for reuse** (packet 02) under `HoneyDrunkStudios` with worker-path permissions `pull_requests: write` + `issues: write` + `contents: read`; installed on `HoneyDrunk.Architecture` for Phase A; private key + app-id + installation-id verified in HoneyDrunk.Vault under the existing `review-agent-github-app-*` names. The walkthrough at `infrastructure/walkthroughs/review-agent-github-app-local-worker.md` records the portal audit and regeneration procedure.
- **The pull-based local worker is running on the home server** (packet 03). Source at `infrastructure/workers/grid-review-runner/`. The Windows Scheduled Task `HoneyDrunkGridReviewWorker` runs on startup/logon, repeats on the configured cadence (60–120 s recommended), restarts on failure, and refuses overlapping runs. The worker mints App-installation tokens from Vault on each tick, polls for `needs-agent-review` PRs Grid-wide, claims one at a time via label swap + queue-comment edit, runs `.claude/agents/review.md` under Codex CLI (and Claude Code CLI when D8 high-risk triggers), synthesizes independent findings into one verdict comment, and posts verdict + label transition. The worker spawns child CLI processes with `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` explicitly unset. D8 multi-perspective dispatch is wired; activation is gated on ADR-0044 packet 13 (`review_risk_class` catalog field) landing. D9 audit-mode dispatch is wired; activation is gated on ADR-0044 packets 15/16 landing.
- **The schema doc is updated** (packet 04). `copilot/review-config-schema.md` documents `runner: local-worker | api-ci` (the `openclaw-codex` value is removed). Worked Architecture-repo example uses `runner: local-worker`. Breaking-change history line records the 2026-05-26 change.
- **`job-review-request.yml` is rewritten** (packet 05) from webhook-emitting to managed-label-normalizing plus label-and-comment enqueue. No more HMAC, no curl POST, no signing secret input. The workflow applies deterministic Grid-owned labels, preserves human labels outside the managed set, adds `needs-agent-review` on every triggering event (including `synchronize` when `agent-review-in-progress` is current — the invalidation signal for the worker's head-SHA check), and upserts the structured queue comment idempotently by the opaque marker `<!-- honeydrunk-grid-review-queue:v1 ... -->`. The workflow's `permissions:` block widened to `contents: read, pull-requests: write, issues: write`.
- **The worker labels and managed PR-label vocabulary are seeded Grid-wide** (packet 06) via the existing labels-as-code + `seed-labels-fanout.yml` pattern.
- **`HoneyDrunk.Architecture` is cut over and Phase A is green** (packet 07). The repo's `.honeydrunk-review.yaml` carries `runner: local-worker`. Its `pr-review.yml` caller drops the webhook inputs and declares the widened `permissions:` block. The cutover PR was itself reviewed by the worker end-to-end; the Phase A go decision is in its PR body.

## Contracts Wave 2 consumes

- **`job-review-request.yml` (label+comment form)** — callable via `workflow_call` at the pinned ref where packet 05 landed. Confirm the pinned ref before filing packet 09's per-repo callers.
- **`.honeydrunk-review.yaml` v1 schema with `runner: local-worker`** — per `copilot/review-config-schema.md` (packet 04). Each of the 10 Phase-B Nodes authors one.
- **The worker labels and managed PR labels exist on every Grid repo** (packet 06's fan-out). Per-repo `gh label create --force` safety nets exist in the workflow if any repo's labels are missing.
- **The widened `permissions:` block on every caller** — invariant 39 mandate. Each per-repo `pr-review.yml` caller declares `contents: read, pull-requests: write, issues: write`.
- **The `Authorship:` line in every repo's PR template** — already mandatory Grid-wide via ADR-0044 packet 07's `authorship-check`. Phase B confirms presence; adds the line in the per-repo PR if missing.

## Wave 2 objectives (Phase A → B cutover + Phase B fan-out)

1. **Decommission the OpenClaw review-runner role** (packet 08) — mark the legacy `infrastructure/openclaw/grid-review-runner.md` as superseded with a banner pointing to the new authority; cross-link from the new worker README. **Operator portal work as Human Prerequisites:** remove the Cloudflare Tunnel hostname for review traffic; rotate the ADR-0044 webhook-signing secret out of Vault per ADR-0006; disable the OpenClaw review-runner cron/poll. **Honeyclaw, ADR-0043 Lore sourcing, and other OpenClaw workloads remain running.** **`adrs/ADR-0081-*.md` is NOT edited** — that one-line edit belongs to ADR-0081's own acceptance/amendment cycle.
2. **Fan out `runner: local-worker` to the 10 remaining live .NET Nodes** (packet 09) — Kernel, Transport, Vault, Auth, Web.Rest, Data (Core); Notify, Communications, Pulse, Actions (Ops). One PR per repo; each PR is itself reviewed by the worker as a smoke test. **Supersedes ADR-0044 Architecture#182** (the same fan-out at the old default) — close Architecture#182 as superseded when packet 09's tracking issue files.

## Constraints carried into Wave 2

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. The pull-based reviewer is tier-3 and advisory — non-required check; never blocks a merge.

> **Invariant 39:** Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. The widened block is required on every per-repo caller.

> **Invariant 52 (preserved from ADR-0044, "requests" redefined by ADR-0086):** Every non-draft PR on an `enabled` repo lands in the GitHub-native queue and is processed by the local worker. Skip is via `skip-review` or `enabled: false`.

- **Phase B is reviewer-fan-out only.** Do not edit `.claude/agents/review.md`. Do not edit `constitution/invariants.md`. Do not edit ADR-0081.
- **OpenClaw decommission precedes Phase B.** Per ADR-0086 D10, packet 08 ships first.
- **OpenClaw's non-review workloads are preserved.** Operator verifies Honeyclaw / Lore sourcing / other home-server workloads remain running before merging packet 08.
- **Cloudflare hostname removal is surgical.** Remove only the review-traffic hostname (`grid-review.honeydrunkstudios.com` per ADR-0081 D6); leave every other tunnel host alone.
- **One PR per repo per initiative** in Phase B (operator discipline, memory-pinned). Each of the 10 repos gets one PR.
- **Smoke test per repo.** Each per-repo enablement PR is itself reviewed by the worker; the per-repo go decision is in that PR's body. Halt on per-repo failure; do not propagate.
- **Private revenue Nodes excluded.** None of the 10 are `.Cloud` Nodes today; recorded for completeness.
- **Excluded from this fan-out:** `HoneyDrunk.Observe` (Seed), `HoneyDrunk.Architecture` (Phase-A pilot), `HoneyDrunk.Studios` (TypeScript), `HoneyDrunk.Vault.Rotation` (non-canonical CI shape), Seed AI-sector Nodes, library/docs Nodes.

## Open coupling at the wave boundary

- **ADR-0044 packet 11 (Architecture#182) is superseded.** Close it as superseded when packet 09's tracking issue files; cross-link Architecture#182 to the new tracking issue for traceability.
- **ADR-0044 packets 13 (`review_risk_class`) and 14 (D8 activation) are preserved, not superseded.** When they land, D8 multi-perspective activates on the local-worker substrate without further work in this initiative (the worker's D8 dispatch wiring from packet 03 is in place).
- **ADR-0044 packets 15 (`generated/post-merge-audits/`) and 16 (audit-sample post-merge job) are preserved, not superseded.** When they land, D9 audit-mode activates similarly. The worker's audit-mode dispatch wiring from packet 03 is in place.
- **The `infrastructure/openclaw/grid-review-runner.md` legacy doc** is preserved as a historical record with a supersession banner (packet 08), not deleted.

## Acceptance signal for Wave 2 → Wave 3

All 10 fan-out Nodes are enabled with `runner: local-worker` (Observe / Architecture / Studios / Vault.Rotation / Seed Nodes / library Nodes excluded); each repo's smoke-test PR ran end-to-end through the worker; the Cloudflare Tunnel review-traffic hostname is removed; the ADR-0044 webhook-signing secret is rotated out and logged in Log Analytics per invariant 22; the OpenClaw review-runner role is disabled (other workloads verified running). Then file Wave 3 (packet 10 — narrative surfacing).
