---
name: Constitution Update
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-2", "architecture", "ops", "adr-0027", "constitution"]
dependencies: ["work-item:01"]
adrs: ["ADR-0027"]
accepts: ADR-0027
wave: 1
initiative: adr-0027-notify-cloud-standup
node: honeydrunk-notify-cloud
---

# Chore: Add ADR-0027's six new invariants to the Grid constitution

## Summary
Add six new invariants to `constitution/invariants.md` derived from ADR-0027's Consequences section: D2 (repo public-default + revenue carve-out), D5 (hot delivery path goes through Communications), D6 (SDK lives in open Notify repo), D4+D12 (API keys stored as salted hashes; raw key returned exactly once), D8 (Notify Cloud contract-shape canary), D11 (FSL on open engine repos with two-year Apache 2.0 conversion).

Assign the six new entries to the **next six free numbers** after the file's current highest at edit time. As of 2026-05-20 the file's highest assigned number visible in the published constitution is **46** (ADR-0016 AI canary). Several parallel standup initiatives also claim invariant slots that may or may not have landed by the time this packet executes:

- **ADR-0016 (AI)** — claims 44/45/46 (already landed as of 2026-05-20).
- **ADR-0017 (Capabilities)** — claims 47/48/49/50.
- **ADR-0021 (Knowledge)** — pre-claims 55/56/57/58/59 in its "If Accepted" section. **This is a direct overlap with this packet's default 55/56 claims.** The two ADRs (Knowledge and Notify Cloud) are both Proposed and their ordering at acceptance is unknown.

Default-assumption text in this packet uses **51-56** under the conservative assumption that ADR-0016's three invariants land at 44/45/46, ADR-0017's four invariants land at 47/48/49/50, and ADR-0021 has NOT landed first. If ADR-0021 lands first and claims 55/56/57/58/59, this packet must claim 60/61/62/63/64/65 (or the next free run after ADR-0017's block, depending on what else has landed). **Collision-check at edit time is a hard gate** — never just trust the 51-56 default; always verify against the live constitution file before editing.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
ADR-0027 explicitly delegates final invariant numbering to the scope agent at acceptance time. The six invariants the ADR proposes (in its "New invariants" section under Consequences, lines 257-263 of the ADR file) need to land in `constitution/invariants.md` so:

- The contract-shape canary in packet 06 has a numbered, citable rule to reference.
- The FSL LICENSE application packets (03 and 04) have a numbered rule to reference.
- The private-repo carve-out (D2) has a Grid-wide constitutional record, not just an ADR-text justification.
- The API-key-handling discipline (D4 + D12) is a constitutional rule, not just a Notify-Cloud-local invariant.
- The hot-path-through-Communications rule (D5) generalizes a Notify Cloud-specific decision into a Grid principle about commercial wrappers above open engines.
- The SDK-in-open-repo rule (D6) preempts future contributors from "tidying" the SDK into the private wrapper repo.

These six rules govern Notify Cloud's first-shipping behavior and the licensing posture of its surrounding open repos. Without them, the canary infrastructure has no citable invariant, the FSL application has no constitutional anchor, and the private-repo decision sits only in an ADR — discoverable but not enforceable at the constitutional level.

## Proposed Implementation

### `constitution/invariants.md` — append six new entries

The current state of the file (verified 2026-05-20):

- Highest assigned number is **46** (ADR-0016 AI canary, in `## AI Invariants` section). ADR-0016 has already landed.
- ADR-0026 took **39** (`## Multi-Tenant Boundary Invariants` section)
- ADR-0019 took **40/41/42/43** (`## Communications Invariants` section)
- ADR-0016 took **44/45/46** (`## AI Invariants` section — landed)
- Numbers **29-30** are reserved for ADR-0010 placeholder; that placeholder stays
- Numbers **31/32/33** are ADR-0011 Code Review Invariants

**Working assumption:** ADR-0017's packet 02 lands before this packet (claiming 47/48/49/50) and ADR-0021 (Knowledge) has NOT landed first. This packet then claims **51, 52, 53, 54, 55, 56**.

**Competing claim — ADR-0021 (Knowledge):** ADR-0021's "If Accepted" section pre-claims **55/56/57/58/59**. ADR-0021 is still Proposed at the time of this packet's draft, and the ordering at acceptance is unknown. If ADR-0021's invariants land first, this packet's claimed range shifts to whatever six contiguous numbers come next after the last assigned entry. Possible outcomes the executing agent may encounter:

- **Neither ADR-0017 nor ADR-0021 has landed:** highest is 46. Claim 47-52 (and note in the PR body that ADR-0017's claim is pre-empted; the ADR-0017 packet will need to renumber when it executes).
- **Only ADR-0017 has landed:** highest is 50. Claim 51-56 (the default).
- **Only ADR-0021 has landed (claimed 55-59):** highest is 59. Claim 60-65.
- **Both ADR-0017 and ADR-0021 have landed (50, then 55-59):** highest is 59. Claim 60-65.
- **ADR-0017 lands after ADR-0021:** ordering is unusual but possible. Whatever the final state, scan for the actual highest before claiming.

**Collision-check rule for the executing agent:** Before committing, scan `constitution/invariants.md` and confirm the actual highest existing number. **This is a hard gate, not a best-effort.** Use:

```bash
rg -nP '^\d+\.\s\*\*' constitution/invariants.md | tail -10
```

to confirm the highest number. Use ripgrep (`rg`), not `grep` — Windows Git Bash boundary semantics differ subtly.

**Hard-coded references to fix in packet 06 if numbers shift.** Packet 06 (the scaffold) hard-codes the assumed invariant numbers 51-56 in roughly fifteen places. **Every one of those references must be updated in lockstep** before that packet is filed. The full list of hard-coded references in packet 06 (verified 2026-05-20 against `06-notify-cloud-node-scaffold.md`):

- Referenced Invariants block — entries `default 51`, `default 52`, `default 53`, `default 54`, `default 55`, `default 56` (six narrative blocks at the bottom of the Referenced Invariants section).
- Constraints block — `constitutional invariant 52`, `constitutional invariant 54`, `constitutional invariant 56` (three narrative references, plus parenthetical `(default-numbered)` annotations).
- Body text — `local invariant 3 and constitutional invariant 54`, `invariant 8 and constitutional invariant 54`, `ADR-0027 D11 and constitutional invariant 56` (three more narrative references in the Constraints/Boundary Check sections).

After picking the actually-assigned numbers, run the lockstep-rename query in this packet's "Lockstep renumber of packet 06 source file" section below.

If the assigned numbers shift away from 51-56:

- The corresponding bullets in ADR-0027's Consequences section ("New invariants (proposed for `constitution/invariants.md`)") at lines 257-263 are updated to state the assigned numbers.
- The packet 06 source file at `generated/work-items/active/adr-0027-notify-cloud-standup/06-notify-cloud-node-scaffold.md` is amended in place before push. Per the dispatch plan's filing-order rule, packet 06 is not filed until this packet has merged, so the pre-filing carve-out under invariant 24 applies.
- `repos/HoneyDrunk.Notify.Cloud/invariants.md` (created in packet 01) references the canary invariant by phrase ("number assigned at packet 02 of this initiative") rather than by number, so no edit is required there. If for some reason a number has been baked into that file already, update it.

### Where the six entries land in `constitution/invariants.md`

Two acceptable layouts:

- **Option A (preferred): introduce a new `## Notify Cloud Invariants` section after `## Communications Invariants`.** Each Ops-sector substrate (Communications, Notify Cloud) gets its own section. Visually clusters the six new entries together and matches the pattern used by ADR-0026 (its own `## Multi-Tenant Boundary Invariants` section) and ADR-0019 (its own `## Communications Invariants` section). Notify Cloud is a distinct enough domain (commercial wrapper, private repo, FSL/proprietary licensing) to warrant its own section.
- **Option B (acceptable fallback): append the six entries inside the existing `## Communications Invariants` section.** Acceptable if the file structure has otherwise drifted in unexpected ways, but suboptimal because Notify Cloud's concerns (private repo, FSL licensing, API key handling) are broader than Communications and reflect a separate substrate.

The executing agent picks based on what the file looks like at edit time:

- If `## Communications Invariants` already contains exactly four entries (40-43) and there is no `## Notify Cloud Invariants` section yet, **Option A** is preferred — start a new section.
- If the file structure has drifted in unexpected ways, fall back to **Option B** and mention the deviation in the PR body.

### Invariant text — assuming numbers 51-56

Append the six entries as:

```markdown
## Notify Cloud Invariants

51. **The HoneyDrunk Grid's repo default is public; private repos require an explicit ADR-recorded justification under the revenue/compliance/experiment carve-out.**
    `HoneyDrunk.Notify.Cloud` is the first private repo; its justification (customer-data-adjacent infrastructure, hyperscaler defense, billing-system integrity) is recorded in ADR-0027 D2. Future private repos require a similar standup-ADR justification on the record. See ADR-0027 D2.

52. **Commercial wrappers compose Communications, not Notify, for the hot delivery path.**
    The dependency graph is `Commercial Wrapper → Communications → Notify`. Direct `Wrapper → Notify` calls are restricted to diagnostic and smoke-test paths only. This preserves Notify's invariant that delivery decisions are made by Communications, and it keeps commercial wrappers' view of tenancy at the orchestration boundary, not at the dispatch boundary. Applied first by `HoneyDrunk.Notify.Cloud` (the only commercial wrapper at v1); generalizes to any future commercial wrapper above an open engine. See ADR-0027 D5.

53. **Customer-facing SDKs that cover both self-host and hosted-service consumers ship from the open engine repo, regardless of the wrapper's visibility.**
    The `HoneyDrunk.Notify.Client` SDK lives in the open `HoneyDrunk.Notify` repo, not in `HoneyDrunk.Notify.Cloud`. Self-hosters and hosted-service customers call the same engine endpoints with the same request shapes; only the base URL and the API key change. Co-locating the SDK with the engine lets self-hosters consume it without a license seam and gives the marketing wedge a stable home (the engine repo is public and FSL-licensed). Future commercial-wrapper SDKs inherit the same rule. See ADR-0027 D6.

54. **API keys are stored only as salted hashes; raw key material is returned to the caller exactly once at issuance time and is never logged, traced, or persisted in raw form.**
    Extension of invariant 8 (secret values never appear in logs, traces, exceptions, or telemetry) to API key material. The one-time issuance shape carries the plaintext key only at the moment of issuance; subsequent reads return only the salted hash and the metadata. Applied first by `INotifyCloudApiKeyStore` and `ApiKeyIssuance` in Notify Cloud; generalizes to any future API key surface in the Grid. See ADR-0027 D4 and D12.

55. **The HoneyDrunk.Notify.Cloud Node CI must include a contract-shape canary that fails the build on shape drift to `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, or `ApiKeyIssuance` without a corresponding version bump.**
    These four are the hot path for every Notify Cloud composition (the runtime, the Stripe billing adapter, the management web app, and any future billing-provider package). Accidental shape drift on any of them breaks the wrapper's internal composition simultaneously. The canary makes this a compile-time failure at Notify Cloud's own CI, not a discovery at runtime in production. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Notify.Cloud.Abstractions`; the obligation is to keep the gate, not to use any specific implementation. The Kernel multi-tenant primitives consumed by Notify Cloud (`TenantId`, `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`) are guarded by Kernel's contract-shape canary per ADR-0026, not by this Node's canary. See ADR-0027 D8.

56. **The open-source repos paired with `HoneyDrunk.Notify.Cloud` (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`) ship under the Functional Source License (FSL) with two-year auto-conversion to Apache 2.0.**
    The license file is committed at the repo root; every shipping `.csproj` declares `PackageLicenseFile` (or `PackageLicenseExpression = "LicenseRef-FSL-1.1-Apache-2.0"`). The wrapper repo (`HoneyDrunk.Notify.Cloud`, private) is `LicenseRef-Proprietary` (all rights reserved by default of being private). The license posture is the studio's commercial moat at the operational economics layer, not at the source-code-secrecy layer — the engine and SDK stay readable, modifiable, self-hostable, redistributable. The competitor restriction (block hyperscaler rehosting) is the only commercially load-bearing FSL clause. See ADR-0027 D11.
```

If Option B is chosen (append inside `## Communications Invariants`), drop the `## Notify Cloud Invariants` heading and place the six entries after the existing 40-43 block. The invariant numbers stay the same.

### Notes for the executing agent

- **None of the six new invariants carry the `(Proposed — this invariant takes effect when ADR-XXXX is accepted)` qualifier in this packet.** ADR-0027 is still at `Status: Proposed` at the time this packet's PR lands, but per the user's standing ADR acceptance workflow, the scope agent flips Status → Accepted after the entire initiative's PRs merge. The six invariants therefore become Accepted alongside the ADR. To match the pattern set by ADR-0016 packet 02 and ADR-0019 packet 02 (both of which omitted the `(Proposed)` qualifier on their new invariants because the ADR flipped concurrently), this packet also omits the qualifier. The Status flip itself is a separate post-merge housekeeping step that follows the initiative's completion.

  However: if for any reason the executing agent observes that ADR-0027 has NOT yet been flipped to Accepted at the time of edit and the invariants do not have an immediate enforcement context, add the qualifier `(Proposed — this invariant takes effect when ADR-0027 is accepted)` at the end of each entry's body, matching the pattern from invariants 28 (ADR-0010) and 31/32/33 (ADR-0011). The qualifier is mechanical to remove later if needed.

- Do not modify the existing entries (28, 29-30 reservation, 31-43) or any text outside the six new entries.

- The new section heading (Option A) reads exactly `## Notify Cloud Invariants` — no parenthetical, no version qualifier, no ADR number in the heading text. Other section headings in this file follow the same pattern.

### Lockstep renumber of packet 06 source file

Packet 06 (the scaffold) hard-codes the assumed invariant numbers 51-56. If the collision check shifts the numbers away from 51-56, every reference in `06-notify-cloud-node-scaffold.md` must update in lockstep before that packet is filed. **Full hard-coded reference list (verified 2026-05-20):**

- Referenced Invariants section — six narrative blocks at the bottom of the section, each annotated `(number assigned by packet 02 of this initiative — default 51)`, `(default 52)`, `(default 53)`, `(default 54)`, `(default 55)`, `(default 56)`. Update the parenthetical to reflect the actually-assigned number.
- Constraints section in Agent Handoff — three narrative references: `constitutional invariant 52 (default-numbered)`, `constitutional invariant 54 (default-numbered)`, `constitutional invariant 56 (default-numbered)`.
- Boundary Check section — narrative `local invariant 3 and constitutional invariant 54`.
- Telemetry constraints — `Per invariant 8 and constitutional invariant 54`.
- LICENSE constraints — `Per ADR-0027 D11 and constitutional invariant 56`.

After determining the actually-assigned numbers, run:

```bash
rg -nP '\b5[1-6]\b' generated/work-items/active/adr-0027-notify-cloud-standup/06-notify-cloud-node-scaffold.md
```

Use ripgrep (`rg`), not `grep`. For each match, replace the old number with the assigned one. Verify by re-running the rg query and confirming zero hits at the old numbers and the expected count at the new numbers. Where a reference is purely narrative ("the Notify Cloud contract-shape canary invariant"), the number does not need to be there at all — those phrase-keyed references are preferred per the packet's existing pattern. The numbers stay in places where they are genuinely needed (e.g. parenthetical "default 55" annotations, the actual `constitution/invariants.md` insertion).

**ADR-0021 cross-check.** If ADR-0021 landed first and claimed 55/56/57/58/59, the rg query above will find no matches at 51-56 (none of those would be Notify Cloud's anymore — they could be ADR-0017's, or unclaimed). The lockstep renumber still applies; just verify that the search for the new range (e.g. 60-65 if ADR-0021 took 55-59) finds the same six hard-coded reference sites listed above. The work is exactly the same, only the number values differ.

### `CHANGELOG.md` (Architecture repo)

Append to the in-progress version entry (no commits under `Unreleased` per the user's standing rule):

`Architecture: Add invariants 51 (private-repo carve-out requires ADR justification), 52 (commercial wrappers compose Communications not Notify on hot path), 53 (customer SDKs live in open engine repo regardless of wrapper visibility), 54 (API keys salted-hash only; raw returned exactly once at issuance), 55 (Notify Cloud contract-shape canary), 56 (FSL on open engine repos paired with Notify Cloud) per ADR-0027 D2, D5, D6, D4+D12, D8, D11. Numbers shift to next-available if collision check finds 51-56 taken.`

If renumbered, update the changelog line to state the actually-assigned numbers.

## Affected Files
- `constitution/invariants.md`
- `adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md` (only if the assigned numbers differ from 51-56 — update the Consequences "New invariants" bullets at lines 257-263)
- `generated/work-items/active/adr-0027-notify-cloud-standup/06-notify-cloud-node-scaffold.md` (only if the assigned numbers differ from 51-56 — pre-filing amendment per invariant 24's carve-out)
- `CHANGELOG.md`

## NuGet Dependencies
None. Architecture is a knowledge repo.

## Boundary Check
- [x] All edits inside `HoneyDrunk.Architecture`.
- [x] No new design decisions — invariant text is taken from ADR-0027's "New invariants" section, with light wordsmithing for the constitution's voice.
- [x] No existing invariants modified, only appended.
- [x] Pre-filing amendment to packet 06's source file is permitted under invariant 24's carve-out; post-filing amendment is forbidden, so the dispatch plan's filing-order rule (packet 06 not filed until this packet's PR has merged) is the structural protection.
- [x] No edits to `catalogs/*.json`, `initiatives/*`, `adrs/README.md` — those are hive-sync's concern.

## Acceptance Criteria
- [ ] Six new invariants present in `constitution/invariants.md` with text matching ADR-0027 D2, D5, D6, D4+D12, D8, D11.
- [ ] Assigned numbers verified against the current highest number in the file using `rg -nP '^\d+\.\s\*\*' constitution/invariants.md | tail -10`. Default assumption is 51-56; the executing agent renumbers to the next six free numbers if anything has shifted. **Specifically check whether ADR-0021 (Knowledge) has landed first** — ADR-0021 pre-claims 55/56/57/58/59 in its "If Accepted" section, which directly overlaps with this packet's default 55/56. If ADR-0021 landed first, this packet's claim shifts to 60-65 (or whatever six contiguous free numbers come next after the actual highest).
- [ ] Each invariant's body cites its source ADR decision.
- [ ] **None of the new invariants carry a `(Proposed)` qualifier**, matching the pattern from ADR-0016 packet 02 and ADR-0019 packet 02 — unless the executing agent observes that ADR-0027 has not been flipped to Accepted at the time of edit AND has no immediate enforcement context, in which case the `(Proposed — this invariant takes effect when ADR-0027 is accepted)` qualifier is added at the end of each body. Document in the PR body which choice was made.
- [ ] Existing entries (28, 29-30 reservation, 31-43) are unmodified.
- [ ] If invariant numbers shifted away from 51-56, the corresponding bullets in ADR-0027's Consequences section ("New invariants (proposed for `constitution/invariants.md`)") at lines 257-263 are updated to match.
- [ ] If invariant numbers shifted away from 51-56, the packet 06 source file is amended before that packet is filed. After determining the assigned numbers, run `rg -nP '\b5[1-6]\b' generated/work-items/active/adr-0027-notify-cloud-standup/06-notify-cloud-node-scaffold.md` and update each match to the actually-assigned number. After replacement, re-run the rg query and confirm zero hits at the old numbers. The dispatch plan's filing-order rule guarantees packet 06 has not been filed yet at the time this packet's PR merges.
- [ ] Section heading choice (Option A new `## Notify Cloud Invariants` section vs Option B append-inside-Communications) documented in the PR body with the executing agent's rationale.
- [ ] `CHANGELOG.md` in-progress version entry updated with the six invariant numbers actually assigned. No commits land under `## [Unreleased]`.
- [ ] `catalogs/*.json`, `initiatives/active-initiatives.md`, `initiatives/proposed-adrs.md`, `adrs/README.md` are **not** modified. Confirm in diff.

## Human Prerequisites
- [ ] None. The constitution edit is purely textual; no portal action, GitHub UI action, or external-system action is required.

## Referenced Invariants

> **Invariant 8:** Secret values never appear in logs, traces, exceptions, or telemetry. Only secret names/identifiers may be traced. `VaultTelemetry` enforces this. — New invariant 54 (API keys salted-hash only) is a direct extension of this rule to API key material.

> **Invariant 11:** One repo per Node (or tightly coupled Node family). Each repo has its own solution, CI pipeline, and versioning. — Reinforces why Notify Cloud is its own private repo (created by packet 05).

> **Invariant 24:** Work items are immutable once filed as a GitHub Issue. Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context without violating this rule. — The pre-filing amendment to packet 06 (if invariant numbers shift) is permitted under this carve-out.

> **Invariant 39:** Tenant mechanics stay at intake and post-dispatch boundaries. Tenant resolution, tenant rate-limit checks, billing-event emission, and tenant-scoped secret lookup must live in intake middleware/orchestration edges or post-dispatch tails. Core dispatch paths for internal Grid callers must remain tenant-agnostic and default to `TenantId.Internal` without caller-specific branches. — Notify Cloud is the first real (non-noop) consumer of this invariant; the new Notify Cloud invariants reinforce the boundary mechanics this rule sets at the Grid level.

> **Invariant 40:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`. — Reinforces the rationale for new invariant 52 (commercial wrappers compose Communications, not Notify, on hot path) — invariant 52 is the commercial-wrapper-side projection of invariant 40's downstream-coupling discipline.

## Referenced ADR Decisions

**ADR-0027 D2 (Repo visibility — private with revenue carve-out):** First private repo in the Grid. Justifications: customer-data-adjacent infrastructure, hyperscaler defense, billing-system integrity. The catalog gains a `visibility` field on this Node (hive-sync-reconciled). — Source for invariant 51.

**ADR-0027 D4 (Exposed contracts) and D12 (API key authentication routed through Auth):** API key issuance lives in Notify Cloud (`INotifyCloudApiKeyStore`); validation lives in `HoneyDrunk.Auth` (`IApiKeyAuthenticator` middleware path — added by a follow-up ADR). Keys are stored only as salted hashes; raw key material is returned exactly once via `ApiKeyIssuance` at issuance time and never logged, traced, or persisted in raw form. — Source for invariant 54.

**ADR-0027 D5 (Boundary rule):** Hot path is Notify Cloud → Communications → Notify. Direct calls from Notify Cloud to Notify (via `INotificationSender`) are diagnostic/smoke-test only. — Source for invariant 52.

**ADR-0027 D6 (SDK lives in open Notify repo):** The customer-facing `HoneyDrunk.Notify.Client` SDK lives in the public `HoneyDrunk.Notify` repo, not in the private `HoneyDrunk.Notify.Cloud` repo. Customers install it from NuGet without ever needing access to the wrapper's source. — Source for invariant 53.

**ADR-0027 D8 (Contract-shape canary):** A contract-shape canary is added to the Notify Cloud Node's CI: it fails the build if any of `INotifyCloudGateway`, `INotifyCloudApiKeyStore`, `NotifyCloudTenantTier`, `ApiKeyIssuance` change shape without a corresponding version bump. The Kernel multi-tenant primitives consumed here are guarded by Kernel's canary per ADR-0026. — Source for invariant 55.

**ADR-0027 D11 (Functional Source License — FSL — for open engine repos):** Open-source repos paired with Notify Cloud (`HoneyDrunk.Notify`, `HoneyDrunk.Communications`) ship under FSL with two-year auto-conversion to Apache 2.0. The wrapper repo (Notify Cloud, private) is `LicenseRef-Proprietary`. Rationale: solo-dev defaults beat configuration; two-year conversion matches the kill-clock cadence; the competitor restriction is the only commercially load-bearing FSL clause; Sentry's precedent is closer to Notify Cloud's buyer profile than HashiCorp's; FSL's plain-language alignment with build-in-public. — Source for invariant 56.

## Dependencies
- `work-item:01` — packet 01 lands the context-folder content (especially the four D4 contract names and the four-package family list) that invariant 55's canary will guard and that invariant 54 (API key handling) refers to. Filing 02 before 01 would leave a forward-reference dangling in the new invariant bodies.

## Labels
`chore`, `tier-2`, `architecture`, `ops`, `adr-0027`, `constitution`

## Agent Handoff

**Objective:** Land six new ADR-0027-derived invariants in the Grid constitution at the next six available numbers, in a single edit. Update ADR-0027 Consequences bullets and packet 06's source file if the assigned numbers shift away from 51-56.

**Target:** HoneyDrunk.Architecture, branch from `main`.

**Context:**
- Goal: ADR-0027's "New invariants" section is a placeholder with the qualifier "Numbering is tentative — scope agent finalizes at acceptance." This packet is the finalization.
- Feature: ADR-0027 standup initiative, Wave 1, Packet 02.
- ADRs: ADR-0027 (sole source).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 01 of this initiative (context-folder registration) must merge first.

**Constraints:**

- **None of the new invariants carry a `(Proposed)` qualifier in the default case.** Matches the pattern from ADR-0016 packet 02 and ADR-0019 packet 02. The Status flip for ADR-0027 is a separate post-merge housekeeping step the scope agent runs after the entire initiative completes; the qualifier-omission is consistent with that flip happening. If the executing agent observes ADR-0027 still at `Proposed` and judges the invariants need a qualifier for clarity, add `(Proposed — this invariant takes effect when ADR-0027 is accepted)` at the end of each entry's body, matching the pattern from invariants 28 (ADR-0010) and 31/32/33 (ADR-0011) — but the default is no-qualifier.
- **Number collision check is a hard gate.** Default 51-56. Verify against the file's highest number at edit time using `rg -nP '^\d+\.\s\*\*' constitution/invariants.md | tail -10`. If shifted, update both ADR-0027's Consequences section (lines 257-263) and packet 06's source file. Do not file partial edits — either all six invariants land at consistent numbers across all three files, or none of them.
- **Section choice (Option A vs Option B) is a stylistic call, not a correctness one.** Pick based on what the file looks like at edit time. Default to Option A (new `## Notify Cloud Invariants` section) since Notify Cloud is a distinct substrate with broad-reaching concerns (private repo, FSL licensing, API key handling) that extend beyond Communications.
- **Verbatim alignment with ADR-0027.** The invariant bodies should restate D2/D5/D6/D4+D12/D8/D11 with constitutional voice, not introduce new requirements. Anything novel belongs in a follow-up ADR.
- **Pre-filing amendment to packet 06 is the mechanism** for handling number shifts. Invariant 24: filed packets are immutable, but pre-filing edits are permitted. The dispatch plan's filing-order rule (packet 06 not filed until this packet's PR has merged) is what makes the carve-out applicable.
- **No commits under CHANGELOG `Unreleased`.** Per the user's standing rule, move to a dated versioned section with a SemVer bump before commit. The Architecture repo uses the CHANGELOG as a version of record.
- **No edits to shared catalog/index files.** `catalogs/*.json`, `initiatives/*`, `adrs/README.md` are reconciled by hive-sync, not this packet.

**Key Files:**
- `constitution/invariants.md` — append six entries (Option A: under a new `## Notify Cloud Invariants` section after `## Communications Invariants`; Option B: inside `## Communications Invariants`)
- `adrs/ADR-0027-stand-up-honeydrunk-notify-cloud-node.md` — only edited if numbers shifted from 51-56 (lines 257-263 in the Consequences "New invariants" block)
- `generated/work-items/active/adr-0027-notify-cloud-standup/06-notify-cloud-node-scaffold.md` — only edited if numbers shifted from 51-56
- `CHANGELOG.md` — version entry (no `Unreleased`)

**Contracts:** None.
