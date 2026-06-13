---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0079", "wave-1"]
dependencies: ["work-item:00"]
adrs: ["ADR-0079", "ADR-0044"]
accepts: ["ADR-0079"]
wave: 1
initiative: adr-0079-pr-review-stack
node: honeydrunk-architecture
---

# Author the `.coderabbit.yaml` Grid template and record the substantive-PR safe-list as a cross-cutting policy note

## Summary
Author the Grid's reference `.coderabbit.yaml` template — the per-repo CodeRabbit configuration shape every repo can copy when it opts in — and record the ADR-0079 D3 substantive-PR safe-list as a single-source cross-cutting policy note where the Grid keeps such notes. The template and the policy note are governance artifacts; per-repo `.coderabbit.yaml` adoption is a follow-up fan-out item, not in scope here.

## Context
ADR-0079 D1 names CodeRabbit as Reviewer 2 — a third-party AI reviewer providing vendor-independence (not Microsoft, not Anthropic) for ~$24/dev/mo. CodeRabbit supports a `.coderabbit.yaml` configuration file at repo root for repo-specific patterns (severity floors, path filters, language tunings, the Grid's invariant cross-links). Today, no repo in the Grid carries a `.coderabbit.yaml` — CodeRabbit operates on its defaults across every repo it reviews. This packet establishes the Grid template.

ADR-0079 D3's substantive-PR safe-list (`*.md`, `*.mdx`, `*.txt`, `docs/**`, `LICENSE*`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `docs/assets/**`) is the mechanical classifier for "Reviewer 4 runs" vs "Reviewer 4 skipped." Today the list lives only in ADR-0079's body. The list will be **consumed by `HoneyDrunk.Actions`** (packet 02 embeds the list in-workflow with a CI drift check against this note) — placing it as a cross-cutting policy note in `business/context/`, with packet 02 pointing at this note as the source of truth, ensures the list is **one artifact**, not duplicated between ADR + workflow + docs. `business/context/` today holds only `entity.md` and `operating-costs.md`; this note will be the first cross-cutting policy artifact filed there, and the placement establishes the convention.

**No new App Insights / Azure resource.** This packet is governance/docs only.

**Per-repo `.coderabbit.yaml` adoption is deferred.** Each repo's CodeRabbit configuration is incremental, repo-by-repo, driven by observed reviewer noise — not a blocking pre-condition for ADR-0079. The dispatch plan's "Per-repo `.coderabbit.yaml` fan-out (deferred)" section names the rationale. This packet ships only the **canonical template + placement convention** so per-repo adoption is mechanical when a repo chooses to opt in.

This is a docs/governance packet. No code, no .NET project.

## Scope
- **A canonical `.coderabbit.yaml` template** at `templates/.coderabbit.yaml` (or the existing templates location in `HoneyDrunk.Architecture`; if no such location exists, create `templates/` and document the convention). The template captures the Grid's reference shape — severity floor, path filters, language tunings, integration-with-Grid-invariants pointer.
- **A cross-cutting policy note recording the ADR-0079 D3 substantive-PR safe-list** at `business/context/` (the location used by `entity.md` and `operating-costs.md`; this packet establishes the convention for cross-cutting policy notes filed alongside the existing entity/cost context). The note is the **single source of truth** for the safe-list — ADR-0079 binds the principle, this note carries the canonical list, packet 02 reads from it.
- **A short README accompanying the template** at `templates/README.md` (or appended to an existing templates README) explaining: when to adopt, how to adopt (copy to repo root, no other steps), and that per-repo refinement is incremental.
- The repo `CHANGELOG.md` updated per repo convention.

## Proposed Implementation
1. **Create `templates/.coderabbit.yaml`** (or match the existing templates location convention). The template body — based on CodeRabbit's documented configuration surface; if the surface has shifted at execution time, research the current options and adapt — should include at minimum:
   - **Header comment** stating this is the Grid's reference template, the source-of-truth ADR (ADR-0079 D1), and per-repo refinement is welcome but optional.
   - **Severity floor** — sensible default (e.g. `suggestions: true`, `nits: false`) so the Grid does not drown in style-only comments.
   - **Path filters** — skip `**/generated/**`, `**/*.Designer.cs`, `**/*.g.cs`, and the same `docs/assets/**` patterns the substantive-PR safe-list uses for "obvious-no-code-impact" files.
   - **Language tuning** — opinionated defaults for the Grid's primary languages (C#, TypeScript, YAML, Bicep, Markdown).
   - **A pointer comment** to the Grid's invariants — CodeRabbit cannot enforce invariants directly, but a comment at the top makes future readers aware that the Grid-aware `review` agent (Reviewer 3/4) is the authoritative invariant-enforcing path; CodeRabbit's role is third-party-vendor-independent generic AI review.
   - **No secret values, no DSNs, no API keys** (invariant 8 — `.coderabbit.yaml` is a public repo file).
2. **Add `templates/README.md` (or extend the existing one)** explaining the adoption flow:
   - When to adopt: any repo where the operator wants to refine CodeRabbit's defaults (severity floor, path filters) for repo-specific patterns. Without a `.coderabbit.yaml`, CodeRabbit uses its own defaults — which is fine for v1.
   - How to adopt: copy `templates/.coderabbit.yaml` to the repo root, commit, push. No CI change is required — CodeRabbit reads the file automatically.
   - Per-repo refinement: for example, the Vault repo's secret-handling patterns may want a higher severity floor on `**/Vault/**` paths; the Audit repo may want a stricter review of `**/Audit/**` append-only patterns. These are per-repo decisions; the template is the starting point.
3. **Add a cross-cutting policy note recording the substantive-PR safe-list.** Create the note at `business/context/` alongside the existing `entity.md` and `operating-costs.md` — this is the first cross-cutting policy note filed there, establishing the convention for future Grid-level policy artifacts that don't naturally fit in `adrs/` or `constitution/`. Title the file along the lines of `pr-review-substantive-safe-list.md`. The note's body must:
   - State the canonical safe-list verbatim from ADR-0079 D3:
     - `*.md`
     - `*.mdx`
     - `*.txt`
     - `docs/**`
     - `LICENSE*`
     - `SECURITY.md`
     - `CODE_OF_CONDUCT.md`
     - `CONTRIBUTING.md`
     - `docs/assets/**`
   - State the classification rule: a PR whose entire changeset is inside the safe-list is **trivial** (Reviewer 4 skipped); any file outside the safe-list makes the PR **substantive** (all four reviewers run, where Reviewer 4 is enabled post-June-15).
   - State the mechanical-classifier discipline: no LLM judgment, no label-based override, no commit-message escape (invariant 55).
   - Name itself as the single source of truth — `HoneyDrunk.Actions`'s classifier workflow (packet 02) reads from this note's safe-list, never from a duplicated copy.
   - Reference invariant 55 (the safe-list-classifier invariant) and ADR-0079 D3.
4. **Update the repo `CHANGELOG.md`** per repo convention with a one-line entry referencing this packet and ADR-0079.

## Affected Files
- `templates/.coderabbit.yaml` (new)
- `templates/README.md` (new or extended)
- A safe-list cross-cutting policy note at `business/context/` (new — first cross-cutting policy note in that directory; convention established by this packet).
- `CHANGELOG.md`

## NuGet Dependencies
None. This packet touches only Markdown, YAML configuration templates, and governance notes; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No per-repo `.coderabbit.yaml` is adopted by this packet — the template lands; per-repo adoption is the deferred fan-out.
- [x] No CI/workflow change — packet 02 is the workflow change.

## Acceptance Criteria
- [ ] `templates/.coderabbit.yaml` exists, contains the Grid's reference CodeRabbit configuration shape, carries a header comment naming ADR-0079 D1 as the source ADR, and contains no secret values or API keys (invariant 8)
- [ ] `templates/README.md` (new or extended) documents when to adopt, how to adopt, and per-repo refinement guidance
- [ ] A cross-cutting policy note in `business/context/` records the ADR-0079 D3 substantive-PR safe-list verbatim, states the classification rule and the mechanical-classifier discipline, names itself as the single source of truth for downstream consumers, and references invariant `{N2}` (packet 00's safe-list classifier invariant)
- [ ] No per-repo `.coderabbit.yaml` is adopted by this packet — the deferred fan-out remains explicit in the dispatch plan
- [ ] The repo `CHANGELOG.md` is updated per repo convention
- [ ] No invariant change (the four PR-review-stack invariants land in packet 00)
- [ ] No workflow change (the classifier lands in packet 02)

## Human Prerequisites
- [ ] **CodeRabbit subscription provisioning.** ADR-0079 D1 names CodeRabbit at ~$24/dev/mo. The operator's CodeRabbit account / GitHub App must be installed on the relevant repos for CodeRabbit reviews to fire. This is a one-time portal step (or per-repo install) outside this packet's scope; until done, packet 01's template is inert in any repo that adopts it.

## Referenced ADR Decisions
**ADR-0079 D1 — CodeRabbit is Reviewer 2.** Third-party AI reviewer providing vendor-independence (not Microsoft Copilot, not Anthropic Claude). ~$24/dev/mo. Supports `.coderabbit.yaml` for repo-specific patterns. Generic, not Grid-aware — the Grid-aware role belongs to Reviewers 3/4 (the `review` agent).

**ADR-0079 D3 — Substantive-PR classifier safe-list.** Mechanical file-path-glob check. Any PR whose entire changeset stays inside the safe-list is trivial; any file outside makes the PR substantive. No LLM judgment, no per-PR override.

**ADR-0079 D9 — Per-PR reviewer override is forbidden.** No label, no commit message can opt out of a reviewer. The classifier is mechanical.

**Invariant 8 (referenced) — Secret values never appear in logs, traces, exceptions, or telemetry — or in workflow / config files.** The `.coderabbit.yaml` template carries no secret values, no DSNs, no API keys; CodeRabbit authenticates via its installed GitHub App.

**Invariant `{N2}` (packet 00) — Substantive-PR classifier is the safe-list in ADR-0079 D3; per-PR override is forbidden.** This note is the canonical single source of truth for the list.

## Constraints
> **Invariant 8 — No secrets in config files.** The `.coderabbit.yaml` template is a public-repo artifact — no DSNs, no API keys, no secret values.

- **One source of truth for the safe-list.** The policy note is the single canonical list; ADR-0079's body and `HoneyDrunk.Actions`'s classifier (packet 02) point at this note, never duplicate the list. If a future change to the safe-list is needed, edit the note + reference an amendment to ADR-0079 — not multiple files.
- **Template is sensible defaults, not exhaustive opinions.** The template captures shared baseline (severity floor, path filters, language tunings); per-repo refinement is the per-repo operator's decision.
- **No per-repo adoption in this packet.** Per-repo `.coderabbit.yaml` adoption is the deferred fan-out. This packet ships only the template + placement convention.
- **Header comment on `.coderabbit.yaml` names ADR-0079 D1.** Future readers should see immediately that the template's shape is ADR-bound.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0079`, `wave-1`

## Agent Handoff

**Objective:** Author the Grid's reference `.coderabbit.yaml` template and record the ADR-0079 D3 substantive-PR safe-list as a single-source cross-cutting policy note.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Establish the canonical CodeRabbit configuration shape every repo can copy, and the canonical safe-list every downstream consumer (workflow, docs, future audit) reads from.
- Feature: ADR-0079 Multi-Perspective PR Review Stack rollout, Wave 1.
- ADRs: ADR-0079 D1/D3/D9 (primary), ADR-0044 (the cloud-code-review baseline ADR-0079 amends).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0079 should be Accepted before its decisions are recorded as a template + canonical policy note.

**Constraints:**
- One source of truth for the safe-list — the policy note is canonical; packet 02 will point at it.
- The template is sensible defaults, not exhaustive opinions — per-repo refinement is per-repo operator's call.
- No per-repo adoption in this packet — per-repo `.coderabbit.yaml` is the deferred fan-out.
- No secrets in the template (invariant 8).

**Key Files:**
- `templates/.coderabbit.yaml`
- `templates/README.md`
- The safe-list policy note in `business/context/` (new file — first cross-cutting policy note in that directory).
- `CHANGELOG.md`

**Contracts:** None changed.
