---
name: HoneyHub BYOK Cloud-Execution Waitlist Page
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunkStudios
labels: ["feature", "tier-2", "meta", "distribution-90", "honeyhub"]
dependencies: []
adrs: ["PDR-0011"]
source: human
generator: scope
wave: 2
initiative: distribution-90
node: honeydrunk-studios
actor: agent
---

# Feature: Ship the HoneyHub BYOK cloud-execution waitlist page (PDR-0011 §5)

## Summary
Build the one-page BYOK cloud-execution waitlist on honeydrunkstudios.com: what it is, a concrete monthly price, a reserve button, and signup storage. This executes PDR-0011 amended §5 verbatim — it is the validation gate for HoneyHub's only commercial candidate, and the only page allowed to exist before any commercial scaffolding.

## Context
PDR-0011 (Accepted, amended 2026-06-06) §5 — "Cheapest validation experiment (before any commercial scaffolding)" — decides, quoted:

> 1. **One-page BYOK-cloud-execution waitlist** with a **concrete monthly price** and a **reserve button**, driven to the operator's build-in-public audience. **<1 solo-dev day to first signal.**
> 2. **If it converts past a pre-set threshold within 30 days →** graduate to a **Wizard-of-Oz** on the existing ADR-0086 runner for **3–5 design partners** (BYOK only, per §3).
> 3. **If not →** BYOK cloud execution stays **operator tooling**; no commercial build.

The strategy review found no waitlist is live; this packet makes the probe real. The page lives on honeydrunkstudios.com (the studio brand site, Next.js on Vercel, app under `honeydrunk-website/`) — HoneyHub is a studio product.

## What the page must say (content constraints from PDR-0011, inline because the executing agent cannot read the PDR)

- **The offer:** run your coding-agent sessions (Claude Code / Codex CLI) on a hosted worker, controlled from the HoneyHub cockpit, **using your own API keys**. Position against the free local product: HoneyHub itself is free and local-first; this is the optional hosted lane.
- **`[Firm]` boundary — must be stated on the page:** cloud execution is **BYO-API-key ONLY**. It never holds, stores, or proxies vendor subscription auth — quoted from §3: "Cloud/hosted execution is BYO-API-key ONLY and MUST NEVER authenticate with a vendor subscription token … there is no configuration, tier, or convenience exception." Phrase it as a customer-facing trust point ("your subscription login never touches our servers; you bring an API key").
- **A concrete monthly price** (operator supplies the number — see Human Prerequisites). Not "TBD", not a range.
- **A reserve button** that captures an email. No payment collection — this is a waitlist, not a checkout.
- **Honest framing** per the charter's build-in-public stance: this is a gauge-interest waitlist for a product that does not exist yet; say so plainly.

## Proposed Implementation
1. New route `honeydrunk-website/app/honeyhub/page.tsx` (or `/honeyhub/cloud` if the operator prefers `/honeyhub` for the free product later) — a single static page, consistent with the site's existing styling.
2. **Signup storage — simplest viable, default: Buttondown** (already provisioned in packet 04's prerequisites) using a tagged embed form (`?tag=honeyhub-byok-waitlist`), so waitlist count is readable from the same dashboard the newsletter uses and flows into the metrics log (packet 03). Alternative if the operator prefers separation: a Tally/Formspark form embed. Do NOT build a custom API route + database — that is commercial scaffolding, which §5 exists to gate.
3. Add one navigation/footer link on the site so the page is reachable, plus an OG title/description for link sharing (packets 10–11 will drive traffic here).

## Human Prerequisites
- [ ] **Set the concrete monthly price** (PDR-0011 §5 requires a real number on the page).
- [ ] **Pre-set the 30-day conversion threshold** and record it in the Distribution 90 entry in `initiatives/active-initiatives.md` *before* the page goes live — §5's go/no-go is meaningless if the bar is set after the data arrives.
- [ ] Confirm signup storage choice (default: Buttondown tag, reusing packet 04's account).
- [ ] Confirm the route (`/honeyhub` vs `/honeyhub/cloud`).

## Acceptance Criteria
- [ ] One page, live on honeydrunkstudios.com, with: offer description, the BYOK-only trust statement, a concrete monthly price, and a working reserve (email capture) button.
- [ ] A test signup appears in the chosen storage backend, attributable to the waitlist (e.g., carries the `honeyhub-byok-waitlist` tag).
- [ ] Page is linked from site navigation or footer and has OG metadata for sharing.
- [ ] No payment integration, no auth, no backend service, no database — email capture only.
- [ ] `npm run build` in `honeydrunk-website/` succeeds; Vercel preview green.

## Dependencies
None hard. Soft: packet 04's Buttondown account if the default storage choice is taken; packet 02's analytics so page traffic is measurable (both are Wave 1 and should land first in practice).

## Agent Handoff

**Objective:** Ship the one-page BYOK cloud-execution waitlist (offer + BYOK-only statement + concrete price + reserve button + email capture) on honeydrunkstudios.com.
**Target:** `HoneyDrunkStudios/HoneyDrunkStudios`, branch from `main`.
**Context:**
- Goal: Distribution 90 Wave 2 — execute the PDR-0011 §5 probe that gates HoneyHub's only commercial candidate.
- The website app lives under `honeydrunk-website/` (Next.js 16, Vercel).

**Acceptance Criteria:** as listed above.

**Dependencies:** operator prerequisites (price, threshold, storage choice) must be answered before implementation.

**Constraints:**
- **`[Firm]` PDR-0011 §3 boundary (inline above): cloud = BYOK-API-key only, never vendor subscription auth.** The page copy must reflect this; nothing on the page may promise subscription-based hosted execution.
- **No commercial scaffolding** — §5 gates it. Email capture via an existing form provider only; no custom backend, no Stripe, no accounts.
- Honest build-in-public framing; no fabricated social proof, no fake scarcity.
- Copy voice: no em dashes; no "it's not X, it's Y" antithesis constructions; explain plainly what HoneyHub is before using product jargon (public readers do not know Grid internals).
- Agent-authored PRs must link to their packet in the PR body (invariant 32: the review agent resolves the packet via this link as the primary scope anchor; absent the link the PR receives a degraded out-of-band review).

**Key Files:**
- `honeydrunk-website/app/honeyhub/page.tsx` (new)
- Site navigation/footer component (one link)

**Contracts:** None.
