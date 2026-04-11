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

## Blocking Relationships

After filing issues, wire native GitHub blocking relationships for every dependency listed in the Dependencies section. Do not leave dependencies as body text only.

Use the GraphQL `addBlockedBy` mutation:

```bash
gh api graphql -f query='
mutation {
  addBlockedBy(input: {
    issueId: "<blocked-issue-node-id>"
    blockingIssueId: "<blocking-issue-node-id>"
  }) {
    issue { number }
    blockingIssue { number }
  }
}'
```

Get issue node IDs with:
```bash
gh api graphql -f query='
{
  repository(owner: "HoneyDrunkStudios", name: "<repo>") {
    issues(first: 20) {
      nodes { number id }
    }
  }
}'
```

Every `Dependencies` entry in an issue body must have a corresponding `addBlockedBy` call. This surfaces the blocking chain natively in the GitHub UI and on The Hive board.

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
- [ ] Blocking relationships wired via `addBlockedBy` for every dependency listed
- [ ] Labels include type, tier, and sector
- [ ] Frontmatter includes all board fields: `wave`, `initiative`, `node`, `adrs`, `tier`
- [ ] Implementation constraints include invariant text (or a direct quoted excerpt) where the exact wording affects behavior; avoid number-only references in constraint sections
- [ ] ADR decisions relevant to implementation are summarized in the packet body with file links so an executor can verify full context quickly

## Anti-Patterns

- **Vague criteria:** "Implement the feature" — always specify what "done" looks like
- **Wrong repo:** Putting Transport work in a Kernel issue
- **Missing context:** Issues without links to ADRs or initiatives
- **Scope creep:** One issue should do one thing. Split if needed.
- **Opaque references:** Writing only "Invariant 17" or "see ADR-0005" in implementation constraints without including the relevant text/excerpt.

Execution note: ADR-0008 D8 checks out both the target repo and `HoneyDrunk.Architecture` during cloud execution. Packets should still be self-sufficient for implementation-critical constraints so execution does not depend on extra document discovery.
