# Dispatch Plan: Abstractions Versioning and Deprecation Policy (ADR-0035)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0035 acceptance).
**Trigger:** ADR-0035 (Abstractions Versioning and Deprecation Policy) — Proposed 2026-05-21, part of the 2026-05-21 batch of cross-cutting Grid-gap ADRs. Scoped now so the packet set is ready when the ADR lands. ADR-0035 D10 and ADR-0034 D7 both state the two ADRs "must land together; neither is useful alone."
**Type:** Multi-repo (Architecture, Standards, Actions — plus a per-Node fan-out across 12 package-producing scaffolded Node repos).
**Sector:** Meta + cross-cutting (every package-producing Node is touched by Wave 3's adoption fan-out).
**Site sync required:** No. Versioning policy, analyzer config, and CI workflows are not public-facing artifacts on the Studios marketing site. Re-evaluate only if a future "developer / SDK" page surfaces a compatibility/versioning promise — that would be a separate site-sync packet.

**Rollback plan:**
- Architecture-side packets (00, 02) revert cleanly via `git revert` — the ADR flip + invariant additions + the cascade template are docs/text-only with no runtime consumer.
- The `HoneyDrunk.Standards` packet (01) is additive build-tooling — the public-API-analyzer fragment has no consumer until a Node imports it (Wave 3), so reverting has zero consumer impact.
- The `HoneyDrunk.Actions` packet (03) is two additive CI artifacts — `job-api-diff.yml` has no caller until Wave 3 wires it; the `[Obsolete]`-audit is a job inside `pr-core.yml`, a guaranteed no-op in repos with no `[Obsolete]` members, so reverting is safe.
- The Wave 3 fan-out (04) reverts per-repo: restore the prior `Directory.Build.props`, delete the committed `PublicAPI.{Shipped,Unshipped}.txt` files, restore the prior release workflow. No runtime change, no contract change — analyzer config + a surface snapshot only. A partially-reverted state (some repos adopted, some not) is operationally fine; the repos are independent.

## Summary

ADR-0035 decides **version semantics** for the Grid's public `*.Abstractions` packages — the policy that makes the Abstractions-first coupling rule (every stand-up ADR from ADR-0016 through ADR-0031) safe to rely on. The decision: strict SemVer 2.0.0 with an explicit major/minor/patch interpretation (D1); a binary-compatibility guarantee at minor/patch (D2); no default-interface-member additions — new behavior lands on a new interface (D3); public records use `init` named members not positional syntax, enums are extensible-by-default (D4); a pre-release channel with a 14-day `-preview` floor and a 7-day `-rc` floor, no version skips (D5); a 60-day deprecation window for member removals at 1.0+ (D6); major-version cascades scoped as initiatives via a template, not ad-hoc packets (D7); a private-package carve-out — revenue Nodes are not bound by D1–D6 (D8); three CI enforcement gates (D9); and version semantics delegated here while ADR-0034 owns distribution (D10).

This initiative ships **5 packets** (`00`–`04`) across **three waves**:

- **Wave 1** — governance + the two foundational artifacts: ADR acceptance + the three versioning invariants + the Kernel.Abstractions 1.0.0-baseline note (00); the `HoneyDrunk.Standards` public-API-analyzer fragment (01); the abstractions-cascade initiative template (02).
- **Wave 2** — the enforcement mechanism: `job-api-diff.yml` + the `[Obsolete]`-audit job in HoneyDrunk.Actions (03).
- **Wave 3** — execution: the per-Node adoption fan-out (04) across 12 package-producing scaffolded Node repos — import the analyzer fragment, commit the `PublicAPI.Shipped.txt` baseline, bring `[Obsolete]` members into compliance, wire the API-diff gate, confirm the `pr-core.yml`-resident `[Obsolete]`-audit.

**ADR-0034 lands together — separate initiative.** ADR-0035 D10 and ADR-0034 D7 are explicit: the two "must land together; neither is useful alone." ADR-0034 (Public Package Distribution) is scoped under `adr-0034-public-package-distribution`. ADR-0035 governs version *semantics*; ADR-0034 governs *distribution* (feeds, metadata, the publish workflow). Packet 00 here flips ADR-0035 only; its acceptance PR must be merged in the same session as ADR-0034's acceptance PR. The two initiatives are sequenced loosely-parallel and share a release moment.

## Cross-dependency with the ADR-0034 initiative

The two initiatives are deliberately kept as separate folders (no shared packets) but they have real coupling at three points — all noted in the packet bodies:

1. **Acceptance co-landing (hard).** ADR-0035 packet `00` and ADR-0034 packet `00-architecture-adr-0034-acceptance.md` must merge in the same session. Each appends three invariants to `constitution/invariants.md` (six total). **Invariant numbering is pre-reserved, not rebase-coordinated:** the true current maximum in `constitution/invariants.md` is 51 (verified). ADR-0035's reserved block is invariants **57, 58, 59**; ADR-0034's acceptance packet holds its own distinct reserved block. Numbers 57-59 are pre-reserved as part of a 12-ADR batch; if any invariant above 51 lands from outside this batch before merge, shift this block upward, never reuse a number. Neither packet edits the other ADR's file. This is a **merge-time coordination**, not a `dependencies:` edge — the two packets are in different initiative folders and the `packet:NN` form only resolves within one folder, so it cannot be expressed as machine-readable frontmatter. It is called out in both packet 00 bodies and both dispatch plans instead.

2. **Shared `HoneyDrunk.Standards` target (version-bump ownership).** ADR-0035 packet `01` (public-API-analyzer fragment) and ADR-0034 packet `02` (packaging-metadata fragment) both add a build-asset fragment to `HoneyDrunk.Standards`. They are independent fragments — different files, no conflict — but both touch the same solution. **ADR-0034 packet 02 is the sole `HoneyDrunk.Standards` solution-version bumper across this 12-ADR batch.** ADR-0035 packet 01 MUST NOT bump the Standards version — it adds its fragment content and appends to the in-progress `CHANGELOG.md` entry only, regardless of merge order. This is recorded unconditionally in ADR-0035 packet 01's Constraints. No `dependencies:` edge — the two are genuinely parallel and either order is fine.

3. **`job-api-diff.yml` reads nuget.org (soft — ordering preference, not a blocker).** ADR-0035 packet `03`'s API-diff job resolves a package's *previous published version* from nuget.org. nuget.org as the primary public feed is ADR-0034 D1. The job needs no credential (public-package read is anonymous) and is correct against whatever is on nuget.org today, so it is **not hard-blocked** on the ADR-0034 fan-out. But the gate is only *meaningful* once Nodes are actually publishing to nuget.org under `HoneyDrunkStudios` (ADR-0034 packet 05). In practice ADR-0035 Wave 3 and ADR-0034 Wave 3 run in the same window; if ADR-0035 Wave 3 lands first, `job-api-diff.yml` simply has fewer baselines to diff against until ADR-0034's publish fan-out catches up — a clean no-op pass per packet 03's no-baseline handling, not a failure.

There is **no shared artifact** between the two initiatives — ADR-0034's `catalogs/package-feeds.json` and packaging-metadata fragment, and ADR-0035's public-API-analyzer fragment and cascade template, are all distinct files. The coupling is entirely the co-landing moment (point 1), one version-bump etiquette point (point 2), and one ordering preference (point 3).

## Important constraints (from ADR-0035 itself)

- **Strict SemVer — the version number is a breaking-change signal, not a release date.** D1 + the Alternatives section reject CalVer and lockstep versioning. An Abstractions package may be at 1.4.2 while its default backing is at 0.6.0; versions are independent per package.
- **Binary compatibility is the guarantee at minor/patch.** D2 — a binary compiled at the prior minor must continue to load and execute without `MissingMethodException` / `TypeLoadException`. Source compatibility is best-effort only.
- **No default-interface-member additions — ever.** D3 + the Alternatives section. DIM is unsupported on AOT and `netstandard2.0` (TFMs the Grid still emits). New behavior lands on a new interface (`IModelRouter` → `IModelRouter2`). This is now an invariant (added by packet 00).
- **Public records use `init` members, not positional syntax.** D4 — positional records make adding a parameter a binary break. Enums are extensible-by-default; an exhaustive `switch` needs a default arm unless the enum is `<closed/>`.
- **Pre-release windows are calendar floors, not "prove it's safe" gates.** D5 — 14 days `-preview`, 7 days `-rc`, no skips. The Alternatives section: "in market for long enough to be observable" is the axis, not "obvious."
- **The 60-day deprecation window is a 1.0+ guarantee.** D6 — pre-1.0 collapses to "next minor." Every Abstractions package except the post-baseline Kernel is currently pre-1.0.
- **A major cascade is an initiative.** D7 — scoped via the `abstractions-cascade.md` template (packet 02), recording the bumping Node, downstream Nodes, topological order, freeze status, and pre-release dates. This is now an invariant (added by packet 00).
- **Private revenue Nodes are not bound by D1–D6.** D8 — they buy velocity by giving up the public ABI promise. They are excluded from the Wave 3 fan-out. But public Abstractions transitively consumed by a private package are still bound.
- **Kernel.Abstractions is the only 1.0.0 package.** The ADR-0026 `TenantId` strict-typing bump is retroactively declared 1.0.0. No bulk-bump — every other Node reaches 1.0.0 only on deliberate review (Follow-up Work).

## Wave Diagram

### Wave 1 — Governance + foundational artifacts (parallel after packet 00)

Run packet 00 first (ADR acceptance). Packets 01 and 02 may run in parallel with each other after 00 — 01 is a `HoneyDrunk.Standards` build-tooling fragment, 02 is an Architecture template; neither depends on the other.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0035** — flip status, add the three versioning invariants, record the Kernel.Abstractions 1.0.0 baseline, register the initiative — [`00-architecture-adr-0035-acceptance.md`](00-architecture-adr-0035-acceptance.md)
  - Blocked by: nothing.
- [ ] `HoneyDrunk.Standards`: Author the public-API-analyzer + record/enum-evolution `Directory.Build.props` fragment — [`01-standards-public-api-analyzers-props-fragment.md`](01-standards-public-api-analyzers-props-fragment.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0035 D3/D4/D9 as live rules).
- [ ] `HoneyDrunk.Architecture`: Author the abstractions-cascade initiative template — [`02-architecture-abstractions-cascade-initiative-template.md`](02-architecture-abstractions-cascade-initiative-template.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0035 D7 as a live rule).

**Wave 1 exit criteria:**
- ADR-0035 reads `**Status:** Accepted`; the three versioning invariants are in `constitution/invariants.md`; the Kernel.Abstractions 1.0.0-baseline note is recorded; the initiative is registered.
- `HoneyDrunk.Standards` ships the public-API-analyzer fragment (`PublicApiAnalyzers` reference, `PublicAPI.{Shipped,Unshipped}.txt` wiring, switch-exhaustiveness rule), scoped to `$(IsPackable)`.
- `initiatives/templates/abstractions-cascade.md` exists with the six D7 fields.

### Wave 2 — The enforcement mechanism

- [ ] `HoneyDrunk.Actions`: Author `job-api-diff.yml` + the `[Obsolete]`-audit job — [`03-actions-job-api-diff-and-obsolete-audit-workflows.md`](03-actions-job-api-diff-and-obsolete-audit-workflows.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0035 D9), `01` (**hard** — `job-api-diff.yml` diffs the `PublicAPI.{Shipped,Unshipped}.txt` files the packet-01 fragment establishes).

**Wave 2 exit criteria:**
- `job-api-diff.yml` exists, is callable via `workflow_call` with `package-id` / `version` / `declared-bump`, resolves the previous nuget.org version, asserts the surface diff matches the declared bump (no-change for patch, additive-only for minor, any-change for major), no-ops cleanly when there is no baseline, and treats pre-1.0 violations as warnings.
- The `[Obsolete]`-audit fails CI on any `[Obsolete]` member missing a `DiagnosticId` or `UrlFormat`.

### Wave 3 — Execution: per-Node adoption fan-out

- [ ] **Per-Node fan-out**: Adopt the analyzer fragment, commit `PublicAPI.Shipped.txt` baselines, bring `[Obsolete]` members into compliance, wire the API-diff gate, confirm the `[Obsolete]`-audit — across all 12 package-producing scaffolded Nodes — [`04-cross-repo-public-api-baseline-and-api-diff-wiring.md`](04-cross-repo-public-api-baseline-and-api-diff-wiring.md)
  - Blocked by: Wave 1 — `01` (**hard** — each repo imports the fragment); Wave 2 — `03` (**hard** — each repo's release/PR pipeline is wired to call the gates).

**Wave 3 exit criteria:**
- All 12 package-producing scaffolded Nodes import the analyzer fragment, have a committed `PublicAPI.Shipped.txt` baseline + empty `PublicAPI.Unshipped.txt` per packable project, build green, have all `[Obsolete]` members in D6 compliance, call `job-api-diff.yml` from their release pipelines, and have the `pr-core.yml`-resident `[Obsolete]`-audit confirmed active.
- `repos/{Node}/integration-points.md` records each Node's surface-gate enforcement.

## Out-of-scope / deferred items

- **ADR-0034 (Public Package Distribution and NuGet Policy).** Lands together with ADR-0035 (D10 / ADR-0034 D7) but is a separate initiative — `adr-0034-public-package-distribution`. It owns feeds, package metadata, SourceLink, and `job-publish-nuget.yml`. Packet 00's acceptance PR coordinates its merge moment with ADR-0034's. See the "Cross-dependency" section above for the three coupling points.
- **Moving each Node's Abstractions package to 1.0.0.** ADR-0035 Follow-up Work: "Move each Node's Abstractions package to 1.0.0 only on deliberate review; do not bulk-bump." This initiative records *only* the Kernel.Abstractions 1.0.0 baseline (packet 00). Every other Node's 1.0.0 declaration is a future, deliberate, per-Node decision — each is its own small packet when the owning Node is ready to make the GA-grade compatibility promise. Not a packet here.
- **An actual major-version ABI cascade.** Packet 02 authors the *template*; it does not scope a live cascade. There is no major bump in flight. The next cascade (the second instance of the Kernel Adoption Alignment pattern) instantiates the template as its own initiative when triggered.
- **A custom Roslyn analyzer for the D3/D4 rules no shipped analyzer covers.** `PublicApiAnalyzers` + switch-exhaustiveness cover most of D3/D4 mechanically; "no positional records on public surface" and "no default-interface-member additions" are partly review-enforced (packet 01 documents which). A purpose-built analyzer is a possible follow-up but is not in this initiative.
- **Unscaffolded Seed Node adoption.** The 9 AI-sector Seed Nodes (AI, Capabilities, Agents, Memory, Knowledge, Flow, Operator, Evals, Sim) are not yet scaffolded as live package-producing repos — they fail packet 04's inclusion test ("scaffolded repo currently shipping a public `.Abstractions` package") and adopt ADR-0035's tooling as they scaffold, each in its own standup-ADR work. Note: `HoneyDrunk.Observe` is *not* in this deferred bucket — it is an Ops-sector Node whose repo is scaffolded and which already ships `HoneyDrunk.Observe.Abstractions` (v0.1.0), so it IS in the packet 04 fan-out. Packet 04 is pinned to the 12 currently-package-producing scaffolded Nodes.
- **Private revenue Node versioning.** ADR-0035 D8 explicitly carves `HoneyDrunk.Notify.Cloud.*` and future revenue Nodes out of D1–D6. They adopt their own (weaker) rule at standup. ADR-0035's own Operational Consequences note "their internal canary and integration-test coverage must be correspondingly stronger; recorded as a follow-up for ADR-0027" — that follow-up belongs to ADR-0027, not here.
- **Extending the ADR-0016 / ADR-0019 / ADR-0031 contract-shape canaries to cover the D2 binary-compat guarantee.** ADR-0035 D2 says "ADR-0016's contract-shape canary is the test surface; canaries are extended per Node to cover this guarantee." The existing per-Node canaries (invariants 46, 43, 49) already gate shape drift; extending each to assert binary-compat specifically is per-Node canary work. The `job-api-diff.yml` gate (packet 03) is the primary mechanical enforcement of D2 at the package level; per-Node canary extension is a finer-grained follow-up best done by each Node's own audit, not bundled here. Recorded so it is not silently assumed done.

## After filing — board fields and blocking relationships

Filing is **automated**. The `file-packets.yml` workflow in `HoneyDrunk.Architecture` triggers on push to `generated/issue-packets/active/**/*.md` and files every packet, adds it to The Hive, sets board fields from frontmatter, and wires `addBlockedBy` from the `dependencies:` arrays. Do not run `gh issue create` manually.

**Fan-out packet:** packet 04 is a per-Node fan-out — the `file-packets` agent expands it into one issue per repo across the 12 repos in `target_repos` (Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Observe), or files it as a tracking issue with 12 sub-tasks. If at filing time `HoneyDrunk.Audit` is not yet package-publishing, it is dropped from the fan-out and noted.

The `file-packets` pipeline sets Status, Wave, Node, Tier, Actor, Initiative, and ADR fields from frontmatter and wires `addBlockedBy` automatically. For reference, the blocking graph (resolved from each packet's `dependencies:`):

- `01` blocked-by `00` (soft)
- `02` blocked-by `00` (soft)
- `03` blocked-by `00` (soft), `01` (hard)
- `04` blocked-by `01` (hard), `03` (hard) — wired on each per-Node fan-out issue

The acceptance co-landing with ADR-0034 packet 00 is **not** in any `dependencies:` array — it cannot be (cross-initiative `packet:NN` does not resolve, and ADR-0034's packet 00 is not yet a filed issue with a `{Repo}#N` id at scope time). It is a merge-time human coordination, called out in packet 00's body and here.

**Actor:** all 5 packets are `Actor=Agent`. 00 and 02 are docs/template; 01 is build tooling; 03 is CI workflows; 04 is per-repo analyzer config + a generated surface baseline + workflow wiring — all delegable. Packet 00 carries one Human Prerequisite (tagging the Kernel 1.0.0 release — agents never push tags); packet 04 carries Human Prerequisites that are review/confirm steps (review each generated baseline, confirm pinned refs). None makes the *entire* work item human — no `human-only` label on any packet.

Verify a wave landed by checking The Hive for the new items + their blocked-by chains, not by inspecting the workflow log.

## Notes

- **Acceptance precedes flip.** ADR-0035 stays Proposed until packet 00's PR merges — and that PR is coordinated with ADR-0034's acceptance PR (ADR-0035 D10 / ADR-0034 D7, "land together").
- **The three new invariants land in packet 00**, not in a separate `constitution/invariants.md` packet — strict SemVer per D1 (invariant 57), no default-interface-member additions per D3 (invariant 58), major-cascade-is-an-initiative per D7 (invariant 59). The true current maximum invariant in `constitution/invariants.md` is 51 (verified); 57-59 are pre-reserved for ADR-0035 as part of a 12-ADR batch. If any invariant above 51 lands from outside this batch before merge, shift the block upward — never reuse a number. ADR-0034's acceptance packet holds its own distinct reserved block.
- **The Kernel.Abstractions 1.0.0 baseline is recorded, not bulk-applied.** Packet 00 writes the retroactive note; the release tag is a Human Prerequisite (agents never push tags). No other Node is moved to 1.0.0 — that is deliberate per-Node future work.
- **No new repo created, no new ADR, no new runtime contract.** This initiative ships an ADR flip + invariants, one build-tooling fragment, one initiative template, two reusable CI artifacts, and a per-Node analyzer-adoption fan-out. `catalogs/contracts.json` is untouched — `PublicAPI.Shipped.txt` snapshots existing surfaces, it does not define new ones.
- **The `PublicAPI.Shipped.txt` baseline is the load-bearing Wave 3 step.** It is a snapshot of each Node's *currently published* surface — not a cleanup. A wrong baseline silently weakens the gate, which is why packet 04 makes "review each generated baseline before merge" a Human Prerequisite.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).

## Archival

Per ADR-0008 D10, when every **filed and in-scope** packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0035-abstractions-versioning/` folder moves to `archive/adr-0035-abstractions-versioning/` in a single commit. Partial archival is forbidden.

## Revision history

- **2026-05-22 initial scope** — 5 packets across three waves. Drafted ahead of ADR-0035 acceptance per the developer's request; packets are pending-acceptance drafts, not yet filed as GitHub Issues. ADR-0034 noted as a separate, co-landing initiative per ADR-0035 D10 / ADR-0034 D7; the three cross-initiative coupling points are recorded in the "Cross-dependency" section.
