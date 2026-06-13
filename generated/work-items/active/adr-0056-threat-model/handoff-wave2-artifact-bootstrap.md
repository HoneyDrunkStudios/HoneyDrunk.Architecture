# Handoff — Wave 1 → Wave 2: artifact bootstrap

**Initiative:** `adr-0056-threat-model`
**Wave transition:** Wave 1 (governance + invariants) → Wave 2 (artifact v0 shell)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 produced

- **Packet 00** — ADR-0056 flipped to **Accepted**. A block of three invariant numbers was claimed at edit time from `constitution/invariant-reservations.md` (referred to as `{N1}/{N2}/{N3}` in the packet bodies; substitute the actual claimed numbers when reading this handoff post-merge). Three new threat-model invariants were added to `constitution/invariants.md` under a new `## Security and Threat Model Invariants` section at those numbers. The verified current max accepted invariant in `invariants.md` at scope time was **53**; reservations beyond that live in `invariant-reservations.md` and are the source of truth for the actual numbers chosen.
  1. **`{N1}`** — Every Node standup ADR includes a "threat model entry" section, and the artifact is updated in the same PR that moves the standup ADR to Accepted. Enforced by `hive-sync` constitution scan (packet 03 implements the scan).
  2. **`{N2}`** — LLM calls use the `PromptEnvelope` typed-channel pattern; direct string concatenation of untrusted input into a prompt is a CI gate failure. Implementing in HoneyDrunk.AI (deferred — see Cross-track follow-ups below).
  3. **`{N3}`** — High-blast-radius agent actions route through PR-discipline (ADR-0044) or Operator confirmation (ADR-0051), never direct execution. Implementing in HoneyDrunk.Capabilities (deferred — see Cross-track follow-ups below).

ADR-0056's decisions are now live rules. Every packet in this initiative from Wave 2 onward references the ADR's D-decisions as live policy.

## What Wave 2 must deliver (packet 01)

Build the v0 shell of `constitution/threat-model.md`:

- **Section 1 (Header)** — version v0, methodology line, last-reviewed = this packet's merge date, last-quarterly-review = n/a, next-quarterly-review calendared for the first week of the next quarter.
- **Section 2 (Methodology recap)** — short paragraph; points at ADR-0056 D1 for the rationale.
- **Section 3 (Trust boundary inventory)** — full 10-row table reproduced verbatim from ADR-0056 D2.
- **Section 4 (Asset inventory)** — full 12-row table reproduced verbatim from ADR-0056 D3, with a placeholder `Threat IDs` column (TBD entries — packet 02 fills).
- **Section 5 (STRIDE pass per boundary)** — ten subsections, one per TB-N, each with six TBD bullets (S/T/R/I/D/E) carrying "target: Phase 2 / packet 02" markers.
- **Section 6 (AI-specific threats)** — eight subsections, one per AI-N, each TBD with the same target marker; AI-1, AI-4, AI-7 carry the deferred-to-owning-Node-track note.
- **Sections 7, 8, 9** — empty placeholder sections with the v0 smell-notes per packet 01's Proposed Implementation.
- **Section 10 (References)** — citations to ADR-0056, ADR-0049, ADR-0036, the slice-ADRs, NIST AI RMF, OWASP LLM Top 10, OWASP Top 10, CWE Top 25, MITRE ATLAS.

## Critical context for Wave 2 execution

- **Structure-first, content is packet 02.** Every STRIDE bullet and every AI-N entry is TBD in packet 01. Do not pre-fill content. The split lets packet 03 (hive-sync extension) author against a deterministic shape; the structure is the deliverable for packet 01.
- **Reproduce D2 and D3 verbatim.** The 10 boundaries and 12 assets come from ADR-0056; do not paraphrase or reorder rows.
- **Cross-reference convention.** `per ADR-NNNN DN` throughout. ADR-0056 D4 is explicit about this — the artifact will be grepped for impact-analysis when ADRs are amended.
- **Markdown only.** No `.tm7`, no IriusRisk, no ThreatDragon JSON. ADR-0056 D4's explicit rejection.
- **The artifact does not duplicate ADR content.** Future mitigation entries (packet 02) say "Vault enforces per-Node Key Vaults with managed-identity bootstrap per ADR-0006 D2" — they do not re-explain managed identity. Same posture in v0: stub entries reference the implementing ADR by anchor, not by retell.

## Invariants binding Wave 2

- **Invariant 93** — the artifact's existence is what makes invariant 93 enforceable. Packet 03 (Wave 3) implements the `hive-sync` scan; packet 01 lands the substrate.
- **Invariant 94** — `PromptEnvelope` typed-channel pattern. Tracked at v0 in section 6 as AI-1 (deferred to HoneyDrunk.AI track). Packet 01 records the deferral; packet 02 surfaces the residual risk; packet 09 registers the trigger.
- **Invariant 95** — High-blast-radius routing. Tracked at v0 in section 6 as AI-7 (deferred to HoneyDrunk.Capabilities standup). Same deferral pattern as 94.

## Wave 2 acceptance gate

Packet 01's PR passes the `pr-core.yml` tier-1 gate. `constitution/threat-model.md` exists with the v0 shell — 10 sections, boundary inventory + asset table filled, all STRIDE/AI bullets stubbed with target-markers, placeholder sections for accepted-risks / pentest-history / open-mitigations with v0 smell-notes.

After Wave 2, Wave 3 starts in parallel:
- **Packet 02** (content fill) — depends on packet 01.
- **Packet 03** (standup-template + hive-sync extension) — depends on packet 01.
- **Packet 04** (`SECURITY.md` authoring) — depends only on packet 00 (already landed); could start in Wave 2 in parallel with 01, but grouped into Wave 3 in the dispatch plan for tidy filing.

## Cross-track follow-ups (deferred — see packet 09 for the tracker)

Wave 2 does not deliver these — they are owned by other tracks. Listed here so the Wave 2 executor knows what is **not** in scope:

- **df-1 `PromptEnvelope` typed-channel pattern + analyzer rule** — HoneyDrunk.AI Node track (post-Seed). Tracked at packet 01 / 02 in section 6 AI-1.
- **df-2 Immutable-tool-description-per-release** — ADR-0017 standup initiative. Tracked in section 6 AI-4.
- **df-3 High-blast-radius capability-side routing** — same as df-2. Tracked in section 6 AI-7.
- **df-4 Model-key 90-day rotation cadence** — Vault.Rotation follow-up. Tracked in section 6 AI-8.
- **df-5 Investigation-extended-retention export** — HoneyDrunk.Audit Phase-2. Tracked in section 5 TB-3 (R) + section 6 D10 reference.
- **df-6 `.claude/agents/security.md` loads artifact** — ADR-0046 scope-out initiative. Tracked in section 2 / packet 02 references.
- **df-7 SBOM tool selection** — follow-up ADR or ADR-0035 amendment. Tracked in section 9 (open mitigations) once packet 02 fills it.
