---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "security", "docs", "adr-0056", "wave-5"]
dependencies: ["packet:02", "packet:03"]
adrs: ["ADR-0056", "ADR-0016", "ADR-0017", "ADR-0006", "ADR-0031", "ADR-0046", "ADR-0035"]
accepts: ["ADR-0056"]
wave: 5
initiative: adr-0056-threat-model
node: honeydrunk-architecture
---

# Register the cross-track follow-up triggers for ADR-0056 deferred work

## Summary
Register the six deferred-to-owning-track items from ADR-0056 as a tracked list so they surface at the right Node-standup or sibling-ADR moment, not lost in the dispatch plan: (1) AI's `PromptEnvelope` typed-channel pattern + analyzer (HoneyDrunk.AI / ADR-0016 track); (2) Capabilities' immutable-tool-description-per-release (HoneyDrunk.Capabilities / ADR-0017 standup); (3) Capabilities' high-blast-radius routing (same); (4) Vault's tighter model-key rotation cadence (HoneyDrunk.Vault / ADR-0006 amendment); (5) Audit's investigation-extended-retention export interface (HoneyDrunk.Audit / Phase-2); (6) ADR-0046's `security.md` agent loading the artifact on every PR (ADR-0046 track); (7) SBOM tool selection (follow-up ADR or ADR-0035 amendment). Tracked in `initiatives/active-initiatives.md` as triggers and in `constitution/threat-model.md` section 9 (open mitigations).

## Context
ADR-0056's Follow-up Work list names 15 items. This initiative ships nine packets covering substrate, governance, runbooks, and tooling enablement. Six items are explicitly deferred to owning-Node tracks per the dispatch plan's "Coupling" sections. The deferrals are right — bundling code work into not-yet-stood-up Nodes is premature decomposition (memory note: "New-Node / standup work gets its own ADR; don't bundle into feature packets") — but they need to be **tracked** so they surface at the right moment.

This packet is the **bridge from ADR-0056's commitments to the tracks that ultimately ship them**. Without it, the deferrals are visible only in the dispatch plan (which moves to `completed/` when the initiative closes) and the artifact's section 9 (which the operator's quarterly review reads). Tracking the deferrals in `initiatives/active-initiatives.md` makes them visible at the **next planning moment** — when the operator or scope agent picks up ADR-0017's standup, ADR-0046's scope-out, or a Vault.Rotation follow-up.

**The six (plus SBOM) deferrals:**

1. **AI-1 `PromptEnvelope` typed-channel pattern + analyzer rule** in `HoneyDrunk.AI`. ADR-0016 is Accepted (the AI standup decided the seven contracts); the Node is in Seed phase. `PromptEnvelope` lands when an LLM-calling consumer needs it, and the analyzer rule lands alongside. Owning track: HoneyDrunk.AI Node track (post-Seed).
2. **AI-4 immutable-tool-description-per-release** in `HoneyDrunk.Capabilities`. ADR-0017 is Proposed (standup ADR; Capabilities does not yet exist as shipped code). The immutability commitment lands at standup as a designed-in invariant + runtime check. Owning track: ADR-0017 standup initiative.
3. **AI-7 high-blast-radius routing** in `HoneyDrunk.Capabilities`. Same Node, same standup. The capability-side wiring requires the capability registry to exist; pre-writing before standup is premature.
4. **AI-8 tighter model-key rotation cadence** (90-day vs general 180-day) in `HoneyDrunk.Vault` / Vault.Rotation. ADR-0006 is Accepted; the model-key class amendment is a one-line rotation-policy change. Owning track: Vault.Rotation follow-up or an ADR-0006 amendment packet.
5. **D10 investigation-extended-retention export interface** in `HoneyDrunk.Audit`. ADR-0031 is Accepted; Audit v0.1.0 is published. The export-and-hold mechanism is an additive read-side feature (Phase-2). Owning track: Audit Phase-2 follow-up.
6. **ADR-0046 `security.md` artifact loading.** ADR-0046 is Proposed; `.claude/agents/security.md` does not yet exist. When ADR-0046's scope-out work lands, the `security.md` file must load `constitution/threat-model.md` on every PR as input context per ADR-0056 D5. Owning track: ADR-0046 scope-out initiative.
7. **SBOM tool selection.** ADR-0056 D7 explicitly defers ("becomes a follow-up ADR or a hive-sync-driven amendment to ADR-0035"). Owning track: a new ADR (or ADR-0035 amendment) once the tool decision is made.

**Tracking surface.** Three locations cooperate to keep the deferrals visible:

- **`initiatives/active-initiatives.md`** — this packet adds the seven items to a "Deferred follow-ups" or "Triggers" subsection inside this initiative's tracking block, with the trigger condition (which event surfaces it) and the owning track.
- **`constitution/threat-model.md` section 9 (open mitigations)** — packet 02 populates section 9 with the same items; this packet ensures the two surfaces stay consistent (the artifact is read in the operator's quarterly review; the initiatives file is read at planning moments).
- **The owning track's standup or follow-up ADR** — when ADR-0017's standup is scoped, when ADR-0046's scope-out is scoped, when a Vault.Rotation follow-up is scoped, those scope passes consume the trigger-list and decide how to incorporate the ADR-0056 commitment.

**This packet does not file PRs against any owning track.** That is each owning track's responsibility when it next plans work. The seven items are **planning inputs**, not assigned issues.

**Sequencing.** This packet depends on packet 02 (the artifact's section 9 is populated) and packet 03 (the standup-template + hive-sync extension is in place — relevant because the AI-sector standups and Audit Phase-2 will read both surfaces). Wave 5 alone — runs after both Wave 3 and Wave 4 are at least partly landed.

**This is a docs packet. No code, no .NET project.**

## Scope
- `initiatives/active-initiatives.md` — add a "Deferred follow-up triggers" subsection inside this initiative's tracking block.
- Cross-check / minor-update `constitution/threat-model.md` section 9 (open mitigations) for consistency with the initiatives-file list. Packet 02 populates section 9 with the same items; this packet confirms consistency and updates phrasing where helpful — does not re-decide content.

## Proposed Implementation

### 1. `initiatives/active-initiatives.md` — Deferred follow-up triggers subsection

Inside the `### ADR-0056 Threat Model and Security Review Cadence` initiative block (registered by packet 00), add a `**Deferred follow-up triggers:**` subsection with the seven items. Format consistent with the existing initiative-tracking convention (see the `### ADR-0044 Cloud Code Review` initiative's tracking subsections for the precedent).

Content:

```markdown
**Deferred follow-up triggers (per dispatch plan / artifact section 9):**

These items are owned by other Node or ADR tracks and surface when those tracks next plan work. They are not packets in this initiative.

| # | Item | Trigger event | Owning track | Threat-model entry |
|---|---|---|---|---|
| df-1 | `PromptEnvelope` typed-channel pattern + analyzer rule | First HoneyDrunk.AI LLM-calling consumer (post-Seed) | HoneyDrunk.AI Node track (ADR-0016) | AI-1 |
| df-2 | Immutable-tool-description-per-release | HoneyDrunk.Capabilities standup (ADR-0017) | ADR-0017 standup initiative | AI-4 |
| df-3 | High-blast-radius capability-side routing | Same as df-2 | Same as df-2 | AI-7 |
| df-4 | Model-API-key 90-day rotation cadence | Next Vault.Rotation follow-up or ADR-0006 amendment | HoneyDrunk.Vault / Vault.Rotation | AI-8 |
| df-5 | Investigation-extended-retention export | HoneyDrunk.Audit Phase-2 planning | HoneyDrunk.Audit (post-v0.1.0) | D10 |
| df-6 | `.claude/agents/security.md` loads threat-model artifact on every PR | ADR-0046 scope-out initiative | ADR-0046 track | D5 (per-PR cadence) |
| df-7 | SBOM tool selection | When SBOM tooling becomes a binding need (v1.5 Tier 0 release) | Follow-up ADR or ADR-0035 amendment | D7 |

These items are also listed in `constitution/threat-model.md` section 9 (open mitigations). The two surfaces are kept consistent at every quarterly review (per ADR-0056 D5).
```

### 2. Consistency check against `constitution/threat-model.md` section 9

Read `constitution/threat-model.md` section 9 (populated by packet 02). The seven df-N items above should map to seven entries in that section. Differences to reconcile:

- **Numbering.** The artifact's section 9 may use bare bullets or its own numbering; the initiatives file uses `df-N` IDs for cross-reference. Both are acceptable — verify that each item is present in both surfaces; identifier mismatch is not a defect.
- **Phrasing.** The artifact may be terser (it is the operator's quarterly-review reading); the initiatives file may include more trigger-context. Both are acceptable — the substance is what matters.
- **Missing entries.** If packet 02 missed an item that this packet expects (e.g., SBOM tool selection — df-7 — was framed as deferred in the dispatch plan but might not have made packet 02's section 9 if the v1-artifact-author judged it not a threat-model item), this packet **adds the missing entry to the artifact's section 9** to keep the two surfaces consistent.
- **Extra entries.** If packet 02's section 9 lists more open mitigations than the seven this packet expects (e.g., entries surfaced during v1 content fill), this packet leaves those in place — the artifact is authoritative for what is currently open; this packet's list is the subset that ADR-0056 explicitly deferred at scope time.

### 3. Optional — issue per owning track

For each `df-N`, consider whether to file a placeholder issue in the owning Node's repo or the owning ADR's track to make the deferral visible there. **Default: no.** The owning track will see the deferral when it next plans work (the operator or scope agent reads `initiatives/active-initiatives.md` + `constitution/threat-model.md` section 9 at planning moments). Filing placeholder issues now would clutter The Hive with not-yet-actionable items.

The exception: if a deferral has a hard external deadline (e.g., a specific regulatory date), file the issue now with the deadline. None of the seven items here has that profile — each surfaces at a track-driven moment, not a calendar moment.

## Affected Files
- `initiatives/active-initiatives.md` — extend the ADR-0056 initiative block with the Deferred-follow-up-triggers subsection.
- Optional: `constitution/threat-model.md` — minor edits to section 9 only if consistency reconciliation finds gaps.

## NuGet Dependencies
None. Docs only; no .NET project.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. `initiatives/active-initiatives.md` and `constitution/threat-model.md` both live here.
- [x] No code change in any Node — the deferrals are planning inputs to other tracks, not issued work.
- [x] No PR filed against any owning track — owning tracks consume the trigger list when they next plan work.

## Acceptance Criteria
- [ ] `initiatives/active-initiatives.md` carries a "Deferred follow-up triggers" subsection inside the ADR-0056 initiative block, listing all seven items (df-1 through df-7) with: item description; trigger event; owning track; threat-model-entry mapping
- [ ] The seven items match the artifact's `constitution/threat-model.md` section 9 (open mitigations) in substance — same items appear in both surfaces, phrasing differences acceptable
- [ ] If any item is missing from the artifact's section 9, this packet **adds** it to keep the two surfaces consistent. If the artifact's section 9 has extra items, this packet leaves them in place (artifact is authoritative for currently-open mitigations).
- [ ] No placeholder issue is filed against any owning track's repo by this packet (default; no exception triggered by any of the seven items)
- [ ] The subsection's format matches the existing initiative-tracking convention in `active-initiatives.md` (see ADR-0044 initiative block for a precedent)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0056 D9 AI-1 — `PromptEnvelope` typed-channel pattern.** Implementing in `HoneyDrunk.AI`. Deferred to AI Node track (df-1).

**ADR-0056 D9 AI-4 — Immutable-tool-description-per-release.** Implementing in `HoneyDrunk.Capabilities`. Deferred to ADR-0017 standup (df-2).

**ADR-0056 D9 AI-7 — High-blast-radius capability-side routing.** Implementing in `HoneyDrunk.Capabilities`. Deferred to ADR-0017 standup (df-3).

**ADR-0056 D9 AI-8 — Model-key tighter rotation cadence.** 90-day instead of general 180-day. Implementing in Vault rotation defaults. Deferred to Vault.Rotation follow-up (df-4).

**ADR-0056 D10 — Investigation-extended-retention export.** Implementing in `HoneyDrunk.Audit` read interface. Deferred to Audit Phase-2 (df-5).

**ADR-0056 D5 — Per-PR review-agent cadence.** `.claude/agents/security.md` loads `constitution/threat-model.md` on every PR. Implementing once ADR-0046 is Accepted and `security.md` is authored. Deferred to ADR-0046 scope-out (df-6).

**ADR-0056 D7 — SBOM generation per release.** Tool selection deferred — "becomes a follow-up ADR or a hive-sync-driven amendment to ADR-0035." Deferred to a follow-up ADR (df-7).

## Constraints
- **Planning inputs, not assigned work.** Owning tracks consume the trigger list when they next plan work; this packet does not file PRs or issues against them.
- **Two surfaces kept consistent.** `initiatives/active-initiatives.md` and `constitution/threat-model.md` section 9 list the same items; phrasing may differ.
- **Artifact is authoritative for currently-open mitigations.** If section 9 has extra items beyond the seven, this packet leaves them in place. If section 9 is missing items the dispatch plan deferred, this packet adds them.
- **Forward-only.** This packet does not back-fill deferrals for earlier ADRs; it covers only ADR-0056's deferrals.
- **The format matches the existing initiative-tracking convention.** See the ADR-0044 initiative block in `active-initiatives.md` for the precedent.

## Labels
`chore`, `tier-3`, `meta`, `security`, `docs`, `adr-0056`, `wave-5`

## Agent Handoff

**Objective:** Register the seven deferred follow-up triggers from ADR-0056 in `initiatives/active-initiatives.md` (and reconcile with `constitution/threat-model.md` section 9), so the deferrals surface at the right Node-standup or sibling-ADR planning moment.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the dispatch plan's "Coupling with not-yet-stood-up Nodes" deferrals visible at the next planning moment, not lost in completed-initiative folders.
- Feature: ADR-0056 Threat Model and Security Review Cadence rollout, Wave 5.
- ADRs: ADR-0056 D9 / D10 / D7 (sources of the deferrals); ADR-0016 (AI Node track); ADR-0017 (Capabilities standup); ADR-0006 (Vault rotation); ADR-0031 (Audit Phase-2); ADR-0046 (specialist review agents); ADR-0035 (versioning / SBOM possible home).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. The artifact's section 9 (open mitigations) is populated; this packet keeps the two surfaces consistent.
- `packet:03` — soft. The standup-template + hive-sync extension is in place; future AI-sector standups and Audit Phase-2 work will be readable against both surfaces.

**Constraints:**
- Planning inputs, not assigned work — no PR filed against any owning track.
- Two surfaces kept consistent; artifact is authoritative for currently-open mitigations.
- Forward-only — covers only ADR-0056's deferrals.
- Format matches existing initiative-tracking convention.

**Key Files:**
- `initiatives/active-initiatives.md`
- Optional: `constitution/threat-model.md` (consistency reconciliation only)

**Contracts:** None changed.
