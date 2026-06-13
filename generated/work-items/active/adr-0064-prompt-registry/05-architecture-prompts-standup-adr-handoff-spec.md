---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ai", "docs", "adr-0064", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0064"]
wave: 2
initiative: adr-0064-prompt-registry
node: honeydrunk-architecture
---

# Author the paired HoneyDrunk.Prompts standup ADR handoff specification

## Summary
Author the handoff specification at `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` (or equivalent doc location matching the existing walkthrough convention) that the paired `HoneyDrunk.Prompts` standup ADR's adr-composer agent reads as input. The specification captures everything ADR-0064 D12 defers to the standup ADR — repo layout, solution structure, the three planned packages, CI pipeline (including the contract-shape and content-shape canaries per invariant `{N4}` from packet 01), HoneyDrunk.Standards wiring, sector placement, the catalog rows that need to land with the standup, the seed migration packet (Honeyclaw + Lore extraction), and the Honeyclaw OpenClaw export workflow. **This packet does not file the standup ADR itself** — that is a separate adr-composer invocation per Required Decision 2 in packet 00. This packet authors the spec the adr-composer reads.

## Context
ADR-0064 D12 commits the paired-standup-ADR pattern explicitly:

> This ADR commits the policy — what gets stored, how it versions, how runtime resolution works, the audit emit, the schema, the loader shape. The Node shape — repo layout, solution structure, CI pipeline, contract-shape canary, scaffold packet contents — is a separate paired standup ADR following the precedent set by the ADR-0058 / ADR-0059 pair.

The standup ADR has not been drafted at the time this packet executes (per Required Decision 2 in packet 00 — both Posture A "file now" and Posture B "defer" are acceptable; the recommendation is Posture B). This packet's job is to author the *specification* the adr-composer agent reads as input when it drafts the standup ADR — whether that draft happens in this initiative's filing window (Posture A) or after this initiative completes (Posture B), the spec is the same.

The pattern mirrors ADR-0067's packet 05 (the Notify Cloud rate-limit policy specification authored as a handoff to the future Notify Cloud follow-up packet, filed after the Notify Cloud standup completes). The shape is: a Markdown document under `infrastructure/walkthroughs/` (or equivalent) that captures the full design intent in one place; the future drafter reads it and turns it into an ADR or a packet set without re-deriving the design.

This is a docs / specification packet. No code, no .NET project, no ADR file created.

## Scope
- `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` (or equivalent path matching the repo's walkthrough convention — verify the existing folder name at edit time; if the convention is `infrastructure/walkthroughs/` add there; if it is `docs/walkthroughs/` add there; if neither, default to `infrastructure/walkthroughs/`) — author the specification document.
- `initiatives/active-initiatives.md` — update the `adr-0064-prompt-registry` initiative entry's exit criteria to reference this spec as the handoff artifact for the paired standup ADR.
- No ADR file created in this packet — that is the adr-composer agent's separate invocation per Required Decision 2.

## Proposed Implementation
1. **Confirm the walkthrough folder location.** Scan the repo to find the existing walkthrough document location (`infrastructure/walkthroughs/`, `docs/walkthroughs/`, or another convention). If multiple exist, prefer the one with the most recent sibling spec (e.g., ADR-0067's `notify-cloud-rate-limit-policy.md` should give the canonical location). If no walkthrough folder exists yet, create `infrastructure/walkthroughs/` and place the file there.

2. **Author the specification.** The spec document has the following sections:

   ### Section: Overview

   - **Purpose:** This document is the specification the paired `HoneyDrunk.Prompts` standup ADR's adr-composer agent reads as input. The policy ADR (ADR-0064) commits *what* the registry is and *what rules* it follows; this spec captures *what the Node looks like* — repo layout, solution structure, CI pipeline, contract-shape canary, scaffold packet contents.
   - **Out of scope of this spec:** the policy decisions themselves (those live in ADR-0064). Hot-reload, per-prompt semver, App-Configuration-as-storage, and database-backed prompts are all explicitly rejected in ADR-0064 and are not re-litigated here.
   - **Precedent:** ADR-0058 / ADR-0059 (the Cache policy / standup pair). The Cache standup ADR is the closest analog in shape; reading ADR-0059 alongside this spec gives the adr-composer the right template.

   ### Section: Repo creation

   - **Repo name:** `HoneyDrunkStudios/HoneyDrunk.Prompts`.
   - **Visibility:** **Public** (per the user's "repos public by default" memory and ADR-0064 D10's rationale — Restricted-tier content is forbidden, secret-scan is enforced; nothing in the repo justifies private visibility).
   - **License:** matches the rest of the Grid's public repos (Apache 2.0 or MIT — verify at standup-ADR time; do not pin here).
   - **Branch protection:** standard Grid posture per ADR-0011 (tier-1 gate required on every PR, no force-push to main).

   ### Section: Solution layout

   The standup ADR's scaffold packet creates three .NET projects in one solution:

   - **`HoneyDrunk.Prompts.Abstractions`** — the contract layer. Contains `IPromptResolver` interface and the supporting record types (`PersonaId`, `PromptId`, `PersonaContent`, `PromptContent`, `ResolvedMessages`). Zero runtime dependencies on other Grid packages — only `Microsoft.Extensions.*` abstractions per the abstractions-package invariant.
   - **`HoneyDrunk.Prompts`** — the default `IPromptResolver` implementation. Depends on `HoneyDrunk.Prompts.Abstractions` and Kernel primitives (`Microsoft.Extensions.*` for DI/options/logging). Embeds the prompt and persona content files (`personas/*.persona.md`, `prompts/{owner-node}/*.prompt.md`) as compile-time content in the package output.
   - **`HoneyDrunk.Prompts.Tests.Fakes`** — the test-time fake. Provides `InMemoryPromptResolver` for consumer tests that need to stub the registry without including the full prompts package. Test-time only per the convention established by ADR-0019 (Communications).

   All three projects share one solution version per invariant 27. The repo-level `CHANGELOG.md` is the source of truth for releases.

   ### Section: HoneyDrunk.Standards wiring

   Every `.csproj` references `HoneyDrunk.Standards` with `PrivateAssets: all` per invariant 26 (StyleCop + EditorConfig analyzers).

   ### Section: CI pipeline

   The standup ADR's CI packet wires the standard reusable workflows from `HoneyDrunk.Actions`:

   - **`pr-core.yml`** — build, unit tests, analyzers, vulnerability scan, secret scan per ADR-0011 D2. Required branch-protection check.
   - **`job-api-compatibility.yml`** — scoped to `HoneyDrunk.Prompts.Abstractions`. Fails the build on shape drift to `IPromptResolver` or the supporting record types without a paired version bump. **This is the contract-shape canary** required by invariant `{N4}` (ADR-0064) — full text: "the `HoneyDrunk.Prompts` package's CI must include (a) a contract-shape canary on `IPromptResolver` that fails the build on shape drift … without a corresponding version bump."
   - **A new content-shape canary** (filed as a separate step in `pr-core.yml`-equivalent or as a dedicated workflow) — asserts every `.persona.md` and `.prompt.md` file's frontmatter parses cleanly (YAML), and for every prompt file, every `{{ parameter_name }}` placeholder in the body has a matching entry in the file's `parameters` frontmatter list (and vice versa). **This is the content-shape canary** required by invariant `{N4}` (ADR-0064). The implementation may be a small custom check (a build-time C# tool that reads the content files and the frontmatter, parses placeholders, and asserts parity) — the obligation is to keep the gate, not to use any specific implementation.
   - **A classification gate** — fails the build if any file's frontmatter declares `classification: Restricted` (forbidden per ADR-0064 D10 / invariant `{N2}`). The secret-scan in `pr-core.yml` covers the secret-values rule from the same invariant.

   ### Section: Sector placement

   - **Sector:** AI (per the `constitution/sectors.md` row added in packet 02 of this initiative).
   - **Cluster:** `cognition` or a new `identity-substrate` cluster — the standup ADR picks. AI's existing clusters in `catalogs/nodes.json` should be reviewed at standup time; if `cognition` is the only cluster, use that.

   ### Section: Catalog rows the standup ADR's catalog packet adds

   The standup ADR's catalog packet adds the following rows (these are the rows ADR-0064 §Catalog and Reference Updates Required enumerates — repeated here for the adr-composer's convenience):

   - **`catalogs/nodes.json`** — `honeydrunk-prompts` entry: name `HoneyDrunk.Prompts`, sector `AI`, signal `Seed`, public visibility, short description "Prompt and persona registry — versioned content, audit-anchored tuple emit, snapshot-at-deploy."
   - **`catalogs/relationships.json`** — `honeydrunk-prompts` with `consumes: ["honeydrunk-kernel"]` (the loader runtime uses Kernel primitives for lifecycle and DI); `consumed_by_planned: ["honeydrunk-ai", "honeydrunk-agents", "honeydrunk-operator", "honeydrunk-memory", "honeydrunk-knowledge", "honeydrunk-evals", "honeydrunk-lore"]`; `exposes.contracts: ["IPromptResolver", "PersonaId", "PromptId", "PersonaContent", "PromptContent", "ResolvedMessages"]`; `exposes.packages: ["HoneyDrunk.Prompts.Abstractions", "HoneyDrunk.Prompts", "HoneyDrunk.Prompts.Tests.Fakes"]`.
   - **`catalogs/grid-health.json`** — Node row for `honeydrunk-prompts`.
   - **`catalogs/modules.json`** — Node entry with the three planned packages.
   - **`catalogs/contracts.json`** — `IPromptResolver` (kind: interface), `PersonaId` / `PromptId` / `PersonaContent` / `PromptContent` / `ResolvedMessages` (kind: record), each with a one-line description matching the existing entry shape.
   - **`infrastructure/reference/tech-stack.md`** — add `HoneyDrunk.Prompts` to the current Nodes table once the standup ADR ships.
   - **`repos/HoneyDrunk.Prompts/`** — folder with `overview.md`, `boundaries.md`, `invariants.md`. The standup ADR's docs packet authors these.

   The naming-rule discipline (memory `project_naming_rule_records`): `IPromptResolver` retains the `I` prefix (interface); `PersonaId`, `PromptId`, `PersonaContent`, `PromptContent`, `ResolvedMessages` drop the `I` (records).

   ### Section: Seed migration packet (Honeyclaw + Lore)

   The standup ADR includes a migration packet that seeds the registry with the personas and prompts already running in production:

   - **`personas/honeyclaw-bear-keeper.persona.md`** — extracted from OpenClaw config. The bear-keeper persona is in production today (memory `project_honeyclaw_bot`); it lives in OpenClaw's third-party gateway config; this migration brings the source of truth to the Grid per ADR-0064 D7. Frontmatter: `id: honeyclaw-bear-keeper`, `kind: persona`, `version: 0.1.0`, `owner: honeydrunk-lore` (or a Honeyclaw-specific owner if a Node lands; until then Lore is the closest owner that ships an AI-mediated surface), `classification: Public` (the bear-keeper persona has no PII; it is a public-facing persona definition), `created: <extraction-date>`, `notes: "Extracted from OpenClaw gateway config. Honeyclaw Telegram bot's bear-keeper voice — the user is Oleg, the emoji is 🍯."`. Body: the verbatim system-prompt text from OpenClaw.
   - **`prompts/honeydrunk-lore/wiki-ingest.prompt.md`** — extracted from the Lore wiki-ingestion skill (memory `project_lore_sourcing_workflow`). Frontmatter per the schema, including a `parameters` list for whatever placeholders the ingest prompt uses today; body: verbatim ingest-prompt text.
   - **Any other prompts already inlined in seed Nodes** — at file time, no other seed Nodes have shipped feature work (the AI-sector standups are at scaffold stage), so the migration is the two above. The migration packet is small.

   ### Section: Honeyclaw OpenClaw export workflow

   Per ADR-0064 D7, the Grid `HoneyDrunk.Prompts` repo is the source of truth for Honeyclaw's persona even though Honeyclaw runs in third-party OpenClaw infrastructure. The export workflow:

   - Runs on every `HoneyDrunk.Prompts` release (i.e., when a new prompts package version ships).
   - Reads `personas/honeyclaw-bear-keeper.persona.md` from the just-released package.
   - Writes it to OpenClaw's configured location — exact mechanism deferred to the standup ADR's decision: (a) a private GitHub gist OpenClaw polls; (b) a Vault-stored OpenClaw config blob the user manually applies via the OpenClaw TUI; (c) a direct OpenClaw API call (if the OpenClaw gateway exposes a config-update endpoint at the time of standup).
   - **No runtime HTTP call** from OpenClaw into the Grid per D7.

   The workflow may live in `HoneyDrunk.Prompts` itself or in a paired `HoneyDrunk.OpenClaw` integration package; the standup ADR picks. Until the workflow exists, the user manually copies the persona text from the Grid repo to OpenClaw at each release.

   ### Section: PDR-app personas (forward-looking)

   Per ADR-0064 D8, Hearth (the first-build pick per the `project_app_concepts_2026_05_05` memory), Lately, Curiosities, and any future consumer-PDR app registers its persona in `HoneyDrunk.Prompts` at the app's first AI-enabled feature packet. The standup ADR does not author these personas (the apps do not yet exist); but the standup ADR's `repos/HoneyDrunk.Prompts/overview.md` should reference this pattern so future PDR-app authors find the discipline documented.

   ### Section: Forward-looking — Evals release gate

   Per ADR-0064 D6, a future Evals-side ADR may add Evals as a release gate for the prompts package: a major or minor bump cannot publish without all affected suites passing. The standup ADR records this as a deferred follow-up; it does not implement it.

   ### Section: Acceptance gate — what the standup ADR's exit criterion looks like

   The standup ADR's exit criterion is satisfied when:

   - `HoneyDrunk.Prompts` repo exists, is public, has the three projects, the CI pipeline (with the contract-shape canary, the content-shape canary, the classification gate, and the standard `pr-core.yml` gates).
   - The seed migration has landed: `personas/honeyclaw-bear-keeper.persona.md` and `prompts/honeydrunk-lore/wiki-ingest.prompt.md` are in the repo, the package is published, the catalog rows are in place.
   - The Honeyclaw OpenClaw export workflow is wired (or the manual-copy interim is documented for the user).
   - The first downstream Node that consumes `IPromptResolver` (likely `HoneyDrunk.Lore` for the wiki-ingest skill migration, since it has the closest-to-ready dependency) has its first registry-aware feature packet ready to ship.

3. **Update `initiatives/active-initiatives.md`** to reference this spec from the `adr-0064-prompt-registry` initiative entry's exit criteria. Sample wording (adapt to the file's existing style):

   > Exit criteria: ADR-0064 status flip done in packet 00; four invariants live in `constitution/invariants.md`; AI sector table records the Prompts Node placeholder; Audit emit contract documented at canonical metadata-key shape; agent checklists updated; standup handoff spec authored at `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md`. The paired `HoneyDrunk.Prompts` standup ADR's drafting and acceptance, and the Node scaffold itself, are out of scope of this initiative and tracked separately per Required Decision 2 in packet 00.

4. **Do NOT file the standup ADR itself.** The adr-composer agent's invocation is a separate human action per Required Decision 2 (Posture A "now" or Posture B "after this initiative"). This packet only authors the spec the adr-composer reads.

## Affected Files
- `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` (or the equivalent walkthrough-folder path the repo uses) — new specification document.
- `initiatives/active-initiatives.md` — exit-criteria reference to the spec.

## NuGet Dependencies
None. Markdown-only packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No ADR file created — the standup ADR's drafting is a separate adr-composer invocation.
- [x] No catalog or `repos/*` edits — those land with the standup ADR's packets, not here.

## Acceptance Criteria
- [ ] `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` (or the equivalent location in the repo's walkthrough convention) exists and carries the spec sections enumerated in §Proposed Implementation Step 2
- [ ] The spec records the public-repo visibility decision (per ADR-0064 D10 and the user's repos-public-by-default memory)
- [ ] The spec records the three-project solution layout (`HoneyDrunk.Prompts.Abstractions`, `HoneyDrunk.Prompts`, `HoneyDrunk.Prompts.Tests.Fakes`) per ADR-0064 D11
- [ ] The spec records the CI pipeline obligations: `pr-core.yml`, `job-api-compatibility.yml` (contract-shape canary on `IPromptResolver`), a content-shape canary (frontmatter parse + `{{ }}` placeholder ↔ `parameters` parity), and a classification gate (no `classification: Restricted`) per invariants `{N2}` and `{N4}` from packet 01
- [ ] The spec records the catalog rows the standup ADR's catalog packet must add (nodes.json, relationships.json, grid-health.json, modules.json, contracts.json, tech-stack.md, repos/HoneyDrunk.Prompts/)
- [ ] The spec records the seed migration packet's contents: `honeyclaw-bear-keeper.persona.md` and `lore-wiki-ingest.prompt.md`, with frontmatter shape per D9
- [ ] The spec records the Honeyclaw OpenClaw export workflow per D7 (build/release-step, no runtime HTTP)
- [ ] The spec records the PDR-app pattern forward-look per D8 and the Evals release-gate forward-look per D6
- [ ] The spec records the standup ADR's exit criteria
- [ ] The spec's contract names follow the naming rule: `IPromptResolver` keeps `I` (interface); `PersonaId`, `PromptId`, `PersonaContent`, `PromptContent`, `ResolvedMessages` drop `I` (records)
- [ ] `initiatives/active-initiatives.md` exit criteria references the spec by path
- [ ] No ADR file is created
- [ ] No catalog or `repos/*` edits

## Human Prerequisites
- [ ] Required Decision 2 (paired standup ADR filing posture) resolved in packet 00's PR. Whether Posture A ("file standup ADR now") or Posture B ("defer"), this packet's spec is the same. **If Posture A** — after this packet merges, invoke the adr-composer agent with prompt "Stand up `HoneyDrunk.Prompts` per ADR-0064 D12, reading `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` as input." **If Posture B** — file the same invocation as a follow-up task after the initiative completes.

## Referenced ADR Decisions
**ADR-0064 D6 — Evals integration.** A future Evals-side ADR may add Evals as a release gate for the prompts package; the spec records this as a deferred follow-up.

**ADR-0064 D7 — Honeyclaw integration.** The Grid registry is the source of truth for Honeyclaw's persona; export via a build/release step, not a runtime HTTP call from OpenClaw into the Grid.

**ADR-0064 D8 — PDR-app personas registered from day one.** The spec records the pattern; PDR apps do not yet exist so no personas are authored at standup time.

**ADR-0064 D9 — On-disk schema.** Path convention `personas/{id}.persona.md` and `prompts/{owner-node}/{id}.prompt.md`; YAML frontmatter; double-brace `{{ parameter_name }}` placeholders.

**ADR-0064 D10 — PII and sensitive content.** Public-or-internal text artifacts only; CI gate forbids `Restricted` classification and runs secret-scan; reviewer-agent rule per ADR-0044.

**ADR-0064 D11 — Loader location.** `IPromptResolver` in `HoneyDrunk.Prompts.Abstractions`; default impl in `HoneyDrunk.Prompts`; test-time fake in `HoneyDrunk.Prompts.Tests.Fakes`.

**ADR-0064 D12 — Paired standup ADR.** Explicit: the standup ADR is a separate ADR following the ADR-0058 / ADR-0059 precedent. Folding the standup into the policy ADR would set the wrong precedent.

**ADR-0058 / ADR-0059 precedent.** ADR-0059 is the standup ADR for the Cache Node (the standup paired to ADR-0058's policy). Reading ADR-0059's text gives the adr-composer the right template for the `HoneyDrunk.Prompts` standup ADR.

**ADR-0067 packet 05 precedent.** The Notify Cloud rate-limit policy specification authored as a handoff to a future follow-up packet. Same shape as this packet — author the spec in the Architecture repo at `infrastructure/walkthroughs/`, the future drafter reads it.

## Constraints
- **No ADR file created.** The standup ADR's drafting is the adr-composer agent's separate invocation per Required Decision 2 in packet 00.
- **No catalog or `repos/*` edits.** The catalog rows, the `repos/HoneyDrunk.Prompts/` folder, and the `infrastructure/reference/tech-stack.md` row all land with the standup ADR's packet set, not in this initiative.
- **Spec captures the design intent, not the implementation.** The adr-composer agent reads the spec and turns it into an ADR; the ADR turns into packets; the packets implement. This spec is the input to that chain.
- **Public-repo visibility is declared.** The spec records `HoneyDrunkStudios/HoneyDrunk.Prompts` as public per ADR-0064 D10 and the user's repos-public-by-default memory.
- **The naming rule is observed in the spec.** `IPromptResolver` keeps `I`; the record types drop it.
- **CI obligations are explicit on the canaries.** The spec records both the contract-shape canary (per invariant `{N4}`) and the content-shape canary (placeholder ↔ parameters parity), and the classification gate (per invariant `{N2}`). Without these in the spec, the standup ADR risks shipping CI that does not satisfy the invariants.
- **No code change anywhere.** This packet is a Markdown specification; no `.csproj` is touched, no project is created.

## Labels
`chore`, `tier-3`, `ai`, `docs`, `adr-0064`, `wave-2`

## Agent Handoff

**Objective:** Author the `HoneyDrunk.Prompts` standup ADR handoff specification at `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` (or the repo's equivalent walkthrough path). The spec captures everything ADR-0064 D12 defers to the standup ADR — repo layout, solution structure, CI pipeline (including both canaries per invariant `{N4}`), catalog rows, seed migration, Honeyclaw export workflow. No ADR file created in this packet; no catalog edits; no `repos/*` folder creation.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Give the future adr-composer invocation (per Required Decision 2 in packet 00) a single document to read as input when it drafts the paired `HoneyDrunk.Prompts` standup ADR.
- Feature: ADR-0064 Prompt and Persona Registry rollout, Wave 2.
- ADRs: ADR-0064 D6 / D7 / D8 / D9 / D10 / D11 / D12 (primary), ADR-0058 / ADR-0059 (paired-standup-ADR precedent), ADR-0067 packet 05 (deferred-follow-up-spec precedent).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — initiative registered, Required Decisions surfaced. The spec is the same regardless of which posture (A or B) is chosen for Required Decision 2; the spec can be authored before the human picks.

**Constraints:**
- No ADR file created. No catalog or `repos/*` edits.
- Spec captures design intent; the adr-composer turns it into ADR text.
- Public-repo visibility declared.
- Naming rule observed (interfaces keep `I`, records drop it).
- CI obligations explicit on both canaries and the classification gate.

**Key Files:**
- `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` (or repo's equivalent walkthrough location) — new spec document.
- `initiatives/active-initiatives.md` — exit-criteria reference to the spec.

**Contracts:** None changed. The spec describes contracts (`IPromptResolver`, the record types) that the standup ADR's contract packet authors in `HoneyDrunk.Prompts.Abstractions` — not in this packet.
