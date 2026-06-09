---
name: Cloudflare Web Analytics on tatteddev.com
type: repo-feature
tier: 1
target_repo: tatteddev/tatteddev-blog
labels: ["feature", "tier-1", "meta", "distribution-90"]
dependencies: []
adrs: ["PDR-0011"]
source: human
generator: scope
wave: 1
initiative: distribution-90
node: none
actor: agent
---

# Feature: Add Cloudflare Web Analytics beacon to tatteddev.com

## Summary
Add the Cloudflare Web Analytics beacon to the tatteddev.com Astro blog so the Distribution 90 initiative has traffic measurement from week 1. Today the blog has zero analytics — launch posts and syndication (packets 10–12) would otherwise ship blind.

## Context
Distribution 90 (operator-priority, 2026-06-09 → 2026-09-07) starts with instrumentation: measurement before exposure. Cloudflare Web Analytics is the default choice because tatteddev.com's DNS is already on Cloudflare, the product is free, privacy-first, and needs no cookie banner. The weekly metrics review (packet 12) reads this data into `initiatives/metrics-log.md` in HoneyDrunk.Architecture.

## Scope
- `app/src/components/BaseHead.astro` — the shared `<head>` component included by every page; the beacon `<script>` goes here so all routes are covered.
- No other files. No content changes, no styling, no build config changes.

## Proposed Implementation
Append the beacon to `BaseHead.astro`:

```html
<script
  defer
  src="https://static.cloudflareinsights.com/beacon.min.js"
  data-cf-beacon='{"token": "<TATTEDDEV_CF_WA_TOKEN>"}'
  is:inline></script>
```

Notes:
- The token is **not a secret** — Cloudflare Web Analytics tokens are public site identifiers embedded in client HTML, like a GA measurement ID. Hardcoding it in the component is correct; no env-var plumbing needed.
- `is:inline` prevents Astro from processing/bundling the external script.
- If the tatteddev.com zone is proxied (orange-cloud) in Cloudflare, the operator can alternatively enable **automatic injection** from the dashboard with zero code change — in that case this packet closes with a note instead of a commit. The manual beacon is the robust default because it works regardless of proxy status.

## Human Prerequisites
- [ ] In the Cloudflare dashboard → Web Analytics → Add a site → `tatteddev.com` → copy the beacon token (about 5 minutes). Provide the token to the implementing agent (it is public, so an issue comment is fine).
- [ ] (Alternative) If the zone is proxied, decide whether to use one-click automatic injection instead of the manual snippet.

## Acceptance Criteria
- [ ] Beacon script present in `app/src/content`-rendered pages (verify in built output: every page in `dist/` contains the `static.cloudflareinsights.com/beacon.min.js` reference).
- [ ] Site builds cleanly (`npm run build` in `app/`) with no new warnings.
- [ ] After deploy, the Cloudflare Web Analytics dashboard shows page views for tatteddev.com within 24 hours.
- [ ] No cookie banner added — Cloudflare Web Analytics is cookieless by design; confirm no consent tooling was introduced.

## Dependencies
None.

## Agent Handoff

**Objective:** Add the Cloudflare Web Analytics beacon snippet to the blog's shared head component.
**Target:** `tatteddev/tatteddev-blog`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 1 — instrumentation before exposure.
- This repo is outside the HoneyDrunkStudios org and is not a Grid Node; Grid CI/review conventions do not apply here. It is a standard Astro site (source under `app/`).

**Acceptance Criteria:** as listed above.

**Dependencies:** none, but the operator must supply the beacon token first (Human Prerequisites).

**Constraints:**
- One logical change: the beacon only. Do not refactor `BaseHead.astro`, do not touch content, do not add a consent banner.
- The token is public by design; do not build secret-management plumbing for it.

**Key Files:**
- `app/src/components/BaseHead.astro`

**Contracts:** None.
