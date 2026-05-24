---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "core", "docs", "adr-0055", "wave-1"]
dependencies: []
adrs: ["ADR-0055"]
accepts: ["ADR-0055"]
wave: 1
initiative: adr-0055-feature-flags
node: honeydrunk-architecture
---

# Accept ADR-0055 — flip status, add the two feature-flag invariants, register the initiative

## Summary
Flip ADR-0055 (Feature Flag and Progressive Rollout Strategy) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, add the two new feature-flag invariants ADR-0055 commits in its Consequences/Invariants section to `constitution/invariants.md`, and register the `adr-0055-feature-flags` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0055 commits the Grid's first formal feature-flag substrate, selecting **Azure App Configuration's feature-flag surface** as the v1 backend (`Microsoft.FeatureManagement.AzureAppConfiguration`) leveraging the App Configuration resource already provisioned per ADR-0005, naming three flag categories (`release`, `permission`, `operational`) with distinct lifecycle policies, placing `IFeatureGate` in `HoneyDrunk.Kernel.Abstractions`, and standing up a new Node `HoneyDrunk.FeatureFlags` for the concrete App-Configuration-backed implementation and the `TenantTargetingFilter`.

The ADR decides:
- **D1** — three flag categories: `release` (days–weeks; mandatory `expires_on`, default 90 days; expired = CI failure), `permission` (long-lived; annual review; off unless tenant entitled), `operational` (long-lived kill-switch; intentionally rarely flipped).
- **D2** — backend: Azure App Configuration's feature-flags surface (`Microsoft.FeatureManagement.AzureAppConfiguration`); no new vendor — leverages the existing App Configuration resource per ADR-0005.
- **D3** — targeting: built-in percentage + time-window filters plus one custom filter `TenantTargetingFilter` (reads `RequestContext.TenantId` / `Tier` per ADR-0026, falls back to a default rollout percentage).
- **D4** — `IFeatureGate` in `HoneyDrunk.Kernel.Abstractions`; concrete implementation in the new Node `HoneyDrunk.FeatureFlags`; `InMemoryFeatureGate` in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15.
- **D5** — naming `{category}.{node}.{feature}` (kebab-case `feature` segment); validated at registration; regex `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$`.
- **D6** — per-Node `featureflags.json` registry + CI validation (every used flag registered, every registered flag used or `expected_orphan: true`, expiry/review enforcement).
- **D7** — release flags hard-expire on `expires_on`; permission/operational require annual review (warning, not gate).
- **D8** — per-tenant policy: flags drive code paths, not UX text; flags are NOT a stand-in for `Capabilities` authorization (ADR-0051); permission flips are audited per ADR-0030.
- **D9** — local-dev affordance: dev defaults on, staging/prod/ci default off, via per-label App Configuration values.
- **D10** — observability: every evaluation emits a `feature_flag_evaluated` log line via `HoneyDrunk.Pulse` (per ADR-0040); hotpath flags sampled at 1% with explicit `hotpath: true` marking; permission and operational flips are audit events per ADR-0030.
- **D11** — operator surface: `operator flags …` subcommand (list/show/enable/disable/expire/review-due).
- **D12** — flags-vs-config boundary: boolean enablement with lifecycle = flag; typed value config = config; CI validator refuses non-boolean flags.
- **D13** — anti-patterns enforced by the review agent: flag-checking in tight loops, flag-as-authorization-check, flag without `RequestContext` access, string-concatenation flag names, long-lived release flags, permission flags that only affect UX text.
- **D14** — phased rollout: Phase 1 contracts + `HoneyDrunk.FeatureFlags` Node standup; Phase 2 CI validation + Notify pilot; Phase 3 Operator CLI; Phase 4 Notify.Cloud (deferred); Phase 5 PDR consumers (deferred); Phase 6 escalation evaluation (deferred).
- **D15** — escalation triggers documented (LaunchDarkly / GrowthBook).
- **D16** — relationship to ADR-0015 (orthogonal — Container Apps revisions split deploy traffic; flags toggle code paths within a single revision), ADR-0005 (extended — same App Configuration resource), ADR-0030 (extended — flip events are audit events), ADR-0053 (completed — trunk-based dev's flag prerequisite is now provided).

ADR-0055 is a **policy / contract / new-Node** ADR. The concrete code — `IFeatureGate` in Kernel, the `HoneyDrunk.FeatureFlags` Node standup, the App Configuration walkthrough, the CI validation workflow + Roslyn analyzer, the Notify pilot, the Operator CLI, the governance docs — lands in packets 01–09 of this initiative. Every other packet references ADR-0055's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0055-feature-flag-and-progressive-rollout-strategy.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0055 row Status column to Accepted.
- `constitution/invariant-reservations.md` — claim the next free block (size 2) above the current ceiling for ADR-0055, adding a row to the **Active Reservations** table.
- `constitution/invariants.md` — add the two new feature-flag invariants (see Proposed Implementation for exact text) at the two reserved numbers (see Constraints).
- `initiatives/active-initiatives.md` — register the `adr-0055-feature-flags` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0055 header: `**Status:** Proposed` → `**Status:** Accepted`.
2. Update the ADR-0055 index row in `adrs/README.md` to Accepted.
3. **Read `constitution/invariant-reservations.md` at edit time.** Compute the next free invariant block above the highest claim in the **Active Reservations** table (`max + 1`). The ADR-0055 block size is **2** (the two invariants below). At scoping time the ceiling is **61** (ADR-0051 holds 54–57); confirm at edit time and use the live `max + 1`.
4. Add a new row to the **Active Reservations** table in `constitution/invariant-reservations.md` claiming that block for ADR-0055. Row shape: `<NA>-<NB> | ADR-0055 | Proposed | Feature-flag substrate (`{N-FLAG-GATE}`, `{N-FLAG-NAMING}`). Packet 00 at `generated/issue-packets/active/adr-0055-feature-flags/00-architecture-adr-0055-acceptance.md`.`
5. Add two new invariants to `constitution/invariants.md` at the two reserved numbers (`{N-FLAG-GATE}`, `{N-FLAG-NAMING}`) — the values claimed in step 4. Never reuse a claimed number; never collide with any other Active Reservation. The text, taken verbatim-in-substance from ADR-0055's Consequences "Invariants" section:
   - **Feature flags are evaluated through `IFeatureGate`, never via direct SDK calls to `Microsoft.FeatureManagement` or the App Configuration client.** Preserves backend reversibility (D15 escalation), audit hookup (D10), and PII scrubbing on log emission. See ADR-0055 D4, D10, D15.
   - **Feature-flag names follow `{category}.{node}.{feature}` and are registered in the consuming Node's `featureflags.json` before first use.** CI gate per ADR-0055 D6; regex `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$`; the category prefix makes the lifecycle policy (D1, D7) visible at every use site.
   - Create a new `## Feature Flag Invariants` section. The file's existing sectioning convention groups invariants by topic — Dependency, Context, Secrets, Packaging, Testing, AI, Audit, etc. Feature flags is a new cross-cutting topic and warrants its own section. Place it after the `## Audit Invariants` section (or after whichever section ends the current file at edit time).
6. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. Use the existing initiative entry pattern (Status, Scope, Initiative slug, Board link, Description, per-wave Tracking lists, Exit criteria).

## Affected Files
- `adrs/ADR-0055-feature-flag-and-progressive-rollout-strategy.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.

## Acceptance Criteria
- [ ] ADR-0055 header reads `**Status:** Accepted`
- [ ] The ADR-0055 row in `adrs/README.md` reflects Accepted
- [ ] `constitution/invariant-reservations.md` carries a new row in the **Active Reservations** table claiming a contiguous block of size 2 for ADR-0055 at the live `max + 1` (the ceiling above any existing Active Reservation), with packet 00's path in the Notes column
- [ ] `constitution/invariants.md` carries the two new feature-flag invariants (flags evaluated through `IFeatureGate` only; flag names follow `{category}.{node}.{feature}` and are registered in `featureflags.json`) under a new `## Feature Flag Invariants` section, each citing ADR-0055
- [ ] The two new invariants use exactly the numbers claimed in `invariant-reservations.md` — never reuse a claimed number; never collide with any other Active Reservation
- [ ] `initiatives/active-initiatives.md` registers the `adr-0055-feature-flags` initiative with a packet checklist mirroring this folder's `dispatch-plan.md` wave structure
- [ ] No catalog schema change in this packet (catalog updates land in packet 01)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0055 D4 — `IFeatureGate` in Kernel.Abstractions; backing in HoneyDrunk.FeatureFlags.** The flag-system abstraction is `IFeatureGate` in `HoneyDrunk.Kernel.Abstractions`; concrete implementation in the new Node `HoneyDrunk.FeatureFlags`; `InMemoryFeatureGate` in `HoneyDrunk.Kernel.Abstractions.Testing` per invariant 15. Folding the implementation into Kernel would couple Kernel to App Configuration and force a Kernel version bump to swap providers — the exact pattern the Abstractions split is designed to prevent.

**ADR-0055 D5 — Naming `{category}.{node}.{feature}`.** Three dot-separated segments: `category` is one of `release` / `permission` / `operational`; `node` is the lowercase owning Node; `feature` is the kebab-case feature identifier. Enforced at registration by the regex `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$` (D6).

**ADR-0055 D6 — Per-Node `featureflags.json` + CI validation.** Each Node consuming flags declares them in a `featureflags.json` file at `src/HoneyDrunk.<Node>/featureflags.json`. CI enforces: every flag used in code is registered (Roslyn analyzer); every registered flag is used or marked `expected_orphan: true`; naming convention; category coherence; release-flag expiry; permission/operational annual-review-due warnings.

**ADR-0055 D10 — Observability.** Every evaluation emits a `feature_flag_evaluated` log line via `HoneyDrunk.Pulse` (per ADR-0040), sampled at 1% for hotpath flags. Permission and operational flips are audit events per ADR-0030.

**ADR-0055 D15 — Escalation path.** App Configuration is the v1 default; the documented escalation triggers (operator workflow pain past ~100 flags, experimentation needs, multi-tenant operator delegation, cost) point to LaunchDarkly or self-hosted GrowthBook. The substrate (`IFeatureGate`, naming, lifecycle, audit hooks, operator CLI) survives the swap; only the backing changes. **Invariant 1 (the first new one) — "evaluated through `IFeatureGate`, never via direct SDK calls" — is what makes the swap possible.**

**ADR-0055 Consequences — Invariants.** ADR-0055 adds exactly two invariants: (1) feature flags are evaluated through `IFeatureGate`, never via direct SDK calls; (2) feature-flag names follow `{category}.{node}.{feature}` and are registered in `featureflags.json` before first use.

## Constraints
- **Acceptance precedes flip.** ADR-0055 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant numbering goes through `constitution/invariant-reservations.md`.** That file is the single coordination surface for in-flight Proposed ADRs; ADR-0055 is not in any pre-reserved batch and must claim its block through `invariant-reservations.md`. At scoping the ceiling is **61** (ADR-0051 holds 54–57); recompute `max + 1` at edit time and claim a contiguous block of size 2. If a sibling ADR's packet 00 lands first, `git pull` produces a conflict on `invariant-reservations.md` — resolve by shifting upward to the new `max + 1`, updating the new invariant numbers in `constitution/invariants.md` to match, and force-pushing the rebased branch (this packet has no `{N-*}` references to update outside `invariants.md` because the two new invariants are stated by content, not by number, in the packets that consume them).
- **New section.** The two feature-flag invariants are a new cross-cutting topic; create a `## Feature Flag Invariants` section rather than appending to an unrelated section. Place it after the `## Audit Invariants` section (or at the file end if a sibling ADR-acceptance packet has added a section there first).
- **Initiative slug length.** `adr-0055-feature-flags` is 22 characters — well under the 39-char `initiative:` slug limit and the 50-char GitHub label cap. No truncation needed.

## Labels
`chore`, `tier-3`, `core`, `docs`, `adr-0055`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0055 to Accepted, add the two feature-flag invariants to `constitution/invariants.md`, and register the feature-flags initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0055 so the remaining packets in this initiative can reference its decisions as live rules.
- Feature: ADR-0055 Feature Flag and Progressive Rollout Strategy rollout, Wave 1.
- ADRs: ADR-0055 (primary), ADR-0008 (initiative/packet conventions).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- Acceptance precedes flip — ADR-0055 stays Proposed until this PR merges.
- Claim the invariant block via `constitution/invariant-reservations.md` (add a row to **Active Reservations** at the live `max + 1`, block size 2). Use those exact numbers when writing the two invariants into `constitution/invariants.md`. Never reuse a claimed number; resolve any merge conflict on `invariant-reservations.md` by shifting upward to the new ceiling.
- Create a new `## Feature Flag Invariants` section after `## Audit Invariants`.

**Key Files:**
- `adrs/ADR-0055-feature-flag-and-progressive-rollout-strategy.md`
- `adrs/README.md`
- `constitution/invariant-reservations.md`
- `constitution/invariants.md`
- `initiatives/active-initiatives.md`

**Contracts:** None changed.
