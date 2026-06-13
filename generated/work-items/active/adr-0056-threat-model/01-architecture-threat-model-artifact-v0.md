---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "security", "docs", "adr-0056", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0056"]
accepts: ["ADR-0056"]
wave: 2
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Author constitution/threat-model.md v0 — header, boundary inventory, asset table, stub STRIDE/AI subsections

## Summary
Create the v0 shell of `constitution/threat-model.md` per ADR-0056 D4: the ten-section structure with the header (version + last-reviewed + last-quarterly-review + next-quarterly-review dates), methodology recap pointing back at ADR-0056, the full D2 trust-boundary inventory (10 entries), the full D3 asset inventory (12 rows crossing ADR-0049 sensitivity and ADR-0036 RPO/RTO), stub STRIDE-pass subsections per TB with six bullets each (each bullet marked TBD with a target date for fill), stub AI-overlay subsections per AI-N, empty accepted-risks / pentest-history / open-mitigations sections, and a references section citing ADR-0056, ADR-0049, ADR-0036, NIST AI RMF, OWASP LLM Top 10, OWASP Top 10 web, CWE Top 25.

## Context
ADR-0056 D4 commits to a single living artifact at `constitution/threat-model.md` in markdown (not a tool-specific format), with ten enforced sections. The ADR is explicit that **it proposes the path and the shape; it does not write the file itself** — the file's first commit lands as a follow-up after acceptance. This packet is that follow-up.

The split between v0 (this packet) and v1 (packet 02) is **deliberate** per ADR-0056 D14 Phase 1 / Phase 2:

- **Phase 1 / v0** — structure-first. The boundary inventory and the asset table are filled (those are factual catalogs cross-referencing ADR-0049 / ADR-0036). The STRIDE-pass subsections per TB and the AI-overlay subsections per AI-N exist as stubs with "TBD — target: {Phase 2}" markers so the section structure is in place and the file is parseable by `hive-sync` (packet 03) from day one.
- **Phase 2 / v1** — content fill. Packet 02 replaces every TBD with a real mitigation entry citing the implementing slice-ADR.

Writing the structure first means the `hive-sync` extension (packet 03) can be authored against a deterministic file shape, and the standup-ADR template amendment (also packet 03) can reference real section anchors. Writing the content first would mean re-shaping the file twice; writing both at once would be a large unreviewable commit.

The artifact lives at `constitution/threat-model.md` — the canonical path ADR-0056 D4 names. It joins the existing `constitution/` files (`invariants.md`, `manifesto.md`, `charter.md`, `agent-capability-matrix.md`, `sector-interaction-map.md`, `naming-conventions.md`, `terminology.md`, `ai-sector-architecture.md`, `feature-flow-catalog.md`, `sectors.md`).

**This is a docs-only packet. No code, no .NET project.**

## Scope
- New file `constitution/threat-model.md` with the v0 shell structure: ten sections per ADR-0056 D4.

## Proposed Implementation

Author `constitution/threat-model.md` with the following sections.

### Section 1 — Header
```
# Threat Model

**Version:** v0
**Methodology:** STRIDE per trust boundary + AI-specific overlay (per ADR-0056 D1)
**Last reviewed:** {YYYY-MM-DD — this packet's merge date}
**Last quarterly review:** n/a — first quarterly review calendared for {first week of next quarter}
**Next quarterly review:** {first week of next quarter — YYYY-MM-DD}
**Maintainer:** the operator
**Source of truth for:** Grid attacker model + mitigation mapping + accepted-risk log
```

### Section 2 — Methodology recap
A short paragraph stating the methodology choice (STRIDE per trust boundary + AI-specific overlay), citing ADR-0056 D1 for the rationale, and summarizing the STRIDE letters (S/T/R/I/D/E) plus the AI overlay codes (AI-1 through AI-8). Do not reproduce the rationale — point at ADR-0056.

### Section 3 — Trust boundary inventory (D2)
Reproduce the full 10-row table verbatim from ADR-0056 D2:

| # | Trust boundary | Description | STRIDE pass | AI overlay |
|---|---|---|---|---|
| TB-1 | Public internet ↔ Web.Rest / Front Door | Untrusted public ingress to the Grid's HTTP surface. | Full | n/a |
| TB-2 | Web.Rest ↔ application Nodes (Notify, Pulse, Communications) | Internal HTTP / gRPC / Service Bus hops behind the front door. | Full | n/a |
| TB-3 | Application Nodes ↔ Vault / Data | Secret resolution and data persistence boundaries. | Full | n/a |
| TB-4 | Tenant A ↔ Tenant B | Multi-tenant isolation per ADR-0026; the most consequential application-level boundary. | Full | applies (agent execution may span tenants) |
| TB-5 | Human user ↔ agent | Delegated authority per ADR-0051; the user grants the agent rights within a scope. | Full | applies |
| TB-6 | Agent ↔ tool registry (Capabilities per ADR-0017) | The agent's interaction with its declared tool surface. | Full | applies |
| TB-7 | Agent ↔ external LLM provider (data egress per ADR-0041) | Outbound boundary where prompt/completion content crosses out of the Grid. | Full | applies |
| TB-8 | Studios-internal tooling ↔ paying-tenant data | Operator-side tooling (admin consoles, support flows) crossing into customer data. The "read fence" boundary. | Full | n/a |
| TB-9 | CI/CD ↔ production | Deploy pipeline crossing into production infrastructure (per ADR-0015 and the Actions reusable workflows). | Full | n/a |
| TB-10 | Open-source contributors ↔ Grid repos | Untrusted external code contributions to open-source Grid repos (per ADR-0039). | Full | applies (a poisoned PR could carry adversarial prompts in docs/tests) |

State the maintenance rule: the inventory is **expected to grow** (every new Node standup ADR's "threat model entry" section adds new boundaries if any) and is **not** expected to retroactively shrink (boundary removal requires its own ADR).

### Section 4 — Asset inventory (D3)
Reproduce the full asset table verbatim from ADR-0056 D3. Add a placeholder `Threat IDs` column with `TBD` entries — packet 02 fills the cross-references.

| Asset | Sensitivity (ADR-0049) | RPO (ADR-0036) | RTO (ADR-0036) | Primary defenses | Threat IDs |
|---|---|---|---|---|---|
| Auth signing keys (JWT, Vault unseal) | Secret | 0 | < 1h | Vault, rotation per ADR-0006 | TBD |
| Per-Node Key Vault credentials | Secret | 0 | < 1h | Managed identity, ADR-0006 bootstrap pattern | TBD |
| Customer payment tokens (Stripe per ADR-0037) | Secret | 0 | < 1h | Token vaulted at Stripe; we hold reference IDs only | TBD |
| Model API keys (OpenAI, Anthropic, etc. per ADR-0041) | Secret | 0 | < 1h | Key Vault; per-environment rotation; usage caps | TBD |
| Tenant data partitions (ADR-0026) | Customer (per tenant) | < 5min (Tier 0) | < 1h (Tier 0) | Tenant-scoped partition keys, gateway-enforced; cross-tenant query fail-closed default | TBD |
| Audit substrate (ADR-0030) | Sensitive (append-only) | 0 | < 4h | Append-only-by-interface, dedicated retention (730 days per ADR-0040 D3) | TBD |
| Notify recipient address book | Customer | < 1h | < 4h | Per-tenant partitioning; PII-scrubbing in observability pipelines | TBD |
| Operator credentials (GitHub, Azure, vendor consoles) | Secret | n/a | n/a | Hardware MFA, separate browser profile, no cross-account session reuse | TBD |
| Source code repos | Internal (public repos) / Sensitive (private repos) | Git-replicated | < 1h | GitHub branch protection, signed commits where used, secret scanning per D8 | TBD |
| CI/CD secrets (GitHub Actions secrets) | Secret | n/a | < 1h | Repo-scoped or env-scoped; least-privilege; OIDC federation where possible | TBD |
| LLM prompt/completion telemetry (when retained per ADR-0040 D9 carve-out) | Sensitive | < 1h | < 24h | Default-forbidden retention; `evals.sensitive=true` carve-out; PII-scrubbing | TBD |
| AI agent execution state (Memory per ADR-0022) | Customer (per tenant) | < 5min | < 1h | Per-tenant scoping; tied to TB-4 isolation guarantees | TBD |

State the data-vs-system-asset split note: ADR-0049 classifies data records; this table classifies system assets (the bytes themselves plus credentials and substrates that are not data records).

### Section 5 — STRIDE pass per boundary
One subsection per TB-N, with six bullets each (S/T/R/I/D/E). Every bullet uses the format:

```
- **S — Spoofing — TBD (target: Phase 2 / packet 02).** {threat → mitigation → implementing ADR(s)/Node(s) → residual risk}
- **T — Tampering — TBD ...**
- **R — Repudiation — TBD ...**
- **I — Information disclosure — TBD ...**
- **D — Denial of service — TBD ...**
- **E — Elevation of privilege — TBD ...**
```

Ten subsections (TB-1 through TB-10), each with six TBD bullets. State an explicit "target: Phase 2 / packet 02" marker so the placeholder is observable to `hive-sync` and to the operator.

### Section 6 — AI-specific threats
One subsection per AI-N from D1 (AI-1 through AI-8). Each subsection has the same shape (threat → mitigation → implementing ADR/Node → residual risk), marked TBD with the same "target: Phase 2 / packet 02" anchor.

For AI-1 / AI-4 / AI-7 specifically, note in the TBD entry that the implementing work is deferred to owning-Node tracks (HoneyDrunk.AI for AI-1's `PromptEnvelope`; HoneyDrunk.Capabilities for AI-4's immutable-tool-description and AI-7's high-blast-radius routing) per the dispatch plan's deferral notes.

### Section 7 — Accepted risks
Empty placeholder section with a one-line note:

```
> No risks accepted yet. An empty section here is a smell once Phase 2 is complete — every honest threat model has at least a few accepted residual risks.
```

### Section 8 — Penetration-test history
Empty placeholder section with a one-line note:

```
> No engagements yet. The pre-Notify-Cloud-GA engagement (per ADR-0056 D6) is the first; results append here as section 8.1.
```

### Section 9 — Open mitigations
Empty placeholder section with a one-line note:

```
> Open mitigations from this artifact's STRIDE pass populate here once Phase 2 fills the subsections.
```

### Section 10 — References
Citations:
- **ADR-0056** (this artifact's governing decision)
- **ADR-0049** (data classification)
- **ADR-0036** (disaster recovery tiers)
- **ADR-0006** (secret rotation), **ADR-0011** (code review), **ADR-0026** (multi-tenant), **ADR-0030/0031** (audit substrate), **ADR-0041** (LLM provider egress), **ADR-0044** (PR discipline), **ADR-0046** (specialist review agents — Proposed), **ADR-0050** (customer comms — Proposed), **ADR-0051** (agent authority — Proposed), **ADR-0054** (incident response — Proposed)
- **NIST AI Risk Management Framework (AI RMF 1.0)** — https://www.nist.gov/itl/ai-risk-management-framework
- **OWASP LLM Top 10 (2025)** — https://owasp.org/www-project-top-10-for-large-language-model-applications/
- **OWASP Top 10 (web)** — https://owasp.org/www-project-top-ten/
- **CWE Top 25** — https://cwe.mitre.org/top25/
- **MITRE ATLAS** — https://atlas.mitre.org/

Note: each cross-link to an ADR uses the convention from ADR-0056 D4 — `per ADR-0006 D3` style, not free-text. This makes the artifact greppable for impact-analysis.

## Affected Files
- `constitution/threat-model.md` (new)

## NuGet Dependencies
None. This packet creates a single Markdown file; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] The file lives at `constitution/threat-model.md`, the canonical path ADR-0056 D4 names.

## Acceptance Criteria
- [ ] `constitution/threat-model.md` exists with the ten sections from ADR-0056 D4 in order
- [ ] Section 1 (header) carries version v0, the methodology line, the merge-date "last reviewed", an n/a "last quarterly review", and a calendared "next quarterly review" date (first week of the next calendar quarter)
- [ ] Section 2 (methodology recap) summarizes STRIDE + AI overlay in a short paragraph and points at ADR-0056 D1
- [ ] Section 3 (boundary inventory) carries all 10 TBs verbatim from ADR-0056 D2 with the maintenance rule
- [ ] Section 4 (asset inventory) carries all 12 assets verbatim from ADR-0056 D3 with the data-vs-system-asset split note and a placeholder `Threat IDs` column
- [ ] Section 5 (STRIDE pass per boundary) has ten subsections, one per TB-N, each with six TBD bullets carrying the "target: Phase 2 / packet 02" marker
- [ ] Section 6 (AI-specific threats) has eight subsections, one per AI-N, each TBD with the same target marker; AI-1, AI-4, AI-7 carry the deferred-to-owning-Node-track note
- [ ] Sections 7, 8, 9 are empty placeholder sections with the one-line notes from Proposed Implementation
- [ ] Section 10 (references) cites ADR-0056, ADR-0049, ADR-0036, the slice-ADRs (0006, 0011, 0026, 0030, 0031, 0041, 0044, 0046, 0050, 0051, 0054), NIST AI RMF, OWASP LLM Top 10, OWASP Top 10 web, CWE Top 25, MITRE ATLAS
- [ ] ADR cross-references use the `per ADR-NNNN DN` convention (greppable for impact-analysis)
- [ ] No content fill in this packet — every STRIDE bullet and every AI-N entry is TBD (Phase 2 / packet 02 owns content fill)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0056 D2 — Trust boundary inventory (10 entries).** TB-1 through TB-10 as enumerated in the table; the list is expected to grow but not retroactively shrink. Every new Node standup ADR's "threat model entry" section adds new boundaries if any.

**ADR-0056 D3 — Asset classification crossing ADR-0049 sensitivity and ADR-0036 RPO/RTO.** 12 assets enumerated; system-asset axis layered on data-record axis (ADR-0049) without changing the data-record axis. Each asset will get threat-ID cross-references in Phase 2.

**ADR-0056 D4 — Artifact at `constitution/threat-model.md` with ten enforced sections.** Markdown, not a tool-specific format. The artifact does not duplicate ADR content — it is the mapping (threat → mitigation → implementing ADR), not the explanation of the underlying mechanism.

**ADR-0056 D14 Phase 1 — Artifact v0 with stub STRIDE-pass subsections.** Six bullets per boundary even if the bullets initially say "TBD" with a target date. This packet executes Phase 1; packet 02 executes Phase 2.

## Constraints
- **Structure-first; content is packet 02.** Every STRIDE bullet and every AI-N entry is TBD in this packet. Do not pre-fill content. The deliberate split lets packet 03 (hive-sync extension) and packet 04 (`SECURITY.md`) author against a deterministic file shape.
- **Reproduce D2 and D3 verbatim.** The boundary table and the asset table come from the ADR; do not paraphrase or reorder rows.
- **Cross-reference convention.** ADR cross-references use `per ADR-NNNN DN` style throughout. The artifact will be grepped for impact-analysis when ADRs are amended; free-text references defeat that.
- **No tool-specific format.** The file is markdown only. No `.tm7` (Microsoft Threat Modeling Tool), no IriusRisk project file, no ThreatDragon JSON — see ADR-0056 D4's explicit rejection.
- **The artifact does not duplicate ADR content.** Mitigation entries (in packet 02) will say "Vault enforces per-Node Key Vaults with managed-identity bootstrap per ADR-0006 D2" — they do not re-explain how managed identity works. The artifact's job is the mapping, not the explanation.

## Labels
`feature`, `tier-2`, `meta`, `security`, `docs`, `adr-0056`, `wave-2`

## Agent Handoff

**Objective:** Create `constitution/threat-model.md` v0 — the ten-section shell with boundary inventory + asset table filled, STRIDE/AI subsections stubbed with TBD markers targeting Phase 2 / packet 02.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land the canonical artifact path and the deterministic file structure so packet 03 (hive-sync extension) and packet 04 (`SECURITY.md`) can author against it.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 2.
- ADRs: ADR-0056 D2/D3/D4/D14 (primary); ADR-0049 (data classification — cited); ADR-0036 (DR tiers — cited); slice-ADRs 0006/0011/0026/0030/0031/0041/0044/0046/0050/0051/0054 (cited in references).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — hard. ADR-0056 must be Accepted before its artifact lands at the canonical path.

**Constraints:**
- Structure-first; content fill is packet 02 — every STRIDE/AI bullet is TBD.
- D2 boundary table and D3 asset table reproduced verbatim from the ADR.
- ADR cross-references use the `per ADR-NNNN DN` convention.
- No tool-specific format — markdown only.
- The artifact does not duplicate ADR content.

**Key Files:**
- `constitution/threat-model.md` (new)

**Contracts:** None changed. The artifact is a governance document, not a code contract.
