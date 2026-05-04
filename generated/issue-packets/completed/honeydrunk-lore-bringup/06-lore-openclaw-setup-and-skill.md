---
name: Chore
type: chore
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Lore
labels: ["chore", "human-only", "tier-1", "automation"]
dependencies: [1, 2, 4]
wave: 3
initiative: honeydrunk-lore-bringup
node: honeydrunk-lore
---

# Chore: OpenClaw setup + scheduled Lore sourcing skill

## Summary
Install and configure OpenClaw (openclaw.ai) as the sourcing engine for HoneyDrunk.Lore. Configure messaging (Telegram), AI provider (Claude), Obsidian vault link, browser tool (managed Chromium profile), one-time logins for login-walled sources (X, Discord), and the scheduled sourcing skill that walks `sourcing-playbook.md` and drops qualifying items in `raw/` every 1–2 days. Scheduled sourcing is the primary mechanism. Two on-demand Telegram triggers ("add [URL] to Lore", "what does Lore know about [topic]") are kept as a phone-friendly serendipitous-capture and query layer on top.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Lore` (local machine)

## Why human-only
OpenClaw installation, AI provider key entry, messaging-app pairing, and browser logins (X, Discord) all require UI interaction. The skill instruction files and OpenClaw config are agent-writable but only useful once the runtime is installed and authenticated.

---

## Part A — Install OpenClaw

### 1. Install on Windows
OpenClaw ships a bash install script. On Windows, run it in Git Bash or WSL:

```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

After install:
- Check the system tray for the OpenClaw icon
- Or run `openclaw status` in your terminal

If the bash install fails on the Windows setup, check openclaw.ai/docs for a Windows-native installer.

---

## Part B — Configure AI provider

### 2. Set Claude as the provider
- Settings → AI Provider → Anthropic
- Enter the Anthropic API key
- Model: current Sonnet (`claude-sonnet-4-6` as of writing) — balanced speed and quality for sourcing volume

---

## Part C — Connect Telegram

### 3. Set up the Telegram bot
- In Telegram, search `@BotFather` and create a new bot
- Copy the bot token
- OpenClaw Settings → Integrations → Telegram → paste token
- Send a test message to the bot — verify OpenClaw responds

---

## Part D — Connect the Obsidian vault

### 4. Link Obsidian
- Settings → Integrations → Obsidian
- Point at the vault root: `HoneyDrunk.Lore/`
- Verify: send "list my vault files" via Telegram → file listing returns

---

## Part E — Configure the browser tool

The browser tool drives an isolated Chromium profile that persists cookies across runs. This is what scrapes X and Discord.

### 5. Enable browser automation
Edit `~/.openclaw/openclaw.json`:

```json
{
  "browser": {
    "enabled": true,
    "defaultProfile": "openclaw",
    "profiles": {
      "openclaw": {
        "headless": true,
        "actionTimeoutMs": 60000
      }
    }
  }
}
```

Verify with the OpenClaw CLI (see docs.openclaw.ai/tools/browser for exact action syntax) that the profile is reachable and Chromium launches.

---

## Part F — One-time logins for login-walled sources

The managed profile persists cookies. Log into each login-walled source once; OpenClaw reuses the session on every scheduled run.

### 6. Log into X
1. Temporarily set `"headless": false` in the browser config so the window is visible.
2. Run an interactive browser session pointed at x.com (CLI form per OpenClaw docs).
3. Log in with the X account; complete 2FA if prompted.
4. Navigate to the curated private list URL specified in `sourcing-playbook.md` (X / Twitter section) — confirm it loads.
5. Close the browser. Revert `"headless": true`.
6. Confirm session persists: a headless `navigate` + `snapshot` against the list URL should succeed without a login redirect.

### 7. Log into Discord
For each server listed in `sourcing-playbook.md` Discord section (Anthropic, OpenAI Developer, Hugging Face, LangChain, .NET / C#):
1. With `"headless": false`, open a browser session at `discord.com/login`.
2. Log in (QR via mobile, or email/password).
3. Join each server above (if not already a member).
4. Open each server's announcement channel to confirm access.
5. Revert `"headless": true`.

---

## Part G — Build the scheduled sourcing skill

OpenClaw skills are markdown/YAML instruction files describing what OpenClaw does on trigger. Skills live in OpenClaw's skills directory (verify path with current docs).

### 8. Create the scheduled sourcing skill

```yaml
name: lore-scheduled-sourcing
description: Walk sourcing-playbook.md and drop qualifying content in HoneyDrunk.Lore/raw/

vault: HoneyDrunk.Lore
playbook_path: sourcing-playbook.md

triggers:
  - schedule: "0 3 * * *"   # daily at 03:00 local; change to "0 3 */2 * *" for every 2 days

instructions: |
  You are the Lore scheduled sourcing agent.

  Before sourcing, read sourcing-playbook.md from the vault root. It defines:
  - 12 topic categories, each with What-to-clip / What-to-skip / Sources
  - The "Sources requiring browser or audio tooling" section for login-walled and audio sources
  - Relevance criteria — apply in order: actionable, durable, in scope, deep enough

  Walk every source listed in the playbook. Mechanism by source type:

  RSS-friendly sources (most of cats 1–12):
  1. Resolve the feed URL — try common endpoints (/rss, /feed, /atom.xml) or auto-discover
     via <link rel="alternate" type="application/rss+xml"> in the source homepage <head>.
  2. Fetch the feed.
  3. For each entry newer than the last run, apply relevance criteria from the playbook.
  4. Qualifying entries: fetch full article, save to raw/ using the Output format below.

  X / Twitter (login-walled, browser tool):
  1. Use the openclaw browser profile.
  2. Navigate to the private X list URL specified in the playbook's X / Twitter section.
  3. Snapshot the timeline; collect tweets/threads newer than the last run.
  4. Apply relevance criteria. Qualifying items: save to raw/ with source_type=x.

  Discord (login-walled, browser tool):
  1. Use the openclaw browser profile.
  2. For each Discord server in the playbook, navigate to its announcement channel.
  3. Snapshot recent messages.
  4. Apply relevance criteria. Save qualifying messages to raw/ with source_type=discord
     and the channel + server name in frontmatter.

  Podcasts (audio):
  1. Fetch each podcast's RSS feed.
  2. For each new episode: download audio, transcribe via Whisper (or equivalent
     transcription path available to the runtime).
  3. Save transcript to raw/ with source_type=podcast and the original audio URL in
     frontmatter.

  Output format for every raw/ file:
    Filename: YYYY-MM-DD-source_type-slug.md
      (e.g., 2026-05-04-rss-fowler-microservices.md)
    Frontmatter:
      source:         [original URL]
      title:          [original title]
      author:         [if available]
      date_published: [original publish date if available]
      date_clipped:   [today YYYY-MM-DD]
      category:       [matched playbook category]
      source_type:    rss | x | discord | podcast
    Body: full extracted content (article, thread, message, or transcript)

  Deduplication: skip items whose source URL already appears in:
  - any existing raw/ file's frontmatter, OR
  - wiki/indexes/sources.md (already-ingested set)

  Reliability: if a single source fails (network error, expired login, parse error),
  log the failure and continue. Do NOT abort the entire run.

  Logging: at end of run, write a summary line to stdout —
  "Sourced N items: A rss, B x, C discord, D podcast" —
  for cron capture.
```

### 9. Create the on-demand override skills

Two secondary skills for phone-triggered actions:

```yaml
name: lore-add-url
description: Manual single-URL clip from Telegram
triggers:
  - "add * to Lore"
  - "add * to lore"
instructions: |
  Extract the URL from the message. Fetch the page. Apply sourcing-playbook.md
  relevance criteria. If out of scope, respond with the reason and stop. If in scope,
  save to raw/ using the same Output format as lore-scheduled-sourcing
  (source_type=clipper).
  Confirm via Telegram: "Added to Lore: [title] → raw/[filename]"
```

```yaml
name: lore-query
description: Query the Lore wiki from Telegram
triggers:
  - "what does Lore know about *"
  - "what does lore know about *"
instructions: |
  Search wiki/ for pages matching the topic. Check wiki/indexes/gaps.md for the topic.
  Respond via Telegram with a brief summary referencing relevant page filenames. If the
  topic is in gaps.md, note it as a known gap.
```

---

## Part H — Verify the schedule

### 10. Confirm cron registration
After the scheduled sourcing skill loads, confirm OpenClaw has registered the cron trigger (CLI form per current docs — typically a `schedule list` action or equivalent). The expected entry: `lore-scheduled-sourcing` running `0 3 * * *`.

If `0 3 */2 * *` (every 2 days) is preferred, edit the skill and reload.

---

## Part I — End-to-end test

### 11. Dry run the scheduled skill
- Manually trigger one run (CLI: `schedule run lore-scheduled-sourcing` or equivalent)
- Expect a summary like "Sourced 12 items: 8 rss, 3 x, 0 discord, 1 podcast"
- Inspect `raw/` — confirm filenames follow the format and frontmatter is complete

### 12. Test the on-demand triggers
- Telegram → "add [paste any relevant article URL] to Lore" — confirm a file appears in `raw/`
- Telegram → "what does Lore know about MCP" — confirm a meaningful response (will be sparse before the ingest agent has run; success here means the mechanism works, not that the wiki is full)

---

## Acceptance Criteria

**Part A–D (runtime + integrations)**
- [ ] OpenClaw installed and running on the user's machine
- [ ] Claude (Anthropic) set as AI provider with API key configured
- [ ] Telegram bot connected and responsive
- [ ] Obsidian integration pointed at the `HoneyDrunk.Lore/` vault root

**Part E–F (browser + logins)**
- [ ] Browser tool enabled in `~/.openclaw/openclaw.json` with managed `openclaw` profile
- [ ] Logged into X — private list URL accessible without login redirect when headless
- [ ] Logged into Discord — all servers in the playbook accessible

**Part G–H (skills + schedule)**
- [ ] `lore-scheduled-sourcing` skill created and registered
- [ ] `lore-add-url` and `lore-query` on-demand skills created
- [ ] Cron schedule registered (`0 3 * * *` daily, or `0 3 */2 * *` every 2 days)

**Part I (end-to-end)**
- [ ] Dry run produces files in `raw/` covering at least RSS + X (Discord/podcast may be empty if no new content that day)
- [ ] Dry run logs the summary line
- [ ] On-demand "add URL to Lore" trigger places a file in `raw/` with correct frontmatter
- [ ] On-demand "what does Lore know about X" trigger returns a meaningful response
- [ ] Out-of-scope URL test: clearly irrelevant URL is rejected via the on-demand trigger with a reason

---

## Dependencies
- Issue #1 (scaffold) — `raw/`, `wiki/indexes/sources.md` must exist
- Issue #2 (Obsidian) — vault must be configured and connected
- Issue #4 (sourcing-playbook.md) — skill reads the playbook for sources and relevance criteria

## Labels
`chore`, `human-only`, `tier-1`, `automation`

## Notes
- OpenClaw docs: openclaw.ai/docs
- Browser tool docs: docs.openclaw.ai/tools/browser
- ClawHub: openclaw.ai/clawhub
- The scheduled sourcing skill reads `sourcing-playbook.md` at runtime — updating the playbook (adding sources, refining relevance criteria) updates skill behavior without re-installing the skill
- When the playbook adds a new login-walled source, repeat Part F to log in via the managed browser
- If X (or any other login-walled source) reskins their UI and scraping breaks, re-prompt the skill instructions rather than maintaining selector code — the browser tool works on snapshots, not CSS selectors, so the skill adapts via natural-language re-prompting
- The sourcing skill is the producer; the weekly Claude Code ingest agent (packet 05) is the consumer. Both target `raw/` — neither cares which produced a file
