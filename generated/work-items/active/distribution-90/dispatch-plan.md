# Dispatch Plan — Distribution 90 (Outward Shipping Push)

> Living narrative per ADR-0008 D7 — the one exception to packet immutability. Updated at wave boundaries.

## Summary

A 90-day operator-priority push (2026-06-09 → 2026-09-07) to take the Grid's external distribution from zero to measured. An org-wide strategy review (2026-06-09) found the engineering/governance side excellent while external distribution is at zero: 1 star org-wide, 0 forks, 0 external issue authors, no analytics, no newsletter, no waitlists live, no release announcements ever.

This initiative is grounded in **existing decisions** — no new ADR:

- **PDR-0011 amended §5** — the BYOK cloud-execution waitlist probe ("one-page waitlist + concrete monthly price + reserve button; <1 solo-dev day to first signal"). This initiative executes that probe.
- **PDR-0002** — Notify Cloud public launch target 2026-09-15 and its pre-launch waitlist mitigation. This initiative forces the explicit go/slip decision so the date does not fail by sequencing default.
- **Charter motivation 3 (career and beyond)** — "A solo dev with a public, well-architected Grid … is a different professional artifact … whether or not any individual product succeeds commercially." Distribution is what makes the artifact visible.
- **Charter §Build-in-public** — the repos and process are already public; this initiative adds the missing outward loop (measurement + announcement + syndication).

**Charter forbids check:** the charter explicitly warns against "reading a Hacker News thread on a Sunday and waking up Monday committed to a 90-day kill clock and a growth target." This is not that: there is no kill clock and no growth target. Every deliverable here executes an already-decided probe (PDR-0011 §5), an already-committed launch date (PDR-0002), or basic instrumentation. Day-90 criteria are *reps completed and decisions recorded*, not numbers hit.

## Trigger

Operator commitment following the 2026-06-09 org-wide strategy review.

## Initiative Guardrails (recorded here and in `initiatives/active-initiatives.md`, NOT as invariants)

1. **No new process/governance ADRs during the 90 days unless they block shipping.** This initiative must not become a governance project.
2. **ADR-0043 Strategic backlog generation is deferred or gated while The Hive's Backlog:Ready ratio exceeds ~10:1.** The constraint is execution attention, not idea supply.
3. **Packets stay day-scale or smaller.** Recurring weekly work lives as a standing checklist in the metrics log (packet 12), not as 12 more packets.

## Wave Diagram

### Wave 1 — Instrumentation + passive surfaces (week 1, zero exposure)
- [ ] HoneyDrunk.Architecture (work in tatteddev/tatteddev-blog): Cloudflare Web Analytics beacon on tatteddev.com — [01](01-tatteddev-blog-cloudflare-web-analytics.md)
- [ ] HoneyDrunkStudios/HoneyDrunkStudios: Cloudflare Web Analytics beacon on honeydrunkstudios.com — [02](02-studios-website-cloudflare-web-analytics.md)
- [ ] HoneyDrunk.Architecture: NuGet/stars/traffic baseline + weekly metrics log — [03](03-architecture-distribution-metrics-log.md)
- [ ] HoneyDrunk.Architecture (work in tatteddev/tatteddev-blog): newsletter signup (Buttondown) — [04](04-tatteddev-blog-newsletter-signup.md)

### Wave 2 — Waitlist, loop bring-up, decisions (weeks 1–3)
- [ ] HoneyDrunkStudios/HoneyDrunkStudios: HoneyHub BYOK cloud-execution waitlist page (PDR-0011 §5 probe) — [05](05-studios-website-honeyhub-byok-waitlist-page.md)
- [ ] HoneyDrunk.HoneyHub: launch-blocking checkpoint (finish in-flight PR stack) — [06](06-honeyhub-launch-blocking-checkpoint.md)
- [ ] HoneyDrunk.Architecture: Notify Cloud go/slip decision (Actor=Human) — [07](07-architecture-notify-cloud-go-slip-decision.md)
- [ ] HoneyDrunk.Architecture: establish the weekly distribution loop + syndication queue — [12](12-architecture-weekly-distribution-loop.md)
  - Blocked by: Wave 1 — packet 03 (metrics log must exist)

### Wave 3 — HoneyHub v0.1.0 launch assets (weeks 2–8)
- [ ] HoneyDrunk.HoneyHub: tag and release v0.1.0 (first tag on the repo) — [08](08-honeyhub-release-v0-1-0.md)
  - Blocked by: Wave 2 — packet 06
- [ ] HoneyDrunk.HoneyHub: record 2-minute demo (Actor=Human) — [09](09-honeyhub-demo-recording.md)
  - Blocked by: Wave 2 — packet 06
- [ ] HoneyDrunk.Architecture (work in tatteddev/tatteddev-blog): HoneyHub launch blog post — [10](10-tatteddev-blog-honeyhub-launch-post.md)
  - Blocked by: Wave 3 — packets 08, 09

### Wave 4 — Launch submissions (weeks 2–8)
- [ ] HoneyDrunk.Architecture (work in tatteddev/tatteddev-blog): Show HN + subreddit submission drafts (operator click-to-submit) — [11](11-tatteddev-blog-launch-submissions.md)
  - Blocked by: Wave 2 — packet 05; Wave 3 — packets 08, 10

### Wave 5 — Close-out
- [ ] HoneyDrunk.Architecture: implementation-notes (as-built reconciliation) — [13](13-implementation-notes.md)
  - Blocked by: all packets 01–12

The recurring weekly loop (12 reps of: one syndicated back-catalog post, 15-minute metrics review, release announcements) runs from Wave 2 onward as a standing checklist in `initiatives/metrics-log.md` — deliberately NOT modeled as packets.

## Site Sync Flag

Partially self-covering: packets 02 and 05 *are* the website changes. No separate site-sync packet. The HoneyHub v0.1.0 release (packet 08) may warrant a `/signal` timeline entry on honeydrunkstudios.com — fold into packet 05's PR or a trivial follow-up at the operator's discretion.

## Known Drift / Flags

- `catalogs/nodes.json` (`honeydrunk-studios`) points at `https://github.com/HoneyDrunkStudios/HoneyDrunk.Studios`, which does not exist; the live website repo is `HoneyDrunkStudios/HoneyDrunkStudios` (Next.js app under `honeydrunk-website/`). Catalog correction is deliberately OUT of this initiative's scope (guardrail 1) — left for hive-sync/tactical audit.
- `tatteddev/tatteddev-blog` is outside the HoneyDrunkStudios org and is not a Grid Node. The 2026-06-09 filing run failed there with HTTP 403 (the org GitHub App is not installed on the personal account), so its four packets (01, 04, 10, 11) carry `target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture` (issue tracking) plus `work_repo: tatteddev/tatteddev-blog` (where the implementing PR opens). They keep `node: none`.
- The strategy-review brief described "both Astro sites"; only the blog is Astro. The website is Next.js 16. Packets reflect ground truth.

## Rollback Plan

Everything in Waves 1–2 is additive and independently revertible (a beacon `<script>` tag, a form embed, one new page, one markdown log). Reverting any commit restores the prior state; no data migrations, no contract changes, no downstream consumers. The v0.1.0 tag (Wave 3) is permanent once pushed — gate it on the operator's explicit go. Launch submissions (Wave 4) are irreversible by nature; that is why packet 11 is draft-for-approval with human click-to-submit.

## Filing Commands (run by file-issues after operator review)

```bash
# Wave 1
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Add Cloudflare Web Analytics beacon to tatteddev.com" --body-file "generated/work-items/active/distribution-90/01-tatteddev-blog-cloudflare-web-analytics.md" --label "feature,tier-1,meta,distribution-90"
gh issue create --repo HoneyDrunkStudios/HoneyDrunkStudios --title "Add Cloudflare Web Analytics beacon to honeydrunkstudios.com" --body-file "generated/work-items/active/distribution-90/02-studios-website-cloudflare-web-analytics.md" --label "feature,tier-1,meta,distribution-90"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Create the distribution metrics log with NuGet/stars/traffic baseline" --body-file "generated/work-items/active/distribution-90/03-architecture-distribution-metrics-log.md" --label "chore,tier-1,meta,distribution-90"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Add newsletter signup (Buttondown) to the blog layout" --body-file "generated/work-items/active/distribution-90/04-tatteddev-blog-newsletter-signup.md" --label "feature,tier-1,meta,distribution-90"

# Wave 2
gh issue create --repo HoneyDrunkStudios/HoneyDrunkStudios --title "Ship the HoneyHub BYOK cloud-execution waitlist page (PDR-0011 §5)" --body-file "generated/work-items/active/distribution-90/05-studios-website-honeyhub-byok-waitlist-page.md" --label "feature,tier-2,meta,distribution-90"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.HoneyHub --title "Close the HoneyHub v0.1.0 launch-blocking PR stack" --body-file "generated/work-items/active/distribution-90/06-honeyhub-launch-blocking-checkpoint.md" --label "chore,tier-2,ai,distribution-90"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Decide: Notify Cloud 2026-09-15 — commit or slip (PDR-0002)" --body-file "generated/work-items/active/distribution-90/07-architecture-notify-cloud-go-slip-decision.md" --label "chore,tier-2,meta,distribution-90,human-only"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Establish the weekly distribution loop and syndication queue" --body-file "generated/work-items/active/distribution-90/12-architecture-weekly-distribution-loop.md" --label "chore,tier-1,meta,distribution-90"

# Wave 3
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.HoneyHub --title "Tag and release HoneyHub v0.1.0 (first release)" --body-file "generated/work-items/active/distribution-90/08-honeyhub-release-v0-1-0.md" --label "chore,tier-2,ai,distribution-90"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.HoneyHub --title "Record the 2-minute HoneyHub demo (phone over Tailscale)" --body-file "generated/work-items/active/distribution-90/09-honeyhub-demo-recording.md" --label "chore,tier-1,ai,distribution-90,human-only"
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Write and publish the HoneyHub v0.1.0 launch post" --body-file "generated/work-items/active/distribution-90/10-tatteddev-blog-honeyhub-launch-post.md" --label "feature,tier-1,meta,distribution-90,honeyhub"

# Wave 4
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Draft HoneyHub launch submissions (Show HN + subreddits)" --body-file "generated/work-items/active/distribution-90/11-tatteddev-blog-launch-submissions.md" --label "feature,tier-1,meta,distribution-90,honeyhub"

# Wave 5
gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture --title "Author the Distribution 90 implementation-notes record" --body-file "generated/work-items/active/distribution-90/13-implementation-notes.md" --label "chore,tier-1,meta,distribution-90"
```

Note: all 13 issues now file into org repos (the four blog-work packets track in HoneyDrunk.Architecture with `work_repo: tatteddev/tatteddev-blog`), so every issue can join The Hive board normally.

## Wave Log

- **2026-06-09** — Initiative scoped; 13 packets authored; awaiting operator review and filing.
- **2026-06-09** — First filing run failed: the org GitHub App got HTTP 403 on `tatteddev/tatteddev-blog` (personal account, App not installed). Pre-filing amendment (invariant 24): packets 01/04/10/11 retargeted to file in HoneyDrunk.Architecture with `work_repo: tatteddev/tatteddev-blog`; no issues had been created, so no duplicates.
