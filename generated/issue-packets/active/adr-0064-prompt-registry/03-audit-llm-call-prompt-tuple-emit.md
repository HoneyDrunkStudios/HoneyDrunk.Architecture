---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Audit
labels: ["feature", "tier-2", "ai", "docs", "adr-0064", "wave-2"]
dependencies: ["packet:00", "packet:01"]
adrs: ["ADR-0064"]
wave: 2
initiative: adr-0064-prompt-registry
node: honeydrunk-audit
---

# Document the LLM-call prompt-tuple audit emit shape in HoneyDrunk.Audit

## Summary
Confirm and document the canonical metadata-key shape ADR-0064 D5 commits for every LLM-call audit emit — `persona_id`, `persona_version`, `persona_hash`, `prompt_id`, `prompt_version`, `prompt_hash`, `bypassed_registry` — in `HoneyDrunk.Audit`'s docs. **The emit rides existing `AuditCategory.AgentAction` (agent-originated calls) or `AuditCategory.Integration` (system / non-agent-originated calls) — no new `AuditCategory` enum value is introduced.** The payload is **tuple-only**: never the rendered prompt body, never the completion text, never the substituted parameter values. Docs-only packet; no contract change, no code change. The two ride the existing `AuditEntry.EventName` free-string field and the existing `Metadata` dictionary; this packet pins the canonical event-name, the category-selection rule, and the metadata-key shape so the AI-sector Nodes that emit these events (Agents, Operator, Memory, Knowledge, Evals, Lore — and any future Node that makes LLM calls) follow one canonical shape and forensic queries find them.

## Context
ADR-0064 D5 commits the per-LLM-call audit emit (full text):

> Every `IChatClient` and `IEmbeddingGenerator` call records to `IAuditLog` (per the audit substrate) the following tuple as part of the audit entry's structured payload: `persona_id`, `persona_version`, `persona_hash`, `prompt_id`, `prompt_version`, `prompt_hash`. Calls that bypass the registry record `persona_id: null`, `prompt_id: null`, and a flag `bypassed_registry: true`. This tuple is required on every LLM-call audit emit. Bypassed-registry calls are operationally legitimate; the goal of the registry is that every production LLM call goes through it; the audit query "how many inline-prompt calls happened" measures progress toward 100% coverage.

The Audit substrate per ADR-0030 ships `IAuditLog`, `IAuditQuery`, the `AuditEntry` record, and a six-value `AuditCategory` enum (`Security`, `UserActivity`, `DataChange`, `SystemAction`, `AgentAction`, `Integration`). The LLM-call audit emit fits cleanly into the existing categories:

- **`AgentAction`** (`AuditCategory.AgentAction = 4`) — defined as "Agent activity such as delegated work, tool execution, or handoffs." When an agent (per ADR-0020) makes an LLM call as part of its execution, the emit is an agent action; the category captures it.
- **`Integration`** (`AuditCategory.Integration = 5`) — defined as "External integration ingress or egress activity." When a non-agent system component makes an LLM call (e.g., a wiki-ingest skill, a one-off operator diagnostic call, a Notify Cloud rendering step), the call is an outbound integration call to an external provider (OpenAI, Anthropic, Azure OpenAI); the category captures it.

The **two-category split** is structurally meaningful: queries against `AuditCategory.AgentAction` find agent-driven LLM activity; queries against `AuditCategory.Integration` find system-driven LLM activity. Mixing both into a single new "Inference" category would lose this discriminator. **Per the refine-pass clarification: do not invent a new `AuditCategory` value for LLM calls.** Use the existing categories with the prompt-tuple metadata keys to discriminate; the metadata is the discriminator, not the category.

This packet documents the canonical event-name + category-selection rule + metadata-field shape in `HoneyDrunk.Audit`'s docs (`README.md` or a new `docs/event-catalog.md`) so:

- AI-sector emitter Nodes (Agents at GA; Operator, Memory, Knowledge, Evals, Lore as they ship) emit the right `EventName` verbatim, pick the right category, and emit the canonical metadata-key shape.
- Forensic queries against the audit substrate find LLM-call entries by `EventName` and the prompt-tuple metadata keys.
- The pattern is single-sourced in the Audit Node's repo — not duplicated across the emitter Nodes' READMEs.

This packet **does not** add code, does not change `IAuditLog` / `AuditEntry` / `AuditCategory`, and does not introduce a new abstraction. The pattern mirrors how ADR-0067 packet 03 documented `RateLimitRejected` and `QuotaOverageBilled` against the existing `AuditEntry.EventName` free-string field — same shape, same kind of registration, different event names.

`HoneyDrunk.Audit` is a docs-only target here — no `.csproj` edits unless the repo's convention requires a PATCH for docs. The repo's existing CHANGELOG convention takes priority; do **not** introduce an `[Unreleased]` section per the user's standing memory note.

## Scope
- `HoneyDrunk.Audit/README.md` (or `HoneyDrunk.Audit/docs/event-catalog.md` if the executor judges the README is the wrong home) — extend with an `## LLM-Call Audit Catalog` section documenting the canonical event-name, the category-selection rule (`AgentAction` vs `Integration`), the metadata-key shape, the tuple-only payload rule, and the no-secret-values guarantee.
- `HoneyDrunk.Audit/CHANGELOG.md` — record the documentation addition under a dated version section (either appended to the most recent dated entry as a `## Documentation` subsection if the convention allows, or a new dated PATCH-bumped entry). **No `[Unreleased]`.**
- No `.csproj` edits. No code change. No `AuditCategory` enum addition. No new abstraction.

## Proposed Implementation
1. Open `HoneyDrunk.Audit/README.md` (or the repo's documentation home for event catalogs — if a `docs/event-catalog.md` exists from packet 03 of `adr-0067-rate-limiting` or any other prior catalog addition, append there; otherwise add to README as a new top-level `## LLM-Call Audit Catalog` section).
2. Add the canonical catalog (substance-verbatim — preserve the event-name, the category-selection rule, the metadata-key names, the tuple-only constraint, and the no-secret-values guarantee exactly so future Audit-repo readers find one canonical source):

   ```
   ## LLM-Call Audit Catalog

   The Grid emits one canonical audit event-type from every LLM call across every Node that consumes `IChatClient` or `IEmbeddingGenerator` (the AI-sector emitter Nodes: Agents, Operator, Memory, Knowledge, Evals, Lore; plus any future Node that makes LLM calls). The event rides the existing `AuditEntry.EventName` free-string field; no new contract is required and no new `AuditCategory` value is introduced — the call site selects from the existing `AgentAction` or `Integration` categories per the rule below.

   ### `LlmCall`

   Emitted on every `IChatClient` or `IEmbeddingGenerator` invocation. The call site captures the prompt-tuple metadata regardless of whether the call composed a registered prompt or bypassed the registry — the emit itself is **never optional**.

   - **Category selection rule:**
     - `AuditCategory.AgentAction` — when the LLM call is part of an **agent execution** (the call originates from inside an agent's `IAgentExecutionContext` per the Agents Node). The agent's identity is recoverable from the audit entry's `Actor` field.
     - `AuditCategory.Integration` — when the LLM call is **not** part of an agent execution (a wiki-ingest skill, a one-off operator diagnostic call, a Notify Cloud rendering step, a non-agent system component). The integration is the outbound call to the external LLM provider.
   - **Outcome:** `AuditOutcome.Succeeded` for completed calls; `AuditOutcome.Failed` if the provider returned an error or the call was canceled. **Do not** set outcome based on whether the registry was bypassed — bypassed-registry calls that succeeded are `Succeeded`; the `bypassed_registry` field in the metadata is the bypass signal, not the outcome.
   - **Actor:** the agent identifier (for `AgentAction`) or the calling Node / service identifier (for `Integration`). Never an end-user identifier raw — per the data-classification regime, only pseudonymous tokens are acceptable in audit Actor fields.
   - **Target:** the **registered prompt id** if one was composed (e.g., `prompts/honeydrunk-knowledge/query-rewrite`); the literal string `"inline-prompt"` if the call bypassed the registry. `Target` is **not** the LLM provider — that is a metadata field. `Target` is the prompt content the call was *about*.
   - **TenantId:** the resolved `TenantId` from the operation context. `TenantId.Internal` for Grid-internal calls (e.g., the Lore wiki-ingest skill running on a scheduled job).
   - **Metadata fields** (in the `Metadata` dictionary, lower-case snake_case keys, all string-valued — `Metadata` is `IReadOnlyDictionary<string, string>`):
     - `persona_id` — the persona's `id` from the prompt-registry frontmatter (e.g., `"honeyclaw-bear-keeper"`, `"evals-judge"`, `"operator-safety-filter"`). Absent (key not present) if the call composed no persona.
     - `persona_version` — the semver version of `HoneyDrunk.Prompts` that supplied the persona (e.g., `"1.3.0"`). Absent if `persona_id` is absent.
     - `persona_hash` — the SHA-256 content hash of the persona file at that version, lower-case hex, no `sha256:` prefix (e.g., `"a3f2c1…"`, 64 hex chars). Absent if `persona_id` is absent.
     - `prompt_id` — the prompt's `id` from the prompt-registry frontmatter. Absent if the call composed no template (raw user message only) — i.e., a fully bypassed call.
     - `prompt_version` — the semver version of `HoneyDrunk.Prompts` that supplied the prompt. Absent if `prompt_id` is absent.
     - `prompt_hash` — the SHA-256 content hash of the prompt file at that version. Absent if `prompt_id` is absent.
     - `bypassed_registry` — `"true"` if the call composed an inline raw system message or skipped the registry entirely; absent or `"false"` otherwise. **The bypassed_registry flag is the only metadata field present on every emit** — it is the discriminator between registered and inline calls.
     - `model_id` — the model identifier per ADR-0041's model registry (e.g., `"gpt-4o-2026-03-15"`). Non-secret operator-visible string.
     - `provider` — the provider key (e.g., `"openai"`, `"anthropic"`, `"azure-openai"`). Non-secret.
     - `correlation_id` — the request-correlation identifier from `IGridContext.CorrelationId`. Required.

   ### Payload constraints (load-bearing)

   The audit payload for `LlmCall` is **tuple-only**:

   - **Never** the rendered prompt body (i.e., the prompt text after parameter substitution).
   - **Never** the completion text (i.e., the LLM's response).
   - **Never** the substituted parameter values (i.e., the actual values that were substituted into `{{ placeholder }}` slots at render time — these may carry PII per the prompt-registry's PII-via-parameters rule).
   - The prompt-tuple metadata fields (`persona_id`, `prompt_id`, etc.) carry only the **identifiers, versions, and hashes** — they are non-secret references to the prompt-registry contents.

   The reason: prompt bodies can be multi-kilobyte; completion text can be too; substituted parameter values may carry PII (`Restricted` or `Confidential` tier per the data-classification taxonomy). The audit substrate's append-only-by-interface stance does not enable redaction-after-the-fact; the right discipline is to never let the bodies / completions / substituted values into the payload in the first place. Forensic reconstruction of what text the model saw is achieved by resolving `(prompt_id, prompt_version, prompt_hash)` against the `HoneyDrunk.Prompts` repo at the indicated version, then re-rendering with the same parameters from the request log (the request log carries parameters in the Node's *application* logs, not in the audit channel, and is subject to the Node's own retention / classification).

   No secret value is recorded. Provider API keys, signing secrets, and any other secret material per the secrets-in-Vault rule never appear in any field.

   ## Cross-references

   - **ADR-0064 D5** — LLM-call audit emit contract.
   - **ADR-0030** — audit substrate, append-only-by-interface stance, durable channel.
   - **ADR-0049** — data classification taxonomy; the tuple-only rule exists because substituted parameter values may carry Restricted-tier content.
   - **ADR-0041** — model registry (`model_id` metadata field).
   - **Invariant 8** — secret values never appear in logs, traces, exceptions, or telemetry; extended to audit entries here.
   - **Invariant `{N1}` (ADR-0064)** — every LLM call emits this audit entry; the emit is never optional even on bypassed-registry calls.
   ```

   Adjust prose to match the repo's existing tone if the README's style differs noticeably; preserve the canonical event-name string `LlmCall`, the metadata-key names, the category-selection rule, and the tuple-only / no-secret-values constraints verbatim.
3. Update `HoneyDrunk.Audit/CHANGELOG.md`. Two options per the repo's convention:
   - **Option A** — if doc-only additions are acceptable as an additive `## Documentation` note on the most recent dated version entry, append a note to that entry recording "Added LLM-Call Audit Catalog documenting the `LlmCall` event-name and the prompt-tuple metadata-key shape per ADR-0064 D5."
   - **Option B** — create a new dated PATCH-bumped entry (e.g., `[0.1.1] - 2026-MM-DD`) with the same note. If a PATCH-bump is chosen, every non-test `.csproj` in the solution is updated to the same new PATCH version in a single commit (invariant 27).
   - Do **not** use `[Unreleased]`. State the chosen option in the PR.
4. Update repo-level `README.md` if needed to link to the new section (the existing README is short enough that the section appears in the same file; if the section is lifted to `docs/event-catalog.md`, add a `## Documentation` link in the README).

## Affected Files
- `HoneyDrunk.Audit/README.md` (the canonical LLM-call event-catalog section appended), or `HoneyDrunk.Audit/docs/event-catalog.md` (if the executor lifts the section out of README; preferred if a `docs/event-catalog.md` already exists).
- `HoneyDrunk.Audit/CHANGELOG.md` (the documentation note under a dated version section).
- Optionally every non-test `.csproj` in the solution if Option B is chosen for the CHANGELOG bump.

## NuGet Dependencies
None. This packet touches only Markdown documentation and possibly a single PATCH `<Version>` bump.

## Boundary Check
- [x] All edits in `HoneyDrunk.Audit`. Routing rule "audit, AuditLog, audit substrate → HoneyDrunk.Audit" maps exactly.
- [x] No contract change to `IAuditLog` / `IAuditQuery` / `AuditEntry` / `AuditCategory` — the LLM-call event-type rides the existing `EventName` free-string field and uses existing `AgentAction` / `Integration` categories.
- [x] **No new `AuditCategory` enum value.** Per the refine-pass clarification: do not invent an `Inference` category. The existing two-category split (`AgentAction` for agent-originated, `Integration` for non-agent-originated) is the discriminator, with the prompt-tuple metadata as the per-call detail.
- [x] No new abstraction. No new code. Documentation-only registration of the canonical event-name + metadata-key shape per ADR-0064 D5.

## Acceptance Criteria
- [ ] `HoneyDrunk.Audit/README.md` (or `docs/event-catalog.md`) carries an `LLM-Call Audit Catalog` section
- [ ] `LlmCall` is documented as the canonical event-name string
- [ ] The category-selection rule is documented: `AgentAction` for agent-execution-originated calls; `Integration` for non-agent-originated calls. **No new `AuditCategory` value is introduced.**
- [ ] The metadata-key set is documented exactly: `persona_id`, `persona_version`, `persona_hash`, `prompt_id`, `prompt_version`, `prompt_hash`, `bypassed_registry`, `model_id`, `provider`, `correlation_id` — with absence semantics and the all-string-valued constraint
- [ ] The **tuple-only payload rule** is documented as a load-bearing constraint: the payload never contains the rendered prompt body, the completion text, or the substituted parameter values
- [ ] The rationale for the tuple-only rule is documented: forensic reconstruction is achieved by resolving `(prompt_id, prompt_version, prompt_hash)` against the `HoneyDrunk.Prompts` repo at the indicated version, not by carrying the body in the audit payload
- [ ] Cross-references to ADR-0064 D5, ADR-0030, ADR-0049, ADR-0041, invariant 8, and the new invariant `{N1}` from packet 01 are present
- [ ] `HoneyDrunk.Audit/CHANGELOG.md` records the documentation addition under a dated version section; `[Unreleased]` is NOT used
- [ ] No code change in any `.cs` file
- [ ] No `IAuditLog` / `AuditEntry` / `AuditCategory` contract change
- [ ] `Directory.Build.props` / `<Version>` is bumped only if Option B is chosen and only by PATCH (e.g., 0.1.0 → 0.1.1), with every non-test `.csproj` in the solution updated in a single commit per invariant 27

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0064 D5 — Audit emit (tuple-only, full text):**

> Every `IChatClient` and `IEmbeddingGenerator` call records to `IAuditLog` the tuple: `persona_id` (null if no persona), `persona_version` (null if no persona), `persona_hash` (null if no persona), `prompt_id` (null if raw user message only), `prompt_version`, `prompt_hash`. Calls that bypass the registry record `persona_id: null`, `prompt_id: null`, and `bypassed_registry: true`. The audit emit itself is never optional. The audit query "how many inline-prompt calls happened" lets the studio measure progress toward registry-coverage = 100%.

**Refine-pass clarification (load-bearing):**
- The audit emit is **tuple-only** — never the rendered prompt body, never the completion text, never the substituted parameter values. The audit payload carries identifiers, versions, and hashes; the bodies live in the `HoneyDrunk.Prompts` repo at the indicated version (forensic reconstruction resolves there).
- **No new `AuditCategory` enum value.** Use the existing `AgentAction` (agent-originated calls) and `Integration` (non-agent-originated calls) categories with the prompt-tuple metadata as the per-call detail.

**ADR-0030 (referenced) — Audit substrate.** Phase-1 stance is append-only-by-interface; the `IAuditLog.AppendAsync(AuditEntry)` contract is the durable channel. Event-name discipline is enforced by documentation in Phase 1 (no typed registry).

**ADR-0049 (referenced) — Data classification taxonomy.** Substituted parameter values may carry `Restricted` or `Confidential` tier content; that is the reason the tuple-only rule exists.

**Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry.** Extended here to audit entries: provider API keys, signing secrets, and any other secret material per the secrets-in-Vault rule never appear in any field of an `LlmCall` audit entry. Non-secret operator-visible strings (`model_id`, `provider`) are acceptable.

**Invariant `{N1}` (ADR-0064, landed by packet 01)** — full text:
> Every `IChatClient` and `IEmbeddingGenerator` call records to `IAuditLog` (per the audit substrate) a structured payload containing `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash, bypassed_registry?)`. … The payload contains only the tuple — never the rendered prompt body, never the completion text, never the substituted parameter values.

## Constraints
- **No code change.** This packet only documents canonical event-name + category-selection rule + metadata-key shape; no contract or runtime change.
- **No `AuditCategory` enum modification.** The two-category split (`AgentAction` / `Integration`) is the discriminator. Do not invent an `Inference` category — the refine-pass call-out is explicit.
- **Tuple-only payload is non-negotiable.** No rendered body, no completion, no substituted parameter values in the audit payload. The rule is in the invariant text from packet 01; reiterate it in the catalog section verbatim.
- **No `[Unreleased]` CHANGELOG.** Per the user's standing convention, move directly to a dated version section. PATCH-bump or append-to-most-recent-dated-entry per the repo's existing convention.
- **No secret values in any field.** Invariant 8 applies; the catalog explicitly states this.
- **No emit-side code lands here.** This packet documents the shape; the AI-sector emitter Nodes (Agents at GA; Operator, Memory, Knowledge, Evals, Lore as they ship) are the first Nodes that actually emit `LlmCall` events. The emitter-side wiring lands with each Node's first registry-aware feature packet, not in this initiative.

## Labels
`feature`, `tier-2`, `ai`, `docs`, `adr-0064`, `wave-2`

## Agent Handoff

**Objective:** Document the canonical shape of the `LlmCall` audit event in the `HoneyDrunk.Audit` repo — event-name, category-selection rule (`AgentAction` vs `Integration`, no new category), metadata-key shape, and the tuple-only payload rule — so AI-sector emitter Nodes emit the right entries.

**Target:** `HoneyDrunk.Audit`, branch from `main`.

**Context:**
- Goal: Pin the canonical event-name + category-selection rule + metadata-key shape for the ADR-0064 D5 LLM-call audit emit. No code change; documentation-only registration in the Audit repo.
- Feature: ADR-0064 Prompt and Persona Registry rollout, Wave 2.
- ADRs: ADR-0064 D5 (primary), ADR-0030 (audit substrate, referenced), ADR-0049 (data classification, referenced — the reason for tuple-only payload), ADR-0041 (model registry, referenced — the `model_id` metadata field).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0064 Accepted.
- `packet:01` — invariant `{N1}` live in `constitution/invariants.md` before the Audit catalog quotes it as a canonical rule.

**Constraints:**
- No code change. **No new `AuditCategory` value** — use the existing `AgentAction` and `Integration` categories. The refine-pass call-out is explicit on this point.
- The audit payload is **tuple-only** — never the rendered prompt body, never the completion text, never the substituted parameter values. Reiterate this in the catalog section.
- `[Unreleased]` is forbidden in `CHANGELOG.md`; use a dated version section.
- No secret material in any documented field; invariant 8 applies.
- Emitter-side code is not in this packet — AI-sector Nodes wire `LlmCall` emits in their own first registry-aware feature packets.

**Key Files:**
- `HoneyDrunk.Audit/README.md` (or `docs/event-catalog.md`) — the new `LLM-Call Audit Catalog` section.
- `HoneyDrunk.Audit/CHANGELOG.md` — documentation entry under a dated version.

**Contracts:** None changed. `IAuditLog` / `IAuditQuery` / `AuditEntry` / `AuditCategory` are unchanged.
