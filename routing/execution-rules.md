# Execution Rules

How work is executed after routing. See `/routing/sdlc.md` for the full three-surface lifecycle (Claude Code → Codex → Copilot).

## Pre-Execution Checklist

Before generating any artifact (issue packet, PR, code change):

1. **Load repo context** — Read `/repos/{node-name}/overview.md` and `boundaries.md` if they exist. If no repo context directory exists for the target Node, fall back to `catalogs/nodes.json` for the Node's description, sector, and relationships.
2. **Check invariants** — Verify the proposed change doesn't violate `/constitution/invariants.md`
3. **Check active work** — Read `/repos/{node-name}/active-work.md` and `/initiatives/current-focus.md` for conflicts (skip if files don't exist)
4. **Determine tier** — Use `/catalogs/flow_tiers.json` to classify the change
5. **Check dependencies** — Use `/catalogs/relationships.json` to identify cascade effects

## Issue Packet Generation

When creating an issue packet in `/generated/issue-packets/`:

1. Use the appropriate template from `/issues/templates/`
2. Include frontmatter with: target repo, request type, tier, dependencies, affected packages
3. Include acceptance criteria that reference specific contracts or tests
4. Reference related ADRs if applicable
5. Name the file: `{date}-{repo}-{short-description}.md` (e.g., `2026-03-22-kernel-add-baggage-limit.md`)

## Execution Order for Cross-Repo Changes

1. Start with the most upstream Node (usually Kernel)
2. Complete and merge upstream changes before starting downstream
3. Bump version references in downstream Nodes after upstream packages are published
4. Run canary tests in downstream Nodes to validate integration

## Handoff Protocol

### Claude Code → Codex

When Claude Code generates work for Codex execution:

1. Generate the artifact in `/generated/` (issue packet or handoff prompt)
2. Include the structured handoff format defined in `/routing/sdlc.md`:
   - Task description (imperative)
   - Target repo and branch
   - Upstream context (Goal, Feature, ADRs)
   - Acceptance criteria
   - Dependencies (PRs that must merge first)
   - Constraints (boundaries, invariants)
3. Create a GitHub Issue in the target repo using the issue packet, or provide the handoff prompt directly to Codex

### Codex → Developer

When Codex completes a task:

1. PR is opened in the target repo with implementation
2. Developer reviews against acceptance criteria from the issue
3. If adjustments needed: developer uses Copilot in IDE to fix, pushes to same branch
4. If fundamental rework needed: close PR, refine issue, re-assign

### Developer → Claude Code (escalation)

When in-IDE work reveals systemic issues:

1. Developer identifies that the problem crosses repo boundaries or requires architectural reasoning
2. Escalate to Claude Code for re-planning, impact analysis, or ADR discussion
3. Claude Code may generate new tasks or adjust the existing plan

## Rollback Rules

If a change causes canary failures in downstream repos:

1. Do not force-push or revert without understanding the failure
2. Create a canary investigation issue packet
3. If the upstream change was correct, fix the downstream canary
4. If the upstream change was wrong, revert it and update the ADR
