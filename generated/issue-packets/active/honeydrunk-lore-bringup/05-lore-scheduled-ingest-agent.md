---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Lore
labels: ["feature", "tier-2", "automation"]
dependencies: [1, 2]
wave: 3
initiative: honeydrunk-lore-bringup
node: honeydrunk-lore
---

# Feature: Scheduled ingest â€” daily agent to auto-compile raw/ sources

## Summary
Set up a Claude Code scheduled remote agent (via CronCreate) that runs daily, checks `raw/` for sources not yet reflected in `wiki/`, and runs the ingest operation for each. This eliminates the manual step of asking Claude to compile after clipping â€” content flows in via Web Clipper, the agent processes it overnight.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Lore`

## Motivation
The wiki compounds only if compilation is frictionless. Without automation, the workflow is: clip article â†’ remember to open Claude Code â†’ ask it to compile. That friction causes `raw/` to accumulate unprocessed sources. The scheduled agent removes the "remember to compile" step entirely â€” you clip, it compiles.

Claude Code's CronCreate creates a remote trigger that runs on a cron schedule. The agent wakes up, reads `raw/` against `wiki/indexes/sources.md`, ingest any unprocessed files, and commits the result. The next time you open Obsidian, new wiki pages are already there.

## How it works

### Detection: what counts as "unprocessed"
A source in `raw/` is unprocessed if its filename does not appear in `wiki/indexes/sources.md`. The ingest operation (defined in `CLAUDE.md`) is responsible for adding a source entry to `sources.md` after compiling it. This creates a simple, inspectable record: if it's in `sources.md`, it's been compiled.

### Agent flow
1. Read `wiki/indexes/sources.md` â€” build a set of processed filenames
2. List all files in `raw/` â€” subtract processed set
3. For each unprocessed file: run the Ingest operation as defined in `CLAUDE.md`
4. After all ingest passes: rebuild `wiki/indexes/topics.md` and update backlinks
5. If any new pages were created: commit to `main` with message `chore: ingest [n] new sources`
6. If nothing new: exit silently (no empty commits)

### Schedule
Daily at 06:00 local time (or configure to preference). Running at start-of-day means new wiki pages are ready when you open Obsidian in the morning.

### Future extensions (v2 hook layer â€” not in scope for this issue)
The daily trigger is the first of several event-driven hooks the wiki grows toward (see the "Extensions (v2)" section in `CLAUDE.md`, sourced from https://gist.github.com/rohitg00/2067ab416f7bbe447c1977edaaa681e2). When volume or noise warrants it, file follow-up issues for:
- **Weekly lint + consolidation trigger** â€” runs the Lint operation with retention decay, promotes reinforced claims, resolves contradictions
- **Crystallize-on-query hook** â€” when a query output scores above the quality threshold, file it back into `wiki/` automatically
- **Contradiction check on write** â€” before any ingest commit, scan for conflicting claims and attempt auto-resolution
- **Session-end digest** â€” compress in-session observations into an episodic entry

None of these are built now. They are listed so future agents understand the trajectory and do not rebuild the daily trigger as a monolith when the hook layer arrives.

## Proposed Implementation

### Step 1: Configure the scheduled agent via CronCreate
Use the Claude Code `/schedule` skill or CronCreate directly to create a scheduled remote trigger on `HoneyDrunkStudios/HoneyDrunk.Lore`:

```
Cron: 0 6 * * *   (daily at 06:00)
Repo: HoneyDrunkStudios/HoneyDrunk.Lore
Branch: main
Prompt: (see agent prompt below)
```

### Agent prompt (to be configured in the trigger)
```
You are the Lore ingest agent. Your job is to compile any unprocessed sources in raw/ into the wiki.

Steps:
1. Read wiki/indexes/sources.md to get the list of already-processed files.
2. List all files in raw/ (exclude .gitkeep).
3. For each file in raw/ NOT present in sources.md:
   a. Follow the Ingest operation defined in CLAUDE.md
   b. Create or update the relevant wiki/ pages
   c. Add the filename to wiki/indexes/sources.md
4. After processing all new sources, rebuild wiki/indexes/topics.md backlinks.
5. If any wiki/ files were created or modified:
   - Stage all changes in wiki/
   - Commit with: "chore: ingest [n] new sources (YYYY-MM-DD)"
6. If nothing was processed, exit without committing.

Read CLAUDE.md before starting â€” it defines the exact ingest behavior.
```

### Step 2: Update CLAUDE.md with a sources.md contract
Add a note to the Ingest operation in CLAUDE.md clarifying the contract:
> After ingesting a source, append its filename (not full path) to `wiki/indexes/sources.md` under a `## Processed` heading. This is how the scheduled agent knows it has been compiled. Do not add a source entry until ingestion is complete.

### Step 3: Update wiki/indexes/sources.md stub
Update the stub created in issue #1 to include the expected heading structure:
```markdown
# Sources Index

## Processed
<!-- Filenames of raw/ sources that have been compiled into wiki/ -->

## Pending
<!-- Optional: manually flag sources for priority ingest -->
```

## Acceptance Criteria
- [ ] Scheduled remote trigger created via CronCreate, running daily at 06:00
- [ ] Agent prompt reads CLAUDE.md before operating (not hardcoded behavior)
- [ ] `wiki/indexes/sources.md` has the `## Processed` heading contract
- [ ] CLAUDE.md Ingest operation updated with sources.md append contract
- [ ] Test run: manually trigger the agent with one file in `raw/` â€” verify wiki page created + sources.md updated + commit made
- [ ] Test run: trigger again with no new files â€” verify no empty commit

## Affected Files
- `CLAUDE.md` (update Ingest operation â€” sources.md contract)
- `wiki/indexes/sources.md` (update stub with heading structure)
- Claude Code settings (new scheduled trigger via CronCreate â€” not a repo file)

## Boundary Check
- [x] Agent reads CLAUDE.md for behavior â€” not hardcoded, easy to update
- [x] sources.md is the only state the agent needs â€” simple, inspectable, no database
- [x] Commits to main directly â€” acceptable for a solo dev wiki repo
- [x] No .NET code, no infrastructure dependencies

## Dependencies
- Issue #1 (scaffold) â€” CLAUDE.md and `wiki/indexes/sources.md` must exist
- Issue #2 (Obsidian + Web Clipper) â€” ingest is only useful once content flows in

## Labels
`feature`, `tier-2`, `automation`

## Agent Handoff

**Objective:** Configure the CronCreate scheduled trigger and update CLAUDE.md + sources.md with the sources contract.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Lore`, branch from `main`

**Context:**
- Lore is a flat-file LLM-compiled wiki (see CLAUDE.md after issue #1 is complete)
- The scheduled agent is the automation layer that removes friction from the ingest workflow
- Detection of unprocessed sources is done via `wiki/indexes/sources.md` â€” simple filename list
- CronCreate creates a Claude Code remote trigger; use the `/schedule` skill to configure it

**Acceptance Criteria:**
- [ ] As listed above

**Constraints:**
- Agent prompt must reference CLAUDE.md â€” do not hardcode ingest behavior in the prompt
- No empty commits â€” agent exits silently if nothing new to process
- sources.md is append-only for the agent; never delete processed entries
- Commit message format: `chore: ingest [n] new sources (YYYY-MM-DD)`

**Key Files:**
- `CLAUDE.md` (update)
- `wiki/indexes/sources.md` (update stub)
- CronCreate trigger (configured via `/schedule` skill, not a repo file)