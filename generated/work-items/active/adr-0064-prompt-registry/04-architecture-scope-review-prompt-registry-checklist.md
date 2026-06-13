---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ai", "docs", "adr-0064", "wave-2"]
dependencies: ["work-item:00", "work-item:01"]
adrs: ["ADR-0064"]
wave: 2
initiative: adr-0064-prompt-registry
node: honeydrunk-architecture
---

# Update scope.md and review.md with the ADR-0064 prompt-registry checklist

## Summary
Per ADR-0064's "Follow-up Work" obligations on the scope agent and the review agent: update `.claude/agents/scope.md` and `.claude/agents/review.md` so both agents check four things whenever a packet introduces (or modifies) an LLM call or a prompt-registry artifact — (a) the call resolves through `IPromptResolver` rather than inlining a body string; (b) the `LlmCall` audit emit is wired with the tuple-only payload; (c) any new prompt file declares `classification` other than `Restricted` and contains no PII / no secrets; (d) any new prompt file's body `{{ parameter }}` placeholders match the declared `parameters` frontmatter list. Coupled context-loading per invariant 33 — both files updated in the same packet so they do not drift. Docs-only packet against the Architecture repo's agent definitions.

## Context
ADR-0064 §Follow-up Work explicitly calls out two agent-checklist obligations:

> Update `.claude/agents/review.md` per the cloud-code-review ADR — new PR-review checklist items for `HoneyDrunk.Prompts` PRs: classification field present and not `Restricted`, no inlined PII, parameter declarations cover every placeholder in the body, body change triggers minor bump.
>
> Update `.claude/agents/scope.md` — packets that introduce LLM calls must declare which persona/prompt id they consume from `HoneyDrunk.Prompts`; absent declaration is grounds to amend the packet before filing.

Invariant 33 ("Review-agent and scope-agent context-loading contracts are coupled") makes this a single-packet, both-files update — they must move together so neither agent has a class of prompt-registry-related defect the other cannot see.

The four checks the agents gain (consolidated and reorganized for ergonomic review-time scanning):

1. **Resolver-not-inline (N3 from packet 01)** — if a packet introduces or modifies an LLM call, the call must resolve through `IPromptResolver` rather than inlining a body string. One-off bypasses are permitted but record `bypassed_registry: true` in the `LlmCall` audit emit. The packet declares the consumed `persona_id` / `prompt_id` in its body so the reviewer can verify.
2. **LlmCall audit emit (N1 from packet 01)** — if a packet introduces an LLM call, the call site emits an `LlmCall` audit entry with the tuple-only payload (`persona_id`, `persona_version`, `persona_hash`, `prompt_id`, `prompt_version`, `prompt_hash`, `bypassed_registry`, plus `model_id` / `provider` / `correlation_id`). Per the documented Audit catalog (packet 03 of this initiative), the category is `AgentAction` for agent-execution-originated calls, `Integration` for non-agent-originated calls. The payload never carries the rendered prompt body, the completion text, or the substituted parameter values.
3. **Classification + secret-scan (N2 from packet 01)** — if a packet adds or modifies a prompt or persona file in `HoneyDrunk.Prompts`, the file's `classification` frontmatter is one of `Public`, `Internal`, or `Confidential` (never `Restricted`); no PII inline; no secret values inline. PII enters via parameters at render time; secrets stay in Vault.
4. **Placeholder-parameter parity (N4 / D9)** — if a packet adds or modifies a prompt file in `HoneyDrunk.Prompts`, every `{{ parameter_name }}` placeholder in the body has a matching entry in the file's `parameters` frontmatter list (and vice versa — unused declared parameters are flagged). The double-brace `{{ }}` form is required (single-brace `{ }` is uncapturable distinction per D9; see the Constraints).

This is a docs/agent-config packet. No code, no .NET project.

## Scope
- `.claude/agents/scope.md` — extend the agent's quality-check / packet-authoring section with the four prompt-registry checks, placed where the existing checklist items live (likely under "Quality Checklist" or a similar section — verify at edit time).
- `.claude/agents/review.md` — extend the agent's review-category checklist with the same four checks, placed in the appropriate review-category sections (likely the AI / Security / Data-Classification / Boundary categories the file uses).

## Proposed Implementation
1. **`.claude/agents/scope.md`** — locate the file's checklist or quality-check section (matching the "Quality Checklist" pattern visible in the agent's reference text). Add four new checklist items, each phrased as a positive obligation:
   - "If a packet introduces or modifies an LLM call (a call to `IChatClient` or `IEmbeddingGenerator` or any composition thereof), the packet body declares which `persona_id` and/or `prompt_id` the call consumes from `HoneyDrunk.Prompts`. A packet that introduces an LLM call without a declared id (or without explicit acknowledgement that the call bypasses the registry) is amended before filing per ADR-0064 §Follow-up Work."
   - "If a packet introduces an LLM call, the packet body confirms the call site emits an `LlmCall` audit entry with the tuple-only payload (`persona_id`, `persona_version`, `persona_hash`, `prompt_id`, `prompt_version`, `prompt_hash`, `bypassed_registry`, plus `model_id` / `provider` / `correlation_id`). The payload **never** carries the rendered prompt body, the completion text, or the substituted parameter values."
   - "If a packet adds or modifies a prompt or persona file in `HoneyDrunk.Prompts`, the packet body confirms the file's `classification` frontmatter is `Public`, `Internal`, or `Confidential` — never `Restricted`. No PII inline; no secret values inline. PII enters via parameters at render time per ADR-0064 D10."
   - "If a packet adds or modifies a prompt file in `HoneyDrunk.Prompts`, the packet body confirms every `{{ parameter_name }}` placeholder in the body has a matching entry in the `parameters` frontmatter list, and every declared parameter is referenced by at least one placeholder. Double-brace `{{ }}` is required; single-brace `{ }` is forbidden per ADR-0064 D9."

2. **`.claude/agents/review.md`** — locate the review-category structure (matching the review-rubric pattern). Add four new check items into the appropriate categories:
   - **Resolver-not-inline check** — under the AI / boundary-preservation category. Phrasing: "When a PR introduces an LLM call (any call to `IChatClient` / `IEmbeddingGenerator`), verify the call resolves through `IPromptResolver`. An inlined prompt body as a string literal is a violation of invariant N3 (ADR-0064) unless the call is an explicit one-off and emits `bypassed_registry: true` to audit."
   - **LlmCall audit emit check** — under the AI / Audit category. Phrasing: "When a PR introduces an LLM call, verify the call site emits an `LlmCall` audit entry with the documented tuple (`persona_id`, `persona_version`, `persona_hash`, `prompt_id`, `prompt_version`, `prompt_hash`, `bypassed_registry`, `model_id`, `provider`, `correlation_id`). The payload must not carry the rendered prompt body, the completion text, or the substituted parameter values — those carry PII and exceed audit retention's classification posture. Category selection: `AgentAction` for agent-execution calls, `Integration` for non-agent-originated calls; no new `AuditCategory` value."
   - **Prompt-file classification + secret-scan check** — under the Security / Data-Classification category. Phrasing: "When a PR adds or modifies a prompt or persona file in `HoneyDrunk.Prompts`, verify the file's `classification` frontmatter is not `Restricted` (per ADR-0064 D10 — `HoneyDrunk.Prompts` is a public repo, Restricted-tier content has no place there). Verify no inlined values look tenant-scoped, PII-bearing, or secret. The CI gate in `HoneyDrunk.Prompts` enforces this, but reviewer eyes catch the subtle cases CI does not."
   - **Placeholder-parameter parity check** — under the Schema / Contract category. Phrasing: "When a PR adds or modifies a prompt file in `HoneyDrunk.Prompts`, verify every `{{ parameter_name }}` placeholder in the body has a matching entry in the `parameters` frontmatter list, and every declared parameter is referenced by at least one placeholder. Verify the double-brace `{{ }}` form is used (single-brace `{ }` is forbidden per D9 — single-brace placeholders are accidentally captured by C# interpolation, Python f-strings, and other formatters that may sit between authoring and the LLM call site). The content-shape canary per invariant N4 (ADR-0064) enforces this in CI; reviewer is the second line."
3. **Cite the source.** Each new check item should reference ADR-0064 D5 / D9 / D10 / D11 by D-letter (not by ADR-number-in-prose for public-facing docs; agent files are internal architecture artifacts where ADR citation by ID is acceptable and matches the surrounding convention; verify by scanning the file's existing references).
4. **Both files updated in the same commit / PR.** Invariant 33's coupling rule means scope.md and review.md must not diverge — one without the other is the anti-pattern the invariant exists to prevent.

## Affected Files
- `.claude/agents/scope.md`
- `.claude/agents/review.md`

## NuGet Dependencies
None. Markdown / agent-config packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture` (`.claude/agents/` is the canonical home for the Grid's agent definitions).
- [x] No code change in any other repo.
- [x] Both agents updated in the same PR per invariant 33.

## Acceptance Criteria
- [ ] `.claude/agents/scope.md` carries four new checklist items: resolver-not-inline (N3 / D11), `LlmCall` audit emit tuple-only (N1 / D5), prompt-file classification + no PII (N2 / D10), placeholder-parameter parity (N4 / D9)
- [ ] `.claude/agents/review.md` carries four matching check items, placed in the appropriate review-category sections (AI / Audit / Security / Schema or equivalent)
- [ ] Both files' new items reference ADR-0064 D5 / D9 / D10 / D11 by D-letter
- [ ] Both files explicitly state the `LlmCall` audit category selection rule: `AgentAction` for agent-execution calls, `Integration` for non-agent calls; **no new `AuditCategory` value is introduced**
- [ ] Both files explicitly state the tuple-only payload rule: the payload never carries the rendered prompt body, the completion text, or the substituted parameter values
- [ ] Both files explicitly state the `classification: Restricted` forbidden rule for `HoneyDrunk.Prompts` files
- [ ] Both files explicitly state the double-brace `{{ }}` placeholder requirement (single-brace `{ }` forbidden per D9)
- [ ] Both files are updated in the same commit / PR (invariant 33 — coupled context-loading contracts)
- [ ] No existing checklist items are removed or renumbered
- [ ] No ADR status edit in this packet

## Human Prerequisites
None.

> Note: after this packet merges, the user should restart Claude Code so the updated agent files re-register with the running session — this is a runtime hygiene step the user owns, not a packet acceptance criterion. The same caveat appears in sibling packets that touch `.claude/agents/`.

## Referenced ADR Decisions
**ADR-0064 D5 — Audit emit.** Every LLM call records `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash, bypassed_registry?)` to `IAuditLog`. Tuple-only payload (no body, no completion, no substituted parameter values per the refine-pass clarification).

**ADR-0064 D9 — On-disk schema.** Placeholders use double-brace `{{ parameter_name }}` Mustache-style — distinct from C# string interpolation `{name}`, distinct from f-string `{name}`, distinct from `%(name)s`, to avoid accidental capture by any of those interpolation systems passing through the text. The `parameters` frontmatter list declares each placeholder; the content-shape canary per N4 enforces parity.

**ADR-0064 D10 — PII and sensitive content.** Prompts and personas are **public-or-internal text artifacts** per ADR-0049. No `Restricted`-tier or PII-bearing value inline. Per the data-classification taxonomy, tier names are `Public / Internal / Confidential / Restricted`. PII enters via parameters at render time.

**ADR-0064 D11 — Loader location.** `IPromptResolver` in `HoneyDrunk.Prompts.Abstractions`; consumers compose at the call site. The reviewer agent rule per ADR-0044 covers prompt-file PRs.

**ADR-0064 §Follow-up Work — agent-checklist obligations.** Explicit on both scope.md and review.md updates: scope.md gains the "packets introducing LLM calls declare which persona/prompt id they consume" item; review.md gains the "classification field present and not Restricted, no inlined PII, parameter declarations cover every placeholder, body change triggers minor bump" item set.

**Invariant 33 — Review-agent and scope-agent context-loading contracts are coupled (full text):**
> The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information.

**Invariant `{N1}` (ADR-0064, landed by packet 01).** Every `IChatClient` / `IEmbeddingGenerator` call emits the prompt tuple; the emit is never optional; the payload is tuple-only.

**Invariant `{N2}` (ADR-0064, landed by packet 01).** No PII, no `Restricted`-tier content, no secret values inline in `HoneyDrunk.Prompts` files; CI gate enforces.

**Invariant `{N3}` (ADR-0064, landed by packet 01).** Application code must never inline a persona's or prompt's body text as a string literal when the registry has an entry for it; new code paths resolve through `IPromptResolver`.

**Invariant `{N4}` (ADR-0064, landed by packet 01).** `HoneyDrunk.Prompts` CI must include a contract-shape canary on `IPromptResolver` and a content-shape canary asserting frontmatter parses and body placeholders match declared parameters.

## Constraints
- **Both files updated in the same PR (invariant 33).** Do NOT land scope.md and review.md in separate PRs — the coupling rule forbids divergence even temporarily.
- **Positive obligations, not "if you remember."** Phrase the new items as obligations that fail review if absent, not as soft "consider checking" prompts.
- **Cite by D-letter only.** ADR-0064 D5 / D9 / D10 / D11 — not "ADR-0064" alone. The D-letters anchor the specific decisions.
- **State the no-new-AuditCategory rule explicitly.** Both agents must enforce that LLM-call emits use the existing `AgentAction` (agent-originated) or `Integration` (non-agent-originated) categories — never an invented `Inference` category. The refine-pass call-out from the initiative is load-bearing.
- **State the tuple-only payload rule explicitly.** Both agents must enforce that the `LlmCall` audit payload never carries the rendered prompt body, the completion text, or the substituted parameter values. This is the load-bearing constraint that protects audit retention from PII contamination.
- **State the double-brace `{{ }}` placeholder requirement.** Single-brace `{ }` is forbidden per D9; both agents flag single-brace placeholders in prompt-file PRs.
- **State the `classification: Restricted` forbidden rule for `HoneyDrunk.Prompts`.** Per D10, files in that repo are Public, Internal, or Confidential only; reviewer agent flags `Restricted` in frontmatter.
- **No ADR status flip.**

## Labels
`feature`, `tier-2`, `ai`, `docs`, `adr-0064`, `wave-2`

## Agent Handoff

**Objective:** Add four new prompt-registry checklist items (D5 audit emit tuple-only, D9 placeholder parity, D10 classification + no PII, D11 resolver not inline) to both `.claude/agents/scope.md` and `.claude/agents/review.md` in a single PR per invariant 33.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Ensure both scope-time packet authoring and PR-time review catch missing prompt-registry resolution, missing audit-emit, files inline PII / Restricted classification, and placeholder-parameter mismatch on any new LLM-call or prompt-file packet.
- Feature: ADR-0064 Prompt and Persona Registry rollout, Wave 2.
- ADRs: ADR-0064 D5 / D9 / D10 / D11 (primary), ADR-0049 (classification regime), ADR-0030 (audit substrate), ADR-0044 (review rubric for review.md placement).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — initiative registered.
- `work-item:01` — invariants `{N1}/{N2}/{N3}/{N4}` live in `constitution/invariants.md` before the agents reference them as canonical prompt-registry rules.

**Constraints:**
- Both files updated in the same PR (invariant 33). Do NOT split.
- Positive obligations; the review agent fails review if a packet introduces an LLM call without naming the consumed persona/prompt id.
- Cite by D-letter (D5 / D9 / D10 / D11) so the rules are unambiguous.
- State the no-new-`AuditCategory`-value rule explicitly (existing `AgentAction` / `Integration` categories only).
- State the tuple-only payload rule explicitly (no body, no completion, no substituted parameter values).
- State the double-brace `{{ }}` placeholder requirement and the `classification: Restricted` forbidden rule for `HoneyDrunk.Prompts` files.

**Key Files:**
- `.claude/agents/scope.md`
- `.claude/agents/review.md`

**Contracts:** None changed. Agent configuration only.
