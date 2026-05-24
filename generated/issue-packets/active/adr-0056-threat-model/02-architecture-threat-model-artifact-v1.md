---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "security", "docs", "adr-0056", "wave-3"]
dependencies: ["packet:01"]
adrs: ["ADR-0056"]
accepts: ["ADR-0056"]
wave: 3
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Fill constitution/threat-model.md v1 — real STRIDE pass per boundary, AI overlay mitigations, asset threat-IDs

## Summary
Replace every TBD in `constitution/threat-model.md` (created by packet 01 as v0 shell) with a real mitigation entry citing the implementing slice-ADR(s): 60 STRIDE bullets across TB-1 through TB-10 (six per boundary), 8 AI-overlay entries across AI-1 through AI-8, and 12 asset rows' `Threat IDs` cross-references. Bump the header to v1. The result is the first operationally useful version of the artifact — the version the operator's quarterly-review cadence and the canonical review agents read.

## Context
Packet 01 shipped the v0 shell: section structure, boundary inventory, asset table, references, with every threat-and-mitigation entry marked TBD. This packet executes ADR-0056 D14 Phase 2: **fill the STRIDE-pass subsections with real mitigation entries pointing to the existing slice-ADRs; fill the AI-overlay subsections with the protections from D9; fill the asset table's threat-ID cross-references**.

After this packet lands, the artifact is **operationally useful** for the operator's quarterly review (D5) and for the canonical `review.md` rubric. The specialist `security` agent (ADR-0046, Proposed) will consume the artifact once ADR-0046's track lands; this packet does not depend on that — the artifact is useful whether or not ADR-0046 has been accepted.

The fill is **deliberately concise**. Each mitigation entry is one to three lines naming the threat, the mitigation, the implementing ADR(s) or Node(s), and the residual risk. The artifact's job is the **mapping** (threat → mitigation → implementing ADR), not the **explanation** of how the underlying mechanism works — that's the implementing ADR's job. A bullet that re-explains how managed identity works is over-engineered; a bullet that says "managed identity per ADR-0006 D2; residual risk: Azure managed-identity service outage" is right-sized.

**Deferred entries are explicit.** Per the dispatch plan, AI-1's `PromptEnvelope` work is deferred to `HoneyDrunk.AI`'s own track, AI-4 and AI-7's capability-side wiring to `HoneyDrunk.Capabilities` standup (ADR-0017), AI-8's tighter rotation to a Vault.Rotation follow-up, D10's investigation-extended-retention export to an Audit Phase-2 follow-up, `.claude/agents/security.md`'s artifact-loading wiring to ADR-0046's track. In the artifact, each deferred mitigation is named explicitly: "Mitigation: {concrete pattern}. Implementing: pending {ADR-NNNN / Node track}. Residual risk: {what the deferral means until the implementing track lands}." The deferrals are visible, not hidden.

**This is a docs-only packet. No code, no .NET project.**

## Scope
- `constitution/threat-model.md` — fill all TBD entries from v0 with real mitigation content; bump header to v1; update last-reviewed date.

## Proposed Implementation

For every TBD entry in `constitution/threat-model.md`, replace with a real mitigation entry using the established format: **threat → mitigation → implementing ADR(s)/Node(s) → residual risk**.

### Section 5 — STRIDE pass per boundary (60 entries)

For each TB-N, write six bullets. Below are the canonical mappings the entries draw from. The agent executing this packet has discretion on phrasing; the substance is fixed by the cited ADRs.

**TB-1 (Public internet ↔ Web.Rest / Front Door)** — entry-point security:
- S/Spoofing: Front Door + Web.Rest enforce JWT Bearer validation per ADR-0010 (Auth is validator-not-issuer). Residual: token-theft via TB-5 (covered there).
- T/Tampering: TLS-only; HSTS preload; signed request envelopes for tenant-bearing traffic where applicable.
- R/Repudiation: every request emits an audit entry via `IAuditLog` per ADR-0030 (invariant 47); CorrelationId attached per invariant 6.
- I/Information disclosure: response envelope per ADR-0011 patterns; error mapping does not leak internals; secret-scrubbing in observability per invariant 8.
- D/Denial of service: rate limits at Front Door + per-tenant rate-limit policy per ADR-0026 invariant 39 (post-dispatch tails); Notify Cloud GA carries explicit DoS rate-limit thresholds.
- E/Elevation of privilege: claims-policy mapping in Web.Rest; tenant policy enforced at intake middleware per invariant 39.

**TB-2 (Web.Rest ↔ application Nodes)** — internal-network boundary:
- S: Managed Identity + token validation between Nodes; no shared-secret schemes.
- T: Transport-layer integrity via Service Bus message-id + (post-ADR-0042) `IdempotencyKey`; tamper requires Service Bus credential compromise (covered by TB-3).
- R: per-message audit entries via `IAuditLog` (ADR-0030); CorrelationId propagates per invariants 5/6.
- I: tenant scoping enforced at consumer per ADR-0026; no cross-tenant message delivery.
- D: Service Bus dead-letter handling per ADR-0028; per-tenant rate limits at TB-1 already bound upstream load.
- E: per-Node Managed Identity scopes RBAC narrowly; no broad service principals.

**TB-3 (Application Nodes ↔ Vault / Data)** — secret + data persistence boundary:
- S: Managed Identity for Vault and Data access; per-Node Key Vault (invariant 17); no application-resident credentials.
- T: Vault audit logs (invariant 22 — diagnostic settings to Log Analytics); Data EF Core constraints + outbox transactional integrity.
- R: `IAuditLog` records every privileged Vault access path; Data emits audit on record CRUD (ADR-0030).
- I: secret values never leave Vault as plaintext into logs (invariant 8); tenant-scoped secrets per invariant 9a.
- D: Vault throttling per Azure default; Data connection-pool exhaustion mitigated by per-Node connection limits.
- E: RBAC enforced at Vault (invariant 17 — no access policies); EF Core role-scoped query model.

**TB-4 (Tenant A ↔ Tenant B)** — multi-tenant isolation (most consequential boundary):
- S: `TenantId` carried as ULID per ADR-0026; cross-tenant token forgery requires Auth signing-key compromise (TB-3).
- T: Tenant-scoped partition keys enforced at the gateway per invariant 39; cross-tenant write rejected at intake.
- R: per-tenant audit trail via `IAuditLog` with `TenantId` dimension (ADR-0030).
- I: cross-tenant read fail-closed by default per ADR-0026; tenant-scoped secrets per invariant 9a; AI overlay applies (agent execution may span tenants — see AI-2/AI-7).
- D: per-tenant rate limits per ADR-0026 (invariant 39); single-tenant burst cannot starve other tenants.
- E: tenant policy escalation requires an explicit Operator action per ADR-0051 (Proposed); no in-band escalation path.

**TB-5 (Human user ↔ agent)** — delegation boundary (AI overlay applies):
- S: delegated authority scoped to specific capabilities per ADR-0051 (Proposed); session tokens tied to authenticated user.
- T: agent cannot rewrite its own scope mid-session; scope changes require re-authorization.
- R: per-action audit via `IAuditLog` with PrincipalId per ADR-0030.
- I: agent context inherits user's tenant scope; cross-tenant escalation blocked at the capability layer (per TB-6).
- D: per-user rate limits on agent dispatch; long-running agent tasks budget-capped per ADR-0052 (Proposed).
- E: any high-blast-radius action routes through PR-discipline or Operator confirmation per invariant `{N3}` (claimed in packet 00).

**TB-6 (Agent ↔ tool registry / Capabilities)** — AI overlay applies; ADR-0017 standup pending:
- S: tool descriptors signed at registry-version-publish per ADR-0017 D9 (pending standup); agents refuse to invoke unrecognized hashes.
- T: tool descriptions are immutable per release (AI-4 mitigation); amendments require a new registry version + deploy.
- R: every tool dispatch emits an audit entry via `IAuditLog` (ADR-0030).
- I: tool descriptors carry no sensitive data; tenant-scoped capability filtering at lookup.
- D: per-capability rate limits; expensive capabilities gate behind cost-aware routing per ADR-0041 / ADR-0052.
- E: tool-registry mutation at runtime requires explicit Operator action per ADR-0051 D11; not delegable.

**TB-7 (Agent ↔ external LLM provider)** — egress boundary; ADR-0041 governs:
- S: per-environment API keys; provider-side workspace isolation per ADR-0041.
- T: payload integrity bounded by TLS; provider's own integrity controls assumed.
- R: every dispatch emits audit per ADR-0041 (and ADR-0030); CostLedger entry per ADR-0016 D5.
- I: `evals.sensitive=true` carve-out per ADR-0040 D9 governs prompt/completion retention; default is forbidden.
- D: per-tenant model-budget cap per ADR-0041; provider rate-limit honored at `IModelRouter`.
- E: model API key compromise (AI-8) — separate per-environment keys, 90-day rotation cadence.

**TB-8 (Studios-internal tooling ↔ paying-tenant data)** — read-fence boundary:
- S: operator MFA required for any tenant-data read path; no service-account access to tenant data outside support-flow allowlist.
- T: support flows are read-only; mutations require explicit Operator confirmation per ADR-0051.
- R: every operator-side tenant-data access audited via `IAuditLog` (ADR-0030) with PrincipalId.
- I: operator-side views minimize disclosure — masked PII, no cross-tenant aggregation outside aggregated metrics.
- D: not a meaningful threat at this boundary.
- E: operator credentials are the most-sensitive class; hardware MFA + separate browser profile (D3 asset table).

**TB-9 (CI/CD ↔ production)** — deploy-pipeline boundary:
- S: OIDC federation for GitHub Actions → Azure per ADR-0015 (no long-lived SP keys).
- T: signed commits where used; branch protection requires PR approval per ADR-0044.
- R: every deploy emits an annotation (per ADR-0045 D6) + an audit entry via the deploy workflow.
- I: workflow files never contain secrets (invariant 8); CI/CD secrets are repo-scoped/env-scoped.
- D: pipeline backpressure via concurrency keys per ADR-0033.
- E: deploy-time RBAC scoped to per-Node service principals; no broad subscription contributors.

**TB-10 (Open-source contributors ↔ Grid repos)** — supply-chain boundary; AI overlay applies (poisoned PR carrying adversarial prompts):
- S: GitHub signed-commit verification where committers sign; required reviewer per branch protection.
- T: PR-author cannot self-merge per ADR-0044; review-agent runs per invariant 52.
- R: PR history is git-historical; audit via GitHub.
- I: secret scanning Grid-wide per ADR-0056 D8 (packet 08) catches accidental disclosure in contributions.
- D: GitHub Actions concurrency limits bound CI cost from PR fork builds.
- E: dependency-injection via Dependabot scoped to security alerts + auto-PR for patches per ADR-0056 D7 (packet 08); minor/major require human merge; AI overlay — poisoned doc/test files carrying adversarial prompts are caught by the review agent's PR-author-untrusted-content scan (per ADR-0044/ADR-0046).

### Section 6 — AI-specific threats (8 entries)

For each AI-N, write a mitigation entry. The substance from ADR-0056 D9, recapped here with the deferred-track notes:

- **AI-1 Prompt injection (direct).** Mitigation: `PromptEnvelope` typed-channel pattern in `HoneyDrunk.AI`; analyzer rule fails CI on direct string concatenation of untrusted input. Implementing: `HoneyDrunk.AI` (ADR-0016, Seed) — **pending HoneyDrunk.AI track work; tracked in cross-track follow-up (packet 09).** Residual risk: structural separation raises the bar but does not close the surface — sophisticated content can be interpreted by the model as instructions despite channel typing; second line is AI-7's output-side guard.
- **AI-2 Indirect prompt injection.** Mitigation: untrusted external content wrapped with explicit untrusted-data tags (`<untrusted_external_content source="...">...</untrusted_external_content>`); system prompt warns the model that content within these tags is not from the user and carries no instructions to follow. Implementing: `HoneyDrunk.AI` LLM-calling library pattern. Residual risk: motivated attackers craft content the model follows despite the tags — same OWASP-LLM consensus.
- **AI-3 Model jailbreak.** Mitigation: provider-side moderation (first line) + AI-7 output-side guard (defense in depth). The Grid does not attempt to harden provider safety stacks. Implementing: provider-side (n/a Grid code) + AI-7 below. Residual risk: provider safety-stack failures are caught only by the output-side guard + the audit trail.
- **AI-4 Tool poisoning.** Mitigation: tool descriptions in `HoneyDrunk.Capabilities` registry are immutable per release; amendments require a new tool-registry version and a deployment that observes the version change; runtime addition requires explicit Operator action per ADR-0051 D11; agents discovering a tool whose description doesn't match the registered hash refuse to invoke it. Implementing: `HoneyDrunk.Capabilities` (ADR-0017, Proposed standup) — **pending Capabilities standup; tracked in cross-track follow-up (packet 09).** Residual risk: until the immutability invariant is enforced in code, tool poisoning is a process control (registry edits require operator action) rather than a system control.
- **AI-5 Training-data poisoning.** Mitigation: zero current exposure — the Grid does no fine-tuning today. Tracked at zero so the gap is visible if fine-tuning is ever added without the corresponding mitigation work. Implementing: n/a today; when fine-tuning is adopted, this entry gains training-data provenance + validation + separation of training and serving infrastructure. Residual risk: zero today.
- **AI-6 Hallucinated-fact downstream impact.** Mitigation: same as AI-7 — output-side guard. A model that confidently states a false fact and routes it into downstream automation is indistinguishable, from the automation's perspective, from a model that has been adversarially manipulated. Implementing: see AI-7. Residual risk: confident-but-false output passes the channel-typing check; only the output-side guard catches it.
- **AI-7 Data exfiltration via agent tool misuse / output-side guard.** Mitigation: high-blast-radius agent actions (file write outside a sandbox, external API call to non-allowlisted endpoint, tenant data mutation, money movement, sending a message externally) route through PR-discipline (ADR-0044) or explicit Operator confirmation (ADR-0051), never direct execution. The list of high-blast-radius actions lives in this artifact (see "Open mitigations" — section 9) and grows as new capabilities land; default for new capability is high-blast-radius until proven otherwise. Implementing: `HoneyDrunk.Capabilities` capability-side wiring (ADR-0017, Proposed standup) + `security` review agent's per-PR check (ADR-0046, Proposed) — **pending Capabilities standup + ADR-0046 acceptance; tracked in cross-track follow-up (packet 09).** Residual risk: until capability-side wiring is in code, this is a process control (review-rubric responsibility) rather than a system control.
- **AI-8 Model API key compromise.** Mitigation: per-environment model API keys (dev/staging/prod); per-environment usage caps configured at the provider where supported (e.g., OpenAI project-level limits); 90-day rotation cadence (tighter than the general 180-day default) for the model-key class specifically. Implementing: Vault rotation defaults (ADR-0006) amended for the model-key class — **pending Vault.Rotation follow-up; tracked in cross-track follow-up (packet 09).** Residual risk: until the 90-day cadence is configured, model keys ride the general 180-day cadence, doubling the worst-case spend-burn window.

### Section 4 — Asset inventory threat-ID cross-references

For each of the 12 asset rows, populate the `Threat IDs` column. Examples:
- Auth signing keys → TB-3 (S/E), TB-9 (S/E), AI-7
- Per-Node Key Vault credentials → TB-3 (S/I/E)
- Customer payment tokens → TB-3 (I/E), TB-8 (I)
- Model API keys → TB-7 (S/I), AI-8
- Tenant data partitions → TB-4 (all), AI-2 (when agent reads cross-tenant content)
- Audit substrate → TB-3 (T/R), TB-8 (R)
- Notify recipient address book → TB-4 (I), TB-8 (I)
- Operator credentials → TB-8 (S/E), TB-9 (S/E)
- Source code repos → TB-10 (T/E)
- CI/CD secrets → TB-9 (I/E)
- LLM prompt/completion telemetry → TB-7 (I), AI-2
- AI agent execution state → TB-4 (I), TB-5 (R), AI-7

The agent has discretion to refine these as it writes them; the substance is "which threats from sections 5/6 target this asset."

### Section 1 — Header bump

Update:
- `**Version:** v0` → `**Version:** v1`
- `**Last reviewed:** {date}` → `{this packet's merge date}`
- Leave the quarterly-review dates as set by packet 01 (first quarterly review still calendared for the next quarter)

### Sections 7, 8, 9 — leave as v0 stubs

Section 7 (Accepted risks): still a placeholder, but Phase 2 may surface 1-3 residual risks the operator has explicitly accepted (e.g., "AI-1 structural separation is incomplete — accepted because no complete defense exists in 2026 state-of-the-art"). The agent decides whether to surface accepted risks from the mitigation entries; default is empty section with the v0 smell-note.

Section 8 (Penetration-test history): still empty — first engagement is per ADR-0056 D6 / packet 07 scoping.

Section 9 (Open mitigations): populate with the deferred items from section 6 — AI-1 `PromptEnvelope`, AI-4 immutable-tool-description, AI-7 capability-side wiring, AI-8 tighter rotation, ADR-0046's artifact-loading wiring, Audit's investigation-extended-retention. Each with a target track (the ADR or Node initiative that owns it). This section is the operator's standing TODO list for the threat model.

## Affected Files
- `constitution/threat-model.md`

## NuGet Dependencies
None. This packet modifies a single Markdown file; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The artifact lives at `constitution/threat-model.md` per ADR-0056 D4.
- [x] No code change in any other repo.
- [x] No invariant change in this packet — those landed in packet 00.

## Acceptance Criteria
- [ ] Every TBD bullet in section 5 (60 STRIDE entries across TB-1 through TB-10) is replaced with a real mitigation entry citing the implementing slice-ADR(s)/Node(s) and naming the residual risk
- [ ] Every AI-N subsection in section 6 (8 entries) carries a real mitigation entry; AI-1, AI-4, AI-7, AI-8 explicitly name the implementing track as deferred and the residual risk that flows from the deferral
- [ ] Section 4's `Threat IDs` column is populated for all 12 assets, cross-referencing the threats from sections 5/6 that target each asset
- [ ] Section 1's header reads `**Version:** v1` and the last-reviewed date is updated to this packet's merge date
- [ ] Section 7 (Accepted risks) carries any residual risks the operator has explicitly accepted (default: empty with the v0 smell-note if no accepted risks surface during fill)
- [ ] Section 9 (Open mitigations) lists the deferred items from section 6 with their target track (AI's `PromptEnvelope` → ADR-0016 / HoneyDrunk.AI; Capabilities' immutable-tool-description and high-blast-radius routing → ADR-0017; Vault model-key rotation → ADR-0006 amendment / Vault.Rotation follow-up; Audit investigation-extended-retention → Audit Phase-2; ADR-0046 `security.md` artifact-loading → ADR-0046 track)
- [ ] Every mitigation entry uses the `per ADR-NNNN DN` cross-reference convention from packet 01
- [ ] No section is removed; v0 structure is preserved and only TBDs are filled

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0056 D2/D3 — boundary inventory and asset classification.** The substrate this packet fills against.

**ADR-0056 D9 — AI-specific protections.** AI-1 structural separation, AI-2 untrusted-content wrapping, AI-3 provider-side + AI-7 output-side, AI-4 immutable-tool-description, AI-5 zero-exposure-tracked, AI-6 = AI-7, AI-7 PR-discipline-or-Operator-confirmation routing, AI-8 per-environment keys + usage caps + 90-day rotation.

**ADR-0056 D14 Phase 2 — fill the artifact with real mitigation entries.** This packet executes Phase 2.

**Slice-ADRs cited:** ADR-0006 (rotation), ADR-0010 (Auth validator), ADR-0011 (review), ADR-0015 (Container Apps), ADR-0026 (multi-tenant), ADR-0028 (messaging), ADR-0030/0031 (audit), ADR-0033 (deploy gating), ADR-0040 (telemetry), ADR-0041 (LLM egress), ADR-0044 (PR discipline), ADR-0045 (errors), ADR-0046 (specialist review — Proposed), ADR-0049 (data classification — Proposed), ADR-0050 (customer comms — Proposed), ADR-0051 (agent authority — Proposed), ADR-0052 (cost — Proposed), ADR-0054 (incident — Proposed).

## Constraints
- **Concise entries — mapping not explanation.** Each STRIDE/AI entry is one to three lines: threat → mitigation → implementing ADR → residual risk. Do not re-explain how the implementing mechanism works; that's the implementing ADR's job (D4 explicit rule).
- **Deferred items are explicit.** AI-1, AI-4, AI-7, AI-8 entries name the implementing track as deferred ("pending {ADR-NNNN / Node track}; tracked in cross-track follow-up (packet 09)") and state the residual risk that flows from the deferral. Do not hide deferrals behind soft language.
- **Honest residual risk.** Every entry names the residual risk — even when it's "low," "covered by another mitigation," or "structural separation is incomplete by construction." An entry without a residual risk is a sign of dishonest mitigation accounting (D2 explicit rule — "a boundary listed without a residual-risk entry is dishonest").
- **`per ADR-NNNN DN` cross-references throughout.** Greppable. ADR-NNNN must be the actual ADR; do not invent ADR numbers.
- **Do not invent boundaries, assets, or threats not in ADR-0056.** This packet **fills** the v0 shell; it does not add new TB-N or AI-N entries. New boundaries/assets/threats are added via subsequent commits driven by standup ADRs or amendments.
- **Header version bump.** v0 → v1. The last-reviewed date is this packet's merge date.

## Labels
`feature`, `tier-2`, `meta`, `security`, `docs`, `adr-0056`, `wave-3`

## Agent Handoff

**Objective:** Replace every TBD in `constitution/threat-model.md` with a real mitigation entry — 60 STRIDE bullets, 8 AI-overlay entries, 12 asset threat-ID cross-references; bump header to v1.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the artifact operationally useful for the operator's quarterly review (D5) and for the canonical review agents.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 3.
- ADRs: ADR-0056 D2/D3/D9/D14 (primary); the cited slice-ADRs as mitigation references.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` — hard. The v0 shell must exist (the TBD entries this packet fills are placed by packet 01).

**Constraints:**
- Mapping not explanation — entries are one to three lines, citing implementing ADRs by `per ADR-NNNN DN`, not re-explaining mechanisms.
- Deferred items (AI-1/AI-4/AI-7/AI-8) are explicit: "pending {track}; tracked in packet 09" + residual risk of the deferral.
- Every entry names residual risk — no entry without one.
- Do not invent boundaries, assets, or threats — fill only.
- Header v0 → v1; last-reviewed date set to this packet's merge date.

**Key Files:**
- `constitution/threat-model.md`

**Contracts:** None changed.
