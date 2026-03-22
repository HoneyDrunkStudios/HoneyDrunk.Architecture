# Generated Site Sync Packets

This directory contains generated content update packets for the HoneyDrunk Studios website.

Files here are **ephemeral** — they can be deleted after the updates are applied.

## Naming Convention

`{YYYY-MM-DD}-{change-type}-{short-description}.md`

## Workflow

1. Architecture change triggers site sync (see `/routing/site-sync-rules.md`)
2. Agent generates packet with content and target pages
3. Human or agent applies updates to HoneyDrunk.Studios repo
4. Packet is deleted or archived
