---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Communications
labels: ["chore", "tier-2", "docs", "ops", "adr-0028"]
dependencies: ["packet:01", "packet:02"]
adrs: ["ADR-0028", "ADR-0019"]
accepts: ADR-0028
wave: 2
initiative: adr-0028-event-driven-architecture
node: honeydrunk-communications
---

# Chore: Document the Communications → Notify in-process boundary and Service Bus migration path

## Summary
Add a `## Notify Delivery Boundary` section to `README.md` in `HoneyDrunk.Communications` that documents the concrete `INotificationSender` → `INotificationQueue` boundary settled by ADR-0028 D4: Communications calls Notify in-process via `INotificationSender`, Notify's intake enqueues onto its internal `INotificationQueue`, and Notify's worker consumes the queue. The section also documents the v2 migration path: when scale demands independently-scaled Container Apps for Communications and Notify, the seam moves to Service Bus via the existing `ITransportPublisher` / `ITransportConsumer` abstraction — a host-time composition change, not a code rewrite. Communications repo doc edit only; no behavior change.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Communications`

## Motivation

ADR-0028's "If Accepted — Required Follow-Up Work" checklist line 4 says:

> Add a follow-up packet against Communications to specify the concrete `INotificationSender` → `INotifyQueueWriter` boundary and confirm that Communications dispatches to Notify in-process (not via Transport) — D4 settles the principle; the implementation packet wires it

The implementation has shipped — Communications v0.2.0 takes a first-class runtime dependency on `HoneyDrunk.Notify.Abstractions` per ADR-0019 D5, and its `CommunicationOrchestrator` constructor injects `INotificationSender` from that package and calls it synchronously after the preference/cadence/decision-log checks. The boundary doc, however, does not yet name the boundary at the granularity the ADR's D4 settles. Specifically:

- The current `README.md` says "delegating delivery mechanics to HoneyDrunk.Notify" — true, but doesn't pin the call shape (in-process vs broker).
- The current `boundaries.md` says "Delegating approved delivery to Notify through `INotificationSender` from `HoneyDrunk.Notify.Abstractions`" — true, but doesn't disclose Notify's own internal queue (`INotificationQueue` in `HoneyDrunk.Notify.Queue.Abstractions`) as the first async hop, and doesn't name the v2 Service Bus migration path.

D4 settles the principle: at v1 (single Container App per Node, low/bursty traffic), Communications → Notify is in-process. The seam to Service Bus opens when Notify Cloud's tier ceiling pressures it — at that point, Communications and Notify get separate Container Apps and the call crosses a Service Bus queue via the existing `ITransportPublisher` abstraction. The abstractions are in place; the change is a host-time composition.

The user's prompt names the contract as "`INotifyQueueWriter`" — at the time of scope, the live Notify contract is `INotificationQueue` in `HoneyDrunk.Notify.Queue.Abstractions`. The verb-form "queue writer" maps to the `EnqueueAsync` method on that interface. This packet uses the live contract name (`INotificationQueue`) and surfaces the mapping in the doc.

This packet codifies the boundary in the Communications repo's `README.md` so future readers (and future agents) see the call shape, the in-Node hop, and the migration path in one section. It is documentation-only — no code change, no contract change.

## Scope

Single-file edit in the Communications repo: `README.md`. No other files touched. No code changes. No CHANGELOG-version-bump (this is a docs edit; per the no-Unreleased rule, the entry goes under a new patch version section).

## Proposed Implementation

### Edits to `README.md`

The current `README.md` is short — Status, Packages, Canonical Node Entry. Add a new top-level section after "Packages" (before "Canonical Node Entry"):

```markdown
## Notify Delivery Boundary

Communications delegates approved sends to Notify by calling `INotificationSender` from `HoneyDrunk.Notify.Abstractions`. The boundary is **in-process** at v1: `INotificationSender` is registered in the same DI container as `ICommunicationOrchestrator`, and the call is a synchronous method invocation, not a broker hop.

### Call shape at v1

```
caller → ICommunicationOrchestrator.SendAsync(intent)
       → recipient resolution
       → IPreferenceStore + ICadencePolicy check
       → ICommunicationDecisionLog append
       → INotificationSender.SendAsync(envelope)   ← in-process call into HoneyDrunk.Notify
            → Notify intake validates the envelope
            → Notify intake enqueues onto INotificationQueue (HoneyDrunk.Notify.Queue.Abstractions)
            → Notify worker dequeues and dispatches via provider adapter (SMTP, Resend, Twilio, ...)
```

The first async hop in the path is Notify's **own internal** queue — `INotificationQueue` in `HoneyDrunk.Notify.Queue.Abstractions`. That queue is a Notify-internal concern (Notify intake writes, Notify worker reads, both inside the Notify Container App) and is intentionally **not** routed through `HoneyDrunk.Transport`. The Transport boundary doc explicitly disclaims this surface: "Queue management for notifications belongs in Notify."

### Why in-process at v1

- Communications and Notify ship as one Container App in the v1 Notify Cloud deployment. A single deployable composes Communications + Notify; no Node boundary is crossed.
- The single most-trafficked seam the Grid is about to ship is Communications → Notify. Putting a broker between them at v1 adds latency, failure modes, and ~$10/mo of Service Bus namespace cost for no boundary-crossing benefit.
- The abstractions are already in place. When the seam needs to move to a broker, the call site is unchanged — only the DI registration swaps.

### v2 migration path (Service Bus)

When Notify Cloud's tier ceiling pressures the deployment — different replica counts for Communications and Notify, different scaling triggers, different release cadences — the path is:

1. Split Communications and Notify into separate Container Apps within the shared Container Apps Environment.
2. Provision a Service Bus queue (`sbq-communications-notify-{env}`) in the existing shared namespace (`sbns-hd-shared-{env}`).
3. Register `ITransportPublisher` against `HoneyDrunk.Transport.AzureServiceBus` in Communications' composition.
4. Replace the in-process `INotificationSender` registration with a Transport-backed implementation that publishes the envelope onto the queue.
5. Register a Transport consumer in Notify's composition that reads the queue and invokes the existing internal `INotificationSender`.

No application code in either Node changes. The orchestrator still calls `INotificationSender.SendAsync(envelope)`; the registered implementation changes from "synchronous in-process call" to "publish onto a Service Bus queue and return." The consumer side resolves to the existing Notify implementation that enqueues onto `INotificationQueue`. The abstractions seam is the migration boundary — `INotificationSender` is the seam, and the `HoneyDrunk.Transport.*` packages are already part of the Grid.

### What this section is not

- It is not a contract change. `INotificationSender` and `INotificationQueue` are not modified by this section.
- It is not a behavior change. The current v0.2.0 runtime already calls `INotificationSender` in-process; this section documents that choice.
- It is not a deployment trigger. The v2 migration is gated on tier-ceiling pressure, not on this packet. No Service Bus provisioning happens here.

### References

- ADR-0028 D4 — Communications → Notify is in-process at v1; Service Bus when scale demands it.
- ADR-0028 D5 — Service Bus shared namespace (`sbns-hd-shared-{env}`), Standard tier, queues named `sbq-{purpose}-{env}`.
- ADR-0019 D5 — Communications takes a first-class runtime dependency on `HoneyDrunk.Notify.Abstractions`. The dependency direction is settled; this section documents what rides over it.
- ADR-0015 — Container Apps hosting platform (per-Node Container Apps within a shared environment).
```

### `CHANGELOG.md` (Communications repo)

Per the Grid's no-Unreleased convention (use a dated versioned section + SemVer bump before committing), add a new patch version section above the most-recent existing version entry. The CHANGELOG today has v0.2.0 as the most-recent entry; this packet adds v0.2.1 as a docs-only patch bump.

The `Directory.Build.props` (or equivalent version source) bumps from `0.2.0` to `0.2.1` for both packages in the solution (per the all-projects-in-a-solution-share-one-version rule). Both `HoneyDrunk.Communications.Abstractions` and `HoneyDrunk.Communications` move together even though only the runtime package has a doc change; this is consistent with the alignment-bump rule (per-package CHANGELOGs are updated only for packages with actual changes — but here the README is at the repo root, not per-package, so only the repo-level CHANGELOG gets an entry).

New CHANGELOG entry. The existing repo CHANGELOG carries a rolling `## Unreleased` section with two pre-existing `### Internal` entries (a coverage backfill to 83.4% + Grid PR coverage gate baseline; a PR-validation split for read-only contents permissions). Per the no-Unreleased-commits rule, those entries must be **folded into the new dated `## 0.2.1 - 2026-05-20` section** alongside the new `### Changed` entry, and the `## Unreleased` header itself must be removed. The repo's existing convention uses bracket-free version headers (e.g., `## 0.2.0 - 2026-05-18`); the new section matches.

Final consolidated CHANGELOG state after this packet's edits (the new section replaces both `## Unreleased` and sits above `## 0.2.0 - 2026-05-18`):

```markdown
## 0.2.1 - 2026-05-20

### Changed
- README: documented the Communications → Notify in-process delivery boundary per ADR-0028 D4. Includes the v1 call shape (`INotificationSender` synchronous call → Notify intake → `INotificationQueue` → Notify worker), the rationale for in-process at v1, and the v2 Service Bus migration path (host-time DI composition change via the existing `ITransportPublisher` abstraction; no code change). Documentation-only — no behavior change, no contract change.

### Internal
- Backfilled Communications test coverage to 83.4% and seeded the Grid PR coverage gate baseline at 83.3% to avoid rounded-threshold drift.
- Split PR validation from the default-branch coverage baseline ratchet so pull requests keep read-only contents permissions.
```

If filing slips past 2026-05-20, the agent uses the **actual filing date** in the section header (e.g., `## 0.2.1 - 2026-05-22`) — the date is the date the version is cut, not the date this packet was authored.

Per-package CHANGELOGs (`src/HoneyDrunk.Communications/CHANGELOG.md` and `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md`) are **not** updated for this docs-only repo-root edit — the alignment-bump rule (invariant 27) is explicit that per-package CHANGELOGs add noise entries only when the package itself has functional changes. The README is not part of either package.

### Version bump

The version source (`Directory.Build.props` or equivalent) bumps from `0.2.0` to `0.2.1`. Both projects in the solution move together (invariant 27). The bump is a patch — no public surface changes, no breaking changes, no new feature; documentation clarification only.

Per the no-manual-tag-push rule, the agent does **not** push a git tag for the v0.2.1 release. Tag pushes are user-driven.

## Affected Files
- `README.md` (append the `## Notify Delivery Boundary` section before `## Canonical Node Entry`)
- `CHANGELOG.md` (new `## 0.2.1 - 2026-05-20` section, bracket-free per repo convention; fold the existing `## Unreleased` Internal entries into this new dated section and delete the `## Unreleased` header)
- `Directory.Build.props` (version `0.2.0` → `0.2.1`) — if the version is sourced elsewhere (e.g., per-`csproj`), bump each project file in the solution (excluding test projects) consistently

## NuGet Dependencies
None. This packet does not add or remove `PackageReference` entries on any project. No code change.

## Boundary Check
- [x] Target is the Communications repo (`HoneyDrunk.Communications`) — correct per the user's prompt and per the ADR's "follow-up packet against Communications" line.
- [x] No code changes — `README.md`, `CHANGELOG.md`, and the version source file only.
- [x] No contract changes. `INotificationSender` (in `HoneyDrunk.Notify.Abstractions`), `INotificationQueue` (in `HoneyDrunk.Notify.Queue.Abstractions`), `ITransportPublisher` (in `HoneyDrunk.Transport`) — all referenced by name in the documentation, none modified.
- [x] No invariant violations. The version bump respects invariants 12 and 27 (semver, all-projects-move-together). The per-package CHANGELOG rule is respected (no alignment-bump noise on per-package CHANGELOGs). No new public API surface, so no README updates beyond this packet's own section.
- [x] Communications boundary preserved. The new section confirms what is already true (Communications calls `INotificationSender` in-process); it does not introduce new responsibilities or remove existing ones.

## Acceptance Criteria
- [ ] `README.md` has a new `## Notify Delivery Boundary` section placed after `## Packages` and before `## Canonical Node Entry`.
- [ ] The section includes the call-shape fenced block (caller → `ICommunicationOrchestrator.SendAsync` → preference + cadence + decision log → `INotificationSender.SendAsync` → Notify intake → `INotificationQueue` → Notify worker).
- [ ] The section names `INotificationQueue` in `HoneyDrunk.Notify.Queue.Abstractions` explicitly as Notify's internal queue (the first async hop in the path), and explicitly states that this queue is **not** routed through `HoneyDrunk.Transport`.
- [ ] The section includes the "Why in-process at v1" subsection with at least the three bullets from the Proposed Implementation (single-Container-App composition; most-trafficked seam doesn't need a broker at v1; abstractions already in place for the v2 swap).
- [ ] The section includes the "v2 migration path (Service Bus)" subsection with the five-step sequence (split Container Apps; provision Service Bus queue; register `ITransportPublisher`; swap `INotificationSender` registration; register Transport consumer in Notify). The five steps must explicitly state that **no application code in either Node changes** — the swap is host-time DI composition only.
- [ ] The section includes the "References" subsection naming ADR-0028 D4, ADR-0028 D5, ADR-0019 D5, and ADR-0015.
- [ ] `CHANGELOG.md` has a new `## 0.2.1 - 2026-05-20` section (bracket-free header, matching the repo's existing convention — `## 0.2.0 - 2026-05-18` is the immediate predecessor) under `### Changed` with the docs-only entry described in the Proposed Implementation.
- [ ] **If the packet is filed/landed after 2026-05-20, the agent uses the actual landing date in the section header** (e.g., `## 0.2.1 - 2026-05-22`). The date is the date the version is cut, not the date this packet was authored. Do not ship a `## 0.2.1 - 2026-05-20` section if the PR merges on a later date.
- [ ] Fold the existing `## Unreleased` content into `## 0.2.1 - 2026-05-20` under appropriate `### Internal` subsections alongside the new `### Changed` entry; do **not** leave an `## Unreleased` section in the file. The two existing `### Internal` entries (coverage backfill to 83.4% + Grid PR coverage gate baseline; PR-validation split for read-only contents permissions) belong inside the new dated section, not above it.
- [ ] The version source for both `HoneyDrunk.Communications` and `HoneyDrunk.Communications.Abstractions` is bumped to `0.2.1`. Both projects in the solution move together (invariant 27); test projects are excluded from the bump.
- [ ] Per-package CHANGELOGs (`src/HoneyDrunk.Communications/CHANGELOG.md` and `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md`) are **not** edited — no alignment-bump noise (invariant 27).
- [ ] The agent does not push a git tag for v0.2.1; tag pushes are user-driven.
- [ ] No code file in `src/**` or `tests/**` is modified. No `.cs`, no `.csproj` other than the version-source bump if it lives in per-`csproj` (and even then only the `<Version>` element).
- [ ] PR description references this packet (per the PR-to-packet linking invariant inlined below).
- [ ] PR description states explicitly: this is a documentation packet that codifies the existing v1 in-process call shape and the v2 Service Bus migration path. No behavior change. No contract change. No deployment trigger.

## Human Prerequisites
None. This packet is fully delegable; the agent edits two doc files and the version source, then opens a PR.

## Referenced ADR Decisions

**ADR-0028 D4 (Communications → Notify is in-process at v1, Service Bus when scale demands it):**

> At v1 (single Container App per Node, low/bursty traffic), the call is in-process. Communications resolves intent, checks preferences and cadence, then synchronously invokes Notify's `INotificationSender`. Notify's *own internal* queue (Notify intake → Notify worker, use case #3) is the first async hop. This matches the existing design and the behavior Notify already ships.
>
> The seam to Service Bus opens when Notify Cloud's tier ceiling pressures it... If Notify Cloud sustains a load where Communications and Notify benefit from being independently scaled — different replica counts, different Container Apps — the path is to introduce a Service Bus queue between them via the existing `ITransportPublisher` / `ITransportConsumer` abstraction. **Communications already composes Transport in its planned dependencies** (Communications → Transport is implied by orchestration over a queue); the abstractions are in place. The change is a host-time composition, not a code rewrite.

The documentation section produced by this packet is the operational form of D4.

**ADR-0028 D5 (Service Bus shared namespace per environment):** `sbns-hd-shared-{env}` for `dev`/`stg`/`prod`, Standard tier, queues `sbq-{purpose}-{env}`. The v2 migration path documented in this packet uses `sbq-communications-notify-{env}` as the queue name pattern, matching this rule.

**ADR-0019 D5 (Communications takes a first-class runtime dependency on `HoneyDrunk.Notify.Abstractions`):** Communications composes `HoneyDrunk.Notify.Abstractions` directly; downstream Nodes consume only `HoneyDrunk.Communications.Abstractions`. This packet does not change that direction — it documents what rides over the dependency.

**ADR-0015 (Container Apps hosting platform):** Containerized deployable Nodes run on Azure Container Apps within a shared Container Apps Environment per environment. The v2 migration path documented in this packet lives inside that environment — no cross-environment routing, no per-Node environments.

## Referenced Invariants

> **Invariant 12:** Semantic versioning with `CHANGELOG.md` and `README.md`. Every shipped change gets an entry in the repo-level changelog. — This packet bumps the version from `0.2.0` to `0.2.1` (patch, docs-only) and adds a repo-level CHANGELOG entry.

> **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo. No work tracked exclusively in packet files, chat logs, or external tools.

> **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. Partial bumps are forbidden. **The first packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only. The repo-level `CHANGELOG.md` must always get an entry for the new version. Per-package changelogs are updated only for packages with actual changes — do not add alignment-bump noise entries.** — This packet is the only Communications-repo packet in this initiative, so it both bumps the version and appends the entry. Per-package CHANGELOGs stay untouched.

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR receives a degraded review.

> **Invariant 40:** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`. Composition against `HoneyDrunk.Communications` is a host-time concern. — Not violated; this packet does not change Communications' public dependency surface.

> **Invariant 41:** Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify. Notify owns delivery mechanics; Communications owns decision logic. — Not violated; the new section reaffirms this split (preference + cadence + decision-log checks happen in Communications before `INotificationSender.SendAsync` is called).

## Dependencies

Blocked by packets 01 and 02 of this initiative. The new section's "References" subsection points at ADR-0028 D4 (settled by the ADR itself), but the developer-facing reference for "which backing serves which use case" lives in the Transport repo's `integration-points.md` (packet 01) and the "no telemetry on Transport" rule lives in Transport's `boundaries.md` (packet 02). Both must merge before this packet's Communications-side doc lands so the cross-references are not dangling.

Packet 03 (Pulse boundaries) is independent — Pulse is not on Communications' call path and is not referenced by this packet's new section. No dependency on packet 03.

## Labels
`chore`, `tier-2`, `docs`, `ops`, `adr-0028`

## Agent Handoff

**Objective:** Add a `## Notify Delivery Boundary` section to `HoneyDrunk.Communications/README.md` documenting the v1 in-process `INotificationSender` → `INotificationQueue` call shape and the v2 Service Bus migration path (host-time DI composition change via the existing `ITransportPublisher` abstraction). Bump the solution version from `0.2.0` to `0.2.1` and append the corresponding repo-level CHANGELOG entry. No code changes; no per-package CHANGELOG edits; no git-tag push.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Communications`, branch from `main`.

**Context:**
- Goal: Codify the Communications → Notify boundary at the call-shape level so future readers see the in-process choice, the Notify-internal queue (`INotificationQueue`) as the first async hop, and the host-time migration path to Service Bus in one place.
- Feature: ADR-0028 Event-Driven Architecture and Messaging, Wave 2.
- ADRs: ADR-0028 (Proposed at edit time; auto-flipped to Accepted by hive-sync after all four packets in this initiative close). ADR-0019 (Accepted — settled the dependency direction; this packet documents what rides over it). ADR-0015 (Container Apps hosting platform — referenced in the migration-path subsection).

**Acceptance Criteria:** As listed above.

**Dependencies:** packet:01 (Transport `integration-points.md` matrix), packet:02 (Transport `boundaries.md` scope clarification).

**Constraints:**

- **Invariant 12:** Semantic versioning with `CHANGELOG.md` and `README.md`. Breaking changes bump major; new features bump minor; fixes bump patch. Every shipped change gets an entry in the repo-level changelog. This packet is a docs-only patch bump (`0.2.0` → `0.2.1`).

- **Invariant 23:** Every tracked work item has a GitHub Issue in its target repo.

- **Invariant 27:** All projects in a solution share one version and move together. When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. Partial bumps are forbidden. Per-package CHANGELOGs are updated only for packages with actual changes — do not add alignment-bump noise entries. The repo-level `CHANGELOG.md` always gets an entry for the new version.

- **Invariant 32:** Agent-authored PRs must link to their packet in the PR body.

- **No code, no contracts.** Do NOT modify any `.cs` file. Do NOT modify `INotificationSender`, `INotificationQueue`, `ITransportPublisher`, or any other contract referenced in the new section. Do NOT change `INotificationSender`'s name to `INotifyQueueWriter` — the user's prompt used that name informally; the live contract is `INotificationSender` (in `HoneyDrunk.Notify.Abstractions`) and `INotificationQueue` (in `HoneyDrunk.Notify.Queue.Abstractions`). Reference the live names; do not rename.

- **No deployment trigger.** The v2 migration-path subsection is a forward-looking description, not an action. Do NOT provision any Service Bus namespace, queue, or Container App. Do NOT modify `Directory.Build.props` deployment targets. The migration is gated on tier-ceiling pressure, not on this packet.

- **No per-package CHANGELOG edits.** The README is at the repo root, not inside a package. Only the repo-level `CHANGELOG.md` is updated. `src/HoneyDrunk.Communications/CHANGELOG.md` and `src/HoneyDrunk.Communications.Abstractions/CHANGELOG.md` stay untouched (the alignment-bump-without-functional-changes case).

- **No git-tag push.** The version bump prepares the release; the user pushes the tag when ready. Do not run `git tag` or `git push --tags`.

- **No edits outside Communications repo.** Do not touch `HoneyDrunk.Transport`, `HoneyDrunk.Notify`, `HoneyDrunk.Architecture`, or any other repo. This is a Communications-repo packet only.

- **No changes to `boundaries.md` in the Communications repo's Architecture-side context folder.** The user direction is explicit: this initiative does not touch shared index files or other-repo context files. The Communications repo's own `README.md` is the only doc target for this packet. (The Communications context folder lives in `HoneyDrunk.Architecture/repos/HoneyDrunk.Communications/` — separate repo, separate concern.)

**Key Files:**
- `README.md` — append the `## Notify Delivery Boundary` section before `## Canonical Node Entry`
- `CHANGELOG.md` — new `## 0.2.1 - 2026-05-20` section (bracket-free, matching the repo's existing `## 0.2.0 - 2026-05-18` convention); fold the existing `## Unreleased` Internal entries into the new dated section and remove the `## Unreleased` header
- `Directory.Build.props` (or per-`csproj` if the version is sourced there) — bump `0.2.0` → `0.2.1` for both runtime projects, exclude test projects

**Contracts:**
- `INotificationSender` (existing, in `HoneyDrunk.Notify.Abstractions`) — referenced by name; not modified.
- `INotificationQueue` (existing, in `HoneyDrunk.Notify.Queue.Abstractions`) — referenced by name; not modified.
- `ITransportPublisher` / `ITransportConsumer` (existing, in `HoneyDrunk.Transport`) — referenced by name in the migration-path subsection; not modified.
- `ICommunicationOrchestrator` (existing, in `HoneyDrunk.Communications.Abstractions`) — referenced by name in the call-shape block; not modified.
