---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "ai", "docs", "adr-0064", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0064"]
wave: 1
initiative: adr-0064-prompt-registry
node: honeydrunk-architecture
---

# Add the prompt-registry layer to constitution/sectors.md and ai-sector-architecture.md

## Summary
Record ADR-0064's commitment that prompts and personas are the **AI sector's identity substrate** (the same way Audit is Core's record substrate) in two governance documents: `constitution/sectors.md` gains a placeholder row in the AI sector table noting the planned `HoneyDrunk.Prompts` Node (Seed signal); `constitution/ai-sector-architecture.md` gains a new subsection describing the prompt-registry layer between AI inference and downstream consumers. The full Node entry (catalog rows in `nodes.json`, `relationships.json`, `modules.json`, `contracts.json`, `grid-health.json`) is deferred to the paired `HoneyDrunk.Prompts` standup ADR; this packet only carries the policy-level sector-table placeholder and the architecture document update so the AI-sector standup wave (Agents, Memory, Knowledge, Evals, Operator) reading these documents during their own feature work has the registry layer in front of them.

## Context
ADR-0064 D12 explicitly defers the Node-shape and catalog edits to the paired `HoneyDrunk.Prompts` standup ADR. But two updates are policy-level, not Node-shape, and belong with this initiative:

1. **`constitution/sectors.md`** — the AI sector table is a high-level sector taxonomy, not a Node-by-Node catalog. Adding a placeholder row for the planned `HoneyDrunk.Prompts` Node (Seed signal, "Prompt and persona registry — versioned content, audit-anchored, snapshot-at-deploy") signals to anyone reading the sector taxonomy that the registry is committed at the policy level even though the Node has not been stood up yet. The Cache Node row in this same table landed at ADR-0058 acceptance time before ADR-0059's standup PRs merged; this packet mirrors that pattern.
2. **`constitution/ai-sector-architecture.md`** — the AI sector's architecture document describes Node boundaries, dependency flow, and integration with the rest of the Grid. ADR-0064 commits a new layer (the prompt-registry layer) that sits between AI inference and every downstream consumer. The architecture document needs an update so future readers (and the AI-sector standup Nodes reading their own architecture spec) understand the layer's role.

Note: the **catalog edits** — `catalogs/nodes.json` (the `honeydrunk-prompts` entry), `catalogs/relationships.json` (the consumes/consumed-by edges), `catalogs/modules.json` (the three planned packages), `catalogs/contracts.json` (the `IPromptResolver` + record types), `catalogs/grid-health.json` (the Node row), and the `repos/HoneyDrunk.Prompts/` folder with `overview.md` / `boundaries.md` / `invariants.md` — **all land with the paired `HoneyDrunk.Prompts` standup ADR**, not this packet. That packet creates the Node; this packet only acknowledges its existence in the sector taxonomy and the AI-sector architecture document.

This is a docs/governance packet. No code, no .NET project.

## Scope
- `constitution/sectors.md` — append a placeholder row to the AI sector table for the planned `HoneyDrunk.Prompts` Node.
- `constitution/ai-sector-architecture.md` — add a new subsection describing the prompt-registry layer (its role, dependency direction, deferral to the paired standup ADR for Node shape).
- `catalogs/*` — **NOT modified** in this packet. The full Node row and edges land with the paired `HoneyDrunk.Prompts` standup ADR.
- `repos/HoneyDrunk.Prompts/` — **NOT created** in this packet. The repo folder lands with the paired standup ADR.

## Proposed Implementation

### Step 1 — `constitution/sectors.md`

Open the file and locate the **AI sector** subsection (around lines 86–105, but verify at edit time — the file may have shifted). The current AI sector table lists nine Nodes (Agents, AI, Memory, Knowledge, Evals, Capabilities, Flow, Operator, Sim), each as a `| Name | Signal | Responsibility |` row.

Append a new row at the end of the table, matching the existing formatting:

```markdown
| **Prompts** | Seed | Prompt and persona registry — versioned content, audit-anchored tuple emit, snapshot-at-deploy. Standup deferred to a paired standup ADR per the policy. |
```

The row uses `Prompts` (the public Node name, matching the convention used by sibling nodes in the table). The Signal is `Seed` because the Node is committed at the policy level but the standup ADR has not yet landed.

Do **not** modify the Dependency Flow diagram at the bottom of `sectors.md` ("Dependency Flow (Real Nodes)"). That diagram is for **Real Nodes** (Live or stood-up Seed); `HoneyDrunk.Prompts` is committed at policy level only at this packet's execution time. The diagram is updated when the paired standup ADR lands.

### Step 2 — `constitution/ai-sector-architecture.md`

Open the file. The document has a **Design Principles** section followed by per-Node **Node Definitions** sections (Agents, AI, Memory, Knowledge, Evals, Capabilities, Flow, Operator, Sim — verify the current Node list at edit time).

Add a new subsection at the end of the **Node Definitions** chain (after Sim's section) — or, if a "Cross-Cutting Layers" / "Substrate" / "Identity substrate" section exists, append there instead. The new subsection captures the prompt-registry layer at architecture level (not at Node-shape level):

```markdown
### HoneyDrunk.Prompts (planned — paired standup ADR)

**Node ID:** `honeydrunk-prompts` (catalog entry added with the paired standup ADR)
**Role:** Prompt and persona registry — the AI sector's identity substrate.

**Owns:**
- Versioned prompt and persona text artifacts (files on disk, frontmatter + body).
- The `IPromptResolver` contract (in `HoneyDrunk.Prompts.Abstractions`) for runtime resolution of personas, prompts, and parameter-substituted compositions.
- The content-hash discipline that anchors every Evals run identifier and every audit-tuple emit to byte-exact prompt text.
- The CI gates that forbid PII and Restricted-tier content inline and prevent shape drift on `IPromptResolver` without a version bump.

**Does not own:**
- Inference (that is `HoneyDrunk.AI`). The Prompts Node supplies prompt content; the AI Node executes the resulting `IChatClient` / `IEmbeddingGenerator` calls.
- Audit storage (that is `HoneyDrunk.Audit`). The Prompts Node's role in audit is to give every LLM call a stable `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash)` tuple that the call site emits via `IAuditLog`. The audit payload is tuple-only — no rendered prompt body, no completion text, no substituted parameter values.
- Evals scoring (that is `HoneyDrunk.Evals`). The Prompts Node's role in Evals is to give every run identifier a hash-anchored equality key for "same prompt or different."

**Dependency flow:**
- `HoneyDrunk.Prompts.Abstractions` — zero runtime dependencies on other Grid packages (only `Microsoft.Extensions.*` abstractions, per the abstractions-package invariant).
- `HoneyDrunk.Prompts` (default impl) — depends on `HoneyDrunk.Prompts.Abstractions` and Kernel primitives for lifecycle and DI.
- Every AI-sector consumer Node (Agents, Operator, Memory, Knowledge, Evals, Lore) takes a runtime dependency on `HoneyDrunk.Prompts.Abstractions`.
- Third-party agent gateways that run Grid-defined personas (e.g., OpenClaw running Honeyclaw) consume the persona via a build/release-step export. The Grid never runs as a runtime dependency of third-party agent infrastructure.

**Versioning:**
- Semver on the `HoneyDrunk.Prompts` package as a whole. Per-prompt versioning was considered and rejected — the audit-emit content hash captures per-file identity for forensic purposes without per-file semver overhead.
- Body rewrites are **minor** bumps (the body change is significant model behavior, not interface break). Removing a persona/prompt id, removing or renaming a parameter, or changing a prompt's `extends` is **major**.

**Runtime resolution:**
- Snapshot at deploy time, no hot-reload. The prompt set live in production is the set baked into the deployed Node binary. Hot-reload was considered and rejected — it desynchronizes production behavior from the Evals score that greenlit the release.

**Standup deferred** to the paired `HoneyDrunk.Prompts` standup ADR per the policy ADR's D12 decision. The standup ADR covers repo creation, solution layout, CI pipeline (including the contract-shape and content-shape canaries), the migration packet that seeds the bear-keeper persona and the Lore wiki-ingest prompt, and the catalog row entries.
```

Adapt the prose to match the document's existing tone if it differs noticeably — the file's existing Node sections have a consistent shape (Node ID, Role, Owns / Does not own, Dependency flow), so the new section follows that shape verbatim.

### Step 3 — Do NOT modify catalogs

- `catalogs/nodes.json` — no row added. The `honeydrunk-prompts` row is the paired standup ADR's responsibility.
- `catalogs/relationships.json` — no edges added.
- `catalogs/modules.json` — no entry added.
- `catalogs/contracts.json` — no `IPromptResolver` or record entries added.
- `catalogs/grid-health.json` — no row added.
- `repos/HoneyDrunk.Prompts/` — folder NOT created.

The rationale: the sector taxonomy and the architecture document are *policy* artifacts; the catalogs and the per-repo `repos/*` folder are *Node-shape* artifacts. ADR-0064 D12 splits these explicitly. The sector-table row and the architecture subsection acknowledge the Node's existence at policy level; the catalog rows land when the Node actually exists.

### Step 4 — Do NOT modify infrastructure/reference/tech-stack.md

`infrastructure/reference/tech-stack.md` carries Grid-wide cross-cutting platform choices. The prompt registry is not a cross-cutting *substrate* choice (no Azure service, no third-party library) — it is a Node. The tech-stack.md entry is added when the Node ships, with the paired standup ADR. Do not add an entry now.

## Affected Files
- `constitution/sectors.md` — new row in the AI sector table for the planned Prompts Node.
- `constitution/ai-sector-architecture.md` — new subsection describing the prompt-registry layer.

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No catalog or per-repo `repos/*` edits — those are paired-standup-ADR territory per ADR-0064 D12.
- [x] No new top-level Node-to-Node edge in catalog data.

## Acceptance Criteria
- [ ] `constitution/sectors.md` AI sector table carries a new `**Prompts** | Seed | …` row matching the existing row formatting
- [ ] The Dependency Flow diagram at the bottom of `sectors.md` is **NOT** modified (it tracks Real Nodes, not policy-level Seeds)
- [ ] `constitution/ai-sector-architecture.md` carries a new subsection (e.g., `### HoneyDrunk.Prompts (planned — paired standup ADR)`) describing the Node's role, owns / does not own, dependency flow, versioning, and runtime resolution
- [ ] The new subsection matches the document's existing per-Node section shape (Node ID, Role, Owns, Does not own, Dependency flow)
- [ ] `catalogs/nodes.json`, `catalogs/relationships.json`, `catalogs/modules.json`, `catalogs/contracts.json`, `catalogs/grid-health.json` are **NOT** modified
- [ ] `repos/HoneyDrunk.Prompts/` is **NOT** created
- [ ] `infrastructure/reference/tech-stack.md` is **NOT** modified
- [ ] The architecture-doc subsection's "Does not own" list explicitly excludes inference (AI's job), audit storage (Audit's job), and Evals scoring (Evals' job)
- [ ] The architecture-doc subsection states that the audit payload is **tuple-only** (no body / completion / substituted parameters), and that runtime resolution is **snapshot at deploy time, no hot-reload**
- [ ] No invariant edit in this packet (invariants land in packet 01)
- [ ] No ADR status edit in this packet (packet 00 already flipped ADR-0064)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0064 D1 — Storage.** Prompts and personas live in a dedicated public repo `HoneyDrunk.Prompts`, distributed as NuGet, content embedded + small loader runtime. The same pattern `HoneyDrunk.Standards` uses for shared analyzers — one repo, NuGet distribution, every consumer pulls the version they build against.

**ADR-0064 D2 — Persona vs Prompt.** Two kinds, one schema. Persona = stable named identity with `system_prompt` body. Prompt = task-specific template with `parameters` declaration, optionally `extends` a persona.

**ADR-0064 D4 — Runtime resolution.** Snapshot at deploy time, no hot-reload. The prompt set live in production at any moment is the set baked into the deployed Node binary.

**ADR-0064 D5 — Audit emit (tuple-only).** Every LLM call records `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash, bypassed_registry?)` to `IAuditLog`. The payload is tuple-only — no rendered prompt body, no completion text, no substituted parameter values.

**ADR-0064 D11 — Loader location.** `IPromptResolver` in `HoneyDrunk.Prompts.Abstractions`; default impl in `HoneyDrunk.Prompts`. `PersonaId`, `PromptId` are records (no `I` prefix per the naming rule). `PersonaContent`, `PromptContent`, `ResolvedMessages` are records carrying body + hash + version + metadata.

**ADR-0064 D12 — Paired standup ADR.** This ADR commits the policy; a paired standup ADR commits the Node shape (repo creation, solution layout, CI pipeline, scaffold packet, contract-shape canary, content folder, catalog entries). The split exists so the per-Node standup convention is preserved.

**ADR-0058 / ADR-0059 precedent.** The Cache Node was added to `constitution/sectors.md` at ADR-0058's acceptance time even though the Node was not yet stood up. This packet mirrors that pattern for the Prompts Node.

## Constraints
- **Sectors-table row only — no catalog row.** The AI sector table is a sector-taxonomy artifact, not a Node catalog. Adding the row signals policy-level commitment; the catalog rows land with the paired standup ADR.
- **Architecture-doc subsection follows the existing shape.** Match the document's per-Node section structure (Node ID, Role, Owns, Does not own, Dependency flow). Do not invent a new shape.
- **The "Does not own" list is load-bearing.** It separates the prompt-registry layer from inference (AI), audit storage (Audit), and Evals scoring (Evals). Without this clarification, the role of the registry layer relative to its neighbors is unclear.
- **Tuple-only audit emit must be stated in the subsection.** The architecture document is read by downstream AI-sector Nodes during their own feature work; the tuple-only rule must surface there so emitter Nodes (Agents, Knowledge, Memory, Operator, Lore) write the right payload from day one.
- **Snapshot-at-deploy resolution must be stated in the subsection.** Without it, the temptation to hot-reload is real (Vault has a hot-reload story); the architecture document needs to record the rejection.
- **No `relationships.json` edits.** Notify Cloud's consumption pattern (and every AI-sector Node's consumption of `IPromptResolver`) lands with the paired standup ADR's catalog packet, not here.
- **No `infrastructure/reference/tech-stack.md` edits.** The Prompts Node is not a substrate choice (no Azure service, no third-party library); it is a Node. tech-stack.md is for cross-cutting platform choices.

## Labels
`feature`, `tier-2`, `ai`, `docs`, `adr-0064`, `wave-1`

## Agent Handoff

**Objective:** Add the prompt-registry layer to the AI sector taxonomy (`constitution/sectors.md`) and the AI sector architecture document (`constitution/ai-sector-architecture.md`). No catalog edits, no `repos/*` folder creation, no tech-stack.md edits — those belong to the paired `HoneyDrunk.Prompts` standup ADR per ADR-0064 D12.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Make the prompt-registry layer visible at the policy-document level so AI-sector standup Nodes reading their own architecture have the layer in front of them.
- Feature: ADR-0064 Prompt and Persona Registry rollout, Wave 1.
- ADRs: ADR-0064 D1 / D2 / D4 / D5 / D11 / D12 (primary), ADR-0058 / ADR-0059 (precedent for policy/standup pairing).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0064 Accepted before its layer is described in policy docs.

**Constraints:**
- Sector-table row + architecture-doc subsection only. No catalog files modified. No `repos/*` folder created. No tech-stack.md entry.
- The architecture-doc subsection's "Does not own" list separates Prompts from AI / Audit / Evals.
- Tuple-only audit emit and snapshot-at-deploy resolution must surface in the architecture-doc subsection.

**Key Files:**
- `constitution/sectors.md` — AI sector table, new Prompts row.
- `constitution/ai-sector-architecture.md` — new subsection.

**Contracts:** None changed. Catalog-level contract surfaces are registered with the paired standup ADR's catalog packet.
