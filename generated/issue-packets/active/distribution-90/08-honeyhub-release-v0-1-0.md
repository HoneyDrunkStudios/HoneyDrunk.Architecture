---
name: HoneyHub v0.1.0 Release
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.HoneyHub
labels: ["chore", "tier-2", "ai", "distribution-90", "honeyhub"]
dependencies: ["packet:06"]
adrs: ["PDR-0011", "ADR-0091"]
source: human
generator: scope
wave: 3
initiative: distribution-90
node: honeydrunk-honeyhub
actor: agent
---

# Chore: Tag and release HoneyHub v0.1.0 (first release on the repo)

## Summary
Cut HoneyHub's first-ever release: freeze the CHANGELOG to `0.1.0`, align workspace versions, write install/quick-start docs good enough for a stranger, and prepare the GitHub Release notes. The operator pushes the `v0.1.0` tag and publishes the Release (agents never push tags). This is the artifact the demo (09), launch post (10), and submissions (11) all point at.

## Context
Distribution 90 Wave 3. The repo has never been tagged. The launch sequencing requires a stable, named version: "HoneyHub v0.1.0" is what Show HN visitors will clone. The bar for v0.1.0 is the **already-shipped** Phase 2 + checkpoint scope (packet 06) — no new features ride in under this packet. The README must let someone who has never heard of the Grid get from `git clone` to driving a real Claude Code session from their phone.

## Scope
- Repo-level `CHANGELOG.md` — freeze `## [Unreleased]` to `## [0.1.0] - <date>`.
- Workspace version alignment: `package.json` (PWA), `Cargo.toml` (bridge crates, including `crates/bridge-host`) all read `0.1.0`.
- `README.md` — stranger-grade quick start: prerequisites (Rust, Node, Claude Code CLI), `cargo run -p honeyhub-bridge-host`, `npm run dev`, pairing/connect flow, what works in v0.1.0 (claude.local full; Codex/Copilot status stated honestly), demo link placeholder (filled by packet 09's output), license statement.
- Drafted GitHub Release notes (highlights + known limitations + link to the launch post placeholder).

## Human Prerequisites
- [ ] Explicit operator **go** for the tag (the tag is permanent; gate on the demo smoke passing).
- [ ] Push the `v0.1.0` tag and publish the GitHub Release using the drafted notes (agents never push tags — invariant 27).
- [ ] Confirm the license/visibility posture for the repo is what you want strangers to see (per ADR-0039 license policy as applied at repo creation; verify, don't change, under this packet).

## Acceptance Criteria
- [ ] `CHANGELOG.md` has a `## [0.1.0] - YYYY-MM-DD` entry covering everything shipped, in Keep a Changelog format (invariant 12: repo-level CHANGELOG is mandatory and is the source for release notes).
- [ ] All workspace version fields read `0.1.0` in one commit (invariant 27, applied to this TS/Rust workspace: all projects in a solution share one version and move together; partial bumps are forbidden).
- [ ] README quick start verified by actually following it on a clean checkout (fresh clone → cockpit drives a real `claude.local` session).
- [ ] Release-notes draft committed (e.g., `docs/release-notes/v0.1.0.md`) ready for the operator to paste into the GitHub Release.
- [ ] Operator pushed `v0.1.0` and the GitHub Release is public.

## Dependencies
- `packet:06` — launch-blocking stack merged; `main` green.

## Downstream Unblocks
Packets 09 (demo records against the released version), 10 (post links the release), 11 (submissions link the release).

## Agent Handoff

**Objective:** Prepare the complete v0.1.0 release (CHANGELOG freeze, version alignment, stranger-grade README, release-notes draft); hand the tag push to the operator.
**Target:** `HoneyDrunkStudios/HoneyDrunk.HoneyHub`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 3 — the first public, named HoneyHub artifact.
- Audience shift: README readers are strangers, not Grid agents. Explain what HoneyHub is in plain terms before any Grid/internal vocabulary.

**Acceptance Criteria:** as listed above.

**Dependencies:** packet 06 Done.

**Constraints:**
- Invariant 27 (inline): "All projects in a solution share one version and move together. … Releases are triggered by pushing a git tag; **agents never push tags**."
- Invariant 12 (inline, repo-level tier): "Repo-level CHANGELOG.md … Mandatory. … Every version that ships must have an entry here. This is the source for auto-generated release notes." Rename the `## [Unreleased]` heading to the exact `## [0.1.0] - YYYY-MM-DD` form.
- No new features under this packet — docs, versions, and release mechanics only.
- README voice: plain, honest about what does not work yet (PDR-0011 honest-capability-flags `[Firm]` principle extends to docs); no em dashes; no "it's not X, it's Y" constructions.
- PR body carries `Authorship:` + `Packet:` (pr-core strict format); link this packet (invariant 32).

**Key Files:**
- `CHANGELOG.md`, `README.md`, `package.json`, `Cargo.toml` (workspace + crates), `docs/release-notes/v0.1.0.md` (new)

**Contracts:** None (no code-shape changes).
