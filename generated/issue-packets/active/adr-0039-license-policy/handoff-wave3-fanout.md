# Handoff: Wave 2 → Wave 3 (execution artifacts → per-repo fan-out + reconciliation)

**Read once at the Wave 2 → Wave 3 transition.** This is an ephemeral baton pass, not a live tracker. Immutable per invariant 24.

## What Waves 1–2 delivered (upstream changes Wave 3 builds on)

- **ADR-0039 is Accepted** (packet 00). Its two new invariants are live in `constitution/invariants.md`, numbered **67 and 68** (ADR-0039's pre-reserved block; the current max invariant is 51, with a deliberate batch gap above it):
  - **Invariant 67** — every Node has a `license` field in `catalogs/nodes.json` and a matching `LICENSE` file in the repo root; the SPDX expression (`MIT`, `FSL-1.1-MIT`, `proprietary`) must match the actual file; drift is reconciled by `hive-sync`.
  - **Invariant 68** — SDK and client-library packages do not inherit the engine's restrictive license; a per-project `<PackageLicenseExpression>MIT</PackageLicenseExpression>` override is required when the engine is FSL.
  D1–D9 are now binding rules.
- **`catalogs/nodes.json` has `license` and `visibility` fields on every Node** (packet 01). `license` values: `FSL-1.1-MIT` for `honeydrunk-notify` and `honeydrunk-communications`; `proprietary` for `honeydrunk-studios`; `MIT` for every other Node including all 10 Seed Nodes. `visibility` values: `private` for `honeydrunk-studios`; `public` for every other Node (FSL is source-available, so FSL Nodes are `public`). Both are new node-object schema fields. The catalog is the single source of truth Wave 3's fan-out reconciles each repo against, and `visibility` lets the public/private split be derived mechanically.
- **The `HoneyDrunk.Standards` packaging fragment sets a conditional MIT default** (packet 02) — `<PackageLicenseExpression Condition="'$(PackageLicenseExpression)' == ''">MIT</PackageLicenseExpression>`. Any package-producing repo that imports the fragment and sets nothing packs as MIT; a repo or project that sets its own value overrides it.
- **`HoneyDrunk.Notify` and `HoneyDrunk.Communications` engine packages are FSL-1.1-MIT** (packet 03) — each repo's old extensionless `LICENSE` (MIT) was `git rm`'d and replaced with a `LICENSE.md` carrying the full FSL-1.1-MIT text (future license = MIT). The engine packages use `<PackageLicenseFile>LICENSE.md</PackageLicenseFile>` (not `<PackageLicenseExpression>` — `FSL-1.1-MIT` is not a valid SPDX identifier). Each Node's `*.Abstractions` contract package stays **MIT** (`<PackageLicenseExpression>MIT</PackageLicenseExpression>`) — the FSL non-compete is a moat on the engine, not the interface downstream Nodes compile against per invariants 40/48. **Their `LICENSE.md` is done — Wave 3's fan-out (packet 05) must NOT touch it**, only confirm consistency with the catalog field. No extensionless `LICENSE` remains in either repo.
- **`job-dco-signoff.yml` exists in `HoneyDrunk.Actions`** (packet 04) — a reusable `workflow_call` workflow taking an `exempt-actors` input (Studio-employee logins), enforcing a `Signed-off-by:` DCO trailer on non-exempt committers' PR commits. It is **advisory-by-default** — callable as a workflow job, not added to any branch protection.

## Contracts Wave 3 consumes

- **The `catalogs/nodes.json` `license` field** — packet 05's per-repo step 1 reads each Node's `license` value and reconciles the repo's `LICENSE` file against it; packet 06 wires `hive-sync` to do the same continuously.
- **The `job-dco-signoff.yml` `workflow_call` contract** — `exempt-actors` input. Packet 05's per-repo PR-validation-workflow amendments add a `job-dco-signoff` job calling it at a pinned ref. Confirm the pinned ref and the `exempt-actors` value before filing packet 05.
- **`hive-sync`'s existing drift-reporting mechanism** — packet 06 adds license-drift reconciliation through whatever channel `hive-sync` already uses; it does not invent a new surface.

## Wave 3 objectives

1. **Per-repo fan-out** (packet 05) — across the **14 public Grid repos**: Kernel, Transport, Vault, Vault.Rotation, Auth, Web.Rest, Data, Audit, Pulse, Notify, Communications, Actions, Standards, Lore. All 14 are live scaffolded repos (verified) — `HoneyDrunk.Audit` included; it is firmly one of the 14, not conditional. Per repo: confirm/normalize the repo-root `LICENSE` against the catalog `license` field (normalize the copyright holder string to `HoneyDrunk Studios LLC`, preserve the existing year); add a net-new `CONTRIBUTING.md` documenting the DCO convention (D5) and the no-per-file-headers rule with the third-party-code exception (D6); wire an advisory `job-dco-signoff` job into the repo's **discovered** PR-validation workflow (filename not assumed — ADR-0011's `pr-core.yml` standard is still Proposed) (D5); and — for `HoneyDrunk.Architecture` and `HoneyDrunk.Lore` only — add a CC-BY-4.0 content-license file plus a README note on the code-MIT / content-CC-BY dual posture (D7).
   - **`HoneyDrunk.Studios` is OUT** — proprietary, ADR-0039 D7 explicitly excludes the marketing site.
   - **Notify and Communications children skip the LICENSE step** — packet 03 already set their FSL `LICENSE.md`; the fan-out only confirms consistency and does the CONTRIBUTING.md + DCO + CHANGELOG work for them.
   - **Seed Nodes and private revenue Nodes are OUT** — they adopt at their own standup. The 14-repo list is pinned.
2. **`hive-sync` license-drift reconciliation** (packet 06) — extend `.claude/agents/hive-sync.md` so each `hive-sync` run reconciles the `catalogs/nodes.json` `license` field against each repo's actual `LICENSE` / `LICENSE.md` and checks `license`/`visibility` internal consistency, reporting mismatches as drift through `hive-sync`'s existing drift-report channel. Makes invariant 67 actively enforced.
3. **D9 license-change procedure** (packet 07) — add the ADR-0039 D9 one-way-door license-change procedure (ADR amendment + `LICENSE.next` advance window + `<PackageReleaseNotes>` callout + no FSL-window-shortening + catalog update) to the ADR amendment template. Independent of 05/06 — depends only on packet 00.

## Constraints carried into Wave 3

> **Invariant 67 (added by packet 00).** Every Node has a `license` field in `catalogs/nodes.json` and a matching `LICENSE` file in the repo root. Packet 05 is the reconciliation step that makes the files match the field; packet 06 makes `hive-sync` the continuous enforcer.

> **Invariant 68 (added by packet 00).** SDK and client-library packages do not inherit the engine's restrictive license. No `HoneyDrunk.Notify.Sdk` package exists today — the rule binds when one is created; the fan-out does not create one. The revenue Nodes' `*.Abstractions` packages are MIT per packet 03 for the same reason.

> **Invariant 12 / 27 — CHANGELOG discipline.** One repo-level `CHANGELOG.md` entry per repo for the license-policy reconciliation; no per-package CHANGELOG noise (this is a docs/CI change, not a per-package functional change). No git tag is pushed (agents never push tags).

> **ADR-0039 D6 — no per-file license headers.** Packet 05 adds NO headers to source files; it documents the no-headers convention in `CONTRIBUTING.md`. Third-party code keeps its original header verbatim.

> **ADR-0039 D7 — Studios excluded.** Do not add a `LICENSE` to `HoneyDrunk.Studios` or otherwise touch it. Its proprietary posture is ADR-0029's concern.

- **The DCO workflow is advisory** — added as a workflow job, never as a required branch-protection check. No branch-protection change anywhere in the fan-out.
- **Preserve copyright years** — normalize only the holder string (`HoneyDrunk Studios LLC`), not the year, on each `LICENSE` file.
- **Pinned 14-repo list** — no Seed Nodes, no private revenue Nodes, no Studios.
- **Notify/Communications `LICENSE.md` is packet 03's artifact** — the fan-out confirms it, does not rewrite it.

## Decisions still open at the Wave 3 boundary

- **Revenue-Node `*.Abstractions` license — RESOLVED, not open.** Packet 03 decisively sets `HoneyDrunk.Notify.Abstractions` / `HoneyDrunk.Communications.Abstractions` to **MIT** (`<PackageLicenseExpression>MIT</PackageLicenseExpression>`). The FSL non-compete is a moat on the revenue engine; the contract surface downstream Nodes are required to compile against per invariants 40/48 must stay permissively licensed. Only the revenue engine repo's engine package is FSL. No follow-up, no flag — packet 05's fan-out does not touch package licensing.
- **CC-BY-4.0 content-license filename** — `LICENSE-docs` vs `LICENSE-CONTENT.md` for Architecture/Lore. Packet 05 picks `LICENSE-docs` absent a developer answer.
- **`exempt-actors` value** — the Studio-employee GitHub login(s) for the DCO exemption; same value packet 04 used as its default. Confirm before filing packet 05.

## Acceptance signal for Wave 3 completion

All 14 public Grid repos have a `LICENSE` consistent with their catalog `license` field, a net-new `CONTRIBUTING.md` (DCO + no-headers conventions), and an advisory `job-dco-signoff` job in their PR-validation workflow; `HoneyDrunk.Architecture` and `HoneyDrunk.Lore` carry a CC-BY-4.0 content-license file; `hive-sync` reconciles the `license` field against each repo's `LICENSE` on each run; and the ADR amendment template carries the D9 license-change procedure. The initiative archives when every filed and in-scope packet is `Done`.
