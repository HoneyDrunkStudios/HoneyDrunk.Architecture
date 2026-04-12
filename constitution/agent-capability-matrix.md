# Agent Capability Matrix

Quick-reference card for all Claude Code agents in `.claude/agents/`. Use this to self-route before loading individual agent definitions.

## The Agents

| Agent | Trigger | Consumes | Produces | Does NOT do |
|-------|---------|----------|----------|-------------|
| **scope** | New work to decompose | Goal/user request, ADRs, catalogs, repo boundaries | Issue packets, dispatch plan, handoff | Execute work, write code, open PRs |
| **adr-composer** | New architectural decision needed | Context, existing ADRs for precedent | ADR draft in `generated/adr-drafts/` | Accept/reject decisions, file issues |
| **pdr-composer** | New product decision needed | Context, existing PDRs for precedent | PDR draft in `generated/pdr-drafts/` | Scope follow-up work, file issues |
| **netrunner** | Cross-repo discovery needed | Keyword/goal, `catalogs/relationships.json`, `catalogs/nodes.json`, `routing/repo-discovery-rules.md` | Repo list + dependency chain + impact scope | Generate packets, make decisions |
| **file-issues** | Packets ready to file as GitHub Issues | Issue packets from `generated/issue-packets/active/` | GitHub Issues in target repos (via gh CLI) | Edit packets post-filing, make decisions |
| **review** | PR opened or execution completed | PR diff, issue packet, ADR constraints | Review comments, pass/fail verdict | Merge, approve in GitHub UI |
| **refine** | Draft exists, needs iteration | Draft doc (ADR, PDR, packet, design), feedback | Revised draft | Author from scratch, make binding decisions |
| **site-sync** | Repo release or content update | Release notes, ADRs, repo state | Site-sync packet in `generated/site-sync-packets/` | Publish to website directly |

---

## Decision Tree: Which Agent?

```
Is there an architectural trade-off to record?
  → yes → adr-composer
  
Is there a product/feature decision to record?
  → yes → pdr-composer

Do I need to understand which repos are affected by a change?
  → yes → netrunner (then scope if work follows)

Do I need to decompose a goal into executable issue packets?
  → yes → scope

Are packets already written and ready to become GitHub Issues?
  → yes → file-issues

Is there a draft that needs iteration/improvement?
  → yes → refine

Has a PR been opened and needs a review pass?
  → yes → review

Did a Node release something that the website should announce?
  → yes → site-sync
```

---

## Execution Rules

These apply to all agents:

- **Claude Code agents plan and generate artifacts; they do not execute code changes.** Execution is Codex or Copilot.
- **Agents do not modify files inside other repos directly.** Cross-repo work goes through issue packets → GitHub Issues → Codex.
- **Agents do not make binding architectural decisions alone.** ADR drafts go to the developer for review before Accepted status.
- **Agents do not push to remote.** No `git push`, no `gh pr create` except `file-issues` (which is authorized for `gh issue create`).

---

## Context Load Order (all agents)

Before any work, load in this order:

1. `constitution/manifesto.md`
2. `constitution/terminology.md`
3. `constitution/invariants.md`
4. `constitution/sectors.md`
5. `routing/request-types.md` → classify the request
6. Agent-specific context (see below)

### Agent-specific additional context

| Agent | Additional files |
|-------|----------------|
| scope | `catalogs/relationships.json`, `catalogs/nodes.json`, `routing/execution-rules.md`, `repos/{target}/boundaries.md`, `repos/{target}/invariants.md`, issue template from `issues/templates/` |
| adr-composer | Existing ADRs in `ADRs/` for format and precedent |
| pdr-composer | Existing PDRs in `PDRs/` for format and precedent |
| netrunner | `catalogs/relationships.json`, `catalogs/nodes.json`, `routing/repo-discovery-rules.md` |
| file-issues | `generated/issue-packets/active/` dispatch plan, `copilot/issue-authoring-rules.md` |
| review | ADRs referenced in packet frontmatter, `constitution/invariants.md` |
| refine | The draft being refined; its governing ADR/PDR if applicable |
| site-sync | `routing/site-sync-rules.md`, `generated/site-sync-packets/` |

---

## Artifact Map

```
Goal / User Request
  │
  ├─ adr-composer → generated/adr-drafts/{slug}.md
  ├─ pdr-composer → generated/pdr-drafts/{slug}.md
  │
  ├─ netrunner   → [verbal impact analysis — no file output]
  │
  └─ scope       → generated/issue-packets/active/{initiative}/
                      ├─ dispatch-plan.md
                      ├─ handoff-{wave}.md
                      ├─ 01-{repo}-{description}.md
                      └─ ...
                          │
                          └─ file-issues → GitHub Issues in target repos
                                              │
                                              └─ Codex / Claude Agent SDK
                                                    │
                                                    └─ PR → review → merged
                                                                │
                                                                └─ site-sync → generated/site-sync-packets/
```
