---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "constitution", "files", "adr-0061"]
dependencies: ["work-item:01"]
adrs: ["ADR-0061"]
accepts: ADR-0061
wave: 1
initiative: adr-0061-files-standup
node: honeydrunk-files
---

# Chore: Add ADR-0061's two new invariants to the Grid constitution

## Summary
Add two new invariants to `constitution/invariants.md` derived from ADR-0061's "New invariants" candidate list:

1. **`{N-domain-meaning}`** — The Files Node persists bytes and bytes-metadata, never domain meaning. The classification of *what a file means* lives in the consuming Node; Files knows the bytes, the size, the content type, the purpose-tag, the tenant, the classification, the upload timestamp, and the processing status — nothing more.
2. **`{N-download-shape}`** — Every download path through Files is either CDN-fronted public or a short-lived SAS issued after policy check. Forbids long-lived storage-account-shared-key URLs anywhere in the Grid.

Both are landed under a new `## Files Invariants` section appended to `constitution/invariants.md`. The numeric assignments (`{N-domain-meaning}` and `{N-download-shape}`) are made at edit time by the collision-check protocol below — at scoping time (2026-05-24) the high-water mark is **49** (the last `## Audit Invariants` entry), so do not use stale 50/51 defaults; assign the range from the reservation registry. The agent verifies this at edit time and substitutes the assigned numbers across every cross-reference target in lockstep.

This packet also updates ADR-0061's Consequences §New invariants subsection to finalize the numbers (replace the candidate-list framing with the assigned numbers) and updates `repos/HoneyDrunk.Files/invariants.md`'s trailing cross-reference paragraph to cite the assigned numbers.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0061's §New invariants subsection lists two candidate invariants for promotion at acceptance time:

> - **Candidate: "The Files Node never persists domain meaning, only bytes and bytes-metadata."** … Prevents Files from drifting into a half-baked content-management system.
> - **Candidate: "Every download path through Files is either CDN-fronted public or a short-lived SAS issued after policy check."** Forbids long-lived storage-account-shared-key URLs anywhere in the Grid.

A third candidate ("Restricted-tier image uploads must have EXIF stripped before becoming consumer-visible") is **conditional on first-feature-packet evidence** per the ADR's own text ("whether it warrants invariant-level promotion is a question best answered after the first real image upload pipeline runs"). This packet does **not** promote that third candidate — it lands the two definitive ones and leaves the EXIF rule as a documented design decision in `repos/HoneyDrunk.Files/invariants.md` (the local invariant set covers it as repo-local invariant 6, leaving room to promote to constitutional level later if the first feature packet shows the canary-test-enforced version is worth it).

The two invariants this packet lands need constitutional anchors for three reasons:

- **The downstream-coupling rule does not subsume them.** ADR-0061 D6 commits the boundary text ("What Files owns / does NOT own") — but the boundary text is design-time documentation. The constitutional invariants are *runtime rules the review agent can cite at PR time*. A future PR that quietly adds a domain-meaning field to `FileDescriptor` (e.g., `ContentDescription` or `AssetTitle`) is a boundary violation the review agent must catch — it needs a numbered rule to cite.
- **The signed-URL-only rule is grep-able and code-reviewable.** "Forbids long-lived storage-account-shared-key URLs anywhere in the Grid" is the kind of rule that surfaces only at PR review unless it lives in a numbered constitutional slot the reviewer agent can match against. The Files Node CI's contract-shape canary catches abstraction-shape drift; it cannot catch implementation drift of "did this PR introduce a shared-key URL pattern." The constitution is the right home.
- **They outlive ADR-0061's text.** The ADR is the design-decision record; the invariants are the enforcement surface. ADR-0016 (AI), ADR-0017 (Capabilities), ADR-0019 (Communications), ADR-0031 (Audit) all carry analogous constitutional invariants for the same reason.

## Reservation-Claim Protocol (Hard Gate, Run Before Any Edit)

This packet adds **two** invariants to `constitution/invariants.md`. Per the reservation discipline in `constitution/invariant-reservations.md`, packet 00 (the acceptance packet) of an ADR is normally where reservations land. ADR-0061 has no separate packet 00 — this packet 02 *is* the constitutional landing packet, so it claims the block here at the same time as it consumes it.

**Step 1 — claim the reservation block.** Open `constitution/invariant-reservations.md` and read the **Active Reservations** table. The next free range is at `max(accepted high-water in invariants.md, highest existing reservation) + 1`. As of scoping time (2026-05-24), the highest in-flight reservation before this packet is **64–66** (ADR-0060 Identity), and accepted high-water in `invariants.md` is **53** — so the next free block of size 2 is **{N1}–{N2} = 67–68**. **Verify at edit time** by re-reading the file; if another ADR's packet 00 landed an interim reservation, shift up by the appropriate offset.

Add a row to the **Active Reservations** table:

```
| {N1}–{N2} | ADR-0061 | Proposed | Files (`{N1}`–`{N2}`). Packet 02 at `generated/work-items/active/adr-0061-files-standup/02-architecture-files-invariants.md`. (N1) Files persists bytes + bytes-metadata, never domain meaning; (N2) every Files download is CDN-fronted public or short-lived SAS, never a long-lived shared-key URL. Block claimed at max(invariants.md=53, highest in-flight reservation=63) + 1. |
```

(Substitute the actual `{N1}` / `{N2}` values from the reservation lookup.)

**Step 2 — cross-check against `invariants.md`.** As defense-in-depth against a missed reservation, also run:

```bash
rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20
```

The numbers `{N1}` and `{N2}` must be **strictly greater** than every existing number returned by that grep. If `{N1}` is not greater than the accepted high-water in `invariants.md`, the reservation-file lookup was wrong — re-do step 1.

**Step 3 — substitute `{N1}` / `{N2}` throughout this packet.** Every occurrence of `{N1}`, `{N2}`, `{N-domain-meaning}`, and `{N-download-shape}` in this packet's body and in the cross-reference target files (listed below) is replaced with the assigned numbers in lockstep before commit.

**Known existing claims as of scoping time (2026-05-24):**

| Range | Owner ADR | Section | Status |
|---|---|---|---|
| 47 / 48 / 49 | **ADR-0030 + ADR-0031** (audit substrate + Audit standup) | `## Audit Invariants` | **Landed** — visible in `constitution/invariants.md` at scoping time |
| 50–53 | various (Testing, Code Review extended) | various | **Landed** — accepted high-water at scoping is 53 |
| 54–57 | ADR-0051 (Agent authorization) | Reservation | In-flight reservation |
| 58–60 | ADR-0049 (Data classification) | Reservation | In-flight reservation |
| 61–63 | ADR-0054 (Incident response) | Reservation | In-flight reservation |
| 64–66 | ADR-0060 (Identity) | Reservation | In-flight reservation |
| {N1}–{N2} (expected 67–68) | **This packet** (ADR-0061 standup) | `## Files Invariants` (new section) | This packet claims |

**Filing-order rule (hard, enforced by `dependencies:` frontmatter):**

This packet depends on `work-item:01` (Architecture catalog registration). Packet 01 must merge first so that `repos/HoneyDrunk.Files/invariants.md` exists on disk for this packet to update (the cross-reference paragraph at the bottom of that file references `{N-domain-meaning}` and `{N-download-shape}` placeholders and needs in-place substitution to the assigned numbers).

**Cross-references to update with the assigned numbers (in lockstep, before commit):**

- `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` — Consequences §New invariants subsection (see implementation block below).
- `repos/HoneyDrunk.Files/invariants.md` — trailing cross-reference paragraph (placeholder text written by packet 01).
- `04-files-node-scaffold.md` source file (this initiative's packet 04) — its acceptance criteria, constraints, and Referenced-Invariants sections currently use `{N-domain-meaning}` and `{N-download-shape}` placeholders for the two assigned numbers. Substitute the assigned numbers in place pre-push under invariant 24's pre-filing carve-out. **Packets 02 and 04 cannot be filed in the same push** because packet 04's placeholders depend on packet 02's actual assignment.

## Proposed Implementation

### `constitution/invariants.md` — append a new `## Files Invariants` section

Append at the end of the file (after the `## Audit Invariants` section). The agent must verify that no `## Files Invariants` section already exists (it does not at scoping time; confirm at edit time).

The new section structure:

```markdown
## Files Invariants

{N-domain-meaning}. **The Files Node persists bytes and bytes-metadata, never domain meaning.**
    The classification of *what a file means* lives in the consuming Node. Files knows the bytes, the size, the content type, the purpose-tag (`avatar` / `journal-media` / `attachment` / etc.), the tenant, the classification tier, the upload timestamp, the processing status, and the soft-delete state — nothing more. Domain-meaning fields (`ContentDescription`, `AssetTitle`, `RelatedEntityId`, etc.) belong on the consumer's record, with the consumer holding the `file_id` reference. A Files-side metadata field that requires the consumer to mean something specific by it is a boundary violation. The review agent rejects additions to `FileDescriptor` (or any package surface in `HoneyDrunk.Files.Abstractions`) that encode domain meaning rather than byte-metadata. See ADR-0061 D6 and the §New invariants subsection.

{N-download-shape}. **Every download path through Files is either CDN-fronted public or a short-lived SAS issued after policy check.**
    Public assets (avatars, published photos, public Studios assets) are served through Azure Front Door / CDN at unauthenticated URLs with permissive cache headers, versioned by `file_id` so a derivative regeneration produces a new URL the CDN naturally invalidates. Private assets are served via short-lived read-scoped SAS issued by `IFileStore.GetDownloadUrl(file_id, ttl)` — default TTL 15 minutes; maximum TTL 4 hours; never CDN-cached. **Long-lived storage-account-shared-key URLs are forbidden anywhere in the Grid.** The shape of every Files download is auditable from this rule alone. A PR that introduces a shared-key URL pattern (`?sv=...&sig=...` with a multi-day expiry, a static SAS embedded in code or configuration, or a backing-direct URL bypassing `IFileStore.GetDownloadUrl`) is rejected by review. See ADR-0061 D7 / D8.
```

The agent substitutes the actual assigned numbers (e.g., `50.` and `51.` if no other invariant landed in the interim) at edit time. The Markdown numbering treats these as ordered-list items — the literal numbers must be in the source.

### `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` — finalize the invariant numbers in Consequences

In ADR-0061's Consequences section, the §New invariants subsection (lines 452-459) currently opens with:

> `Two candidate invariants are nominated for promotion at acceptance time. The scope agent assigns final invariant numbers when the ADR flips to Accepted:`

Followed by two bullet points (the domain-meaning candidate and the download-shape candidate), then a third paragraph about the conditional EXIF-strip candidate.

Replace the opening sentence so the subsection reads (substitute the actual assigned numbers):

> `Assigned invariant numbers: **{N-domain-meaning}** (Files persists bytes + bytes-metadata, not domain meaning) and **{N-download-shape}** (every Files download is CDN-fronted public or short-lived SAS). See \`constitution/invariants.md\`, \`## Files Invariants\`. Both landed by ADR-0061's stand-up initiative (packet 02).`

Leave the two bullet points unchanged. Leave the third paragraph (the conditional EXIF-strip candidate) unchanged — that one stays a documented design decision pending first-feature-packet evidence.

### `repos/HoneyDrunk.Files/invariants.md` — update the trailing cross-reference

Packet 01 of this initiative writes a trailing cross-reference paragraph using `{N-domain-meaning}` and `{N-download-shape}` placeholders. The exact text (per packet 01's implementation block) is:

> `_Constitutional invariants {N-domain-meaning} (Files persists bytes only, not domain meaning) and {N-download-shape} (every Files download is CDN-fronted public or short-lived SAS) in \`constitution/invariants.md\` are the Grid-level rules this Node exists to enforce. Both are landed by ADR-0061's stand-up initiative (packet 02). The numeric assignments are made at packet 02's edit time via the collision-check protocol._`

This packet substitutes the placeholders with the assigned numbers. The replacement text:

> `_Constitutional invariants {assigned-N-domain-meaning} (Files persists bytes only, not domain meaning) and {assigned-N-download-shape} (every Files download is CDN-fronted public or short-lived SAS) in \`constitution/invariants.md\` are the Grid-level rules this Node exists to enforce. Both landed by ADR-0061's stand-up initiative (packet 02 — this packet)._`

(Substitute the actual numeric assignments.)

### `CHANGELOG.md` (Architecture repo)

Append to the current in-progress dated SemVer section (per memory `feedback_no_unreleased_commits`):

`Architecture: Add new ## Files Invariants section with invariants {N-domain-meaning} (Files persists bytes and bytes-metadata, never domain meaning — review rejects domain-meaning additions to FileDescriptor or any HoneyDrunk.Files.Abstractions surface) and {N-download-shape} (every Files download is CDN-fronted public or short-lived SAS; long-lived storage-account-shared-key URLs forbidden Grid-wide) per ADR-0061 §New invariants. Finalizes the invariant numbers in ADR-0061 Consequences (replaces the candidate-list framing with assigned numbers). Updates repos/HoneyDrunk.Files/invariants.md trailing cross-reference. The conditional EXIF-strip candidate from ADR-0061 stays a documented design decision pending first-feature-packet evidence — repo-local invariant 6 in repos/HoneyDrunk.Files/invariants.md covers it for now.`

## Affected Files

- `constitution/invariants.md` (append new `## Files Invariants` section with 2 invariants)
- `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` (Consequences §New invariants subsection — finalize numbers)
- `repos/HoneyDrunk.Files/invariants.md` (trailing cross-reference paragraph — substitute placeholders with assigned numbers)
- `CHANGELOG.md` (entry under the current dated SemVer-bumped section)

## NuGet Dependencies
None. Architecture is a knowledge repo — no .NET projects.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture` — correct repo per routing rules.
- [x] No new design decision — invariant text is taken from ADR-0061 §New invariants with light wordsmithing for the constitution's voice.
- [x] No double-numbering — the agent runs the collision-check protocol at edit time and uses the next two free slots after the current high-water mark.
- [x] No edit to ADR-0061's Status header. Status stays Proposed; the flip is post-merge housekeeping.

## Acceptance Criteria

- [ ] **Collision check performed at edit time** using `rg -n '^[0-9]+\.' constitution/invariants.md | tail -n 20`. The actual assigned numbers are recorded in the PR body and substituted into every cross-reference target. **Hardcoding 50/51 is forbidden because those slots are already accepted/reserved in current Architecture; use only the reservation-registry assigned numbers at edit time** — if another invariant-numbering packet landed between this scoping and this packet's edit, the assignments shift.
- [ ] `constitution/invariants.md` carries a new `## Files Invariants` section appended after the existing `## Audit Invariants` section.
- [ ] The new section carries exactly two invariants at the assigned monotonic numbers: `{N-domain-meaning}` (Files persists bytes + bytes-metadata only — naming `FileDescriptor` and `HoneyDrunk.Files.Abstractions` as the boundary surface) and `{N-download-shape}` (CDN-fronted public OR short-lived SAS; long-lived shared-key URLs forbidden).
- [ ] Invariant `{N-domain-meaning}`'s text names `purpose-tag`, `tenant`, `classification tier`, `upload timestamp`, `processing status`, and `soft-delete state` as the allowed Files-side metadata fields, and names domain-meaning fields (`ContentDescription`, `AssetTitle`, `RelatedEntityId`) as forbidden Files-side additions.
- [ ] Invariant `{N-download-shape}`'s text names the 15-minute default TTL and 4-hour maximum TTL for SAS-based downloads, the `?sv=...&sig=...` long-expiry pattern as a forbidden code addition, and `IFileStore.GetDownloadUrl` as the only valid download-URL minting site.
- [ ] **All cross-reference targets updated in lockstep with the assigned numbers:** ADR-0061 Consequences §New invariants subsection, `repos/HoneyDrunk.Files/invariants.md` trailing paragraph, and this initiative's packet 04 source file (pre-filing under invariant 24's carve-out).
- [ ] `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` Consequences §New invariants subsection has its preamble sentence replaced — "Two candidate invariants are nominated…" → "Assigned invariant numbers: **{N-domain-meaning}**…**{N-download-shape}**…". The two bullet points and the third paragraph (the conditional EXIF candidate) remain unchanged.
- [ ] `repos/HoneyDrunk.Files/invariants.md` trailing paragraph is updated to cite the two assigned numbers with brief parenthetical descriptions, naming ADR-0061 as the source of both.
- [ ] `CHANGELOG.md` carries an entry under the current dated SemVer section describing the invariant additions (not under `## Unreleased`).
- [ ] PR body explicitly notes: (1) two new invariants landed under a new `## Files Invariants` section at the next two free slots after the collision check; (2) ADR-0061 Consequences finalized; (3) `repos/HoneyDrunk.Files/invariants.md` cross-reference updated; (4) packet 04 source file was edited in place pre-filing to substitute the assigned numbers.
- [ ] Status of ADR-0061 stays `Proposed` in this packet's diff. No edit to the ADR header.

## Human Prerequisites
- [ ] Packet 01 of this initiative merged to `main` before this packet's PR is opened. Without that merge, `repos/HoneyDrunk.Files/invariants.md` does not exist for the trailing-paragraph edit, and `constitution/sectors.md`'s Files row is not in place for the cross-cite to be coherent.
- [ ] Confirm the assigned-number text in ADR-0061 Consequences matches the user's understanding of the two candidate invariants — both are mechanical text edits, but ADR Consequences edits warrant a quick eye before merge.

## Referenced Invariants

> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — Packet 04 of this initiative cites the two invariant numbers this packet assigns. It must be amended in place pre-filing once this packet's PR merges and the actual assigned numbers are known. **Packets 02 and 04 cannot be filed in the same push.**

## Referenced ADR Decisions

**ADR-0061 §New invariants:** Two candidate invariants nominated for promotion — the Files-Node-never-persists-domain-meaning rule and the every-download-is-CDN-or-SAS rule. This packet performs the promotion. The third candidate (Restricted-tier image EXIF-strip) stays a documented design decision per the ADR's own "conditional on first-feature-packet evidence" qualifier.

**ADR-0061 D6 (Boundaries):** "What Files Owns / What Files Does NOT Own" — the design-time documentation. The new constitutional invariants are the *runtime enforcement* surface the review agent cites at PR time.

**ADR-0061 D7 (Upload flow):** Signed-URL direct-to-blob upload. The API never proxies bytes. SAS is write-scoped, 15-minute TTL default, content-type pin, max content length = declared_size + 5% slack. The new download-shape invariant is the read-side counterpart.

**ADR-0061 D8 (Public vs. private):** Metadata-driven distinction. Public CDN-fronted (unauthenticated, permissive cache, versioned by `file_id`); private short-lived SAS (15-min default, 4-hour max, never CDN-cached). No long-lived shared-key URLs. The new download-shape invariant restates this as a Grid-wide constitutional rule.

## Dependencies

- `work-item:01` — Architecture catalog registration. This packet edits `repos/HoneyDrunk.Files/invariants.md` (created by packet 01) and assumes the Files Node is registered in catalogs (so the constitutional invariant has a Node to refer to). Without packet 01 merged, the trailing-paragraph edit has no file to land in.

## Labels

`chore`, `tier-2`, `architecture`, `constitution`, `files`, `adr-0061`

## Agent Handoff

**Objective:** Promote ADR-0061's two definitive candidate invariants to numbered constitutional rules. Append a new `## Files Invariants` section to `constitution/invariants.md`. Substitute the assigned numbers across three cross-reference targets in lockstep. Do not promote the conditional EXIF-strip candidate (it stays a documented design decision per the ADR's own qualifier).

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: Land the two constitutional invariants ADR-0061 nominates so packet 04 of this initiative (the HoneyDrunk.Files scaffold) can cite them by number, and so the review agent has citable rules for domain-meaning-boundary and download-shape enforcement at every future PR.
- Feature: ADR-0061 standup initiative — this is the constitution side of Wave 1.
- ADRs: ADR-0061 (this packet finalizes its two candidate invariants).

**Acceptance Criteria:** As listed above.

**Dependencies:** `work-item:01` (Architecture catalog registration) must be merged to `main` before this packet's PR is authored — that packet creates `repos/HoneyDrunk.Files/invariants.md`, registers the Files Node in catalogs, and writes the placeholder text the trailing paragraph update needs.

**Constraints:**

- **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Pre-filing amendments are permitted; post-filing corrections require a new packet. — Packet 04 cites the two invariant numbers this packet assigns. It must be amended in place pre-filing once this packet's PR merges. **Packets 02 and 04 cannot be filed in the same push.**
- **The assignment is dynamic — do NOT hardcode 50/51 without verifying.** Run the collision-check `rg` command at edit time. The accepted high-water and active reservations have moved beyond 50/51; take the assigned numbers only from `constitution/invariant-reservations.md` at edit time.
- **New section header — yes.** This is the first Files-sector invariant set in the constitution, so a new `## Files Invariants` header is required. Place it after `## Audit Invariants` to follow the file's existing sector-grouped organization.
- **Two invariants only.** The conditional EXIF-strip candidate stays a design decision in `repos/HoneyDrunk.Files/invariants.md` (covered as repo-local invariant 6). Do not promote it here — the ADR's own qualifier says it's "best answered after the first real image upload pipeline runs."
- **No `(Proposed)` qualifier on the new invariants.** ADR-0061 will be Accepted (by post-merge housekeeping) once this initiative completes; the invariants read as fully active from day one. The standup ADR's "Done When" gate carries the qualifier semantics, not the constitutional text.

**Key Files:**
- `constitution/invariants.md` — append new `## Files Invariants` section with the two new invariants
- `adrs/ADR-0061-stand-up-honeydrunk-files-node.md` — Consequences §New invariants subsection preamble sentence (replace "Two candidate invariants are nominated…" with "Assigned invariant numbers: **{N-domain-meaning}**…**{N-download-shape}**…")
- `repos/HoneyDrunk.Files/invariants.md` — trailing cross-reference paragraph (substitute placeholders with assigned numbers)
- `CHANGELOG.md` — append entry under the current dated SemVer section

**Contracts:**
- This packet does not author any new contracts. It records the two constitutional rules. Authoring of the actual `.cs` files (`IFileStore`, `IFileUploadSession`, etc.) happens in packet 04 (the scaffold).
