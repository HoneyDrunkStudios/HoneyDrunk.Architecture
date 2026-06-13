# Dispatch Plan — ADR-0056: Threat Model and Security Review Cadence

**Initiative:** `adr-0056-threat-model`
**ADR:** ADR-0056 (Proposed → Accepted via packet 00)
**Sector:** Meta / Security / cross-cutting
**Created:** 2026-05-24

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0056 is the **integration layer for the Grid's security slices**: STRIDE-per-trust-boundary methodology with an AI-specific overlay (D1), a 10-entry trust-boundary inventory (D2), an asset classification crossing ADR-0049 sensitivity and ADR-0036 RPO/RTO (D3), a single living artifact at `constitution/threat-model.md` (D4), four review cadences (D5), a three-layer pentest posture (D6), Dependabot + SBOM (D7), GitHub secret scanning + a found-secret rotation runbook (D8), eight named AI threats with concrete mitigations (D9), incident-response coupling (D10), responsible disclosure via `SECURITY.md` (D11), explicit-and-rationaled compliance posture (D12), preservation of every existing slice-ADR (D13), and a six-phase rollout (D14).

The ADR adds three invariants: (a) every Node standup ADR includes a "threat model entry" section; (b) LLM calls use a typed-channel `PromptEnvelope` pattern; (c) high-blast-radius agent actions route through PR-discipline or Operator confirmation, never direct execution.

This initiative ships **the substrate, the governance plumbing, the security-tooling enablement, and the operator runbooks that integrate the existing slice-ADRs**. It deliberately **does not** retrofit AI-specific code into not-yet-stood-up Nodes (Capabilities, Operator, parts of AI), Audit's investigation-extended-retention export interface, or Vault's tighter model-key rotation cadence — those land in the owning Nodes' own work tracks per the Grid's "standup gets its own ADR / don't bundle into feature packets" rule. Packet 09 registers the cross-track follow-up triggers so the deferrals are tracked, not forgotten.

**10 packets across 5 waves**, targeting **2 repos** (`HoneyDrunk.Architecture` x9, `HoneyDrunk.Actions` x1). 10 `Actor=Agent`, 0 `Actor=Human`. Five packets carry Human Prerequisites — the most consequential are in packets 04 (org-level `SECURITY.md` creation in `HoneyDrunkStudios/.github`, `security@honeydrunkstudios.com` mailbox provisioning), 07 (pentest-firm shortlist + DIY tooling install), and 08 (Dependabot enablement scope decision, GitHub Advanced Security cost-tier decision, initial historical-secret-scan triage).

## Trigger

ADR-0056 is Proposed with no scope. Forcing functions from the ADR's Context: (a) **ADR-0046's specialist `security` review agent needs a substrate** — without the artifact, the agent pattern-matches; with it, the agent runs threat-modeled review. (b) **Notify.Cloud GA (PDR-0002) is the meaningful attack-surface expansion** — first commercial product, first tenant-bearing traffic, first regulatory exposure. (c) **The AI sector introduces nine Nodes with novel threat categories** that conventional STRIDE doesn't cover by construction. (d) **Cross-ADR mitigation drift is invisible without a substrate** — ADR-0006 rotation and ADR-0030 audit-retention windows could disagree silently today. (e) **Compliance posture conversations are imminent** — enterprise prospects will ask "do you have a threat model" and "what's your security review cadence" in due diligence; an honest written answer beats improvising under sales pressure.

## Scope Detection

**Multi-repo, governance-heavy.** Nine packets land in `HoneyDrunk.Architecture` (acceptance/invariants, the artifact at `constitution/threat-model.md`, standup-template + hive-sync extension, `SECURITY.md` content, security-incident runbook extensions in `business/context/`, found-secret rotation runbook, pentest-and-DIY-probe playbook, the cross-track follow-up tracker). One packet lands in `HoneyDrunk.Actions` (Dependabot enablement + critical-CVE auto-work-item wiring + secret-scanning verification — the CI/CD-control-plane surface per ADR-0012 invariants).

**Deliberate deferrals to owning-Node tracks (registered in packet 09, not scoped as packets here):**

- **AI-1 `PromptEnvelope` typed-channel pattern + analyzer rule** in `HoneyDrunk.AI`. ADR-0016 is Accepted but the Node is Seed; the `PromptEnvelope` shape is `HoneyDrunk.AI`'s own work, sequenced when an LLM-calling consumer needs it. Pre-writing a packet against a Seed-phase abstraction-only Node is premature decomposition.
- **AI-4 immutable-tool-description-per-release** in `HoneyDrunk.Capabilities`. ADR-0017 standup is Proposed — Capabilities Node does not yet exist as shipped code. The immutability commitment lands at standup as a designed-in invariant, not retrofit. Belongs to ADR-0017's track.
- **AI-7 high-blast-radius routing** in `HoneyDrunk.Capabilities`. Same — capability-side wiring requires the capability registry to exist. Standup-time concern.
- **AI-8 tighter model-key rotation cadence** (90-day max vs general 180-day default) in `HoneyDrunk.Vault`. Belongs in Vault's rotation-policy track / a Vault.Rotation follow-up, not in this initiative — the rotation policy is ADR-0006's mechanism, this ADR just names a tighter cadence for the specific secret class.
- **D10 investigation-extended-retention export interface** in `HoneyDrunk.Audit`. ADR-0031 Audit standup is Accepted and v0.1.0 is published; the export interface is a Phase-2 Audit enhancement, not in this initiative's scope. Belongs to a future Audit packet driven by an actual investigation event or by Audit's own Phase-2 plan.
- **`.claude/agents/security.md` updates** to load the artifact on every PR. ADR-0046 (specialist review agents) is Proposed — `security.md` does not yet exist in `.claude/agents/`. The artifact-as-input wiring lands when ADR-0046 is Accepted and the agent file is authored, as part of that initiative. Packet 09 registers the cross-track hook so ADR-0046's scope-out work knows to consume `constitution/threat-model.md` as input context.
- **SBOM tooling selection and `HoneyDrunk.Actions` reusable-workflow integration.** D7 explicitly defers the tool decision ("becomes a follow-up ADR or a hive-sync-driven amendment to ADR-0035"). This initiative does not pick the tool. Packet 09 registers the follow-up.

**No new-Node scaffolding.** Every target repo is live: `HoneyDrunk.Architecture` (governance) and `HoneyDrunk.Actions` (CI/CD control plane). No empty cataloged repo is touched.

## Wave Diagram

### Wave 1 (No Dependencies — governance + invariants)
- [ ] **00** — Architecture: Accept ADR-0056, add the three threat-model invariants (numbers `{N1}/{N2}/{N3}` — claimed at edit time from `constitution/invariant-reservations.md`), register the initiative. `Actor=Agent`.

### Wave 2 (Depends on Wave 1 — the artifact shell)
- [ ] **01** — Architecture: Author `constitution/threat-model.md` v0 — header, methodology recap, full D2 boundary inventory, full D3 asset table, stub STRIDE-pass subsections per TB (six bullets each with "TBD" entries and target dates), stub AI-overlay subsections, empty accepted-risk + pentest-history + open-mitigations sections, references. `Actor=Agent`. Blocked by: 00.

### Wave 3 (Depends on Wave 2 — fill the artifact + governance plumbing, parallel)
- [ ] **02** — Architecture: Fill `constitution/threat-model.md` v1 — every TB-N gets a real STRIDE pass with mitigation entries cross-referencing the slice-ADRs; every AI-N gets a mitigation entry; asset-table threat-ID cross-references filled. `Actor=Agent`. Blocked by: 01.
- [ ] **03** — Architecture: Amend the standup-ADR template to require a "threat model entry" section + extend `hive-sync` to fail on standup-ADR-vs-artifact Node-list drift. `Actor=Agent`. Blocked by: 01.
- [ ] **04** — Architecture: Author org-level `SECURITY.md` content + per-public-repo `SECURITY.md` copy template + 90-day disclosure commitment + safe-harbor language + out-of-scope list. `Actor=Agent`. Blocked by: 00.

### Wave 4 (Depends on Wave 1 — operator runbooks + tooling enablement, parallel)
- [ ] **05** — Architecture: Author the security-incident-response extensions in `business/context/` — SEV-1 default, tenant-notification path (GDPR 72h alignment), forensic-preservation hold, security post-mortem amendment section. `Actor=Agent`. Blocked by: 00.
- [ ] **06** — Architecture: Author the found-secret rotation runbook in `business/context/` — 1-hour high-sensitivity / 4-hour lower-sensitivity time-to-rotation targets, pre-staged rotation commands per secret class, history-rewrite-is-cosmetic posture. `Actor=Agent`. Blocked by: 00.
- [ ] **07** — Architecture: Document the pentest-engagement scoping prep (firm-selection criteria, scope-for-pre-GA engagement) + DIY adversarial-probe playbook (OWASP ZAP, Burp Community, prompt-injection corpus). `Actor=Agent`. Blocked by: 02.
- [ ] **08** — Actions: Enable Dependabot Grid-wide (security alerts + auto-PR for patches, human merge for minor/major) + wire the critical-CVE → auto-work-item flow + verify GitHub secret scanning + push protection enabled Grid-wide. `Actor=Agent`. Blocked by: 00.

### Wave 5 (Depends on Wave 3 — cross-track follow-up tracker)
- [ ] **09** — Architecture: Register the cross-track follow-up triggers — AI's `PromptEnvelope` work, Capabilities' immutable-tool-description and high-blast-radius routing, Vault's tighter model-key rotation cadence, Audit's investigation-extended-retention export, ADR-0046's `security.md` artifact-loading wiring, SBOM tool selection — as a tracked list in `initiatives/active-initiatives.md` so the deferrals surface at the right Node-standup or sibling-ADR moment. `Actor=Agent`. Blocked by: 02, 03.

Packets within a wave run in parallel. Wave 4 packets 05/06/07/08 depend only on packet 00 (or packet 02 for 07's pentest-scoping which wants the boundary inventory finalized) and run fully parallel with Wave 3. They are grouped into Wave 4 for tidy filing; the `dependencies:` frontmatter is the real ordering signal.

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0056](./00-architecture-adr-0056-acceptance.md) | Architecture | Agent | 1 | — |
| 01 | [Threat-model artifact v0 shell](./01-architecture-threat-model-artifact-v0.md) | Architecture | Agent | 2 | 00 |
| 02 | [Threat-model artifact v1 content](./02-architecture-threat-model-artifact-v1.md) | Architecture | Agent | 3 | 01 |
| 03 | [Standup-ADR template + hive-sync extension](./03-architecture-standup-template-and-hive-sync.md) | Architecture | Agent | 3 | 01 |
| 04 | [SECURITY.md authoring](./04-architecture-security-md-authoring.md) | Architecture | Agent | 3 | 00 |
| 05 | [Security incident runbook extensions](./05-architecture-security-incident-runbook.md) | Architecture | Agent | 4 | 00 |
| 06 | [Found-secret rotation runbook](./06-architecture-found-secret-rotation-runbook.md) | Architecture | Agent | 4 | 00 |
| 07 | [Pentest scoping + DIY adversarial probe playbook](./07-architecture-pentest-and-diy-probe-playbook.md) | Architecture | Agent | 4 | 02 |
| 08 | [Dependabot + secret-scanning Grid-wide enablement](./08-actions-dependabot-and-secret-scanning.md) | Actions | Agent | 4 | 00 |
| 09 | [Cross-track follow-up tracker](./09-architecture-cross-track-followup-tracker.md) | Architecture | Agent | 5 | 02, 03 |

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution. Governance, doc, catalog edits only.
- **`HoneyDrunk.Actions`** — not a versioned .NET solution. Workflow/YAML changes + GitHub repo settings. Repo `CHANGELOG.md` updated per the repo convention if it keeps one for the workflow surface.

No NuGet version bumps in this initiative. No `## NuGet Dependencies` section is load-bearing on any packet.

## Cross-Cutting Concerns

### Coupling with ADR-0046 (`security` review agent) — soft, registered

ADR-0046 is **Proposed**, not Accepted, and `.claude/agents/security.md` does not yet exist in this repo. ADR-0056 D5 says the per-PR cadence loads the threat-model artifact "as input context" — that wiring belongs to ADR-0046's scope-out work, not this initiative. Packet 09's tracker registers the hook so ADR-0046's authors know to (a) load `constitution/threat-model.md` on every PR and (b) flag novel-boundary-not-in-model and mitigation-drift-from-model — the substance D5 commits the agent to.

**Why not block this initiative on ADR-0046 acceptance:** the artifact is operationally useful for the **operator** (quarterly review, per-Node standup, per-dependency-upgrade) and for the **review agents that already exist** (the canonical `review.md` rubric already has security categories; it can cross-reference the artifact even before a specialist `security.md` ships). Decoupling lets the artifact land and exercise the operator-side cadences while ADR-0046 sequences independently.

### Coupling with not-yet-stood-up AI-sector Nodes

D9's AI-1 / AI-4 / AI-7 protections require code in `HoneyDrunk.AI` (Seed) and `HoneyDrunk.Capabilities` (Proposed standup ADR-0017, no shipped Node). Per the Grid's New-Node-scaffold convention, retrofitting `PromptEnvelope` into AI before AI has a real consumer, or pre-writing capability-side wiring before Capabilities is stood up, is premature decomposition. The AI overlay sections in the artifact (packet 02) cite the threats and the **named mitigations**, marking them as "implementing ADR(s): ADR-0017 D… / ADR-0056 D9 — pending capability standup." When ADR-0017's standup track lands, that track inherits the threat-model entry's commitments. Packet 09 registers the trigger.

### Coupling with ADR-0006 secret rotation and ADR-0031 Audit

- **ADR-0006 (Accepted) — model-key tighter rotation cadence (AI-8).** Vault's rotation defaults are 180-day general / 90-day for the model-key class per D9 AI-8. This is a one-line Vault-rotation-policy amendment, not a major Vault work item. **Deferred** to a Vault-rotation follow-up packet (or a Vault.Rotation initiative the operator already owns). Packet 09 registers it.
- **ADR-0031 (Accepted, v0.1.0 shipped) — investigation-extended-retention export.** D10 asks Audit for an export-with-no-expiry path for an active investigation. Audit v0.1.0 ships `IAuditLog`/`IAuditQuery`/`AuditEntry` and a Data-backed impl; the export-and-hold interface is an additive read-side feature. **Deferred** to an Audit follow-up packet. Packet 09 registers it. The artifact (packet 02) records the dependency in the D10 mitigation entry as "Audit: investigation-extended-retention export — pending Audit Phase-2."

### Coupling with ADR-0040 (telemetry) and ADR-0050 (customer comms) — read-only

D3's asset table cross-references ADR-0036 RPO/RTO and ADR-0049 sensitivity classes. ADR-0036 and ADR-0049 are Proposed. The artifact (packet 02) records the cross-references as live citations; if those ADRs are amended before this initiative completes, the artifact's quarterly review will catch the drift. ADR-0050 (Tenant lifecycle) is referenced from D10 for the tenant-notification path; same Proposed status, same posture.

**No hard blocker.** This initiative's packets do not depend on ADR-0036/0049/0050 acceptance — they cross-reference whatever those ADRs ultimately decide and the artifact is the integration substrate by design.

### `business/context/` — operator-context location convention

Three packets (05, 06, 07) write to `business/context/`. Per the memory note on user feedback and the precedent set by ADR-0040 packet 08 / ADR-0045 packet 06, this is where operational runbooks and operator-facing context notes live. Each packet's `Proposed Implementation` specifies the file path; the precedent of "extend an existing related note if one exists, otherwise create a new file" is preserved.

### Site sync

No site-sync flag. ADR-0056 is internal Meta/Security governance — no public-facing Studios website content changes. The org-level `SECURITY.md` lives in `HoneyDrunkStudios/.github`, not in Studios.

### Compliance posture — D12 is decision-of-record, not work

ADR-0056 D12 commits to **not** pursuing SOC 2 / ISO 27001 at v1 and records the conditions under which the question is reopened. No packet in this initiative pursues certification. If a D12 trigger fires (enterprise LOI conditional on SOC 2, regulated-vertical customer, ~10 paying enterprise tenants without SOC 2), the conversation reopens via a new ADR amendment. The artifact's references section (packet 02) records the D12 rationale for prospect-due-diligence conversations.

### Invariant numbering

The verified current maximum accepted invariant in `constitution/invariants.md` is **53**. ADR-0056 adds **three** invariants. The numbers are **claimed at edit time** from `constitution/invariant-reservations.md`, not hardcoded in this dispatch plan — that file is the single source of truth for in-flight reservations and prevents collisions across concurrently-Proposed ADRs. Packet 00's executor reads `constitution/invariant-reservations.md`, picks the next free contiguous block of size 3 above the highest existing reservation, adds a row to that file's **Active Reservations** table in the same PR that writes the new invariants, and references the claimed numbers as `{N1}/{N2}/{N3}` throughout the packet body. As of authoring time, ADR-0051 holds 54–57 and ADR-0049 holds 58–60 in `invariant-reservations.md`, so the next free block is **61–63** — but the executor re-reads the file at edit time in case other ADRs have landed reservations since.

## Rollback Plan

- **Packet 00 (governance + invariants):** revert the PR. ADR-0056 returns to Proposed; the three threat-model invariants are removed; the initiative entry is removed. No runtime impact.
- **Packet 01 (artifact v0 shell):** revert the PR. `constitution/threat-model.md` is deleted. No downstream consumer yet — review agents fall back to their pre-artifact behavior (which is the current state).
- **Packet 02 (artifact v1 content):** revert the PR. The artifact rolls back to v0 stubs. The operator's quarterly-review cadence still has a substrate, just an emptier one.
- **Packet 03 (standup-template + hive-sync):** revert the PR. Standup-ADR template loses the "threat model entry" requirement; `hive-sync` loses the drift-detection scan. Existing accepted standup ADRs are unaffected.
- **Packet 04 (`SECURITY.md`):** revert the PR. The org-level `SECURITY.md` file is removed; per-repo copies are removed. Researchers fall back to no published disclosure path — recorded as a security regression in the artifact's accepted-risk log if the revert sticks.
- **Packet 05 (incident runbook extensions):** revert the PR. The security-specific incident-response extensions leave `business/context/`. The broader incident matrix (ADR-0054 — Proposed) is unaffected.
- **Packet 06 (found-secret runbook):** revert the PR. The pre-staged rotation commands and time-to-rotation targets leave `business/context/`. The operator falls back to ADR-0006's general rotation mechanics.
- **Packet 07 (pentest + DIY playbook):** revert the PR. The pentest-scoping note and DIY-probe playbook leave `business/context/`. The pre-GA pentest engagement is then ungated until re-applied.
- **Packet 08 (Dependabot + secret scanning Grid-wide):** Dependabot configuration files (`.github/dependabot.yml` per repo) can be reverted per repo; the GitHub-side Dependabot/secret-scanning *enablement* is an org-setting that the operator must toggle off in the GitHub Settings UI if revert is needed. The auto-work-item workflow can be disabled via its `on:` block. **Reverting is a multi-surface operation** — the runbook in packet 08 documents the exact toggle list.
- **Packet 09 (cross-track follow-up tracker):** revert the PR. The deferred-trigger list leaves `initiatives/active-initiatives.md`. The deferrals are then carried only in the dispatch-plan / packet bodies — readable but less prominent.
- **Operational escape hatch for the artifact:** if the artifact develops a defect that affects the review agent or operator confidence, the operator's quarterly-review process is the corrective surface — fix in place, version-bump the artifact's header date, commit. No full revert needed for normal artifact maintenance.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

The `dependencies:` array uses `work-item:NN` qualified references within this folder. No cross-initiative dependencies are wired (ADR-0046 is referenced only as a soft narrative coupling).
