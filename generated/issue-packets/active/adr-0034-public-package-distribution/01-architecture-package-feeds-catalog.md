---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0034", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0034", "ADR-0032"]
accepts: ["ADR-0034"]
wave: 1
initiative: adr-0034-public-package-distribution
node: honeydrunk-architecture
---

# Create catalogs/package-feeds.json — the approved-feeds allowlist (ADR-0034 D8)

## Summary
Create the new `catalogs/package-feeds.json` catalog — the single source of truth for the Grid's approved package feeds — keyed by `feed-id` with `url`, `owner`, `visibility`, and `consumers` fields per ADR-0034 D8, and index it so the catalog is discoverable and so ADR-0032's NuGet-leak PR check can read it as the allowlist.

## Context
ADR-0034 D8 commits the approved-feeds list to catalog form: `catalogs/package-feeds.json`, "keyed by `feed-id`, with fields `url`, `owner`, `visibility (public|private|prerelease-staging)`, and `consumers (node-ids)`." This artifact does not exist today — the Grid's feed configuration is fragmented (some Nodes on GitHub Packages, some on an internal Azure Artifacts feed). ADR-0032 (PR validation policy) flags NuGet leaks and, per ADR-0034's Context section, "presupposes a defined approved-feeds list that does not exist as a single artifact." This packet creates that artifact.

ADR-0034 D8 also states the catalog "is the single source of truth; readme tables and ADR text reference it but do not redefine it." So no feed list is duplicated into ADR text or README tables — they point at this file.

This is a docs/catalog-only packet. No code, no workflow, no .NET project. The ADR-0032 NuGet-leak check that *reads* this catalog as its allowlist is ADR-0032's own scope — not a packet in this initiative (see the dispatch plan's Out-of-scope section).

## Scope
- `catalogs/package-feeds.json` — new file.
- The catalog index — ADR-0034 D8 says the new catalog is "indexed in `catalogs/README.md`." Check whether `catalogs/README.md` exists. If it does **not** exist, this packet **unconditionally creates it** — this initiative owns the new catalog index. Author it as a short index of every file in `catalogs/` (a one-line description per catalog), with the `package-feeds.json` row included. If `catalogs/README.md` already exists, add the `package-feeds.json` row to it. Do not defer the create/add decision to discretion — the existence check is the deterministic switch.
- `initiatives/drift-report.md` / `hive-sync` note — ADR-0034's Operational Consequences says `package-feeds.json` "is a new artifact `hive-sync` (ADR-0014) must include in drift reconciliation." No code change is required for that; `hive-sync` reconciles the `catalogs/` directory generically. If `hive-sync` maintains an explicit per-catalog list, add `package-feeds.json` to it; otherwise no action.

## Proposed Implementation
Author `catalogs/package-feeds.json` with this shape (one object per approved feed):

```json
{
  "feeds": [
    {
      "feed-id": "nuget-org-public",
      "url": "https://api.nuget.org/v3/index.json",
      "owner": "HoneyDrunkStudios",
      "visibility": "public",
      "consumers": ["honeydrunk-kernel", "honeydrunk-transport", "..."]
    },
    {
      "feed-id": "github-packages-private",
      "url": "https://nuget.pkg.github.com/HoneyDrunkStudios/index.json",
      "owner": "HoneyDrunkStudios",
      "visibility": "private",
      "consumers": []
    },
    {
      "feed-id": "azure-artifacts-prerelease",
      "url": "<the existing internal Azure Artifacts feed URL — see Human Prerequisites>",
      "owner": "HoneyDrunkStudios",
      "visibility": "prerelease-staging",
      "consumers": ["..."]
    }
  ]
}
```

Field rules per ADR-0034 D8:
- `feed-id` — stable string key, unique per feed.
- `url` — the v3 feed index URL.
- `owner` — `HoneyDrunkStudios` for all three (ADR-0034 D1/D2).
- `visibility` — exactly one of `public`, `private`, `prerelease-staging`.
- `consumers` — array of Node ids from `catalogs/nodes.json` (e.g. `honeydrunk-kernel`). For `nuget-org-public`, list the 12 live public Nodes that produce packages. For `github-packages-private`, leave empty until the first private revenue Node (`HoneyDrunk.Notify.Cloud`, ADR-0027) is scaffolded. For `azure-artifacts-prerelease`, list the Nodes that currently SHA-pin pre-release builds.

The exact Azure Artifacts feed URL is not in the ADR — it is the existing internal feed used for SHA-pinned Kernel-adoption builds. See Human Prerequisites: the human supplies the URL, or the implementing agent uses a documented placeholder and flags it in the PR for the human to fill before merge. The URL is an org-internal endpoint, not a secret — committing it is acceptable (it is not credentials; see CLAUDE.md "repos public by default — never commit secrets or env-specific IDs": the feed *URL* is not a secret, but if it embeds an org/project GUID, prefer the org-name form `https://pkgs.dev.azure.com/{org}/_packaging/{feed}/nuget/v3/index.json`).

Match the JSON style of the existing catalogs (`catalogs/nodes.json`, `catalogs/relationships.json`) — two-space indent, top-level object with a single array property.

## Affected Files
- `catalogs/package-feeds.json` (new)
- `catalogs/README.md` (created if absent — this initiative owns the new catalog index; otherwise the `package-feeds.json` row is appended, per Scope)

## NuGet Dependencies
None. This packet creates a JSON catalog and a Markdown index; no .NET project is created or modified.

## Boundary Check
- [x] Catalogs live in `HoneyDrunk.Architecture`. Routing rule "catalog → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `catalogs/package-feeds.json` exists with at least the three ADR-0034 feeds: `nuget-org-public` (public), `github-packages-private` (private), `azure-artifacts-prerelease` (prerelease-staging)
- [ ] Each feed object has `feed-id`, `url`, `owner`, `visibility`, and `consumers`; `owner` is `HoneyDrunkStudios` on all; `visibility` is exactly one of `public` / `private` / `prerelease-staging`
- [ ] `consumers` arrays use Node ids from `catalogs/nodes.json` (e.g. `honeydrunk-kernel`); `github-packages-private` consumers may be empty (no private Node scaffolded yet)
- [ ] The JSON is well-formed and matches the style of the existing catalog files
- [ ] The catalog is indexed — if `catalogs/README.md` did not exist it is created (this packet owns the new index) with a one-line description per catalog file including `package-feeds.json`; if it already existed the `package-feeds.json` row is appended to it
- [ ] The Azure Artifacts feed URL is either the real internal feed URL or a clearly-flagged placeholder for the human to fill before merge
- [ ] No feed list is duplicated into ADR text or other README tables — they reference this catalog (ADR-0034 D8 single-source-of-truth rule)

## Human Prerequisites
- [ ] Provide the existing internal Azure Artifacts feed URL (the feed currently used for SHA-pinned pre-release builds during Kernel adoption cascades). If not provided before the packet runs, the agent uses a flagged placeholder and the human fills it before merge.
- [ ] Confirm the set of Nodes that currently consume the Azure Artifacts pre-release feed, so the `azure-artifacts-prerelease` `consumers` array is accurate.

## Referenced ADR Decisions
**ADR-0034 D8 — Approved feeds list lives in catalog form.** "The list of approved feeds is recorded in `catalogs/package-feeds.json` (new), keyed by `feed-id`, with fields `url`, `owner`, `visibility (public|private|prerelease-staging)`, and `consumers (node-ids)`. ADR-0032's NuGet-flag check reads this catalog as the allowlist. The catalog is the single source of truth; readme tables and ADR text reference it but do not redefine it."

**ADR-0034 D1 — Primary feed.** nuget.org under the `HoneyDrunkStudios` owner is the primary public feed. Azure Artifacts is retained as a pre-release-only staging surface — pre-release versions flow there first; stable versions land on nuget.org and are never republished back.

**ADR-0034 D2 — Private packages.** `HoneyDrunk.Notify.Cloud.*` and future private Nodes publish to GitHub Packages scoped to `HoneyDrunkStudios`.

**ADR-0034 Operational Consequences.** `catalogs/package-feeds.json` is a new artifact `hive-sync` (ADR-0014) must include in drift reconciliation.

## Constraints
- **The catalog is the single source of truth.** Do not duplicate the feed list into ADR text or README tables — those reference the catalog.
- **`visibility` is a closed enum** — exactly `public`, `private`, or `prerelease-staging`. No other value.
- **`consumers` uses canonical Node ids** from `catalogs/nodes.json`, not display names.
- The Azure Artifacts URL is an internal endpoint, not a credential — committing it is fine. Never commit a feed *token* or PAT.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0034`, `wave-1`

## Agent Handoff

**Objective:** Create `catalogs/package-feeds.json` — the approved-feeds allowlist per ADR-0034 D8 — and index it.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Establish the single-source-of-truth feed catalog that ADR-0032's NuGet-leak check will read as its allowlist (that check is ADR-0032's own scope, not a packet here).
- Feature: ADR-0034 Public Package Distribution rollout, Wave 1.
- ADRs: ADR-0034 (D8, D1, D2), ADR-0032 (the future consumer of this catalog), ADR-0014 (`hive-sync` drift reconciliation).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0034 acceptance (soft — references ADR-0034 D8 as a live rule).

**Constraints:**
- The catalog is the single source of truth; do not duplicate the feed list elsewhere.
- `visibility` is a closed enum: `public` / `private` / `prerelease-staging`.
- `consumers` uses canonical Node ids from `catalogs/nodes.json`.
- The Azure Artifacts URL is an internal endpoint, not a secret — but never commit a token/PAT.

**Key Files:**
- `catalogs/package-feeds.json` (new)
- `catalogs/README.md` (created if absent; otherwise appended to)
- `catalogs/nodes.json` (read-only — source of `consumers` Node ids)

**Contracts:** Introduces the `package-feeds.json` schema (`feed-id` / `url` / `owner` / `visibility` / `consumers`). Future consumer: ADR-0032's NuGet-leak check (built under ADR-0032's own scope).
