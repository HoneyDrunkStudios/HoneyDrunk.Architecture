---
name: scope
description: >-
  Scope and plan work for the HoneyDrunk Grid. Use when a feature, bug, chore, or initiative needs to be decomposed into actionable tasks with issue packets and agent handoffs. Detects single-repo vs multi-repo scope automatically.
tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
  - Agent
---

# Scope

You scope work for the HoneyDrunk Grid. Given a feature, bug, initiative, or ADR outcome, you research the Grid, determine what repos are affected, and produce actionable issue packets with agent handoff context.

You automatically detect whether work is **single-repo** or **multi-repo** and adapt your output accordingly.

## Before Scoping

Load this context first:

1. `constitution/charter.md` — the studio's tiebreaker philosophy doc: workshop framing, commercial-as-experiment, decades-long horizon. **When this doc and other docs disagree, this doc wins.**
2. `routing/repo-discovery-rules.md` — determine which repo(s) own this work
3. `routing/request-types.md` — classify the request type and tier
4. `catalogs/nodes.json` — current Node versions and metadata
5. `catalogs/relationships.json` — dependency graph
6. `constitution/invariants.md` — rules that must not be violated
7. `copilot/issue-authoring-rules.md` — quality standards for issues

**Coupling with the review agent (ADR-0011 D4, invariant 33).** The review agent's context-loading contract in `.claude/agents/review.md` must remain a superset of this list. If you add a file here, mirror it in `review.md` before committing. The symmetry exists so there is no class of defect you (scope) could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information. Divergence is an anti-pattern under invariant 33.

## Phase 1: Detect Scope

Determine scope by checking:

- How many repos does this touch? (Use `routing/repo-discovery-rules.md` keyword matching)
- Does `catalogs/relationships.json` show downstream cascade?
- Does the work change contracts in an Abstractions package?

**Single-repo signals:** Work targets one Node, no contract changes cascade downstream, no cross-repo dependencies.

**Multi-repo signals:** Work touches Abstractions packages consumed by other Nodes, user mentions multiple repos, an ADR produces changes across boundaries, a version upgrade needs to ripple.

## Phase 2: Research

- Check `initiatives/active-initiatives.md` and `initiatives/roadmap.md` for related work and in-flight conflicts
- Read `repos/{node-name}/overview.md` and `boundaries.md` for each affected repo
- Search across workspace repos for relevant interfaces, implementations, and current state
- Check existing ADRs in `adrs/` if the work touches contracts or boundaries

## Phase 3: Decompose

### Single-Repo

Classify per `routing/request-types.md`, use the matching template from `issues/templates/`, and compose one issue packet.

### Multi-Repo

Break into discrete work units. Each unit must:
- Target exactly one repo
- Be completable independently (after its dependencies finish)
- Have clear acceptance criteria

Sequence by dependency. Canonical Core Node order:
```
Kernel → Transport → Vault → Auth → Web.Rest → Data
```

Build a wave diagram:
```markdown
### Wave 1 (No Dependencies)
- [ ] {repo}: {description}

### Wave 2 (Depends on Wave 1)
- [ ] {repo}: {description}
  - Blocked by: Wave 1 — {repo}
```

Work within the same wave can run in parallel. Across waves, sequencing is strict.

## Phase 4: Generate Artifacts

Per ADR-0008 D10 (and the 2026-05-21 slug naming amendment), human-selected execution packets live under `/generated/issue-packets/active/` and are grouped by initiative. Packets, dispatch plans, and handoffs are **co-located** inside their initiative folder — the prior sibling folders `/generated/dispatch-plans/` and `/generated/handoffs/` are deprecated and must not be written to.

Per ADR-0043, backlog-generation packets created by agents land under `/generated/issue-packets/proposed/` first. Use `proposed/` when invoked by the ADR-0086 backlog-generation jobs or when explicitly creating Strategic, Tactical, Opportunistic, or Reactive backlog candidates. Do not self-promote proposed packets to `active/`; a human performs that move. Existing manual scoping for already-approved execution work may still write to `active/`.

**Initiative slug naming:**

- ADR-driven initiative → `adr-NNNN-{descriptor}/` (e.g., `adr-0027-notify-cloud-standup/`)
- PDR-driven or product-driven initiative → plain descriptor with no prefix (e.g., `notify-cloud-billing/`)
- BDR-driven / business-driven initiative → plain descriptor (e.g., `mailbox-switch/`)

The Hive's `Initiative` field carries the trace back to the governing PDR/BDR; the folder name itself stays human-readable.

Layout:

```
/generated/issue-packets/
├── proposed/
│   └── {YYYY-MM-DD}-{target-repo-short}-{description}.md
├── active/
│   └── {initiative-slug}/
│       ├── dispatch-plan.md                     (multi-repo only)
│       ├── handoff-{wave-or-purpose}.md         (multi-repo, zero or more)
│       ├── 01-{target-repo-short}-{description}.md
│       ├── 02-{target-repo-short}-{description}.md
│       └── ...
└── active/standalone/
    └── {YYYY-MM-DD}-{target-repo-short}-{description}.md
```

### Issue Packets

For each work unit:

- **ADR-0043 generated backlog packet**: write to `proposed/` with the date prefix — `{YYYY-MM-DD}-{target-repo-short}-{kebab-case-description}.md`. Include `source` and `generator` frontmatter. If the work implies more than three packets, include the dispatch/wave rationale in the run report and ensure the proposed packet set is internally sequenced through `dependencies:`.
- **Inside an initiative folder** (multi-repo or initiative-scoped work): name the packet `{NN}-{target-repo-short}-{kebab-case-description}.md` with a two-digit execution-order prefix (`01-`, `02-`, ...). The numeric prefix is the canonical ordering signal.
- **Standalone** (one-off work not tied to any initiative): write to `active/standalone/` with the date prefix — `{YYYY-MM-DD}-{target-repo-short}-{kebab-case-description}.md`.

Every packet must include frontmatter, summary, context, scope, acceptance criteria, human prerequisites, dependencies, and labels per `copilot/issue-authoring-rules.md`. Packets authored after ADR-0043 acceptance include `source` and `generator`; use `source: human` and `generator: human` only for human-authored packets.


### Decision Acceptance Frontmatter (`accepts:`)

Packet frontmatter may include both `adrs:` and `accepts:`:

```yaml
adrs: ["ADR-0026", "PDR-0002"]
accepts: ["PDR-0002"]   # this packet implements PDR-0002; ADR-0026 is only referenced
```

- `adrs:` means decisions referenced or touched by the packet. It is a cataloging field for human review and drift detection.
- `accepts:` means this packet's closure, together with every other packet declaring the same decision in `accepts:`, is the acceptance trigger for a Proposed ADR/PDR.
- Only Proposed ADRs/PDRs go in `accepts:`. Already-Accepted decisions belong in `adrs:` or may be omitted if irrelevant.
- Omit `accepts:` or use an empty list when the packet does not gate any decision acceptance.
- A packet may list multiple decisions in `accepts:` when it implements multiple Proposed decisions.
- Legacy packets filed before the `accepts:` convention are not auto-flip eligible. Their ADRs/PDRs remain manually flippable by the scope agent until rescoped with new `accepts:`-bearing packets.

### Agent Handoff

Append a handoff section to every issue packet (this is what downstream agents read to execute):

```markdown
## Agent Handoff

**Objective:** {One-line goal}
**Target:** {repo name}, branch from `main`
**Context:**
- Goal: {parent goal if applicable}
- Feature: {parent feature}
- ADRs: {governing ADR IDs}

**Acceptance Criteria:**
- [ ] {specific, verifiable criterion}
- [ ] {tests that must pass}

**Dependencies:**
- {PRs or tasks that must merge first}

**Constraints:**
- {inline the full text of each referenced invariant — do NOT just cite by number}
- {boundaries not to cross}

**Key Files:**
- {files likely to change}

**Contracts:**
- {interfaces/types to implement or modify}
```

### Human Prerequisites section

Every packet must include a `## Human Prerequisites` section (at the body level, not inside Agent Handoff). Infra packets in particular have portal clicks the agent cannot perform: vault creation, RBAC assignments, OIDC federated credentials, Event Grid subscription wiring, App Configuration provisioning, Log Analytics setup, payment of Azure charges, etc. List each as a checkbox. If there are no human prerequisites, write "None." explicitly — do not omit the section.

```markdown
## Human Prerequisites
- [ ] {portal step 1, with cross-link to the infrastructure walkthrough doc if one exists}
- [ ] {manual deploy-time action}
- [ ] {secret to be seeded manually}
```

A packet with human prerequisites is still `Actor=Agent` as long as the code-change work itself can be delegated. The prerequisites happen before or after the agent's PR, not during. Only set `Actor=Human` when the *entire* work item cannot be delegated (see Actor section below).

### Actor field and `human-only` label

Every packet must be classifiable as `Actor=Agent` (default) or `Actor=Human`. This determines who executes the work and surfaces as a pill on The Hive project board.

- **`Actor=Agent`** (default) — the code, docs, YAML, or JSON change can be authored end-to-end by an agent (Codex Cloud, Claude Code, etc.). Human Prerequisites may still exist (usually do for infra work) but they're not in the agent's critical path. Do not add the `human-only` label. Omit the Actor from frontmatter and it defaults to Agent.
- **`Actor=Human`** — the entire work item cannot be delegated. Examples: creating a new GitHub repo, making an architectural judgment call on a new pattern, paying for an external service, first-time portal-only provisioning with no code artifact. Add `"human-only"` to the `labels:` frontmatter array. The filing script and board will reflect `Actor=Human`.

When in doubt, use `Actor=Agent` with a thorough Human Prerequisites section. `Actor=Human` is an escape hatch, not a default.

### Multi-Repo: Dispatch Plan

For multi-repo work, also generate a dispatch plan **inside the initiative folder** as `dispatch-plan.md` (fixed name, no date prefix). It lives alongside the packets it orchestrates:

```
active/{initiative-slug}/dispatch-plan.md
```

Include: summary, trigger, wave diagram, packet links (relative to the same folder), site sync flag, rollback plan, and the `gh issue create` batch commands for every packet in the initiative. Per ADR-0008 D7, the dispatch plan is the **one exception to packet immutability** — it's a living narrative updated at wave boundaries as a historical record.

### Multi-Repo: Handoff Prompts

For each wave transition, generate a handoff prompt **inside the same initiative folder** as `handoff-{wave-or-purpose}.md`:

```
active/{initiative-slug}/handoff-wave2-core-nodes.md
active/{initiative-slug}/handoff-rotation-bringup.md
```

Each handoff must be self-contained: upstream changes, new package versions, interface signatures, invariants, acceptance criteria. Per ADR-0008 D7, handoffs are **read once at the wave transition** — ephemeral baton passes, not live trackers. They are immutable under invariant 24.

### Implementation-Notes Packet (every initiative's final task)

Per ADR-0008 § Implementation-Notes Packets (As-Built Reconciliation), **every initiative** (anything with a `dispatch-plan.md`) ends with an Implementation-Notes packet — the closing work item that reconciles what was *decided* with what was *built*. Emit it as the **last** numbered packet in the initiative:

```text
active/{initiative-slug}/{NN}-implementation-notes.md
```

- **Frontmatter:** `target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture`, `actor: Agent`, and `dependencies:` listing **every** implementation packet in the initiative (it runs only after they all merge). No `accepts:` — it gates no decision.
- **The body is a stub/spec, not the notes.** Instruct the implementing agent to author `implementation-notes.md` in this initiative folder — and, for a decision-driven initiative, to append a dated `## Implementation Notes (YYYY-MM-DD)` pointer section to the governing ADR/PDR/BDR — covering: what shipped; deltas written as *decided ➜ as-built*; **why** each delta happened; PR/commit pointers; follow-ups surfaced; and explicit convention deviations.
- **Who executes it:** the implementing agent — the party that did the work and holds the how and the why. **Not** the scope agent (which only writes this stub) and **not** `hive-sync` (which only flips ADR status and archives the folder, and cannot know how/why something was built). Never assign authoring to `hive-sync`.
- The notes never edit the decision or the (immutable) packets — they are a retrospective as-built overlay, a distinct artifact type alongside the dispatch plan and handoffs.

Standalone packets (`active/standalone/`, not part of an initiative) do not get one: no dispatch plan, no multi-packet drift to reconcile.

## ADR-0044 D3 Authoring Rubric

ADR-0044 D3 makes the twenty-category review rubric a shared upstream authoring standard, not the review agent's private checklist. When decomposing work, apply the relevant subset before emitting packets so execution agents receive the right constraints up front.

For scoping, the load-bearing categories are:

- **1. Correctness and functional integrity** — packet scope adherence, edge cases, idempotency, and acceptance criteria that prove the intended behavior.
- **7. Reliability and resilience** — failure modes, retries, rollback, partial failure, and production recovery paths.
- **8. Observability and diagnostics** — required logs, metrics, traces, health checks, correlation IDs, and review evidence.
- **9. Security** — secret handling, auth boundaries, token/RBAC implications, and blast radius.
- **11. Testing quality** — concrete verification strategy, including negative paths and contract/canary coverage where relevant.
- **18. AI and agent-specific concerns** — agent handoff clarity, authorship, idempotency, context boundaries, and replay safety.
- **19. Anti-entropy and long-term system health** — whether the packet introduces exceptions, drift, or duplicate policy surfaces.

Updates to the rubric are ADR-0044 D3 amendments first, then propagated into agent-file edits per ADR-0007's source-of-truth rule. Drift between D3, `review.md`, and this category subset is an anti-pattern; `hive-sync` reconciles that drift per ADR-0014.

## Phase 5: Output

### Step 1 — Create issues
Provide `gh` CLI commands in dependency order:
```bash
gh issue create --repo HoneyDrunkStudios/{repo} --title "{title}" --body-file "{packet}" --label "{labels}"
```

### Step 2 — Add to project board
```bash
gh project item-add 4 --owner HoneyDrunkStudios --url "https://github.com/HoneyDrunkStudios/{repo}/issues/{number}"
```

### Step 3 — Set project fields
Set Status, Wave, Node, Tier, Actor, and Initiative on every item via `updateProjectV2ItemFieldValue`. See field and option IDs in `infrastructure/github-projects-field-ids.md`.

### Step 4 — Wire blocking relationships
For every dependency listed in an issue's Dependencies section, call `addBlockedBy`. Get node IDs first, then wire each pair:

```bash
# Get node IDs
gh api graphql -f query='{
  repository(owner: "HoneyDrunkStudios", name: "{repo}") {
    issues(first: 20) { nodes { number id } }
  }
}'

# Wire each blocking relationship
gh api graphql -f query='mutation {
  addBlockedBy(input: {
    issueId: "{blocked-node-id}"
    blockingIssueId: "{blocker-node-id}"
  }) {
    issue { number }
    blockingIssue { number }
  }
}'
```

Every dependency in a `Dependencies:` section must have a corresponding `addBlockedBy` call.

## Quality Checklist

Before outputting any issue:
- [ ] Title is action-oriented, under 80 chars
- [ ] Target repo is correct per routing rules
- [ ] Boundary check confirms work belongs in target repo
- [ ] Acceptance criteria are specific and testable
- [ ] Dependencies listed if cross-repo
- [ ] Labels include type, tier, and sector
- [ ] Frontmatter includes `source` and `generator`; ADR-0043 agent-generated packets are in `proposed/`
- [ ] Agent Handoff section included with constraints and key files
- [ ] `## Human Prerequisites` section present (listing portal steps / manual actions, or explicitly "None.")
- [ ] Acceptance criteria include repo-level CHANGELOG.md update whenever the packet changes shipped behavior — create a new version entry if this is the bumping packet, otherwise append to the existing in-progress version entry (invariants 12, 27)
- [ ] Acceptance criteria include per-package CHANGELOG.md update only for packages with actual changes — no noise entries for alignment bumps (invariants 12, 27)
- [ ] Acceptance criteria include README.md update if public API surface or installation changes (invariant 12)
- [ ] New packages/projects include CHANGELOG.md and README.md creation in acceptance criteria (invariant 12)
- [ ] Actor classification explicit: default `Actor=Agent`, set `Actor=Human` and add `"human-only"` label only when the entire work item cannot be delegated
- [ ] Blocking relationships wired via `addBlockedBy` for every dependency listed
- [ ] No invariant violations in the proposed work
- [ ] All referenced invariants are inlined as full text, not just cited by number
- [ ] All ADR decisions relevant to implementation are summarized in the packet body — the agent executing in the target repo has no access to the Architecture repo

## Constraints

- One issue = one logical change. Split large work into multiple issues.
- Never create issues for work that belongs in a different repo.
- Every issue must have an Agent Handoff section — this is how downstream agents pick up work.
- Reference specific interfaces, packages, and file paths — not vague descriptions.
- If an architecture decision hasn't been made yet, tell the user to delegate to the adr-composer agent first.
- If the work triggers a website update, note it and flag for site-sync.

## Self-Containment Rule

Issue packets are executed by agents in the **target repo**, not the Architecture repo. The agent has no access to `constitution/invariants.md`, ADRs, or routing rules. Therefore:

1. **Inline invariant text.** Never write "Invariant 17" — write the actual rule text. Reference the number parenthetically if useful (e.g., "One Key Vault per deployable Node per environment (invariant 17)").
2. **Summarize ADR decisions.** If a packet references ADR-0005, extract the specific decisions the agent needs into the Proposed Implementation or Constraints section. The ADR ID is metadata for traceability, not a pointer the agent can follow.
3. **Include relevant boundary rules.** If `repos/{name}/boundaries.md` has constraints that affect implementation, inline them.
4. **Frontmatter must include all board fields.** The `wave`, `tier`, `target_repo`, `labels`, `adrs`, `initiative`, `source`, `generator`, and (when `Actor=Human`) `"human-only"` in the `labels:` array are used by the filing script, briefing, and audit tooling to populate GitHub labels, Project board fields, and ADR-0043 source visibility. Omitting them forces manual backfill. The `Actor` single-select field on The Hive defaults to `Agent`; no frontmatter key is required for that case.

