# ADR-0007: `.claude/agents/` as Single Source of Truth for Agent Definitions

**Status:** Accepted
**Date:** 2026-04-09
**Deciders:** HoneyDrunk Studios
**Sector:** Meta
**Supersedes:** [ADR-0004](ADR-0004-tool-agnostic-agent-definitions.md)

## Context

[ADR-0004](ADR-0004-tool-agnostic-agent-definitions.md) established a tool-agnostic canonical agent format in `agents/canonical/` and a generator (`agents/generate.sh` + `agents/tool-mappings.json`) that projected canonical agents into tool-specific formats — primarily `.claude/agents/` and optionally `.github/agents/`.

The premise was that multiple AI surfaces (Claude Code, GitHub Copilot, OpenAI Codex) would each need their own first-class agent file format, and a capability-mapping layer would translate one source into many outputs.

In practice, the consumption model turned out simpler than the ADR assumed:

- **GitHub Copilot** discovers agents from `.claude/agents/*.md` directly. It does not require `.github/agents/*.agent.md` files. ADR-0004 already acknowledged this — the generator's default target was `.claude/agents/` only, and `--target copilot` was opt-in.
- **OpenAI Codex** does not consume per-agent files at all. It reads repo-level instructions from `AGENTS.md` and uses runtime-managed tools. No agent projection from canonical sources has ever been implemented for Codex.
- **Claude Code** is the only surface that actually consumes files from `.claude/agents/`.

This means the generator has exactly **one real output target**. The capability-mapping indirection (`read_files` → `Read`, `search_code` → `Grep`, etc.) translates from one source format into one output format. The abstraction layer buys nothing — it only adds cost:

- Every agent edit requires running `bash agents/generate.sh` before Claude Code picks it up.
- CI must run `--check` to detect stale generated files.
- Canonical files duplicate content that is already present in `.claude/agents/`.
- New contributors (human or AI) have to learn the canonical → generated indirection before they can edit an agent.

The original drift problem ADR-0004 was solving — the same agent existing in two formats with ~90% overlapping content — no longer exists. There is now exactly one format and exactly one location.

## Decision

**Agent definitions live directly in `.claude/agents/*.md`. There is no canonical layer, no generator, and no capability mapping.**

### What changes

- `agents/canonical/`, `agents/generate.sh`, and `agents/tool-mappings.json` are removed.
- `.claude/agents/*.md` becomes the authoritative source. Edit these files directly.
- The `<!-- GENERATED ... do not edit -->` header comment is removed from all agent files — they are no longer generated.
- Agent files use Claude Code's native frontmatter format (`tools:` with Claude tool names like `Read`, `Grep`, `Edit`, `Bash`, `Agent`, etc.).
- GitHub Copilot continues to discover agents from `.claude/agents/` automatically. No action required for Copilot compatibility.
- Codex continues to consume `AGENTS.md`. Guidance that should shape Codex behavior is hand-maintained there, as it already was under ADR-0004.

### What this means in practice

Editing an agent is now a one-step operation: open the file in `.claude/agents/`, make the change, commit. No generator run. No staleness check. No mapping file to update when Claude Code adds a new tool.

If a second tool ever emerges that requires a genuinely different file format and cannot consume `.claude/agents/*.md`, this decision can be revisited — either by reintroducing a generator targeted at that specific tool, or by hand-maintaining a parallel directory. Until then, YAGNI applies.

## Consequences

### Positive

- **Zero indirection.** The file Claude Code reads is the file you edit.
- **No generation step.** No pre-commit hook, no CI check, no staleness detection needed.
- **Lower onboarding cost.** A new contributor (human or AI agent) sees `.claude/agents/scope.md` and can edit it immediately, without learning a capability vocabulary or running a build script.
- **Matches actual consumption.** Copilot reads `.claude/agents/`, Claude Code reads `.claude/agents/`, Codex reads `AGENTS.md`. The directory layout now exactly reflects reality.
- **Less code to maintain.** The ~300-line Python generator, the JSON mapping file, and the bash wrapper are deleted.

### Negative

- **Agent files are now tied to Claude Code's frontmatter vocabulary.** If Claude Code renames `Grep` to something else, every agent file needs updating. This is a cheap, scripted find-and-replace when it happens — cheaper than maintaining a mapping layer against a hypothetical.
- **Adding a third tool that needs a different format requires reintroducing generation.** Accepted. We'll build the generator when we actually have two targets, not in anticipation of having them.
- **ADR-0004's "survives vendor format changes" argument is lost.** True in theory, but Claude Code's format has been stable and the cost of a future migration is bounded.

## Alternatives Considered

### Keep ADR-0004 as-is

Continue running the generator with one real target. Pays complexity cost for zero benefit. The whole point of the canonical layer was portability across tools, and we don't have multiple tools consuming agents in different formats.

### Keep canonical, drop the mapping file

Store agents in `agents/canonical/` but just copy them verbatim to `.claude/agents/` with a minimal script. Still adds an indirection for no gain — if the content is identical after "generation," the generation step is ceremony.

### Symlink `.claude/agents/` to `agents/canonical/`

Works on Unix but is fragile on Windows (the primary development environment here) and still requires a format shim because the frontmatter vocabulary differs between canonical and Claude formats.

## Migration

Completed as part of accepting this ADR:

1. Stripped the `<!-- GENERATED ... -->` header from every file in `.claude/agents/`.
2. Deleted `agents/canonical/`, `agents/generate.sh`, and `agents/tool-mappings.json`.
3. Marked ADR-0004 as Superseded and linked here.

No CI changes were required because no CI job was running `generate.sh --check` yet — ADR-0004 listed it as a future mitigation but it was never wired up.
