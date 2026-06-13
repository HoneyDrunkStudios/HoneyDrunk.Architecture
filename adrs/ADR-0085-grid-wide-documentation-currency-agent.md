# ADR-0085: Grid-Wide Documentation Currency Agent (`docs-sync`)

**Status:** Proposed
**Date:** 2026-05-26
**Deciders:** HoneyDrunk Studios
**Sector:** Meta

## Context

The Grid has 25+ repos. Each repo ships its own documentation surface:

- **Root `README.md`** (every repo) — purpose, install/quickstart, top-level public API summary, badges, contributing pointer.
- **Per-package `README.md`** (one per package directory inside a solution) — required by Invariant 12.
- **Root `CHANGELOG.md`** (every repo) — required by Invariant 12; sourced by `HoneyDrunk.Actions` release-notes composite.
- **Per-package `CHANGELOG.md`** — required when the package itself has functional changes (Invariant 12, refined by Invariant 27 to suppress alignment-bump noise).
- **`AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md`** — repo-specific agent guidance.
- **`docs/` content** (where present) and the future Docusaurus sites scoped by [ADR-0075](./ADR-0075-documentation-tooling.md).
- **In-product OpenAPI surfaces** rendered via Scalar per [ADR-0075](./ADR-0075-documentation-tooling.md) D1 — generated, not authored.

None of these has a scheduled keeper. Documentation drift is real and observed:

- `node-audit` (read-only, one-Node-at-a-time, on-demand) routinely surfaces stale READMEs, CHANGELOG gaps, and `AGENTS.md` that no longer matches current practice — but only when an operator invokes it on a specific Node, and the findings sit until a human writes a packet.
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) D3's twenty-category rubric includes "Documentation" at PR-review time, but a PR reviewer only sees the diff — it cannot detect that a Node has been silently drifting for six months across many PRs that each individually felt fine.
- [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md) `hive-sync` reconciles the **Architecture repo** against live state (initiatives, packet lifecycle, README index, drift report). Its mandate is explicitly Architecture-repo-only per D4; it does not touch the docs of any other repo.
- [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) names four backlog-source streams (Strategic, Tactical, Opportunistic, Reactive) but defers `node-audit`'s output to the human-driven weekly briefing on a quarterly per-Node rotation. Doc drift surfaces in that rotation but on a 90-day clock, per-Node, not Grid-wide.

The pattern repeating across recent ADRs (0014, 0030, 0043, 0044, 0058) is **"one owner per substrate-shaped concern, surfaced centrally, executed downstream."** Documentation currency is a substrate-shaped concern — Grid-wide, no current owner, cheap to drift, expensive to find later — and it does not have one.

The further observation that distinguishes documentation from `hive-sync`'s mandate: **the truth lives in two places at once**. `hive-sync` reconciles Architecture-repo files against external truth (issue states, board state, `grid-health.json`) — one direction, one repo. Documentation currency is reconciling per-repo prose against catalog truth (Architecture repo) and against the repo's own current code (the same repo). That cross-cutting shape — read everywhere, reconcile shared truth, write back to the source — is the same shape `site-sync` has for the marketing website. The analogy is load-bearing for D4.

Three forcing functions converging now:

1. **Notify Cloud GA approaches.** First commercial product means external developers encounter Grid docs. A stale `HoneyDrunk.Notify` README on the path to NotifyCloud's first integrator is exactly the first-impression risk [ADR-0075](./ADR-0075-documentation-tooling.md) D1 cited for tooling — but now applied to *content*, not renderer.
2. **`accepts:` packet frontmatter is shipping** (ADR-0014 Phase 5). The Grid now has machine-readable links between ADRs/PDRs and the packets that implement them. A documentation reconciler can use that same chain to ask "this ADR was accepted; does every repo it names actually document the resulting behavior?"
3. **The cascade of ADRs 0026-0082 has produced ~25 contracts named in catalogs** but with no scheduled "did the repo's README catch up?" pass. Doc drift on this scale will not be caught by ad-hoc audits.

This ADR commits a **scheduled, full-sweep, write-authorized central agent (`docs-sync`)** that detects documentation drift Grid-wide and reconciles it directly via per-repo PRs. It composes with — and extends — the existing `proposed/` packet pipeline rather than replacing it.

The ADR is bounded: it covers the **Markdown documentation surface inside each repo** (README, CHANGELOG, AGENTS, CLAUDE, copilot-instructions, `docs/`). It explicitly carves out: in-product OpenAPI rendering (ADR-0075), Docusaurus sites (ADR-0075), the Studios marketing site (handled by `site-sync`), the Architecture repo's own internal docs (handled by `hive-sync`), and XML-doc-comment generation (Invariant 13, enforced by `HoneyDrunk.Standards`, not by this agent).

## Decision

### D1 — Stand up `docs-sync` as a new Meta-sector agent

A new agent `.claude/agents/docs-sync.md` is authored in the Architecture repo following the [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md) source-of-truth convention.

**Role:** central, scheduled detector and reconciler of cross-repo documentation drift. Surfaces a per-run summary report in the Architecture repo and opens one PR per affected repo per run with the proposed doc fixes.

**Hosting:** Architecture repo (`HoneyDrunk.Architecture/.claude/agents/docs-sync.md`). Same hosting model as `hive-sync` and `site-sync`.

**Execution surface:** ADR-0086 runner scheduled job, with manual dispatch supported. ADR-0088 removed the OpenClaw schedule premise during decommissioning; the agent itself remains execution-surface-agnostic.

**Tools:** `Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`, `TodoWrite`. `Bash` includes `gh pr create` against the target repo (see D4 for the explicit grant and its bounds). No `gh issue create` (filing is `file-issues`'s job per ADR-0008).

### D2 — Scope of "documentation" this agent owns

The agent reads and reasons about, for every repo named in `catalogs/nodes.json` (and the Meta-surface repos: Actions, Architecture, Lore, Standards, CoreWorkspace), across two concerns: **existence** ("the doc is present and structurally valid") and **accuracy** ("the doc's factual claims match current Grid + repo state").

| Surface | Per Repo | Existence checks | Accuracy checks (v1 cut) |
|---------|----------|-----------------|--------------------------|
| Root `README.md` | 1 | Exists; non-empty; standard section headers per repo template | Version refs match package version; named contract types exist in `catalogs/contracts.json` AND in repo code; named consumed Nodes match `consumes` in `catalogs/relationships.json`; install snippet package name matches `*.csproj` `<PackageId>`; install snippet version matches `grid-health.json` |
| Per-package `README.md` | N | Exists (Invariant 12); non-empty | Same accuracy checks as root README, scoped to the package; `<PackageId>` and `<Version>` in `*.csproj` match the README's stated values |
| Root `CHANGELOG.md` | 1 | Exists; Keep a Changelog format per Invariant 12 | Latest entry version matches `grid-health.json`; date present and not in the future; entries reference real ADR numbers when cited |
| Per-package `CHANGELOG.md` | N | Exists when functional changes shipped (Invariant 12 + 27) | Same accuracy checks as root CHANGELOG; version matches package `<Version>` |
| `AGENTS.md` | 0 or 1 | Existence checked only where the repo has agent-specific guidance | Named agents exist in `.claude/agents/` of Architecture repo; named workflows/conventions are not Superseded |
| `CLAUDE.md` | 0 or 1 | Same as AGENTS.md | Same as AGENTS.md |
| `.github/copilot-instructions.md` | 0 or 1 | Same | Same |
| `docs/` content | optional | Intra-repo Markdown links resolve | Cross-references to ADR numbers resolve; referenced ADRs that are Superseded are flagged (not auto-changed) |

**What "accuracy" means in v1 (the tractable cut):**

The accuracy checks above are all **resolvable by symbol lookup or string comparison** — no compilation, no runtime, no LSP. The agent verifies that:

1. **Symbol references resolve.** Every type/interface/method named in prose can be found by name in the repo's code (`Grep` against `*.cs` / `*.ts` / etc.).
2. **Catalog references resolve.** Every contract, Node, package, or ADR name referenced in prose appears in the corresponding catalog file.
3. **Version numbers match.** Every version string in prose (READMEs, CHANGELOGs, install snippets) matches either `<Version>` in the relevant `*.csproj` or `grid-health.json`.
4. **Dependency claims match.** Every "this Node depends on X" claim in prose matches the `consumes` array for that Node in `catalogs/relationships.json`, both directions (claimed dependency must be in catalog; large undeclared catalog dependency in code is flagged, not silently added).
5. **Install snippets are syntactically valid.** `dotnet add package …` and `<PackageReference Include="…" Version="…" />` snippets in READMEs are checked for the package name resolving to a real `*.csproj` `<PackageId>` and the version resolving to either the current package version or "*"; **no actual `dotnet add` is executed**.

**What v1 explicitly does NOT do (deferred to a future ADR):**

- Compile or execute code examples. A C# fenced snippet in a README that references a real type is checked for symbol resolution only, not for syntactic correctness of the snippet itself.
- Run shell commands or HTTP examples. A `curl` example in a README is not invoked.
- Prose-quality / style / grammar / marketing copy. (Vale-class concern; orthogonal.)
- In-product OpenAPI rendering (ADR-0075 D1 → Scalar).
- Per-Node Docusaurus sites (ADR-0075 D2 → `@honeydrunk/docs-preset`; per-Node decision).
- Studios marketing site (`site-sync` agent; ADR-0075 D3).
- Architecture repo's internal tracking files (`hive-sync` per ADR-0014).
- XML doc comments on public APIs (Invariant 13, enforced via `HoneyDrunk.Standards` analyzers at build time).

This v1 accuracy cut is the **tractable but meaningful** line: every check listed above is mechanically resolvable in a single read pass against the workspace, with high signal (false positives are rare because the comparison is exact-string) and high coverage of the most common drift modes (renamed types, version bumps, removed dependencies, dead links). The deferred items are real but require execution surfaces (compiler, shell, HTTP) the agent does not need to own to deliver substantial value.

### D3 — Six detection categories (existence + accuracy interleaved)

On each run, the agent walks every in-scope repo and emits findings across these categories. Each finding carries a severity (`block` / `warn` / `note`), the file path, and a one-line summary.

1. **Missing required artifacts** (existence). A repo with `*.csproj` projects but no root `README.md` or `CHANGELOG.md` (Invariant 12 violation). A package directory inside a solution missing its `README.md` (Invariant 12 violation). Severity: `block`.

2. **Version drift** (accuracy). Latest entry in root `CHANGELOG.md` does not match `grid-health.json`'s `version` field for that Node, OR a `<Version>` in `*.csproj` does not match the README's stated version, OR an install snippet's version string does not match the package's actual version. The symmetric check to `hive-sync` Step 12 — `docs-sync` reconciles per-repo docs against the same source of truth `hive-sync` uses for catalog reconciliation. Severity: `warn` (because `grid-health.json` could itself be stale; surfaces both directions).

3. **Symbol-reference drift** (accuracy). Public types/interfaces/methods named in prose (README, package READMEs, `docs/`) that do not resolve to any symbol in the repo's code by name. This is the largest accuracy category and the most common drift mode after a rename. Severity: `warn`. Conversely, public types listed in `catalogs/contracts.json` for a Node that do not appear by name anywhere in the Node's root README — `note` (the README is not required to enumerate every type, but a contract listed in the central catalog should at least be mentioned).

4. **Catalog-reference drift** (accuracy + existence). Markdown link or prose reference to `HoneyDrunkStudios/{Repo}`, a Node name, an ADR number, or a contract name where the target doesn't resolve in the corresponding catalog or filesystem (file moved, package renamed, repo archived, ADR number unused). Cross-references to ADR numbers that are now `Superseded` — `note` only, not `warn`, because Superseded ADRs are still valid history. Severity for unresolved references: `warn`.

5. **Dependency-graph drift** (accuracy). A Node's README naming a consumed Node that is not in its `consumes` array in `catalogs/relationships.json`. Or a Node's `consumes` array containing a Node that the README is silent about. Severity: `warn` for missing-from-catalog; `note` for missing-from-README.

6. **Agent-instruction drift** (accuracy). `AGENTS.md` / `CLAUDE.md` / `.github/copilot-instructions.md` referencing an agent that no longer exists in `.claude/agents/` of the Architecture repo, naming a workflow / convention that an Accepted ADR has superseded, or naming a `.github/workflows/*.yml` reusable workflow that no longer exists in `HoneyDrunk.Actions`. Severity: `note`.

**Stale CHANGELOG entries** (the former category 3 in the previous draft) and **AI-authored-PR README skew** (the former category 8) are intentionally folded into category 2 (version drift) and the per-PR `review` agent respectively. The per-PR README check belongs at PR time per ADR-0044; replicating it as a scheduled retrospective is duplicative.

The categories are ordered so that **the most signal-dense and least-false-positive categories come first** (existence violations are deterministic; version drift is exact-string; symbol resolution has very low false-positive rate when the symbol catalog is the agent's source of truth). Higher false-positive risk (agent-instruction drift, where "named convention" may be paraphrased and miss a Grep) is last.

### D4 — Authority model: direct cross-repo PRs, with a per-run report in Architecture

`docs-sync` is authorized to **open one PR per affected repo per run, against the target repo's default branch**, containing the doc fixes for findings it can mechanically resolve. It also writes a per-run summary report into the Architecture repo for visibility.

**Two write surfaces:**

1. **In each affected target repo: one PR per repo per run.** Branch name: `chore/docs-sync-{YYYY-MM-DD}`. PR title: `chore(docs-sync): {YYYY-MM-DD} doc reconciliation`. Per-repo branch is reused across runs in a week if the prior week's PR is still open and unmerged — findings update the existing PR rather than opening a parallel one. (Aligns with the operator's "one PR per repo per initiative" rule; see below.)
2. **In the Architecture repo: `generated/docs-sync-reports/{YYYY-MM-DD}.md`** — the full run report, append-only by date. One file per run. Format: a section per Node listing all findings (whether or not auto-fixed), links to the per-repo PR opened (or skipped, with reason), and a Grid-wide summary. The report is committed via a small PR to Architecture (`chore/docs-sync-report-{YYYY-MM-DD}`) using the same authoring discipline as `hive-sync`'s reconciliation PR.

**What goes in the cross-repo PR vs. the report-only surface:**

| Finding type | Auto-fixed in cross-repo PR? | Always in report? |
|--------------|------------------------------|-------------------|
| Version drift (README says 1.2.0, `<Version>` says 1.3.0) | Yes — update README to match `<Version>` | Yes |
| Catalog-reference drift to a renamed Node (e.g., `HoneyDrunk.Old` → `HoneyDrunk.New`) | Yes — rewrite link/name using the canonical name from `catalogs/nodes.json` | Yes |
| Dead Markdown link to a moved/deleted file inside the repo | Yes when the target's new location is determinable; `note` in report otherwise | Yes |
| Symbol-reference drift (README names a removed type) | **No** — flagged in the PR description as a `// TODO: docs-sync flagged this prose for human review` block in the PR body; not auto-edited (the prose context is often nuanced) | Yes |
| Dependency-graph drift (README claims a dependency not in catalog) | **No** — surfaced in PR body as a question for the human | Yes |
| Agent-instruction drift (CLAUDE.md names a removed agent) | **No** — surfaced in PR body; replacement is editorial | Yes |
| Missing required artifact (no root README in a repo with `*.csproj`) | **Conditionally yes** — agent generates a skeleton README from `catalogs/nodes.json` Node manifest, marked `<!-- docs-sync generated skeleton; please review -->` | Yes |

The bias is: **mechanical, exact-string drift is auto-fixed in the PR**; **anything requiring editorial judgment is surfaced for human action** either via TODO blocks in the PR body or as a fallback `proposed/` packet in Architecture (see "fallback packet path" below).

**PR metadata (pr-core compliance):**

The PR body must satisfy `pr-core.yml` Job 7 (Authorship Check) and Job 8 (PR Metadata Check). The decision:

- **Authorship value: `agent-codex`.** The v1 scheduled job runs through the ADR-0086 runner's `codex` command, so the PR-body authorship token must match that execution surface. Expanding the `pr-core.yml` enum to add `agent-docs-sync` would be a coordinated change across HoneyDrunk.Actions and every consumer pr-core gate, which is disproportionate to the value. If a future host invokes the same agent through Claude Code, the job spec and prompt must be updated together.
- **Packet vs Out-of-band: `Out-of-band reason:`** pointing at the docs-sync run report path. Example: `Out-of-band reason: Generated by docs-sync run 2026-05-29; full report at HoneyDrunk.Architecture/generated/docs-sync-reports/2026-05-29.md`. Rationale: docs-sync is a **continuous reconciliation initiative**, not a per-finding packet — the same model `hive-sync`'s reconciliation PRs follow today. The report path in the OOB reason is the audit trail. The `out-of-band` label is auto-applied by the pr-core workflow per the existing OOB pattern.

A future ADR may revisit this and either (a) add `agent-docs-sync` as a first-class enum value, or (b) introduce a `Work Item:` link to a per-run governing packet in Architecture. Either is reversible; the v1 cost of using `agent-claude-code` + OOB-reason is one line per PR and is consistent with how `site-sync`-class agents will operate.

**One-PR-per-repo-per-initiative compliance:**

Operator convention: one PR per repo per initiative. `docs-sync` is its own continuous initiative — "Grid-wide documentation currency, weekly cadence." The natural unit is therefore **one PR per repo per weekly run**, batching that week's mechanical fixes for that repo into a single PR. If the prior week's docs-sync PR for a repo is still open and unmerged at the start of the next run, the agent commits new findings into the existing branch rather than opening a parallel PR. This honors the one-PR-per-repo-per-initiative rule and avoids the "PR hell" failure mode.

**Composition with `pr-core`:**

The cross-repo PR is subject to the target repo's full `pr-core` gate just like any other PR. If `pr-core` fails (most likely cause: a generated skeleton README trips a linter, or a doc edit breaks a Docusaurus sidebar reference), the failure is the human's signal — the agent does not retry on its own. The next weekly run re-evaluates: if the underlying issue still exists, the agent commits a corrective edit to the same branch (not a new PR). If three consecutive runs fail to land a fix for a given repo, the finding for that repo escalates to a `proposed/` packet in Architecture for human-driven triage (the "fallback packet path"). This bounded retry prevents the agent from getting stuck in a loop while preserving the operator's ability to intervene.

**Fallback packet path** (preserves the existing `proposed/` pipeline):

For findings the agent declines to auto-fix (symbol drift, editorial calls, agent-instruction drift) AND for findings where three consecutive PRs failed, the agent writes a `generated/work-items/proposed/{YYYY-MM-DD}-{repo}-docs-{slug}.md` packet in Architecture per the standard format from `copilot/issue-authoring-rules.md`. Frontmatter: `source: reactive`, `generator: docs-sync`. These packets follow the ADR-0043 D3 lifecycle — they are **not** self-promoted to `active/`; a human triages them in the weekly briefing per ADR-0043 D5. So the docs-sync surface composes with the proposed/ pipeline; it does not bypass it for editorial work.

**PAT scope and secret management:**

Cross-repo PR authority requires a token with `pull_requests: write` and `contents: write` on every Grid repo in `HoneyDrunkStudios`. Two options were considered and the recommendation is:

- **Recommended: GitHub App installation token** scoped to the `HoneyDrunkStudios` organization, with `Contents: read+write`, `Pull requests: read+write`, `Metadata: read` permissions. App-installation tokens auto-rotate (1-hour lifetime), do not consume PAT inventory, are auditable per-installation in the org audit log, and survive operator rotation. The app is named `docs-sync` and registered as a HoneyDrunk Studios GitHub App; its private key is stored in `kv-hd-docs-sync-prod` per ADR-0005 and rotated per ADR-0006 Tier 2 (since the token is short-lived, the key itself is the long-lived secret subject to standard SLAs).
- **Rejected: classic PAT on the operator account.** Blast radius is the operator's entire GitHub identity (all orgs, all scopes the PAT was granted). Even a fine-grained PAT scoped to the org has worse audit posture than a GitHub App (PAT actions show up as the operator's user; App actions show up as the App with installation-ID lineage). Per ADR-0006's rotation discipline, the App pattern is the correct one for any persistent automation that opens PRs at scale.

If the App registration is blocked (org admin friction, free-tier App limits), the v1 fallback is a fine-grained PAT on a dedicated `tatteddev-bot` machine user with read/write on `HoneyDrunkStudios` repos only. This is documented as a temporary measure with a follow-up packet to migrate to the App pattern.

**Why this composes with ADR-0043 D3 (no self-promotion):**

ADR-0043 D3 says agents do not self-promote `proposed/` → `active/` packets. That rule is about **the packet lifecycle inside the Architecture repo**: agents file packets in `proposed/`, humans triage them into `active/`. Opening a cross-repo PR is a **different surface entirely** — it is the equivalent of `site-sync` editing the website's JSON files directly or `hive-sync` updating `initiatives/active-initiatives.md` directly. Both of those agents already write directly to their target repo without going through the packet lifecycle, because the work is mechanical reconciliation of shared truth, not "promotion of agent-generated work." `docs-sync`'s mechanical doc fixes are the same shape: reconciliation, not promotion.

The relevant guardrails on cross-repo writes are not ADR-0043 D3 — they are (a) the PR gate (`pr-core` is the human-equivalent review checkpoint; the PR cannot merge until checks pass and a human approves per branch protection), and (b) the bounded auto-fix scope (only mechanical exact-string drift is auto-edited; everything else falls back to a `proposed/` packet, which DOES go through D3). So D3 is preserved exactly where it matters (editorial work) and bypassed only where the work is mechanical (the same exception ADR-0014 carved for `hive-sync` and ADR-0075 implies for `site-sync`).

The candidate Invariant in D9 below offers the option to formalize this distinction as a new numbered invariant ("mechanical cross-repo reconciliation by named central agents is permitted without packet routing; editorial work routes through `proposed/`").

### D5 — Interaction with existing agents

| Agent | Boundary with `docs-sync` |
|-------|--------------------------|
| `hive-sync` | Strictly disjoint write surfaces. `hive-sync` writes only to the Architecture repo; `docs-sync` writes to per-repo target repos and to one report file in Architecture. Both read `grid-health.json` and `catalogs/*.json`. The version-drift category (D3 #2) is symmetric to `hive-sync` Step 12: `hive-sync` reconciles `catalogs/compatibility.json`/`modules.json`/`services.json` against `grid-health.json`; `docs-sync` reconciles per-repo README/CHANGELOG prose against the same source. |
| `site-sync` | Adjacent and complementary. `site-sync` writes to the marketing website; `docs-sync` writes to per-repo docs. Same write-pattern shape ("central agent reconciles shared truth into target repo"); same Authorship/OOB-reason discipline applies to both. They do not interlock. |
| `node-audit` | Complementary. `node-audit` is deep, one-Node-at-a-time, on-demand, all-phases. `docs-sync` is shallow, all-Nodes, scheduled, docs-only. A `node-audit` Phase 6 finding ("README is stale") that `docs-sync` already surfaced is acceptable — the redundancy makes the doc surface visible from both the per-Node and per-Grid lens. The audit's per-Node deep findings remain the authoritative source for fixes; `docs-sync` is the early-warning radar and mechanical reconciler. |
| `scope` | Downstream of the fallback packet path. A human triaging a `docs-sync`-generated `proposed/` packet (the editorial-finding fallback) may invoke `scope` if the docs work overlaps with non-doc changes worth bundling. |
| `review` | Per-PR reviewer of every docs-sync PR. ADR-0044 D7 PR-size discipline applies: docs-sync PRs are expected to be well under 400 lines in normal weeks. If a docs-sync PR exceeds 400 lines (e.g., first-run cleanup against a repo that has never been audited), the `Size justification:` block in the PR body cites the catch-up nature explicitly. ADR-0044 D8 multi-perspective review is not triggered by docs PRs (docs paths do not touch high-risk Nodes' executable surface). |
| `netrunner` | Reader. Weekly briefing per ADR-0043 D5 includes (a) the per-run docs-sync report summary, (b) any docs-sync-generated `proposed/` packets (editorial fallback), and (c) any docs-sync PRs that have been open and unmerged for more than 14 days (the stale-PR surface). |
| `file-issues` | Unrelated. docs-sync does not file GitHub Issues; its output is cross-repo PRs and (for editorial findings) `proposed/` packets that go through the standard `file-issues` path only if a human promotes them. |

The agent capability matrix at `constitution/agent-capability-matrix.md` is updated in the same PR that lands the agent definition. The Execution Rules section is updated to add `docs-sync` to the named list of agents authorized for cross-repo PR creation (currently: `file-issues` for issues; `hive-sync` for Architecture-repo PRs; adding `docs-sync` for per-target-repo PRs with the scope bounds in D4).

### D6 — Cadence and execution surface

**v1 cadence: weekly, Friday.** Confirmed. Avoids the Monday/Thursday `hive-sync` slot, lands fixes before the weekend gap, and gives the report time to surface in `netrunner`'s Monday briefing. A full Grid sweep across 25 repos takes minutes (Markdown grep + catalog cross-reference + symbol resolution); weekly is cheap.

**Full sweep, not event-driven.** Confirmed. Every run walks every in-scope repo from scratch. No incremental "only re-check repos touched since last run" optimization at v1 — the cost is low enough that the simpler model wins. A future ADR may add event-driven supplemental runs (e.g., on ADR acceptance, immediately check all repos the ADR names) if the weekly cadence proves too slow for specific signals; this is a strict superset of the v1 weekly-full-sweep model and does not invalidate it.

**Execution surface: ADR-0086 runner scheduled job, with manual dispatch.** ADR-0088 removed the OpenClaw schedule and tunnel path before this ADR reached acceptance. The Friday cadence is now implemented by `infrastructure/workers/grid-agent-runner/config/jobs/docs-sync.psd1`, and the manual cadence remains the floor if the scheduled task is paused.

**No GitHub Actions cron alternative is committed in this ADR.** A future ADR may reverse this if local-runner availability becomes a constraint; the agent itself is execution-surface-agnostic (it reads files, writes files, and calls `gh`), so the reversal cost is bounded.

### D7 — Deduplication and noise control

The single most important quality control. The agent is at risk of either (a) re-fixing the same drift every week if upstream isn't fixed, or (b) re-opening the same PR every week even if the previous one is open or merged.

Rules:

- **Per-run report (`generated/docs-sync-reports/{YYYY-MM-DD}.md`) is append-only by date.** Each run is its own file. History is preserved.
- **Per-repo cross-repo PR uses a stable branch name `chore/docs-sync-{YYYY-MM-DD}`.** If a PR with that branch already exists and is open at the start of the next run, the agent **reuses the branch** and pushes additional commits rather than opening a parallel PR. If the prior week's PR was merged or closed, the new run opens a fresh PR with the new date in the branch name.
- **Auto-fix idempotency.** Every auto-fix the agent applies must be idempotent — running the same fix twice produces no diff. Version-drift fixes, name rewrites, and dead-link rewrites all satisfy this trivially; skeleton-README generation is gated on the file not existing, so it cannot re-fire on a repo whose README the human has since created.
- **Editorial-finding packet dedup.** Before writing a new `proposed/` packet for a Node (the fallback path), the agent checks for an existing un-triaged packet with `generator: docs-sync` covering the same Node and the same finding category. If found, the existing packet is left alone (Invariant 24 protects packets from agent edits post-creation) and a one-line note is added to the run report: "Skipped — existing `proposed/` packet `{path}` still pending triage."
- **Sticky findings carry a "first surfaced" date** in the run report, computed the same way `hive-sync` does for `drift-report.md`. Findings older than 60 days are flagged in a `Stale Findings` section so the operator sees what's been ignored.
- **`block`-severity findings have no dedup grace period.** A `block` finding (e.g., a missing required README) generates a packet AND a fresh PR commit every run until the underlying issue is fixed, even if a `proposed/` packet exists. This is deliberate: missing required docs are an Invariant 12 violation and the per-week reminder is the floor.
- **PR-failure backoff.** If three consecutive weekly runs against the same repo open or update a PR that fails `pr-core` and is not merged or closed by the human within the week, the agent stops auto-pushing to that repo's PR and converts all that repo's findings to `proposed/` packets for human triage. The operator is alerted in the run report. This prevents zombie-PR loops.

### D8 — Phased rollout

Re-sequenced from the prior draft to land accuracy-class checks earlier (since accuracy is now in v1 scope) and to land cross-repo PR authority in a discrete phase the operator can validate before broadening it.

Each phase is independently shippable and the agent does not gain new authority until the prior phase is observed working.

**Phase 1 — Agent definition, matrix wiring, report-only mode.**
- Author `.claude/agents/docs-sync.md`.
- Add capability matrix row.
- Create `generated/docs-sync-reports/` directory with a seed README.
- Register the `docs-sync` GitHub App and store its private key in `kv-hd-docs-sync-prod`.
- Wire ADR-0086 runner scheduled trigger (Friday slot).
- The agent runs and produces a full report covering categories 1, 2, 3, 4 (existence + version drift + symbol drift + catalog reference drift) for every in-scope repo. **No cross-repo PRs yet.** The Architecture-repo report PR is the only write.
- Verifies: the ADR-0086 runner can invoke the agent, the App token mints correctly, the report format is useful, the false-positive rate on accuracy checks is acceptable.

**Phase 2 — Cross-repo PR authority enabled for mechanical fixes.**
- Agent gains `gh pr create` against target repos.
- Auto-fix scope at this phase: version drift (#2) only — the highest-signal, lowest-judgment category. Every other finding remains report-only.
- One PR per affected repo per run, with the `Authorship: agent-codex` + OOB-reason metadata for the v1 runner job.
- Validates: PR-metadata gates pass, branch-naming convention works, idempotency holds, operator's PR-review workload is acceptable.

**Phase 3 — Broaden auto-fix to catalog references and dead links.**
- Auto-fix scope expands to category 4 (catalog-reference drift: rename-aware link rewrites) and dead intra-repo Markdown links where the target's new location is determinable from `catalogs/nodes.json`.
- Categories 3 (symbol drift), 5 (dependency-graph drift), and 6 (agent-instruction drift) remain report-only + fallback `proposed/` packet path.

**Phase 4 — Add dependency-graph and agent-instruction drift detection.**
- Categories 5 and 6 begin emitting findings (still report-only + fallback packets).
- Higher false-positive risk because prose phrasing is variable; the report is the validation surface before any auto-fix authority is considered.

**Phase 5 — Skeleton README generation for missing-required-artifact `block` findings.**
- Auto-generate skeleton README from `catalogs/nodes.json` Node manifest when a repo with `*.csproj` projects has no root README, marked as a docs-sync skeleton requiring human review.
- This is the highest-judgment auto-fix category; lands last so the operator has trust calibration from Phases 2-3.

**Phase 6 — Cadence / automation finalization and invariant decision.**
- Confirm Friday cadence and ADR-0086 runner integration. If 90-day observation shows weekly is too aggressive or too lax, adjust here.
- Decide D9 invariant candidates.
- Decide whether to add `agent-docs-sync` as a first-class `pr-core.yml` Authorship enum value (revisits the D4 metadata decision in light of observed PR volume and operator preference).

Each phase is its own packet. The same `accepts: ["ADR-0085"]` chain applies; on full acceptance, `hive-sync` per ADR-0014 D7 will auto-flip this ADR to Accepted.

### D9 — Possible new invariants

Three invariants are candidates, none committed in this ADR. The Proposed status is deliberate: the operator should decide whether each constraint is worth the rigidity before it becomes Grid law. The decision lives in the Phase 6 acceptance packet.

**Candidate A: "Every Node has a non-empty root `README.md` and `CHANGELOG.md`, validated weekly."**
Already implied by Invariant 12; this would name `docs-sync` as the weekly validator. If accepted, the prose of Invariant 12 is amended to name `docs-sync`. No new numbered invariant.

**Candidate B: "`docs-sync`'s cross-repo write authority is bounded to: (a) one PR per repo per weekly run, (b) auto-edits limited to the file categories in D2, (c) auto-fix categories limited to the per-phase D8 scope active at the time."**
Locks in the architectural decision against drift. Worth adding as a numbered invariant only if the operator wants the rigidity. Symmetric to ADR-0014 D4's `hive-sync` constraint.

**Candidate C: "Mechanical cross-repo reconciliation by named central agents (`hive-sync`, `site-sync`, `docs-sync`) is permitted without packet routing; editorial cross-repo work routes through `generated/work-items/proposed/`."**
Formalizes the distinction made in D4 between mechanical and editorial work. Makes ADR-0043 D3's no-self-promotion rule explicitly scoped to packet promotion, not all cross-repo writes. Most rigorous of the three; also the most useful for future agent decisions where the same pattern recurs (any "central reconciler" agent the Grid grows will benefit from this distinction being explicit).

## Consequences

### Affected Nodes

- **HoneyDrunk.Architecture** (this repo) — primary affected. New agent file, new `generated/docs-sync-reports/` directory, capability matrix row, ADR. Same surface area as the `hive-sync` introduction in ADR-0014, plus the per-run report-PR cadence.
- **Every code Node listed in `catalogs/nodes.json`** — each becomes a read target and a potential PR target. The cross-repo PR cadence introduces a new ongoing weekly PR surface in each repo (expected steady-state: 0-1 docs-sync PRs per repo per week; not every repo has drift every week).
- **HoneyDrunk.Actions** — no change at v1. A future amendment may add `agent-docs-sync` to the `pr-core.yml` Authorship enum (deferred to Phase 6 per D8).
- **HoneyDrunk.Standards** — no change. XML doc comment enforcement remains Standards' job per Invariant 13.
- **HoneyDrunk.Vault** — new secret `kv-hd-docs-sync-prod` holding the docs-sync GitHub App private key. Standard ADR-0005/ADR-0006 lifecycle applies.

### Cascade Impact (per `catalogs/relationships.json`)

No code-level dependency edges added. The agent reads catalogs but introduces no new `consumes` / `consumed_by` entries.

The closest existing pattern is `site-sync`'s direct edits to the marketing website repo. `docs-sync` extends that "central agent writes directly to target repo via PR" model from one adjacent repo to N=25 target repos, with the bounded scope (mechanical fixes only) and the per-phase rollout (D8) as the controls.

### Operational Consequences

- **The weekly briefing surface grows.** Per ADR-0043 D5, new `proposed/` packets and (now) docs-sync PR summaries are listed in the weekly briefing. Expected steady-state: 0-3 editorial-fallback packets per week, 2-8 cross-repo PRs per week Grid-wide. Below the noise threshold of a solo + agents shop; well within the 30-minute weekly triage budget.
- **A new recurring PR-review workload.** The operator now reviews docs-sync PRs as a weekly task. Each PR is typically small (version-string rewrites, link updates) and review-by-glance is sufficient. The PR-size cap from ADR-0044 D7 applies; first-run cleanups may exceed 400 lines and require explicit size justification (which the agent provides automatically in the PR body).
- **`generated/docs-sync-reports/` accumulates.** One file per week, ~25 sections each. After a year: ~50 files. Comparable in size to the existing `generated/incidents/`, `generated/audits/`, `generated/scout-reports/` directories. No pruning policy required at v1; revisit after 6 months.
- **The `block`-severity dedup-grace exception means a missing-README finding repeats every Friday until fixed.** Intentional. The operator can silence it only by fixing the underlying violation.
- **New Grid-wide cost: the docs-sync GitHub App** runs against the org with read+write on Contents and Pull Requests. App-installation token lifetime is 1 hour, auto-rotated. Standard ADR-0006 Tier 2 lifecycle for the private key.
- **Per-run model cost is negligible** at v1: filesystem-local reads, no model API calls per detection. The agent prompt itself is the only model cost, comparable to a single `node-audit` run.

### Process Consequences

- **Doc cleanup becomes mostly automated.** Mechanical version drift, renamed-Node link rewrites, and dead intra-repo links are auto-corrected within a week. Editorial drift (symbol references, dependency claims, agent instructions) remains a weekly triage item but with full visibility instead of zero.
- **`node-audit` Phase 6 ("Job Performance" → README accuracy) becomes redundant for already-detected items.** When `node-audit` is invoked on a Node, the operator may already see open docs-sync PRs for that Node's README. Acceptable — the agents have different lenses, and `node-audit` remains authoritative on the deeper Phase 1-7 categories `docs-sync` does not cover.
- **The first-impression for external Notify Cloud integrators improves.** The first 3 months of operation will likely catch and auto-correct 30-60 mechanical doc inconsistencies, plus surface ~15 editorial issues for human action. Notify Cloud's docs surface specifically benefits before GA.
- **A new failure mode: docs-sync PR introduces a regression.** A mechanical auto-fix could in principle introduce a docs error (e.g., updating a version reference to a value that's correct in `grid-health.json` but contradicts an explicit upgrade-notes section). Mitigation: every PR is human-reviewed before merge; the agent's bias is "fix what's mechanically resolvable, surface everything else." Risk is bounded by the PR-review gate.
- **Another new failure mode:** docs-sync produces a `block` finding that's actually a `grid-health.json` staleness issue, not a docs issue. Operator triages and resolves by reconciling the catalog rather than the docs. Acceptable; both directions are valuable.

### Invariants

None added by this ADR. Three candidates flagged in D9 for Phase 6 decision.

If candidates A, B, and C are accepted in Phase 6:
- Invariant 12 amended to name `docs-sync` as the weekly validator (Candidate A).
- A new numbered invariant for the `docs-sync` cross-repo write bounds (Candidate B).
- A new numbered invariant formalizing mechanical-vs-editorial cross-repo write authority (Candidate C).

### Follow-up Work

- Author `.claude/agents/docs-sync.md` (Phase 1 packet).
- Update `constitution/agent-capability-matrix.md` and `Execution Rules` for the cross-repo PR authority grant (Phase 1 packet, same PR).
- Create `generated/docs-sync-reports/` with seed README.
- Register the `docs-sync` GitHub App, store its private key in `kv-hd-docs-sync-prod`, document the rotation runbook (Phase 1 packet).
- Phase 2-5 packets per D8.
- Phase 6 acceptance packet covering cadence finalization, invariant decisions (D9), and whether to add `agent-docs-sync` to the `pr-core.yml` Authorship enum.
- After 90 days of operation: retrospective check against the assumed steady-state (2-8 PRs per week, 0-3 fallback packets per week) and noise/value calibration. Revisit Phase 4 thresholds if they prove over-sensitive.
- Future ADR for code-example correctness (compilation/sample-validation against fenced code blocks) — explicitly deferred per D2 scope carve-out.

## Alternatives Considered

### Extend `hive-sync`'s mandate to cover cross-repo docs

Rejected. ADR-0014 D4 explicitly bounds `hive-sync` to Architecture-repo writes; the constraint is load-bearing. Documentation currency is a substrate-shaped concern that deserves its own owner. `docs-sync` is the right factoring — same logic ADR-0014 used to broaden `initiatives-sync` into `hive-sync` argues here for a focused second agent rather than further broadening `hive-sync`. Settled.

### Fold `docs-sync` into `node-audit`

Rejected. `node-audit` is deep, on-demand, one-Node-at-a-time — its value is the all-phases lens on a single Node when a human points at it. `docs-sync` is shallow, scheduled, Grid-wide — its value is the cross-cutting "did anyone notice that contract X was renamed?" pass. Conflating them either dilutes `node-audit`'s depth or compromises `docs-sync`'s breadth. The two are complementary; redundancy on README-accuracy findings is acceptable because the two lenses have different cadences and triggers. Settled.

### Report-only mode for v1 (no cross-repo PR authority)

Rejected. The earlier draft of this ADR proposed exactly this — surface findings as `proposed/` packets, never touch target repos. Two problems with that model: (a) the editorial-vs-mechanical distinction is real, and routing every mechanical version-string fix through a human-triaged packet is friction without value; (b) the operator preference is for direct PRs (as `site-sync` already does for the website). The right factoring is: mechanical fixes get a PR, editorial fixes get a packet. D4 reflects this.

The reasoning that previously rejected cross-repo writes — PAT blast radius, pr-core gate compliance, ADR-0043 D3 — has been addressed: PAT replaced by GitHub App (smaller blast radius, auditable), pr-core compliance handled via `agent-claude-code` + OOB-reason, ADR-0043 D3 explicitly scoped to packet promotion rather than all cross-repo writes (Candidate C invariant formalizes this).

### Use a third-party docs-as-code linter (Vale, markdownlint, etc.) instead of a Grid-aware agent

Rejected for the Grid-specific categories. The Grid-aware categories (catalog cross-reference, ADR-Status cross-reference, agent-existence cross-reference, contract surface, dependency graph, symbol resolution against repo code) are not what generic Markdown linters check. A generic linter would catch a fraction of the value; the Grid-aware agent catches all of it. Adding markdownlint at per-repo CI for prose-quality concerns is a credible orthogonal addition not committed here.

### Decide the execution surface (local runner vs GitHub Actions cron) in this ADR

Rejected per D6 deferral pattern, with a 90-day observation window written in (Phase 6 cadence finalization). The deferral is bounded. If local-runner availability proves to be the constraint, the agent runs manually for the bounded period and the cadence decision in Phase 6 chooses GitHub Actions cron.

### Run `docs-sync` daily instead of weekly

Rejected. Per ADR-0043 D9's analysis: daily cadences become interruption noise for a solo + agents shop; weekly is where signal exceeds noise. The dedup rule in D7 specifically prevents the same finding from re-firing every run, so the cadence is about how often the report is regenerated, not how often the operator sees it. Settled.

### Event-driven on ADR acceptance instead of weekly full sweep

Rejected at v1. Considered as a supplemental signal: when an ADR is accepted, immediately re-check the repos the ADR names. The weekly full sweep covers this case within at most 7 days; the marginal benefit of immediate event-driven runs does not justify the implementation complexity at v1. A future ADR may add event-driven supplemental runs as a strict superset of the weekly model. Settled.

### Scope `docs-sync` to only Notify Cloud and Live Nodes

Rejected. Seed Nodes become Live Nodes; building doc discipline before consumers exist is cheaper than retrofitting after. The agent's full Grid scope is also low cost (read-only filesystem walk + bounded PR cadence) so the asymmetry is in favor of broad coverage.

### Expand `pr-core.yml` Authorship enum to add `agent-docs-sync`

Considered for v1; deferred to Phase 6. Adding a new enum value requires a coordinated change across `HoneyDrunk.Actions/.github/workflows/pr-core.yml` and every consumer pr-core gate plus the post-merge audit workflow. Using `agent-codex` (which is accurate for the v1 ADR-0086 runner job) with `Out-of-band reason:` pointing at the per-run report path is operationally equivalent for v1 and avoids coupling this ADR's acceptance to a HoneyDrunk.Actions change. Phase 6 revisits in light of observed PR volume.

### Authorize `docs-sync` to merge its own PRs after pr-core passes

Rejected. The PR-review gate is the human checkpoint on the agent's mechanical edits. Even purely mechanical fixes can introduce regressions in nuanced cases (e.g., a version reference in a deprecation notice that intentionally cites an old version). Human review on merge is cheap (PRs are small, edits are scoped) and the safety value is substantial. The agent opens PRs and updates them; humans merge them.

## Remaining Open Questions

The three questions outstanding in the prior draft (separate agent vs. fold-in, accuracy scope, authority model) have been resolved (D1, D2, D4 respectively). Cadence (D6) is settled at weekly full sweep.

Remaining items, each Phase-6-or-earlier and none blocking acceptance of this ADR:

1. **GitHub App registration logistics.** The recommended PAT-replacement path (D4) assumes the operator can register a `docs-sync` GitHub App in the `HoneyDrunkStudios` org. If org-level constraints make App registration impractical, the fine-grained PAT fallback is documented as the v1 path. Decision deferrable to the Phase 1 packet.
2. **Authorship enum decision** (`agent-docs-sync` vs. continuing `agent-claude-code`). Deferred to Phase 6 per the Alternatives Considered entry above. Either choice is reversible.
3. **D9 invariant adoption.** Three candidates (A, B, C). Decided in Phase 6 acceptance packet, not this ADR.

The ADR is ready for acceptance review subject to the above three items being acknowledged as deferrable, not blocking.

## References

- [`constitution/charter.md`](../constitution/charter.md) — workshop framing; the doc surface is one of the "things lived in"
- [`constitution/invariants.md`](../constitution/invariants.md) Invariants 11, 12, 13, 27
- [ADR-0005](./ADR-0005-secret-management.md) — Key Vault naming + storage convention for `kv-hd-docs-sync-prod`
- [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md) — rotation lifecycle for the docs-sync App private key
- [ADR-0007](./ADR-0007-claude-agents-as-source-of-truth.md) — `.claude/agents/` source-of-truth convention
- [ADR-0008](./ADR-0008-work-tracking-and-execution-flow.md) — packet → issue → board → PR lifecycle (preserved for editorial-fallback path)
- [ADR-0014](./ADR-0014-hive-architecture-reconciliation-agent.md) — `hive-sync` precedent; D4 bounded-surface pattern; ADR auto-acceptance mechanism
- [ADR-0043](./ADR-0043-continuous-backlog-generation-strategy.md) — `proposed/` → `active/` lifecycle (the no-self-promotion rule scoped to packet promotion); weekly briefing surface; execution-surface deferral pattern
- [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — D6 Authorship enum (`agent-claude-code` used for docs-sync PRs); D7 PR-size discipline; D8 multi-perspective review boundary
- [ADR-0046](./ADR-0046-specialist-review-agents.md) — specialist-agent layering pattern
- [ADR-0075](./ADR-0075-documentation-tooling.md) — Scalar / Docusaurus tooling; `docs-sync` is content-side, not tooling-side
- [ADR-0086](./ADR-0086-pull-based-local-worker-grid-review-runner.md) — local runner execution surface
- [ADR-0088](./ADR-0088-decommission-openclaw-from-the-grid.md) — OpenClaw decommission and docs-sync runner-job cutover
- `.claude/agents/hive-sync.md` — closest agent pattern for the report-PR surface
- `.claude/agents/site-sync.md` — direct cross-repo write precedent for D4
- `.claude/agents/node-audit.md` — complementary read-only agent; Phase 6 README accuracy overlaps
- `constitution/agent-capability-matrix.md` — to be updated in Phase 1 packet (add `docs-sync` row, expand `Execution Rules` cross-repo PR list)
