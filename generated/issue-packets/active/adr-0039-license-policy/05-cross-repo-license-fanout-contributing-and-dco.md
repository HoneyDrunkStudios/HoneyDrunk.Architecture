---
name: Cross-Repo Change
type: cross-repo-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
target_repos: ["HoneyDrunk.Kernel", "HoneyDrunk.Transport", "HoneyDrunk.Vault", "HoneyDrunk.Vault.Rotation", "HoneyDrunk.Auth", "HoneyDrunk.Web.Rest", "HoneyDrunk.Data", "HoneyDrunk.Audit", "HoneyDrunk.Pulse", "HoneyDrunk.Notify", "HoneyDrunk.Communications", "HoneyDrunk.Actions", "HoneyDrunk.Standards", "HoneyDrunk.Lore"]
labels: ["chore", "tier-2", "core", "ops", "meta", "coordination", "adr-0039", "wave-3"]
dependencies: ["packet:01", "packet:03", "packet:04"]
adrs: ["ADR-0039"]
accepts: ["ADR-0039"]
wave: 3
initiative: adr-0039-license-policy
node: honeydrunk-architecture
---

# Reconcile LICENSE files, add CONTRIBUTING.md + DCO wiring across all public Grid repos (ADR-0039 D1/D4/D5/D6/D7)

## Summary
Roll the ADR-0039 license conventions out to every public Grid repo: confirm or correct the repo-root `LICENSE` file against the `catalogs/nodes.json` `license` field, add a `CONTRIBUTING.md` documenting the DCO sign-off convention and the no-per-file-headers rule (D5/D6), wire the `job-dco-signoff.yml` reusable workflow into each repo's PR-validation workflow (D5), and add the CC-BY-4.0 content-license file to the documentation repos (D7).

## Context
ADR-0039's Consequences names the per-repo follow-up: "Audit every public repo's current `LICENSE` file against the policy; open packets for drift (most should be MIT already by accident; a couple may be stale or missing)." It also commits the DCO convention to each repo's `CONTRIBUTING.md` ("The repo CONTRIBUTING.md (per repo) documents the convention") and the no-per-file-headers convention to the same file (D6: "The repo CONTRIBUTING.md documents the convention").

**Reality at scoping time** (verified across the workspace):
- All 14 code repos already carry an `MIT License` file at repo root — so the D1 default is mostly satisfied by accident. The two **revenue** repos (Notify, Communications) are corrected to FSL by packet 03, not here. This packet's LICENSE work for the 12 non-revenue repos is a *confirm* (already MIT) plus a copyright-year/holder-string cleanup, not a rewrite.
- **No repo has a `CONTRIBUTING.md`.** That is net-new across the fan-out.
- `HoneyDrunk.Studios` has **no** `LICENSE` file and is `proprietary` (ADR-0029 marketing site). ADR-0039 D7 explicitly excludes Studios from the policy ("a separate license posture (private/proprietary) and is not addressed here"). **Studios is OUT of this fan-out** — its proprietary `LICENSE` and posture are ADR-0029's concern.

**This is a multi-repo packet** describing one repeated unit of work across the 14 repos in `target_repos`. The `file-packets` agent files it as a tracking issue with one child issue per repo, or as 14 sibling issues. The per-repo work is small and identical in shape.

## Repo-list reconciliation (read before filing)
`target_repos` is the **14 public Grid repos** that have a repo-root `LICENSE` file today: the 11 .NET Node repos (Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications) plus `HoneyDrunk.Actions`, `HoneyDrunk.Standards`, and `HoneyDrunk.Lore`.

- **`HoneyDrunk.Studios` is OUT** — no `LICENSE` file today, `proprietary`, explicitly excluded by ADR-0039 D7. Its license posture is ADR-0029's concern.
- **Notify and Communications are IN** for the CONTRIBUTING.md + DCO-wiring work, but their `LICENSE` file is handled by packet 03 (FSL conversion) — this packet does NOT touch their `LICENSE`/`LICENSE.md`. The per-repo work unit below skips step 1 for those two.
- **Seed Nodes are OUT** — the 10 AI-sector + Observe Seed Nodes are not yet scaffolded as live repos. They adopt the ADR-0039 conventions at their own standup (each standup ADR's scope). Do not add them at filing time.
- **Private revenue Nodes** (`HoneyDrunk.Notify.Cloud`, ADR-0027) are OUT — proprietary `LICENSE` per ADR-0039 D4, adopted at their own standup.

## Per-repo work unit (repeated for each of the 14 repos in `target_repos`)
For each repo:

1. **LICENSE file confirm/correct** *(skip for Notify and Communications — packet 03 owns their `LICENSE.md`)*. Open the repo-root `LICENSE`. Confirm it is the MIT license text and that the SPDX value matches the repo's `license` field in `catalogs/nodes.json` (all 12 non-revenue repos here are `MIT`). Correct the copyright line to a consistent form — `Copyright (c) <year> HoneyDrunk Studios LLC` (note: existing files vary between `2025`/`2026` and use `HoneyDrunkStudios` without `LLC`; normalize the holder string to match ADR-0039 D4's `HoneyDrunk Studios LLC` legal-entity wording; keep the original year the file already carries — do not change a 2025 file to 2026). If the file is missing or is not MIT text, replace it with the standard MIT text.
2. **`CONTRIBUTING.md`** *(net-new in every repo)*. Add a `CONTRIBUTING.md` at repo root documenting:
   - **The DCO convention (D5).** Contributions are accepted under the Developer Certificate of Origin. External contributors sign off each commit (`git commit --signoff`), adding a `Signed-off-by: Name <email>` trailer. Include the standard one-line DCO statement and a link to developercertificate.org. Note that Studio-employee commits are exempt.
   - **No per-file license headers (D6).** Contributors do not add `// Copyright ... Licensed under MIT` headers to source files — the repo-root `LICENSE` is the single source of truth. Exception: third-party code brought into the repo keeps its original header verbatim.
   - **The repo's license.** State the repo's license (`MIT`, or `FSL-1.1-MIT` for Notify/Communications) and, for the FSL repos, a one-line pointer to the README's FSL explanation.
   This content is identical across repos except the license line — author one canonical `CONTRIBUTING.md` template and apply it, varying only the license statement.
3. **Wire `job-dco-signoff.yml` (D5).** **Discover the repo's actual PR-validation workflow filename** — do NOT assume a uniform `pr-*.yml` name. Inspect `.github/workflows/` in the repo and identify the workflow that runs on `pull_request` and gates the PR (the tier-1/PR-validation gate). The filename is not guaranteed uniform across repos: ADR-0011 (which would standardize a `pr-core.yml` name) is still Proposed, so repos may use `pr-validation.yml`, `ci.yml`, `pr.yml`, or another name. Amend whichever file is the PR-validation workflow to add a `job-dco-signoff` job that calls `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-dco-signoff.yml` at a pinned ref, passing `exempt-actors` (the Studio-employee logins). If a repo has no PR-validation workflow at all, the agent records that in the per-repo PR and the DCO wiring for that repo is deferred — do not invent a new PR-validation workflow solely to host the DCO job. Per packet 04, the job is **advisory** — added as a workflow job, NOT a required branch-protection check. Do not modify branch protection.
4. **CC-BY-4.0 content license (D7) — `HoneyDrunk.Architecture` and `HoneyDrunk.Lore` only.** ADR-0039 D7: documentation surfaces license *content* under CC-BY-4.0 while *code* stays MIT. For these two repos, add a `LICENSE-docs` file (or `LICENSE-CONTENT.md` — pick one name, apply to both) containing the CC-BY-4.0 license text, and add a short note to the repo `README.md` explaining the dual posture: code is MIT (the `LICENSE` file), prose/documentation/wiki content is CC-BY-4.0 (the `LICENSE-docs` file). The repo-root `LICENSE` stays MIT. `catalogs/nodes.json` `license` remains `MIT` (the code license — set by packet 01); this file is the content-license record D7 calls for.
   - Note: `HoneyDrunk.Architecture` is the repo this packet's tracking issue lives in — the D7 work for Architecture lands as part of the same per-repo unit.
5. **Repo-level `CHANGELOG.md`.** Add an entry recording the license-policy reconciliation (CONTRIBUTING.md added, DCO workflow wired, copyright-string normalized, CC-BY-4.0 content license added where applicable). Use a dated, versioned section — no Unreleased section committed. This is a docs/tooling change, not a code change — one repo-level CHANGELOG entry per repo; no per-package CHANGELOG noise (invariant 12/27).

## Affected Repos
The 14 repos in `target_repos`: Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Actions, Standards, Lore. **Studios OUT** (proprietary, ADR-0039 D7 / ADR-0029). **Seed Nodes and private revenue Nodes OUT** (adopt at their own standup). The list is pinned — do not add or drop repos at filing time. `HoneyDrunk.Audit` is a **live, scaffolded repo** (verified: it carries `LICENSE`, `Directory.Build.props`, `HoneyDrunk.Audit.slnx`, `src/`, `tests/`) and is firmly one of the 14 fan-out targets — it is not conditional.

## NuGet Dependencies
None. This packet edits `LICENSE`/`CONTRIBUTING.md`/`README.md`/`CHANGELOG.md` Markdown-and-text files and amends GitHub Actions workflow YAML. No .NET project is created or modified; no `PackageReference` is added or removed. `CONTRIBUTING.md`, `LICENSE`, and `LICENSE-docs` are content files, not projects.

## Boundary Check
- [x] Each repo's `LICENSE`, `CONTRIBUTING.md`, `README.md`, `CHANGELOG.md`, and PR-validation workflow live in that repo — correct ownership.
- [x] `HoneyDrunk.Actions` is both a fan-out target (it gets a CONTRIBUTING.md + DCO wiring like any repo) and the home of `job-dco-signoff.yml` (authored in packet 04) — no conflict; packet 04 ships the workflow, this packet's Actions child wires it into Actions' own PR-validation workflow.
- [x] No new cross-Node runtime dependency — license/contribution metadata and CI wiring only.
- [x] No contract change.

## Acceptance Criteria
- [ ] Every repo in `target_repos` has a repo-root `LICENSE` whose SPDX value matches its `catalogs/nodes.json` `license` field (all 12 non-revenue repos confirmed `MIT`; Notify/Communications `LICENSE.md` is FSL — owned by packet 03, only confirmed-consistent here)
- [ ] The copyright holder string is normalized to `HoneyDrunk Studios LLC` across all `LICENSE` files; the existing year on each file is preserved (not bulk-changed)
- [ ] Every repo in `target_repos` has a net-new `CONTRIBUTING.md` documenting the DCO convention (D5), the no-per-file-headers rule with the third-party-code exception (D6), and the repo's license
- [ ] Each repo's actual PR-validation workflow (filename discovered per repo, not assumed `pr-*.yml`) has a `job-dco-signoff` job calling `job-dco-signoff.yml` at a pinned ref with `exempt-actors` set — added as an advisory job, NOT a required branch-protection check; if a repo has no PR-validation workflow, the per-repo PR records the deferral
- [ ] `HoneyDrunk.Architecture` and `HoneyDrunk.Lore` each have a CC-BY-4.0 content-license file (consistent filename across both) and a README note explaining the code-MIT / content-CC-BY dual posture; their repo-root `LICENSE` remains MIT
- [ ] Each repo's repo-level `CHANGELOG.md` records the license-policy reconciliation under a dated, versioned section; no per-package CHANGELOG noise (invariant 12/27)
- [ ] No branch-protection change in any repo
- [ ] `HoneyDrunk.Studios`, Seed Nodes, and private revenue Nodes are NOT touched

## Human Prerequisites
- [ ] Confirm the legal copyright holder string — `HoneyDrunk Studios LLC` per ADR-0039 D4 — or the correct entity name if BDR-0001 (entity finalization) has produced a different one. If the agent cannot confirm, it uses `HoneyDrunk Studios LLC` and flags it.
- [ ] Confirm the pinned `job-dco-signoff.yml` ref for all 14 callers.
- [ ] Confirm the `exempt-actors` value (Studio-employee GitHub logins) passed by each caller — same value as packet 04's default.
- [ ] (Optional) Decide on the CC-BY-4.0 content-license filename (`LICENSE-docs` vs `LICENSE-CONTENT.md`) — the agent picks one and applies it to both Architecture and Lore; the developer may override.

## Dependencies
- `packet:01` — `catalogs/nodes.json` `license` field (**hard** — step 1 reconciles each repo's `LICENSE` against this field; it must exist).
- `packet:03` — FSL conversion of Notify/Communications (**hard for the Notify/Communications children** — those two repos' `LICENSE.md` must already be FSL before this packet confirms consistency; this packet does not touch their license file).
- `packet:04` — `job-dco-signoff.yml` reusable workflow (**hard** — every repo's PR-validation workflow is amended to call it; it must exist).

## Referenced ADR Decisions
**ADR-0039 D1 — Default license: MIT.** Every Grid Node defaults to MIT. (Most repos already carry MIT by accident — this packet confirms and normalizes.)

**ADR-0039 D4 — Private Nodes: proprietary, no license header.** Private Nodes carry `LICENSE` stating "All rights reserved. Proprietary to HoneyDrunk Studios LLC." — establishes `HoneyDrunk Studios LLC` as the legal-entity copyright string used across `LICENSE` files. (No private Node is in this fan-out; the string is reused for consistency.)

**ADR-0039 D5 — Contribution: DCO, not CLA.** External contributions accepted under the DCO; `Signed-off-by:` per commit; Studio-employee commits exempt. The repo `CONTRIBUTING.md` documents the convention. The DCO sign-off Action (packet 04) is wired into each repo's PR-validation workflow.

**ADR-0039 D6 — License headers in source files: not required.** Per-file headers are not required — the repo-root `LICENSE` is the single source of truth. Exception: third-party code keeps its original header verbatim. "The repo CONTRIBUTING.md documents the convention."

**ADR-0039 D7 — Documentation and content: CC-BY-4.0.** `HoneyDrunk.Architecture` and any future documentation surface license content under CC-BY-4.0; code in those repos is MIT. The Studios marketing site is a separate private/proprietary posture and is not addressed by ADR-0039 — Studios is excluded from this fan-out.

**ADR-0039 Consequences — Follow-up Work.** "Audit every public repo's current `LICENSE` file against the policy; open packets for drift." "Wire the DCO sign-off Action ... consumer PR-validation workflows call it."

## Constraints
> **Invariant 67 (added by packet 00) — every Node has a `license` field in `catalogs/nodes.json` and a matching `LICENSE` file in the repo root.** The SPDX expression in the catalog (`MIT`, `FSL-1.1-MIT`, or `proprietary`) must match the actual `LICENSE` / `LICENSE.md` file the repo carries; drift is reconciled by `hive-sync`. This packet is the reconciliation step that makes the `LICENSE` files match the catalog field packet 01 set.

> **Invariant 12 / 27 — CHANGELOG discipline.** One repo-level `CHANGELOG.md` entry per repo for the license-policy reconciliation; no per-package CHANGELOG noise — this is a docs/tooling change, not a per-package functional change. No git tag is pushed (agents never push tags).

- **Studios is excluded** — proprietary, ADR-0039 D7. Do not add a `LICENSE` to Studios or otherwise touch it.
- **Notify/Communications `LICENSE` is packet 03's job** — this packet's Notify/Communications children skip step 1 (LICENSE file) and only do CONTRIBUTING.md + DCO wiring + CHANGELOG.
- **DCO workflow is advisory** — added as a job, never as a required branch-protection check. No branch-protection change anywhere.
- **Preserve existing copyright years** — normalize only the holder string (`HoneyDrunk Studios LLC`), not the year, on each `LICENSE` file.
- **No per-file license headers** — per D6, this packet adds NO headers to source files; it documents the no-headers convention in `CONTRIBUTING.md`.
- **Pinned 14-repo list** — no Seed Nodes, no private revenue Nodes, no Studios.

## Labels
`chore`, `tier-2`, `core`, `ops`, `meta`, `coordination`, `adr-0039`, `wave-3`

## Agent Handoff

**Objective:** Per-repo ADR-0039 reconciliation across 14 public Grid repos — confirm/normalize the `LICENSE` file against the catalog, add a `CONTRIBUTING.md` (DCO + no-headers conventions), wire the advisory `job-dco-signoff.yml` job, and add the CC-BY-4.0 content license to the two documentation repos.

**Target:** Coordination/tracking issue in `HoneyDrunk.Architecture` with one child issue per repo; each child branches from `main` in its own repo. (The CC-BY-4.0 work for `HoneyDrunk.Architecture` itself lands in the Architecture child.)

**Context:**
- Goal: Every public Grid repo's license posture matches the ADR-0039 policy and the `catalogs/nodes.json` `license` field, and every repo documents the DCO contribution convention.
- Feature: ADR-0039 Grid Open Source License Policy rollout, Wave 3.
- ADRs: ADR-0039 (D1, D4, D5, D6, D7, Follow-up Work).
- In scope: the 14 public Grid repos in `target_repos`. Out: Studios (proprietary), Seed Nodes, private revenue Nodes.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:01` (hard — the `license` catalog field), `packet:03` (hard for the Notify/Communications children — their FSL `LICENSE.md`), `packet:04` (hard — the `job-dco-signoff.yml` workflow).

**Constraints:**
- See "Constraints" — inlined for agent consumption.
- Studios excluded entirely.
- Notify/Communications `LICENSE` is packet 03's job — skip step 1 for those two.
- DCO workflow is advisory — added as a job, never a required check; no branch-protection change.
- Preserve existing copyright years; normalize only the holder string.
- No per-file license headers — document the no-headers convention, do not add headers.

**Key Files (per repo):**
- repo-root `LICENSE` (confirm/normalize — skipped for Notify/Communications)
- `CONTRIBUTING.md` (net-new)
- the PR-validation workflow (filename discovered per repo in `.github/workflows/` — not assumed `pr-*.yml`; ADR-0011's `pr-core.yml` standard is still Proposed)
- `README.md` (CC-BY note — Architecture and Lore only)
- `LICENSE-docs` / `LICENSE-CONTENT.md` (new — Architecture and Lore only)
- `CHANGELOG.md`

**Contracts:** No runtime contract change. Consumes the `catalogs/nodes.json` `license` field (packet 01) and the `job-dco-signoff.yml` `workflow_call` contract (packet 04).
