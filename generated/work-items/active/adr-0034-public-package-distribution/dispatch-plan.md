# Dispatch Plan: Public Package Distribution and NuGet Policy (ADR-0034)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0034 acceptance).
**Trigger:** ADR-0034 (Public Package Distribution and NuGet Policy) — Proposed 2026-05-21, part of the 2026-05-21 batch of cross-cutting Grid-gap ADRs. Scoped now so the packet set is ready when the ADR lands. ADR-0034 sits in `current-focus.md`'s "Future / Watch — Commercial / substrate ADRs (0034–0042, 0045)" group, gated on the "first external NuGet consumer" forcing function — which ADR-0034's own Context says has effectively arrived (Notify Cloud SDK per PDR-0002/ADR-0027).
**Type:** Multi-repo (Architecture, Standards, Actions, Vault — plus a per-Node fan-out across 11 package-producing Node repos).
**Sector:** Meta + cross-cutting (every package-producing Node is touched by Wave 3's adoption fan-out).
**Site sync required:** No. Package-distribution policy, feed configuration, and CI workflows are not public-facing artifacts on the Studios marketing site. Re-evaluate only if a future "developer / SDK" page on the Studios site surfaces install instructions — that would be a separate site-sync packet.

**Rollback plan:**
- Architecture-side packets (00, 01) revert cleanly via `git revert` — the ADR flip + invariant additions are docs/text-only; `catalogs/package-feeds.json` is a new file with no consumer until ADR-0032's leak check reads it (out of this initiative's scope), so deleting it has no consumer impact.
- The `HoneyDrunk.Standards` packet (02) is additive build-tooling — the packaging-metadata fragment has no consumer until a Node imports it (Wave 3), so reverting has zero consumer impact.
- The `HoneyDrunk.Actions` packet (03) is an additive reusable workflow — no consumer calls `job-publish-nuget.yml` until Wave 3's fan-out amends release workflows; reverting is safe.
- The signing-certificate packet (04) is human/portal work — "reverting" means not procuring the cert; `job-publish-nuget.yml` already publishes unsigned conditionally, so the absence of a cert is the pre-packet-04 steady state, not a broken state.
- The Wave 3 fan-out (05) reverts per-repo: restore the prior `Directory.Build.props`, the prior per-project metadata, and the inline `dotnet nuget push` in the release workflow. No runtime change, no contract change — packaging metadata only. A partially-reverted state (some repos adopted, some not) is operationally fine; the repos are independent and each publishes through its own release workflow.

## Summary

ADR-0034 decides **where and how** the Grid's public packages are distributed. The decision: nuget.org under a single `HoneyDrunkStudios` owner account as the primary public feed (D1); GitHub Packages for private revenue Nodes (D2); Azure Artifacts retained only as a pre-release staging surface (D1); thirteen required, CI-enforced package-metadata fields (D3); SourceLink + symbols + deterministic builds, non-negotiable (D4); author-signing gated on the BDR-0001 entity finalization, with repository signing unconditional (D5); a single `job-publish-nuget.yml` reusable workflow in HoneyDrunk.Actions that every Node's release workflow calls (D6); version *semantics* delegated to ADR-0035 (D7); and the approved-feeds list recorded as `catalogs/package-feeds.json` (D8).

This initiative ships **6 packets** (`00`–`05`) across **three waves**:

- **Wave 1** — governance + the two foundational artifacts: ADR acceptance (00), the feeds catalog (01), the shared packaging-metadata fragment (02).
- **Wave 2** — the publish mechanism: `job-publish-nuget.yml` in HoneyDrunk.Actions (03).
- **Wave 3** — execution: the per-Node adoption fan-out (05) across 11 package-producing Node repos, and the signing-certificate procurement (04).

**ADR-0035 lands together — separate initiative.** ADR-0034 D7 is explicit: ADR-0034 and ADR-0035 "must land together; neither is useful alone." ADR-0035 (Abstractions Versioning and Deprecation Policy) is scoped under its own initiative folder. Packet 00 here flips ADR-0034 only; its acceptance PR must be merged in the same session as ADR-0035's acceptance PR. The two initiatives are sequenced loosely-parallel: ADR-0035 governs version *semantics* (SemVer rules, deprecation windows, the API-diff job) while ADR-0034 governs *distribution* (feeds, metadata, the publish workflow). They share no packet but they share a release moment.

## Important constraints (from ADR-0034 itself)

- **nuget.org is the primary public feed — not GitHub Packages, not Azure Artifacts.** D1 + the Alternatives section. GitHub Packages requires authenticated pulls (breaks "install without an account"); Azure Artifacts is tenant-locked. Both rejected as the primary surface.
- **Per-slot package identity is non-negotiable.** The Alternatives section rejects "one package per repo" — external consumers must take `HoneyDrunk.<Node>.Abstractions` without dragging in a default backing. Every packable project gets its own `PackageId`.
- **Author-signing is gated on BDR-0001.** D5 — the code-signing certificate's subject must match the finalized legal entity name. Until the Sunbiz amendment lands, packages publish **unsigned**, and `job-publish-nuget.yml` logs an explicit `Publishing UNSIGNED` line. Repository signing (nuget.org server-side) is unconditional and independent.
- **Publish runs through the one reusable workflow.** D6 + the new invariant — no consumer repo calls `dotnet nuget push` directly. The whole point of D6 is the ADR-0012 control-plane rule.
- **`catalogs/package-feeds.json` is the single source of truth.** D8 — feed lists are not duplicated into ADR text or README tables; those reference the catalog.
- **No long-lived PATs.** D2/D5 — nuget.org via a Vault-stored API key, GitHub Packages and the signing-cert fetch via federated OIDC tokens.
- **Private packages are scoped separately.** ADR-0034 governs only the *public* surface; `HoneyDrunk.Notify.Cloud.*` and future revenue Nodes (ADR-0027 D2) use the GitHub Packages private path and adopt the conventions in their own standup — out of this initiative.

## Wave Diagram

### Wave 1 — Governance + foundational artifacts (parallel after packet 00)

Run packet 00 first (ADR acceptance). Packets 01 and 02 may run in parallel with each other after 00 — 01 is an Architecture catalog, 02 is `HoneyDrunk.Standards` build tooling; neither depends on the other.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0034** — flip status, add the three packaging invariants, register the initiative — [`00-architecture-adr-0034-acceptance.md`](00-architecture-adr-0034-acceptance.md)
  - Blocked by: nothing.
- [ ] `HoneyDrunk.Architecture`: Create `catalogs/package-feeds.json` — the approved-feeds allowlist — [`01-architecture-package-feeds-catalog.md`](01-architecture-package-feeds-catalog.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0034 D8 as a live rule).
- [ ] `HoneyDrunk.Standards`: Author the shared packaging-metadata + SourceLink `Directory.Build.props` fragment — [`02-standards-packaging-metadata-props-fragment.md`](02-standards-packaging-metadata-props-fragment.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0034 D3/D4 as live rules).

**Wave 1 exit criteria:**
- ADR-0034 reads `**Status:** Accepted`; the three packaging invariants are in `constitution/invariants.md`; the initiative is registered.
- `catalogs/package-feeds.json` exists with the three feeds (`nuget-org-public`, `github-packages-private`, `azure-artifacts-prerelease`) and is indexed.
- `HoneyDrunk.Standards` ships the packaging-metadata + SourceLink fragment and the build-failing metadata-enforcement target.

### Wave 2 — The publish mechanism

- [ ] `HoneyDrunk.Actions`: Author `job-publish-nuget.yml` — the single reusable package-publish workflow — [`03-actions-job-publish-nuget-workflow.md`](03-actions-job-publish-nuget-workflow.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0034 D6), `01` (**hard** — the workflow validates the `feed` input against `catalogs/package-feeds.json`).

**Wave 2 exit criteria:**
- `job-publish-nuget.yml` exists, is callable via `workflow_call` with `package-id` / `version` / `feed`, validates `feed` against the catalog, handles auth + conditional signing + push + post-publish metadata verification, and pushes `.snupkg` alongside.

### Wave 3 — Execution: adoption fan-out + signing

Packets 04 and 05 are independent of each other and may run in parallel. Packet 04 is hard-gated on BDR-0001; packet 05 is not.

- [ ] **Per-Node fan-out**: Adopt the packaging-metadata fragment + `job-publish-nuget.yml` across all 11 package-producing Nodes — [`05-cross-repo-adopt-packaging-metadata-and-publish-workflow.md`](05-cross-repo-adopt-packaging-metadata-and-publish-workflow.md)
  - Blocked by: Wave 1 — `02` (**hard** — each repo imports the fragment); Wave 2 — `03` (**hard** — each repo's release workflow is amended to call the workflow).
- [ ] `HoneyDrunk.Vault`: Procure + seed the code-signing certificate, enable author-signing — [`04-vault-signing-certificate-procurement.md`](04-vault-signing-certificate-procurement.md)
  - Blocked by: Wave 2 — `03` (**hard** — the workflow with the conditional sign stage must exist; this packet provisions the cert that activates it).
  - **`Actor=Human` — `human-only` label set.** Procuring a CA certificate and the portal-only Key Vault import cannot be delegated.
  - **HARD PRECONDITION — do not file until BDR-0001 lands.** ADR-0034 D5 holds cert procurement until the Sunbiz amendment finalizes the legal entity name. The `file-work-items` agent holds this packet until the human confirms BDR-0001 is complete. Until then it stays in `active/` as a held draft. This does not block the rest of the initiative — packets 00–03 and 05 publish unsigned in the interim, exactly as ADR-0034 D5 specifies.

**Wave 3 exit criteria:**
- All 11 package-producing Nodes import the metadata fragment, set per-project + Node-level metadata, pack per-package READMEs, produce SourceLink + `.snupkg`, and call `job-publish-nuget.yml` from their release workflows — no `dotnet nuget push` remains anywhere.
- `repos/{Node}/integration-points.md` records each Node's published feed.
- **Wave 3 fan-out completion means the publish workflow is WIRED into every repo's release workflow — not that any package has actually published to nuget.org.** Actual publishing requires the human prerequisites from packet 03 (the `HoneyDrunkStudios` nuget.org account claimed, the API key seeded into Vault, the federated-OIDC trust configured). The fan-out's exit criterion is "calls `job-publish-nuget.yml` and the build/pack is green," not "a `.nupkg` is live on nuget.org." First real publish happens on each repo's next release run once the nuget.org credentials exist.
- *Conditional:* if BDR-0001 lands within the wave, the code-signing certificate is procured + seeded and published packages flip from unsigned to author-signed (packet 04). If BDR-0001 has not landed, Wave 3 exits on packet 05 alone; packet 04 is filed later when BDR-0001 clears, without re-opening the wave.

## Out-of-scope / deferred items

- **ADR-0035 (Abstractions Versioning and Deprecation Policy).** Lands together with ADR-0034 (D7) but is a separate initiative — `adr-0035-abstractions-versioning`. ADR-0035 owns version semantics, the `-preview.N`/deprecation windows, `Microsoft.CodeAnalysis.PublicApiAnalyzers`, and the API-diff job. This initiative owns distribution only. Packet 00's acceptance PR coordinates its merge moment with ADR-0035's.
- **The ADR-0032 NuGet-leak PR check that *reads* `package-feeds.json`.** ADR-0034 D8 says ADR-0032's leak check "reads this catalog as the allowlist," and ADR-0034's Context names ADR-0032 as a forcing function. But ADR-0032 is itself Proposed and its current text carries no feed/allowlist check. Building the leak check is ADR-0032's own scope, not ADR-0034's. This initiative produces the *catalog* (packet 01, the artifact ADR-0034 owns); ADR-0032's check consuming it is correctly deferred to ADR-0032's scope/initiative. Recorded here so it is not silently assumed done.
- **Private revenue Node distribution (`HoneyDrunk.Notify.Cloud.*`, ADR-0027).** ADR-0034 governs only the public surface (its Context is explicit). The GitHub Packages private path (D2) is built into `job-publish-nuget.yml` (`feed: github-packages-private`), but no private Node is scaffolded yet — Notify Cloud adopts the `feed: github-packages-private` path in its own ADR-0027 standup initiative. Not a packet here.
- **Seed Node adoption.** The 10 AI-sector + Observe Seed Nodes adopt the ADR-0034 conventions "as they scaffold" (ADR-0034 Affected Nodes). That is each Seed Node's standup-ADR work — the standup ADRs already exist (0017–0025, 0031). Not a fan-out here; packet 05 is pinned to the 11 currently-package-producing live Nodes.
- **`HoneyDrunk.Actions` / `HoneyDrunk.Architecture` / `HoneyDrunk.Studios` package metadata.** None of the three ships a NuGet package — this is a known fact about what each repo produces (Actions ships reusable GitHub workflows, Architecture is docs/catalogs, Studios is a Next.js site), confirmed against `catalogs/relationships.json` `exposes` and `catalogs/contracts.json`, neither of which lists a package for these three. (`catalogs/nodes.json` has no `packages` field — exclusion is by repo type / what the repo actually produces, not a catalog flag.) Excluded from the packet-05 fan-out. If any later starts producing a package, its adoption is a follow-up.
- **Migrating existing GitHub-Packages-published Nodes off GitHub Packages.** ADR-0034 D1 makes nuget.org the public feed; ADR-0034's Context notes "some Nodes publish to GitHub Packages." Packet 05's release-workflow amendment switches each Node's `feed` to `nuget.org` for stable — the de-facto migration. No separate "decommission the old GitHub Packages feed" packet is filed; the old feed simply stops receiving new versions. If an explicit deprecation/cleanup of stale GitHub Packages versions is wanted, that is a follow-up housekeeping packet.

## `gh` CLI Commands — file Wave 1–3 issues

Filing is **automated**. The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers on push to `generated/work-items/active/**/*.md` and files every packet, adds it to The Hive, sets board fields from frontmatter, and wires `addBlockedBy` from the `dependencies:` arrays. Do not run `gh issue create` manually.

**Held work-item:** packet 04 (signing-certificate procurement) is **hard-preconditioned on BDR-0001** — the `file-work-items` agent holds it until the human confirms the Sunbiz amendment has landed. Packets 00–03 and 05 file on the normal push trigger.

**Fan-out work-item:** packet 05 is a per-Node fan-out — the `file-work-items` agent expands it into one issue per repo across the 11 repos in `target_repos` (Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications), or files it as a tracking issue with 11 sub-tasks. The 11-repo list is pinned and fixed — no repo is added or dropped at filing time. `HoneyDrunk.Audit` carries `signal: "Seed"` in `catalogs/nodes.json` (it is not a Live Node) but it is scaffolded and package-producing — the ADR-0030/0031 standup stood up buildable `HoneyDrunk.Audit.Abstractions` + `HoneyDrunk.Audit.Data` projects. Fan-out membership is the scaffolded-and-package-producing test, not the Live signal, so Audit is a permanent member.

## After filing — board fields and blocking relationships

The `file-work-items` pipeline sets Status, Wave, Node, Tier, Actor, Initiative, and ADR fields from frontmatter and wires `addBlockedBy` automatically. For reference, the blocking graph (resolved from each packet's `dependencies:`):

- `01` blocked-by `00` (soft)
- `02` blocked-by `00` (soft)
- `03` blocked-by `00` (soft), `01` (hard)
- `04` blocked-by `03` (hard) — wired only when packet 04 is un-held (BDR-0001 landed) and filed
- `05` blocked-by `02` (hard), `03` (hard) — wired on each per-Node fan-out issue

**Actor:** packets 00, 01, 02, 03, 05 are `Actor=Agent` (00/01 are docs/catalog; 02 is build tooling; 03 is a workflow; 05 is per-repo metadata + workflow edits — all delegable, though 03 and 05 carry Human Prerequisites for the nuget.org account/credentials). **Packet 04 is `Actor=Human`** — it carries the `human-only` label because CA procurement and portal-only Key Vault import are the *entire* work item, not a side prerequisite.

Verify a wave landed by checking The Hive for the new items + their blocked-by chains, not by inspecting the workflow log.

## Notes

- **Acceptance precedes flip.** ADR-0034 stays Proposed until packet 00's PR merges — and that PR is coordinated with ADR-0035's acceptance PR (ADR-0034 D7, "land together").
- **The three new invariants land in packet 00**, not in a separate `constitution/invariants.md` packet — nuget.org ownership, SourceLink + symbols, publish-via-reusable-workflow. They are **invariants 54, 55, 56** (in that order). The current highest invariant in `constitution/invariants.md` is 51 (1–51 all present). Numbers 54–56 are **pre-reserved for ADR-0034 as part of a 12-ADR batch** that reserves blocks of invariant numbers across ADRs 0034–0042/0045; numbers 52–53 belong to a sibling ADR in the batch. Packet 00 uses the hard numbers 54–56 — it does not scan for "next free." If any invariant above 51 lands from **outside** this batch before packet 00's PR merges, shift the block upward to the next free triple and never reuse a number.
- **The unsigned-publish window is expected and acceptable.** ADR-0034 D5 explicitly publishes unsigned until BDR-0001 lands. `job-publish-nuget.yml` (packet 03) implements the conditional sign stage from day one; packet 04 provisions the certificate that activates it. The initiative does not wait on BDR-0001 — only packet 04 does.
- **No new repo created, no new ADR, no new runtime contract.** This initiative ships an ADR flip + invariants, one catalog, one build-tooling fragment, one reusable workflow, and a per-Node packaging/release-workflow fan-out. The one new catalog (`package-feeds.json`) introduces a new JSON schema but no runtime contract — `catalogs/contracts.json` is untouched.
- **No Azure resources are provisioned by an agent.** The nuget.org account, the nuget.org API key, the federated-OIDC trust, and the code-signing certificate are all Human Prerequisites / `Actor=Human` work. The Studios Key Vault already exists per ADR-0005; this initiative seeds two secrets into it (the nuget.org API key, the signing certificate).
- **Cost.** nuget.org hosting is free. The code-signing certificate is a recurring CA cost (typically $200–600/year). Azure Artifacts pre-release staging uses the existing internal feed — no new spend.
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).

## Archival

Per ADR-0008 D10, when every **filed and in-scope** packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0034-public-package-distribution/` folder moves to `archive/adr-0034-public-package-distribution/` in a single commit. Partial archival is forbidden.

**Archival-gate decision for packet 04 (signing-certificate procurement):** packet 04 is **in-scope and NOT exempt** from the archival gate. Unlike a packet gated on a thing that may never exist, BDR-0001 is a near-term, committed entity-finalization step with a concrete completion path. The initiative's archival waits for packet 04 to be filed-and-`Done` once BDR-0001 lands. If BDR-0001 is materially deferred such that the unsigned-publish window stretches indefinitely, a future dispatch-plan revision records that and re-classifies packet 04 — but the default expectation is that packet 04 completes within this initiative.

## Revision history

- **2026-05-22 initial scope** — 6 packets across three waves. Drafted ahead of ADR-0034 acceptance per the developer's request; packets are pending-acceptance drafts, not yet filed as GitHub Issues. ADR-0035 noted as a separate, co-landing initiative per ADR-0034 D7.
