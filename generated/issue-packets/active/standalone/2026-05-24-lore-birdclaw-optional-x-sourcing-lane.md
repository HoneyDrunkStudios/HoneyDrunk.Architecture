---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Lore
labels: ["feature", "tier-2", "meta", "automation"]
dependencies: []
adrs: ["ADR-0008"]
initiative: standalone
node: honeydrunk-lore
actor: Agent
---

# Feature: Add Birdclaw as an optional X sourcing lane for Lore

## Summary

Introduce a targeted, opt-in Birdclaw sourcing workflow for X/Twitter signals in HoneyDrunk.Lore, while preserving the current default policy that automated Lore sourcing remains website/RSS-first and does not source X by default.

## Target Repo

HoneyDrunkStudios/HoneyDrunk.Lore

## Motivation

Lore already documents that X/Twitter is disabled by default because browser-login scraping has been noisy and unreliable. That default should stay.

However, there is still occasional high-signal content that appears first on X. Birdclaw provides a local-first, CLI-driven, JSON-exportable capture surface that is more scriptable and less brittle than browser snapshots.

This packet adds Birdclaw as an optional lane for selective capture only, not a default crawler. The goal is to improve capture reliability for known high-value targets without reopening the old broad X ingestion pattern.

## Proposed Implementation

### 1. Document the optional Birdclaw lane in sourcing guidance

Update Lore sourcing docs to include an explicit optional workflow:

- Default remains website/RSS-first.
- Birdclaw is allowed only as a targeted capture lane when operator intent is explicit.
- Captures must resolve into durable files in raw/, same as any other source.
- Prefer canonical written source replacement when available (official blog/changelog/docs).

Suggested files to update:

- sourcing-playbook.md
- README.md

### 2. Add a Birdclaw-to-raw converter utility

Add a lightweight tooling script under tools/ that converts stable Birdclaw JSON output into Lore raw markdown files with standard frontmatter.

Script responsibilities:

- Read Birdclaw JSON input from a file or stdin.
- Normalize each item into Lore raw file format with frontmatter fields:
  - source
  - title
  - author
  - date_published
  - date_clipped
  - category
  - source_type
- Write files under raw/ with naming convention:
  - YYYY-MM-DD-birdclaw-x-{slug}.md
- Deduplicate by source URL and stable source id when present.
- Emit a concise run summary (written, skipped duplicates, failed items).

Suggested file to add:

- tools/openclaw_lore_source_birdclaw.py

### 3. Keep the existing default automation unchanged

Do not switch scheduled default sourcing from website/RSS to Birdclaw.

If prompts are updated, they should state Birdclaw is optional and operator-invoked, not default-run.

Suggested file to touch only if needed for clarity:

- tools/openclaw-lore-sourcing-prompt.md

## Affected Files

- HoneyDrunk.Lore/sourcing-playbook.md
- HoneyDrunk.Lore/README.md
- HoneyDrunk.Lore/tools/openclaw_lore_source_birdclaw.py
- HoneyDrunk.Lore/tools/openclaw-lore-sourcing-prompt.md (optional, clarity update only)

## Boundary Check

- [x] Feature is within this Node's stated responsibilities
- [x] Feature does not duplicate capabilities of another Node
- [x] No new cross-Node dependencies introduced (or cascades identified)

Notes:

- This is Lore-local sourcing policy and tooling.
- No Grid invariant changes.
- No contract or Abstractions surface changes.
- No ADR amendment required.

## Acceptance Criteria

- [ ] sourcing-playbook.md explicitly describes Birdclaw as an optional, targeted X sourcing lane.
- [ ] sourcing-playbook.md still declares website/RSS as the default automated sourcing path.
- [ ] README.md includes a short section on when and how to use the Birdclaw lane.
- [ ] tools/openclaw_lore_source_birdclaw.py exists and converts Birdclaw JSON into Lore raw markdown files with required frontmatter.
- [ ] Converter writes filenames that follow Lore raw naming conventions.
- [ ] Converter includes dedupe behavior against existing raw source URLs/ids.
- [ ] Converter outputs a run summary suitable for operator review.
- [ ] No secrets/tokens/cookies are written to raw/, wiki/, or output/.
- [ ] Existing website/RSS sourcing flow remains functional and unchanged by default behavior.

## Dependencies

- None required for implementation.
- Optional local prerequisite for operator use: Birdclaw installed on the machine running ad hoc sourcing.

## Validation Plan

1. Run converter with a small sample Birdclaw JSON export.
2. Verify expected markdown files are created under raw/.
3. Re-run with same input and confirm duplicates are skipped.
4. Confirm frontmatter fields are populated and compile-compatible with existing Lore ingest flow.
5. Confirm scheduled/default sourcing prompts still favor website/RSS unless Birdclaw lane is explicitly invoked.

## Constraints

- Do not enable broad/default X scraping.
- Do not introduce browser-login automation as the default path.
- Do not store auth artifacts in repo files.
- Keep the implementation local-first and deterministic.

## Labels

feature, tier-2, meta, automation
