---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "security", "docs", "adr-0056", "wave-1"]
dependencies: []
adrs: ["ADR-0056"]
accepts: ["ADR-0056"]
wave: 1
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Accept ADR-0056 — flip status, add three threat-model invariants, register the initiative

## Summary
Flip ADR-0056 (Threat Model and Security Review Cadence) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the three new threat-model invariants ADR-0056 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0056-threat-model` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0056 is the integration layer for the Grid's previously-fragmented security slice ADRs (0006 secrets, 0011 review, 0030/0031 audit, 0026 multi-tenant, 0049 data classification, 0036 DR, 0051 agent authority, 0041 LLM egress, 0044 PR discipline, 0046 specialist review agents, 0050 customer comms, 0054 incident response). It commits to STRIDE-per-trust-boundary methodology with an AI-specific overlay, a 10-entry trust-boundary inventory, an asset-classification axis layered on ADR-0049 + ADR-0036, a single living artifact at `constitution/threat-model.md`, four review cadences (per-PR / quarterly / per-Node-standup / per-major-dependency-upgrade), a three-layer pentest posture (external pre-GA, annual, DIY interim), Dependabot + SBOM, GitHub secret scanning + push protection + a found-secret rotation runbook, eight named AI-specific threats with concrete mitigations, incident-response coupling, responsible disclosure via `SECURITY.md`, and an explicit-rationaled compliance posture.

The ADR decides:

- **D1** — STRIDE per trust boundary as the primary methodology, with an AI-specific overlay (AI-1 through AI-8) covering prompt injection, indirect prompt injection, model jailbreak, tool poisoning, training-data poisoning, hallucinated-fact downstream impact, agent-tool exfiltration, model-API-key compromise. Supporting frames: NIST AI RMF, OWASP LLM Top 10, MITRE ATLAS.
- **D2** — 10 enumerated trust boundaries (public internet ↔ Web.Rest, Web.Rest ↔ application Nodes, application Nodes ↔ Vault/Data, tenant ↔ tenant, human ↔ agent, agent ↔ tool registry, agent ↔ external LLM, Studios-internal ↔ paying-tenant data, CI/CD ↔ production, open-source contributors ↔ Grid repos).
- **D3** — Asset classification table crossing ADR-0049 sensitivity (Public/Internal/Customer/Sensitive/Secret) and ADR-0036 RPO/RTO, naming Auth signing keys, per-Node Key Vault creds, payment tokens, model API keys, tenant data partitions, audit substrate, recipient address book, operator creds, source repos, CI/CD secrets, LLM prompt/completion telemetry, AI agent execution state.
- **D4** — Single living artifact at `constitution/threat-model.md` in markdown (not a tool-specific format), with ten enforced sections (header, methodology recap, boundary inventory, asset inventory, STRIDE pass per boundary, AI-specific threats, accepted risks, pentest history, open mitigations, references). Lands as a follow-up issue after this ADR is Accepted.
- **D5** — Four review cadences: per-PR (`security` review agent), quarterly (operator-led full review), per-new-Node (standup-ADR template requires "threat model entry"), per-major-dependency-upgrade (paragraph attached to the PR description).
- **D6** — Three pentest layers: external pre-Notify-Cloud-GA engagement ($5–15K), annual thereafter if revenue supports it, DIY interim using OWASP ZAP + Burp Community + prompt-injection corpus.
- **D7** — Dependency / supply-chain scanning: Dependabot Grid-wide, critical-CVE → auto-work-item, CodeQL on public repos free / private repos cost-gated, SBOM per release (CycloneDX or SPDX; tool selection deferred).
- **D8** — Secret scanning: GitHub-native secret scanning Grid-wide, push protection where supported, optional local `git-secrets`/`gitleaks` pre-commit hooks, found-secret runbook with 1-hour high-sensitivity / 4-hour lower-sensitivity time-to-rotation targets.
- **D9** — AI-specific protections: `PromptEnvelope` typed-channel pattern in `HoneyDrunk.AI` (AI-1); untrusted-content wrapping with explicit tags (AI-2); provider-side moderation + output-side gates (AI-3); immutable-tool-description-per-release in `HoneyDrunk.Capabilities` (AI-4); training-data-poisoning tracked at zero (AI-5); output-side guard for hallucinated-fact downstream impact (AI-6); PR-discipline or Operator-confirmation routing for high-blast-radius actions (AI-7); usage caps + per-environment keys + 90-day rotation for model API keys (AI-8).
- **D10** — Incident-response coupling: confirmed security incidents SEV-1 by default, tenant notification per ADR-0050 + ADR-0019, forensic-preservation hold beyond 730-day standard retention, post-mortem with threat-model amendment section.
- **D11** — Responsible disclosure: `SECURITY.md` at org level + per-public-repo copies, `security@honeydrunkstudios.com`, 90-day disclosure window, safe-harbor language modeled on Disclose.io core terms, no bug bounty at v1.
- **D12** — Compliance posture: not pursuing SOC 2 Type 2 or ISO 27001 at v1; substrate-now-audit-later sequencing; trigger conditions recorded (enterprise LOI conditional on SOC 2, regulated-vertical customer, ~10 paying enterprise tenants without SOC 2).
- **D13** — Relationship to existing security-touching ADRs: this ADR preserves every slice-ADR (0006, 0011, 0030, 0046, 0026, 0049, 0036, 0051, 0041, 0044, 0050, 0019, 0054) and adds the integration substrate.
- **D14** — Six-phase rollout: artifact v0 → artifact v1 → tooling rollout (Dependabot, secret scanning, `SECURITY.md`) → AI-protection implementation → pentest scoping → quarterly cadence steady state.

ADR-0056 is a **policy / decision** ADR. The concrete artifact — `constitution/threat-model.md` v0 shell and v1 content — lands in packets 01 and 02. The governance plumbing (standup-template + hive-sync extension, `SECURITY.md` authoring, the operator runbooks for incidents, found-secret rotation, pentest scoping, DIY adversarial probing) lands in packets 03-07. The Dependabot + secret-scanning Grid-wide enablement lands in packet 08 in `HoneyDrunk.Actions`. The cross-track follow-up tracker (for AI's `PromptEnvelope`, Capabilities' immutable-tool-description and high-blast-radius routing, Vault's tighter model-key rotation, Audit's investigation-extended-retention export, ADR-0046's `security.md` artifact-loading wiring, SBOM tool selection) lands as packet 09.

Every other packet in this initiative references ADR-0056's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0056-threat-model-and-security-review-cadence.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0056 row Status column to Accepted.
- `constitution/invariants.md` — add the three new threat-model invariants (see Proposed Implementation for exact text) under a new `## Security and Threat Model Invariants` section. The numbers are claimed at edit time from `constitution/invariant-reservations.md` — referred to in this packet as `{N1}/{N2}/{N3}`. See Constraints for the reservation procedure.
- `constitution/invariant-reservations.md` — add a new row to the **Active Reservations** table claiming the `{N1}–{N3}` block for ADR-0056 in the same commit.
- `initiatives/active-initiatives.md` — register the `adr-0056-threat-model` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0056 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0056 index row in `adrs/README.md` to Accepted.
3. **Claim the invariant block.** Read `constitution/invariant-reservations.md`. Find the highest currently-reserved number across the **Active Reservations** table (do not assume the values cached in this packet body — re-verify at edit time). Pick the next contiguous block of size 3 above it; call the three numbers `{N1}`, `{N2}`, `{N3}` for the remainder of this packet. Add a row to the **Active Reservations** table in the same PR claiming `{N1}–{N3}` for ADR-0056, with this packet's path. (At packet authoring time, the highest reservation was ADR-0049 at 58–60, so the expected block is **61–63**; re-verify before editing.)
4. Add three new invariants to `constitution/invariants.md`, numbered `{N1}`, `{N2}`, `{N3}`. The text, taken verbatim-in-substance from ADR-0056's Consequences "Invariants" section:
   - **`{N1}` — Every Node standup ADR includes a "threat model entry" section, and the artifact is updated in the same PR that moves the standup ADR to Accepted.** The standup ADR's "threat model entry" section declares the new Node's trust boundaries (if any), new assets (if any), STRIDE pass against the boundaries the Node touches, and the AI overlay if the Node is in the AI sector. The standup ADR cannot move from Proposed to Accepted until the artifact-update commit lands in the same PR. Enforced by `hive-sync` constitution scan, which fails if a standup ADR references a Node not present in `constitution/threat-model.md`. See ADR-0056 D5.
   - **`{N2}` — LLM calls use the `PromptEnvelope` typed-channel pattern; direct string concatenation of untrusted input into a prompt is a CI gate failure.** Every LLM call in the Grid uses structural separation of system instructions, user input, and tool output. The Grid's LLM-calling library (per ADR-0016 — `HoneyDrunk.AI`'s abstraction) enforces a `PromptEnvelope` shape where system / user / tool / assistant messages are typed channels, not concatenated strings. Direct string concatenation of untrusted input into a prompt is a CI gate failure (analyzer rule per ADR-0046's analyzer surface). Structural separation is not a complete defense against prompt injection — the residual risk is tracked in the artifact's accepted-risk log and addressed by the output-side guard in invariant `{N3}`. See ADR-0056 D9 AI-1.
   - **`{N3}` — High-blast-radius agent actions route through PR-discipline or Operator confirmation; never direct execution.** Any agent action with high blast radius (file write outside a sandbox, external API call to a non-allowlisted endpoint, tenant data mutation, money movement, sending a message externally) routes through one of two paths: (a) the ADR-0044 PR-discipline path — the agent opens a PR rather than executing directly, and a human-or-review-agent approves the merge; or (b) explicit Operator confirmation via ADR-0051's confirmation primitives — the operator sees a structured "the agent intends to do X" prompt and approves or denies in real time. Never direct execution for high-blast-radius actions. The list of "high blast radius" actions lives in `constitution/threat-model.md` and grows over time as new capabilities land; the default for a new capability is high blast radius until proven otherwise. Enforced by capability-side wiring in `HoneyDrunk.Capabilities` (per ADR-0017 once stood up) and by the `security` review agent's per-PR check (per ADR-0046 once accepted). See ADR-0056 D9 AI-7.
   - Create a new `## Security and Threat Model Invariants` section at the bottom of the `## AI Invariants` block (security is a cross-cutting concern adjacent to AI in the existing sectioning), or create a new top-level section if the file's convention places `Security` ahead of `AI` — match the file's current sectioning convention.
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder.

## Affected Files
- `adrs/ADR-0056-threat-model-and-security-review-cadence.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0056 header reads `**Status:** Accepted`
- [ ] The ADR-0056 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariants.md` carries the three new threat-model invariants (standup ADRs include a "threat model entry" section; LLM calls use the `PromptEnvelope` typed-channel pattern; high-blast-radius agent actions route through PR-discipline or Operator confirmation, never direct execution), numbered `{N1}/{N2}/{N3}` under a new `## Security and Threat Model Invariants` section, each citing ADR-0056
- [ ] `{N1}/{N2}/{N3}` were claimed via `constitution/invariant-reservations.md` — a new row was added to the **Active Reservations** table in the same PR, citing ADR-0056 and this packet's path
- [ ] The claimed block is the next free contiguous block of size 3 above the highest reservation that existed in `invariant-reservations.md` at edit time (re-verified at edit time; not assumed from cached numbers in this packet body)
- [ ] No existing invariant is renumbered; new invariants are appended only
- [ ] `initiatives/active-initiatives.md` registers the `adr-0056-threat-model` initiative with a packet checklist
- [ ] No catalog schema change in this packet (the artifact at `constitution/threat-model.md` lands in packets 01/02)
- [ ] No artifact file is created in this packet — `constitution/threat-model.md` is packet 01's job

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0056 D5 — Review cadence (per-Node standup row).** Node standup ADRs (every standup ADR template from ADR-0014 onward) must include a "threat model entry" section that adds the Node to the artifact: new trust boundaries (if any), new assets (if any), STRIDE pass against the boundaries the Node touches, AI overlay if the Node is in the AI sector. The standup ADR cannot move from Proposed to Accepted until the artifact-update commit lands. Enforcement: the `hive-sync` constitution-scan job fails if a standup ADR references a Node not present in the artifact.

**ADR-0056 D9 AI-1 — Prompt injection (direct) — structural separation.** Every LLM call in the Grid uses structural separation of system instructions, user input, and tool output via a `PromptEnvelope` shape where system / user / tool / assistant messages are typed channels, not concatenated strings. Direct string concatenation of untrusted input into a prompt is a CI gate failure (analyzer rule per ADR-0046's analyzer surface).

**ADR-0056 D9 AI-7 — Data exfiltration via agent tool misuse — output-side guard.** Any agent action with high blast radius (file write outside a sandbox, external API call to a non-allowlisted endpoint, tenant data mutation, money movement, sending a message externally) routes through PR-discipline (ADR-0044) or explicit Operator confirmation (ADR-0051), never direct execution.

**ADR-0056 Consequences — Invariants.** ADR-0056 adds exactly three invariants: (1) standup ADRs include a "threat model entry"; (2) LLM calls use `PromptEnvelope`; (3) high-blast-radius agent actions route through PR-discipline or Operator confirmation.

## Constraints
- **Acceptance precedes flip.** ADR-0056 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbers are claimed at edit time from `constitution/invariant-reservations.md`.** The current verified maximum accepted invariant in `constitution/invariants.md` is **53**. Reservations for in-flight Proposed ADRs live in `constitution/invariant-reservations.md` — that file is the single source of truth for collision avoidance. The executor reads it, picks the next free contiguous block of size 3 above the highest existing reservation, claims the block by adding a row to its **Active Reservations** table in the same PR, and uses the claimed numbers throughout this packet body (referred to as `{N1}/{N2}/{N3}`). Never reuse a number that already appears in `invariants.md` or as a reservation.
- **Do not renumber existing invariants.** Append only.
- **New section name.** The three threat-model invariants are a new cross-cutting topic; create a `## Security and Threat Model Invariants` section. Match the file's existing sectioning convention; place adjacent to `## AI Invariants` if the file groups security-adjacent concerns there, or as a new top-level section if a `Security` heading already exists.
- **Inline the full invariant text — do NOT reference by number only.** Each of `{N1}/{N2}/{N3}` is written out in full in the invariants file (as in Proposed Implementation), so downstream agents reading the constitution at PR time can act on the rule without traversing back to this packet.
- **No artifact creation in this packet.** `constitution/threat-model.md` is packet 01's deliverable. This packet ships only the ADR flip + the three invariants + the initiative registration.

## Labels
`chore`, `tier-3`, `meta`, `security`, `docs`, `adr-0056`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0056 to Accepted, claim a block of three invariant numbers from `constitution/invariant-reservations.md` (referred to as `{N1}/{N2}/{N3}`), add the three threat-model invariants to `constitution/invariants.md` at those numbers, and register the threat-model initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0056 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 1.
- ADRs: ADR-0056 (primary), ADR-0008 (initiative/packet conventions), ADR-0046 (specialist review agents — Proposed, soft-coupled), ADR-0044 (PR discipline — Accepted, referenced by invariant `{N3}`).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0056 stays Proposed until this PR merges.
- Claim a contiguous block of three invariant numbers from `constitution/invariant-reservations.md` (the single source of truth for in-flight reservations). The verified current max accepted in `constitution/invariants.md` is **53**; reservations beyond 53 live in `invariant-reservations.md`. At edit time: read the **Active Reservations** table, pick the next free block of size 3 above the highest existing reservation, refer to those numbers as `{N1}/{N2}/{N3}` in this packet, and add a claiming row to that table in the same commit. Do not renumber existing invariants.
- Inline the full text of each new invariant in `constitution/invariants.md`. Do not abbreviate to "see ADR-0056."
- Create a new `## Security and Threat Model Invariants` section adjacent to `## AI Invariants` (or as a new top-level section if the file already has a `Security`-prefixed section).
- No artifact file in this packet — `constitution/threat-model.md` is packet 01.

**Key Files:**
- `adrs/ADR-0056-threat-model-and-security-review-cadence.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
