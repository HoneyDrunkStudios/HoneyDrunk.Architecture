---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "ai", "docs", "adr-0064", "wave-1"]
dependencies: []
adrs: ["ADR-0064"]
accepts: ["ADR-0064"]
wave: 1
initiative: adr-0064-prompt-registry
node: honeydrunk-architecture
---

# Accept ADR-0064 — flip status, claim invariant block {N1}–{N4}, register the initiative

## Summary
Flip ADR-0064 (Prompt and Persona Registry with Versioning) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, register the `adr-0064-prompt-registry` initiative in `initiatives/active-initiatives.md`, and confirm the 4-invariant reservation block `{N1}–{N4}` for ADR-0064 in `constitution/invariant-reservations.md` (the reservation row may already exist from a prior reservation-batching PR — verify, and either add or leave-in-place). Surface two **Required Decisions** in the body for resolution before downstream packets land: (a) the N3 / invariant-44 conflict (introducing `HoneyDrunk.Prompts.Abstractions` as a new AI-sector dependency); and (b) whether the paired `HoneyDrunk.Prompts` standup ADR is filed inside this initiative's filing window or as a separate sibling track.

## Context
ADR-0064 commits the prompt-and-persona registry policy — what gets stored, how it versions, the runtime resolution rule, the Audit emit contract, the Evals integration shape, the Honeyclaw posture, the PDR-app pattern, the on-disk schema, the PII rule, and the loader location. The Node shape itself (repo layout, solution structure, CI pipeline, scaffolding) is intentionally deferred to a paired standup ADR (D12) following the precedent set by the ADR-0058 / ADR-0059 pair.

ADR-0064 is a **policy** ADR: it decides *what the rules are* and *what the contract surface will be*; it does not stand up the `HoneyDrunk.Prompts` repo, write the contract code, or land catalog edges into the relationships graph. Those moves arrive with the paired standup ADR.

The ADR decides (summary, D-letter granularity):

- **D1** — storage is a dedicated public repo `HoneyDrunk.Prompts`, text files with YAML frontmatter, distributed as a NuGet package (content + small loader runtime). Alternatives explicitly rejected: App Configuration values; database-table-with-hash; per-Node inlining.
- **D2** — two file kinds: **Persona** (stable, named identity; `system_prompt` body; long lifecycle; few in total) and **Prompt** (task-specific template with `{{ parameter }}` placeholders; short lifecycle; many in total; optionally `extends` a persona). Uniform on-disk schema; `kind:` frontmatter discriminates.
- **D3** — semver on the **package as a whole**, not per file. Major = persona/prompt id removal, parameter required/optional flip, persona `extends` rewrite. Minor = additive (new persona/prompt, new optional parameter) **and body rewrites** (body change is significant model behavior, not interface break). Patch = frontmatter-metadata-only changes. Every file's body+normalized-frontmatter is SHA-256 content-hashed at package build; both the semver version and the hash flow into the audit emit (D5).
- **D4** — runtime resolution is **snapshot at deploy time**, no hot-reload. The prompt set live in production at any moment is the set baked into the deployed Node binary. Hot-reload (Vault-style Event Grid pattern) explicitly rejected — Evals coverage diverges from production behavior if prompts hot-swap.
- **D5** — every `IChatClient` / `IEmbeddingGenerator` call records `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash, bypassed_registry?)` to `IAuditLog`. Bypass-registry calls record `bypassed_registry: true` with null prompt fields; the emit itself is never optional.
- **D6** — Evals integration: a run identifier captures `ModelId`, the `(prompt_id, prompt_version, prompt_hash)` tuple, and the persona tuple if composed. **Equality key for "same prompt" is the hash**, not the version. Two package versions with the same prompt hash are the same text; Evals does not re-score.
- **D7** — Honeyclaw integration: the Grid `HoneyDrunk.Prompts` repo is the **source of truth** for the bear-keeper persona even though Honeyclaw runs in third-party OpenClaw infrastructure. A build/release-step exporter (in `HoneyDrunk.Prompts` or a paired `HoneyDrunk.OpenClaw` integration package — exact location deferred to the standup ADR) pushes the persona to OpenClaw's configured location at each prompts package release. **No runtime HTTP call** from OpenClaw into the Grid.
- **D8** — PDR-app personas register in `HoneyDrunk.Prompts` at the app's first AI-enabled feature packet, not later. The app's release is gated on the prompts package's release that includes them.
- **D9** — on-disk schema: YAML frontmatter + Markdown/text body. Paths `personas/{id}.persona.md` and `prompts/{owner-node}/{id}.prompt.md`. The `id` field in frontmatter is the **lookup key** (path is for human navigation only). Frontmatter fields: `id`, `kind`, `version`, `extends` (prompts only, optional), `parameters` (prompts only), `model_compatibility` (optional), `owner`, `classification` (Public / Internal / Confidential — Restricted forbidden per D10), `created`, `notes`. Placeholders use double-brace `{{ parameter_name }}` Mustache-style — distinct from C# interpolation, Python f-strings, and other capture-prone formats.
- **D10** — prompt/persona files are **public-or-internal-tier text artifacts**. No PII, no Restricted-tier content, no secret values inline. PII enters via parameters at render time; secrets stay in Vault. Two-tier enforcement: CI gate in `HoneyDrunk.Prompts` (scan for `classification: Restricted` and run secret-scan); reviewer-agent rule per ADR-0044.
- **D11** — loader `IPromptResolver` lives in `HoneyDrunk.Prompts.Abstractions`; default impl in `HoneyDrunk.Prompts`. `PersonaId`, `PromptId` are records (no `I` prefix per the naming rule); `PersonaContent`, `PromptContent`, `ResolvedMessages` are records carrying body + hash + version + metadata. `Compose(promptId, personaId, parameters)` is the hot path. `HoneyDrunk.Prompts.Tests.Fakes` provides `InMemoryPromptResolver`.
- **D12** — paired `HoneyDrunk.Prompts` standup ADR follows immediately (precedent: ADR-0058 policy + ADR-0059 standup). This ADR is the policy; the standup ADR is the Node shape.

The ADR also commits four new invariants (Consequences / New Invariants) — claimed at `{N1}–{N4}` per `constitution/invariant-reservations.md`. Packet 01 of this initiative writes them to `constitution/invariants.md`.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Required Decisions (surface in PR description, resolve before downstream packets)

The reservation row for ADR-0064 in `constitution/invariant-reservations.md` already calls out a Required Decision; this packet re-surfaces it as a board-visible item for human resolution.

### Required Decision 1 — invariant 44 conflict

Invariant 44 reads in full:

> Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`. Composition against `HoneyDrunk.AI` and any `HoneyDrunk.AI.Providers.*` package is a host-time concern resolved at application startup from App Configuration. This is the same abstraction/runtime split applied for Vault and Transport, restated here because it is the specific rule that allows blocked AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) to proceed on `Abstractions` alone without waiting for provider packages. See ADR-0016 D9.

ADR-0064 N3 (the third invariant ADR-0064 commits) reads in full:

> Application code must never inline a persona's or prompt's body text as a string literal when the registry has an entry for it. New code paths resolve through `IPromptResolver`; one-off bypasses are recorded in audit per the prior invariant.

Resolving N3 to be live requires AI-sector Nodes (Agents, Operator, Memory, Knowledge, Evals, Lore) to take a runtime dependency on `HoneyDrunk.Prompts.Abstractions`. Invariant 44 in its current text reads as restricting downstream AI-sector runtime dependencies to `HoneyDrunk.AI.Abstractions`. Three resolution paths:

- **Resolution A — amend invariant 44 to permit prompt-registry coupling.** Add an explicit exception: "Downstream AI-sector Nodes may also depend on `HoneyDrunk.Prompts.Abstractions` per ADR-0064 D11." Cleanest in narrative terms; preserves invariant 44's blocking-proceed property for AI-provider concerns.
- **Resolution B — restate invariant 44 narrowly.** Change "Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`" to "Downstream AI-sector Nodes take a runtime dependency on `HoneyDrunk.AI.Abstractions` and no `HoneyDrunk.AI.Providers.*` package." The original intent (no AI-provider lock-in at the consumer site) is preserved; the over-broad "only" is dropped.
- **Resolution C — carve out by addition.** Leave invariant 44 alone, add a new invariant alongside N3 that explicitly permits `HoneyDrunk.Prompts.Abstractions` as a permitted AI-sector cross-dependency. Heaviest constitution surface.

**Recommendation (defer to user at acceptance time):** Resolution B. The original ADR-0016 D9 reasoning is "no AI-provider lock-in"; `HoneyDrunk.Prompts.Abstractions` is not an AI provider, it is a sibling AI-sector contract. Restating the invariant narrowly captures the intent without amendment-by-exception.

**Action:** the executor of packet 01 chooses A/B/C and applies the chosen text in the same commit as the four new N1–N4 invariants. If the user has not picked at acceptance time, this packet's PR description carries the open question and packet 01 is blocked on resolution.

### Required Decision 2 — paired `HoneyDrunk.Prompts` standup ADR filing posture

ADR-0064 D12 explicitly defers the Node-shape decisions (repo creation, solution layout, CI pipeline, scaffolding, the contract-shape canary on `IPromptResolver`, context folder, catalog entries) to a paired standup ADR. ADR-0064 names "the next available ADR number after the Aspire ADR that ships in the same wave" as the standup ADR's slot — but two postures are possible:

- **Posture A — file the standup ADR draft now**, in this initiative's filing window, by the adr-composer agent. The standup ADR is filed as a fresh Proposed ADR; a sibling `adr-{N}-prompts-standup` initiative is created for it; this initiative's packet 05 (handoff specification) is the handshake from policy to standup.
- **Posture B — defer the standup ADR draft until after ADR-0064 is Accepted on `main`**. The standup ADR is drafted by the adr-composer agent in a subsequent wave; this initiative's packet 05 is the spec that the standup ADR's adr-composer reads as input.

Either posture is acceptable. The packets in this initiative are **identical under both postures** — no packet here writes Node-shape code or scaffolds `HoneyDrunk.Prompts`. Packet 05 is the handoff document regardless; what changes is whether the sibling initiative folder exists by the time this initiative completes.

**Recommendation:** Posture B. Keeping the policy ADR landed on `main` before drafting the standup ADR matches the ADR-0058 / ADR-0059 cadence (ADR-0058 went Accepted before ADR-0059's standup packets landed). It also keeps this initiative's filing surface small and reduces the chance of races between the two adr-composer drafts.

**Action:** if the user chooses Posture A at acceptance time, an additional task is created outside this initiative: invoke the adr-composer agent against "stand up `HoneyDrunk.Prompts` per ADR-0064 D12." If Posture B, the same task is filed as a follow-up after ADR-0064 reaches Accepted state.

## Scope
- `adrs/ADR-0064-prompt-and-persona-registry-with-versioning.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — update the ADR-0064 row Status column to Accepted.
- `initiatives/active-initiatives.md` — register the `adr-0064-prompt-registry` initiative under `## In Progress` with the wave structure and packet checklist for this folder, matching the entry shape used by sibling ADR initiatives (`adr-0058-caching-strategy`, `adr-0067-rate-limiting`).
- `constitution/invariant-reservations.md` — verify the existing ADR-0064 row at `{N1}–{N4}` is correct (the row already exists per the reservations file). If a collision shift is needed (another ADR raced), update the row in this packet per the file's "How a collision is resolved at merge time" procedure. If no shift is needed, this packet does **not** rewrite the row.
- `constitution/invariants.md` — **NOT modified.** Invariants land via packet 01.

## Proposed Implementation
1. Edit the ADR-0064 header: `**Status:** Proposed` → `**Status:** Accepted`. Leave every other line of the ADR text unchanged.
2. Update the ADR-0064 index row in `adrs/README.md` to `Accepted`.
3. Register the initiative in `initiatives/active-initiatives.md` under `## In Progress`. Sample shape (adapt to the file's current style):

   ```markdown
   ### ADR-0064 Prompt and Persona Registry with Versioning
   **Status:** In Progress
   **Scope:** Architecture (policy + invariants + catalog + agent checklists + handoff to paired Prompts standup ADR)
   **Initiative:** `adr-0064-prompt-registry`
   **Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
   **Description:** Land the ADR-0064 policy on the registry shape, audit emit contract, on-disk schema, PII rule, and loader location. Four new invariants (`{N1}/{N2}/{N3}/{N4}` claimed in `constitution/invariant-reservations.md`). The paired `HoneyDrunk.Prompts` standup ADR (D12) is filed as a separate sibling track per Required Decision 2.

   **Tracking (Wave 1 — governance):**
   - [ ] Architecture: Accept ADR-0064 + reservation row + initiative registration (packet 00)
   - [ ] Architecture: Four prompt-registry invariants `{N1}/{N2}/{N3}/{N4}` + invariant 44 narrowing (packet 01)
   - [ ] Architecture: AI sector + ai-sector-architecture.md updates (packet 02)

   **Tracking (Wave 2 — downstream artifacts):**
   - [ ] Audit: prompt-tuple metadata-key documentation under existing AgentAction / Integration categories (packet 03)
   - [ ] Architecture: scope.md + review.md prompt-registry checklist (packet 04)
   - [ ] Architecture: Handoff specification for the paired HoneyDrunk.Prompts standup ADR (packet 05)

   **Exit criteria:** ADR-0064 status flip done in packet 00; four invariants live in `constitution/invariants.md`; AI sector table records the Prompts Node placeholder; Audit emit contract documented at canonical metadata-key shape; agent checklists updated; standup handoff spec authored. The paired `HoneyDrunk.Prompts` standup ADR's acceptance and the Node scaffold are out of scope of this initiative.
   ```

4. **`constitution/invariant-reservations.md`** — verify the ADR-0064 row (range `74–77` per the current state of the file) is correct. The row already exists; it claims the 4-invariant block and explicitly calls out the invariant 44 conflict as a Required Decision. If, at execution time, another ADR (e.g., ADR-0065 or ADR-0066) has already won a merge race and shifted the available range, follow the file's "How a collision is resolved at merge time" procedure: shift this ADR's range upward to the next free quadruple, update the row, and update every `{N1}/{N2}/{N3}/{N4}` placeholder in packets 01, 03, and 04 to the new numbers in the same commit.

5. Do **NOT** modify `constitution/invariants.md` — packet 01 lands the four invariants and the invariant 44 amendment (per Required Decision 1).

6. Do **NOT** modify `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/grid-health.json`, `catalogs/modules.json`, `catalogs/contracts.json`, or `repos/HoneyDrunk.Prompts/`. Those catalog and repo-folder edits belong to the paired `HoneyDrunk.Prompts` standup ADR (D12), not to this policy initiative. The sectors.md + ai-sector-architecture.md edits (which are policy-level, not Node-shape) land in packet 02.

## Affected Files
- `adrs/ADR-0064-prompt-and-persona-registry-with-versioning.md` — header `Proposed` → `Accepted`.
- `adrs/README.md` — index row.
- `initiatives/active-initiatives.md` — new initiative entry.
- `constitution/invariant-reservations.md` — verify (no rewrite unless a collision shift is needed).

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency. No catalog edges added.
- [x] No `HoneyDrunk.Prompts` repo work in this packet (deferred to paired standup ADR).

## Acceptance Criteria
- [ ] ADR-0064 header reads `**Status:** Accepted`
- [ ] The ADR-0064 row in `adrs/README.md` reflects Accepted
- [ ] `initiatives/active-initiatives.md` registers the `adr-0064-prompt-registry` initiative with the packet checklist
- [ ] `constitution/invariant-reservations.md` ADR-0064 row is consistent (either unchanged because the existing `74–77` claim still holds, or shifted upward and updated in this commit per the file's collision procedure)
- [ ] `constitution/invariants.md` is **NOT** modified (invariants land in packet 01)
- [ ] `catalogs/*` is **NOT** modified (Node-shape catalog edits land with the paired standup ADR)
- [ ] `repos/HoneyDrunk.Prompts/` is **NOT** created (the repo standup belongs to the paired standup ADR)
- [ ] PR body surfaces Required Decision 1 (invariant 44 conflict — A/B/C choice) and Required Decision 2 (standup ADR filing posture — A/B choice) for human acknowledgement before packet 01 is unblocked

## Human Prerequisites
- [ ] Pick a resolution for Required Decision 1 (A — amend invariant 44 by exception; B — restate invariant 44 narrowly; C — carve out by addition). The choice gates packet 01's invariant-44 amendment.
- [ ] Pick a posture for Required Decision 2 (A — file the paired HoneyDrunk.Prompts standup ADR now via adr-composer; B — defer until after this initiative completes). The choice affects whether a sibling initiative folder is created in this filing window.

## Referenced ADR Decisions
**ADR-0064 D12 — paired standup ADR.** "This ADR commits the policy — what gets stored, how it versions, how runtime resolution works, the audit emit, the schema, the loader shape. The Node shape — repo layout, solution structure, CI pipeline, contract-shape canary, scaffold packet contents — is a separate paired standup ADR following the precedent set by the ADR-0058 / ADR-0059 pair. … Folding the standup into this ADR would set the wrong precedent — future policy ADRs would feel they have to standup their own Nodes inline. Keeping them paired is the right shape."

**ADR-0064 Consequences / New Invariants.** Four invariants commit at acceptance: (1) the audit-emit-tuple rule (N1); (2) the no-PII-in-prompt-files rule (N2); (3) the no-inlined-prompt-body rule (N3, the invariant-44 conflict source); (4) the contract-and-content-shape canary rule (N4). Final numbers assigned at the constitution update.

**Invariant 44** — full text in Required Decision 1 above.

## Constraints
- **Acceptance precedes implementation.** ADR-0064 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet of this initiative.
- **No invariant edits in this packet.** Invariants land in packet 01 (which also applies the invariant-44 amendment per Required Decision 1).
- **No catalog/relationships edits.** The Node-shape catalog edits in ADR-0064's "Catalog and Reference Updates Required" list belong to the paired `HoneyDrunk.Prompts` standup ADR's filing, not this initiative.
- **Exit criterion is on the standup-ADR side.** ADR-0064's deeper success criterion ("`HoneyDrunk.Prompts` repo stood up; first registry-aware feature packet lands through `IPromptResolver`") is satisfied across the paired-standup-ADR boundary, not within this initiative. This split mirrors ADR-0067's pattern of flipping Status at the start of its initiative because downstream packets need the decisions as live rules.
- **Self-containment of downstream packets.** Packets 01–05 inline the relevant ADR-0064 decisions and invariant text; an executor in any target repo reads the packet end-to-end and does not need to fetch the ADR file.

## Labels
`chore`, `tier-3`, `ai`, `docs`, `adr-0064`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0064 to Accepted, register the prompt-registry initiative, verify the `{N1}–{N4}` reservation row, and surface the two Required Decisions for human resolution. No invariant edits and no catalog edits in this packet.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0064 so the remaining packets in this initiative can reference its decisions (D1–D12) as live rules.
- Feature: ADR-0064 Prompt and Persona Registry with Versioning policy rollout, Wave 1.
- ADRs: ADR-0064 (primary); ADR-0030 (audit substrate — context for packet 03); ADR-0049 (data classification — context for D10 and packet 02); ADR-0044 (review-agent contract — context for packet 04); ADR-0035 (abstractions-versioning policy — referenced by D3).

**Acceptance Criteria:** As listed above.

**Dependencies:** None. This is the first packet in the initiative.

**Constraints:**
- ADR-0064 stays Proposed until this PR merges.
- No invariant edits — that is packet 01's job, and it includes the invariant-44 amendment per Required Decision 1.
- No catalog edits — Node-shape catalog edits belong to the paired `HoneyDrunk.Prompts` standup ADR (D12).
- The two Required Decisions are surfaced in the PR description, not silently resolved by the executor.

**Key Files:**
- `adrs/ADR-0064-prompt-and-persona-registry-with-versioning.md`
- `adrs/README.md`
- `initiatives/active-initiatives.md`
- `constitution/invariant-reservations.md` (verify only; rewrite only on collision shift)

**Contracts:** None changed. Catalog-level contract surfaces (`IPromptResolver`, `PersonaId`, `PromptId`, `PersonaContent`, `PromptContent`, `ResolvedMessages`) are registered with the paired `HoneyDrunk.Prompts` standup ADR's catalog packet, not here.
