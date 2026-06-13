# Issue Authoring Rules

Rules for agents when generating GitHub Issues or work items.

## Structure

Every issue must include:

1. **Title** — Action-oriented, starts with a verb. Max 80 characters.
2. **Summary** — One sentence describing what and why.
3. **Context** — Why this is needed now. Link to ADR, initiative, or upstream change.
4. **Scope** — Which packages, files, or interfaces are affected.
5. **Acceptance Criteria** — Checkboxes. Specific and verifiable.
6. **Labels** — At minimum: type (`feature`, `bug`, `chore`), tier (`tier-1`, `tier-2`, `tier-3`), sector.
7. **Dependencies** — Other issues or PRs that must complete first.

## Packet Lifecycle and Frontmatter

Work items authored after ADR-0043 acceptance use the three-state lifecycle:

- `generated/work-items/proposed/` — agent-generated or draft packets awaiting human triage. Not filed.
- `generated/work-items/active/` — human-promoted packets ready for `file-issues` and GitHub issue creation.
- `generated/work-items/completed/` — closed packets moved by `hive-sync`.

Agents write new backlog-generation packets to `proposed/` only. A human moves a packet to `active/` when it is selected for execution. `hive-sync` is the only agent that moves packets from `active/` to `completed/`.

Every new packet must carry:

- `source:` one of `strategic`, `tactical`, `opportunistic`, `reactive`, or `human`.
- `generator:` the agent or person that produced the packet, for example `scope`, `node-audit`, `product-strategist`, `hive-sync`, `netrunner`, `codex`, or `human`.
- `priority:` only when useful for triage. Use `urgent` for high+ CVE, production incident, or canary-failure-past-grace reactive packets.

## Blocking Relationships

The `dependencies:` array in packet frontmatter is the **canonical, machine-readable** source of blocking relationships. The body's `## Dependencies` section is human narrative explaining *why* — it is not parsed by the filing pipeline.

### `dependencies:` schema

Each entry must use one of two qualified reference forms:

- **`"work-item:NN"`** — another packet in the **same initiative folder**, identified by its two-digit ordinal prefix (or `NN` + suffix letter, e.g. `"work-item:07a"`). Resolved at filing time once the referenced packet has a manifest entry.
  - Example: `dependencies: ["work-item:01", "work-item:04"]`
- **`"{Repo}#N"` or `"{owner}/{repo}#N"`** — already-filed issue in another repo. Bare `Repo` short-names expand to `HoneyDrunkStudios/HoneyDrunk.{Repo}` (so `"Architecture#9"` → `HoneyDrunkStudios/HoneyDrunk.Architecture#9`).
  - Example: `dependencies: ["work-item:01", "Architecture#9"]`

Forbidden — these were ambiguous and silently broke the wiring step:

- Bare integers: `dependencies: [1, 2]`
- Narrative strings: `dependencies: ["Issue #1 (scaffold)"]` or `dependencies: ["Architecture#NN — ADR text (packet 01)"]`
- Filename slugs: `dependencies: ["01-foo-bar"]`

The filing pipeline (`HoneyDrunk.Actions/scripts/file-work-items.sh`) consumes this field, resolves each entry to an issue node ID, then calls `addBlockedBy` so the relationship surfaces natively in the GitHub UI and on The Hive board. Any unresolvable entry produces a `::warning::` in the workflow log; the build does not fail, so check the summary on every run.

## Naming Convention for Work Items

`{YYYY-MM-DD}-{repo-short-name}-{kebab-case-description}.md`

Examples:
- `2026-03-22-kernel-add-websocket-context-mapper.md`
- `2026-03-22-vault-hashicorp-provider.md`
- `2026-03-22-cross-repo-kernel-050-upgrade.md`

## Quality Checks

Before finalizing an work item:

- [ ] Title is action-oriented and under 80 characters
- [ ] Acceptance criteria are specific (not "works correctly")
- [ ] Target repo is correct per routing rules
- [ ] Boundary check confirms the work belongs in the target repo
- [ ] Dependencies are listed if this is part of a cross-repo change
- [ ] Blocking relationships wired via `addBlockedBy` for every dependency listed
- [ ] Labels include type, tier, and sector
- [ ] Frontmatter includes all board fields: `wave`, `initiative`, `node`, `adrs`, `tier`
- [ ] Frontmatter includes `source` and `generator`; agent-generated packets land in `proposed/` until a human promotes them
- [ ] Acceptance criteria include a repo-level CHANGELOG.md update for any shipped change, using a new version entry when this packet is the bumping packet and appending to the existing solution entry otherwise
- [ ] Acceptance criteria include per-package CHANGELOG.md update only for packages with actual changes (no noise entries for alignment bumps)
- [ ] Acceptance criteria include README.md update if public API surface or installation changes
- [ ] New projects/packages include both CHANGELOG.md and README.md creation in acceptance criteria
- [ ] Implementation constraints include invariant text (or a direct quoted excerpt) where the exact wording affects behavior; avoid number-only references in constraint sections
- [ ] ADR decisions relevant to implementation are summarized in the packet body with file links so an executor can verify full context quickly

## Anti-Patterns

- **Vague criteria:** "Implement the feature" — always specify what "done" looks like
- **Wrong repo:** Putting Transport work in a Kernel issue
- **Missing context:** Issues without links to ADRs or initiatives
- **Scope creep:** One issue should do one thing. Split if needed.
- **Opaque references:** Writing only "Invariant 17" or "see ADR-0005" in implementation constraints without including the relevant text/excerpt.

Execution note: ADR-0008 D8 checks out both the target repo and `HoneyDrunk.Architecture` during cloud execution. Packets should still be self-sufficient for implementation-critical constraints so execution does not depend on extra document discovery.
