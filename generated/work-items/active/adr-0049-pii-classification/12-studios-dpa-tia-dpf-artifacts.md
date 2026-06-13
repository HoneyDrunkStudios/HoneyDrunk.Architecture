---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Studios
labels: ["feature", "tier-2", "meta", "adr-0049", "wave-6", "human-only"]
dependencies: ["work-item:00"]
adrs: ["ADR-0049", "ADR-0036"]
wave: 6
initiative: adr-0049-pii-classification
node: honeydrunk-studios
---

# Author the DPA template, the v1 Transfer Impact Assessment, and the DPF enrollment artifact location

## Summary
Author the three commercial/legal artifacts that ADR-0049 Phase 5 commits the Studio to land:

1. **Data Processing Agreement (DPA) template** incorporating EU Standard Contractual Clauses (2021 module 2 controller-to-processor; module 4 processor-to-controller) plus the UK ICO's International Data Transfer Addendum. Closes ADR-0036 D7's deferred DPA work.
2. **v1 Transfer Impact Assessment (TIA)** for the Azure US East 2 hosting choice, asserting US adequacy via the EU-US Data Privacy Framework (DPF) certification.
3. **DPF enrollment artifact location** in `business/legal/dpf/` (or matching path) documenting the annual $250 fee, the compliance attestation process, and the operator-owned renewal cadence.

These are **commercial/legal artifacts**, not code. They land in `HoneyDrunk.Studios`'s `business/` folder (the existing home for legal/commercial documents per the studio's `business/` convention used by the Notify Cloud standup ADR-0027 packets). The packet is **`Actor=Human`** for the legal authoring; an agent can prepare structure and template scaffolding, but the legal review and the DPF enrollment payment are human-only.

> **`Actor=Human` rationale.** Per the scope agent's Actor field convention, `Actor=Human` is reserved for work items whose *entire* substance cannot be delegated. Legal-document authoring against regulatory text (GDPR Article 28 for DPAs, Article 46 for SCC mechanism, Schrems II + DPF for TIAs) is judgment-bearing legal work that the studio operator owns. An agent can scaffold a template and pre-fill the easy fields; the operator must complete the legal substance. The DPF enrollment itself is an external payment + attestation; no agent action exists for it. Hence the entire packet is `Actor=Human` and carries the `human-only` label.

## Context
ADR-0049 D7 commits Azure US East 2 as the v1 data-residency posture and names three follow-up artifacts that operationalize the lawful basis for EU/UK personal data hosted in the US:

- **DPA (Data Processing Agreement) template** — referenced by ADR-0036 D7 and not yet authored. The template incorporates the EU Standard Contractual Clauses (2021 modules 2 and 4) and the UK ICO's International Data Transfer Addendum, providing the Article 46 mechanism for cross-border transfers. A signed enterprise contract requiring a DPA will block on this template existing.
- **v1 Transfer Impact Assessment (TIA)** — required under post-Schrems II EU case law. The v1 TIA asserts US adequacy via DPF certification (conditional on enrollment); until enrolled, the Studio relies on SCCs alone.
- **DPF enrollment** — annual $250 fee + compliance attestation. Operator-owned external action. Missing the renewal does not break the architecture but invalidates the TIA's adequacy argument; the architecture commitments in this ADR enable but do not perform the enrollment.

ADR-0049 Phase 5 schedules these for month 2–3 of the rollout, **after** the architectural commitments in Phases 1–4 are in place. Per ADR-0049 Operational Consequences: "DPA/TIA artifacts are commercial requirements, not architectural. They are named here because the architecture commitments enable them, but their authoring is operator work."

## Scope
- `business/legal/dpa-template.md` (or matching path under `HoneyDrunk.Studios`'s `business/` convention — read the repo at branch time for the canonical legal-document location).
- `business/legal/tia-v1.md` — the v1 Transfer Impact Assessment.
- `business/legal/dpf/README.md` — DPF enrollment artifact location, documenting the renewal cadence, fee, and attestation procedure.
- `business/legal/README.md` — index of the legal-document tree (if not already present).

## Proposed Implementation

### DPA template structure

The template covers the substance Article 28 GDPR requires for a controller-to-processor DPA. Sections:

1. **Parties and definitions.** Studio (HoneyDrunk Studios LLC, Florida) as processor; the customer as controller. Definitions of personal data, processing, sub-processor, data subject — aligned with GDPR Article 4.
2. **Subject matter and duration.** Tied to the customer's Notify.Cloud / Studio-product subscription.
3. **Nature and purpose of processing.** The specific operations (delivery, orchestration, telemetry, audit).
4. **Categories of data subjects and types of personal data.** Tied to ADR-0049 D2's PII sub-taxonomy.
5. **Processor obligations** per Article 28(3):
   - Process only on documented instructions.
   - Confidentiality obligations on personnel.
   - Article 32 technical/organizational measures — point to the TIA and the Studio's security posture (incident response per ADR-0054, threat model per ADR-0056).
   - Sub-processor engagement with general written authorization + 14-day-notice substitution clause.
   - Data subject rights assistance — point to ADR-0050's tenant-lifecycle mechanics for erasure/access/portability.
   - Article 33/34 breach notification — 72-hour controller notification.
   - End-of-processing data return/deletion options.
   - Audit rights — annual, reasonable-notice, scope-limited.
6. **International transfers.** Standard Contractual Clauses (Commission Implementing Decision (EU) 2021/914 of 4 June 2021) incorporated by reference; module 2 (controller-to-processor) as the default; module 4 (processor-to-controller) where the customer is the data importer. UK ICO IDTA incorporated by reference for UK personal data.
7. **TIA reference.** The Studio's v1 TIA (next file) is referenced; the customer acknowledges they have reviewed it.
8. **Liability and indemnification.** Standard.
9. **Termination.** Tied to the subscription.
10. **Governing law.** Florida (BDR-0001) plus the SCCs' own governing-law clauses for EU/UK data subject rights.

### v1 TIA structure

Per Schrems II's requirements + EDPB Recommendations 01/2020:

1. **Transfer details.** Studio (data exporter, processor) → Azure US East 2 (Microsoft Corporation, data importer in third country). Data categories: tenant operational data, user PII, audit records, telemetry per ADR-0049 D2.
2. **Adequacy basis.** EU-US Data Privacy Framework — Microsoft's certification under DPF. **Conditional language:** "The Studio's reliance on DPF requires Studio's own DPF enrollment (Phase 5 follow-up); until enrolled, the SCCs (DPA section 6) provide the Article 46 mechanism alone."
3. **US legal regime assessment.** FISA Section 702, Executive Order 12333, USA FREEDOM Act — third-country surveillance practices. Microsoft's transparency report and the DPF's EO 14086 redress mechanism cited as mitigations.
4. **Supplementary measures.** Encryption at rest (Azure-native), encryption in transit (TLS 1.2+ Grid-wide), access controls (per ADR-0005 RBAC, ADR-0006 secret rotation), audit logging (per ADR-0030).
5. **Conclusion.** Risk acceptable for v1; reassessed at every BDR-significant milestone (Studio entity change, first non-US tenant, first EU-resident enterprise customer).
6. **Review cadence.** Annual, plus event-driven re-review.

### DPF enrollment artifact location

The `business/legal/dpf/` folder contains:

1. `README.md` — operator runbook covering:
   - The $250/year fee and the enrollment portal URL (Department of Commerce).
   - The annual self-certification renewal cadence.
   - The required public privacy policy elements (Notice principle; Choice; Accountability for Onward Transfer; Security; Data Integrity & Purpose Limitation; Access; Recourse, Enforcement, & Liability).
   - The redress mechanism (DPF Panel + Federal Trade Commission backstop).
   - Where the enrollment-certificate file lives once issued (`certificates/` subfolder, with the cert PDF or JSON).
2. `certificates/.gitkeep` — placeholder so the certificates folder exists.

### Authoring approach (the human/agent split)

An agent CAN draft:
- Section headers and structural outlines for all three documents.
- Citations to ADR sections, invariants, and other Grid artifacts.
- The DPF runbook (mostly procedural and operator-facing, not legal-substance).
- The TIA's "Transfer details" and "Supplementary measures" sections (factual technical descriptions).
- Cross-references between the three documents.

An agent CANNOT (without operator legal review):
- Article 28 DPA legal substance — the operator confirms each clause aligns with the studio's commercial posture and Florida LLC operating model.
- TIA risk-acceptance conclusion — the operator owns the risk decision.
- The customer-counterparty signature flow (a customer's DPA review and signing is an operator-conducted commercial negotiation).
- The DPF enrollment payment itself ($250 to the Department of Commerce).

This packet therefore proceeds in two stages on `HoneyDrunk.Studios`:

**Stage 1 (the agent-completable part).** An agent opens a PR with the structural scaffolding: file paths created; section headers and ADR cross-references filled in; the TIA's technical descriptions filled in; the DPF runbook fully authored; the DPA's procedural sections (parties, definitions, duration tied to subscription, processor obligations procedural, termination, governing law) authored. Sections requiring legal-substance authorship are left as `[OPERATOR: complete this section per Article 28(3)(c)]` placeholders.

**Stage 2 (the operator-only part).** The operator completes the legal substance sections, runs an external legal review if desired, and merges. The DPF enrollment payment + certificate acquisition happens outside this PR — the certificate lands in `business/legal/dpf/certificates/` via a separate small commit at the operator's pace.

## Affected Files
- `business/legal/dpa-template.md` (new).
- `business/legal/tia-v1.md` (new).
- `business/legal/dpf/README.md` (new).
- `business/legal/dpf/certificates/.gitkeep` (new — placeholder).
- `business/legal/README.md` (new or amended — index of the legal-document tree).
- Possibly `business/README.md` if the legal subfolder didn't previously exist.

## NuGet Dependencies
None. Markdown only.

## Boundary Check
- [x] All edits in `HoneyDrunk.Studios` under `business/legal/`. Routing rule "website, Studios, Next.js, pages, blog → HoneyDrunk.Studios" maps — the studio site repo houses the studio's business/legal documents too (the Studios repo also houses `business/` per the ADR-0027 standup pattern). The legal documents are NOT customer-facing on the website at v1 — they sit in the repo for internal use plus operator-controlled sharing.
- [x] No code change.
- [x] No new cross-Node dependency.

## Acceptance Criteria
- [ ] `business/legal/dpa-template.md` exists with the 10-section structure above; sections requiring operator legal-substance authorship are marked `[OPERATOR: ...]` placeholders
- [ ] `business/legal/tia-v1.md` exists with the 6-section structure above; the "Transfer details" and "Supplementary measures" sections are agent-completed; the "Conclusion" section is an `[OPERATOR: ...]` placeholder
- [ ] `business/legal/dpf/README.md` exists with the operator runbook fully authored (fee, portal URL, renewal cadence, privacy-policy elements, redress mechanism, certificate-file location)
- [ ] `business/legal/dpf/certificates/.gitkeep` exists
- [ ] `business/legal/README.md` exists or is updated to index the new documents and explain the agent-vs-operator authoring split
- [ ] All ADR cross-references (to ADR-0049 D7, ADR-0036 D7, ADR-0026, ADR-0005, ADR-0006, ADR-0030, ADR-0050, ADR-0054, ADR-0056, BDR-0001) are accurate and link to the actual files in `HoneyDrunk.Architecture`
- [ ] The PR body explicitly flags the operator-only sections and the DPF enrollment payment as out-of-scope-of-the-agent-PR
- [ ] The `human-only` label is applied (per the user's `human-only` label convention)
- [ ] The packet's `Actor=Human` is reflected on the project board

## Human Prerequisites
- [ ] **Complete the `[OPERATOR: ...]` placeholder sections in the DPA template** — Article 28 clause-by-clause legal authoring; commercial-posture decisions on sub-processor authorization, audit-rights scope, and liability caps.
- [ ] **Complete the TIA "Conclusion" section** — the risk-acceptance decision is the operator's.
- [ ] **Pay the DPF enrollment fee** ($250/year, Department of Commerce) and complete the self-certification at https://www.dataprivacyframework.gov/ — external action.
- [ ] **Download the DPF certificate** upon issuance and commit it to `business/legal/dpf/certificates/`.
- [ ] **Optional external legal review** of the DPA template before customer use (this packet does not commission such review; the operator decides whether to engage outside counsel).
- [ ] **Set the annual DPF renewal calendar reminder** so the certificate doesn't lapse and invalidate the TIA.

## Referenced ADR Decisions
**ADR-0049 D7 — v1 Azure US East 2 + SCCs + DPF.** "The Studio uses the EU Standard Contractual Clauses (2021 module 2 controller-to-processor; module 4 processor-to-controller as applicable) plus the UK ICO's International Data Transfer Addendum. The Data Processing Agreement (DPA) template referenced by ADR-0036 D7 and not yet authored must incorporate SCCs by reference. This is a deferred follow-up of this ADR. The Studio publishes a Transfer Impact Assessment (TIA) for the US East 2 hosting choice; v1 TIA asserts US adequacy via the EU-US Data Privacy Framework (DPF) certification, conditional on the Studio enrolling in DPF. DPF enrollment is a follow-up (annual $250 fee + compliance attestation); until enrolled, the Studio relies on SCCs alone."

**ADR-0049 D10 Phase 5 — DPA, TIA, DPF.** "Author the DPA template incorporating SCCs (closes the ADR-0036 D7 deferred work). Author the v1 TIA. Enroll in EU-US Data Privacy Framework (operator action; $250/year). These are the commercial/legal artifacts that the architectural decisions in this ADR enable; without them, the architecture commitments are unprovable to a customer."

**ADR-0036 D7 — DPA template deferred.** Originally deferred; this packet closes that follow-up alongside the TIA and DPF artifacts.

**ADR-0049 Operational Consequences — DPA/TIA are commercial requirements.** "They are named here because the architecture commitments enable them, but their authoring is operator work. A signed enterprise contract that requires a DPA will block on Phase 5 completion if it precedes it."

**ADR-0049 D6 — Right-to-erasure mechanics handed to ADR-0050.** The DPA's data-subject-rights-assistance clause references ADR-0050's tenant-lifecycle mechanics for erasure/access/portability.

**BDR-0001 — Florida LLC.** Governing law clause in the DPA defaults to Florida; supplemented by the SCCs' own governing law for EU data subject rights.

## Constraints
- **`Actor=Human` with `human-only` label.** The legal-substance authoring is operator-only.
- **Two-stage workflow.** Stage 1 is the agent-completable scaffolding + procedural sections; Stage 2 is the operator-completed legal substance + DPF enrollment payment. The agent PR closes Stage 1; Stage 2 happens in subsequent commits at the operator's pace.
- **Customer-counterparty signature flow is out of scope.** Each customer's DPA review and signature is a commercial negotiation, not a packet.
- **External legal review is optional, not mandatory.** This packet does not commission outside counsel. The operator decides whether to engage one.
- **Documents are NOT customer-facing on the website at v1.** They sit in the Studios repo's `business/legal/` folder; the operator shares them with customers via secure channels (signed PDFs, executed contracts), not as published pages.
- **All ADR cross-references must be accurate** — confirm each citation's section number and the target ADR's current status before linking.

## Labels
`feature`, `tier-2`, `meta`, `adr-0049`, `wave-6`, `human-only`

## Agent Handoff

**Objective:** Author the structural scaffolding + procedural sections of the DPA template, the TIA's technical sections, and the DPF enrollment runbook. Leave operator-only sections as explicit placeholders.

**Target:** `HoneyDrunk.Studios`, branch from `main`.

**Context:**
- Goal: Close ADR-0049 D10 Phase 5 + ADR-0036 D7's deferred DPA work.
- Feature: ADR-0049 Data Classification rollout, Wave 6 (Phase 5 commercial/legal).
- ADRs: ADR-0049 D7/D10 Phase 5 (primary), ADR-0036 D7 (deferred DPA closure), BDR-0001 (Florida LLC governing law).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — ADR-0049 Accepted; the DPA/TIA reference ADR-0049 by section.

**Constraints:**
- `Actor=Human` with `human-only` label. The packet's *substance* completion is operator-only; the agent scaffolds.
- Two-stage workflow — Stage 1 agent-PR for structure; Stage 2 operator-commits for legal substance and DPF payment.
- Documents are NOT customer-facing on the website at v1.
- All ADR cross-references accurate.

**Key Files:**
- `business/legal/dpa-template.md` (new).
- `business/legal/tia-v1.md` (new).
- `business/legal/dpf/README.md` (new).
- `business/legal/dpf/certificates/.gitkeep` (new placeholder).
- `business/legal/README.md` (new or updated index).

**Contracts:** No code contracts. Legal-document scaffolding only.
