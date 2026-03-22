# Site Sync Rules

Rules for keeping the HoneyDrunk Studios website in sync with architecture changes.

## When to Trigger Site Sync

Generate a site-sync packet when:

1. **New Node added** — New entry in `catalogs/nodes.json`
2. **Version released** — Major or minor version bump of any Node
3. **ADR accepted** — New ADR in `/adrs/`
4. **Sector restructured** — Changes to `constitution/sectors.md`
5. **Public API changed** — Breaking changes to Abstractions packages
6. **New service deployed** — New entry in `catalogs/services.json`

Do NOT trigger site sync for:
- Patch version bumps
- Internal refactors
- Test-only changes
- CI/CD changes

## Site Sync Packet Format

Create packets in `/generated/site-sync-packets/` with this structure:

```markdown
---
target: HoneyDrunk.Studios
type: site-sync
trigger: {what caused this}
pages_affected:
  - /docs/{page}
  - /blog/{post}
priority: normal | urgent
---

# Site Sync: {Title}

## What Changed
{Description of the architecture change}

## Content Updates Needed

### Page: /docs/{page}
{What to add, update, or remove}

### Blog Post (if applicable)
{Draft content for announcement}
```

## Content Mapping

| Architecture Change | Website Impact |
|--------------------|---------------|
| New Node | New docs page, update architecture overview, blog post |
| Version release | Update version badges, changelog page, release notes |
| New ADR | Link from architecture decisions page |
| New provider | Update provider comparison table |
| Breaking change | Migration guide page, blog post |

## Naming Convention

`{date}-{change-type}-{short-description}.md`

Example: `2026-03-22-new-node-notify-announcement.md`
