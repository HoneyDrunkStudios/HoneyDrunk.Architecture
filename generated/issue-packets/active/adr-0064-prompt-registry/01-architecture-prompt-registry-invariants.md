---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ai", "docs", "adr-0064", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0064"]
wave: 1
initiative: adr-0064-prompt-registry
node: honeydrunk-architecture
---

# Land the four ADR-0064 prompt-registry invariants and amend invariant 44

## Summary
Add the four new prompt-registry invariants ADR-0064 commits — the audit-emit-tuple rule (N1), the no-PII-in-prompt-files rule (N2), the no-inlined-prompt-body rule (N3), and the CI canary rule (N4) — to `constitution/invariants.md` at the numbers `{N1}, {N2}, {N3}, {N4}` reserved against ADR-0064 in `constitution/invariant-reservations.md`. In the **same commit**, apply the resolution of Required Decision 1 (the invariant 44 conflict) — packet 00's PR carries the human's A/B/C choice; this packet realizes the chosen resolution. After landing, move the ADR-0064 row in `invariant-reservations.md` from **Active Reservations** to **Reservation History** with the merge date. Governance-only packet; no code, no .NET project.

## Context
ADR-0064 Consequences / New Invariants commits four invariants. Each is a load-bearing rule that downstream code (the paired `HoneyDrunk.Prompts` standup ADR's Node scaffold, the AI-sector Nodes that consume `IPromptResolver`, the Audit Node's emit shape, the reviewer agent) references. Without the invariant text live in `constitution/invariants.md`, the rules cannot be quoted inline by downstream packets.

The four invariants ADR-0064 commits:

- **N1 (audit emit)** — every `IChatClient` / `IEmbeddingGenerator` call emits an `IAuditLog` entry recording `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash, bypassed_registry?)`. Bypass calls record `bypassed_registry: true` with null prompt fields; the emit itself is never optional. Source: D5.
- **N2 (no PII in files)** — no PII, no `Restricted`-tier content, no secret values inline in `HoneyDrunk.Prompts` files. PII enters via parameters at render time; secrets stay in Vault; CI gate enforces. Source: D10.
- **N3 (no inlined prompt bodies)** — application code must never inline a persona's or prompt's body text as a string literal when the registry has an entry for it; new code paths resolve through `IPromptResolver`; one-off bypasses are recorded in audit per N1. Source: D2 / D11. **This is the invariant that conflicts with invariant 44's current text** — see Required Decision 1 in packet 00, and the amendment in §Proposed Implementation below.
- **N4 (CI canary)** — the `HoneyDrunk.Prompts` package's CI must include a contract-shape canary on `IPromptResolver` and a content-shape canary asserting every prompt file's frontmatter parses and every body's `{{ parameter }}` placeholders match the declared parameters list. Source: D11 / D9.

This packet also applies the resolution of Required Decision 1 (packet 00's PR captures the human's choice). The recommended choice is Resolution B (restate invariant 44 narrowly), but A or C is acceptable. The chosen text lands in the same commit as the four new N1–N4 invariants so the constitution is internally consistent at every commit boundary.

This is a docs/governance packet. No code, no workflow, no .NET project.

## Scope
- `constitution/invariants.md` — add four new invariants at numbers `{N1}, {N2}, {N3}, {N4}` (resolved from the ADR-0064 row in `constitution/invariant-reservations.md`); amend invariant 44 per the chosen resolution; do not renumber any existing invariant.
- `constitution/invariant-reservations.md` — move the ADR-0064 row from **Active Reservations** to **Reservation History** with the merge date.

## Proposed Implementation

### Step 0 — Resolve `{N1}/{N2}/{N3}/{N4}` from the reservation file

Open `constitution/invariant-reservations.md`. Find the ADR-0064 row in the **Active Reservations** table (claimed by packet 00; the current state of the file claims `74–77`). The row gives a contiguous 4-number block. `{N1}` is the first, `{N2}` the second, `{N3}` the third, `{N4}` the fourth.

If, at execution time, the reservation row has been shifted upward due to a merge race with another ADR (per the file's collision-resolution procedure), use the shifted numbers and update every placeholder in this packet body and in packets 03 and 04 in the same commit.

Do **not** invent numbers from memory — read the file each time.

### Step 1 — Add the four invariants to `constitution/invariants.md`

`constitution/invariants.md` is **topic-grouped, not contiguously numbered.** Scan the whole file before placement; do not append all four at the end. Suggested groupings:

- **`{N1}` (audit emit tuple, D5)** — append to the **Audit Invariants** group (alongside invariants 47–49). The audit-emit-tuple rule is structurally an extension of invariant 47's "durable, attributable security, action, and data-change events are emitted to the HoneyDrunk.Audit substrate via `IAuditLog`" — N1 names the specific tuple shape for LLM-call events. Verify the section heading at edit time.
- **`{N2}` (no PII in prompt files, D10)** — this is a data-classification rule. If a **Data Classification Invariants** section exists (it may have landed via ADR-0049's reservation between this initiative's authoring and execution time), append there. If not, place it adjacent to invariant 8 (`Secret values never appear in logs, traces, exceptions, or telemetry`) in the Secrets & Trust Invariants group — N2 is the prompt-source-file analog of invariant 8 extended to public-repo source-file artifacts.
- **`{N3}` (no inlined prompt bodies, D2 / D11)** — append to the **AI Invariants** group (alongside invariants 28, 29, 30, 44, 45, 46). N3 is the prompt-text analog of invariant 28's "application code must never hardcode a model name or provider" — the same shape, the same forcing-function logic, for prompt text instead of model identifiers.
- **`{N4}` (contract + content canary, D11 / D9)** — append to the AI Invariants group, adjacent to invariants 43 (Communications canary) and 46 (HoneyDrunk.AI canary) which it structurally mirrors. The canary obligation is the same as those two — keep the gate, do not pin a specific implementation file.

Invariant texts (substance-verbatim — the body is what gets quoted inline by downstream packets per the issue-authoring rule "implementation constraints include invariant text … avoid number-only references"):

#### `{N1}` — Every LLM call emits an audit entry recording the prompt tuple

> Every `IChatClient` and `IEmbeddingGenerator` call records to `IAuditLog` (per the audit substrate) a structured payload containing `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash, bypassed_registry?)`. `persona_id` / `persona_version` / `persona_hash` are `null` when no persona is composed; `prompt_id` / `prompt_version` / `prompt_hash` are `null` when the call composed no template (raw user message only). Calls that bypass the registry (a one-off inline raw-system-message call) record `bypassed_registry: true` with null prompt fields; the audit emit itself is **never optional**. The payload contains only the tuple — never the rendered prompt body, never the completion text, never the substituted parameter values. See ADR-0064 D5.

#### `{N2}` — No PII, no Restricted-tier content, no secret values appear inline in `HoneyDrunk.Prompts` files

> Prompt and persona files in the `HoneyDrunk.Prompts` repo are **public-or-internal text artifacts**. No `Restricted`-tier content per the data-classification taxonomy, no PII-bearing values, and no secret values appear inline in any prompt or persona file body or frontmatter. Tenant-scoped data, PII, customer records, and any classified payload enter the LLM call at **render time, via parameters** — the prompt file declares `{{ parameter_name }}` placeholders; the runtime substitutes the actual value at call time; the file never carries the value itself. Secrets stay in Vault and resolve through `ISecretStore`, never inlined into prompt text. CI gate enforces: any file with `classification: Restricted` in frontmatter, or any secret-scan pattern match in any file body, fails the `HoneyDrunk.Prompts` build. See ADR-0064 D10.

#### `{N3}` — Application code must never inline a persona's or prompt's body text as a string literal when the registry has an entry for it

> When the `HoneyDrunk.Prompts` registry has an entry for a persona or prompt, application code must resolve it through `IPromptResolver` and never inline the body text as a string literal. New code paths consume the registry; one-off bypasses (a developer experiment, a one-shot operator diagnostic prompt) are not forbidden but are recorded in audit per the prompt-tuple invariant (`bypassed_registry: true`) so the studio can measure progress toward registry-coverage = 100%. This is the prompt-text analog of the rule that forbids inlining model names: a Grid-wide primitive should be sourced from one place, not duplicated across N Nodes. See ADR-0064 D2 / D11.

#### `{N4}` — `HoneyDrunk.Prompts` CI must include a contract-shape canary and a content-shape canary

> The `HoneyDrunk.Prompts` package's CI must include (a) a contract-shape canary on `IPromptResolver` that fails the build on shape drift to the interface or its supporting record types (`PersonaId`, `PromptId`, `PersonaContent`, `PromptContent`, `ResolvedMessages`) without a corresponding version bump, and (b) a content-shape canary asserting every prompt file's YAML frontmatter parses cleanly and every body's `{{ parameter }}` placeholders match the file's declared `parameters` list. Shape drift on the contract surface or content drift in the files is a build failure unless paired with an intentional version bump. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Prompts.Abstractions` plus a content-parse step; the obligation is to keep both gates, not to use any specific implementation. See ADR-0064 D11 / D9.

### Step 2 — Apply the chosen resolution of Required Decision 1 (invariant 44 amendment)

Packet 00's PR description carries the human's A/B/C choice for Required Decision 1. The current text of invariant 44 is (verbatim):

> Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`. Composition against `HoneyDrunk.AI` and any `HoneyDrunk.AI.Providers.*` package is a host-time concern resolved at application startup from App Configuration. This is the same abstraction/runtime split applied for Vault and Transport, restated here because it is the specific rule that allows blocked AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) to proceed on `Abstractions` alone without waiting for provider packages. See ADR-0016 D9.

Apply the chosen resolution in the same commit as the four new invariants:

**Resolution A — amend invariant 44 to permit prompt-registry coupling.** Replace the first sentence with:
> Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions` and (per ADR-0064 D11) `HoneyDrunk.Prompts.Abstractions`.

**Resolution B (recommended) — restate invariant 44 narrowly.** Replace the first sentence with:
> Downstream AI-sector Nodes take a runtime dependency on `HoneyDrunk.AI.Abstractions` and no `HoneyDrunk.AI.Providers.*` package directly.

Optionally append a clarifying sentence: "Sibling AI-sector contracts (e.g., `HoneyDrunk.Prompts.Abstractions` per ADR-0064 D11) are permitted; the rule targets AI-provider coupling specifically."

**Resolution C — carve out by addition.** Leave invariant 44's text unchanged. Add a new invariant adjacent to N3 in the AI Invariants group with text:
> Downstream AI-sector Nodes may take a runtime dependency on `HoneyDrunk.Prompts.Abstractions` per ADR-0064 D11. This is an explicit exception to invariant 44's "only `HoneyDrunk.AI.Abstractions`" rule — the Prompts contract is a sibling AI-sector primitive, not an AI-provider, and the host-time composition rule does not apply.

If Resolution C is chosen, the carve-out invariant gets the next free number after `{N4}` — i.e., `{N4}+1`. **In that case** the ADR-0064 reservation row must be widened from 4 to 5 numbers; coordinate with `constitution/invariant-reservations.md` and shift any downstream ADR's reservation upward by one in the same commit per the file's collision-shift procedure. (This is operationally heavier than A or B; it is the reason A and B are preferred and B is recommended.)

### Step 3 — Consume the reservation

In `constitution/invariant-reservations.md`, move the ADR-0064 row from **Active Reservations** to **Reservation History** with the merge date (per the file's "When a reservation is consumed" procedure). The reservation is "consumed" the moment the invariants land in `invariants.md`.

## Affected Files
- `constitution/invariants.md` — four new invariants at `{N1}/{N2}/{N3}/{N4}`; invariant 44 amendment per the chosen resolution; (optional `{N4}+1` carve-out if Resolution C).
- `constitution/invariant-reservations.md` — move ADR-0064 row from **Active Reservations** to **Reservation History**; if Resolution C, widen the row to 5 numbers and shift downstream reservations.

## NuGet Dependencies
None. Markdown-only packet.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] Governance-only — no runtime impact, no canary required.

## Acceptance Criteria
- [ ] `constitution/invariants.md` carries four new invariants at the numbers resolved from the ADR-0064 row in `constitution/invariant-reservations.md`, each citing ADR-0064 by D-letter
- [ ] `{N1}` is placed in the Audit Invariants group; full text as quoted in §Proposed Implementation Step 1
- [ ] `{N2}` is placed in a Data Classification Invariants section (if it exists) or adjacent to invariant 8; full text as quoted
- [ ] `{N3}` is placed in the AI Invariants group adjacent to invariant 28; full text as quoted
- [ ] `{N4}` is placed in the AI Invariants group adjacent to invariants 43 / 46; full text as quoted
- [ ] Invariant 44 is amended per the chosen resolution (A / B / C), or (Resolution C only) a new carve-out invariant lands at `{N4}+1` and the ADR-0064 reservation row is widened to 5 numbers
- [ ] The full text of each invariant is included, not a placeholder or stub
- [ ] No existing invariant (other than 44 per the chosen resolution) is renumbered or rewritten
- [ ] `constitution/invariant-reservations.md` has had the ADR-0064 row moved from **Active Reservations** to **Reservation History** with the merge date
- [ ] If Resolution C was chosen, any downstream ADR reservation in the file that needs to shift upward by one is shifted in the same commit
- [ ] No ADR status edit in this packet — packet 00 already flipped ADR-0064

## Human Prerequisites
- [ ] Required Decision 1 (invariant 44 conflict) resolved in packet 00's PR before this packet executes — without a chosen A/B/C, this packet is blocked.

## Referenced ADR Decisions
**ADR-0064 D5 — Audit emit (N1 source).** Every `IChatClient` and `IEmbeddingGenerator` call records `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash)` plus a `bypassed_registry?` flag. The tuple is required on every LLM-call audit emit. Calls that bypass the registry record `bypassed_registry: true` with null prompt fields — bypassed-registry calls are operationally legitimate but the audit emit is not optional. **Payload is tuple-only** — never the rendered prompt body, never the completion text, never the substituted parameter values (per the refine-pass clarification).

**ADR-0064 D10 — PII and sensitive content (N2 source).** Prompts and personas are public-or-internal text artifacts. Per ADR-0049, no `Restricted`-tier or PII-bearing value may appear inline in a prompt or persona file. Tenant-scoped data, PII, customer records, and any classified payload enter the LLM call at render time, via parameters. CI gate enforces: scans every file's frontmatter for `classification: Restricted` (forbidden) and runs the secret-scan pipeline on every file body. Tier names per ADR-0049 D1 are `Public / Internal / Confidential / Restricted` — `Sensitive` is a PII *sub-classification* under ADR-0049 D2, not a top-level tier.

**ADR-0064 D2 / D11 — No inlined prompt bodies (N3 source).** When the registry has an entry, application code must resolve through `IPromptResolver`, not inline the body as a string literal. The prompt-text analog of invariant 28's model-name rule. One-off bypasses record in audit per N1.

**ADR-0064 D11 / D9 — Canaries (N4 source).** Contract-shape canary on `IPromptResolver` and the record types. Content-shape canary asserting every prompt file's frontmatter parses and every body's `{{ parameter }}` placeholders match the declared `parameters` list. Shape or content drift is a build failure unless paired with an intentional version bump.

**Invariant 44 (current text) — see Required Decision 1 in packet 00.** N3 forces a resolution to A / B / C. This packet applies the chosen resolution.

**ADR-0049 D1 — Classification taxonomy.** Four tiers: `Public`, `Internal`, `Confidential`, `Restricted`. Higher-tier datum can always be handled at a higher tier; the converse is a boundary violation. When classification is unclear, default to `Restricted`.

## Constraints
- **Invariant numbers come from `constitution/invariant-reservations.md`, not from this packet.** Read the file at execution time. The current ADR-0064 row claims `74–77`; if a merge race has shifted the row, use the shifted numbers and update every placeholder in this packet, packet 03, and packet 04 in the same commit.
- **Topic-grouped placement.** The file is topic-grouped, not contiguously numbered. Place each invariant in its appropriate group — do not append all four at the end.
- **Full invariant text, not a number-only reference.** Each invariant's body must contain the full text so downstream packets can quote it inline (per the issue-authoring rule "implementation constraints include invariant text … avoid number-only references in constraint sections").
- **The invariant 44 amendment is non-optional.** N3's introduction of `HoneyDrunk.Prompts.Abstractions` as a downstream AI-sector dependency conflicts with the current text of invariant 44; the conflict must be resolved at the same commit as N3 lands. The recommended path is Resolution B; A or C is acceptable if the user picks it in packet 00's PR.
- **Tier names are `Public / Internal / Confidential / Restricted`.** Do not use `Sensitive` as a tier — that is a PII sub-classification under ADR-0049 D2, not a top-level tier. N2's text uses `Restricted` (the relevant top-level tier).
- **The audit emit is tuple-only.** N1's text explicitly excludes rendered prompt body, completion text, and substituted parameter values from the audit payload. Do not soften this — the rule exists because prompt bodies can be multi-kilobyte and substituted parameters may carry PII per N2.
- **Consume the reservation.** Once the four (or five, if Resolution C) invariants land, move the ADR-0064 row from **Active Reservations** to **Reservation History** in `invariant-reservations.md` with the merge date.
- **No status flip.** ADR-0064's `Status:` header stays `Accepted` (flipped by packet 00). No re-edit here.

## Labels
`chore`, `tier-3`, `ai`, `docs`, `adr-0064`, `wave-1`

## Agent Handoff

**Objective:** Land the four new prompt-registry invariants in `constitution/invariants.md` at the numbers reserved against ADR-0064, and apply the chosen resolution of Required Decision 1 (invariant 44 amendment) in the same commit. Consume the reservation by moving the row to history.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the four prompt-registry invariants live before any downstream packet (Audit emit docs, scope/review agent checklists, paired-standup-ADR specification) quotes them inline.
- Feature: ADR-0064 Prompt and Persona Registry rollout, Wave 1.
- ADRs: ADR-0064 D5 / D10 / D2 / D11 / D9 (primary), ADR-0049 D1 / D2 (classification taxonomy), ADR-0035 D1 (abstractions versioning — referenced by D3 of ADR-0064 and N4).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0064 Accepted, initiative registered, Required Decision 1 resolved in the PR description.

**Constraints:**
- Use the numbers in `constitution/invariant-reservations.md`'s ADR-0064 row at execution time — read, don't assume.
- Place each invariant in its topic group, not at the end of the file.
- Include the full invariant text for each.
- Apply the chosen resolution (A / B / C) of Required Decision 1 in the same commit. Recommended: Resolution B.
- Tier names per ADR-0049 D1 are `Public / Internal / Confidential / Restricted` — `Sensitive` is a PII sub-classification, not a tier.
- Audit emit (N1) is tuple-only. No body text, no completion text, no substituted parameter values in the payload.
- Consume the reservation by moving the row from Active to History.

**Key Files:**
- `constitution/invariants.md` — four new invariants in their topic groups + invariant 44 amendment.
- `constitution/invariant-reservations.md` — move the ADR-0064 row to **Reservation History**.

**Contracts:** None changed. Governance only.
