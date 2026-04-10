# ADR-0004: Tool-Agnostic Agent Definitions

**Status:** Superseded by [ADR-0007](ADR-0007-claude-agents-as-source-of-truth.md)
**Date:** 2026-04-08
**Superseded:** 2026-04-09
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

> **Note:** This ADR is retained for historical context. The canonical `agents/` directory and generator described below were removed on 2026-04-09. Agent definitions now live directly in `.claude/agents/`. See [ADR-0007](ADR-0007-claude-agents-as-source-of-truth.md) for rationale.

## Context

HoneyDrunk Studios uses three AI development surfaces concurrently:

1. **Claude Code** — reads agents from `.claude/agents/*.md`
2. **GitHub Copilot** — reads agents from `.github/agents/*.agent.md`
3. **OpenAI Codex** — reads repo-level instructions from `AGENTS.md` at repo root

Claude Code and GitHub Copilot both support named agent definitions. Codex does not use the same per-agent file model; it consumes repo-level instructions from `AGENTS.md` and exposes runtime-managed tools and delegation primitives.

The core guidance for many agents — what to research, how to decompose, what to output — is still largely shared across surfaces. The file format and invocation model differ, however, so the "same agent in every tool" assumption only fully holds for tools that support first-class agent definitions.

This creates two problems immediately for Claude/Copilot, and a third consistency problem for Codex:

**Duplication.** The same agent (e.g., `scope`) exists in `.claude/agents/scope.md` and `.github/agents/scope.agent.md` with ~90% identical content. Changes must be made in two places. They drift. The `scope` agents already diverge: Claude's version says "Codex Handoff," Copilot's says "Agent Handoff." The Architecture repo has 5 agents × 2 tools = 10 files for 5 logical agents.

**Discovery overlap.** GitHub Copilot discovers agents from both `.github/agents/` and `.claude/agents/`. When both directories contain agents, Copilot displays duplicates in its agent picker. This means `.github/agents/` is redundant — Copilot can consume Claude-format agents from `.claude/agents/` directly. The generation target for Copilot-specific files is therefore unnecessary; only `.claude/agents/` needs to be generated.

**Codex drift.** Codex cannot consume `.claude/agents/*.md` or `.github/agents/*.agent.md` directly, so any shared guidance that should apply to Codex must be duplicated manually into `AGENTS.md` unless it is also generated from a canonical source.

As the AI sector (Agents, Capabilities, Flow) comes online, the number of agents will grow significantly. Maintaining N agents × M tools with manual synchronization does not scale — especially for a solo developer.

This problem extends beyond HoneyDrunk. Any team using multiple AI tools faces the same interop challenge. The agent's *skill logic* is a knowledge artifact. The tool-specific wiring is a deployment concern.

## Decision

**Agent definitions are maintained in a canonical, tool-agnostic location. Tool-specific projections are generated from that source.**

### Canonical Agent Format

Each agent lives in `agents/canonical/{name}.md` within the Architecture repo (and within individual repos for repo-scoped agents). The canonical format uses a superset schema for agent-capable tools, while still being usable as source material for Codex-facing instruction generation:

```markdown
---
name: scope
description: >-
  Scope and plan work for the HoneyDrunk Grid. Decomposes features, bugs, and
  initiatives into actionable tasks with issue packets and agent handoffs.
capabilities:
  - read_files
  - search_code
  - search_files
  - edit_files
  - write_files
  - run_commands
  - sub_agent
delegates_to:
  - adr-composer
  - site-sync
---

# Scope

{Tool-agnostic body — the actual agent instructions}
```

Key design choices:

- **`capabilities` replaces `tools`.** Capabilities are semantic (what the agent needs to do), not strictly operational. Multiple capabilities may map to the same tool primitive in a given surface (e.g., `search_code` and `search_files` both map to Copilot's `search`). The generator maps capabilities to each tool's vocabulary.
- **`delegates_to` replaces tool-specific agent references.** Lists other canonical agents this agent may invoke.
- **The body is tool-agnostic.** No references to specific tool names like `Read`, `Grep`, `search`, or `edit`. Instead, the body describes actions in natural language ("read the file," "search the codebase"). LLMs understand intent regardless of tool vocabulary.
- **Tool-specific phrasing is avoided.** Instead of "invoke `@scope`" (Copilot syntax) or "use the Agent tool" (Claude syntax), write "delegate to the scope agent."

### Capability Mapping

A versioned mapping file (`agents/tool-mappings.json`) translates capabilities to each agent-capable tool's **frontmatter vocabulary** — the values that appear in the `tools:` list of generated agent files. These are not the same as the underlying function names the tool uses at runtime (e.g., Copilot's frontmatter says `search` but the runtime functions are `grep_search`, `semantic_search`, `file_search`). The mapping targets the authoring layer, not the execution layer.

```json
{
  "version": 1,
  "capabilities": {
    "read_files":    { "claude": "Read",      "copilot": "read" },
    "search_code":   { "claude": "Grep",      "copilot": "search" },
    "search_files":  { "claude": "Glob",      "copilot": "search" },
    "edit_files":    { "claude": "Edit",      "copilot": "edit" },
    "write_files":   { "claude": "Write",     "copilot": "edit" },
    "run_commands":  { "claude": "Bash",      "copilot": "terminal" },
    "sub_agent":     { "claude": "Agent",     "copilot": "agent" },
    "web_access":    { "claude": "WebSearch", "copilot": "web" },
    "task_tracking": { "claude": "TodoWrite", "copilot": "todo" }
  }
}
```

### Generation

A generator script (`agents/generate.sh`) reads canonical agents and produces the currently implemented projections:

| Output | Location | Format |
|--------|----------|--------|
| Claude Code agents | `.claude/agents/{name}.md` | YAML frontmatter with `tools:` list |
| Copilot agents (optional) | `.github/agents/{name}.agent.md` | Copilot frontmatter via `--target copilot` |

GitHub Copilot discovers agents from `.claude/agents/` automatically, so no separate Copilot-specific generation is needed by default. The generator supports `--target copilot` or `--target all` if explicit Copilot-format files are needed.

OpenAI Codex uses repo-level instructions from `AGENTS.md`, but that projection is not produced by the generator today. `AGENTS.md` is hand-maintained. If Codex projection from canonical sources is added later, this ADR should be updated to reflect the implemented output.

Generated files include a header comment:

```markdown
<!-- GENERATED — do not edit. Source: agents/canonical/{name}.md -->
```

### Validation

The generator validates each canonical agent before producing output:

- **Required frontmatter fields** — `name`, `description`, `capabilities` must be present.
- **Capability resolution** — every entry in `capabilities` must exist in `tool-mappings.json`. Unknown capabilities fail the build.
- **Delegate resolution** — every entry in `delegates_to` must correspond to another canonical agent file in the same scope.
- **Output diff check** — CI can compare generated files against committed versions to detect manual edits to generated files or stale output from a forgotten generation run.

### Versioning

`tool-mappings.json` is versioned via its `version` field. When a tool adds new frontmatter capabilities or changes its vocabulary, the mapping is updated and the version is bumped. Generated files include the mapping version they were produced from, enabling staleness detection.

### Directory Structure

```
agents/
  canonical/
    adr-composer.md
    scope.md
    netrunner.md
    refine.md
    review.md
    site-sync.md
    pdr-composer.md
  tool-mappings.json
  generate.sh
skills/
  canonical/
    honeyhub-domain.SKILL.md
    grid-topology.SKILL.md
.claude/agents/          ← generated (Copilot also discovers these)
.claude/skills/          ← copied or generated
AGENTS.md                ← optionally generated from shared guidance
```

### For Individual Repos

Repos that define their own agents follow the same pattern:

```
agents/
  canonical/
    my-repo-agent.md
  tool-mappings.json     ← or inherit from Architecture
.claude/agents/          ← generated (Copilot also discovers these)
```

Repos can inherit `tool-mappings.json` from the Architecture repo or override it locally.

### Escape Hatches

Some tool-specific behavior genuinely cannot be expressed tool-agnostically:

- **Claude Code's `Agent` tool** supports `subagent_type`, `isolation`, and `model` parameters that Copilot doesn't have.
- **Copilot's `agents:` frontmatter** enables agent-to-agent delegation syntax that Claude handles differently.
- **Codex has no repo-authored named-agent format.** Delegation, tool availability, and execution behavior are runtime concerns, so Codex must consume projections as general instructions rather than as first-class generated agents.

For these cases, the canonical format supports optional tool-specific overrides in the frontmatter:

```yaml
overrides:
  claude:
    tools:
      - Agent(subagent_type=Explore)
  copilot:
    agents:
      - adr-composer
```

The generator merges overrides into the tool-specific output. This keeps most of the guidance generic while allowing the parts that genuinely differ to stay explicit.

### Skills: The Lighter Sibling

This ADR primarily addresses **agents** (named execution roles with distinct invocation). The same multi-tool problem applies to **skills** (knowledge packs and workflow modules that enhance understanding), but skills are easier to share because they are primarily knowledge artifacts rather than execution identities.

#### Agents vs Skills

| | Agents | Skills |
|---|---|---|
| **Purpose** | Specialized execution roles with distinct behavior | Reference knowledge and workflow guidance |
| **Invocation** | Named, tool-native (`@scope`, `/skill-name`) | Auto-matched by description, or manually invoked |
| **Examples** | `@scope`, `@review`, `@adr-composer` | "HoneyHub domain model", "Grid topology", "API conventions" |
| **Generation needed** | Always — frontmatter and tool vocabulary differ | Often not — many skills can share content directly |

#### Skill Sharing Model

Skills are primarily `name` + `description` + markdown body. When a skill uses only this common subset, Claude and Copilot can often share the same content with minimal path/layout adaptation — no generation needed.

**Canonical skill format:**

```markdown
---
name: honeyhub-domain
description: >-
  Domain model for HoneyHub control plane — entities, relationships, lifecycles.
  USE FOR: understanding Studio/Project/Directory/Node/Capability entities.
---

# HoneyHub Domain Model
{Domain knowledge here}
```

**Directory structure:**

```
skills/
  canonical/
    honeyhub-domain.SKILL.md
    grid-topology.SKILL.md
    adr-authoring.SKILL.md
.claude/skills/                  ← copied or generated
  honeyhub-domain/
    SKILL.md
.github/skills/                  ← copied or generated
  honeyhub-domain.SKILL.md
```

#### When Skills Need Generation

Generation is only required when a skill uses tool-specific features:

- **Claude-specific:** Tool allowlists with Claude tool names, subagent controls, dynamic context injection, execution lifecycle metadata
- **Copilot-specific:** Different discovery paths, different instruction-loading behavior, different metadata expectations

For these cases, the same `skills/canonical/` → generated output pattern applies, and the generator can be extended to handle skills alongside agents.

#### Codex and Skills

Codex supports skills, but not as repo-local discovery from a `SKILL.md` file. Codex skills are **environment-level** — useful for behavior across many repos. For repo-specific skill-like content, Codex consumes:

- `AGENTS.md` — repo-level instructions
- Referenced playbooks (e.g., `agents/canonical/`)
- True Codex skills installed in the Codex environment

This means skill content from `skills/canonical/` can inform Codex behavior, but the projection path is through `AGENTS.md` or environment configuration, not through a generated skill file.

## Consequences

### Positive

- **Single source of truth.** Each agent is authored once. Changes propagate to all tools via generation.
- **No more duplicates.** Only `.claude/agents/` is generated. Copilot discovers agents there alongside Claude Code, so both tools share one set of generated files.
- **Codex stays aligned.** Guidance that should shape Codex behavior can be projected into `AGENTS.md` from the same canonical source instead of being hand-maintained separately.
- **New agent-capable tool adoption is cheap.** Adding a fourth tool that supports named agent definitions (e.g., Cursor, Windsurf) means adding a column to `tool-mappings.json` and a generation target. Tools with different consumption models (like Codex) require a custom projection — still cheaper than hand-maintaining duplicates, but not a one-line addition.
- **Agent logic is portable.** The canonical format is a knowledge artifact that survives any individual tool's format changes.
- **Consistency is enforced.** Agents can't drift between tools because they share one source.

### Negative

- **Generation step required.** Editing an agent now requires running the generator before the tool picks it up. Mitigated by a pre-commit hook or CI check.
- **Abstraction cost.** Writing "search the codebase" instead of "use Grep" is slightly less precise. Mitigated by LLMs being good at interpreting intent, and by the capability mapping handling tool vocabulary.
- **Codex projection is lossy.** `AGENTS.md` can carry shared guidance, but it cannot fully reproduce named-agent UX, frontmatter semantics, or per-agent discoverability.
- **Not an industry standard.** No existing convention for tool-agnostic agent definitions exists. We're defining one. This may need revision as tools evolve.

## Alternatives Considered

### Keep separate agents per tool

The status quo. Each tool gets its own hand-maintained agent. This works at 5 agents × 2 tools but fails at 20 agents × 3 tools. Already causing duplicates and drift.

### Use one tool's format as canonical

Pick Claude Code's format and make Copilot/Codex adapt. This couples the canonical format to one vendor. If Claude Code changes its format, every agent needs updating. A tool-agnostic format survives vendor changes.

### Symlinks or includes

Symlink `.github/agents/scope.agent.md` → `agents/canonical/scope.md`. This doesn't work because the formats differ — Claude and Copilot need different frontmatter. The body is the same, but the wiring is not.

### Runtime agent registry

Build a system that serves agent definitions dynamically. Over-engineered for the current scale. Flat files with generation are simpler, version-controlled, and work offline.
