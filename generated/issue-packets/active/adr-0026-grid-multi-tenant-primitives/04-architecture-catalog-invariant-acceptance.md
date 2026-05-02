---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "docs", "governance", "adr-0026", "wave-3"]
dependencies: ["Kernel#NN — Grid multi-tenant primitives (packet 01)", "Vault#NN — Tenant-scoped secret resolver (packet 02)"]
adrs: ["ADR-0026"]
wave: 3
initiative: adr-0026-grid-multi-tenant-primitives
node: honeydrunk-architecture
---

# Feature: ADR-0026 catalog updates, multi-tenant boundary invariant, and Status flip to Accepted

## Summary
Land the Architecture-side obligations of ADR-0026: append the multi-tenant boundary invariant to `constitution/invariants.md` (assigning the next available number, currently 37); add catalog entries for the four new Kernel surfaces in `catalogs/contracts.json`; update `repos/HoneyDrunk.Kernel/boundaries.md` and `invariants.md` to reflect the tenancy primitives; update `repos/HoneyDrunk.Vault/boundaries.md` to add the `TenantScopedSecretResolver` composition pattern with link to `docs/Tenancy.md`; flip ADR-0026 Status from Proposed to Accepted; record acceptance in `initiatives/active-initiatives.md` and `initiatives/releases.md` (or wherever ADR acceptances are tracked).

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Architecture`

## Motivation
Per ADR-0026's "If Accepted — Required Follow-Up Work" section and per the Grid's ADR acceptance workflow (memory: feedback_adr_workflow), the scope agent flips Status to Accepted only after the implementation packets ship. Packets 01 (Kernel) and 02 (Vault) deliver the runtime side; this packet closes the loop on the Architecture knowledge base so:

1. The constitution carries the new boundary rule that prevents the PDR-0002 §K kill criterion 2 failure mode (multi-tenanting bleeds into core dispatch in a way internal callers must know about).
2. `catalogs/contracts.json` reflects the four new public Kernel surfaces, so downstream agents know the contracts exist when scoping consumer-Node work (Notify Cloud, Communications, future commercial Nodes).
3. The per-Node boundary docs reflect the new responsibilities, so the review agent and future scope agents have a single source for "what does Kernel own / what does Vault own" that includes the tenancy primitives.
4. The ADR's index entry flips to Accepted, and the active-initiatives tracker records the closure.

This packet is the third wave — runs strictly after packets 01 and 02 are merged AND the Kernel + Vault NuGet packages are published. The Pulse packet (#03) can be in flight in parallel; this packet does not block on Pulse, but the Pulse adoption is a Done-When item on ADR-0026 and the active-initiatives tracker should reflect that as a separate checkbox.

## Proposed Implementation

### A. Append the multi-tenant boundary invariant to `constitution/invariants.md`

Today's `constitution/invariants.md` ends at invariant 36 (the Container App revision-mode invariant from ADR-0015). The next available number is **37**. Append a new section after the "Hosting Platform Invariants" group, titled "Multi-Tenancy Invariants":

```markdown
## Multi-Tenancy Invariants

37. **Tenant resolution, rate-limit enforcement, billing-event emission, and tenant-scoped secret resolution live in gateway-layer middleware (Node intake) and post-dispatch tails, never in core dispatch paths.**
    Core dispatch — the routing, retry, worker, and provider layers of any Node — receives requests with tenancy already resolved (or `TenantId.Internal` defaulted) and emits no tenant-aware concerns of its own. Internal callers that bypass gateway middleware (in-process direct dispatch from the same Node, internal job-to-job hops within a worker) are unaffected by tenancy enforcement and continue to operate as `TenantId.Internal`. See ADR-0026.
```

The text matches ADR-0026 D7 (and the "New invariants" entry in ADR-0026's Consequences section) verbatim modulo formatting. **Final number is 37** — confirmed by reading `constitution/invariants.md` at packet authoring time (last existing invariant is #36). If a new invariant lands between this packet's authoring and execution, take the next available number and update the ADR's "If Accepted" section accordingly (it currently says "provisional 37" — the agent updates the ADR text to match whatever number is actually assigned).

Update the AI Invariants placeholder line `_Invariants 29–30 are reserved for the Observation Layer (ADR-0010). They will be added here when ADR-0010 is accepted._` only if its content has shifted by the time this packet runs (verify; if 29–30 already landed, no edit needed).

### B. Update `catalogs/contracts.json`

In the `honeydrunk-kernel` entry, add a SECOND section for the Tenancy package surfaces. The current entry has interfaces grouped under one section keyed on `package: "HoneyDrunk.Kernel.Abstractions"`. The simplest shape is to append the new entries to that same section's `interfaces` array, since they live in the same package (`HoneyDrunk.Kernel.Abstractions`, namespace `Tenancy`):

```jsonc
{
  "node": "honeydrunk-kernel",
  "node_name": "HoneyDrunk.Kernel",
  "package": "HoneyDrunk.Kernel.Abstractions",
  "status": "stable",
  "interfaces": [
    // ... existing entries unchanged ...
    {
      "name": "ITenantRateLimitPolicy",
      "kind": "interface",
      "description": "Per-tenant rate-limit contract consulted at the gateway / intake layer before tenant-billable work. Implementations short-circuit on TenantId.IsInternal and return Allow without consulting any store. Default: NoopTenantRateLimitPolicy in HoneyDrunk.Kernel."
    },
    {
      "name": "TenantRateLimitDecision",
      "kind": "type",
      "description": "Result of a per-tenant rate-limit evaluation. Outcome (Allow/Throttle/Reject), optional RetryAfter, optional non-PII Reason. Reason never carries secret material."
    },
    {
      "name": "TenantRateLimitOutcome",
      "kind": "type",
      "description": "Enum: Allow, Throttle, Reject. Allow proceeds; Throttle is a soft advisory; Reject is a hard refusal."
    },
    {
      "name": "IBillingEventEmitter",
      "kind": "interface",
      "description": "Per-tenant billing-event contract for emitting consumed-capacity events. Fire-and-forget. Implementations short-circuit on TenantId.IsInternal and emit nothing. Default: NoopBillingEventEmitter in HoneyDrunk.Kernel."
    },
    {
      "name": "BillingEvent",
      "kind": "type",
      "description": "Tenant-scoped billing event. TenantId, EventType, OperationKey, Units, OccurredAtUtc, CorrelationId, Attributes (bounded ~16 entries, no PII or secret material)."
    }
  ]
}
```

Update the existing `TenantId` entry to reflect the new `Internal` static + `IsInternal` predicate — modify the description string to:

```jsonc
{ "name": "TenantId", "kind": "type", "description": "ULID-based strongly-typed tenant identity. Carries TenantId.Internal sentinel and IsInternal predicate for non-multi-tenant Grid usage. The default value applied by GridContextMiddleware / messaging+job mappers when no X-Tenant-Id header is present at Grid entry." }
```

Update `_meta.updated` to today's date (2026-05-02 or the actual date the packet runs).

If `catalogs/contracts.json` has any per-Node "exposes" or "status" field that should reflect the new namespace, verify and update at execution. The contracts.json uses interfaces keyed under `node` + `package` — additions here do not change schema shape.

### C. Update `repos/HoneyDrunk.Kernel/boundaries.md`

Today's `boundaries.md` says Kernel owns "Identity grammar (strongly-typed ID primitives)" and lists what it does NOT own. Update the "What Kernel Owns" section to add a new bullet:

```markdown
- Tenancy primitives — `TenantId.Internal` sentinel and `IsInternal` predicate (in `HoneyDrunk.Kernel.Abstractions.Identity`); `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` contracts (in `HoneyDrunk.Kernel.Abstractions.Tenancy`); `NoopTenantRateLimitPolicy` and `NoopBillingEventEmitter` defaults (in `HoneyDrunk.Kernel`). Kernel does NOT enforce, authorize, or bill — those are consumer-Node concerns at gateway-layer middleware.
```

In "What Kernel Does NOT Own", add a clarifying bullet:

```markdown
- **Tenant rate-limit enforcement, billing emission, tenant-scoped secret resolution.** Kernel ships the contracts and noop defaults; real implementations live in consumer Nodes (Notify Cloud, Communications, future commercial Nodes) at gateway-layer middleware.
```

### D. Update `repos/HoneyDrunk.Kernel/invariants.md`

Append a new invariant (`8.` — counting continues from the existing list ending at 7):

```markdown
8. **Tenancy primitives are interpretation-free in Kernel.**
   Kernel parses `TenantId` at Grid entry, applies the `TenantId.Internal` default when no header is present, propagates the value through `IGridContext` and the messaging/job mappers, and exposes the four Tenancy contracts (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`) plus noop defaults. Kernel does NOT authorize, rate-limit, bill, or enforce tenant scoping. Those concerns live in consumer Nodes at gateway-layer middleware (per Grid invariant 37).
```

The number `8` reflects the next slot after the existing list — verify at execution. The point of this Kernel-specific invariant is to nail down the interpretation-free stance for the new Tenancy namespace, so a future agent does not accidentally land enforcement logic in `HoneyDrunk.Kernel`.

### E. Update `repos/HoneyDrunk.Vault/boundaries.md`

Add a new bullet to "What Vault Owns":

```markdown
- `TenantScopedSecretResolver` composition layer (in the `HoneyDrunk.Vault` runtime package) — resolves per-tenant secrets named `tenant-{tenantId}-{secretName}` with fallback to the Node's shared secret. Internal-tenant callers short-circuit to the shared path. **No contract change to `ISecretStore`** — tenancy is a usage pattern. See `docs/Tenancy.md`.
```

Add a clarifying bullet to "What Vault Does NOT Own":

```markdown
- **Tenant slot lifecycle.** Per-tenant secret slots (`tenant-{tenantId}-{secretName}`) are populated and rotated by the consumer Node's tenant-onboarding workflow, not by Vault. Vault provides the resolver; consumers provide the slot contents.
```

### F. Update `repos/HoneyDrunk.Vault/active-work.md`

Append a "Recent Changes" entry (or update the existing structure to reflect Vault's new minor):

```markdown
## Recent Changes (v0.3.0)

- `TenantScopedSecretResolver` (composition over `ISecretStore`)
- `docs/Tenancy.md` documents the per-tenant secret naming convention and fallback semantics
- Adopted typed `TenantId` from Kernel 0.5.0 (no contract change to `ISecretStore`)
```

### G. Update `repos/HoneyDrunk.Kernel/active-work.md`

Append a "Recent Changes" entry:

```markdown
## Recent Changes (v0.5.0)

- `IGridContext.TenantId` promoted from `string?` to non-nullable `TenantId`
- `TenantId.Internal` sentinel + `IsInternal` predicate (ULID-pinned by canary)
- New `HoneyDrunk.Kernel.Abstractions.Tenancy` namespace: `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent`
- Noop defaults in `HoneyDrunk.Kernel`: `NoopTenantRateLimitPolicy`, `NoopBillingEventEmitter`
- `GridContextMiddleware`, `MessagingContextMapper`, `JobContextMapper`, `GridContextSerializer` adopt the typed value with Internal default at Grid entry
```

Also update the `## Current` section: bump "v0.4.0 stable" to "v0.5.0 released" and reset the "Upcoming" notes accordingly.

### H. Flip ADR-0026 Status

Edit the ADR header in `adrs/ADR-0026-grid-multi-tenant-primitives.md`:

- `**Status:** Proposed` → `**Status:** Accepted`

Replace the placeholder "provisional number 37 — final number assigned by scope agent at acceptance" wording in three places (the If-Accepted section, D7 body, and Consequences/New Invariants section) with the assigned final number (currently 37). Search the ADR for `provisional` and `final number` and update each occurrence.

In the If-Accepted checklist at the top of the ADR, check off completed items:
- [x] Kernel packet — TenantId.Internal + IsInternal + ...
- [x] Kernel packet — IGridContext.TenantId promotion ...
- [x] Kernel packet — ITenantRateLimitPolicy + IBillingEventEmitter ...
- [x] Vault packet — Tenancy.md + TenantScopedSecretResolver
- [ ] Pulse packet — tenant_id telemetry (leave unchecked unless packet 03 has merged when this runs)
- [x] Architecture packet — invariants + catalog + boundary docs (this packet)
- [x] Scope agent flips Status → Accepted (this step)

(If packet 03 has merged before this packet runs, check that box too. If not, leave it unchecked and add a follow-up note in `active-initiatives.md` per step I.)

### I. Update `initiatives/active-initiatives.md`

Add a new "In Progress" or "Recently Completed" entry for the ADR-0026 initiative. Match the existing style. Sample shape:

```markdown
### ADR-0026 Grid Multi-Tenant Primitives
**Status:** {In Progress | Completed} (depending on whether packet 03 has shipped)
**Scope:** Kernel, Vault, Pulse, Architecture
**Initiative:** `adr-0026-grid-multi-tenant-primitives`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Promote `TenantId` to a Kernel-Abstractions first-class primitive; add `Internal` sentinel + `IsInternal` predicate; ship `ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `IBillingEventEmitter`, `BillingEvent` contracts with noop defaults; add `TenantScopedSecretResolver` composition over `ISecretStore`; adopt the typed `tenant_id` enrichment in Pulse with cardinality discipline anchored on PDR-0002 §K. Foundation primitives for Notify Cloud and any future commercial Node.

**Tracking:**
- [x] Kernel#NN: Grid multi-tenant primitives (packet 01) — closed YYYY-MM-DD
- [x] Vault#NN: Tenant-scoped secret resolver (packet 02) — closed YYYY-MM-DD
- [{x|}] Pulse#NN: tenant_id telemetry tag adoption (packet 03) — {closed YYYY-MM-DD | open}
- [x] Architecture#NN: catalog + invariant + acceptance (this packet)

> **Sync (YYYY-MM-DD):** ADR-0026 status flipped to Accepted. {N}/{4} packets closed. {Notes about Pulse if still open.}
```

Fill in the actual issue numbers and dates at execution.

### J. Update `initiatives/releases.md` (if the file exists and is the right home)

Check if `initiatives/releases.md` tracks per-Node version releases. If it does, add entries for `HoneyDrunk.Kernel.Abstractions 0.5.0`, `HoneyDrunk.Kernel 0.5.0`, and `HoneyDrunk.Vault 0.3.0` (and `HoneyDrunk.Pulse 0.2.0` if Pulse has shipped). Match the existing style in that file. If it does not exist or is not the right home, skip this step — `active-initiatives.md` is the primary tracker.

### K. (Optional, only if ADR-0019 is currently in the active-initiatives tracker as "in progress") cross-link

If ADR-0019 is referenced in `active-initiatives.md` as in-progress, add a one-line note that ADR-0026 supersedes ADR-0019's tenancy concerns — Communications inherits the typed `IGridContext.TenantId` automatically. This is informational; ADR-0019 is not blocked or invalidated.

## Affected Files

- `constitution/invariants.md` (edit — append invariant 37)
- `catalogs/contracts.json` (edit — add 5 entries to honeydrunk-kernel package, update existing TenantId description, bump `_meta.updated`)
- `repos/HoneyDrunk.Kernel/boundaries.md` (edit — Kernel-owns + Kernel-does-not-own bullets)
- `repos/HoneyDrunk.Kernel/invariants.md` (edit — append invariant 8)
- `repos/HoneyDrunk.Kernel/active-work.md` (edit — Recent Changes for v0.5.0)
- `repos/HoneyDrunk.Vault/boundaries.md` (edit — Vault-owns + Vault-does-not-own bullets)
- `repos/HoneyDrunk.Vault/active-work.md` (edit — Recent Changes for v0.3.0)
- `adrs/ADR-0026-grid-multi-tenant-primitives.md` (edit — Status flip; provisional → 37 in three places; If-Accepted checklist marks)
- `initiatives/active-initiatives.md` (edit — new entry)
- `initiatives/releases.md` (optional edit — if it tracks per-Node releases)

## NuGet Dependencies
None. Pure docs / catalog / governance changes.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing" matches.
- [x] No code changes. No package changes. No CI changes.
- [x] Catalog and constitution are the only sources of architectural truth being updated; `repos/HoneyDrunk.{Node}/*.md` updates are informational reflections of what shipped in packets 01 + 02.
- [x] No invariant violation. The new invariant 37 is the one being added and is settled by ADR-0026 D7.

## Acceptance Criteria

- [ ] `constitution/invariants.md` has a new "Multi-Tenancy Invariants" section with invariant 37, text matching ADR-0026 D7 verbatim.
- [ ] If a new invariant landed between packet authoring and execution and 37 was claimed, the assigned number is updated in this packet AND in the ADR text in three places (`provisional 37`, `final number assigned`, `(See D7.)`).
- [ ] `catalogs/contracts.json` `honeydrunk-kernel` entry has the five new entries (`ITenantRateLimitPolicy`, `TenantRateLimitDecision`, `TenantRateLimitOutcome`, `IBillingEventEmitter`, `BillingEvent`) AND the existing `TenantId` description is updated to mention `Internal` + `IsInternal`.
- [ ] `catalogs/contracts.json` `_meta.updated` is bumped to the execution date.
- [ ] `catalogs/contracts.json` validates as well-formed JSON (`jq . catalogs/contracts.json` succeeds with no error). Tools that consume this file (Studios website data import, agent context loaders) must not break — verify with `jq` before committing.
- [ ] `repos/HoneyDrunk.Kernel/boundaries.md` updated with the tenancy-owns and tenancy-does-not-own bullets.
- [ ] `repos/HoneyDrunk.Kernel/invariants.md` updated with the new Kernel-specific invariant about interpretation-free tenancy.
- [ ] `repos/HoneyDrunk.Kernel/active-work.md` updated with the v0.5.0 Recent Changes entry.
- [ ] `repos/HoneyDrunk.Vault/boundaries.md` updated with the `TenantScopedSecretResolver` bullet and the slot-lifecycle exclusion.
- [ ] `repos/HoneyDrunk.Vault/active-work.md` updated with the v0.3.0 Recent Changes entry.
- [ ] `adrs/ADR-0026-grid-multi-tenant-primitives.md` Status header is `Accepted` (was `Proposed`).
- [ ] All three `provisional` / `final number assigned` references in the ADR are replaced with the actual final number.
- [ ] If-Accepted checklist in the ADR has the Kernel + Vault + Architecture items checked. The Pulse item is checked only if packet 03 has merged at execution time; otherwise it remains unchecked with a note.
- [ ] `initiatives/active-initiatives.md` has a new ADR-0026 entry with checkbox tracking (Kernel, Vault, Pulse, Architecture rows; correctly marked based on what's merged).
- [ ] If `initiatives/releases.md` is the right home for per-Node version releases, the new versions are added.
- [ ] No catalog / constitution / ADR text uses an "Invariant 37" reference anywhere it should use the inlined invariant text. (Architecture-internal docs may cite invariants by number with a brief one-line gloss; the rule about no-number-only references applies to issue packets, not Architecture knowledge-base docs.)
- [ ] `git diff` shows ONLY changes inside the files listed in Affected Files. No collateral edits to unrelated catalogs, ADRs, or invariants.

## Human Prerequisites

The agent ships the doc edits and Status flip. The human does the gating check before merging:

- [ ] **Confirm packet 01 (Kernel) merged AND `HoneyDrunk.Kernel.Abstractions` 0.5.0 + `HoneyDrunk.Kernel` 0.5.0 are published to the Grid's NuGet feed.** If not, this packet's Status flip is premature — wait.
- [ ] **Confirm packet 02 (Vault) merged AND `HoneyDrunk.Vault` 0.3.0 is published.** Same gating — Status flip requires both Kernel + Vault per ADR-0026 D9 + Done When list.
- [ ] **Decide on Pulse packet status.** Pulse packet (#03) is part of ADR-0026's Done-When list ("`tenant_id` low-cardinality telemetry tag with PDR-0002 §K cardinality discipline"). Two readings:
  - **Strict:** Wait for Pulse to merge before flipping Status to Accepted.
  - **Pragmatic:** Status flip when Kernel + Vault land (the primitives themselves are settled and shipped); Pulse adoption is a downstream consumer-side change that does not affect the primitive contracts. The ADR explicitly says "Step 3 is consumer-Node work that proceeds under its own ADRs and packets" — Pulse adoption is consumer-side.
  - **Recommendation:** Pragmatic. Flip when Kernel + Vault land. Track Pulse as an open checkbox in `active-initiatives.md`. Confirm before merge: this packet defaults to the pragmatic reading; if you prefer strict, hold this packet until Pulse merges.
- [ ] **Verify the assigned invariant number.** Open `constitution/invariants.md` at execution time. If the highest invariant is 36, the new one is 37. If a new invariant landed between authoring and execution and 37 was claimed, take the next available number and update the ADR text in three places.
- [ ] **No portal / Azure work.** This is documentation only.

## Dependencies
- **Kernel#NN — Grid multi-tenant primitives (packet 01).** Hard. Packet 01 must merge AND publish before this packet runs.
- **Vault#NN — Tenant-scoped secret resolver (packet 02).** Hard. Packet 02 must merge AND publish before this packet runs.
- **Pulse#NN — tenant_id telemetry tag adoption (packet 03).** Soft. This packet can ship with packet 03 still open per the pragmatic reading (see Human Prerequisites). If you take the strict reading, packet 03 is hard.

## Downstream Unblocks
- Notify Cloud standup ADR (PDR-0002 §Recommended Follow-Up Artifacts) can reference Accepted ADR-0026 + invariant 37 + the catalog entries when it is drafted.
- Communications (ADR-0019) is unblocked on tenancy concerns — the typed `IGridContext.TenantId` is the upstream they consume; ADR-0026's acceptance gives Communications a stable reference.
- Future commercial Nodes (Communications-as-a-Service, AI-as-a-Service, Vault-as-a-Service) inherit the same primitives and the same boundary invariant.
- The ADR-0019 active-initiative entry (if any) can be updated to note that ADR-0026 supersedes its tenancy section.

## Referenced Invariants

> **Invariant 25 (Work Tracking):** Dispatch plans are initiative narratives, not live state. The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records. **Why it matters here:** The dispatch plan for this initiative is updated at the close of Wave 3 (this packet's merge) to record completion; it is not the source of truth for in-flight tracking — the GitHub board and `active-initiatives.md` are.

> **Invariant 24 (Work Tracking):** Issue packets are immutable once filed as a GitHub Issue. **Why it matters here:** This packet (and packets 01–03) are immutable after filing. If post-acceptance refinements to ADR-0026 or the new invariant text are needed, write a new packet rather than editing this one.

(The substantive invariant being introduced — invariant 37 — is the body of this packet, not a reference to it. The full text appears in section A above.)

## Referenced ADR Decisions

**ADR-0026 (Grid Multi-Tenant Primitives):**
- **D7 — Multi-tenant boundary invariant.** This packet adds it to `constitution/invariants.md`.
- **D8 — Where these primitives live — packages and dependency rule.** This packet records the four contracts in `catalogs/contracts.json`.
- **D9 — Ordering — Kernel ships first, then Vault docs, then consumer Nodes. ADR flips Status → Accepted when steps 1 and 2 are landed.** This packet executes the Status flip after verifying steps 1 (packet 01) and 2 (packet 02) have shipped. Step 3 (consumer Nodes) is explicitly deferred and tracked separately.

**ADR-0026 Done When list (in Consequences):** Cross-checked against this packet's Acceptance Criteria. Every Done-When item that lives in the Architecture repo is covered here. Items that live in Kernel / Vault are covered by packets 01 / 02. The Pulse item is covered by packet 03.

**ADR Acceptance Workflow (Grid governance, not an ADR):** New ADRs start Proposed; scope agent flips to Accepted after the implementation PRs merge, never on first draft. This packet executes that flip for ADR-0026.

## Constraints

- **The number 37 is assigned at execution time, not at packet authoring.** Verify by reading `constitution/invariants.md` first; take the next available number; update the ADR text in three places to match. The packet uses 37 throughout for clarity but the number is configurable.
- **The new boundary invariant text is verbatim from ADR-0026 D7.** Do not paraphrase — the wording is settled by the ADR. Copy it exactly (modulo trivial Markdown formatting).
- **`catalogs/contracts.json` must remain valid JSON.** Run `jq . catalogs/contracts.json` before committing. A malformed file breaks the Studios website data import pipeline (Studios consumes Architecture catalogs as static JSON per its overview).
- **The ADR Status flip is the load-bearing change in this packet.** All other edits are reflective. If the Status flip is missed, the ADR remains Proposed and downstream agents will not treat its decisions as binding.
- **Pragmatic vs strict acceptance.** Default behavior: flip Status when Kernel + Vault land, even if Pulse is still open. The ADR's D9 explicitly says step 3 is consumer-Node work proceeding under its own packets. The human can override at PR review by holding the Status flip until Pulse merges.
- **No new initiatives.** This packet does not create a follow-up initiative. The Notify Cloud standup ADR and any other downstream work are tracked separately.
- **No ADR ID in the constitution / catalog / per-repo doc bodies beyond the existing precedent.** The constitution today references ADRs at the end of invariants (e.g., "See ADR-0005."). This packet follows that precedent — invariant 37 ends with "See ADR-0026." That is the existing convention for the constitution and is allowed (the no-ADR-in-docs rule applies to code comments, package READMEs, and runtime docs — Architecture-knowledge-base docs reference ADRs by design).

## Labels
`feature`, `tier-2`, `docs`, `governance`, `adr-0026`, `wave-3`

## Agent Handoff

**Objective:** Land the Architecture-side obligations of ADR-0026 — append invariant 37, update `catalogs/contracts.json` with the four new Kernel surfaces, refresh per-repo boundary + active-work docs for Kernel and Vault, flip ADR-0026 Status to Accepted, and record the initiative tracker entry.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Close the loop on ADR-0026 acceptance — the constitution, catalog, and per-repo boundary docs reflect the shipped primitives.
- Feature: ADR-0026 Grid Multi-Tenant Primitives, Wave 3 (acceptance + governance updates).
- ADRs: ADR-0026 (the one being accepted).
- Initiative: `adr-0026-grid-multi-tenant-primitives`.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Kernel#NN — packet 01 merged and 0.5.0 published.
- Vault#NN — packet 02 merged and 0.3.0 published.
- Pulse#NN — packet 03 (soft per pragmatic reading; hard per strict reading).

**Constraints:** Per Constraints section above. Specifically:
- Verify the assigned invariant number at execution; update ADR text in three places if it isn't 37.
- Boundary invariant text is verbatim from ADR-0026 D7.
- `catalogs/contracts.json` must remain valid JSON (`jq` check).
- The Status flip is the load-bearing edit — do not skip it.
- Pragmatic reading is default: flip Status when Kernel + Vault land, even if Pulse is open.
- No ADR ID in code / READMEs (architecture-knowledge-base docs are an exception per existing precedent).

**Inlined Invariant Text (for review without leaving the target repo):**

> **Invariant 24:** Issue packets are immutable once filed as a GitHub Issue. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one.

> **Invariant 25:** Dispatch plans are initiative narratives, not live state. The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records.

**Key Files:**
- `constitution/invariants.md`
- `catalogs/contracts.json`
- `repos/HoneyDrunk.Kernel/boundaries.md`, `invariants.md`, `active-work.md`
- `repos/HoneyDrunk.Vault/boundaries.md`, `active-work.md`
- `adrs/ADR-0026-grid-multi-tenant-primitives.md`
- `initiatives/active-initiatives.md`
- `initiatives/releases.md` (optional)

**Contracts:** None. Pure docs / catalog / governance.
