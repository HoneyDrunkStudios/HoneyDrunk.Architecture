---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "constitution", "audit", "adr-0031"]
dependencies: ["Architecture#109"]
adrs: ["ADR-0031", "ADR-0030"]
accepts: ADR-0031
wave: 1
initiative: adr-0031-audit-node-standup
node: honeydrunk-audit
---

# Chore: Add ADR-0031's two new invariants (next two free slots) to the Grid constitution

## Summary
Add two new invariants to `constitution/invariants.md` derived from ADR-0031 D9 (downstream Abstractions-only coupling) and ADR-0031 D8 (Audit contract-shape canary requirement). Assign them the next two free slots under the existing `## Audit Invariants` section, which already carries the substrate-level audit-emission boundary invariant landed by ADR-0030 packet 02. Update ADR-0031's Consequences section to finalize the invariant numbers (replace the tentative-numbering preamble), and update `repos/HoneyDrunk.Audit/invariants.md` to cite the now-final invariant numbers in its trailing cross-reference paragraph.

**Collision reality at edit time (2026-05-20):** ADR-0030 packet 02 was originally drafted assuming 44 was free and reserved 45/46 for this packet. As of 2026-05-20, `constitution/invariants.md` already has invariants 44/45/46 occupied by ADR-0016 (AI sector) — see the `## AI Invariants` section: `44.` Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`; `45.` Token cost rates / routing policies / capability declarations sourced from App Configuration via Vault's `IConfigProvider`; `46.` HoneyDrunk.AI Node CI contract-shape canary. The real high-water mark is **46**. The next two free slots **at this packet's edit time** are therefore **47** and **48** (or higher if ADR-0018 packet 02 — which claims 47-50 — lands first; or higher still if any other ADR's invariant-numbering packet lands between this scoping and this packet's edit time). See the §Collision-Check Protocol below.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0031 explicitly delegates final invariant numbering to the scope agent at acceptance time ("Numbering is tentative — scope agent finalizes at acceptance" in the §New invariant subsection; "Scope agent assigns final invariant numbers when flipping Status → Accepted" in the "If Accepted" checklist). The two invariants ADR-0031 restates (the substrate-level audit-emission boundary belongs to ADR-0030 and lands separately) need numbered constitutional homes so:

- **The downstream-coupling rule (D9)** has a constitutional anchor the review agent can cite when an emitter or reader takes a runtime dependency on `HoneyDrunk.Audit.Data` (a future bug we want to catch at PR time, not at downstream-canary failure time).
- **The contract-shape canary requirement (D8)** outlives any single CI workflow file. The api-compatibility workflow is what enforces the rule today; the constitutional invariant makes the *obligation* outlast workflow rewrites. ADR-0016 (AI), ADR-0017 (Capabilities), ADR-0018 (Operator), and ADR-0019 (Communications) all carry analogous canary invariants for the same reason.

ADR-0030 packet 02 lands the substrate-level audit-emission boundary invariant (auditable security events emitted to the Audit substrate via `IAuditLog` on a durable channel separate from observability; Phase 1 append-only-by-interface, NOT tamper-evident) in a new `## Audit Invariants` section, with a reservation note for the next two slots. This packet redeems that reservation: the first of the new entries = downstream Abstractions-only coupling, the second = contract-shape canary. The reservation note is replaced by the actual numbered entries.

The dispatch plan for ADR-0030 originally recorded the allocation as **44 → ADR-0030 (already landed); 45 → ADR-0031 D9; 46 → ADR-0031 D8**. That allocation **no longer holds** — invariants 44/45/46 are occupied by ADR-0016 AI standup as of 2026-05-20 (and the AI section landed before ADR-0030 packet 02 will). The same logical cross-ADR allocation still applies, but with the assigned numbers shifted to the next two free slots after the substrate-level invariant lands. This packet honors the allocation in *content* (downstream coupling first, canary second, immediately after the substrate-level invariant inside `## Audit Invariants`) — the numeric assignment is whatever is actually free at edit time.

## Collision-Check Protocol (Hard Gate, Run Before Any Edit)

Before authoring any of the edits below, run:

```bash
rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20
```

Identify the current high-water mark across the entire file (not just the `## Audit Invariants` section — invariants are numbered globally, not per-section). The next two free slots after that high-water mark are this packet's assignments. Throughout this packet's edits, treat the assignments as **`N` (downstream coupling) and `N+1` (contract-shape canary)** where `N` = current high-water mark + 1.

**Known existing claims on the 44-50 range as of scoping time (2026-05-20):**

| Range | Owner ADR | Section in `constitution/invariants.md` | Status |
|---|---|---|---|
| 44 / 45 / 46 | **ADR-0016** (AI standup, Accepted) | `## AI Invariants` | **Landed** — visible in `constitution/invariants.md` at scoping time |
| 44 | **ADR-0030 packet 02** (audit substrate) | `## Audit Invariants` (new section, with reservation note for 45-46) | Pre-claim — will collide; ADR-0030 packet 02 must self-shift to the next free slot per its own collision-check protocol. The reservation note that packet writes is the substrate's "reserve next two for ADR-0031" promise — this packet redeems the next two slots after whatever ADR-0030 packet 02 actually lands |
| 47 / 48 / 49 / 50 | **ADR-0018 packet 02** (Operator standup) | `## AI Sector — Operator Invariants` (new section) | Pre-claim — has not landed yet at scoping time; if it lands before this packet, the assignments here shift up by four |
| Future AI-sector standups (ADR-0020 Agents, ADR-0021 Knowledge, ADR-0022 Memory, ADR-0023 Evals, ADR-0024 Flow, ADR-0025 Sim) | Each carries its own invariant-numbering packet | Various new sections | Pre-claims — unknown order of landing; this packet's filing-order rule (see Filing-order rule below) protects against ADR-0030 packet 02 specifically; AI-sector pre-claims are not blocking gates on this packet, but collision-check still applies |

The high-water mark at this packet's actual edit time is whatever it is — the agent runs the `rg` command above, identifies the highest existing number, and assigns this packet's two invariants to `high-water + 1` and `high-water + 2`.

**Filing-order rule (hard, enforced by `dependencies:` frontmatter):**

This packet depends on `Architecture#109` (ADR-0030 packet 02). ADR-0030 packet 02 must merge first. After it merges, this packet's agent reads `constitution/invariants.md` to find the actual `## Audit Invariants` section + the actual number ADR-0030 packet 02 landed at + the actual reservation note for the next two slots. This packet appends to that section using the two slots that the reservation note explicitly identifies.

**If the reservation note in `## Audit Invariants` after ADR-0030 packet 02 merges does NOT match the high-water mark + 1 / + 2 (because some other ADR-0018 or AI-sector standup packet 02 squeezed in between),** then ADR-0030 packet 02's own self-shift collision check failed and the dispatch plan's narrative needs honest updating before this packet's PR opens. Stop, surface, fix ADR-0030 packet 02 forward (a new packet, not an amendment — invariant 24), and re-run the collision check.

**Cross-references to update with the assigned numbers (in lockstep, before commit):**

- `adrs/ADR-0031-stand-up-honeydrunk-audit-node.md` — Consequences §New invariant subsection (see implementation block below).
- `repos/HoneyDrunk.Audit/invariants.md` — trailing cross-reference paragraph (see implementation block below).
- `03-audit-node-scaffold.md` source file (this initiative's packet 03) — its acceptance criteria, constraints, and Referenced-Invariants sections currently template `{N-coupling}` and `{N-canary}` placeholders for the two assigned numbers. Substitute the assigned numbers in place pre-push under invariant 24's pre-filing carve-out. **Packets 01 and 03 cannot be filed in the same push** because packet 03's placeholders depend on packet 01's actual assignment.
- `04-auth-wire-first-emitter.md` source file (this initiative's packet 04) — same templating applies. Same pre-push substitution rule under invariant 24.

## Proposed Implementation

### `constitution/invariants.md` — extend the existing `## Audit Invariants` section with the two new invariants; remove the reservation note

After ADR-0030 packet 02 merges (the dependency on this packet — `Architecture#109`), the relevant block in `constitution/invariants.md` reads roughly (the exact numbers depend on what ADR-0030 packet 02's own collision-check assigned — could be 47, 48, 49, or higher depending on what else lands in between; the structure is what matters):

```markdown
## Audit Invariants

{N-substrate}. **Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry.**
    Login attempts, authorization grants and denials, and privileged-action execution are recorded durably and attributably through `IAuditLog`. Auditable security events routed only to sampled or retention-bounded observability (Pulse / Loki) are a boundary violation — observability answers "is the system healthy in aggregate," audit answers "who did what, when, against what, and was it allowed." The audit channel and the telemetry channel are never merged: audit *records* are not telemetry and never flow to Pulse, and the Audit Node's own operational telemetry flows one-way to Pulse with no runtime dependency on Pulse. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. See ADR-0030 D1, D6, D7, D9.

_Invariants {N-coupling} and {N-canary} are reserved for the HoneyDrunk.Audit stand-up (ADR-0031): the Audit downstream Abstractions-only coupling rule (D9) and the Audit contract-shape canary requirement (D8). They will be added here when the ADR-0031 standup initiative is scoped and executed — deliberately not landed with the substrate-level invariant, to keep ADR-0030 and ADR-0031 from double-numbering._
```

Where `{N-substrate}` is whatever number ADR-0030 packet 02 actually assigned (per its own collision-check) and `{N-coupling}` / `{N-canary}` are the two numbers it reserved (typically `{N-substrate}+1` and `{N-substrate}+2`).

This packet makes two edits:

1. **Remove the reservation paragraph** (the `_Invariants {N-coupling} and {N-canary} are reserved..._` italic block).
2. **Append two new invariants `{N-coupling}` and `{N-canary}`** in its place, preserving the section header and the substrate-level invariant above unchanged.

After this packet's edit, the same section reads:

```markdown
## Audit Invariants

{N-substrate}. **Durable, attributable security and action events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry.**
    Login attempts, authorization grants and denials, and privileged-action execution are recorded durably and attributably through `IAuditLog`. Auditable security events routed only to sampled or retention-bounded observability (Pulse / Loki) are a boundary violation — observability answers "is the system healthy in aggregate," audit answers "who did what, when, against what, and was it allowed." The audit channel and the telemetry channel are never merged: audit *records* are not telemetry and never flow to Pulse, and the Audit Node's own operational telemetry flows one-way to Pulse with no runtime dependency on Pulse. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. See ADR-0030 D1, D6, D7, D9.

{N-coupling}. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`.**
    Emitters (Auth, Operator, any Node recording a security or privileged-action event) and readers compile against `HoneyDrunk.Audit.Abstractions`. Composition against `HoneyDrunk.Audit.Data` — which store backing is active, which retention policy is loaded — is a host-time concern resolved at application startup from App Configuration. Production references to `HoneyDrunk.Audit.Data` from consumer Nodes are forbidden; test-time fixtures, when packaged as a future `HoneyDrunk.Audit.Testing` artifact, remain test-time only. See ADR-0031 D9.

{N-canary}. **The HoneyDrunk.Audit Node CI must include a contract-shape canary for `IAuditLog`, `IAuditQuery`, and `AuditEntry`.**
    Shape drift on any of the three frozen contracts — method signatures, parameter shapes, record members — is a build failure unless paired with an intentional version bump. `IAuditLog` is on the write path of every security and privileged-action event in the Grid; `AuditEntry` is its payload; `IAuditQuery` is the contract every forensic reader (and the future tenant-facing forensics Service) compiles against. The whole public surface of `HoneyDrunk.Audit.Abstractions` is exactly these three contracts; the canary is scoped to the Abstractions assembly and the whole-assembly diff produced by `HoneyDrunk.Actions/.github/workflows/job-api-compatibility.yml` is sufficient to enforce shape stability. See ADR-0031 D8.
```

Notes for the executing agent:

- **Number-collision check is a hard gate.** Per the §Collision-Check Protocol above, run `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20` and identify the actual high-water mark **after** ADR-0030 packet 02 has merged. Use the two slots that the reservation note left by ADR-0030 packet 02 explicitly identifies — those are `{N-coupling}` and `{N-canary}` for this packet's substitutions throughout the edits below.
- **The substrate invariant's number is also dynamic.** ADR-0030 packet 02's own collision check may have shifted it from the originally-planned 44 to a higher number (47, 51, etc.) depending on what other invariant-numbering packets landed before it. This packet's edits to ADR-0031 Consequences and to `repos/HoneyDrunk.Audit/invariants.md` must reference the *actual* substrate number (`{N-substrate}`), not a hardcoded 44.
- **Do not introduce a new section header.** Invariants `{N-coupling}` and `{N-canary}` extend the existing `## Audit Invariants` section. The next section after Audit is whatever ADR-0030 packet 02 left in place.
- **No `(Proposed)` qualifier on the two new invariants.** ADR-0031 is flipped to Accepted (eventually) by the scope agent housekeeping at initiative completion — after this packet's PR + packets 02/03/04 merge. The invariants read as fully active from day one; the standup ADR's "Done When" gate carries the qualifier semantics, not the constitutional text.
- **Preserve the substrate-level invariant unchanged.** This packet does not touch the text of `{N-substrate}` — only removes the reservation paragraph and appends `{N-coupling}` / `{N-canary}` after it.

### `adrs/ADR-0031-stand-up-honeydrunk-audit-node.md` — finalize the invariant numbers in Consequences

In ADR-0031's Consequences section, the §New invariant (proposed for `constitution/invariants.md`) subsection currently opens with: `Numbering is tentative — scope agent finalizes at acceptance. Proposed by ADR-0030 and restated here for the stand-up's contract-coupling rule:` followed by two bullet points (the downstream coupling rule and the contract-shape canary requirement), and ends with a parenthetical noting that the audit-emission boundary invariant is proposed in ADR-0030's Consequences and is not restated here.

Replace the opening sentence so the subsection reads (substitute the actual `{N-coupling}`, `{N-canary}`, and `{N-substrate}` numbers from this packet's collision check):

> `Assigned invariant numbers: **{N-coupling}** (downstream Abstractions-only coupling, ADR-0031 D9) and **{N-canary}** (contract-shape canary, ADR-0031 D8). See \`constitution/invariants.md\`, \`## Audit Invariants\`. The substrate-level audit-emission boundary invariant is **{N-substrate}**, landed separately by ADR-0030 packet 02.`

Leave the two bullet points and the trailing parenthetical unchanged — only the preamble sentence flips from tentative to assigned.

### `repos/HoneyDrunk.Audit/invariants.md` — update the trailing cross-reference

The repo-local invariants file at `repos/HoneyDrunk.Audit/invariants.md` currently ends (as of scoping time, 2026-05-20) with the trailing paragraph:

> `_Constitutional invariant 44 (the audit-emission boundary invariant, in \`constitution/invariants.md\`) is the Grid-level rule this Node exists to enforce. The Audit-specific downstream-coupling and contract-shape-canary invariants are introduced by the standup ADR and assigned their final constitutional numbers when that standup initiative lands._`

**The literal `44` here is stale.** It was authored when `repos/HoneyDrunk.Audit/` was first sketched (under the assumption that 44 was the next free constitutional slot) and was never re-checked when ADR-0016 AI-sector landed at 44/45/46. Treat the on-disk literal `44` as wrong on sight — the real substrate-level number is whatever ADR-0030 packet 02's own collision-check protocol assigns at its edit time (i.e., `{N-substrate}`), **regardless of what `44` says here**. This is an instance of the cross-cutting collision-check-stale-source protocol: when a repo-local file pre-cites a constitutional number, the constitutional file is authoritative and the repo-local cite must be rewritten to match.

Replace the paragraph with (substitute the actual numbers from this packet's collision check):

> `_Constitutional invariants {N-substrate} (audit-emission boundary), {N-coupling} (downstream Abstractions-only coupling), and {N-canary} (Audit contract-shape canary) in \`constitution/invariants.md\` are the Grid-level rules this Node exists to enforce. {N-substrate} was landed by ADR-0030's acceptance initiative; {N-coupling} and {N-canary} were landed by ADR-0031's stand-up initiative._`

If the substrate-level invariant landed at a number other than what ADR-0030 packet 02's reservation note records (i.e., the reservation note already lies), do not proceed — the collision check has caught a stale state. Stop, surface, and unwind ADR-0030 packet 02 forward (a new packet, not an amendment — invariant 24).

### `CHANGELOG.md` (Architecture repo)

Append to the current in-progress version section (per memory `feedback_no_unreleased_commits` — no entries under `## Unreleased`; use the existing dated SemVer-bumped section or create a new one if this commit bumps the version), substituting the actual assigned numbers: `Architecture: Add invariants {N-coupling} (downstream Nodes take a runtime dependency only on HoneyDrunk.Audit.Abstractions; HoneyDrunk.Audit.Data is host-time composition) and {N-canary} (HoneyDrunk.Audit CI must include a contract-shape canary for IAuditLog/IAuditQuery/AuditEntry — shape drift is a build failure) under the existing ## Audit Invariants section per ADR-0031 D9 and D8. Removes the reservation paragraph ADR-0030 packet 02 left in place; finalizes the invariant numbers in ADR-0031 Consequences; updates repos/HoneyDrunk.Audit/invariants.md cross-reference.`

## Affected Files

- `constitution/invariants.md` (remove the two-slot reservation paragraph in `## Audit Invariants`; append invariants `{N-coupling}` and `{N-canary}`)
- `adrs/ADR-0031-stand-up-honeydrunk-audit-node.md` (Consequences §New invariant subsection — finalize the numbers, replace the tentative-numbering preamble)
- `repos/HoneyDrunk.Audit/invariants.md` (update the trailing cross-reference paragraph)
- `CHANGELOG.md` (entry under the current dated SemVer-bumped section)

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No new design decision — invariant text is taken from ADR-0031 D8 and D9 with light wordsmithing for the constitution's voice.
- [x] The substrate-level audit-emission boundary invariant `{N-substrate}` (landed by ADR-0030 packet 02) is preserved unchanged.
- [x] No double-numbering — the 45/46 reservation was set by ADR-0030 packet 02 explicitly for this packet to redeem.
- [x] No new ADR file. This packet does not draft ADR text; it numbers ADR-0031's existing tentative invariants.

## Acceptance Criteria

- [ ] **Collision check performed at edit time** using `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20`. The actual assigned numbers (`{N-coupling}` = downstream coupling; `{N-canary}` = contract-shape canary) are recorded in the PR body and substituted into every cross-reference target. **Hardcoding 45/46 is wrong** — those slots are occupied by ADR-0016 (AI standup) as of 2026-05-20.
- [ ] `constitution/invariants.md` `## Audit Invariants` section no longer contains the two-slot reservation italic block left by ADR-0030 packet 02.
- [ ] `constitution/invariants.md` `## Audit Invariants` section carries the substrate-level invariant (unchanged, at whatever number ADR-0030 packet 02 actually landed it at), invariant `{N-coupling}` (downstream Abstractions-only coupling per ADR-0031 D9), and invariant `{N-canary}` (Audit contract-shape canary per ADR-0031 D8) in that order, monotonically numbered.
- [ ] Invariant `{N-coupling}`'s text states the runtime-dependency restriction is on `HoneyDrunk.Audit.Abstractions` only, forbids consumer references to `HoneyDrunk.Audit.Data` in production composition, and notes that test-time fixtures (future `HoneyDrunk.Audit.Testing`) remain test-time only.
- [ ] Invariant `{N-canary}`'s text names all three frozen contracts (`IAuditLog`, `IAuditQuery`, `AuditEntry`), states that shape drift is a build failure unless paired with an intentional version bump, and references the api-compatibility canary scoped to `HoneyDrunk.Audit.Abstractions`.
- [ ] **All cross-reference targets updated in lockstep with the assigned numbers:** ADR-0031 Consequences, `repos/HoneyDrunk.Audit/invariants.md`, this initiative's packet 03 source file (pre-filing under invariant 24's carve-out), this initiative's packet 04 source file (pre-filing).
- [ ] `adrs/ADR-0031-stand-up-honeydrunk-audit-node.md` Consequences §New invariant subsection has its preamble sentence replaced — "Numbering is tentative…" → "Assigned invariant numbers: **{N-coupling}**…**{N-canary}**…". The two bullet points and the trailing parenthetical about the substrate-level invariant remain unchanged.
- [ ] `repos/HoneyDrunk.Audit/invariants.md` trailing paragraph is updated to cite the three numbers with brief parenthetical descriptions, naming ADR-0030 as the source of the substrate-level invariant and ADR-0031 as the source of the other two.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer-bumped section describing the invariant additions (not under `## Unreleased`).
- [ ] PR body explicitly notes: (1) reservation paragraph removed, (2) the two new invariants landed at `{N-coupling}` and `{N-canary}` under `## Audit Invariants`, (3) ADR-0031 Consequences finalized, (4) `repos/HoneyDrunk.Audit/invariants.md` cross-reference updated, (5) packets 03 and 04 source files were edited in place pre-filing to substitute the assigned numbers.

## Human Prerequisites

- [ ] **`Architecture#109` placeholder substituted with the real GitHub issue number** in this packet's `dependencies:` frontmatter pre-push. See the dispatch plan's PRE-FILING REWRITE REQUIRED warning. `file-work-items.sh` cannot resolve the literal placeholder string.
- [ ] ADR-0030 packet 02 (whatever real issue number it gets) merged to `main` before this packet's PR is opened. Without that merge, this packet has no `## Audit Invariants` section to extend and no substrate-level invariant to slot next to.
- [ ] Confirm the assigned-number text in ADR-0031 Consequences matches the user's understanding of D8 (canary requirement) and D9 (downstream coupling) — both are mechanical text edits, but ADR Consequences edits warrant a quick eye before merge.

## Referenced Invariants

> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — Packets 03 and 04 of this initiative cite the two invariant numbers this packet assigns. Both packets must be amended in place pre-filing once this packet's PR merges and the actual assigned numbers are known. Packets 01 and 03 (and 04) cannot be filed in the same push.

## Referenced ADR Decisions

**ADR-0031 D9 (Downstream coupling rule):** Emitters and readers compile only against `HoneyDrunk.Audit.Abstractions`. They do not take a runtime dependency on `HoneyDrunk.Audit.Data` in production composition. Composition — which store backing is active, which retention policy is loaded — is a host-time concern resolved at application startup from App Configuration. This is the same abstraction/runtime split applied for AI, Capabilities, Operator, Vault, and Transport. Restated as constitutional invariant `{N-coupling}` by this packet.

**ADR-0031 D8 (Contract-shape canary):** A contract-shape canary is added to the Audit Node's CI; it fails the build if any of `IAuditLog`, `IAuditQuery`, or `AuditEntry` change shape without a corresponding version bump. All three are the hot path for every emitter and reader. Because the public surface is exactly three contracts, all three are frozen from the first scaffold rather than a four-of-N hot subset. Restated as constitutional invariant `{N-canary}` by this packet.

**ADR-0030 packet 02 (the predecessor packet, must land first):** Adds the substrate-level audit-emission boundary invariant in a new `## Audit Invariants` section with a reservation paragraph for the next two slots. This packet redeems that reservation. ADR-0030 packet 02's own collision-check protocol determines the substrate-level number; this packet's collision-check protocol determines the two redemption numbers.

**ADR-0031 §New invariant (proposed for `constitution/invariants.md`):** Numbering is tentative; scope agent finalizes at acceptance. This packet performs that finalization.

## Dependencies

- `Architecture#109` (PLACEHOLDER — substitute real issue number pre-push) — ADR-0030 packet 02 adds the substrate-level audit-emission boundary invariant in a new `## Audit Invariants` section with a reservation for the next two slots. This packet extends that section. Without the substrate-level invariant + the reservation in place, this packet has nothing to redeem.

## Labels

`chore`, `tier-2`, `architecture`, `constitution`, `audit`, `adr-0031`

## Agent Handoff

**Objective:** Add two new invariants — downstream Abstractions-only coupling (ADR-0031 D9) and Audit contract-shape canary (ADR-0031 D8) — to `constitution/invariants.md` under the existing `## Audit Invariants` section, at the next two free slots identified by collision check at edit time. Remove the two-slot reservation paragraph ADR-0030 packet 02 left in place. Finalize the invariant numbers in ADR-0031's Consequences §New invariant subsection. Update `repos/HoneyDrunk.Audit/invariants.md`'s trailing cross-reference.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Land the two constitutional invariants ADR-0031 restates so packet 03 of this initiative (the HoneyDrunk.Audit scaffold) can cite them by number, and so the review agent has citable rules for downstream-coupling and canary-requirement enforcement.
- Feature: ADR-0031 standup initiative — this is the first packet (constitution side).
- ADRs: ADR-0031 (this packet finalizes its two restated invariants); ADR-0030 (predecessor — packet 02 of that initiative lands the substrate-level invariant and reserves two slots for this packet).

**Acceptance Criteria:** As listed above.

**Dependencies:** `Architecture#109` (ADR-0030 packet 02, real issue number substituted pre-push) must be merged to `main` before this packet's PR is authored — that packet creates the `## Audit Invariants` section, lands the substrate-level audit-emission boundary invariant, and reserves the next two slots for this packet.

**Constraints:**

- **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Before a packet is filed, it may be amended to fill in missing operational context without violating this rule. After filing, state lives on the org Project board, never in the packet file. — Concretely: packets 03 and 04 of this initiative cite the two invariant numbers assigned here. Both must be amended in place pre-filing once this packet's PR merges and the actual assigned numbers are known. **Packets 01 and 03 cannot be filed in the same push, and neither can 01 and 04.**
- **The assignment is dynamic — do NOT hardcode 45/46.** At scoping time (2026-05-20), invariants 44/45/46 are occupied by ADR-0016 AI standup. The real assignments depend on what ADR-0030 packet 02's own collision check lands at + what else gets in between. Use the actual assigned numbers from the §Collision-Check Protocol.
- **Preserve the substrate-level invariant unchanged.** This packet does not touch the substrate-level invariant's text or number — only removes the reservation paragraph and appends the two new entries after it.
- **No new section header.** The two new invariants extend the existing `## Audit Invariants` section.
- **No `(Proposed)` qualifier on the new invariants.** ADR-0031 is Accepted-eligible the moment this initiative's PRs merge and the scope agent flips Status. The invariants read as fully active. (The ADR-0031 §New invariant subsection is what carries the tentative-numbering semantics; that gets finalized by this packet too.)

**Key Files:**
- `constitution/invariants.md` — remove the two-slot reservation italic block; append the two new invariants in monotonic order after the substrate-level invariant under the `## Audit Invariants` section
- `adrs/ADR-0031-stand-up-honeydrunk-audit-node.md` — Consequences §New invariant subsection preamble sentence (replace "Numbering is tentative…" with "Assigned invariant numbers: **{N-coupling}**…**{N-canary}**…")
- `repos/HoneyDrunk.Audit/invariants.md` — trailing cross-reference paragraph (update to cite the three numbers with brief parentheticals)
- `CHANGELOG.md` — append entry under the current dated SemVer section

**Contracts:**
- This packet does not author any new contracts. It records the two constitutional rules. Authoring of the actual `.cs` files (`IAuditLog`, `IAuditQuery`, `AuditEntry`) happens in packet 03 (the scaffold).
