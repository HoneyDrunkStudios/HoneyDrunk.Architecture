# Execution Rules

How agents should execute work after routing.

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

When handing off work to another agent or human:

1. Generate the artifact in `/generated/`
2. Include a summary section at the top with:
   - What this is (issue, ADR, site-sync)
   - Target repo and branch
   - Prerequisites (other PRs that must merge first)
   - Estimated tier and complexity
3. The receiving agent should validate the artifact against repo boundaries before executing

## Rollback Rules

If a change causes canary failures in downstream repos:

1. Do not force-push or revert without understanding the failure
2. Create a canary investigation issue packet
3. If the upstream change was correct, fix the downstream canary
4. If the upstream change was wrong, revert it and update the ADR
