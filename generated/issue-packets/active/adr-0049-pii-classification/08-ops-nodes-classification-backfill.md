---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ops", "adr-0049", "wave-4", "backfill", "coordinator", "fan-out"]
dependencies: ["packet:03"]
adrs: ["ADR-0049"]
wave: 4
initiative: adr-0049-pii-classification
node: honeydrunk-architecture
coordinator: true
actual_target_repos: ["HoneyDrunkStudios/HoneyDrunk.Notify", "HoneyDrunkStudios/HoneyDrunk.Communications"]
---

# Backfill [Classification]/[PiiField] attributes on Ops-sector Node persisted records (Notify, Communications)

## Summary
**This is a coordinator packet, not an executable single-repo packet.** Walk every persisted record type, every API/contract type, and every `AuditEntry`-payload type in the Ops-sector live Nodes — `HoneyDrunk.Notify`, `HoneyDrunk.Communications` — and apply the correct `[Classification]` and `[PiiField]` attributes from packet 02. Sibling to packet 07 (Core-sector backfill); both packets feed packet 09's catalog population. The `security` specialist (per ADR-0046 D2 / ADR-0049 D8) reviews each PR.

> **READ THIS FIRST — packet shape and Hive routing.**
> - `target_repo: HoneyDrunk.Architecture` in the front-matter is **literal only** because The Hive's per-packet schema requires a single value. **This packet does not file a PR against `HoneyDrunk.Architecture`.** The Architecture repo gets zero code edits from this packet.
> - The actual execution surface is the repos listed in front-matter `actual_target_repos`: `HoneyDrunk.Notify`, `HoneyDrunk.Communications` (and conditionally `HoneyDrunk.Pulse` if Pulse persists tenant-attributable records — verify at branch time per the Scope section). Each gets its own PR with its own `security`-specialist review and its own release tag.
> - **The Hive routing rule is the `actual_target_repos` list, not `target_repo`.** When this packet is filed as an issue, the issue lives on `HoneyDrunk.Architecture` (as a tracking issue for the coordinator), but the work-tracking Issues for the executor live in each `actual_target_repos` entry.
> - The `coordinator: true` front-matter field is the load-bearing signal. Tooling that routes solely on `target_repo` will mis-route this packet; the flag exists so that tooling can branch on it. If tooling doesn't yet honor `coordinator: true`, this human-readable callout is the safety net.
> - Same shape as packet 07. If the per-Node alternative is later preferred, this packet can be split into `08a-notify-backfill.md`, `08b-communications-backfill.md` (and conditionally `08c-pulse-backfill.md`) with no other change.

## Context
ADR-0049 D10 Phase 2 covers all 12 live Nodes' persistence/contract surfaces. Packet 07 covers the Core-sector PII-dense Nodes (Auth, Vault, Data). This packet covers the Ops-sector outbound-comms-dense Nodes:

- **`HoneyDrunk.Notify`** — the delivery substrate. Recipient emails (PII), SMS recipient numbers (PII), message bodies (Restricted, often PII or SensitivePii depending on template content), template metadata (Confidential), queue records (Confidential), provider credentials (Restricted but never persisted as records — credential values live in Vault). Per ADR-0040 D9 the recipient-email and message-body categories are already named "forbidden in telemetry" — packet 04's redactor enforces this at the boundary; this packet ensures the source-side declarations exist so the boundary can find the markers.
- **`HoneyDrunk.Communications`** — the orchestration substrate. `IMessageIntent` shapes (often carry PII via recipient resolution), `MessageDecision` records (Confidential — record the *fact* of a decision, not the message body), preference store records (PII tied to user/tenant), cadence-policy state (Confidential). Per ADR-0019 D8, the contract-shape canary on Communications hot-path contracts is already in place; this packet's marker additions are additive (per ADR-0035 minor-bump rules).

Other Ops-sector Nodes (Pulse, Actions) are deferred:
- **`HoneyDrunk.Pulse`** is exempt from this backfill — Pulse owns the boundary that reads markers, not the source records that carry them. Pulse's own internal types are operational and Internal-classed by default; if Pulse persists any tenant-attributable records (rare — Pulse mostly streams), those are marked in this packet by adding Pulse to its target list. **Verify at branch time:** read `HoneyDrunk.Pulse` for persisted-record types; if none exist, skip Pulse here.
- **`HoneyDrunk.Actions`** has no persisted records (workflows are config, not data); exempt.
- **`HoneyDrunk.Vault.Rotation`** — minimal persisted state (mostly logged-not-stored). Check at branch time; include if persisted records exist.
- **`HoneyDrunk.Audit`** — already restructured by packet 05 (which added the redactor); confirm packet 05's marker additions are complete on `AuditEntry` itself.

The Notify.Cloud Node is private and not yet at v1 GA — handled in its own ADR-0027 standup track, not in this initiative.

The Architecture-side Kernel-Abstractions doesn't need backfill because the attributes ship from there; the attributes themselves are the classification. Kernel runtime types (`IGridContext`, `OperationContext`, etc.) are operational metadata and Internal-classed; their backfill is small and is bundled here under "any remaining Kernel runtime types that touch tenant-attributable state."

## Scope
Two (or three, if Pulse persists records) separate PRs:

1. **`HoneyDrunk.Notify`** PR — backfill recipient/template/queue records.
2. **`HoneyDrunk.Communications`** PR — backfill intent/decision/preference/cadence records.
3. **(Conditional) `HoneyDrunk.Pulse`** PR — only if Pulse persists tenant-attributable records; verify at branch time.

Order: Notify → Communications. Notify first because Communications composes Notify (consumes `INotificationSender` per ADR-0019) — keeping Notify's marker state ahead lets Communications' reviewer confirm the recipient shapes downstream.

Within each PR:
- Add `[Classification(...)]` to every public/internal property on persisted records, API request/response types, and `AuditEntry`-payload types.
- Add `[PiiField(...)]` to every PII-carrying field per ADR-0049 D2.
- Set `Purpose` strings using the convention `"{node}:{operation}"` (e.g. `"notify:delivery"`, `"communications:intent"`, `"communications:preference"`).
- Per-package CHANGELOG entries on packages with real marker additions.
- Repo-level `CHANGELOG.md` new entry.
- Version-bump per invariant 27.

## Proposed Implementation

Same procedure as packet 07; reproduced here for self-containment:

Per-Node procedure (repeat for Notify, then Communications):

1. **Read every persisted-record, contract-type, and `AuditEntry`-payload type in the Node.** Use `Grep` against the Node's source for `record ` and `class ` declarations on persisted/contract surfaces.

2. **For each property, determine the classification** (Public / Internal / Confidential / Restricted) per ADR-0049 D1. Default to Restricted on ambiguity.

3. **For each Restricted property, determine the PII sub-category** (PII / SensitivePii / Pseudonymous) per ADR-0049 D2.

4. **Apply the markers** using the worked example from ADR-0049 D4 as the template. Specific Notify/Communications patterns:
   ```csharp
   public sealed record Recipient(
       [Classification(DataClass.Restricted)]
       [PiiField(PiiCategory.Pii, Purpose = "notify:delivery")]
       string EmailAddress,
       // ...
   );
   
   public sealed record MessageDecision(
       [Classification(DataClass.Confidential)]
       TenantId Tenant,
       
       [Classification(DataClass.Restricted)]
       [PiiField(PiiCategory.Pseudonymous, Purpose = "communications:audit")]
       PrincipalId Subject,
       
       [Classification(DataClass.Confidential)]
       MessageIntentKind Intent,
       
       [Classification(DataClass.Confidential)]
       DecisionOutcome Outcome
       // NO message body in MessageDecision — the body is on the inbound intent.
   );
   ```

5. **Pay close attention to message-body fields.** Per ADR-0040 D9 (and now ADR-0049 D5 binding), prompt text, completion text, message bodies, and recipient emails are the named forbidden-in-telemetry categories. Message bodies in `Notify`'s template-render path almost certainly need `[Classification(DataClass.Restricted)] [PiiField(PiiCategory.Pii, Purpose = "notify:body")]` — and where the body contains health, financial, biometric, or other Article 9 content (the template author chooses; the runtime cannot tell at compile time), the **safe default** is `SensitivePii`. Discuss with the security reviewer if a body field's PII subcategory is unclear; default to SensitivePii.

6. **Build the Node.** Zero analyzer warnings post-backfill.

7. **Run the `security` specialist review.** Mandatory per ADR-0049 D8 + ADR-0046 D2, especially on Notify where SensitivePii markers may land for the first time on production code.

8. **Per-Node CHANGELOG and version bump.** Invariant 27 + invariant 12.

9. **Sequencing across repos.** Notify PR merges first. Wait for the Notify release tag to land on the package feed (human action) before opening the Communications PR. Communications PR merges, then release.

10. **The "should not have been storing at all" finding workflow.** Same as packet 07 — mark-and-flag, open a follow-up issue, do not delete in this PR. For Notify in particular: any field capturing a raw outbound message body for debug/diagnostic purposes that isn't strictly required for delivery is a finding (ADR-0040 D9 is explicit that message bodies do not belong in telemetry; if they're also being persisted in non-delivery records, that's a wider concern).

## Affected Files
- Per-Node `[Classification]`/`[PiiField]` additions across record types, contract types, and Audit-payload types — across Notify, Communications, (conditionally) Pulse repos.
- Per-package `CHANGELOG.md` entries on every package gaining markers.
- Per-package `README.md` updates only where API-surface change is consumer-visible.
- Repo-level `CHANGELOG.md` entries on Notify, Communications, (conditionally) Pulse.
- Every non-test `.csproj` in each repo's solution — version bump.

## NuGet Dependencies
- Each Node repo's relevant packages gain (or version-bump) `PackageReference` on `HoneyDrunk.Kernel.Abstractions` at the packet-02 version. Most already reference it (Notify already references for `IGridContext`/`TenantId`; Communications already references per ADR-0026); verify and bump.
- No other new package references.

## Boundary Check
- [x] Markers land in the Node that owns the records — Notify's in Notify, Communications' in Communications. No cross-repo edit.
- [x] No new runtime dependency. Pure declarative annotation.
- [x] ADR-0019 invariant 41 preserved: Notify owns delivery mechanics, Communications owns decision logic. The marker additions reinforce this split rather than blurring it.
- [x] Communications' contract-shape canary (invariant 43) stays green — the additions are additive (per ADR-0035).

## Acceptance Criteria
- [ ] Two PRs (or three if Pulse persistence applies) filed and merged: one on `HoneyDrunk.Notify`, one on `HoneyDrunk.Communications`, in that order
- [ ] Every persisted-record/contract-type/Audit-payload property in each Node carries a `[Classification(...)]` attribute (or explicit `[Classification(DataClass.Public)]`)
- [ ] Every PII-carrying property additionally carries a `[PiiField(...)]` attribute with the appropriate `PiiCategory` and a `Purpose` string
- [ ] Message-body fields in Notify carry `[PiiField(PiiCategory.Pii)]` (or `SensitivePii` if the body content domain warrants it)
- [ ] The analyzer rule from packet 03 shows ZERO warnings against the touched files post-backfill
- [ ] Each PR receives a generalist `review` agent pass AND a `security` specialist pass
- [ ] Each repo's `CHANGELOG.md` has a new `[X.Y.0]` entry
- [ ] Per-package `CHANGELOG.md` entries only on packages with marker additions (no noise, invariant 12/27)
- [ ] Every non-test `.csproj` in each repo's solution at the new same minor version (invariant 27)
- [ ] Any "field that should not exist" finding mark-and-flagged; not deleted in this PR
- [ ] Notify PR released to the package feed before Communications PR opens (cross-Node sequencing)
- [ ] Communications' contract-shape canary (invariant 43) remains green

## Human Prerequisites
- [ ] **Confirm packets 02 and 03 are released to the package feed.** Same gate as packet 07.
- [ ] **For each Node release, push the git release tag after the PR merges.** Notify tag → Communications tag, in sequence.
- [ ] **Allocate the `security` specialist review on each PR.** Per ADR-0046 D2.

## Referenced ADR Decisions
**ADR-0049 D10 Phase 2 — Backfill existing Nodes.** Same rule as packet 07.

**ADR-0040 D9 — Forbidden content in telemetry.** Prompt text, completion text, recipient email addresses, message bodies are forbidden in trace attributes and log properties. This packet ensures every Notify/Communications record carrying those categories declares its classification so the boundary redactor (packet 04) can mechanically enforce.

**ADR-0049 D1/D2 — Taxonomy.** Same as packet 07.

**ADR-0049 D8 — `security` specialist review for new `[PiiField(SensitivePii)]` declarations.** Notify's message-body fields are the most likely landing spot for SensitivePii markers in this packet — the specialist is mandatory.

**ADR-0019 invariant 41 — Decision logic in Communications, delivery in Notify.** Preserved; the marker discipline reinforces the boundary.

**Invariant 82 (from packet 00).** Same as packet 07's reference.

**Invariant 43 — Communications contract-shape canary.** Stays green; additive marker additions paired with a minor-version bump are not shape drift per ADR-0035.

## Constraints
- **Two (or three) separate PRs in two (or three) repos.** Do not combine.
- **Mark only — do not refactor.** Same as packet 07.
- **Default to Restricted on ambiguity** per ADR-0049 D1. For PII subcategory ambiguity (especially on message-body fields), default to `SensitivePii`.
- **`security` specialist review is mandatory** — Notify's message-body markers especially.
- **Sequence Notify → Communications** with human release tags between them.
- **Invariant 27 — Solution-version bump per repo.** Invariant 12 — Per-package CHANGELOG only on packages with real marker additions.
- **Communications' contract-shape canary** (invariant 43) must stay green — pair the marker additions with a coordinated minor-version bump per ADR-0035.
- **Pulse exemption verified at branch time.** If Pulse persists no tenant-attributable records, skip it; if it does, file a third PR.

## Labels
`feature`, `tier-2`, `ops`, `adr-0049`, `wave-4`, `backfill`

## Agent Handoff

**Objective:** Backfill `[Classification]` and `[PiiField]` markers across the Ops-sector live Nodes Notify and Communications (and Pulse if applicable) — separate PRs sequenced Notify → Communications with `security` specialist review on each.

**Target:** This coordinator packet lives in `HoneyDrunk.Architecture`. The executor opens two (or three) separate PRs in `HoneyDrunk.Notify`, `HoneyDrunk.Communications` (and conditionally `HoneyDrunk.Pulse`).

**Context:**
- Goal: Apply the field-marking discipline to the Ops-sector live Nodes' persistence/contract surfaces. Notify's message-body and recipient fields are the highest-risk PII concentration; Communications' decision-log fields are mostly Pseudonymous tokens.
- Feature: ADR-0049 Data Classification rollout, Wave 4 (Phase 2 backfill).
- ADRs: ADR-0049 D10 Phase 2 (primary), ADR-0049 D1/D2 (taxonomy), ADR-0049 D8 (review duties), ADR-0019 (Notify/Communications boundary), ADR-0040 D9 (forbidden-in-telemetry content named).

**Acceptance Criteria:** As listed above. Each PR has its own subset.

**Dependencies:**
- `packet:03` — analyzer rule exists so warnings drive the checklist.

**Constraints:**
- Two (or three) separate PRs; do not combine.
- Mark only; "should not exist" findings are mark-and-flag with separate follow-up issues.
- Default to Restricted on classification ambiguity; default to SensitivePii on PII-subcategory ambiguity for message-body fields.
- `security` specialist review on each PR (ADR-0046 D2).
- Sequence Notify → Communications with human release tags.
- Invariant 27 per-repo bumps; invariant 12 per-package CHANGELOGs only where real markers landed.
- Communications contract-shape canary stays green (invariant 43).

**Key Files:**
- Per-Node persisted records, contract types, intent/decision shapes, `AuditEntry` payload types.
- Per-package and repo-level `CHANGELOG.md` entries.
- Every non-test `.csproj` in each repo's solution.

**Contracts:** No new contracts. Existing types gain `[Classification]` and `[PiiField]` attributes.
