---
name: CI Change
type: ci-change
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["ci", "tier-3", "ops", "adr-0044", "wave-1"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0044", "ADR-0007", "ADR-0011", "ADR-0012"]
accepts: ["ADR-0044"]
wave: 1
initiative: adr-0044-cloud-code-review
node: honeydrunk-actions
---

# Build job-review-agent.yml — the cloud-wired Grid-aware code reviewer (Phase 1 MVP)

## Summary
Author a new reusable workflow `HoneyDrunk.Actions/.github/workflows/job-review-agent.yml` that runs the Grid's `review` agent in the cloud on `pull_request` events, loads Grid context from a checkout of `HoneyDrunk.Architecture`, posts the verdict as a PR comment, and sets a non-required advisory check run — with the cost guardrails baked in as default behavior.

## Target Workflow
**File:** `.github/workflows/job-review-agent.yml`
**Family:** pr-core (follows the `pr-core.yml` factoring per ADR-0012's reusable-workflow model)

## Motivation
ADR-0044 D1 mandates the Grid build, own, and operate its own cloud-wired Grid-aware code reviewer rather than adopting a third-party tool that cannot actively load Grid catalogs at review time. The prompt logic already exists in `.claude/agents/review.md`; the context-loading contract is defined in ADR-0011 D4; the workflow host is HoneyDrunk.Actions; the Claude Agent SDK provides the runtime. This packet is the Phase-1 MVP build — a 1-2 day engineering project that wires the existing agent into a GitHub Action and posts the verdict as a PR comment. It is the load-bearing build of the entire initiative; packet 04 (Phase-1 enablement on the Architecture repo) consumes it.

## Proposed Change

### Workflow shape (per ADR-0044 D1)
- New reusable workflow callable via `workflow_call` so consumer repos invoke it from their `pr.yml`.
- Triggered (in the consumer caller) on `pull_request` event types: `opened`, `synchronize`, `ready_for_review`. **Not** on `draft` PRs — draft is by definition WIP and skipping drafts is a cost-discipline default (D5).
- The workflow invokes the **Claude Agent SDK** against the `.claude/agents/review.md` definition. The agent definition is **not** copied into the workflow — it is read from the `HoneyDrunk.Architecture` checkout (per ADR-0007's source-of-truth rule). Both the local Claude Code invocation and this cloud workflow consume the *same* `.claude/agents/review.md`; drift between the two execution surfaces is forbidden.
- Posts the verdict as a PR comment using the format already defined in `.claude/agents/review.md`.
- Sets a **non-required** check run — advisory only, per ADR-0011 D5's advisory posture (preserved by ADR-0044 D10). The workflow never blocks a merge.

### Cross-repo checkout (per ADR-0044 D2)
The workflow checks out **both**:
1. The target repo (the PR's repo) — for the diff and the repo's own files.
2. `HoneyDrunkStudios/HoneyDrunk.Architecture` — using the GitHub App installation token from packet 02 (`review-agent-github-app-id`, `review-agent-github-app-private-key`, `review-agent-github-app-installation-id` resolved from the CI-surface Key Vault). This makes `constitution/invariants.md`, the catalogs, and per-repo boundary files locally readable by the agent, mirroring the local Claude Code workspace layout exactly.

### Context loaded (identical to local invocation, per ADR-0044 D2 / ADR-0011 D4)
The agent loads exactly this set — no more, no less:
1. `constitution/invariants.md`
2. Governing ADRs referenced in the packet frontmatter
3. `catalogs/relationships.json`
4. `catalogs/contracts.json`
5. For each target repo: `repos/{node}/overview.md`, `boundaries.md`, `invariants.md`
6. `copilot/pr-review-rules.md`
7. The packet file (resolved via PR-body link)
8. The PR diff

### Cost guardrails baked in as default behavior (per ADR-0044 D5)
These are **not configurable** — they ship as default workflow behavior:
- **Hard per-PR ceiling** — `cost_cap_per_pr_usd` from `.honeydrunk-review.yaml` (default $5). The agent runtime tracks accumulated token cost; on cap exceedance the agent posts a **partial-review comment** naming what was reviewed and what was skipped, and the workflow exits cleanly. It must never silently fail.
- **Skip on draft PRs.**
- **Skip on PRs labeled `skip-review`** — the manual escape hatch (label-as-config, no schema change).
- **PR-size cap** — if the diff exceeds 2000 lines after `skip_paths` exclusions, the agent reviews only the highest-risk files (`*.Abstractions/**`, `*.csproj` changes, anything touching `boundaries.md` or `invariants.md`) and posts a comment indicating coverage was capped.
- **Sonnet by default** — Opus only when D8's high-risk-Node trigger fires (D8 activates in Phase 3; for Phase 1 the workflow always uses Sonnet, but the model-selection plumbing should read the `model` field from `.honeydrunk-review.yaml` so Phase 3 needs no rework here).
- **Cache context loads per workflow run** — catalogs and invariants do not change within a single PR run; load once, reuse across all files in the diff.

### Config gate (per ADR-0044 D4)
The workflow reads `.honeydrunk-review.yaml` from the target repo root. If the file is absent or `enabled: false`, the workflow exits immediately without invoking the agent (no API spend). This is the opt-in gate for phased rollout. The v1 schema the workflow consumes is documented in packet 05.

### Graceful degradation
- Anthropic API outage → the workflow fails gracefully and posts a comment stating the reviewer could not run; the PR still merges (advisory posture).
- The architecture-repo checkout failing → same: post a comment, exit cleanly.

### Claude Agent SDK version pin (decision recorded here)
The Claude Agent SDK is the workflow's runtime dependency. **It must be pinned to an exact version** — never a floating `latest` — so review behavior is reproducible and an upstream SDK release cannot silently change verdicts mid-rollout. This packet is the canonical place the pin is **recorded**: the chosen exact SDK version is written into `job-review-agent.yml` (as the installed package version) **and** restated in `docs/consumer-usage.md` (this repo, HoneyDrunk.Actions) under a "Claude Agent SDK version pin" heading, so there is one human-readable record of the decided pin in the same repo as the workflows that consume it. Any later SDK bump is a deliberate, reviewed change to `job-review-agent.yml` — and packet 16's `job-audit-sample.yml` (also in HoneyDrunk.Actions), which reuses the same SDK runtime, must read the pin from this recorded value rather than choosing its own. The exact version number is the human's call at build time (see Human Prerequisites); once chosen it is recorded, not re-decided per consumer.

## Consumer Impact
- No consumer repo is affected until it adds a caller job and a `.honeydrunk-review.yaml` with `enabled: true`. Packet 06 wires the first consumer (Architecture repo, Phase 1). Phase 2 (packet 11) rolls it out to the 10 remaining live .NET Nodes.
- The workflow is purely additive — existing `pr-core.yml` consumers are untouched.

## Breaking Change?
- [ ] Yes
- [x] No — new reusable workflow, additive. Default-off via the `.honeydrunk-review.yaml` gate.

## Acceptance Criteria
- [ ] `.github/workflows/job-review-agent.yml` exists and is callable via `workflow_call`
- [ ] The workflow checks out both the target repo and `HoneyDrunk.Architecture` (App token from packet 02's Vault secrets)
- [ ] The agent is invoked via the Claude Agent SDK against `.claude/agents/review.md` read from the architecture-repo checkout — the agent prompt is not duplicated in the workflow
- [ ] The exact eight-item context set from ADR-0044 D2 is loaded; context loads are cached per workflow run
- [ ] The verdict is posted as a PR comment in the `.claude/agents/review.md` format; a non-required advisory check run is set
- [ ] Cost guardrails present: per-PR cost cap with partial-review comment on exceedance, draft skip, `skip-review` label skip, 2000-line high-risk-only cap, Sonnet default with model field read from config
- [ ] The workflow reads `.honeydrunk-review.yaml` and exits without API spend when the file is absent or `enabled: false`
- [ ] Anthropic API outage and architecture-checkout failure both degrade gracefully (comment + clean exit, no merge block)
- [ ] The Claude Agent SDK is pinned to an exact version in `job-review-agent.yml` (no floating `latest`); the same exact version is recorded under a "Claude Agent SDK version pin" heading in `docs/consumer-usage.md` so the pin has one human-readable record packet 16 can reference
- [ ] `docs/CHANGELOG.md` updated with a new entry for the `job-review-agent.yml` reusable workflow
- [ ] `docs/consumer-usage.md` updated with the caller snippet and the `.honeydrunk-review.yaml` requirement
- [ ] README.md updated to list `job-review-agent.yml` among the reusable workflows

## Human Prerequisites
- [ ] Packet 02 must be complete — the GitHub App and Anthropic API key must exist in Vault and be wired into the HoneyDrunk.Actions secrets surface before this workflow can run end-to-end
- [ ] Decide the exact Claude Agent SDK version to pin (the human's call). Once chosen, the agent records it in `job-review-agent.yml` and in `docs/consumer-usage.md` per the "Claude Agent SDK version pin" section above — it is recorded once and reused by packet 16, not re-decided per workflow.

## Dependencies
- `packet:01` — ADR-0044 acceptance (soft; references ADR-0044 decisions as live rules).
- `packet:02` — GitHub App + Anthropic key in Vault (**hard** — the workflow cannot authenticate the cross-repo checkout or call the API without these credentials).

## Referenced ADR Decisions

**ADR-0044 D1** — Build `job-review-agent.yml` in HoneyDrunk.Actions as a reusable workflow following `pr-core.yml` factoring; triggered on `pull_request` opened/synchronize/ready_for_review, not draft; invokes the Claude Agent SDK against `.claude/agents/review.md`; posts the verdict as a PR comment; non-required advisory check.
**ADR-0044 D2** — Context loading identical to the local invocation; the workflow checks out both the target repo and `HoneyDrunk.Architecture` using a GitHub App token; the eight-item context set is mandatory.
**ADR-0044 D4** — `.honeydrunk-review.yaml` is the per-repo config; repos without it are `enabled: false`; v1 schema is the enabled gate plus `severity_floor`, `skip_paths`, `model`, `cost_cap_per_pr_usd`.
**ADR-0044 D5** — Cost guardrails ship as non-configurable default behavior: per-PR cap, draft skip, `skip-review` skip, 2000-line cap, Sonnet default, per-run context caching. Expected $40-100/month.
**ADR-0007** — `.claude/agents/` is the single source of truth for agent definitions; the cloud workflow consumes `review.md` directly, no duplication.
**ADR-0011 D5** — Review agent is advisory, not a required check (preserved by ADR-0044 D10).

## Constraints
> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. The Anthropic key and GitHub App private key must never be echoed into workflow logs.

> **Invariant 9:** Vault is the only source of secrets. The workflow resolves credentials through the GitHub Actions secrets surface populated from the CI-surface Key Vault — never hardcoded.

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. The review agent is tier-3 and advisory — it does not become a required check and does not alter the tier-1 gate.

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. The cloud workflow must load exactly the set `.claude/agents/review.md` mandates — do not add or remove context files in the workflow; changes to the context set are edits to the agent file.

- **No agent-prompt duplication.** The workflow reads `.claude/agents/review.md` from the architecture-repo checkout. Copying the prompt into the workflow YAML creates a drift surface and violates ADR-0007.
- **Advisory only.** Never make the check required; never block a merge. Per ADR-0011 D5, preserved by ADR-0044 D10.
- **Cost discipline is non-negotiable.** The guardrails in D5 are default behavior, not optional knobs.

## Labels
`ci`, `tier-3`, `ops`, `adr-0044`, `wave-1`

## Agent Handoff

**Objective:** Build `job-review-agent.yml` — the cloud-wired Grid-aware reviewer. Check out both the target repo and `HoneyDrunk.Architecture`, run the `review` agent via the Claude Agent SDK against `.claude/agents/review.md`, post the verdict as a PR comment, set a non-required advisory check, and bake in the D5 cost guardrails.

**Target:** `HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Ship the Phase-1 MVP of the cloud code reviewer so it can be enabled on the Architecture repo (packet 04).
- Feature: ADR-0044 Cloud Code Review rollout, Phase 1.
- ADRs: ADR-0044 (primary, D1/D2/D4/D5), ADR-0007 (agent-definition source of truth), ADR-0011 (advisory posture, D4 context contract), ADR-0012 (reusable-workflow factoring).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — ADR-0044 acceptance (soft).
- `packet:02` — GitHub App + Anthropic key in Vault (hard).

**Constraints:**
- See "Constraints" section — inlined for agent consumption.
- No agent-prompt duplication; read `review.md` from the architecture checkout.
- Advisory only; never a required check.
- Cost guardrails are default behavior, not optional.

**Key Files:**
- `.github/workflows/job-review-agent.yml` (new)
- `docs/CHANGELOG.md`
- `docs/consumer-usage.md`
- `README.md`

**Contracts:** Consumes `.claude/agents/review.md` (read-only, from the architecture-repo checkout) and `.honeydrunk-review.yaml` (target-repo config, schema per packet 05).
