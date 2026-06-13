# Dispatch Plan: Grid Open Source License Policy (ADR-0039)

**Date:** 2026-05-22 (initial scope — drafted ahead of ADR-0039 acceptance).
**Trigger:** ADR-0039 (Grid Open Source License Policy) — Proposed 2026-05-21, part of the 2026-05-21 batch of cross-cutting Grid-gap ADRs. Scoped now so the packet set is ready when the ADR lands.
**Type:** Multi-repo (Architecture, Standards, Actions, plus a per-repo fan-out across 14 public Grid repos for license/CONTRIBUTING/DCO reconciliation, and an FSL conversion of the two revenue repos Notify + Communications).
**Sector:** Meta / cross-cutting (every public Grid repo is touched by Wave 3's fan-out).
**Site sync required:** No. License policy, `LICENSE` files, `CONTRIBUTING.md`, and CI workflows are not public-facing artifacts on the Studios marketing site. Re-evaluate only if a future "developer / open-source" page on the Studios site surfaces license information — that would be a separate site-sync packet.

**Rollback plan:**
- Architecture-side packets (00, 01, 06, 07) revert cleanly via `git revert` — they are docs/text/catalog edits with no runtime consumer. The `license` field on `catalogs/nodes.json` (packet 01) has no compiled consumer; deleting it has no runtime impact.
- The `HoneyDrunk.Standards` packet (02) adds one conditional MSBuild property to the shared packaging fragment — additive build tooling; reverting it just restores the no-explicit-default state (the per-repo FSL overrides in packet 03 still work without it).
- The `HoneyDrunk.Actions` packet (04) is an additive reusable workflow — no consumer calls `job-dco-signoff.yml` until Wave 3's fan-out (packet 05) wires it in; reverting is safe.
- The FSL conversion (packet 03) reverts per-repo: restore the prior MIT `LICENSE` and the prior `Directory.Build.props` license metadata. **Caveat:** a license change is consumer-visible — if a package was *published* under FSL between the conversion and a revert, the revert does not un-publish that version. ADR-0039 D9's one-way-door rule applies. In practice this packet only changes repo files; no publish happens until a human triggers a release, so a same-session revert is clean.
- The Wave 3 fan-out (packet 05) reverts per-repo: remove the `CONTRIBUTING.md`, restore the prior `LICENSE` copyright string, remove the `job-dco-signoff` job from the PR-validation workflow, remove the CC-BY-4.0 content-license file. No runtime change, no contract change. A partially-reverted state (some repos reconciled, some not) is operationally fine — the repos are independent.

## Summary

ADR-0039 records the Grid's first Grid-level license decision. The decision: **MIT** as the default for every Node (D1); **FSL-1.1-MIT** for revenue Nodes, formalizing the one-off ADR-0027 precedent (D2); **MIT** for client SDKs even when the engine is FSL (D3); **proprietary** copyright-reservation for private Nodes (D4); **DCO not CLA** for contributions (D5); **no per-file license headers** (D6); **CC-BY-4.0** for documentation/content (D7); a **`license` field on `catalogs/nodes.json`** as the single source of truth (D8); and a heavyweight **ADR-amendment procedure** for any future license change (D9).

This initiative ships **8 packets** (`00`–`07`) across **three waves**:

- **Wave 1** — governance + the catalog source of truth: ADR acceptance + two new invariants (00), the `license` field on `catalogs/nodes.json` with full backfill (01).
- **Wave 2** — the three independent execution artifacts: the MIT default in the shared `HoneyDrunk.Standards` packaging fragment (02), the FSL conversion of the two revenue repos (03), the reusable `job-dco-signoff.yml` workflow in `HoneyDrunk.Actions` (04).
- **Wave 3** — the per-repo fan-out across 14 public repos (05), the `hive-sync` license-drift reconciliation (06), and the D9 license-change procedure in the ADR amendment template (07).

**Reality check that shaped the scope** (verified across the workspace at scoping time):
- All 14 code repos already carry an `MIT License` file at repo root — the D1 default is *mostly satisfied by accident*. So the fan-out's LICENSE work for the 12 non-revenue repos is a *confirm + copyright-string normalize*, not a rewrite.
- **No repo has a `CONTRIBUTING.md`** — that is net-new across the fan-out.
- The two revenue repos (Notify, Communications) carry the *stale MIT file* — the FSL decision exists in ADR-0027/ADR-0039 text but was never applied. Packet 03 applies it.
- `HoneyDrunk.Studios` has **no `LICENSE` file** and is `proprietary` — ADR-0039 D7 explicitly excludes the marketing site. Studios is out of every fan-out.

## Important constraints (from ADR-0039 itself)

- **MIT is the default — by SPDX expression.** D1 — `<PackageLicenseExpression>MIT</PackageLicenseExpression>` is the `Directory.Build.props` default. Revenue Nodes and SDKs override it explicitly.
- **FSL is custom text — it needs a packed `LICENSE.md`, not just an SPDX id.** D2 — "the SPDX identifier alone is insufficient because FSL is custom-text per project." FSL repos pack `LICENSE.md`.
- **Future license is MIT, not Apache-2.0.** D2 — the Grid uses `FSL-1.1-MIT` (not `FSL-1.1-Apache-2.0`) for consistency with D1.
- **SDKs and contract surfaces do not inherit the engine's restrictive license.** D3 / new invariant 68 — a revenue Node's SDK is MIT even when the engine is FSL, via a per-project override; packet 03 extends the same reasoning to the revenue Nodes' `*.Abstractions` contract packages (MIT — invariants 40/48 require downstream Nodes to compile against them).
- **`FSL-1.1-MIT` is not a valid SPDX identifier.** FSL engine repos use `<PackageLicenseFile>LICENSE.md</PackageLicenseFile>`, not `<PackageLicenseExpression>` — the latter fails NuGet SPDX validation. MIT packages keep `<PackageLicenseExpression>MIT</PackageLicenseExpression>`.
- **DCO, not CLA.** D5 — `Signed-off-by:` per commit; Studio-employee commits exempt. No CLA bot.
- **No per-file license headers.** D6 — the repo-root `LICENSE` is the single source of truth. Exception: third-party code keeps its original header verbatim.
- **`catalogs/nodes.json` `license` is the single source of truth.** D8 — `hive-sync` reconciles repos against it.
- **License changes are a one-way door.** D9 — heavyweight ADR-amendment procedure; you cannot un-license an already-released version.
- **Studios is excluded.** D7 — the marketing site's private/proprietary posture is ADR-0029's concern, not ADR-0039's.

## Wave Diagram

### Wave 1 — Governance + the catalog source of truth

Run packet 00 first (ADR acceptance + the two invariants). Packet 01 (the `license` catalog field) follows.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0039** — flip status, add invariants 67 + 68, register the initiative — [`00-architecture-adr-0039-acceptance.md`](00-architecture-adr-0039-acceptance.md)
  - Blocked by: nothing.
- [ ] `HoneyDrunk.Architecture`: Extend `catalogs/nodes.json` with the `license` field and backfill every Node — [`01-architecture-nodes-license-field.md`](01-architecture-nodes-license-field.md)
  - Blocked by: Wave 1 — `00` (soft — references ADR-0039 D8 as a live rule).

**Wave 1 exit criteria:**
- ADR-0039 reads `**Status:** Accepted`; invariants 67 (license-field-matches-LICENSE-file) and 68 (SDKs don't inherit the engine license) are in `constitution/invariants.md`; the initiative is registered.
- Every Node in `catalogs/nodes.json` has a `license` field (`FSL-1.1-MIT` for Notify/Communications, `proprietary` for Studios, `MIT` for all others) and a `visibility` field (`private` for Studios, `public` for all others).

### Wave 2 — The three independent execution artifacts (parallel)

Packets 02, 03, 04 are independent of each other and may run fully in parallel after Wave 1.

- [ ] `HoneyDrunk.Standards`: Add the `<PackageLicenseExpression>MIT</PackageLicenseExpression>` default to the shared packaging fragment — [`02-standards-license-expression-props-default.md`](02-standards-license-expression-props-default.md)
  - Blocked by: Wave 1 — `00` (soft).
- [ ] **Revenue-repo FSL conversion** (Notify + Communications): replace the stale MIT `LICENSE` with FSL-1.1-MIT `LICENSE.md`, set FSL package metadata, add the README FSL section — [`03-cross-repo-fsl-conversion-notify-communications.md`](03-cross-repo-fsl-conversion-notify-communications.md)
  - Blocked by: Wave 1 — `00` (soft). Not blocked by `02` — these repos *override* the shared default; the override works whether or not `02` has landed.
- [ ] `HoneyDrunk.Actions`: Author `job-dco-signoff.yml` — the reusable DCO sign-off enforcement workflow — [`04-actions-dco-signoff-workflow.md`](04-actions-dco-signoff-workflow.md)
  - Blocked by: Wave 1 — `00` (soft).

**Wave 2 exit criteria:**
- The `HoneyDrunk.Standards` packaging fragment sets a *conditional* `<PackageLicenseExpression>MIT</PackageLicenseExpression>` default.
- `HoneyDrunk.Notify` and `HoneyDrunk.Communications` carry FSL-1.1-MIT `LICENSE.md`, FSL package metadata, and a README FSL section; their engine packages pack as FSL.
- `job-dco-signoff.yml` exists in `HoneyDrunk.Actions`, is callable via `workflow_call` with `exempt-actors`, and is advisory-by-default.

### Wave 3 — Fan-out + reconciliation + the D9 procedure

Packet 07 depends only on packet 00 and could technically run in Wave 1; it is placed in Wave 3 because it is governance polish, not a blocker for anything. Packets 05 and 06 depend on the Wave 1/2 artifacts.

- [ ] **Per-repo fan-out** across 14 public Grid repos: confirm/normalize `LICENSE`, add `CONTRIBUTING.md`, wire the advisory `job-dco-signoff` job, add the CC-BY-4.0 content license to Architecture + Lore — [`05-cross-repo-license-fanout-contributing-and-dco.md`](05-cross-repo-license-fanout-contributing-and-dco.md)
  - Blocked by: Wave 1 — `01` (**hard** — reconciles each repo's `LICENSE` against the catalog field); Wave 2 — `03` (**hard for the Notify/Communications children** — their FSL `LICENSE.md` must exist first), `04` (**hard** — each PR-validation workflow is amended to call `job-dco-signoff.yml`).
- [ ] `HoneyDrunk.Architecture`: Add license-drift reconciliation to the `hive-sync` agent — [`06-architecture-hive-sync-license-drift.md`](06-architecture-hive-sync-license-drift.md)
  - Blocked by: Wave 1 — `01` (**hard** — the catalog field `hive-sync` reconciles against); Wave 3 — `05` (soft — packet 05 cleans up known drift so `hive-sync`'s first run is near-clean).
- [ ] `HoneyDrunk.Architecture`: Add the D9 license-change procedure to the ADR amendment template — [`07-architecture-license-change-procedure-amendment-template.md`](07-architecture-license-change-procedure-amendment-template.md)
  - Blocked by: Wave 1 — `00` (soft).

**Wave 3 exit criteria:**
- All 14 public Grid repos have a `LICENSE` consistent with their catalog `license` field, a net-new `CONTRIBUTING.md` (DCO + no-headers conventions), and an advisory `job-dco-signoff` job in their PR-validation workflow.
- `HoneyDrunk.Architecture` and `HoneyDrunk.Lore` carry a CC-BY-4.0 content-license file.
- `hive-sync` reconciles the `nodes.json` `license` field against each repo's `LICENSE` file on each run.
- The ADR amendment template carries the D9 license-change procedure.

## Out-of-scope / deferred items

- **`HoneyDrunk.Studios` license posture.** ADR-0039 D7 explicitly excludes the Studios marketing site — "a separate license posture (private/proprietary) and is not addressed here." Studios has no `LICENSE` file today; whether it gets a proprietary one is ADR-0029's concern. `catalogs/nodes.json` records `honeydrunk-studios` as `proprietary` (packet 01) only so the catalog field is complete and `hive-sync` does not flag a missing field — recording it is not ADR-0039 governing it.
- **`HoneyDrunk.Notify.Cloud` and future private revenue Nodes.** ADR-0039 D4 makes private Nodes proprietary with an "All rights reserved" `LICENSE`. `HoneyDrunk.Notify.Cloud` is not yet scaffolded; it adopts the proprietary `LICENSE` at its own ADR-0027 standup. Not a packet here.
- **`HoneyDrunk.Billing` and consumer-app server Nodes.** Future revenue Nodes (ADR-0037 D9, PDR-0003–0008). They adopt FSL-1.1-MIT at their own standup per ADR-0039 D2. Not a packet here.
- **Seed Node license adoption.** The 10 AI-sector + Observe Seed Nodes adopt the ADR-0039 conventions at their own standup ADRs. `catalogs/nodes.json` records them as `MIT` (packet 01) so the catalog is complete, but their repos do not exist yet — packet 05's fan-out is pinned to the 14 currently-live public repos.
- **The `*.Abstractions` package license of a revenue Node — resolved in packet 03.** Packet 03 decisively sets `HoneyDrunk.Notify.Abstractions` / `HoneyDrunk.Communications.Abstractions` to **MIT**: the FSL non-compete is a moat on the revenue engine, not on the contract surface downstream Nodes are required to compile against per invariants 40/48. Only the revenue engine repo's engine package is FSL. This is no longer an open developer decision.
- **Promoting `job-dco-signoff.yml` to a required branch-protection check.** Packet 04/05 ship it as advisory. The Grid is single-author; making DCO a required gate is premature. Promotion to a required check is a per-repo decision deferred to the first external contributor PR. Not a packet here.
- **`HoneyDrunk.Notify.Sdk` package creation.** ADR-0039 D3 uses `HoneyDrunk.Notify.Sdk` as the SDK-stays-MIT example, but `catalogs/nodes.json` shows no such package exists today (Notify exposes `HoneyDrunk.Notify.Abstractions` + `HoneyDrunk.Notify`). Packet 03 does *not* create an SDK package — if one is added later, its MIT per-project override is its own packet's job.

## Decisions needed from the developer (before refinement)

1. **CC-BY-4.0 content-license filename (packet 05).** `LICENSE-docs` vs `LICENSE-CONTENT.md` for the Architecture/Lore content license. The agent picks `LICENSE-docs` if no answer; trivial to override.
2. **`exempt-actors` value (packets 04, 05).** The Studio-employee GitHub login(s) seeded as the DCO sign-off exemption. Currently the sole developer — confirm the login string.

*(The revenue-Node `*.Abstractions` license question was previously flagged here; it is now resolved decisively in packet 03 — the `*.Abstractions` packages are MIT. No developer decision is pending.)*

## `gh` CLI Commands — file Wave 1–3 issues

Filing is **automated**. The `file-work-items.yml` workflow in `HoneyDrunk.Architecture` triggers on push to `generated/work-items/active/**/*.md` and files every packet, adds it to The Hive, sets board fields from frontmatter, and wires `addBlockedBy` from the `dependencies:` arrays. Do not run `gh issue create` manually.

**Fan-out packets:** packet 03 is a 2-repo fan-out (Notify, Communications); packet 05 is a 14-repo fan-out. The `file-work-items` agent expands each into one issue per repo, or files a tracking issue with per-repo sub-tasks. All 14 packet-05 fan-out repos are live scaffolded repos (verified) — including `HoneyDrunk.Audit` (it carries `LICENSE`, `Directory.Build.props`, `HoneyDrunk.Audit.slnx`, `src/`, `tests/`). The 14-repo list is pinned and complete; no repo is conditionally dropped at filing time.

## After filing — board fields and blocking relationships

The `file-work-items` pipeline sets Status, Wave, Node, Tier, Actor, Initiative, and ADR fields from frontmatter and wires `addBlockedBy` automatically. For reference, the blocking graph (resolved from each packet's `dependencies:`):

- `01` blocked-by `00` (soft)
- `02` blocked-by `00` (soft)
- `03` blocked-by `00` (soft)
- `04` blocked-by `00` (soft)
- `05` blocked-by `01` (hard), `03` (hard — Notify/Communications children), `04` (hard)
- `06` blocked-by `01` (hard), `05` (soft)
- `07` blocked-by `00` (soft)

**Actor:** every packet in this initiative is **`Actor=Agent`**. There is no `Actor=Human` packet — the entire initiative is delegable. The Human Prerequisites (sourcing the canonical FSL-1.1-MIT license text, confirming the legal copyright string, confirming `exempt-actors` logins, and the two developer decisions above) are inputs the agent needs, not work items the agent cannot do. Sourcing FSL text is a fetch, not a portal click. No repo is created, no Azure resource is provisioned, no payment is made. The `human-only` label is not applied to any packet.

Verify a wave landed by checking The Hive for the new items + their blocked-by chains, not by inspecting the workflow log.

## Notes

- **Acceptance precedes flip.** ADR-0039 stays Proposed until packet 00's PR merges. No other packet flips the ADR.
- **The two new invariants land in packet 00**, numbered 67 and 68: (67) every Node has a `license` field and a matching `LICENSE` file, reconciled by `hive-sync`; (68) SDK packages do not inherit the engine's restrictive license. The current highest invariant in `constitution/invariants.md` is 51 (verified); numbers 67-68 are **pre-reserved as part of a 12-ADR batch**, leaving a deliberate gap above 51. If any invariant above 51 lands from outside this batch before merge, shift this block upward — never reuse a number. (Numbers 52/53 are reserved for ADR-0044, not ADR-0039.)
- **MIT-by-accident is the steady state.** All 14 code repos already carry an MIT `LICENSE`. The fan-out's LICENSE work is mostly a confirm + a copyright-holder-string normalize (`HoneyDrunkStudios` → `HoneyDrunk Studios LLC`), not a rewrite. The real net-new work is `CONTRIBUTING.md` (no repo has one) and the DCO workflow wiring.
- **The FSL conversion is the load-bearing code change.** Notify and Communications carry a *stale* MIT file — the FSL decision from ADR-0027 was never applied to the repos. Packet 03 is the first time the repos match the decision.
- **No new repo, no new ADR, no new runtime contract.** This initiative ships an ADR flip + two invariants, one catalog field, one MSBuild property, one reusable workflow, an FSL conversion of two repos, a 14-repo docs/CI fan-out, an agent-responsibility addition, and a template addition. `catalogs/contracts.json` is untouched.
- **No Azure resources, no spend.** Nothing in this initiative provisions infrastructure or incurs cost. (Contrast ADR-0034's signing certificate — there is no equivalent paid artifact here.)
- **The dispatch plan is the one exception to packet immutability** (ADR-0008 D7). It is updated at wave boundaries as a historical record; packet bodies are immutable post-filing (invariant 24).

## Archival

Per ADR-0008 D10, when every filed and in-scope packet in this initiative reaches `Done` on the org Project board and the wave exit criteria are met, the entire `active/adr-0039-license-policy/` folder moves to `archive/adr-0039-license-policy/` in a single commit. Partial archival is forbidden.

## Revision history

- **2026-05-22 initial scope** — 8 packets across three waves. Drafted ahead of ADR-0039 acceptance per the developer's request; packets are pending-acceptance drafts, not yet filed as GitHub Issues. Three developer decisions originally flagged (revenue-Node Abstractions license, content-license filename, `exempt-actors` value).
- **2026-05-22 refinement-review fixes** — corrected the ADR-0039 invariant block to 67/68 (52/53 reserved for ADR-0044; pre-reservation note added); packet 01 now adds a `visibility` field alongside `license`; packet 02 made an explicit non-version-bumper of the Standards fragment (ADR-0034 packet 02 owns the batch bump); packet 03 `git rm`s the extensionless `LICENSE`, uses `<PackageLicenseFile>` for FSL engines (`FSL-1.1-MIT` is not valid SPDX), and decisively sets the `*.Abstractions` packages to MIT; packet 05 confirmed `HoneyDrunk.Audit` as a firm fan-out target (no conditional drop) and instructs per-repo discovery of the PR-validation workflow filename. Two developer decisions remain (content-license filename, `exempt-actors`); the Abstractions question is resolved.
