# Dispatch Plan — ADR-0064: Prompt and Persona Registry with Versioning

**Initiative:** `adr-0064-prompt-registry`
**ADR:** ADR-0064 (Proposed → Accepted via packet 00)
**Sector:** AI / cross-cutting
**Created:** 2026-05-25

> Per ADR-0008 D7, this dispatch plan is the one exception to packet immutability — it is a living narrative updated at wave boundaries as a historical record.

## Summary

ADR-0064 commits the prompt-and-persona registry **policy** — what gets stored (D1: dedicated public repo `HoneyDrunk.Prompts`, files on disk, NuGet distribution), the persona-vs-prompt distinction (D2), the package-level semver + per-file content-hash versioning (D3), snapshot-at-deploy runtime resolution with no hot-reload (D4), the tuple-only LLM-call audit emit (D5), Evals integration via hash equality key (D6), the Honeyclaw posture with Grid-as-source-of-truth via build-step export (D7), the PDR-app pattern (D8), the on-disk YAML-frontmatter + double-brace-Mustache placeholder schema (D9), the PII-via-parameters / no-Restricted-content rule (D10), the `IPromptResolver` loader contract in `HoneyDrunk.Prompts.Abstractions` (D11), and the paired-standup-ADR pattern (D12).

The **Node shape** (repo creation, solution layout, CI pipeline, scaffolding, catalog rows, `repos/HoneyDrunk.Prompts/` folder) is intentionally deferred to a paired `HoneyDrunk.Prompts` standup ADR per D12, following the ADR-0058 / ADR-0059 precedent. This initiative does not create the Node — it lands the policy, the invariants, the AI-sector taxonomy / architecture-doc update, the Audit emit shape documentation, the agent checklists, and the standup-ADR handoff spec.

This initiative delivers, in **6 packets across 2 waves**, targeting **2 repos** (`HoneyDrunk.Architecture`, `HoneyDrunk.Audit`):

1. ADR acceptance + reservation row verification + initiative registration + two Required Decisions surfaced for human resolution (Architecture).
2. Four prompt-registry invariants `{N1}–{N4}` land in `constitution/invariants.md`; the invariant 44 conflict is resolved in the same commit per Required Decision 1 (Architecture).
3. The AI sector table gains a Prompts row; the AI sector architecture document gains a prompt-registry layer subsection (Architecture).
4. The Audit Node's docs gain an `LLM-Call Audit Catalog` documenting the canonical `LlmCall` event-name, the category-selection rule (existing `AgentAction` / `Integration` categories — no new `AuditCategory` value), and the tuple-only metadata-key shape (Audit).
5. `scope.md` + `review.md` gain four new prompt-registry checklist items in a single PR per invariant 33 (Architecture).
6. A standup-ADR handoff specification is authored as the input the future adr-composer reads when it drafts the paired `HoneyDrunk.Prompts` standup ADR (Architecture).

**6 packets, all `Actor=Agent`, 0 `Actor=Human`.** Two human prerequisites surface in the initiative — both are decision-only (Required Decisions 1 and 2 in packet 00); neither requires portal clicks, deploy actions, or out-of-PR human work *during* the agent's filing window.

## Trigger

ADR-0064 is Proposed. The forcing functions from the ADR's Context: every AI-sector standup ADR (ADR-0016, ADR-0018, ADR-0020, ADR-0021, ADR-0022, ADR-0023) currently has its consumers inlining prompts in feature work because there is no Grid-level registry; the AI-sector standup wave is in flight (ADR-0020, ADR-0021, ADR-0022, ADR-0023 all Proposed); every one of those Nodes' first feature packets will either inline prompts or pull on a registry. Inlining compounds — every Node that inlines now has to migrate later, every Audit emit recorded without a prompt-version field has to be backfilled, every Evals regression discovered after the fact is investigated against drifted text. The cost of doing this later climbs week over week.

ADR-0064 is also the forcing function for Honeyclaw's persona to stop drifting between OpenClaw config and the user's notes (memory `project_honeyclaw_bot`), and for the Lore wiki-ingest skill to source its ingest prompt from a versioned, audit-anchored, hash-equality-keyed registry rather than a code-embedded literal.

## Scope Detection

**Multi-repo (Architecture + Audit), policy-only.** ADR-0064 is a policy ADR; the Node shape lands with the paired standup ADR (D12). This initiative's packets touch only governance documents in `HoneyDrunk.Architecture` and a single docs-only update in `HoneyDrunk.Audit` (the `LLM-Call Audit Catalog`). No code packets; no `HoneyDrunk.AI` / `HoneyDrunk.Agents` / `HoneyDrunk.Operator` / etc. edits.

**No catalog row added in this initiative.** The `honeydrunk-prompts` row in `catalogs/nodes.json` / `relationships.json` / `modules.json` / `contracts.json` / `grid-health.json` lands with the paired standup ADR's catalog packet. This initiative only adds the **sector-taxonomy row** (`constitution/sectors.md` — a sector-level artifact, not a Node catalog) and the **architecture-doc subsection** (`constitution/ai-sector-architecture.md` — a sector-architecture artifact, not a Node catalog). The Cache Node followed the same pattern: ADR-0058 added the row to `sectors.md`; ADR-0059's catalog packet added the catalog rows.

**Four invariants land.** N1 (audit emit tuple), N2 (no PII in files), N3 (no inlined prompt bodies), N4 (canaries). Numbers reserved at `{N1}–{N4}` (currently `74–77` per the reservations file at packet authoring time; resolved against the file at execution time in case of merge races).

**Invariant 44 conflict.** N3 introduces `HoneyDrunk.Prompts.Abstractions` as a new downstream AI-sector dependency. Invariant 44's current text reads as restricting AI-sector runtime dependencies to `HoneyDrunk.AI.Abstractions` only. This is a Required Decision in packet 00 (A — amend by exception; B — restate narrowly, recommended; C — carve out by addition). Packet 01 applies the chosen resolution in the same commit as the four new invariants.

**No new `AuditCategory` enum value.** The refine-pass clarification is load-bearing: the LLM-call audit emit rides existing `AgentAction` (agent-originated calls) and `Integration` (non-agent-originated calls) categories with prompt-tuple metadata as the per-call discriminator. Do NOT invent an `Inference` category.

**Audit payload is tuple-only.** Never the rendered prompt body, never the completion text, never the substituted parameter values. This is stated in invariant N1, in packet 03's audit catalog, and in packet 04's agent checklists. The reason: substituted parameters may carry `Restricted`-tier content per ADR-0049 / N2; the audit substrate's append-only-by-interface stance does not enable redaction-after-the-fact; the right discipline is never let the bodies / completions / substituted values into the payload.

**Paired standup ADR is filed separately.** Required Decision 2 in packet 00: Posture A — file the standup ADR via adr-composer now, in this initiative's filing window; Posture B (recommended) — defer until after this initiative completes. Either is acceptable; the packets here are identical under both postures. Packet 05 authors the spec the adr-composer reads regardless.

## Required Decisions Carried by Packet 00

Both decisions are documented in packet 00's body and surface in the PR description for human resolution before packets 01 and 05 unblock.

### Required Decision 1 — invariant 44 conflict (N3 introduces `HoneyDrunk.Prompts.Abstractions`)

Three resolutions; recommendation: **Resolution B** (restate invariant 44 narrowly so the original "no AI-provider lock-in" intent is preserved without amendment-by-exception). Resolutions A and C are acceptable if the user picks them.

### Required Decision 2 — paired `HoneyDrunk.Prompts` standup ADR filing posture

Two postures; recommendation: **Posture B** (defer standup ADR drafting until after this initiative completes). Posture A is acceptable if the user wants the standup ADR filed in this initiative's filing window.

## Wave Diagram

### Wave 1 (No Dependencies — governance + invariants + sector taxonomy)
- [ ] **00** — Architecture: Accept ADR-0064 + verify `{N1}–{N4}` reservation row + register initiative + surface Required Decisions 1 and 2. `Actor=Agent`.
- [ ] **01** — Architecture: Land four prompt-registry invariants `{N1}–{N4}` in `constitution/invariants.md` + apply the chosen resolution of Required Decision 1 (invariant 44 amendment) + move ADR-0064 reservation row to history. `Actor=Agent`. Blocked by: 00.
- [ ] **02** — Architecture: Add the Prompts row to `constitution/sectors.md` AI sector table + add the prompt-registry layer subsection to `constitution/ai-sector-architecture.md`. `Actor=Agent`. Blocked by: 00.

### Wave 2 (Depends on Wave 1 — Audit catalog + agent checklists + standup handoff)
- [ ] **03** — Audit: Document the canonical `LlmCall` audit event-shape + the category-selection rule (existing `AgentAction` / `Integration`, no new `AuditCategory` value) + the tuple-only metadata-key shape in `HoneyDrunk.Audit`'s docs. `Actor=Agent`. Blocked by: 00, 01.
- [ ] **04** — Architecture: Update `.claude/agents/scope.md` + `.claude/agents/review.md` in the same PR with four prompt-registry checklist items per invariant 33. `Actor=Agent`. Blocked by: 00, 01.
- [ ] **05** — Architecture: Author the standup ADR handoff specification at `infrastructure/walkthroughs/honeydrunk-prompts-standup-spec.md` (the future adr-composer reads it). `Actor=Agent`. Blocked by: 00.

Packets within Wave 1 run sequentially (00 → 01 + 02). Packets 01 and 02 are both blocked by 00 only and could run in parallel; the natural ordering is 01 first (invariants are referenced by 02's prompt-registry-layer subsection) but 02 does not strictly require 01 because the subsection text is independent of the specific invariant numbers — both can execute in parallel without conflict. Within Wave 2, all three packets run in parallel (no shared file conflicts — packet 03 targets the Audit repo; packets 04 and 05 target Architecture but touch different files).

## Packet Links

| # | Packet | Repo | Actor | Wave | Blocked by |
|---|--------|------|-------|------|-----------|
| 00 | [Accept ADR-0064 — initiative + reservation + Required Decisions](./00-architecture-prompt-registry-initiative-and-sector.md) | Architecture | Agent | 1 | — |
| 01 | [Land four prompt-registry invariants + amend invariant 44](./01-architecture-prompt-registry-invariants.md) | Architecture | Agent | 1 | 00 |
| 02 | [AI sector table + ai-sector-architecture.md prompt-registry layer](./02-architecture-ai-sector-prompt-registry-layer.md) | Architecture | Agent | 1 | 00 |
| 03 | [Document `LlmCall` audit event-shape — tuple-only, no new AuditCategory](./03-audit-llm-call-prompt-tuple-emit.md) | Audit | Agent | 2 | 00, 01 |
| 04 | [scope.md + review.md prompt-registry checklist](./04-architecture-scope-review-prompt-registry-checklist.md) | Architecture | Agent | 2 | 00, 01 |
| 05 | [HoneyDrunk.Prompts standup ADR handoff specification](./05-architecture-prompts-standup-adr-handoff-spec.md) | Architecture | Agent | 2 | 00 |

## Version Bumps

- **`HoneyDrunk.Architecture`** — not a versioned .NET solution; governance/catalog/doc edits across packets 00, 01, 02, 04, 05.
- **`HoneyDrunk.Audit`** — packet 03 is docs-only. PATCH-bump optional per repo convention (e.g., `0.1.0` → `0.1.1`). If PATCH is chosen, every non-test `.csproj` in the solution moves to the same new version in a single commit per invariant 27. `[Unreleased]` is forbidden per the user's standing convention.

No `HoneyDrunk.Prompts` version-bump in this initiative — the Node does not exist yet. The first version (`0.1.0`) lands with the standup ADR's scaffold packet.

## Cross-Cutting Concerns

### Required Decision 1 — invariant 44 conflict

N3 (no inlined prompt bodies; AI-sector Nodes consume `IPromptResolver` from `HoneyDrunk.Prompts.Abstractions`) introduces a new downstream AI-sector runtime dependency. Invariant 44 in its current text restricts downstream AI-sector dependencies to `HoneyDrunk.AI.Abstractions` only.

Three resolutions:
- **A** — amend invariant 44 to permit prompt-registry coupling (add an explicit exception).
- **B (recommended)** — restate invariant 44 narrowly: change "only `HoneyDrunk.AI.Abstractions`" to "on `HoneyDrunk.AI.Abstractions` and no `HoneyDrunk.AI.Providers.*` package directly." Preserves the original ADR-0016 D9 intent ("no AI-provider lock-in at the consumer site") without amendment-by-exception.
- **C** — carve out by addition (leave invariant 44 alone, add a new invariant at `{N4}+1` permitting `HoneyDrunk.Prompts.Abstractions` as a sibling AI-sector dependency). Heaviest constitution surface.

Packet 00's PR description surfaces this for human resolution. Packet 01 applies the chosen resolution in the same commit as N1–N4 land.

### Required Decision 2 — paired standup ADR filing posture

ADR-0064 D12 commits a paired `HoneyDrunk.Prompts` standup ADR following the ADR-0058 / ADR-0059 precedent. Two postures:
- **A** — file the standup ADR draft now via adr-composer, in this initiative's filing window. A sibling `adr-{N}-prompts-standup` initiative is created.
- **B (recommended)** — defer the standup ADR draft until after ADR-0064 reaches Accepted on `main`. Mirrors the ADR-0058 / ADR-0059 cadence (ADR-0058 was Accepted before ADR-0059's standup packets landed). Reduces filing-window surface and the chance of races between the two adr-composer drafts.

Either is acceptable; the packets here are identical. Packet 05 authors the spec the adr-composer reads regardless of posture.

### No new `AuditCategory` enum value

The refine-pass clarification is load-bearing across packets 03 and 04: do NOT invent an `Inference` category. The LLM-call emit uses existing `AgentAction` (agent-execution-originated calls) and `Integration` (non-agent-originated calls — wiki-ingest skill, one-off operator diagnostic, Notify Cloud rendering step). The category is the discriminator between agent and integration LLM activity; the prompt-tuple metadata is the per-call detail.

The reason this matters: introducing a new `AuditCategory` value is a major-breaking-shape change on `HoneyDrunk.Audit.Abstractions` per ADR-0035 strict semver. The category enum is part of the contract surface canary (invariant 49). Adding a value where the existing two-category split works is unnecessary risk.

### Audit payload is tuple-only

Across N1 (invariant), packet 03 (audit catalog), and packet 04 (agent checklists): the LLM-call audit payload never carries the rendered prompt body, the completion text, or the substituted parameter values. The reason: substituted parameters may carry `Restricted`-tier content per ADR-0049 / N2; the audit substrate's append-only-by-interface stance does not enable redaction-after-the-fact; the right discipline is never let the bodies / completions / substituted values into the payload in the first place.

Forensic reconstruction of "what text did the model actually see" is achieved by:
1. Reading the `(prompt_id, prompt_version, prompt_hash)` from the audit entry.
2. Resolving the prompt content from the `HoneyDrunk.Prompts` repo at the indicated version (the hash confirms byte-exactness).
3. Reading the substituted parameter values from the Node's *application* logs (not the audit channel — the application logs are subject to the Node's own retention / classification posture, which may include redaction).

This split keeps the audit channel free of PII while preserving forensic reconstruction capability.

### Tier names per ADR-0049

ADR-0049 D1 commits four classification tiers: `Public`, `Internal`, `Confidential`, `Restricted`. `Sensitive` is a **PII sub-classification** under D2 (a sub-taxonomy of `Restricted`), **not** a top-level tier. Across N2 and packet 04, the rule for `HoneyDrunk.Prompts` files is "Public / Internal / Confidential only, never `Restricted`." Do not say "no Sensitive" — say "no Restricted." Sensitive is a sub-category that does not apply at the file-classification level.

### Paired standup ADR is filed as a separate sibling track

This initiative does not create the `HoneyDrunk.Prompts` repo, does not write the contract code, does not land catalog edges. Packet 05 authors the spec the adr-composer reads when it drafts the paired standup ADR. The standup ADR's own packets (scaffold, contract, runtime, seed migration, catalog rows) land in a sibling initiative folder when the user invokes the adr-composer per Required Decision 2.

This is the same pattern ADR-0067 used for the Notify Cloud rate-limit policy implementation (deferred to ADR-0027's standup completion + a follow-up packet).

### Site sync

No site-sync flag. ADR-0064 is internal AI-sector infrastructure; the Studios website does not change. (Once the `HoneyDrunk.Prompts` Node is stood up via the paired standup ADR, the Studios website's Grid visualization gains the Prompts Node — but that is the standup ADR's site-sync concern, not this initiative's.)

### Deferred follow-ups (explicitly out of scope of this initiative)

- **`HoneyDrunk.Prompts` Node standup** (the paired standup ADR + its packet set). Drafted by adr-composer per Required Decision 2. Includes repo creation, the three .NET projects, CI pipeline (contract-shape canary, content-shape canary, classification gate, `pr-core.yml`), `repos/HoneyDrunk.Prompts/` folder, catalog rows, seed migration (Honeyclaw + Lore), Honeyclaw OpenClaw export workflow.
- **AI-sector consumer wiring.** Agents (ADR-0020), Operator (ADR-0018), Memory (ADR-0022), Knowledge (ADR-0021), Evals (ADR-0023), Lore — each Node's first registry-aware feature packet wires `IPromptResolver` consumption + the `LlmCall` audit emit. These packets land in each Node's own standup or feature initiative, not here.
- **Honeyclaw OpenClaw export workflow implementation.** Deferred to the standup ADR's decision (private gist / Vault config blob / OpenClaw API call). Until it lands, the user manually copies the persona text from the Grid repo to OpenClaw at each release.
- **Evals release-gate ADR.** Per ADR-0064 D6, a future ADR may add Evals as a release gate for the prompts package (major/minor bumps cannot publish without affected suites passing). Out of scope here.
- **PDR-app persona registration packets.** Per ADR-0064 D8, Hearth (first-build pick), Lately, Curiosities register their personas at their first AI-enabled feature packet — those packets land in each app's initiative, not here.

## Rollback Plan

- **Packets 00–02 (governance):** revert the PR. ADR returns to Proposed; the four invariants disappear from `constitution/invariants.md`; the invariant 44 amendment is reverted; the sectors.md Prompts row is removed; the ai-sector-architecture.md subsection is removed. The ADR-0064 reservation row returns to **Active Reservations** if it had been moved to history. No runtime impact (no code, no Node exists).
- **Packet 03 (Audit docs):** revert the PR; the LLM-Call Audit Catalog section is removed from `HoneyDrunk.Audit`'s docs. No runtime impact (no code).
- **Packet 04 (agent checklists):** revert the PR; the four prompt-registry checklist items are removed from `scope.md` and `review.md`. After revert, the user restarts Claude Code so the reverted files re-register. No runtime impact on any deployed Node.
- **Packet 05 (standup handoff spec):** revert the PR; the spec document is removed. No runtime impact. The paired standup ADR's drafting is unaffected at the runtime level; only the input document for the adr-composer is gone (the adr-composer can still draft the standup ADR by reading ADR-0064 directly, just with more derivation).
- **Operational escape hatch:** none required at this initiative's stage. The Node does not exist yet; no consumer is wired; no LLM call emits an `LlmCall` audit entry yet (the first emitter ships with the AI-sector consumer wiring in a later initiative). If a defect surfaces in the policy itself post-acceptance, the fix is an amendment to ADR-0064 + a new acceptance packet, not a rollback.

## Filing

Filing is automated. On push to `main`, `file-work-items.yml` in `HoneyDrunk.Architecture` files every packet in this folder as a GitHub issue in its `target_repo`, adds it to The Hive (project #4), sets the board fields from frontmatter, and wires `addBlockedBy` edges from the `dependencies:` arrays. No manual `gh issue create`.

The paired `HoneyDrunk.Prompts` standup ADR is **not** filed by this initiative's push. It is filed later, as a separate adr-composer invocation per Required Decision 2 in packet 00 — either as Posture A (in this initiative's filing window, as a sibling initiative folder) or as Posture B (after this initiative completes, as a follow-up task).
