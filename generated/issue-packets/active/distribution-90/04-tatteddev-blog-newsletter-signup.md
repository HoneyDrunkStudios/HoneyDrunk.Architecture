---
name: Newsletter Signup on tatteddev.com
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

# Feature: Add newsletter signup (Buttondown) to the blog layout

## Summary
Wire a newsletter signup form (Buttondown free tier) into the tatteddev.com blog layout so the back-catalog syndication loop (packet 12) and the HoneyHub launch post (packet 10) have a durable capture surface. Today a reader who likes a post has no way to hear about the next one.

## Context
Distribution 90 Wave 1, passive surfaces. Buttondown is the default recommendation: free tier (up to 100 subscribers), simple HTML form embed (no JS SDK required), markdown-native authoring, and it can double as the storage backend for the packet-05 waitlist via tags — one vendor, two jobs. The operator may substitute another provider at the prerequisite step; the implementation pattern (plain HTML form POST) is provider-portable.

## Scope
- `app/src/components/Footer.astro` — site-wide signup placement.
- `app/src/layouts/BlogPost.astro` — end-of-post signup placement (the highest-intent moment).
- Optionally a small shared `NewsletterSignup.astro` component used by both, to avoid duplication.

## Proposed Implementation
1. Create `app/src/components/NewsletterSignup.astro`: a short pitch line + Buttondown's plain HTML embed form:

```html
<form
  action="https://buttondown.com/api/emails/embed-subscribe/<USERNAME>"
  method="post"
  target="popupwindow"
  class="newsletter-signup"
>
  <label for="bd-email">Get new posts by email</label>
  <input type="email" name="email" id="bd-email" required placeholder="you@example.com" />
  <button type="submit">Subscribe</button>
</form>
```

2. Include the component in `Footer.astro` (every page) and at the bottom of `BlogPost.astro` (after the post body, before Giscus comments).
3. Style minimally with the existing Tailwind setup; match the site's current look — this is a form, not a redesign.
4. Copy: one sentence, honest and low-pressure, in the operator's voice (no hype, no "join 1000s of devs").

## Human Prerequisites
- [ ] Create a Buttondown account (free tier), pick the username, and confirm the newsletter name/description (about 10 minutes).
- [ ] Provide the Buttondown username (public, appears in the form action URL) to the implementing agent.
- [ ] (Optional) Configure Buttondown's double-opt-in and welcome email defaults.

## Acceptance Criteria
- [ ] Signup form renders in the footer on every page and at the end of every blog post.
- [ ] Submitting a real email address lands a subscriber in the Buttondown dashboard (operator verifies once post-deploy).
- [ ] `npm run build` in `app/` succeeds; no layout regressions on mobile width (the form wraps cleanly).
- [ ] No tracking scripts, popups, or modals added — inline forms only.

## Dependencies
None.

## Agent Handoff

**Objective:** Add a Buttondown signup form to the blog footer and end-of-post layout via a shared Astro component.
**Target:** `tatteddev/tatteddev-blog`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 1 — passive capture surface feeding the weekly loop (packet 12) and the launch post (packet 10).
- This repo is outside the HoneyDrunkStudios org; Grid CI/review conventions do not apply. Standard Astro site, source under `app/`.

**Acceptance Criteria:** as listed above.

**Dependencies:** none, but the operator must create the Buttondown account first (Human Prerequisites).

**Constraints:**
- No signup popups/modals; inline forms only. Keep copy to one low-pressure sentence.
- Blog voice rules: no em dashes in user-facing copy; no "it's not X, it's Y" constructions.
- Plain HTML form POST; do not add a JS SDK or client-side subscriber tracking.

**Key Files:**
- `app/src/components/NewsletterSignup.astro` (new)
- `app/src/components/Footer.astro`
- `app/src/layouts/BlogPost.astro`

**Contracts:** None.
