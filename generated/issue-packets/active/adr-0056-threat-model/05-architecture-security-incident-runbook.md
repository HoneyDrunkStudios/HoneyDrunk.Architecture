---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "security", "docs", "adr-0056", "wave-4"]
dependencies: ["packet:00"]
adrs: ["ADR-0056", "ADR-0054", "ADR-0030", "ADR-0050", "ADR-0019"]
accepts: ["ADR-0056"]
wave: 4
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Author the security-incident-response extensions for the incident runbook

## Summary
Author the security-specific extensions to the Grid's incident runbook per ADR-0056 D10, in `business/context/`: SEV-1-by-default posture for confirmed security incidents with the explicit downgrade-with-rationale rule; the tenant-notification path coupling ADR-0050 customer-comms cadence and ADR-0019 Communications-orchestrated outbound delivery (GDPR 72-hour alignment); the forensic-preservation hold extending audit-substrate retention beyond the 730-day standard during an active investigation; the security post-mortem's threat-model-amendment section.

## Context
ADR-0056 D10 names four security-specific extensions to the broader incident response substrate governed by ADR-0054 (Proposed):

1. **SEV-1 by default** for confirmed security incidents. Downgrade to SEV-2 requires explicit operator decision with rationale recorded. The cost of treating a real security incident as SEV-2 is meaningfully larger than the cost of treating a false-alarm as SEV-1 — the asymmetry argues for SEV-1 default.
2. **Tenant notification** when tenant data is involved. The path consumes ADR-0050's customer-comms cadence (Proposed) and ADR-0019's Communications-orchestrated delivery (Accepted). GDPR is 72 hours; US state-level breach laws vary; the artifact records the operative window per current tenant geography.
3. **Forensic preservation hold** during an active investigation. The audit substrate's standard retention is 730 days per ADR-0040 D3; the relevant log subset is exported to a separate retention key with no expiry during an investigation, released when the investigation closes. Both the export-event and the release-event are themselves auditable.
4. **Post-mortem threat-model-amendment section.** Every confirmed security incident produces a post-mortem per the existing template; security post-mortems carry an additional threat-model-amendment section asking three questions: did this incident reveal a threat the model didn't enumerate? a mitigation that was on paper but not actually in place? an accepted risk that turned out to be larger than estimated? The amendment commits to `constitution/threat-model.md` in the same PR as the post-mortem.

The extensions live in `business/context/` — the operator-context location for operational runbooks (precedent: ADR-0040 packet 08, ADR-0045 packet 06). The exact file path is verified at edit time:

- If a security-incident-runbook file already exists in `business/context/` (verify at edit time), extend it.
- If a broader incident runbook exists (per ADR-0054), add a security-extensions subsection to it.
- If neither exists, create `business/context/security-incident-runbook.md` and cross-reference ADR-0054's broader matrix.

**Coupling with ADR-0054 (Proposed) — soft.** ADR-0054 sets the broader incident severity matrix and response cadence. This packet's extensions cite ADR-0054 as the broader substrate; if ADR-0054's severity matrix evolves, these extensions stay consistent (they reference ADR-0054's matrix rather than restating it).

**Coupling with ADR-0050 (Proposed) — soft.** ADR-0050 is the tenant-comms cadence ADR (offboarding, suspension, data export). The breach-notification path consumes ADR-0050's customer-comms cadence: the channel (email per existing Communications Node), the timing alignment with regulatory windows, the content template structure. This packet's tenant-notification entry cites ADR-0050 without restating its mechanics.

**Coupling with ADR-0019 (Accepted) — concrete.** Communications Node is Accepted and v0.X is in flight. The notification *delivery* is orchestrated by `ICommunicationOrchestrator` per ADR-0019 — the breach-notification path uses Communications' existing orchestration surface, not a separate breach-only delivery path. This is consistent with invariant 41 (preference enforcement, cadence rules, suppression logic live in Communications, not in Notify).

**The post-mortem template extension.** The Grid has a post-mortem template at `generated/incidents/_template.md` (verified — `find` results from scope). Security post-mortems add a "Threat model amendment" section to that template. This packet either (a) edits `_template.md` to add the section as a conditional, or (b) creates a `_template-security.md` variant adjacent. The executor decides at edit time based on the template's existing structure.

**This is a docs packet. No code, no .NET project.**

## Scope
- The security-incident-response extensions in `business/context/` — verified file path at edit time.
- The post-mortem template extension for security incidents — either in-place edit of `generated/incidents/_template.md` or a new `_template-security.md` variant.

## Proposed Implementation

### 1. Security incident runbook content

Content of the runbook (or extension to an existing runbook). Markdown, written for the operator (the audience for `business/context/`):

```markdown
# Security incident runbook extensions

> Extends the broader incident-response substrate (ADR-0054, Proposed). For non-security incidents, see {existing runbook reference}. For the underlying threat surface this runbook responds to, see `constitution/threat-model.md`.

## Severity default

Confirmed security incidents are **SEV-1 by default** per ADR-0056 D10. Downgrade to SEV-2 requires explicit operator decision with the rationale recorded in the incident's `generated/incidents/{date}-{slug}.md` file.

**Legitimate downgrade examples:**
- A confirmed-internal-only credential leak with no external exposure window.
- A CVE alert on a dependency the Grid does not actually use in the affected code path.
- A reported "vulnerability" that on triage is correct-by-design behavior.

**Illegitimate downgrade examples:**
- "This looks like a false alarm and I don't want to wake up." Operator tiredness is not a threat-model variable.
- "We can fix it Monday." Calendar friction is not a severity argument.

A confirmed-real incident at SEV-1 carries the SEV-1 response time and escalation expectations from ADR-0054 (Proposed). Until ADR-0054 is Accepted, those expectations are described in `business/context/` adjacent to this runbook.

## Tenant notification

When tenant data is involved in a confirmed breach, the notification path:

1. **Trigger.** The operator confirms tenant data involvement and starts the notification clock. The clock starts at confirmation, not at detection.
2. **Operative window.** **GDPR — 72 hours** from confirmation for any EU-resident tenant. **US state-level — varies** (most states 30-60 days, some "without unreasonable delay"). **Default operative window: 72 hours**, the tightest applicable regulatory floor. If no EU tenants are affected and US state-level allows longer, document the rationale for the longer window — do not silently extend.
3. **Channel.** Email via the Communications Node's `ICommunicationOrchestrator` per ADR-0019 — the breach-notification path uses the same orchestration surface as all other tenant-facing comms, with preference enforcement and decision-log entries (invariants 41, 42).
4. **Content alignment with ADR-0050.** The content template aligns with the customer-comms cadence ADR-0050 (Proposed) defines for other tenant-facing notifications — same tone register, same opt-out / regulatory-exception handling, same signature surface.
5. **Content substance.** What happened (in plain language), what data was involved (specific to the affected tenant), what the operator has done about it, what the tenant should do (rotate keys, watch for fraud, contact support), how to reach the operator for follow-up.

**Cross-jurisdictional.** If a single incident affects tenants across jurisdictions with different windows, **the tightest window applies to all affected tenants** — running parallel windows by jurisdiction is operationally brittle and risks differential treatment that could itself become a finding.

## Forensic preservation hold

The audit substrate's standard retention is 730 days per ADR-0040 D3. During an active investigation:

1. **Identify the relevant subset.** The relevant `IAuditLog` subset is identified by the investigation's scope — typically a time range, a tenant scope, and an action-category scope.
2. **Export with no expiry.** The relevant subset is exported to a separate retention key that does not expire until the investigation closes. The export uses the Audit Node's read interface (per ADR-0030; the no-expiry-export-with-hold mechanism is **pending Audit Phase-2** — see the cross-track follow-up tracker, packet 09; until then, an interim mechanism is a manual export to long-retention Azure Blob with a Key Vault-stored decryption key).
3. **The export is itself an auditable event.** The audit substrate records the export-event. Releasing the hold (investigation closes) is also an auditable event.
4. **Hold release.** When the investigation closes, the operator explicitly releases the hold. The release-event is recorded. The exported subset returns to its origin retention (if still within 730 days) or is preserved if the investigation produced a record that needs longer retention than the standard window.

The preservation hold is the **only mechanism** by which audit logs escape the 730-day standard retention. The rules are explicit so the operator and any external investigator can verify that the preservation is what it claims to be.

## Post-mortem

Every confirmed security incident produces a post-mortem per the existing post-mortem template (`generated/incidents/_template.md`). Security post-mortems carry an additional **Threat model amendment** section, asking three questions:

1. **Did this incident reveal a threat the model didn't enumerate?** If yes, the amendment adds the threat to `constitution/threat-model.md` — likely in section 5 (STRIDE pass) or section 6 (AI overlay) — in the same PR as the post-mortem.
2. **Was there a mitigation that was on paper but not actually in place?** If yes, the amendment moves the mitigation from "shipped" to "open" in the artifact's section 9, and adds an issue packet to actually ship it.
3. **Did an accepted risk turn out to be larger than estimated?** If yes, the amendment revisits the accepted risk in section 7 — either accept it at a higher cost, or move it to "open mitigations" so it is no longer just-accepted.

The amendment commits to `constitution/threat-model.md` in the same PR as the post-mortem, so the artifact's history reflects what the operator learned from each incident.

## Cross-references

- ADR-0056 D10 — this runbook's source.
- ADR-0054 (Proposed) — broader incident severity matrix and response cadence.
- ADR-0050 (Proposed) — customer-comms cadence the tenant-notification content aligns with.
- ADR-0019 (Accepted) — Communications Node's orchestration surface.
- ADR-0030 — audit substrate boundaries; the forensic-preservation export interface is **pending Audit Phase-2**.
- ADR-0040 D3 — 730-day audit retention standard.
- `constitution/threat-model.md` — the artifact the post-mortem's amendment section commits to.
```

### 2. Post-mortem template extension

Verify at edit time which approach the executor chooses:

- **Option A — in-place edit.** Edit `generated/incidents/_template.md` to add a conditional "Threat model amendment (security incidents only)" section at the bottom. The conditional approach keeps a single template; non-security incidents leave the section empty or remove the header before committing.
- **Option B — variant.** Create `generated/incidents/_template-security.md` with the existing structure + the threat-model-amendment section appended. The variant approach creates clean separation but adds maintenance overhead.

Default to **Option A** unless the existing template's structure makes the conditional unwieldy. The threat-model-amendment section content is the three-question prompt from the runbook above.

## Affected Files
- A security-incident-response runbook file in `business/context/` — verified path at edit time (extend an existing file or create new).
- `generated/incidents/_template.md` (Option A) or `generated/incidents/_template-security.md` (Option B).

## NuGet Dependencies
None. Docs and template files only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. `business/context/` is the established operator-context location; `generated/incidents/` is the incident-post-mortem location, both in this repo.
- [x] No code change in any other repo.
- [x] The runbook cross-references ADR-0019's `ICommunicationOrchestrator` but does not modify Communications Node code — actual breach-notification orchestration lives in Communications, this packet only documents the operator-facing procedure.

## Acceptance Criteria
- [ ] A security-incident-response runbook exists in `business/context/` (verified file path at edit time — either extending an existing incident-runbook file or creating `business/context/security-incident-runbook.md`) carrying all four extensions: SEV-1 default + legitimate/illegitimate downgrade examples; tenant-notification path with 72-hour GDPR / cross-jurisdictional tightest-window-applies rule; forensic-preservation hold extending 730-day standard with audit-Phase-2-pending note; post-mortem threat-model-amendment section with the three-question prompt
- [ ] The runbook cross-references ADR-0054 (broader incident substrate), ADR-0050 (customer-comms cadence), ADR-0019 (Communications orchestration), ADR-0030 (audit substrate + Phase-2-pending export), ADR-0040 D3 (730-day retention), and `constitution/threat-model.md`
- [ ] The post-mortem template at `generated/incidents/_template.md` carries a Threat-model-amendment section (Option A in-place edit) OR `generated/incidents/_template-security.md` exists as a variant (Option B) — executor's choice at edit time; default Option A
- [ ] The forensic-preservation export mechanism is named as **pending Audit Phase-2** (cross-references packet 09's tracker), with an interim manual-export-to-Blob escape hatch documented
- [ ] No code change in any Node; no PR filed against Communications, Audit, or any other Node

## Human Prerequisites
None for this packet itself. (Operator follows the runbook **when a security incident actually happens** — that's the runbook's job. The runbook's existence is what this packet ships.)

## Referenced ADR Decisions
**ADR-0056 D10 — Incident response coupling.** SEV-1 by default; downgrade requires operator rationale. Tenant notification triggers ADR-0050 customer-comms cadence + ADR-0019 Communications orchestration; timeline aligns with applicable regulations (GDPR 72h). Forensic preservation extends standard retention during active investigation. Post-mortem has additional threat-model-amendment section.

**ADR-0054 (Proposed) — Incident response and on-call model.** Broader severity matrix and response cadence; this runbook's extensions sit within that framework.

**ADR-0050 (Proposed) — Tenant lifecycle.** Customer-comms cadence that the tenant-notification content aligns with.

**ADR-0019 (Accepted) — Communications Node.** `ICommunicationOrchestrator` is the orchestration surface for tenant-facing comms, including breach notifications. Invariants 41, 42 apply.

**ADR-0030 — Audit substrate.** `IAuditLog` is the source of forensic logs; the no-expiry-export-with-hold mechanism is a Phase-2 enhancement.

**ADR-0040 D3 — Audit log retention.** 730 days is the standard; the preservation hold is the only mechanism for longer retention.

## Constraints
- **Documentation only — no Node-side code change.** The runbook tells the operator what to do; the Communications-orchestrated delivery already exists per ADR-0019. The forensic-export mechanism is **pending** — the runbook names the interim manual approach.
- **72-hour GDPR window is the operating default for cross-jurisdictional incidents.** Differential treatment by jurisdiction is operationally brittle and could itself become a finding.
- **`business/context/` location follows established convention.** Match the precedent set by ADR-0040 packet 08 / ADR-0045 packet 06; extend an existing file if one exists, otherwise create new.
- **Post-mortem template extension defaults to Option A in-place edit.** Choose Option B (variant template) only if the existing template's structure makes the conditional unwieldy.
- **Forensic preservation export is named as Phase-2 pending.** Do not promise the export interface exists — it does not yet (Audit v0.1.0 shipped but the export-and-hold is a Phase-2 enhancement per the dispatch plan's cross-track deferral note).

## Labels
`feature`, `tier-2`, `meta`, `security`, `docs`, `adr-0056`, `wave-4`

## Agent Handoff

**Objective:** Author the security-incident-response runbook extensions (SEV-1 default, tenant notification via Communications, forensic preservation hold, post-mortem threat-model-amendment) in `business/context/`; extend the post-mortem template with a threat-model-amendment section.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the operator a runbook to follow when a real security incident happens, integrated with the existing Communications orchestration and the Audit substrate.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 4.
- ADRs: ADR-0056 D10 (primary); ADR-0054 (broader incident substrate, Proposed); ADR-0050 (customer-comms, Proposed); ADR-0019 (Communications, Accepted); ADR-0030 (audit, Accepted); ADR-0040 D3 (retention).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — soft. ADR-0056 should be Accepted before its operator-facing runbook lands.

**Constraints:**
- Documentation only — no Node-side code; forensic-export is Phase-2 pending with an interim manual-export note.
- 72-hour GDPR window is the cross-jurisdictional default.
- `business/context/` location follows the established convention (extend existing or create new).
- Post-mortem template defaults to Option A in-place edit.

**Key Files:**
- A runbook in `business/context/`
- `generated/incidents/_template.md` (or `_template-security.md` variant)

**Contracts:** None changed.
