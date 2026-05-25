---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "constitution", "web-ui", "adr-0071"]
dependencies: ["packet:01"]
adrs: ["ADR-0071"]
accepts: ADR-0071
wave: 1
initiative: adr-0071-web-ui-standup
node: honeydrunk-web-ui
---

# Chore: Add ADR-0071's three new invariants to the Grid constitution

## Summary
Add three new invariants to `constitution/invariants.md` derived from ADR-0071's Consequences §Invariants subsection:

1. **`{N1}`** — Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`. Per-PDR re-derivation of tokens or primitive CSS is a boundary violation. Per-PDR overrides via standard CSS-variable cascade are permitted.
2. **`{N2}`** — `HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios. The Studios website is a product Node, not the design-system host.
3. **`{N3}`** — `HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts. Web.UI is purely client-side substrate; the dependency direction is consumer→Web.UI, never the inverse.

All three are landed under a new `## Web.UI Invariants` section appended to `constitution/invariants.md`. The numeric assignments (`{N1}`, `{N2}`, `{N3}`) come from the reservation registry — ADR-0071 already holds the block **87–89** per `constitution/invariant-reservations.md`. **Verify at edit time** by re-reading the file; if another ADR's packet 00 landed an interim reservation, shift up by the appropriate offset per the reservation discipline.

This packet also updates ADR-0071's Consequences §Invariants subsection to finalize the numbers (replace the "(this ADR proposes — not commits …)" framing with the assigned numbers) and updates `repos/HoneyDrunk.Web.UI/invariants.md`'s trailing cross-reference paragraph to cite the assigned numbers.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0071's §Invariants subsection lists three candidate invariants for promotion at acceptance time:

> - **Invariant proposal: Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`.** Per-PDR re-derivation of tokens or primitive CSS is a boundary violation. Per-PDR overrides via standard CSS-variable cascade are permitted.
> - **Invariant proposal: Web.UI does not host Studios; Web.UI is consumed by Studios.** The Studios website is a product Node, not the design-system host. (Codifies D3.)
> - **Invariant proposal: Web.UI does not depend on any Grid Node's runtime contracts.** Web.UI is purely client-side substrate; the dependency direction is consumer→Web.UI, never the inverse. (Codifies D9.)

All three are definitive — none are conditional on first-feature-packet evidence. This packet promotes all three.

The three invariants need constitutional anchors for three reasons:

- **The downstream-coupling rule does not subsume them.** ADR-0071 D8 commits the boundary text ("Web.UI owns / Web.UI does NOT own") — but the boundary text is design-time documentation. The constitutional invariants are *runtime rules the review agent can cite at PR time*. A future Notify Cloud admin PR that quietly re-derives its own color palette instead of consuming `@honeydrunk/web-ui-tokens` is a boundary violation the review agent must catch — it needs a numbered rule to cite.
- **The Studios-not-host rule is grep-able and code-reviewable.** "Web.UI is not folded into Studios" is the kind of rule that surfaces only at PR review unless it lives in a numbered constitutional slot the reviewer agent can match against. A future PR that adds a Studios `package.json` export of `studios/design-system` is a boundary violation that needs constitutional standing to reject cleanly.
- **The zero-Grid-Node-dependency rule is grep-able and code-reviewable.** A future Web.UI PR that quietly adds a `@honeydrunk/kernel-abstractions` dependency to one of the Web.UI packages is the most likely future drift this rule exists to prevent. The contract-shape canary catches abstraction-shape drift; it cannot catch "did this PR introduce an upstream Grid-Node coupling." The constitution is the right home.

## Reservation-Claim Protocol (Hard Gate, Run Before Any Edit)

This packet adds **three** invariants to `constitution/invariants.md`. Per the reservation discipline in `constitution/invariant-reservations.md`, ADR-0071 already holds the block **87–89** for these three invariants.

**Step 1 — verify the reservation block is still 87–89.** Open `constitution/invariant-reservations.md` and read the **Active Reservations** table. As of scoping time (2026-05-25), the ADR-0071 row reads:

```
| 87–89 | ADR-0071 | Proposed | Web.UI Node standup (`{N1}`–`{N3}`). Packet 02 at `generated/issue-packets/active/adr-0071-web-ui-standup/02-architecture-web-ui-invariants.md`. (N1) Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI` — per-PDR re-derivation is a boundary violation; per-PDR CSS-variable overrides are permitted (D1 / D8). (N2) `HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios (D3). (N3) `HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts — the dependency direction is one-way consumer → Web.UI (D9). Block claimed at max(invariants.md=53, ADR-0051 reservation=57, ADR-0049 reservation=60, ADR-0054 reservation=63, ADR-0060 reservation=66, ADR-0050 reservation=68, ADR-0063 reservation=73, ADR-0064 reservation=77, ADR-0065 reservation=79, ADR-0066 reservation=82, ADR-0068 reservation=86) + 1.
```

**At edit time** verify the block is still 87–89. If a packet 00 for an earlier-numbered Proposed ADR has landed in the interim and shifted the block, update the assignment per the reservation discipline (rule 6 — first merge wins; second packet shifts upward).

**Step 2 — cross-check against `invariants.md`.** As defense-in-depth against a missed reservation, also run:

```bash
rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20
```

The numbers `{N1}`, `{N2}`, `{N3}` must be **strictly greater** than every existing number returned by that grep. If `{N1}` is not greater than the accepted high-water in `invariants.md`, the reservation-file lookup was wrong — re-do step 1.

**Step 3 — substitute `{N1}` / `{N2}` / `{N3}` throughout this packet and across cross-reference targets.** Every occurrence of `{N1}`, `{N2}`, `{N3}` in this packet's body and in the cross-reference target files (listed below) is replaced with the assigned numbers in lockstep before commit.

**Step 4 — move the ADR-0071 row from Active Reservations to the Reservation History table.** Per the reservation discipline rule 6 / the History table:

```
| 87–89 | ADR-0071 | YYYY-MM-DD | Web.UI Node standup invariants — landed in ## Web.UI Invariants section |
```

(Substitute the actual merge date — typically the date the packet 02 PR merges to `main`.)

**Cross-references to update with the assigned numbers (in lockstep, before commit):**

- `adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md` — Consequences §Invariants subsection (see implementation block below).
- `repos/HoneyDrunk.Web.UI/invariants.md` — trailing cross-reference paragraph (placeholder text written by packet 01).
- `04-web-ui-node-scaffold.md` source file (this initiative's packet 04) — its acceptance criteria, constraints, and Referenced-Invariants sections currently use `{N1}` / `{N2}` / `{N3}` placeholders for the three assigned numbers. Substitute the assigned numbers in place pre-push under invariant 24's pre-filing carve-out. **Packets 02 and 04 cannot be filed in the same push** because packet 04's placeholders depend on packet 02's actual assignment.

**Filing-order rule (hard, enforced by `dependencies:` frontmatter):**

This packet depends on `packet:01` (Architecture catalog registration). Packet 01 must merge first so that `repos/HoneyDrunk.Web.UI/invariants.md` exists on disk for this packet to update (the cross-reference paragraph at the bottom of that file references `{N1}` / `{N2}` / `{N3}` placeholders and needs in-place substitution to the assigned numbers).

## Proposed Implementation

### `constitution/invariants.md` — append a new `## Web.UI Invariants` section

Append at the end of the file (after the most-recent existing section, e.g., `## Files Invariants` if ADR-0061 has landed). The agent must verify that no `## Web.UI Invariants` section already exists (it does not at scoping time; confirm at edit time).

The new section structure — **do not include any "(Proposed)" or "(takes effect when accepted)" qualifier**; land the invariants in their final, active form:

```markdown
## Web.UI Invariants

{N1}. **Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`.**
    Every consumer frontend in the Grid — Studios, Notify Cloud admin (Blazor or React), all PDR-driven consumer apps — sources its design tokens (color, spacing, typography, radii, shadows, motion, breakpoints, z-index) from `@honeydrunk/web-ui-tokens` and its primitive CSS (reset, base typography, utility classes) from `@honeydrunk/web-ui-css`. Per-PDR re-derivation — declaring custom CSS variables for the same semantic concepts or authoring a private reset/utility-class layer — is a boundary violation. Per-PDR overrides via the standard CSS-variable cascade (a consumer setting `--hd-color-accent: var(--my-warmer-accent)` at its root, etc.) are permitted and intentional; the override flows downstream only. The review agent rejects new consumer-frontend packages that introduce a private token/CSS layer instead of consuming Web.UI's. See ADR-0071 D1 / D8.

{N2}. **`HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios.**
    Studios is a product Node, not the design-system host. The relationship is one-way: Studios consumes Web.UI's published packages (`@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, eventually `@honeydrunk/web-ui-react`) the same way Hearth, Lately, Currents, Curiosities, and Notify Cloud admin will. A PR that adds a `studios/design-system` export to Studios' package surface — or proposes folding Web.UI sources into the Studios repo — is rejected on this invariant. The Studios website is the **first consumer** of Web.UI; it is not the host. See ADR-0071 D3.

{N3}. **`HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts.**
    No package in the Web.UI repo (`@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native`) takes a runtime dependency on `HoneyDrunk.Kernel`, `HoneyDrunk.Vault`, `HoneyDrunk.Auth`, `HoneyDrunk.Data`, `HoneyDrunk.Transport`, `HoneyDrunk.Audit`, `HoneyDrunk.Pulse`, `HoneyDrunk.Notify`, `HoneyDrunk.Communications`, or any other Grid Node. The dependency direction is one-way consumer → Web.UI, never the inverse. If a consumer needs to render a Grid-canonical value type (e.g., `Money` per ADR-0069, `TenantId` per ADR-0026), the dependency direction stays consumer-side — the consuming PDR's adapter, not the Web.UI primitive. Web.UI's package.json `dependencies` and `peerDependencies` arrays contain only third-party libraries (React, React Native, headless primitives at the implementation layer) and the `HoneyDrunk.Web.UI.Blazor` `.csproj` does not reference any `HoneyDrunk.*` NuGet package. The review agent rejects additions of any `HoneyDrunk.*` dependency to any Web.UI package. See ADR-0071 D9.
```

The agent substitutes the actual assigned numbers (87, 88, 89 — or shifted block if the reservation moved at edit time) at edit time. The Markdown numbering treats these as ordered-list items — the literal numbers must be in the source.

### `adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md` — finalize the invariant numbers in Consequences

In ADR-0071's Consequences section, the §Invariants subsection currently opens with:

> `This ADR proposes (not commits — invariant numbers and final wording assigned by the scope agent at acceptance):`

Followed by three bullet points (the token-consumption proposal, the Studios-not-host proposal, the zero-runtime-dependency proposal).

Replace the opening sentence so the subsection reads (substitute the actual assigned numbers):

> `Assigned invariant numbers: **{N1}** (Grid frontend surfaces consume design tokens and primitive CSS from HoneyDrunk.Web.UI), **{N2}** (Web.UI does not host Studios; Web.UI is consumed by Studios), and **{N3}** (Web.UI does not depend on any Grid Node's runtime contracts). See \`constitution/invariants.md\`, \`## Web.UI Invariants\`. All three landed by ADR-0071's stand-up initiative (packet 02).`

Leave the three bullet points unchanged.

### `repos/HoneyDrunk.Web.UI/invariants.md` — update the trailing cross-reference

Packet 01 of this initiative writes a trailing cross-reference paragraph using `{N1}` / `{N2}` / `{N3}` placeholders. The exact text (per packet 01's implementation block) is:

> `_Constitutional invariants {N1} (Grid frontend surfaces consume design tokens and primitive CSS from HoneyDrunk.Web.UI), {N2} (HoneyDrunk.Web.UI does not host HoneyDrunk.Studios — Web.UI is consumed by Studios), and {N3} (HoneyDrunk.Web.UI does not depend on any Grid Node's runtime contracts) in \`constitution/invariants.md\` are the Grid-level rules this Node exists to enforce. All three are landed by ADR-0071's stand-up initiative (packet 02). The numeric assignments are made at packet 02's edit time via the reservation registry._`

This packet substitutes the placeholders with the assigned numbers. The replacement text:

> `_Constitutional invariants {assigned-N1} (Grid frontend surfaces consume design tokens and primitive CSS from HoneyDrunk.Web.UI), {assigned-N2} (HoneyDrunk.Web.UI does not host HoneyDrunk.Studios — Web.UI is consumed by Studios), and {assigned-N3} (HoneyDrunk.Web.UI does not depend on any Grid Node's runtime contracts) in \`constitution/invariants.md\` are the Grid-level rules this Node exists to enforce. All three landed by ADR-0071's stand-up initiative (packet 02 — this packet)._`

(Substitute the actual numeric assignments.)

### `constitution/invariant-reservations.md` — move ADR-0071 row from Active to History

Locate the ADR-0071 row in the **Active Reservations** table and remove it. Add a new row to the **Reservation History (for audit)** table at the bottom:

```
| 87–89 | ADR-0071 | YYYY-MM-DD | Web.UI Node standup invariants — landed in ## Web.UI Invariants section |
```

Replace `YYYY-MM-DD` with the merge date of this packet's PR (whatever date the file-packets pipeline records).

### `CHANGELOG.md` (Architecture repo)

Append to the current in-progress dated SemVer section (per memory `feedback_no_unreleased_commits`):

`Architecture: Add new ## Web.UI Invariants section with invariants {N1} (Grid frontend surfaces consume design tokens and primitive CSS from HoneyDrunk.Web.UI — per-PDR re-derivation is a boundary violation; per-PDR CSS-variable overrides permitted), {N2} (HoneyDrunk.Web.UI does not host HoneyDrunk.Studios — Web.UI is consumed by Studios; Studios is a product Node, not the design-system host), and {N3} (HoneyDrunk.Web.UI does not depend on any Grid Node's runtime contracts — pure client-side substrate; dependency direction is one-way consumer → Web.UI) per ADR-0071 §Invariants. Finalizes the invariant numbers in ADR-0071 Consequences (replaces the "This ADR proposes (not commits)…" framing with assigned numbers). Updates repos/HoneyDrunk.Web.UI/invariants.md trailing cross-reference. Moves ADR-0071 reservation row from Active Reservations to Reservation History in constitution/invariant-reservations.md.`

## Affected Files

- `constitution/invariants.md` (append new `## Web.UI Invariants` section with 3 invariants)
- `constitution/invariant-reservations.md` (move ADR-0071 row from Active Reservations to Reservation History)
- `adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md` (Consequences §Invariants subsection — finalize numbers)
- `repos/HoneyDrunk.Web.UI/invariants.md` (trailing cross-reference paragraph — substitute placeholders with assigned numbers)
- `CHANGELOG.md` (entry under the current dated SemVer-bumped section)

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No new design decision — invariant text is taken from ADR-0071 §Invariants with light wordsmithing for the constitution's voice.
- [x] No double-numbering — the agent verifies the reservation block (87–89) at edit time and shifts if any earlier-numbered Proposed ADR's packet 00 landed in the interim.
- [x] No `(Proposed — takes effect when accepted)` qualifier on the new invariants. Land in their final, active form.
- [x] No edit to ADR-0071's Status header. Status stays Proposed; the flip is post-merge housekeeping.

## Acceptance Criteria

- [ ] **Reservation check performed at edit time** using both `constitution/invariant-reservations.md` (Active Reservations table) and `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20`. The actual assigned numbers are recorded in the PR body and substituted into every cross-reference target. **Block is expected to remain 87–89; use only the reservation-registry assigned numbers at edit time** — if another invariant-numbering packet landed between this scoping and this packet's edit, the assignments shift.
- [ ] `constitution/invariants.md` carries a new `## Web.UI Invariants` section appended after the most-recent existing section.
- [ ] The new section carries exactly three invariants at the assigned monotonic numbers: `{N1}` (Grid frontend surfaces consume design tokens and primitive CSS from `HoneyDrunk.Web.UI`), `{N2}` (`HoneyDrunk.Web.UI` does not host `HoneyDrunk.Studios`; Web.UI is consumed by Studios), `{N3}` (`HoneyDrunk.Web.UI` does not depend on any Grid Node's runtime contracts).
- [ ] **No `(Proposed)` or `(takes effect when ADR-0071 is accepted)` qualifier** appears in the invariant text. The invariants read as fully active from day one.
- [ ] Invariant `{N1}`'s text names `@honeydrunk/web-ui-tokens` and `@honeydrunk/web-ui-css` as the consumed package surface and names per-PDR CSS-variable overrides as the permitted divergence mechanism.
- [ ] Invariant `{N2}`'s text explicitly forbids a `studios/design-system` export shape and explicitly forbids folding Web.UI sources into Studios.
- [ ] Invariant `{N3}`'s text names the five Web.UI packages (`@honeydrunk/web-ui-tokens`, `@honeydrunk/web-ui-css`, `@honeydrunk/web-ui-react`, `HoneyDrunk.Web.UI.Blazor`, `@honeydrunk/web-ui-native`) and explicitly forbids any `HoneyDrunk.*` dependency in any of them. Names the consumer-side adapter as the correct location for any future Grid-canonical-value-type rendering.
- [ ] **All cross-reference targets updated in lockstep with the assigned numbers:** ADR-0071 Consequences §Invariants subsection, `repos/HoneyDrunk.Web.UI/invariants.md` trailing paragraph, and this initiative's packet 04 source file (pre-filing under invariant 24's carve-out).
- [ ] `adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md` Consequences §Invariants subsection has its preamble sentence replaced — "This ADR proposes (not commits…)" → "Assigned invariant numbers: **{N1}**…**{N2}**…**{N3}**…". The three bullet points remain unchanged.
- [ ] `repos/HoneyDrunk.Web.UI/invariants.md` trailing paragraph is updated to cite the three assigned numbers with brief parenthetical descriptions, naming ADR-0071 as the source.
- [ ] `constitution/invariant-reservations.md` ADR-0071 row moved from **Active Reservations** to **Reservation History** with the merge date.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section describing the invariant additions (not under `## Unreleased`).
- [ ] PR body explicitly notes: (1) three new invariants landed under a new `## Web.UI Invariants` section at block 87–89 (or shifted if reservation moved); (2) ADR-0071 Consequences finalized; (3) `repos/HoneyDrunk.Web.UI/invariants.md` cross-reference updated; (4) packet 04 source file was edited in place pre-filing to substitute the assigned numbers; (5) reservation row moved to History.
- [ ] Status of ADR-0071 stays `Proposed` in this packet's diff. No edit to the ADR header.

## Human Prerequisites

- [ ] Packet 01 of this initiative merged to `main` before this packet's PR is opened. Without that merge, `repos/HoneyDrunk.Web.UI/invariants.md` does not exist for the trailing-paragraph edit, and `constitution/sectors.md`'s Creator-sector anchor row is not in place for the cross-cite to be coherent.
- [ ] Confirm the assigned-number text in ADR-0071 Consequences matches the user's understanding of the three candidate invariants — both are mechanical text edits, but ADR Consequences edits warrant a quick eye before merge.

## Referenced Invariants

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — Packet 04 of this initiative cites the three invariant numbers this packet assigns. It must be amended in place pre-filing once this packet's PR merges and the actual assigned numbers are known. **Packets 02 and 04 cannot be filed in the same push.**

## Referenced ADR Decisions

**ADR-0071 §Invariants subsection:** Three candidate invariants nominated for promotion — the token-consumption rule, the Studios-not-host rule, and the zero-runtime-dependency rule. This packet performs the promotion. All three are definitive (none are conditional on first-feature-packet evidence).

**ADR-0071 D1 (Web.UI is the Creator sector's owner of design tokens, primitive CSS, and component contracts):** The token-consumption invariant `{N1}` is the cross-PDR enforcement of D1's ownership statement.

**ADR-0071 D3 (Web.UI is consumed by Studios — not folded into Studios):** The Studios-not-host invariant `{N2}` codifies D3 at the constitutional level.

**ADR-0071 D8 (Boundaries explicit):** The boundary text is design-time documentation; the constitutional invariants are the runtime-enforcement surface the review agent cites at PR time.

**ADR-0071 D9 (Dependencies and Grid-relationship discipline):** The zero-runtime-dependency invariant `{N3}` codifies D9 at the constitutional level. Names all five Web.UI packages and explicitly forbids any `HoneyDrunk.*` dependency in any of them.

## Dependencies

- `packet:01` — Architecture catalog registration. This packet edits `repos/HoneyDrunk.Web.UI/invariants.md` (created by packet 01) and assumes the Web.UI Node is registered in catalogs (so the constitutional invariant has a Node to refer to). Without packet 01 merged, the trailing-paragraph edit has no file to land in.

## Labels

`chore`, `tier-2`, `architecture`, `constitution`, `web-ui`, `adr-0071`

## Agent Handoff

**Objective:** Promote ADR-0071's three candidate invariants to numbered constitutional rules. Append a new `## Web.UI Invariants` section to `constitution/invariants.md` at block 87–89 (per the reservation registry). Substitute the assigned numbers across four cross-reference targets in lockstep. Move the ADR-0071 reservation row from Active to History. No `(Proposed)` qualifier on the new invariants — land them in final active form.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Land the three constitutional invariants ADR-0071 nominates so packet 04 of this initiative (the HoneyDrunk.Web.UI scaffold) can cite them by number, and so the review agent has citable rules for token-consumption enforcement, Studios-not-host enforcement, and zero-Grid-Node-runtime-dependency enforcement at every future PR.
- Feature: ADR-0071 standup initiative — this is the constitution side of Wave 1.
- ADRs: ADR-0071 (this packet finalizes its three candidate invariants).

**Acceptance Criteria:** As listed above.

**Dependencies:** `packet:01` (Architecture catalog registration) must be merged to `main` before this packet's PR is authored — that packet creates `repos/HoneyDrunk.Web.UI/invariants.md`, registers the Web.UI Node in catalogs, and writes the placeholder text the trailing paragraph update needs.

**Constraints:**

- **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — Packet 04 cites the three invariant numbers this packet assigns. It must be amended in place pre-filing once this packet's PR merges. **Packets 02 and 04 cannot be filed in the same push.**
- **The assignment is from the reservation registry — block 87–89 is the expected value.** Verify against `constitution/invariant-reservations.md` at edit time; if an earlier Proposed ADR's packet 00 landed in the interim, the block shifts up per the reservation discipline.
- **New section header — yes.** This is the first Creator-sector / Web.UI-related invariant set in the constitution, so a new `## Web.UI Invariants` header is required. Place it after the most-recent existing section to follow the file's existing sector-grouped organization.
- **Three invariants — all promoted.** All three are definitive per the ADR text; none are conditional on first-feature-packet evidence. Promote all three.
- **No `(Proposed)` or `(takes effect when ADR-0071 is accepted)` qualifier on the new invariants.** ADR-0071 will be Accepted (by post-merge housekeeping) once this initiative completes; the invariants read as fully active from day one. The standup ADR's "Done When" gate carries the qualifier semantics, not the constitutional text. **This is a deliberate departure from earlier drafts that included the qualifier — drop it.**

**Key Files:**
- `constitution/invariants.md` — append new `## Web.UI Invariants` section with the three new invariants
- `constitution/invariant-reservations.md` — move ADR-0071 row from Active Reservations to Reservation History
- `adrs/ADR-0071-stand-up-honeydrunk-web-ui-node.md` — Consequences §Invariants subsection preamble sentence (replace "This ADR proposes (not commits…)" with "Assigned invariant numbers: **{N1}**…**{N2}**…**{N3}**…")
- `repos/HoneyDrunk.Web.UI/invariants.md` — trailing cross-reference paragraph (substitute placeholders with assigned numbers)
- `CHANGELOG.md` — append entry under the current dated SemVer section

**Contracts:**
- This packet does not author any new contracts. It records the three constitutional rules. Authoring of the actual `DesignTokens` JSON schema, `TokensCssVariables` CSS file, and `PrimitiveCss` bundle happens in packet 04 (the scaffold).
