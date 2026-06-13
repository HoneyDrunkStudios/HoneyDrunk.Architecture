---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["feature", "tier-2", "ops", "adr-0054", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0054", "ADR-0019", "ADR-0027"]
accepts: ["ADR-0054"]
wave: 2
initiative: adr-0054-incident-response
node: honeydrunk-communications
---

# Author the D9 tenant-incident-email templates (declaration, update, resolution) in HoneyDrunk.Communications

## Summary
Author the three D9 tenant-facing incident-email templates — **SEV-1/2 declaration**, **update**, and **resolution** — in the `HoneyDrunk.Communications` template catalog per ADR-0054 D9 / ADR-0019 D3. Wire a `TenantIncidentEmailIntent` (or equivalent ADR-0019-aligned intent type) that maps an incident-state change to one of the three templates. Send delegation continues to flow through `INotificationSender` to Notify — Communications does not touch SMTP / Resend / Twilio.

## Context
ADR-0054 D9 specifies the tenant-email surface for incident communication. The three templates are listed verbatim in ADR-0054 D9:

**SEV-1 / SEV-2 declaration:**
```
Subject: [HoneyDrunk Notify] Incident in progress affecting your account
We are currently investigating an issue affecting <tenant-name>. The impact you may see is <human description>.
Incident ID: INC-YYYY-NNNN
Status: <status>
Next update: within 60 minutes
You can follow updates at status.honeydrunkstudios.com.
```

**Update:**
```
Subject: [HoneyDrunk Notify] Update on INC-YYYY-NNNN
<one paragraph update>
Next update: within 60 minutes
```

**Resolution:**
```
Subject: [HoneyDrunk Notify] INC-YYYY-NNNN resolved
The issue affecting <tenant-name> has been resolved as of <time UTC>.
Cause: <one-line>
A post-mortem will be published within 5 business days.
Thank you for your patience.
```

ADR-0054 D9 says: "Templates are **versioned in Communications** so they update without an ADR amendment; the SLA they reference (within 60 min, 5 business days) is bound by this ADR and changes only via amendment."

Per ADR-0019, `HoneyDrunk.Communications` owns the **decision/orchestration** layer for outbound communications — the templates live here, not in Notify. The send dispatch delegates to `INotificationSender` (the Notify-Abstractions intake) which routes to Resend/SMTP for email delivery. Communications never touches SMTP / Resend / Twilio directly (invariant 41 — preference enforcement, cadence rules, and suppression logic live in Communications, not in Notify; Notify owns delivery mechanics).

**Notify Cloud in-product banner and SEV-1 ticket surface are deferred.** ADR-0054 D9 names a future in-product banner on the Notify Cloud tenant portal and an in-product SEV-1 ticket surface. Both depend on Notify Cloud (ADR-0027) which is a Seed Node — those surfaces ship with Notify Cloud, not in this packet. This packet authors **only the email templates** + intent type; in-product surfaces are a follow-on packet when Notify Cloud lands.

**Communications is live** (v0.1.0 ships the public contract surface and a welcome-email runtime slice per the catalog). This packet adds three template entries to the existing template catalog and wires the matching intent type. The template catalog convention already exists from the welcome-email work.

**Versioning.** Communications is live and versioned. This is the first ADR-0054 packet on the `HoneyDrunk.Communications` solution → minor bump per invariant 27 (new public intent type, new templates in the catalog).

## Scope
- `HoneyDrunk.Communications` — three new tenant-incident-email templates in the template catalog; the `TenantIncidentEmailIntent` (or equivalent) intent type wiring the templates to the orchestration surface.
- Communications test projects — tests covering each template's rendering, the intent → template mapping, and the delegation to `INotificationSender`.
- The decision-log entry per invariant 42 — every orchestrated send records via `ICommunicationDecisionLog`. The incident emails are orchestrated; each send records a decision.
- Repo-level `CHANGELOG.md` and per-package `CHANGELOG.md` for the packages with actual changes.

## Proposed Implementation
1. **Three template entries in the Communications template catalog.** Match the existing catalog convention (the welcome-email work already establishes how templates are registered). Each entry carries the template body, the subject template, the placeholder variables (`<tenant-name>`, `<human description>`, `INC-YYYY-NNNN`, `<status>`, `<time UTC>`, `<one-line>` cause, `<one paragraph update>`), and the channel (email).
2. **`TenantIncidentEmailIntent` (or extension to existing intent surface).** Match the existing intent pattern in Communications. Three variants — declaration / update / resolution — distinguished by an enum or sub-type. The intent carries the same placeholder fields plus the recipient resolution (tenant id → primary tenant email contact; resolved via the existing preference / recipient-resolution path that the welcome-email work already established).
3. **Map intent → template.** Communications' `ICommunicationOrchestrator` (or equivalent — match existing surface) accepts the intent, evaluates preferences/cadence/suppression (D9 implies tenants opted-in to product communication receive these; cadence for incident emails is **unrestricted** within the per-incident update cadence — the ADR specifies "every 60 min" during active incident, but that cadence is enforced by the source/orchestration, not by Communications' general cadence rule), renders the template with the placeholder substitutions, and delegates to `INotificationSender`.
4. **Cadence-rule carve-out for incident emails.** Communications' general cadence rule may rate-limit tenant emails; incident emails are explicitly **carved out** from general cadence — a tenant in a SEV-1/2 affecting them must receive every update regardless of background cadence. Implement the carve-out as a per-intent cadence override or as a documented intent-class exemption — match the existing pattern.
5. **Suppression respect.** Tenants who have unsubscribed from *transactional* communication are an edge case — incident emails are operationally critical, not marketing. Per ADR-0019's preference model, transactional communication may not be suppressible by default; if Communications' preference store distinguishes "essential service communication" from "product news," incident emails fall in the essential category. Document the policy choice in the PR.
6. **Decision log.** Per invariant 42 ("every orchestrated send records a decision-log entry via `ICommunicationDecisionLog`"), every send records — including suppressed ones (suppressed entries carry `reason: suppressed_essential_communication` or whatever the existing decision-log convention names).
7. **Delegate to `INotificationSender`.** The email body and subject flow to Notify via the existing `INotificationSender` surface — Notify's email provider (Resend or SMTP) handles delivery. Communications never touches the email provider directly.
8. **No tenant-portal in-product banner here.** ADR-0054 D9 also names a future in-product banner on the Notify Cloud tenant portal. That depends on Notify Cloud (Seed Node per ADR-0027) — it is not in this packet's scope. The banner orchestration is a follow-on packet when Notify Cloud lands.
9. **Subject branding.** The template subjects say "[HoneyDrunk Notify]" per the ADR. Confirm this matches the brand voice for paying-tenant communication; if the tenant-facing product brand is "HoneyDrunk Notify Cloud" (or similar) at the time of execution, adjust the subject to match — ADR-0054 D9 is descriptive of the v1 brand, not normative if the product brand evolves.
10. **XML documentation** on every public member (invariant 13).
11. **Version bump.** First ADR-0054 packet on the `HoneyDrunk.Communications` solution → minor bump (invariant 27).
12. **CHANGELOG / README.** Repo-level `CHANGELOG.md` new-version entry. Per-package `CHANGELOG.md` for packages with actual changes. Update the Communications `README.md` if the new template catalog surface is part of the documented public/operational surface.
13. **Tests.** Unit tests cover: each template renders correctly with the placeholder substitutions; the intent → template mapping is correct per declaration/update/resolution; the cadence carve-out is applied; the decision-log entry is recorded; the delegation to `INotificationSender` carries the right payload. Tests run in-process (invariant 15); no `Thread.Sleep` (invariant 51).

## Affected Files
- `HoneyDrunk.Communications/` — template catalog entries + intent type wiring; match existing directory layout from the welcome-email work.
- `HoneyDrunk.Communications.Abstractions/` — if the intent type is a new public abstraction, declared here.
- Communications test projects — incident-email tests.
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md` for changed packages; every non-test `.csproj` (version bump).
- `HoneyDrunk.Communications/README.md` if the incident-email surface is documented externally.

## NuGet Dependencies
- **No new external dependency.** Template rendering uses the existing `ITemplateRenderer` surface; intent orchestration uses the existing `ICommunicationOrchestrator` surface.
- The new abstraction types live in `HoneyDrunk.Communications.Abstractions` — invariant 1 (Abstractions packages take only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package they already reference). No external runtime dependency added to Abstractions.
- `HoneyDrunk.Standards` is already on Communications' projects — no change (invariant 26).

## Boundary Check
- [x] `HoneyDrunk.Communications` is the correct repo — ADR-0054 D9 names "Tenant email — `HoneyDrunk.Communications` (ADR-0019)" as the surface owner; routing rule "workflow, CI, GitHub Actions, pipeline, PR check, release → HoneyDrunk.Actions" does NOT match (incorrect rule); the matching routing rule is the workflow/orchestration template work in Communications, per the catalog description "Decision and orchestration layer for outbound communications. Determines why, when, and to whom messages are sent; enforces preferences and cadence; records decisions; delegates delivery mechanics to Notify."
- [x] Communications owns decision/orchestration; delivery delegates to `INotificationSender` → Notify (invariant 41).
- [x] No SMTP / Resend / Twilio reference in Communications (invariant 41).
- [x] Notify Cloud in-product banner / SEV-1 ticket surface are deferred to Notify Cloud (ADR-0027).
- [x] Every send records a decision-log entry per invariant 42.

## Acceptance Criteria
- [ ] Three tenant-incident-email templates (declaration / update / resolution) exist in the Communications template catalog with the verbatim ADR-0054 D9 wording (subject and body), parameterized on the placeholder variables
- [ ] A `TenantIncidentEmailIntent` (or extension of the existing intent surface — match the existing pattern) maps to the three templates by sub-type / enum
- [ ] The intent → template mapping is wired into `ICommunicationOrchestrator`; preferences/cadence/suppression are evaluated; the template is rendered with placeholder substitutions; delegation flows to `INotificationSender`
- [ ] Cadence carve-out: incident emails bypass the general cadence rate-limit; the carve-out is implemented per the existing pattern (per-intent override or intent-class exemption — documented in the PR)
- [ ] Suppression policy is documented in the PR: incident emails are essential service communication and (per the existing Communications preference model) are not suppressible by default; the policy decision is recorded
- [ ] Every send records a decision-log entry via `ICommunicationDecisionLog` (invariant 42), including suppressed sends with `reason: suppressed_essential_communication` or the equivalent convention
- [ ] Communications never references SMTP / Resend / Twilio directly (invariant 41) — all email goes through `INotificationSender`
- [ ] In-product banner / SEV-1 ticket surface are NOT implemented in this packet — they are deferred to Notify Cloud
- [ ] Every new public member has XML documentation stating its purpose and the ADR binding (invariant 13)
- [ ] Unit tests cover template rendering, intent → template mapping, cadence carve-out, decision-log recording, `INotificationSender` payload — tests run in-process (invariant 15), no `Thread.Sleep` (invariant 51)
- [ ] The version-state check is performed: the `HoneyDrunk.Communications` solution bumps (first ADR-0054 packet on the solution) — minor bump for the new template catalog (invariant 27)
- [ ] Repo-level `CHANGELOG.md` carries the new version entry; per-package `CHANGELOG.md` for packages with actual changes; `README.md` updated if the surface is documented externally
- [ ] The solution builds; existing unit tests pass; tier-1 gate passes

## Human Prerequisites
- [ ] No portal step. This is pure code work in `HoneyDrunk.Communications`.
- [ ] **Existence of tenant primary-email recipient resolution.** This packet assumes the existing welcome-email work already established a recipient-resolution path that the incident intent can reuse. If it does not, that gap surfaces during execution and may require a follow-on Communications packet — document the gap, do not block on building recipient resolution here.

## Referenced ADR Decisions
**ADR-0054 D9 — Communication channels, external paying tenants.** Tenant email through `HoneyDrunk.Communications` (per ADR-0019). SEV-1 with confirmed tenant impact: emails at declaration, hourly thereafter, at resolution. SEV-2 with confirmed tenant impact: emails at declaration if > 30 min ETA to mitigation, at resolution. Three template variants (declaration / update / resolution) with the verbatim wording given in the ADR.

**ADR-0054 D9 — Versioning split.** Templates are versioned in Communications and update without an ADR amendment; the SLA the templates reference (within 60 min, 5 business days) is bound by this ADR and changes only via amendment.

**ADR-0054 D9 — In-product surfaces deferred.** Banner-on-tenant-portal orchestration lands when Notify Cloud portal lands (ADR-0027). Not in this packet.

**ADR-0019 — Communications/Notify split.** Communications owns decision/orchestration; Notify owns delivery mechanics. Email body and subject flow to Notify via `INotificationSender`.

**ADR-0019 D3 — Template catalog.** Templates live in the Communications template catalog and are managed via the existing surface.

**ADR-0027 — Notify Cloud (Seed).** The in-product tenant banner and in-product SEV-1 ticket surface depend on Notify Cloud; not in this packet's scope.

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `HoneyDrunk.Communications.Abstractions` takes only `Microsoft.Extensions.*` abstractions plus whatever HoneyDrunk abstraction package it already references.

> **Invariant 13 — All public APIs have XML documentation.** Enforced by `HoneyDrunk.Standards`.

> **Invariant 15 — Unit tests never depend on external services.** Template-rendering and orchestration tests run in-process.

> **Invariant 26 — Work items for .NET code work include a `## NuGet Dependencies` section; `HoneyDrunk.Standards` is on every new .NET project**.

> **Invariant 27 — All projects in a solution share one version and move together.** First ADR-0054 packet on `HoneyDrunk.Communications` → version bumps.

> **Invariant 31 — Every PR traverses the tier-1 gate before merge.**

> **Invariant 40 — Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`.** The new intent type, if a public abstraction, lives in Abstractions; runtime composition is host-time.

> **Invariant 41 — Preference enforcement, cadence rules, and suppression logic for outbound messages live in `HoneyDrunk.Communications`, not in `HoneyDrunk.Notify`.** This packet's templates and intent live in Communications; Notify never knows the incident-email semantics — it only ships an email payload.

> **Invariant 42 — Every orchestrated send records a decision-log entry via `ICommunicationDecisionLog`.** Each incident-email send records — including suppressed ones with the documented reason.

> **Invariant 43 — Communications CI must include a contract-shape canary for the hot-path orchestration contracts.** If the new intent type is part of the hot-path orchestration contract, the canary covers it.

> **Invariant 51 — Test code contains no `Thread.Sleep`.**

- **Verbatim ADR wording.** The three template bodies use the exact wording in ADR-0054 D9 (subject lines included). Diverging from the wording requires an ADR amendment (D9 binds it).
- **Cadence carve-out for incident emails.** Incident emails bypass the general cadence rule; suppression respects only the "essential service communication" carve-out documented per the existing Communications preference model.
- **No SMTP / Resend / Twilio in Communications.** Delivery delegates to `INotificationSender` always (invariant 41).
- **In-product surfaces are deferred** to Notify Cloud — out of scope here.

## Labels
`feature`, `tier-2`, `ops`, `adr-0054`, `wave-2`

## Agent Handoff

**Objective:** Add the three D9 tenant-incident-email templates (declaration / update / resolution) and the matching intent type to `HoneyDrunk.Communications`, with delegation through `INotificationSender` to Notify for delivery.

**Target:** `HoneyDrunk.Communications`, branch from `main`.

**Context:**
- Goal: Land the external tenant-facing comms surface ADR-0054 D9 specifies, so the incident-response process can communicate with paying tenants per the SLA.
- Feature: ADR-0054 Incident Response rollout, Wave 2.
- ADRs: ADR-0054 D9 (primary), ADR-0019 (decision/orchestration ownership), ADR-0027 (Notify Cloud surfaces deferred).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0054 should be Accepted before its communication templates land.

**Constraints:**
- Verbatim D9 wording.
- Cadence carve-out for incident emails.
- No SMTP/Resend/Twilio in Communications (invariant 41).
- In-product banner / SEV-1 ticket surface are NOT in this packet.
- Perform the invariant-27 version-bump check on `HoneyDrunk.Communications` — first ADR-0054 packet → bumps.

**Key Files:**
- `HoneyDrunk.Communications/` — template catalog entries + intent type wiring (match existing welcome-email work layout)
- `HoneyDrunk.Communications.Abstractions/` — public intent type if needed
- Communications test projects
- Repo-level `CHANGELOG.md`; per-package `CHANGELOG.md`; non-test `.csproj` (version bump)

**Contracts:**
- `TenantIncidentEmailIntent` (or equivalent — match the existing intent surface) — three variants for declaration / update / resolution.
