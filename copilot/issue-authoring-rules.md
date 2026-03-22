# Issue Authoring Rules

Rules for agents when generating GitHub Issues or issue packets.

## Structure

Every issue must include:

1. **Title** — Action-oriented, starts with a verb. Max 80 characters.
2. **Summary** — One sentence describing what and why.
3. **Context** — Why this is needed now. Link to ADR, initiative, or upstream change.
4. **Scope** — Which packages, files, or interfaces are affected.
5. **Acceptance Criteria** — Checkboxes. Specific and verifiable.
6. **Labels** — At minimum: type (`feature`, `bug`, `chore`), tier (`tier-1`, `tier-2`, `tier-3`), sector.
7. **Dependencies** — Other issues or PRs that must complete first.

## Naming Convention for Issue Packets

`{YYYY-MM-DD}-{repo-short-name}-{kebab-case-description}.md`

Examples:
- `2026-03-22-kernel-add-websocket-context-mapper.md`
- `2026-03-22-vault-hashicorp-provider.md`
- `2026-03-22-cross-repo-kernel-050-upgrade.md`

## Quality Checks

Before finalizing an issue packet:

- [ ] Title is action-oriented and under 80 characters
- [ ] Acceptance criteria are specific (not "works correctly")
- [ ] Target repo is correct per routing rules
- [ ] Boundary check confirms the work belongs in the target repo
- [ ] Dependencies are listed if this is part of a cross-repo change
- [ ] Labels include type, tier, and sector

## Anti-Patterns

- **Vague criteria:** "Implement the feature" — always specify what "done" looks like
- **Wrong repo:** Putting Transport work in a Kernel issue
- **Missing context:** Issues without links to ADRs or initiatives
- **Scope creep:** One issue should do one thing. Split if needed.
