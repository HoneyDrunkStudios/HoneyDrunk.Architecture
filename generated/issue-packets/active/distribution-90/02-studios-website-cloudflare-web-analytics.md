---
name: Cloudflare Web Analytics on honeydrunkstudios.com
type: repo-feature
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunkStudios
labels: ["feature", "tier-1", "meta", "distribution-90"]
dependencies: []
adrs: ["PDR-0011", "PDR-0002"]
source: human
generator: scope
wave: 1
initiative: distribution-90
node: honeydrunk-studios
actor: agent
---

# Feature: Add Cloudflare Web Analytics beacon to honeydrunkstudios.com

## Summary
Add the Cloudflare Web Analytics beacon to the honeydrunkstudios.com Next.js site so the Distribution 90 initiative has traffic measurement from week 1. The site currently has zero analytics; the HoneyHub BYOK waitlist page (packet 05) will live on this domain and its probe result is meaningless without traffic context.

## Context
Distribution 90 (operator-priority, 2026-06-09 → 2026-09-07) starts with instrumentation. Cloudflare Web Analytics is the default: honeydrunkstudios.com's DNS is already on Cloudflare, it is free, privacy-first, and needs no cookie banner. **Ground-truth note:** the live website repo is `HoneyDrunkStudios/HoneyDrunkStudios` (the catalog's `https://github.com/HoneyDrunkStudios/HoneyDrunk.Studios` URL is drifted — do not "fix" that here; it is flagged for hive-sync). The site is **Next.js 16** (not Astro), deployed on Vercel, app source under `honeydrunk-website/`.

## Scope
- `honeydrunk-website/app/layout.tsx` — the root layout; the beacon goes here so every route is covered.
- No other files. No content, styling, or build-config changes.

## Proposed Implementation
Add the beacon to the root layout using `next/script` so it renders on every page without blocking hydration:

```tsx
import Script from "next/script";

// inside the root layout's <body>, after {children}:
<Script
  src="https://static.cloudflareinsights.com/beacon.min.js"
  data-cf-beacon='{"token": "<HDS_CF_WA_TOKEN>"}'
  strategy="afterInteractive"
/>
```

Notes:
- The token is **not a secret** — Cloudflare Web Analytics tokens are public site identifiers embedded in client HTML. Hardcoding is correct; no env-var plumbing needed.
- honeydrunkstudios.com is on Vercel, so the Cloudflare zone is likely DNS-only (grey-cloud) for the apex/site records — automatic injection will NOT work; the manual beacon is required here.
- The site is a static-data Next.js app (no CMS); there is no existing analytics or consent tooling to integrate with.

## Human Prerequisites
- [ ] In the Cloudflare dashboard → Web Analytics → Add a site → `honeydrunkstudios.com` → copy the beacon token (about 5 minutes). Provide it to the implementing agent (public value; issue comment is fine).

## Acceptance Criteria
- [ ] Beacon renders on every route (spot-check `/`, `/grid`, `/nodes`, `/signal` in the deployed preview: each page's HTML references `static.cloudflareinsights.com/beacon.min.js`).
- [ ] `npm run build` in `honeydrunk-website/` succeeds with no new warnings; Vercel preview deploy is green.
- [ ] After production deploy, the Cloudflare Web Analytics dashboard shows page views for honeydrunkstudios.com within 24 hours.
- [ ] No cookie banner added — Cloudflare Web Analytics is cookieless; confirm no consent tooling was introduced.

## Dependencies
None. (Independent of packet 01 — same change, different domain/repo/framework.)

## Agent Handoff

**Objective:** Add the Cloudflare Web Analytics beacon to the Next.js root layout.
**Target:** `HoneyDrunkStudios/HoneyDrunkStudios`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 1 — instrumentation before exposure; prerequisite context for the packet-05 waitlist probe on this same domain.
- The website app lives in the `honeydrunk-website/` subfolder of this repo.

**Acceptance Criteria:** as listed above.

**Dependencies:** none, but the operator must supply the beacon token first (Human Prerequisites).

**Constraints:**
- One logical change: the beacon only. Do not refactor the layout, do not add a consent banner, do not upgrade dependencies.
- The token is public by design; do not add env-var or secret plumbing for it.
- Agent-authored PRs must link to their packet in the PR body — the review agent resolves the packet via this link and uses it as the primary scope anchor; absent the link the PR is treated as out-of-band and receives a degraded review (invariant 32).

**Key Files:**
- `honeydrunk-website/app/layout.tsx`

**Contracts:** None.
