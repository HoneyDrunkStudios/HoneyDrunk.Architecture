---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "infrastructure", "human-only", "adr-0054", "wave-2"]
dependencies: ["packet:00"]
adrs: ["ADR-0054", "ADR-0052", "ADR-0027"]
accepts: ["ADR-0054"]
wave: 2
initiative: adr-0054-incident-response
node: honeydrunk-architecture
---

# Provision the Statuspage v0 static fallback under Studios.HoneyDrunk.com; defer Statuspage Starter until first paying tenant

## Summary
Provision the **v0 static-status-page fallback** at `status.honeydrunkstudios.com` (or the equivalent path on the existing Studios website) per ADR-0054 D9. Author the operator walkthrough for updating it during a SEV-1/2. Defer the **Atlassian Statuspage Starter ($29/month)** adoption to first paying-tenant onboarding per ADR-0054's Operational Consequences. Author the upgrade walkthrough so the Starter adoption is a documented, single-session task when the trigger fires.

## Context
ADR-0054 D9 names the tenant status page as the public-facing incident surface. The ADR commits to **two tiers**:

- **v1 (when first paying tenant exists):** Atlassian Statuspage Starter at ~$29/month — gives subscriber notifications, RSS, history, proper external surface.
- **v0 (now):** a **static page** in `Studios.HoneyDrunk.com` — free, no notification surface, but acceptable until the first paying tenant. The trade-off is explicit: "Statuspage gives proper subscriber notifications, RSS, history; static page gives nothing but is free. Choose Statuspage when first paying tenant exists; before that, static is acceptable."

ADR-0054's Operational Consequences: "Atlassian Statuspage Starter ($29/month) is a recommended-but-deferred adoption. The v0 fallback (static page in Studios.HoneyDrunk.com) is acceptable until the first paying tenant exists; the Starter tier adopts at first paying-tenant onboarding."

**Two artifacts in one packet:**

1. **v0 static-page provisioning** — a static page at `status.honeydrunkstudios.com` (or `studios.honeydrunkstudios.com/status` if subdomains require extra DNS work). Manually updated during a SEV-1/2 via the existing Studios website edit flow. Renders the current grid status from a static JSON file or just inline content. Site sync handled by the Studios website's existing static-content pipeline.
2. **Deferred Statuspage Starter walkthrough** — the upgrade path documented now so adoption is a single-session task at trigger time. The trigger: **first paying-tenant onboarding**.

**Studios website is the surface.** ADR-0054 names "static page in `Studios.HoneyDrunk.com`" — that is the `HoneyDrunk.Studios` Next.js site. The static page lives in that site. However, this packet's `target_repo` is `HoneyDrunk.Architecture` because:

- The **walkthrough** (both v0 setup and the deferred Starter adoption) lives in `infrastructure/walkthroughs/` — a Architecture-repo artifact.
- The **actual Studios website edit** that adds a `/status` route is a small follow-on Studios PR, scoped from the walkthrough. The PR is trivial (a markdown / JSON content file plus a Next.js route) and the operator executes it directly — it does not warrant a separate packet in this initiative.
- The Statuspage Starter adoption itself is portal work in the Atlassian Statuspage UI; no code lands then either.

Per the operator's standing preference, infra provisioning uses portal UI walkthroughs, not CLI / Terraform.

**Provision-when-needed.** No paying tenant exists in 2026-05; the v0 static fallback is sufficient. The Starter adoption fires when the first paying tenant is onboarded — not now. This packet **does not** provision Atlassian Statuspage Starter now; it only documents the adoption walkthrough for the trigger.

**Site sync.** Adding the `/status` route to the Studios website is a Studios PR; that PR is the "site sync" for this packet. Not flagged as a separate packet because the surface change is small.

This is an infrastructure walkthrough packet. No code, no .NET project. **Actor=Human** — the steps are website edits and (deferred) portal clicks.

## Scope
- `infrastructure/walkthroughs/statuspage-provisioning.md` (new) — combined walkthrough covering: (a) v0 static-page setup at `status.honeydrunkstudios.com`, (b) operator runbook for updating the page during a SEV-1/2, (c) deferred Statuspage Starter adoption when first paying tenant exists.
- The Studios website — a `/status` route or `status.honeydrunkstudios.com` subdomain rendering a static incident-status page. Surface change executed via a small follow-on Studios PR scoped from the walkthrough.
- `catalogs/grid-health.json` (or equivalent) — record the v0 status-page state.
- `business/context/` — record the Starter $29/month adoption as a deferred cost item gated on first-paying-tenant trigger.

## Proposed Work (human-executed, website edit + walkthrough authoring)
The walkthrough authors and the operator executes:

1. **v0 static page on Studios website.**
   - Decide path: `status.honeydrunkstudios.com` (subdomain — requires Cloudflare DNS per ADR-0029) or `honeydrunkstudios.com/status` (path — no new DNS).
   - **Recommendation:** subdomain `status.honeydrunkstudios.com` — it matches the convention referenced in the D9 tenant-email template ("You can follow updates at status.honeydrunkstudios.com"). Requires a Cloudflare DNS record per ADR-0029.
   - In the `HoneyDrunk.Studios` Next.js site, add a new route or new subdomain page rendering a static incident-status JSON / markdown. The page has three components: (i) current overall status ("All systems operational" / "Incident in progress" / "Maintenance"), (ii) the incident-state line (if active), (iii) the link to the most recent post-mortem (if any).
   - Initially: "All systems operational" — no active incident.
   - The page is **manually updated** via a Studios website PR during a SEV-1/2 declaration / update / resolution. The operator edits a static markdown / JSON content file in the Studios repo; the website redeploys automatically.
2. **Operator runbook for the v0 page.**
   - Document the file path in the Studios repo to edit (e.g., `data/status.json` or `content/status.md`).
   - Document the SEV-1/2 update cadence: 30 min after declaration, every 60 min during active incident, within 30 min of resolution (per D9). Cross-link the cadence to D9 in the runbook.
3. **Deferred Statuspage Starter walkthrough.**
   - Document the trigger: "first paying tenant onboarded." When this fires, the operator follows the walkthrough's Starter section.
   - The Starter section covers: signup at statuspage.com Starter plan; DNS swap for `status.honeydrunkstudios.com` from Studios website to Statuspage's hosted page; configure components (one per Node); configure subscribers (tenant emails for incident notifications); test incident → resolution flow.
   - Update the cadence reference: Statuspage provides the proper subscriber-notification surface, replacing the manual Studios-website edit.
4. **Update catalog readout.**
   - `catalogs/grid-health.json` (or equivalent) carries the status-page state: `v0-static`. Flips to `v1-statuspage-starter` when the Starter is adopted (a future follow-on packet to flip the catalog).
5. **Cost guard.**
   - `business/context/` carries the deferred Statuspage Starter $29/month line as a **gated** cost item — does not fire until first paying tenant. Annotated against ADR-0052's cost-discipline envelope.

## Affected Files
- `infrastructure/walkthroughs/statuspage-provisioning.md` (new)
- `catalogs/grid-health.json` (or equivalent) — status-page state entry.
- `business/context/` — deferred Statuspage Starter cost annotation.
- A follow-on Studios PR (out of this packet's `target_repo` scope) — small static-content edit + new route / subdomain. Scoped from the walkthrough.

## NuGet Dependencies
None. This packet has no .NET project.

## Boundary Check
- [x] The walkthrough doc lives in `HoneyDrunk.Architecture` — correct home for infrastructure walkthroughs.
- [x] The Studios website edit is a follow-on Studios PR, not part of this packet's commit — the walkthrough scopes the work.
- [x] Statuspage adoption is deferred per ADR-0054's Operational Consequences.
- [x] The DNS work, if a subdomain is chosen, follows ADR-0029's Cloudflare DNS convention.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/statuspage-provisioning.md` exists and documents: (a) the v0 static-page provisioning at `status.honeydrunkstudios.com` (or `honeydrunkstudios.com/status` — the path choice is recorded with rationale), (b) the operator runbook for updating the page during a SEV-1/2 with the D9 cadence (30 min after declaration, every 60 min during active incident, within 30 min of resolution), (c) the deferred Statuspage Starter adoption walkthrough gated on first-paying-tenant trigger
- [ ] The Studios website has a `/status` route or `status.honeydrunkstudios.com` subdomain rendering a static incident-status page with "All systems operational" initially; this is delivered via a follow-on Studios PR, scoped from the walkthrough
- [ ] `catalogs/grid-health.json` (or equivalent) records the status-page state as `v0-static`
- [ ] `business/context/` records the deferred Statuspage Starter $29/month cost as gated on first-paying-tenant trigger; annotated against ADR-0052
- [ ] The walkthrough's deferred-Statuspage section is detailed enough that adoption is a single-session task when the trigger fires (signup, DNS swap, components, subscribers, test flow — all documented)
- [ ] The DNS choice (subdomain vs path) follows ADR-0029's Cloudflare convention if a subdomain is selected
- [ ] No Statuspage account is provisioned now — the Starter adoption is deferred

## Human Prerequisites
- [ ] **Decide DNS path:** subdomain `status.honeydrunkstudios.com` vs path `honeydrunkstudios.com/status`. The agent recommends the subdomain to match the D9 email-template wording, but the operator chooses.
- [ ] **If the subdomain is chosen:** add the Cloudflare DNS record per ADR-0029. The agent does not have Cloudflare access.
- [ ] **Execute the follow-on Studios PR** to add the `/status` route / page. Small, scoped from the walkthrough — the agent can author the PR description from the walkthrough.
- [ ] **Atlassian Statuspage Starter adoption is deferred** — no action now. When the first paying tenant is onboarded, follow the deferred section of the walkthrough.

## Referenced ADR Decisions
**ADR-0054 D9 — Status page.** Two tiers: Atlassian Statuspage Starter ($29/month) v1 when first paying tenant exists; static page in `Studios.HoneyDrunk.com` v0 fallback before that. Cadence: within 30 min of SEV-1/2 declaration with tenant impact, every 60 min during active incident, resolution within 30 min of close. Trade-off: Statuspage gives proper subscriber notifications, RSS, history; static page gives nothing but is free.

**ADR-0054 D9 — Tenant email references the status page.** The D9 tenant-email templates say "You can follow updates at status.honeydrunkstudios.com." The subdomain choice should match this to avoid template churn.

**ADR-0054 Operational Consequences — Atlassian Statuspage Starter deferred.** "Atlassian Statuspage Starter ($29/month) is a recommended-but-deferred adoption. The v0 fallback (static page in `Studios.HoneyDrunk.com`) is acceptable until the first paying tenant exists."

**ADR-0052 — Cost discipline.** $29/month for a status page with no audience is poor ROI. Deferred adoption fires at first paying tenant.

**ADR-0027 — Notify Cloud (first paying-tenant surface).** Notify Cloud GA is the first paying-tenant event; that is the Statuspage Starter trigger.

**ADR-0029 — Cloudflare DNS.** Subdomain DNS records use the Cloudflare convention.

## Constraints
- **No Statuspage Starter now.** Defer to first paying-tenant trigger. Document the walkthrough so adoption is single-session at trigger time.
- **v0 is acceptable.** The static page gives nothing but is free; the ADR explicitly accepts this.
- **Subdomain matches D9 template wording.** If the subdomain `status.honeydrunkstudios.com` is chosen (recommended), no D9 template edit is needed. If the path is chosen, the D9 template wording in packet 05 needs to match — coordinate.
- **Operator runbook is part of the walkthrough.** The "how to update the static page during a SEV-1/2" runbook is the v0 operational substitute for Statuspage's UI.

## Labels
`feature`, `tier-2`, `ops`, `infrastructure`, `human-only`, `adr-0054`, `wave-2`

## Agent Handoff

**Objective:** Provision the v0 static status page at `status.honeydrunkstudios.com` (or `honeydrunkstudios.com/status` — operator chooses), author the operator runbook for updating it during a SEV-1/2, and author the deferred Atlassian Statuspage Starter adoption walkthrough so the Starter is a single-session task when the first paying tenant is onboarded.

**Target:** `HoneyDrunk.Architecture` for the walkthrough doc. The Studios website edit is a small follow-on Studios PR, scoped from the walkthrough.

**Context:**
- Goal: Land the v0 tenant-facing incident surface so the D9 tenant-email templates have a working URL to link to, and document the upgrade path so Statuspage adoption is fast at trigger time.
- Feature: ADR-0054 Incident Response rollout, Wave 2.
- ADRs: ADR-0054 D9 (primary), ADR-0054 Operational Consequences (deferred), ADR-0052 (cost discipline), ADR-0027 (paying-tenant trigger), ADR-0029 (Cloudflare DNS).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0054 should be Accepted before its public-status-page surface stands up.

**Constraints:**
- No Statuspage Starter now — deferred.
- Subdomain matches D9 template wording, or coordinate with packet 05.
- Operator runbook for updating the static page during a SEV-1/2 is part of the walkthrough.

**Key Files:**
- `infrastructure/walkthroughs/statuspage-provisioning.md` (new)
- `catalogs/grid-health.json` (or equivalent) — status-page state
- `business/context/` — deferred cost annotation
- A follow-on Studios PR (out of this packet's commit scope)

**Contracts:** None changed.
