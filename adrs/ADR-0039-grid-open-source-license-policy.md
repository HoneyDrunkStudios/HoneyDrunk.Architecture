# ADR-0039: Grid Open Source License Policy

**Status:** Proposed
**Date:** 2026-05-21
**Deciders:** HoneyDrunk Studios
**Sector:** Meta / cross-cutting

## Context

The Grid is "public-by-default" by convention but has never recorded a license decision at the Grid level. ADR-0027 (Notify Cloud) carved out **FSL (Functional Source License)** for `HoneyDrunk.Notify` and `HoneyDrunk.Communications` as a one-off justification, with the SDK staying in the open Notify repo under whatever license that repo carried. The license carried by most repos today is "unset" or "MIT in a stale `LICENSE` file copied from the first repo."

The forcing functions:

- **ADR-0034 (NuGet)** mandates a `<PackageLicenseExpression>` on every public package; without a policy, this is one-off SPDX picks scattered across project files.
- **ADR-0027** introduced FSL as precedent without a Grid-wide policy framing. Two more revenue Nodes (potential hosted `HoneyDrunk.Payments` surfaces per ADR-0037 D9, future consumer-app servers) will hit the same question.
- **External consumer of an Abstractions package** can today install with no clear license, which is a problem for any consumer's legal review.
- **Future-contributor friction:** absent a license, an external contributor's PR carries an unclear IP grant.

The policy has to decide three things at minimum:

- The **default license** for any Grid Node that doesn't have a specific reason to deviate.
- The **revenue-Node** license posture (the FSL pattern from ADR-0027) and the conditions under which a Node uses it.
- The **SDK / client-library** license posture (different shape from engines and from revenue Nodes).

It should also address contribution licensing (CLA or DCO), license headers in source files (or their absence), and the relationship to documentation/content licenses (which are typically distinct from code licenses).

## Decision

### D1 — Default license: MIT

Every Grid Node defaults to **MIT** unless an exception applies (D2, D3). MIT was chosen on three criteria:

- **Permissive and compatible.** MIT-licensed packages cause zero downstream legal-review friction; commercial and OSS consumers both adopt without question.
- **The Grid is .NET-centric.** The .NET package ecosystem is overwhelmingly MIT/Apache-2.0; consumers expect one of those. Apache-2.0's patent grant is meaningful for some consumers but the Grid does not currently file patents.
- **Single-author project.** Copyleft (GPL, LGPL, MPL) is overkill for a Grid where the Studio is the sole author and where the goal of "permissive enough that anyone can build on the Abstractions" is paramount.

`<PackageLicenseExpression>MIT</PackageLicenseExpression>` becomes the `Directory.Build.props` default per ADR-0034 D3.

### D2 — Revenue Nodes: Functional Source License (FSL) 2-year MIT delay

Revenue Nodes — Nodes the Studio intends to monetize directly or that exist primarily to support a paid product — license under **FSL-1.1-MIT**, the same license precedent set by ADR-0027 for `HoneyDrunk.Notify` and `HoneyDrunk.Communications`.

FSL-1.1-MIT semantics:

- The current version is non-compete-licensed: anyone may use, modify, and contribute back, but may not use the software to offer a **competing product**.
- After two years, each version converts to **MIT** automatically. The Grid uses the shorter `MIT` future-license variant rather than `Apache-2.0`, for consistency with D1.

A Node qualifies as a "revenue Node" if at least one of:

- It is the primary code surface of a commercial product (per a PDR).
- It is the multi-tenant gateway / cloud variant of an open Node (per the ADR-0027 D2 pattern: `HoneyDrunk.<Node>.Cloud`).
- An ADR amendment explicitly designates it.

Current revenue Nodes under this rule:

- `HoneyDrunk.Notify` — FSL (ADR-0027).
- `HoneyDrunk.Communications` — FSL (ADR-0027).
- `HoneyDrunk.Notify.Cloud` — private (ADR-0027 D2); license not externally visible, internally treated as proprietary.
- `HoneyDrunk.Payments` (ADR-0037 D9) — public Abstractions/provider packages where useful, private on any hosted payment-control surface.
- Consumer-app server Nodes (future, PDR-0003 through PDR-0008) — FSL when they exist.

`<PackageLicenseExpression>FSL-1.1-MIT</PackageLicenseExpression>` for FSL Nodes. The FSL text is included as `LICENSE.md` in the repo (the SPDX identifier alone is insufficient because FSL is custom-text per project).

### D3 — SDKs and client libraries: MIT regardless of engine license

A revenue Node's **client SDK** is MIT-licensed even when the engine is FSL. This is the ADR-0027 D6 pattern made into policy. The reason: consumers cannot adopt an SDK whose license restricts what their own product can do. SDK licensing is a hospitality concern, not a moat concern.

`HoneyDrunk.Notify.Sdk` (the SDK in the open Notify repo) is MIT. `HoneyDrunk.Notify` (the engine) is FSL. Both live in the same repo; the repo's root `LICENSE.md` is the FSL text, and the SDK's project carries a per-project `LICENSE` and a `<PackageLicenseExpression>MIT</PackageLicenseExpression>` that overrides the `Directory.Build.props` default.

### D4 — Private Nodes: proprietary, no license header

Private Nodes (per ADR-0027 D2) live in private repos with no public license. They carry a short `LICENSE` file stating "All rights reserved. Proprietary to HoneyDrunk Studios LLC." This is not a license to anyone; it's a copyright reservation that makes the IP posture legible to internal collaborators and to GitHub's display.

### D5 — Contribution: DCO (Developer Certificate of Origin), not CLA

External contributions to any Grid repo are accepted under the **Developer Certificate of Origin** (DCO). Contributors `Signed-off-by:` their commits; no separate CLA is signed. The DCO is lighter-weight for both contributor and project, and is sufficient for a single-author project that does not anticipate license relicensing.

CLA may be reconsidered if a future ADR proposes a license change that would require relicensing existing contributions. Until then, DCO.

A GitHub Action enforces `Signed-off-by:` on PRs from non-Studio committers. Studio-employee commits (currently: the sole developer) are exempted because the Studio's IP assignment covers them under the founder's contributions to the LLC (see BDR-0001 / future IP-assignment BDR).

### D6 — License headers in source files: not required

Per-file license headers (`// Copyright (c) HoneyDrunk Studios. Licensed under MIT.`) are **not required**. The repository-root `LICENSE` file is the single source of truth. Per-file headers are:

- Maintenance burden (drift between files, drift between headers and root license).
- Noise at the top of every file with no enforcement benefit.
- Not legally necessary for MIT or FSL.

Exception: **third-party code** brought into the Grid carries its original license header verbatim. This is non-negotiable and standard practice.

### D7 — Documentation and content: CC-BY-4.0

`HoneyDrunk.Architecture` (this repo) and any future documentation surface license **content** under **CC-BY-4.0**. Code in those repos (Markdown is borderline; embedded code snippets are clearly code) is MIT.

The Studios marketing site (per ADR-0029) is a separate license posture (private/proprietary) and is not addressed here.

### D8 — License catalog

`catalogs/nodes.json` gains a `license` field per Node with the SPDX expression (MIT, FSL-1.1-MIT, proprietary). The catalog is the single source of truth; ADR-0034's `Directory.Build.props` and CI gates derive from it. `hive-sync` (ADR-0014) reconciles the catalog with each repo's actual `LICENSE` file.

### D9 — License changes are an ADR amendment

Changing a Node's license is a one-way door (you cannot un-MIT a previously released version). License changes require:

- An ADR amendment to this ADR (or a superseding ADR).
- A `LICENSE.next` file committed alongside the existing `LICENSE` for at least one minor release before the change takes effect.
- A `<PackageReleaseNotes>` entry on the next package release explicitly calling out the license change.
- For FSL-licensed Nodes, no shortening of the MIT delay window.

This procedure is mandatory because the upstream-consumer impact of a license surprise is high and irreversible for already-shipped versions.

## Consequences

### Affected Nodes

- **Every public Node** — `LICENSE` file reviewed and updated to MIT if not already; per-project `<PackageLicenseExpression>` set per ADR-0034 D3.
- **HoneyDrunk.Notify** — `LICENSE.md` is the FSL text (already established by ADR-0027); reaffirmed by this ADR.
- **HoneyDrunk.Communications** — same as Notify.
- **HoneyDrunk.Notify.Sdk** — per-project LICENSE override to MIT (D3).
- **HoneyDrunk.Notify.Cloud** — proprietary, no public license (D4).
- **HoneyDrunk.Architecture** — content license added (D7); `catalogs/nodes.json` schema extended (D8).
- **HoneyDrunk.Actions** — adds a DCO sign-off enforcement job to the PR-validation workflow (D5).

### Invariants

Adds two:

- **Invariant: every Node has a `license` field in `catalogs/nodes.json` and a matching `LICENSE` file in the repo root.** Drift is reconciled by `hive-sync`.
- **Invariant: SDK packages do not inherit the engine's restrictive license.** Per-project override required when the engine is FSL.

### Operational Consequences

- The DCO sign-off job adds a small friction to external contributions. The Studio is single-author today; the friction is theoretical until the first external PR.
- FSL semantics include "non-compete" wording that is novel to most consumers; the README of FSL-licensed repos must explain it briefly. (ADR-0027 already commits to this.)
- License catalog reconciliation is a new `hive-sync` responsibility; the first run will surface existing LICENSE-file inconsistencies as drift to clean up.
- License headers being absent from source files (D6) may surprise contributors used to other projects. The repo CONTRIBUTING.md (per repo) documents the convention.

### Follow-up Work

- Audit every public repo's current `LICENSE` file against the policy; open packets for drift (most should be MIT already by accident; a couple may be stale or missing).
- Extend `catalogs/nodes.json` schema with the `license` field; backfill all entries.
- Wire the DCO sign-off Action in HoneyDrunk.Actions as a reusable workflow; consumer PR-validation workflows call it.
- Author short README sections on each FSL-licensed repo explaining the license (one paragraph + link to the FSL FAQ).
- Add license-change procedure (D9) to the ADR amendment template.

## Alternatives Considered

### Apache-2.0 default instead of MIT

Considered. Apache's patent grant is real value for consumers who care about it (large enterprises, IP-conscious orgs). Rejected on weight: the .NET ecosystem skews MIT; the Studio has no patent portfolio to grant; MIT's brevity is a meaningful signal of "no surprises." Reconsidered if a substantial consumer specifically requires Apache.

### BSL (Business Source License) instead of FSL for revenue Nodes

Considered. BSL is the older sibling; FSL is its 2023 simplification. Rejected because BSL allows per-license-grant variation (each project can pick its own terms within the BSL frame), which makes downstream legal review harder. FSL's two variants (MIT delay or Apache delay) are simple to reason about.

### AGPL for revenue Nodes

Rejected. AGPL is a copyleft hammer; it discourages adoption by exactly the audience the FSL non-compete clause is designed to permit (downstream non-competing commercial use). Wrong tool.

### CLA instead of DCO

Rejected at current scale. A CLA buys the right to relicense and the right to enforce IP claims on contributions. The Studio doesn't anticipate relicensing (D9 procedure is deliberately heavy); doesn't anticipate contributor-driven IP enforcement (DCO is sufficient); doesn't want to administer a CLA-bot workflow. Reconsidered if either anticipation changes.

### Per-file license headers required

Rejected (D6). Net cost > net benefit. The root LICENSE file is unambiguous; per-file headers drift and add noise. Standard practice in many large OSS projects (the .NET runtime itself, for instance) is to skip per-file headers.

### No license decision at all (keep status quo of unset / MIT-by-accident)

Rejected by ADR-0034's `<PackageLicenseExpression>` requirement. Once Abstractions packages publish to nuget.org, the absence of a license decision is itself a decision — and an unfriendly one.
