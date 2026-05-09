---
name: Repo Feature
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-1", "docs", "infrastructure", "adr-0029"]
dependencies: []
adrs: ["ADR-0029"]
wave: 1
initiative: adr-0029-cloudflare-dns-rollout
node: honeydrunk-architecture
---

# Chore: Add transfer-in-flight notes to GoDaddy + Cloudflare vendor-inventory rows

## Summary
Add a small transitional edit to `infrastructure/vendor-inventory.md`: annotate the GoDaddy and Cloudflare rows so the catalog truthfully reflects "registrar transfer in flight per ADR-0029." Per-domain row-state flips happen inside each migration packet (P4, P5a, P5b). The closing edit at the end of Wave 3 (last P5 packet's PR) removes the GoDaddy row entirely once the last domain drains.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0029 commits the Grid to Cloudflare as registrar, authoritative DNS, and edge platform of choice. The vendor inventory is the catalog source of record for vendor relationships. The naive approach — collapse the GoDaddy row out and rewrite the Cloudflare row to "registrar + DNS + edge" in one Wave 1 edit — produces a falsified catalog for the multi-week transfer window: GoDaddy still holds two of three domains until P5a / P5b land, and saying otherwise on day one is the same kind of catalog drift the ADR's If-Accepted contract is meant to prevent ("do not accept and leave the catalogs stale").

The right shape is a **state machine across the rollout**:

- **Wave 1 (this packet):** annotate both rows with "transfer-in-flight per ADR-0029 (in progress; per-domain state on each migration packet)." No row dropped, no scope change to the Cloudflare row beyond the note.
- **Wave 2 (P4 — `honeydrunkstudios.com` cutover):** flip the Cloudflare row's scope to include "Registrar (active for `honeydrunkstudios.com`)." The GoDaddy row stays — it still holds `tatteddev.com` and `honeyhub.app`. The Cloudflare lock-in assessment row gets added in this PR (the ADR is being accepted at this PR, so the assessment shifts here).
- **Wave 3 (P5a — `tatteddev.com`, P5b — `honeyhub.app`):** each packet flips its own domain's status on the catalog. P5a lists `tatteddev.com` as Cloudflare-registered; P5b lists `honeyhub.app`. Whichever P5 packet is the **last** to merge also performs the closing edit: removes the GoDaddy row entirely, removes the GoDaddy lock-in assessment row, and finalizes the Cloudflare row's scope as "Registrar, authoritative DNS, CDN, DDoS, WAF" with the at-cost-Free pricing posture. The last P5 packet's Acceptance Criteria say so explicitly.

This packet (P1) is the entry-state — a transitional note. The downstream packets carry the row-state edits as their own work product. The catalog is honest at every PR-merge boundary.

## Proposed Implementation

### Edits to `infrastructure/vendor-inventory.md`

1. **`Last Updated` header** — bump to today's date.

2. **`## DNS / CDN / Domain` section** — annotate both existing rows. Do not drop, rename, or rescope.

   Current:
   ```
   | GoDaddy | Domain registrar | Domain registration and management | Paid |
   | Cloudflare | DNS, CDN, DDoS protection | DNS management, edge caching, security | Free tier / Pro |
   ```

   New (annotation only):
   ```
   | GoDaddy | Domain registrar (transfer-in-flight to Cloudflare per ADR-0029; per-domain state flips on migration packets) | Domain registration and management for the not-yet-migrated portfolio | Paid |
   | Cloudflare | DNS, CDN, DDoS protection (registrar role pending — first cutover lands with P4 per ADR-0029) | DNS management, edge caching, security | Free tier / Pro |
   ```

   Section header (`## DNS / CDN / Domain`) is unchanged in this packet. P4 renames it.

3. **`## Vendor Lock-In Assessment` table** — no edits in this packet. The table currently has rows for Azure, GitHub, Vercel, Resend / Twilio, Sentry / PostHog, OpenTelemetry. GoDaddy is not in the table and is not added; Cloudflare is not in the table and is not added in this packet. Both edits land in P4 alongside the ADR's acceptance event.

4. **No changes to other sections.** Cloud Platform, AI / Developer Tools, Hosting, Source Control / CI/CD, Notification Providers, Observability, Package Registries, Database, Security Scanning, Accessibility / Performance — all untouched.

### `CHANGELOG.md` (Architecture repo)
Append an entry to the existing in-progress `## [Unreleased]` section under `### Changed`:
- "Vendor inventory: GoDaddy and Cloudflare rows annotated as transfer-in-flight per ADR-0029. Per-domain row-state edits land on the migration packets (P4, P5a, P5b)."

## Affected Files
- `infrastructure/vendor-inventory.md`
- `CHANGELOG.md`

## Boundary Check
- [x] Architecture-repo doc edit only. No code in any Node touched.
- [x] No catalog graph changes (`catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`) — Cloudflare and GoDaddy are vendors, not Nodes.
- [x] No invariant text changes. ADR-0029 explicitly proposes no new invariants.

## Acceptance Criteria
- [ ] `infrastructure/vendor-inventory.md` `Last Updated` header bumped to today's date.
- [ ] `## DNS / CDN / Domain` section's GoDaddy row carries the transfer-in-flight annotation referencing ADR-0029 and noting per-domain state on migration packets.
- [ ] Same section's Cloudflare row carries the "registrar role pending — first cutover lands with P4" annotation.
- [ ] No other rows or sections in `vendor-inventory.md` are edited.
- [ ] `CHANGELOG.md` `## [Unreleased]` section has the changed-entry described above.
- [ ] PR description references this packet (per invariant 32 — link the packet from the PR body).

## Human Prerequisites
None. This packet is fully delegable; the agent edits the doc and opens a PR.

## Referenced Invariants

> **Invariant 12:** Every shipped behavior change is reflected in `CHANGELOG.md` (and `README.md` when public surface changes). Catalog edits that change what the documented vendor surface says are shipped behavior changes for documentation consumers.

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor.

## Referenced ADR Decisions

**ADR-0029 §If Accepted:** "Update `infrastructure/vendor-inventory.md` — replace the GoDaddy row with Cloudflare (registrar)... and update the lock-in assessment to reflect the consolidation." This packet is the *first* increment toward that line. The collapse-the-row-out edit lands in P4 (Cloudflare row scope flip + lock-in assessment add) and the closing edit in the last P5 packet (GoDaddy row removed). Splitting the work across the rollout keeps the catalog truthful at every PR-merge boundary; the alternative is a multi-week stretch where the catalog says GoDaddy is gone while two domains still live there.

**ADR-0029 D1:** "All Grid-owned domains move to Cloudflare Registrar... Existing domains at GoDaddy transfer one at a time, in the order in §Implementation." The catalog state mirrors the migration state.

**ADR-0029 §Consequences — Operational:** "Vendor-lock-in assessment shifts marginally — the Cloudflare row in `vendor-inventory.md` becomes higher-impact (registrar + DNS + edge), GoDaddy's row goes away." The assessment add (Cloudflare) is in P4; the assessment removal (GoDaddy was never in the table) is implicit; the row-removal edit lands in the last P5 packet.

## Dependencies
None. This is the first packet in the rollout.

## Labels
`chore`, `tier-1`, `docs`, `infrastructure`, `adr-0029`

## Agent Handoff

**Objective:** Annotate the GoDaddy and Cloudflare rows in `infrastructure/vendor-inventory.md` to reflect that the transfer is in flight per ADR-0029. Per-domain row-state edits and the eventual GoDaddy row removal happen on the downstream migration packets.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Honest catalog state at every PR-merge boundary across the rollout. This packet is the entry edit; downstream packets carry the per-domain state flips and the closing row removal.
- Feature: ADR-0029 Cloudflare DNS & Edge Platform Rollout, Wave 1.
- ADR: ADR-0029 (Proposed).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- **Invariant 12:** Every shipped behavior change is reflected in `CHANGELOG.md` (and `README.md` when public surface changes). The vendor-inventory edit ships a doc-state change; CHANGELOG entry mandatory.
- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR receives a degraded review.
- **No catalog graph edits.** Cloudflare and GoDaddy are vendors, not Nodes — `catalogs/nodes.json`, `catalogs/relationships.json`, and `catalogs/grid-health.json` are not touched. ADR-0029 §Catalog Obligations is explicit: no catalog-graph changes.
- **Stay narrow — annotation only.** This packet does NOT collapse the GoDaddy row out, does NOT rescope the Cloudflare row, does NOT touch the lock-in assessment table, and does NOT rename the section. Those are P4 and P5 work; pre-empting them produces stale catalog state for the transfer window.

**Key Files:**
- `infrastructure/vendor-inventory.md` (the only doc edited)
- `CHANGELOG.md` (Unreleased section append)

**Contracts:** None changed. This is a doc-catalog edit, not an interface change.
