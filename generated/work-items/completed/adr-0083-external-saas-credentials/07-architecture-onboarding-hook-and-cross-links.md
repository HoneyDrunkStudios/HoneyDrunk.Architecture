---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "meta", "docs", "adr-0083", "wave-3"]
dependencies: ["work-item:01"]
external_dependencies: ["HoneyDrunkStudios/HoneyDrunk.Architecture#{adr-0084-packet-07-issue-number}"]
adrs: ["ADR-0083", "ADR-0082", "ADR-0084", "ADR-0006"]
wave: 3
initiative: adr-0083-external-saas-credentials
node: honeydrunk-architecture
---

<!-- Operator: fill in the real ADR-0084 packet 07 issue number in `external_dependencies` once ADR-0084 has been
     filed. This packet and ADR-0084 packet 07 both amend the SAME onboarding-hook section of
     `constitution/node-standup.md`. Per the cross-initiative ordering constraint in the dispatch plan, ADR-0084
     is promoted first and its packet 07 lands first; this packet then rebases against the merged state and
     inserts its external-credential-onboarding step adjacent to (not replacing) ADR-0084's operator-alert
     routing step. -->


# Amend `constitution/node-standup.md` for D6 onboarding hook + cross-link Vault.Rotation overview and vendor-inventory

## Summary
Three governance edits that complete the ADR-0083 rollout: (1) amend `constitution/node-standup.md` (the canonical procedure document landed by ADR-0082) to add the sensitive-inventory onboarding step per ADR-0083 D6; (2) add a cross-link to `repos/HoneyDrunk.Vault.Rotation/overview.md` noting that external-SaaS PAT rotation is deliberately out of scope per ADR-0083 D1; (3) update `infrastructure/reference/vendor-inventory.md` to cross-link `sensitive-inventory.md` for each vendor whose artifacts the Grid holds.

**Cross-initiative amendment coordination.** This packet and ADR-0084 packet 07 (the D10 operator-alert-routing-step amendment) both amend the SAME onboarding-hook section of `constitution/node-standup.md`. Per the cross-initiative ordering constraint, ADR-0084 packet 07 lands first; this packet rebases against the merged state and inserts the sensitive-inventory onboarding step **adjacent to** (not replacing) ADR-0084's operator-alert-routing step. The two steps live side-by-side in the standup procedure — both attach as parallel sub-steps of D4's mandatory step set or D5's class-specific step set, in whichever structural position the canonical procedure landed in ADR-0082 packet 01.

## Context

ADR-0083 D6 commits the onboarding hook:

> When a new external-SaaS provider is adopted — Stripe per PDR-0002, Resend / Twilio per ADR-0073, any future SaaS the Grid integrates with — the **standup procedure per ADR-0082** gains a credential-onboarding step.
>
> Specifically, ADR-0082 D5 (the class-specific steps) is extended with a new mandatory step for any Node whose standup introduces a new external-SaaS provider or a new sensitive-inventory artifact:
>
> > **Sensitive-inventory onboarding.** If the Node's standup introduces any artifact governed by ADR-0083's inventory (an external-SaaS credential, a non-rotating identifier, a webhook signing secret, an OIDC federated-credential configuration, a resource identifier, or any other entry in the D2 `Kind` taxonomy) that does not already appear in `infrastructure/reference/sensitive-inventory.md`, the standup packet must, before the artifact enters any CI surface or workflow file:
> >
> > 1. Add a row to `infrastructure/reference/sensitive-inventory.md` per ADR-0083 D2, including the `Kind`, `Use Cases`, and `Rotates` columns.
> > 2. If `Rotates: yes`: land the per-provider rotation walkthrough under `infrastructure/walkthroughs/{provider}-{credential}-rotation.md` per ADR-0083 D4 and open the initial standing rotation issue with the `external-credential-rotation` label per ADR-0083 D3.
> > 3. If `Rotates: yes`: verify the artifact's `Current Expiration` date is picked up by `external-credentials-check.yml` on its next scheduled run.
> > 4. If `Rotates: no` or `Rotates: automated-elsewhere`: no walkthrough or standing issue is required — the inventory row itself is the deliverable.
>
> This step lands as an amendment to ADR-0082's D5 in the same packet that lands `constitution/node-standup.md` per ADR-0082's D7 follow-up work. The cross-reference is recorded here; ADR-0082's text is not edited directly (Accepted-ADR discipline), but its follow-up document — the canonical procedure — picks up this step.

This packet edits `constitution/node-standup.md` directly. **The ADR-0082 ADR body is not edited** — per Accepted-ADR discipline, ADRs are not amended in place after acceptance. The canonical procedure document is the live surface; this packet adds the step there.

ADR-0083 §Follow-up Work also commits two cross-link edits:

> **Cross-reference this ADR from `HoneyDrunk.Vault.Rotation/overview.md`** — note that external-SaaS PAT rotation is deliberately out of scope, governed by ADR-0083, and that the sensitive inventory carries a summary row for the Vault contents that Vault.Rotation governs.
>
> **Update `infrastructure/reference/vendor-inventory.md`** to cross-link to `sensitive-inventory.md` for each vendor whose artifacts the Grid holds.

The Vault.Rotation overview lives in `repos/HoneyDrunk.Vault.Rotation/overview.md` inside `HoneyDrunk.Architecture` (the Architecture-owned mirror of each Node's overview); the cross-link edit stays in the Architecture repo, not in the Vault.Rotation repo itself. Per ADR-0083 §Affected Nodes, Vault.Rotation is **explicitly unchanged** — only its Architecture-side overview gets the documentation cross-link.

This is a docs/governance packet. No code, no .NET project.

## Scope
- **Edit 1:** `constitution/node-standup.md` — add the new step per ADR-0083 D6 into the appropriate location in the procedure (the class-specific steps section, matching ADR-0082 D5's structure).
- **Edit 2:** `repos/HoneyDrunk.Vault.Rotation/overview.md` — add a one-paragraph cross-reference noting that external-SaaS PAT rotation is out of scope per ADR-0083 D1, and that `infrastructure/reference/sensitive-inventory.md` carries a summary row for the Vault contents Vault.Rotation governs.
- **Edit 3:** `infrastructure/reference/vendor-inventory.md` — for each vendor row whose artifacts appear in `sensitive-inventory.md`, add a cross-link to the relevant inventory section. The shape of the cross-link is determined by the existing `vendor-inventory.md` format; match it.

## Proposed Implementation

### Edit 1 — `constitution/node-standup.md`

Open `constitution/node-standup.md` and locate the class-specific steps section (the part that mirrors ADR-0082 D5). Add a new mandatory step with the exact text from ADR-0083 D6 quoted above (the four-numbered-substeps block). The placement convention:

- If the document is organized by Node-class (library / deployable / sector-specific), add the step under each class that could conceivably introduce a new sensitive-inventory artifact. Most likely all classes need the step — even library-only Nodes occasionally introduce a webhook secret or an OIDC federated credential.
- If the document uses a single shared "every standup must" section, add the step there.

Match the existing document's style. Cite ADR-0083 D6 as the governing decision and link to `infrastructure/reference/sensitive-inventory.md`, the four-numbered substeps, and `infrastructure/walkthroughs/` for the walkthrough convention.

**Do not edit `adrs/ADR-0082-*.md`.** Per Accepted-ADR discipline (and explicit per ADR-0083 D6: "ADR-0082's text is not edited directly"), the ADR body is left untouched. The canonical procedure document is the live surface.

### Edit 2 — `repos/HoneyDrunk.Vault.Rotation/overview.md`

Open `repos/HoneyDrunk.Vault.Rotation/overview.md`. Find an appropriate location (the "Scope" or "Boundary" section is typical; if neither exists, add a new "Cross-references" or "Out of scope" section at the end). Add a paragraph like:

> **External-SaaS PAT rotation is out of scope of Vault.Rotation.**
>
> Per ADR-0083 D1, credentials that live as GitHub organization secrets (`SONAR_TOKEN`, `NUGET_API_KEY`, `GH_ISSUE_TOKEN`, the OpenClaw webhook signing secret, the imminent Stripe / Resend / Twilio API keys before their post-issuance writes into `kv-hd-notify-{env}`, etc.) are rotated **manually** per the per-provider walkthroughs under `HoneyDrunk.Architecture`'s `infrastructure/walkthroughs/`. Vault.Rotation handles only the **post-issuance** rotation of secrets stored in Azure Key Vault per ADR-0006 Tier 2.
>
> The full inventory of credentials the Grid holds — Vault-stored and external-SaaS alike — lives at [`infrastructure/reference/sensitive-inventory.md`](../../infrastructure/reference/sensitive-inventory.md) in `HoneyDrunk.Architecture`. The Vault contents Vault.Rotation governs appear there as a single summary row (`Kind: azure-key-vault-secret`, `Rotates: automated-elsewhere (ADR-0006)`); the per-secret detail lives in the Vault inventory ADR-0006 owns.

The exact wording may be adjusted to match the overview's voice; the load-bearing facts are:
1. External-SaaS PAT rotation is **not** Vault.Rotation's job.
2. ADR-0083 is the governing ADR; the inventory file is the canonical index.
3. Vault contents appear in the sensitive-inventory as a single summary row, not per-secret.

### Edit 3 — `infrastructure/reference/vendor-inventory.md`

Open `infrastructure/reference/vendor-inventory.md` and read its existing format. For each vendor whose artifacts appear in `sensitive-inventory.md`, add a cross-link cell or footnote pointing at the sensitive-inventory row(s) for that vendor.

The cross-link must be **product-level → artifact-level**, per ADR-0083 §Cascade Impact:

> `infrastructure/reference/vendor-inventory.md` is **not edited** by this ADR — vendor inventory is product-level ("which SaaS products do we use"); the sensitive inventory is artifact-level ("which credentials, identifiers, and identity bindings do we hold against each product, plus everything else load-bearing"). The two files cross-reference each other.

The ADR's "is not edited by this ADR" phrasing means **the structural content** of `vendor-inventory.md` is not changed — what is added here is the cross-link metadata, which is a structural-no-op addition (a footer line, a column addition, a Notes-cell update — whichever matches the existing format). Specifically:

- For each vendor in `vendor-inventory.md` that has an inventory row in `sensitive-inventory.md` (SonarCloud, NuGet, GitHub, Azure, Anthropic, OpenAI — plus the imminent Stripe / Resend / Twilio when their rows land per PDR-0002 / ADR-0073 / ADR-0084), add a cross-link to the relevant section in `sensitive-inventory.md`. The simplest form is a "See sensitive inventory for credentials, identifiers, and identity bindings: [link]" footer line per vendor; the alternative is a "Sensitive Inventory" column added to the table.
- Pick the form that minimizes disruption to the existing file. The footer-line-per-vendor form is the safer default.

## Affected Files
- `constitution/node-standup.md`
- `repos/HoneyDrunk.Vault.Rotation/overview.md`
- `infrastructure/reference/vendor-inventory.md`
- `CHANGELOG.md` (append to in-progress entry; no version bump)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. The Vault.Rotation overview lives in Architecture's `repos/` mirror, not in the Vault.Rotation repo itself — no edits to the Vault.Rotation repo.
- [x] No code change in any other repo.
- [x] No edits to `adrs/ADR-0082-*.md` (Accepted-ADR discipline; the canonical procedure document is the live surface).
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] `constitution/node-standup.md` contains the new mandatory step from ADR-0083 D6, with the four-numbered-substeps block, in the appropriate location matching the document's existing structure
- [ ] The new step cites ADR-0083 D6 as the governing decision and links to `infrastructure/reference/sensitive-inventory.md` and `infrastructure/walkthroughs/`
- [ ] `adrs/ADR-0082-*.md` is **not** edited (Accepted-ADR discipline preserved)
- [ ] `repos/HoneyDrunk.Vault.Rotation/overview.md` contains a one-paragraph cross-reference noting that external-SaaS PAT rotation is out of scope per ADR-0083 D1, with the three load-bearing facts (external-SaaS rotation is not Vault.Rotation's job; ADR-0083 is the governing ADR; Vault contents appear as a single summary row in the sensitive-inventory)
- [ ] `infrastructure/reference/vendor-inventory.md` contains cross-links from each vendor whose artifacts appear in `sensitive-inventory.md` (today: SonarCloud, NuGet, GitHub, Azure, Anthropic, OpenAI) to the relevant inventory row(s) or section
- [ ] The cross-link form in `vendor-inventory.md` matches the existing file's format conventions (footer-line-per-vendor or column-addition — whichever minimizes structural disruption)
- [ ] No changes to the **structural content** of `vendor-inventory.md` beyond cross-link metadata addition (ADR-0083 §Cascade Impact compliance)
- [ ] No edits to `HoneyDrunk.Vault.Rotation` repo (only the Architecture-side overview mirror)
- [ ] Repo-level `CHANGELOG.md` appends to the in-progress entry (no version bump)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0083 D6 — Onboarding hook.** ADR-0082 D5's standup-procedure document gains a credential-onboarding step. Inventory row exists before the artifact enters any CI surface. The procedural enforcement is the `review` agent per ADR-0044 D3 rubric category 9 (Security). Procedural rule: any PR introducing a workflow consuming a new GitHub org secret, repo secret, or environment variable without a matching inventory row is a `Request Changes` finding.

**ADR-0083 §Follow-up Work — Vault.Rotation overview cross-link.** Documentation-only cross-reference; Vault.Rotation's scope per ADR-0006 Tier 2 stays as-is. The cross-link makes the boundary discoverable from the Vault.Rotation overview without expanding its scope.

**ADR-0083 §Follow-up Work — vendor-inventory cross-links.** Product-level vendor-inventory and artifact-level sensitive-inventory cross-reference each other.

**ADR-0083 §Cascade Impact — `vendor-inventory.md` is "not edited" structurally.** The cross-link addition is metadata, not structural content. ADR-0083 explicitly preserves the existing vendor-inventory's product-level shape.

**ADR-0082 — Standup procedure.** The canonical procedure document is `constitution/node-standup.md`. ADRs are not edited in place after acceptance; the live procedure document is amended directly.

**ADR-0006 — Vault.Rotation Tier 2 scope.** Unchanged. The cross-link from Vault.Rotation overview points outward to ADR-0083; ADR-0006 itself does not require an edit.

**ADR-0044 D3 rubric category 9 (Security).** The procedural enforcement surface for the new invariant 103 per packet 00. The `review` agent flags PRs introducing a workflow consuming a new secret without a matching inventory row as `Request Changes`. This is a behavioral enforcement, not a packet-shipped enforcement — out of scope for this packet but cited here for the operator's reference.

## Constraints
- **Do not edit `adrs/ADR-0082-*.md`.** Accepted-ADR discipline. The live procedure document is the surface; the ADR text is left untouched. ADR-0083 D6 makes this requirement explicit.
- **Do not edit any file in the `HoneyDrunk.Vault.Rotation` repo.** Per ADR-0083 §Affected Nodes: "explicitly unchanged." The Architecture-side overview mirror at `repos/HoneyDrunk.Vault.Rotation/overview.md` is the cross-link surface; the Vault.Rotation repo itself does not change.
- **`vendor-inventory.md` edit is metadata-only.** Per ADR-0083 §Cascade Impact: the file's structural content is not changed; only cross-link metadata is added. Use the footer-line-per-vendor form unless a column-addition is clearly cleaner against the existing format.
- **Do not add the step to ADR-0082's body.** The amendment lives in the procedure document, not in the ADR. ADR-0083 D6 is explicit.
- **The four-numbered substeps must appear verbatim** (or with minor formatting adjustments to match `constitution/node-standup.md`'s house style) in the standup-procedure edit. The substeps are load-bearing; paraphrasing risks dropping the "before the artifact enters any CI surface" gating clause.

## Labels
`chore`, `tier-2`, `meta`, `docs`, `adr-0083`, `wave-3`

## Agent Handoff

**Objective:** Three governance edits that complete the ADR-0083 rollout: the D6 onboarding hook in the standup procedure, the Vault.Rotation overview cross-link, and the vendor-inventory cross-links.

**Target:** `HoneyDrunk.Architecture`, branch from `main` after packet 01 has merged.

**Context:**
- Goal: Close the door on new external-SaaS providers landing without their inventory row first (PDR-0002, ADR-0073, ADR-0084), and make the ADR-0083 / Vault.Rotation scope boundary discoverable from each side.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 3.
- ADRs: ADR-0083 D6 (onboarding hook), §Follow-up Work (cross-links), §Cascade Impact (vendor-inventory metadata-only edit); ADR-0082 (standup-procedure document home); ADR-0006 (Vault.Rotation Tier 2 scope, unchanged); ADR-0044 D3 category 9 (review-agent enforcement surface, cited for context).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 (inventory file must exist for the cross-links to point at).

**Constraints:**
- Do not edit `adrs/ADR-0082-*.md` (Accepted-ADR discipline).
- Do not edit any file in the `HoneyDrunk.Vault.Rotation` repo (Vault.Rotation explicitly unchanged).
- `vendor-inventory.md` edit is metadata-only — no structural-content change.
- Do not add the D6 step to ADR-0082's body — amendment lives in the procedure document.
- The four-numbered substeps appear verbatim (or with house-style formatting) in the standup-procedure edit.

**Key Files:**
- `constitution/node-standup.md`
- `repos/HoneyDrunk.Vault.Rotation/overview.md`
- `infrastructure/reference/vendor-inventory.md`
- `CHANGELOG.md`

**Contracts:** None changed.

**PR Body Metadata:**
- `Authorship: agent`
- `Work Item: generated/work-items/proposed/adr-0083-external-saas-credentials/07-architecture-onboarding-hook-and-cross-links.md`
