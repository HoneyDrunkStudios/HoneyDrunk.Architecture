---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "ops", "adr-0057", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0057"]
wave: 1
initiative: adr-0057-api-versioning
node: honeydrunk-architecture
---

# Author the per-API migration-guide template, deprecation runbook, and docs-subdomain provisioning playbook

## Summary
Author three operator-facing reference documents that govern day-to-day execution of ADR-0057's policies once the substrate is live: (1) a per-API **migration-guide template** at `infrastructure/walkthroughs/public-api-migration-guide-template.md` that every v(N+1) release fills in; (2) a per-API **deprecation runbook** at `infrastructure/walkthroughs/public-api-deprecation-runbook.md` covering the operator side of the 180-day lifecycle (announcement, header emission, the T-90 / T-30 / T-7 cadence, sunset cutover, post-sunset rejection audit); (3) a per-API **docs-subdomain provisioning playbook** at `infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md` capturing the Cloudflare DNS records, the Cloudflare Pages target, and the Studios-sector handoff for any new `docs.{api}.honeydrunkstudios.com` site. These are reference documents that consuming packets and future follow-ups read; no code, no .NET project.

## Context
ADR-0057's Follow-up Work list calls out: *"Author per-API migration guides (template) for when v(N+1) ships; the template lives in the docs-generation tooling."* and *"Document the docs-subdomain provisioning playbook in `repos/HoneyDrunk.Studios/` (or equivalent)."* This packet centralizes both in the Architecture repo so they are reviewable and discoverable from the same place ADR-0057 lives; the Studios-sector side ship in packet 09 references this playbook for the concrete first-instance DNS provisioning.

The deprecation runbook is the human-facing companion to the `deprecation-notification` named flow catalogued in packet 01. The runbook covers the operator side: what to push when, what to monitor, when to roll forward and when to roll back. It complements (does not replace) the automated tenant-notification orchestration in Communications + Notify; ADR-0057 D5's audited rejections require a human-readable "what to do" document for the operator when something does not fire on schedule.

The docs-subdomain provisioning playbook documents per-instance work: Cloudflare DNS CNAME at the apex (`docs.notify.honeydrunkstudios.com` → Cloudflare Pages target), Pages project creation, branch/build-output binding, custom domain attachment, TLS certificate issuance, and the Cloudflare Access rule (if any). Per ADR-0029 (Cloudflare DNS rollout) the DNS records live in the Cloudflare-managed zone; the Pages project is per-Studios. The playbook is the operator's checklist.

None of these documents are themselves load-bearing for any code path. They are referenced by:
- **Packet 04** (the SDK-publication workflow) — the migration-guide template is the asset OpenAPI Generator-driven CHANGELOG entries link to when a major bumps.
- **Packet 08** (Notify Phase 2) — the first concrete migration-guide instance will be rendered from this template when Notify v2 first ships.
- **Packet 09** (Studios docs-subdomain provisioning for `docs.notify`) — the first concrete docs-subdomain provisioning instance references this playbook.
- **Future deprecation events** (any) — the runbook is consulted at the moment of announcement.

This is a docs-only packet. No catalog change beyond what packet 01 introduced; no code.

## Scope
- **New document:** `infrastructure/walkthroughs/public-api-migration-guide-template.md`
- **New document:** `infrastructure/walkthroughs/public-api-deprecation-runbook.md`
- **New document:** `infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md`
- No other catalog or governance file modified.

## Proposed Implementation

1. **`infrastructure/walkthroughs/public-api-migration-guide-template.md`** — author a fillable template the v(N+1) release uses to produce its concrete migration guide. Required sections:
   - **Title:** "Migrating from {Surface} v{N} to v{N+1}"
   - **Released:** the v(N+1) GA date.
   - **Sunset:** the v{N} sunset date (release date + at-minimum 180 days per ADR-0057 D5).
   - **Summary of breaking changes:** one line per change, citing the ADR-0057 D4 category (`Removed endpoint`, `Renamed field (request)`, `Renamed field (response)`, `Type narrowing`, `Semantic change`, `Removed enum value`, `Added required request field`, `Changed error code mapping`, `Changed authentication requirement`, `Changed rate-limit envelope`, `Changed pagination scheme`).
   - **Per-endpoint diff sections** — for each changed endpoint, paired request and response examples (v{N} → v{N+1}); the SDK migration snippet (TypeScript / Swift / Kotlin) showing the equivalent call with the new shape.
   - **Auto-migration support** — if the OpenAPI Generator template enables auto-mapping (e.g., a field rename can be auto-handled by the SDK at deserialization), state it here. Per ADR-0057 D8, the SDK generation does *not* attempt cross-major auto-migration by default; this section is usually "None — pin to the new SDK major and update call sites."
   - **Rollback** — pinning back to v{N} is a one-line dependency revert; v{N} stays live for the full deprecation window per D6. State the explicit version pin (e.g. `"@honeydrunk/notify-sdk": "^1.0.0"`).
   - **Pre-sunset and sunset deadlines** — T-90 / T-30 / T-7 windows with the dates filled in; what the tenant sees in each window (Deprecation header on every response, then Sunset header counting down).
   - **Support contact / docs URL** — the per-API support route; the migration-guide is itself published at `docs.{api}.honeydrunkstudios.com/v{N}/migrating-to-v{N+1}/`.
   - **Required follow-up steps if you depend on a deprecated field/endpoint past sunset** — the request is rejected per ADR-0057 D5; the rejection carries the per-D12 problem-details `type: https://docs.honeydrunkstudios.com/errors/common/endpoint-sunsetted`.
   - At the bottom, mark the template fields with `{{placeholders}}` so a future Codex / Claude run can render a concrete instance by substitution.

2. **`infrastructure/walkthroughs/public-api-deprecation-runbook.md`** — author the operator playbook for the 180-day lifecycle. Required sections:
   - **Pre-announcement checklist** — confirm the v(N+1) GA has shipped (the SDKs are live on npm / Maven / SPM at v(N+1).0.0; the docs site `docs.{api}.honeydrunkstudios.com/v{N+1}/` is live); confirm the migration guide is rendered and published at `docs.{api}.honeydrunkstudios.com/v{N}/migrating-to-v{N+1}/`.
   - **Announcement** — the operator-side step that flips the v{N} surface into deprecation: enable the `Deprecation` + `Sunset` + `Link rel="successor-version"` headers (configured per-Node — usually a feature-flag or an OpenAPI spec amendment on the v{N} spec marking the deprecation timestamps); seed the active-tenant list (every tenant whose API key touched a v{N} endpoint within the prior 30 days) to Communications; record the announcement event in the Audit substrate per ADR-0030.
   - **T-90 monitoring** — Communications dispatches the first email batch via Notify; confirm the dispatch event in the audit log; check the per-tenant traffic on v{N} (have the largest tenants begun migrating?).
   - **T-30 monitoring** — second email batch; per-endpoint traffic check; flag tenants whose traffic on v{N} has not declined (the migration is at risk).
   - **T-7 monitoring** — third email batch; per-tenant traffic per day reported in the email body; a personal-outreach decision for any high-traffic non-migrated tenant.
   - **Sunset cutover** — flip the v{N} surface off (a feature-flag flip or a v{N} spec removal from the host); confirm every v{N} request is now returning the per-D12 problem-details envelope with `type: https://docs.honeydrunkstudios.com/errors/common/endpoint-sunsetted`; the Audit substrate records each rejected request.
   - **Post-sunset week** — monitor the post-sunset rejection audit stream; reach out to any tenant whose traffic is still hitting v{N} (they get hard 404s now; their integration is broken).
   - **Post-sunset month** — archive the v{N} docs site to `docs.{api}.honeydrunkstudios.com/archive/v{N}/`; the v{N} SDK lines on npm / Maven / SPM are marked deprecated in the registry but **not unpublished** (unpublishing breaks any frozen consumer build per ADR-0057 D9).
   - **Off-cadence rollback** — if the operator decides to extend the deprecation window past the announced sunset (e.g., a major tenant requests more time), the announcement is amended (new `Sunset` header date), the audit substrate records the amendment, the T-90 / T-30 / T-7 cadence does NOT replay (the original cadence already fired); the tenant receives a manual notification. Document this as a non-default path.
   - **Operator escalation contacts** — who to page if Communications + Notify do not dispatch at T-90 / T-30 / T-7 (the named flow is in Communications; failures are observable per ADR-0040 / ADR-0045).
   - At the top of the runbook, a one-paragraph summary: "Use this runbook when announcing the deprecation of an endpoint or entire major version per ADR-0057 D5. The 180-day window is the hard floor; longer windows are permitted. The T-90 / T-30 / T-7 tenant emails are automated via the `deprecation-notification` named flow in `constitution/feature-flow-catalog.md`. This runbook is the operator-side procedure that pairs with that automated flow."

3. **`infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md`** — author the operator playbook for provisioning a new `docs.{api}.honeydrunkstudios.com` site. Required sections:
   - **Pre-provisioning checklist** — Cloudflare DNS account credentials available; Cloudflare Pages project provisioning rights confirmed; the per-API repo's `docs/` directory exists with the Docusaurus + Scalar composition committed; the OpenAPI spec for the surface is checked in.
   - **DNS provisioning** — in Cloudflare DNS, add a `CNAME` record at `docs.{api}.honeydrunkstudios.com` pointing to the Cloudflare Pages target (the convention: `honeydrunk-docs-{api}.pages.dev`). Proxy through Cloudflare (orange-cloud ON) for the TLS cert + DDoS at the edge per ADR-0029. **Note that ADR-0029 names Cloudflare as the DNS substrate;** if a Studios-side Bicep template ever provisions the records via Cloudflare's API, the template lives in `HoneyDrunk.Studios` (per ADR-0077 IaC posture, currently Proposed) — until then DNS is portal-provisioned per the user's portal-over-CLI preference.
   - **Cloudflare Pages project** — create a new Pages project named `honeydrunk-docs-{api}`. Bind it to the per-API repo's branch (`main`); build command runs the Docusaurus build that the `job-publish-docs.yml` workflow (packet 05 of this initiative) emits; output directory `build/` (Docusaurus default). Attach the custom domain `docs.{api}.honeydrunkstudios.com`; verify TLS certificate issuance via Cloudflare-managed cert.
   - **Access policy** — Cloudflare Access policy is **none by default** — docs sites are public. If a specific docs site needs to be Studios-internal during pre-GA development, an Access policy can be added; that decision is per-API and is noted in the Pages project's notes.
   - **Per-version path routing** — the Docusaurus + Scalar composition handles per-major-version path routing (`/v1/`, `/v2/`, etc.) internally; the Pages project itself is single-instance per surface. The version switcher in the top navigation crosses majors at the same conceptual path per ADR-0057 D15.
   - **Archiving** — when a major sunsets per D6, the archive copy lives at `/archive/v{N}/` within the same Pages project (one-time copy at sunset; the live `/v{N}/` path can be removed or kept and just renamed; usually renamed for backlink stability).
   - **Cost note** — Cloudflare Pages is free at the Studios traffic ceiling (per the user's `feedback_default_cheapest_azure_tier` rule extended to vendor SaaS — free tier is the default until a concrete reason forces a paid tier).
   - **Studios-sector cross-link** — the Studios sector (per ADR-0029) owns the apex `honeydrunkstudios.com` and `*.honeydrunkstudios.com` subdomains. New API docs subdomains live in the Studios sector's responsibility per ADR-0057 §Cross-ref Studios sector. Packet 09 of this initiative is the first concrete instance (`docs.notify.honeydrunkstudios.com`) and consumes this playbook.

4. Run a quick consistency check: every URL pattern referenced in the three documents matches ADR-0057 D5 / D12 / D15 verbatim (`docs.{api}.honeydrunkstudios.com`; `docs.honeydrunkstudios.com/errors/`; `docs.{api}.honeydrunkstudios.com/v{N}/`; `docs.{api}.honeydrunkstudios.com/archive/v{N}/`).

## Affected Files
- `infrastructure/walkthroughs/public-api-migration-guide-template.md` (new)
- `infrastructure/walkthroughs/public-api-deprecation-runbook.md` (new)
- `infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md` (new)

## NuGet Dependencies
None. This packet authors Markdown reference documents; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No catalog or invariant change in this packet — packet 00 wrote the four invariants; packet 01 wrote the catalog updates; this packet authors the operator-facing reference documents that the substrate workflows (packets 03-06) and the per-API instance packets (07-10) consult.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/public-api-migration-guide-template.md` exists with the required sections (title, released, sunset, summary of breaking changes by D4 category, per-endpoint diffs, SDK snippets in TS / Swift / Kotlin, rollback pin, T-90 / T-30 / T-7 deadlines, support contact / docs URL, post-sunset behavior) and `{{placeholder}}` markers throughout
- [ ] `infrastructure/walkthroughs/public-api-deprecation-runbook.md` exists with the required sections (pre-announcement, announcement, T-90 / T-30 / T-7 monitoring, sunset cutover, post-sunset week, post-sunset month, off-cadence rollback, operator escalation, top-of-doc summary)
- [ ] `infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md` exists with the required sections (pre-provisioning checklist, DNS provisioning, Cloudflare Pages project, Access policy default, per-version routing, archiving, cost note, Studios-sector cross-link)
- [ ] URL patterns match ADR-0057 D5 / D12 / D15 verbatim across all three documents
- [ ] No catalog or constitution file is modified
- [ ] No code or .NET project change

## Human Prerequisites
None. The documents are reference text; they are consulted by future operator actions but require no portal step at packet-execution time.

## Referenced ADR Decisions
**ADR-0057 D5 — Deprecation policy.** RFC 8594 `Deprecation` + `Sunset` + `Link rel="successor-version"`; 180-day minimum lifecycle; T-90 / T-30 / T-7 emails through Communications + Notify; audit via Audit substrate.

**ADR-0057 D6 — Two-major coexistence.** A new major cannot be released until v(N-1) has been sunsetted. This forces a roughly six-month-floor cadence and disciplines major-version planning.

**ADR-0057 D12 — RFC 7807 error envelope.** `type` URI host at `docs.honeydrunkstudios.com/errors/`. Two error types referenced by the deprecation runbook: `https://docs.honeydrunkstudios.com/errors/common/endpoint-sunsetted` (post-sunset request rejected) and `https://docs.honeydrunkstudios.com/errors/common/cursor-expired` (D14 — cursor TTL).

**ADR-0057 D15 (reconciled with ADR-0075 — 2026-05-24) — Docs site composition.** Scalar + Docusaurus at `docs.{api}.honeydrunkstudios.com`; per-major version prefix `/v{N}/`; OpenAPI reference at `/v{N}/api/`; archived majors at `/archive/v{N}/`.

**ADR-0029 (referenced) — Cloudflare DNS rollout.** DNS is Cloudflare-managed; new subdomains are provisioned via the Cloudflare portal or (future) Bicep templates. TLS via Cloudflare-managed cert.

**ADR-0019 (referenced) — Communications / Notify split.** Communications owns decision/orchestration of tenant notification cadence; Notify owns intake/delivery. The deprecation-notification named flow (packet 01) lives in Communications.

**ADR-0030 (referenced) — Audit substrate.** Every deprecation announcement, every per-tenant T-90 / T-30 / T-7 dispatch, and every post-sunset rejected request are recorded via `IAuditLog`.

## Constraints
- **No code change.** All three documents are operator reference text.
- **URL patterns match the ADR verbatim.** The error `type` URIs, the docs subdomain pattern, the per-major path prefix — every URL pattern in the documents matches ADR-0057's source-of-truth wording. A reviewer can grep the three documents against the ADR and find no drift.
- **Studios-sector cross-link is one-way.** The docs-subdomain provisioning playbook lives in `HoneyDrunk.Architecture` (here); packet 09 (Studios) consumes it without re-authoring. There is no parallel Studios-side document; the Architecture document is canonical.
- **No invariant edits.** ADR-0057's four invariants land via packet 00; the operator playbooks here do not codify new constitutional rules.

## Labels
`feature`, `tier-2`, `core`, `docs`, `ops`, `adr-0057`, `wave-1`

## Agent Handoff

**Objective:** Author three operator-facing reference documents in `infrastructure/walkthroughs/`: a per-API migration-guide template, a 180-day deprecation runbook, and a docs-subdomain provisioning playbook. All three are referenced by downstream packets and by future deprecation events.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the operator-side execution of ADR-0057's lifecycle (announcement, header emission, tenant notification, sunset, archive) procedural rather than ad-hoc; pair the automated `deprecation-notification` named flow with a documented operator playbook.
- Feature: ADR-0057 Public HTTP API Versioning and Client SDK Strategy rollout, Wave 1.
- ADRs: ADR-0057 D5 / D6 / D12 / D15 (primary); ADR-0029 (Cloudflare DNS); ADR-0019 (Communications / Notify split); ADR-0030 (Audit substrate); ADR-0075 (docs composition); ADR-0077 (IaC Bicep — future-state cross-link).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — the invariants must be live so the migration guide / runbook reference them by number (the documents cite invariants `{N1}-{N4}` once resolved).

**Constraints:**
- No code change. No catalog or constitution edit.
- URL patterns match ADR-0057 verbatim.
- Three new files only.

**Key Files:**
- `infrastructure/walkthroughs/public-api-migration-guide-template.md`
- `infrastructure/walkthroughs/public-api-deprecation-runbook.md`
- `infrastructure/walkthroughs/public-api-docs-subdomain-provisioning.md`

**Contracts:** None.
