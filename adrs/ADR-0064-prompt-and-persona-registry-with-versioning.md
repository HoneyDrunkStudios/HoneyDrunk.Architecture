# ADR-0064: Prompt and Persona Registry with Versioning

**Status:** Proposed
**Date:** 2026-05-23
**Deciders:** HoneyDrunk Studios
**Sector:** AI / cross-cutting

## Context

[ADR-0041](./ADR-0041-ai-model-registry-and-approval-workflow.md) commits a **model** registry inside `HoneyDrunk.AI` — `models.json`, `IModelRegistry`, capability canaries, approval workflow. That ADR settles the "which model versions are approved for what use" question. It does **not** settle the parallel question for **prompts**: which prompts and personas are approved, where they live, how they version, how they are traceable from a production LLM call back to the exact text that produced an output.

Every AI-sector standup ADR pulls on this missing piece:

- **[ADR-0016](./ADR-0016-stand-up-honeydrunk-ai-node.md)** committed `IChatClient` and `IEmbeddingGenerator` in `HoneyDrunk.AI.Abstractions`. The chat-message argument is a `Messages` collection; the *content* of that collection — system prompt, persona instructions, task templates — is left to the consumer. Today every consumer inlines string literals.
- **[ADR-0018](./ADR-0018-stand-up-honeydrunk-operator-node.md)** stands up Operator as the human-oversight Node. Operator owns safety filter prompts, refusal-classifier prompts, and approval-rationale prompts that *will* be inlined unless a registry exists.
- **[ADR-0020](./ADR-0020-stand-up-honeydrunk-agents-node.md)** stands up the Agent execution runtime. Every agent has at minimum a system prompt; many have multi-stage prompt chains. Without a registry, "which prompt did agent run `agn_abc` use" is uninvestigable after a regression.
- **[ADR-0021](./ADR-0021-stand-up-honeydrunk-knowledge-node.md)** stands up Knowledge / RAG. Retrieval-augmentation templates, query-rewriting prompts, citation-formatting prompts — all inlined today.
- **[ADR-0022](./ADR-0022-stand-up-honeydrunk-memory-node.md)** stands up Memory. Summarization prompts (long-term memory compaction), retrieval-ranking prompts, scope-extraction prompts — all inlined today.
- **[ADR-0023](./ADR-0023-stand-up-honeydrunk-evals-node.md)** stands up Evals. Evals' whole job is to score model-and-prompt combinations against rubrics. Without a stable prompt identifier and version, an Evals score is meaningless — "the prompt was probably X, give-or-take" is not a forensic anchor. Evals **cannot pin a regression** to a prompt change unless prompts version like models do.
- **`HoneyDrunk.Lore`** (Seed in [`constitution/sectors.md`](../constitution/sectors.md)) is the LLM-compiled wiki. Per memory [`project_lore_sourcing_workflow`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_lore_sourcing_workflow.md), a Claude Code skill ingests raw sources into the wiki — that ingestion uses prompts in production.
- **Honeyclaw** is the user's OpenClaw bear-keeper Telegram bot (memory [`project_honeyclaw_bot`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_honeyclaw_bot.md)). The bear-keeper persona is in production. Today it lives in OpenClaw's third-party gateway config; there is no Grid-side source of truth for it.
- The consumer-PDR apps (Hearth, Lately, Curiosities — memory [`project_app_concepts_2026_05_05`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_app_concepts_2026_05_05.md)) each imply distinct personas. Without a registry committed before they ship, each app reinvents prompt storage at startup.

The forcing function: the AI-sector standup wave is in flight ([ADR-0020](./ADR-0020-stand-up-honeydrunk-agents-node.md), [ADR-0021](./ADR-0021-stand-up-honeydrunk-knowledge-node.md), [ADR-0022](./ADR-0022-stand-up-honeydrunk-memory-node.md), [ADR-0023](./ADR-0023-stand-up-honeydrunk-evals-node.md) all Proposed). Every one of those Nodes' first feature packets will either inline prompts or pull on a registry. Inlining compounds: every Node that inlines now has to migrate later, every Audit emit recorded without a prompt-version field has to be backfilled, every Evals regression discovered after the fact is investigated against drifted text. The cost of doing this later climbs week over week.

This ADR commits the prompt-and-persona registry shape, the storage model, the persona-vs-prompt distinction, the versioning scheme, the runtime resolution rule, the Audit emit contract, the Evals integration shape, the Honeyclaw posture, the PDR-app pattern, the on-disk schema, the PII rule, and the loader location. A paired stand-up ADR for the `HoneyDrunk.Prompts` Node follows immediately (per D11) — this ADR is the **policy**; that stand-up ADR is the **Node shape**.

## Decision

### D1 — Storage: dedicated `HoneyDrunk.Prompts` repo, files on disk, distributed as NuGet

Prompts and personas live in a **dedicated public repo, `HoneyDrunk.Prompts`**, as text files with YAML frontmatter. The repo is distributed to consumers as a NuGet package (`HoneyDrunk.Prompts`, content-and-runtime hybrid: prompt files are content embedded in the package; a small loader runtime is included for resolution). Consumers (`HoneyDrunk.AI`, `HoneyDrunk.Agents`, `HoneyDrunk.Operator`, `HoneyDrunk.Memory`, `HoneyDrunk.Knowledge`, `HoneyDrunk.Evals`, `HoneyDrunk.Lore`, Honeyclaw's build pipeline) take a NuGet dependency on `HoneyDrunk.Prompts` at the version their build is pinned against.

Alternatives explicitly rejected:

- **Files in App Configuration, versioned by Configuration snapshots.** Rejected on three counts. (a) Snapshots are point-in-time and key-value-shaped; prompts are multi-kilobyte text bodies that fit poorly in a config key. (b) App Configuration does not give a clean diff surface in code review — PRs that change prompts could not be reviewed as text-vs-text. (c) Per [ADR-0005](./ADR-0005-configuration-and-secrets-strategy.md), App Configuration carries operator-tunable runtime values (rate tables, routing policies, feature flags) — values that *change between deploys without a recompile*. Prompts are part of the release surface (see D4); coupling them to operator-runtime mutability is the wrong shape.
- **Prompts in a database table with a content-addressed hash.** Rejected for v1. The database row gives audit-grade immutability but loses the code-review diff surface and forces every prompt change into a data-migration shape. Reviewable text changes are the higher-value property in the prompt iteration loop. A content-hash field is still emitted at use time per D5 — the audit trail does not require database storage.
- **Prompts embedded in each Node's source, versioned with the Node.** This is the status quo for the Nodes that have shipped (Lore wiki, Honeyclaw). Rejected as the go-forward stance for the same reasons inlining model names is forbidden per Invariant 28: a Grid-wide primitive ("which prompt was this") should not be duplicated across N Nodes. The cross-Node prompt **lookup** capability — "which Nodes use the bear-keeper persona," "show me every prompt that calls `IChatClient` with vision capability" — is impossible when prompts live N-times across N repos.

This is the same pattern `HoneyDrunk.Standards` uses for shared analyzers, EditorConfig, and Roslyn analyzers (per the naming-rule memory [`project_naming_rule_records`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_naming_rule_records.md)): a single repo, NuGet distribution, every consumer pulls the version they build against.

### D2 — Persona vs Prompt: two kinds, one schema, persona composition optional

A **Persona** is a stable, named, owned identity definition. It has:
- A `system_prompt` body — the instructions, voice, constraints, refusal posture, and persona-level guardrails.
- Long lifecycle (months to years) and few in total (Honeyclaw bear-keeper, Operator safety filter, Evals judge, app-specific personas, etc.).
- Owned by a single Node or surface that defines the persona's role.

A **Prompt** is a task-specific template, often parameterized. It has:
- A `body` with named placeholders (`{recipient_name}`, `{document_text}`, `{user_message}`).
- A `parameters` declaration listing each placeholder, type, and whether required.
- Short lifecycle (days to weeks of iteration) and many in total (per Node, per feature).
- Optionally `extends` a persona — at composition time, the persona's `system_prompt` is prepended to the prompt's `body` rendering, producing the full message sequence sent to `IChatClient`.

Both are kind-tagged in the frontmatter (`kind: persona` or `kind: prompt`). The on-disk schema (D9) is uniform; the loader knows which kind a file is by the frontmatter.

The two-kind distinction is load-bearing: it separates identity (a stable persona for Honeyclaw, the Evals judge, the Operator filter) from task (a task-specific compaction prompt, a query-rewriting prompt, an entity-extraction prompt). Without the distinction, every task prompt re-inlines the same persona text and persona iteration becomes N-prompt rather than one-persona.

### D3 — Versioning: semver per `HoneyDrunk.Prompts` package, content-hash per file emitted at use time

Versioning is **semver on the package as a whole**, not per individual prompt. All prompts move together as a coherent release. The package versions per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md) (strict semver):

- **Major** — any change a downstream consumer could observe as a contract break: removing a persona/prompt id, removing or renaming a parameter on a prompt, changing a parameter's required/optional status, changing the persona that a prompt `extends`. Removing a persona or prompt is the prompt-registry analog of removing an interface member.
- **Minor** — additive only. New persona, new prompt, new optional parameter on an existing prompt, **rewriting an existing persona's or prompt's body** (the body change is not interface-breaking from the consumer's perspective — the consumer still looks up the same id — but it changes model behavior, which is significant; minor is the right tier).
- **Patch** — frontmatter metadata changes that do not affect model behavior (notes, owner, model_compatibility list expansion).

The body-rewrite-is-minor rule is deliberate. A consumer that pins to a `^1.0.0` range and receives `1.4.0` may observe materially different model behavior; this is the entire reason D4 makes resolution a deploy-time snapshot rather than a hot-reload, and D5 makes the per-call audit emit include the content hash. The semver bump captures the "this changed" signal; the audit hash captures the "exactly which version produced this output" signal.

**Each prompt file's `body` plus normalized frontmatter is content-hashed (SHA-256) at package build time** and the hash is recorded in a generated manifest inside the package. At runtime, the loader emits the hash alongside the prompt id and version in every Audit entry per D5. Hashes are reproducible across builds — a prompt file unchanged in commit N+1 has the same hash as in commit N.

The combination is the right level of immutability:
- The **semver version** answers "what release of the prompts package shipped this."
- The **content hash** answers "byte-for-byte, exactly which text was this."

Both are required in the audit emit (D5). Evals' regression analysis uses the hash, not the semver version, as the equality key for "same prompt or different."

### D4 — Runtime resolution: snapshot at deploy time, no hot-reload

Each consuming Node embeds the `HoneyDrunk.Prompts` NuGet package version at **build time**. The prompt set live in production at any moment is the set baked into the deployed Node binary. There is no hot-reload of prompts.

Alternatives rejected:

- **Hot-reload via Event Grid** (the pattern Vault uses for secret rotation per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md)). Rejected because it produces drift between the prompt-version Evals tested against and the prompt-version production runs. If an Evals score for prompt `evals-judge-v1.3.0` greenlit a release, and production hot-reloads to `1.4.0` an hour later, the Evals score no longer covers what is running. Prompts are part of the **release surface**, not an operator dial.
- **Snapshot at startup with periodic refresh.** Same problem at a slower cadence. Rejected.

Snapshot-at-deploy means prompt iteration follows the normal release loop: change a prompt, bump the prompts package version, the change ships when each consuming Node next releases against the new version. For Notify Cloud GA scenarios where prompt changes need to ship fast, the prompts package update + Node release is one pipeline run end-to-end — not slow in practice.

The constraint forces discipline: prompt changes have the same deployment posture as code changes. They go through CI, they go through Evals (D6), they are reviewed.

### D5 — Audit emit: every LLM call records the prompt-version tuple

Every `IChatClient` and `IEmbeddingGenerator` call records to `IAuditLog` (per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)) the following tuple as part of the audit entry's structured payload:

- `persona_id` — the persona's `id` from the frontmatter (e.g., `honeyclaw-bear-keeper`, `evals-judge`, `operator-safety-filter`). `null` if the call composed no persona.
- `persona_version` — the semver version of `HoneyDrunk.Prompts` that supplied the persona. `null` if `persona_id` is `null`.
- `persona_hash` — the SHA-256 content hash of the persona file at that version. `null` if `persona_id` is `null`.
- `prompt_id` — the prompt's `id` from the frontmatter. `null` if the call composed no template (raw user message only).
- `prompt_version` — the semver version of `HoneyDrunk.Prompts` that supplied the prompt.
- `prompt_hash` — the SHA-256 content hash of the prompt file at that version.

This tuple is **required** on every LLM-call audit emit. Calls that bypass the registry (a one-off `IChatClient` invocation with an inline raw system message) are not forbidden, but they record `persona_id: null`, `prompt_id: null`, and a flag `bypassed_registry: true` so the audit query "how many inline-prompt calls happened" is answerable.

Bypassed-registry calls are operationally legitimate (e.g., a one-shot diagnostic prompt by an operator, a developer-time experiment). They are not legitimate at steady-state — the goal of the registry is that every production LLM call goes through it. The audit query lets the studio measure progress toward "registry-coverage = 100%" without enforcing it as a runtime check (an over-strict runtime check would block legitimate one-off operator use).

### D6 — Evals integration: score against `(prompt_id, prompt_hash)`, replay against the same

Evals (per [ADR-0023](./ADR-0023-stand-up-honeydrunk-evals-node.md)) scores prompt-and-model combinations against rubrics. An Evals **run identifier** captures:

- The `ModelId` (per [ADR-0041](./ADR-0041-ai-model-registry-and-approval-workflow.md)).
- The `(prompt_id, prompt_version, prompt_hash)` tuple from D5.
- The persona tuple if composed.

The **equality key for "same prompt"** is the `prompt_hash`, not the `prompt_version`. A prompt with the same hash across two package versions is the same text — Evals does not need to re-score it. A prompt with a different hash is a different prompt and must re-score before its new hash can land in production.

This is the registry's load-bearing integration with Evals. Without prompt hashes, every Evals score is anchored to "the file in this branch at this commit" — when the file moves, the score is orphaned. With prompt hashes, an Evals score is permanently anchored to the exact text it scored. Regression analysis ("did the v1.4.0 prompts release regress quality on the Notify summarization suite") becomes a hash-diff query.

A future Evals-side ADR may add **Evals as a release gate** for the prompts package: a major or minor bump cannot publish without all affected suites passing. This ADR commits the integration shape; the gate is a follow-up.

### D7 — Honeyclaw integration: Grid registry is source of truth, OpenClaw consumes via build step

Honeyclaw runs in OpenClaw (third-party agent gateway, memory [`project_openclaw`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_openclaw.md)). Per memory [`project_honeyclaw_bot`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_honeyclaw_bot.md), the bear-keeper persona is in production today.

The decision: the **Grid's `HoneyDrunk.Prompts` repo is the source of truth for Honeyclaw's persona** even though Honeyclaw runs in third-party OpenClaw infrastructure. The persona file `honeyclaw-bear-keeper.persona.md` lives in `HoneyDrunk.Prompts`. A small adapter (in `HoneyDrunk.Prompts` itself or in a paired `HoneyDrunk.OpenClaw` integration package — to be decided in the standup ADR) exports the persona on each prompts-package release in the format OpenClaw expects. OpenClaw pulls the exported persona at its own release/config-update cadence.

The pull is **not** a runtime HTTP call from OpenClaw into the Grid. OpenClaw is third-party; assuming Grid availability for OpenClaw's startup is the wrong coupling. The pull is a **build/release step** — when a new prompts package version ships, a separate workflow exports Honeyclaw's persona to OpenClaw's configured location (memory, a private GitHub gist, a Vault-stored OpenClaw config blob, exact mechanism deferred to the standup ADR).

Alternatives rejected:

- **Honeyclaw's persona lives in OpenClaw's own config, Grid registry mirrors it.** Rejected because it inverts the source-of-truth — the studio iterates on Honeyclaw via OpenClaw's third-party config and the Grid's registry is perpetually stale. Iteration ergonomics matter more than mechanical convenience.
- **Honeyclaw's persona lives nowhere structured — copy/paste between OpenClaw's UI and the user's notes.** Rejected. This is the status quo and it is the exact thing this ADR exists to prevent.

This rule generalizes: any third-party agent gateway, any external surface that runs a Grid-defined persona, treats the Grid's `HoneyDrunk.Prompts` repo as the source of truth and pulls via a build step. The Grid never runs as a runtime dependency of third-party agent infrastructure.

### D8 — PDR-app personas: registered from day one

Hearth, Lately, Curiosities, and any future consumer-PDR app that implies a persona (a journaling-town narrator, a connection-companion voice, a curiosity-cabinet curator) registers that persona **in `HoneyDrunk.Prompts` at the app's first AI-enabled feature packet** — not after the app ships, not in the app's repo.

The mechanism: when a PDR-app introduces an AI-mediated feature, the packet that ships that feature includes a `HoneyDrunk.Prompts` PR adding the persona and any task prompts. The app's release is gated on the prompts package's release that includes them. This is the same coupling shape Evals has with the prompts package (D6).

The reasoning: prompt registries that "fill in later" never get filled in. The discipline is to register at first use; the alternative is a year-later cleanup initiative.

### D9 — On-disk schema: YAML frontmatter + Markdown/text body

Each prompt or persona is one file at a path of the form:

```
HoneyDrunk.Prompts/
  personas/
    {id}.persona.md
  prompts/
    {owner-node}/
      {id}.prompt.md
```

So:

```
personas/honeyclaw-bear-keeper.persona.md
personas/evals-judge.persona.md
personas/operator-safety-filter.persona.md
prompts/honeydrunk-memory/long-term-summarization.prompt.md
prompts/honeydrunk-knowledge/query-rewrite.prompt.md
prompts/honeydrunk-lore/wiki-ingest.prompt.md
```

The path is part of the convention but the `id` field in the frontmatter is the **lookup key** (the path is for human navigation; the loader uses `id`).

Each file's frontmatter (YAML) carries:

- `id` — globally unique stable identifier (kebab-case, e.g., `honeyclaw-bear-keeper`). Renaming an id is a breaking change per D3.
- `kind` — `persona` or `prompt`.
- `version` — informational. The authoritative version is the `HoneyDrunk.Prompts` package version that contains this file. (Per-file versioning was considered and rejected — see Alternatives.)
- `extends` — for prompts only, optional. The `id` of a persona this prompt composes with at render time.
- `parameters` — for prompts only. A list of `{ name, type, required, description }` entries describing each placeholder in the body.
- `model_compatibility` — list of model `id`s from [ADR-0041](./ADR-0041-ai-model-registry-and-approval-workflow.md)'s `models.json` that this prompt is known to work with. Optional; absent means "no constraint."
- `owner` — the Node `id` (per [`catalogs/nodes.json`](../catalogs/nodes.json)) that primarily uses this prompt. Personas may omit owner if cross-Node. The reviewer agent (per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md)) uses `owner` to route PR review.
- `classification` — per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md). `Public`, `Internal`, or `Sensitive`. See D10 — `Restricted` and PII-bearing values are forbidden in prompt/persona files outright.
- `created` — ISO date of the file's first commit.
- `notes` — free-form. Author's notes on intent, known-failure cases, model-specific quirks.

The body of the file is the prompt text (for prompts) or system-prompt text (for personas), in Markdown-friendly prose. Placeholders use `{{ parameter_name }}` (double-brace Mustache-style) — distinct from C# string interpolation `{name}`, distinct from f-string `{name}`, distinct from `%(name)s`, to avoid accidental capture by any of those interpolation systems passing through the text.

### D10 — PII and sensitive content: forbidden in prompt/persona files

Prompts and personas are **public-or-internal text artifacts**. Per [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md), no `Restricted`-tier or PII-bearing value may appear inline in a prompt or persona file. Per memory [`project_repos_public_by_default`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_repos_public_by_default.md), the `HoneyDrunk.Prompts` repo is **public**, which makes this enforcement obvious — anything tenant-scoped, PII-bearing, or secret has no place in a public repo.

Tenant-scoped data, PII, customer records, and any classified payload enter the LLM call at **render time, via parameters** (the prompt's `parameters` declaration in D9). The prompt file says `{{ user_message }}`; the runtime substitutes the actual user message at call time. The user message is never inlined into the file.

Enforcement is two-tier:

- **CI gate in the `HoneyDrunk.Prompts` repo** — scans every file's frontmatter for `classification: Restricted` (forbidden) and runs the secret-scan pipeline per [ADR-0009](./ADR-0009-package-scanning-policy.md) on every file body (any matched pattern is a CI failure).
- **Reviewer agent rule** — per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md), PRs to `HoneyDrunk.Prompts` are checked for: (a) classification field present and not `Restricted`, (b) no inlined values that look tenant-scoped or PII-bearing, (c) parameter declarations cover every placeholder in the body.

This is the prompt-registry analog of Invariant 8 (secrets never appear in logs) extended to prompt source files.

### D11 — Loader location: `IPromptResolver` in `HoneyDrunk.Prompts.Abstractions`, default impl in `HoneyDrunk.Prompts`

The contract:

```
IPromptResolver
  PersonaContent ResolvePersona(PersonaId id);
  PromptContent ResolvePrompt(PromptId id, IReadOnlyDictionary<string, object?> parameters);
  ResolvedMessages Compose(PromptId promptId, PersonaId? personaId, IReadOnlyDictionary<string, object?> parameters);
```

`PersonaId` and `PromptId` are records (no `I` prefix, per memory [`project_naming_rule_records`](../../../.claude/projects/c--Users-tatte-source-repos-HoneyDrunkStudios-HoneyDrunk-CoreWorkspace/memory/project_naming_rule_records.md)). `PersonaContent`, `PromptContent`, and `ResolvedMessages` are records carrying body text, hash, version, and metadata. `Compose` is the typical hot-path call — render a prompt with parameters, prepend the persona's system prompt, return the message sequence ready for `IChatClient`.

The interface lives in `HoneyDrunk.Prompts.Abstractions` so consumers compile against the abstraction, not the runtime, per the Grid-wide abstractions-first rule (Invariant 2, Invariant 44 by analogy). The default implementation lives in `HoneyDrunk.Prompts` and reads prompt files from the package's embedded content at startup.

A separate package, `HoneyDrunk.Prompts.Tests.Fakes`, provides an `InMemoryPromptResolver` for consumer tests that need to stub the registry without including the full prompts package. The Fakes package is test-time only per the convention established by [ADR-0019](./ADR-0019-stand-up-honeydrunk-communications-node.md).

Each consuming Node takes a runtime dependency on `HoneyDrunk.Prompts` and composes the resolver in DI at startup. The dependency direction:

```
HoneyDrunk.Prompts.Abstractions   (IPromptResolver, records)
  ↑
  ├─ HoneyDrunk.Prompts            (default IPromptResolver, embedded content)
  ├─ HoneyDrunk.AI                 (composes IChatClient + IPromptResolver at host time)
  ├─ HoneyDrunk.Agents             (composes resolver per-agent)
  ├─ HoneyDrunk.Operator           (composes resolver for safety filters)
  ├─ HoneyDrunk.Memory             (composes resolver for summarization)
  ├─ HoneyDrunk.Knowledge          (composes resolver for query rewriting)
  ├─ HoneyDrunk.Evals              (composes resolver to capture run identifiers)
  └─ HoneyDrunk.Lore               (composes resolver for wiki ingestion prompts)
```

`HoneyDrunk.Prompts.Abstractions` has zero runtime dependencies on other Grid packages (Invariant 1). `HoneyDrunk.Prompts` (the default impl) depends only on `HoneyDrunk.Prompts.Abstractions` and `Microsoft.Extensions.*` abstractions (Invariant 2). Consuming Nodes depend on the abstraction; the runtime is host-composed.

### D12 — Paired standup ADR for `HoneyDrunk.Prompts` Node

This ADR commits the **policy** — what gets stored, how it versions, how runtime resolution works, the audit emit, the schema, the loader shape. The **Node shape** — repo layout, solution structure, CI pipeline, contract-shape canary, scaffold packet contents — is a separate paired standup ADR following the precedent set by the [ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) / [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) pair.

**Why two ADRs, not one:** the per-Node standup convention (set 2026-04-19; precedent established by every Node standup since) treats "is there a Node for this" as a separate decision from "what is the Grid policy this Node implements." Folding the standup into this ADR would set the wrong precedent — future policy ADRs would feel they have to standup their own Nodes inline. Keeping them paired is the right shape.

The standup ADR is filed immediately after this one (the next available ADR number after the Aspire ADR that ships in the same wave). It covers: `HoneyDrunk.Prompts` repo creation (public), solution layout (`HoneyDrunk.Prompts.Abstractions`, `HoneyDrunk.Prompts`, `HoneyDrunk.Prompts.Tests.Fakes`, the placeholder packaging-of-content project), HoneyDrunk.Standards wiring, CI pipeline (build, test, secret scan, classification check per D10), the contract-shape canary on `IPromptResolver` per [ADR-0035](./ADR-0035-abstractions-versioning-and-deprecation-policy.md), context folder, catalog entries, sector placement (AI sector — prompts and personas are the AI sector's identity substrate, the same way Audit is Core's record substrate).

A migration packet seeds the registry with the personas/prompts already running in production:
- `honeyclaw-bear-keeper.persona.md` — extracted from OpenClaw config.
- `lore-wiki-ingest.prompt.md` — extracted from the Lore wiki-ingestion skill.
- Any prompts inlined in the seed Nodes that have shipped feature work (none expected at file time; the AI-sector standups are at scaffold stage, not feature stage).

## Consequences

### Affected Nodes

- **`HoneyDrunk.Prompts`** (new Node, paired standup ADR). Houses the registry, the default `IPromptResolver`, the content, and the loader runtime.
- **`HoneyDrunk.AI`** — gains a transitive dependency on `HoneyDrunk.Prompts.Abstractions` via the Audit emit path (the audit entry for an LLM call needs the prompt tuple). The composition is host-time; the abstraction is consumed at the call site.
- **`HoneyDrunk.Agents`** (per [ADR-0020](./ADR-0020-stand-up-honeydrunk-agents-node.md)) — composes `IPromptResolver` per agent. Agent definitions reference persona and prompt ids by string.
- **`HoneyDrunk.Operator`** (per [ADR-0018](./ADR-0018-stand-up-honeydrunk-operator-node.md)) — safety filters and approval rationales resolve through the registry.
- **`HoneyDrunk.Memory`** (per [ADR-0022](./ADR-0022-stand-up-honeydrunk-memory-node.md)) — summarization and retrieval-ranking prompts resolve through the registry.
- **`HoneyDrunk.Knowledge`** (per [ADR-0021](./ADR-0021-stand-up-honeydrunk-knowledge-node.md)) — query-rewrite, citation-format, and rerank prompts resolve through the registry.
- **`HoneyDrunk.Evals`** (per [ADR-0023](./ADR-0023-stand-up-honeydrunk-evals-node.md)) — run identifiers capture the prompt tuple; the equality key for "same prompt" is the hash. The release-gate-on-Evals integration is a follow-up.
- **`HoneyDrunk.Lore`** — the Claude Code wiki-ingest skill resolves its prompts through the registry. Lore's first registry-aware feature packet migrates its inlined ingest prompts.
- **`HoneyDrunk.Audit`** (per [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)) — the audit entry schema for LLM-call events gains the prompt tuple fields. The schema change is additive (existing audit consumers see optional new fields).
- **Honeyclaw / OpenClaw** — Honeyclaw's persona is sourced from `HoneyDrunk.Prompts`; an export workflow keeps OpenClaw's runtime config in sync.
- **Consumer PDR apps** (Hearth, Lately, Curiosities, future) — each app's personas register in `HoneyDrunk.Prompts` at the app's first AI-enabled feature packet.

### New Invariants

This ADR commits four new invariants (final numbers assigned at the constitution update; the standup ADR's acceptance flips them in):

- **Invariant — every LLM call emits an audit entry recording `(persona_id, persona_version, persona_hash, prompt_id, prompt_version, prompt_hash, bypassed_registry?)`.** Calls that bypass the registry record `bypassed_registry: true` with null prompt fields, but the audit emit itself is not optional.
- **Invariant — no PII, no `Restricted`-tier content, no secret values appear inline in `HoneyDrunk.Prompts` files.** PII enters through parameters at call time; secrets stay in Vault. CI gate enforces.
- **Invariant — application code must never inline a persona's or prompt's body text as a string literal when the registry has an entry for it.** New code paths resolve through `IPromptResolver`; one-off bypasses are recorded in audit per the prior invariant. (The Invariant 28 analog for prompts — model names cannot be inlined; neither can persona text.)
- **Invariant — the HoneyDrunk.Prompts package's CI must include a contract-shape canary on `IPromptResolver` and a content-shape canary asserting every prompt file's frontmatter parses and every body's `{{ parameter }}` placeholders match the declared parameters list.** Shape drift on `IPromptResolver` or content drift in the files is a build failure unless paired with an intentional version bump.

### Operational Consequences

- **Prompt iteration is a release-loop activity, not an operator dial.** Changing a prompt and seeing the result in production is: edit file → PR → review → merge → prompts package version bump → consuming Node release. The standup ADR's CI keeps this loop fast (a typical edit-to-merge is under an hour); the slow part is the consuming Node's release cadence. Operators who want faster iteration on prompts will pull on a hot-reload story; this ADR rejects that pull. The reasoning is recorded in D4.
- **Evals scoring against the hash gives the studio a permanent quality timeline.** Every commit to `HoneyDrunk.Prompts` produces deterministic hashes; every Evals run pins to a hash; the timeline of "this prompt at hash X scored Y" is queryable forever.
- **Honeyclaw's persona stops drifting between OpenClaw and the studio's notes.** The Grid registry becomes the single place to iterate; the OpenClaw export workflow is the single coupling point.
- **The PDR apps inherit a built-in persona discipline.** Hearth, Lately, Curiosities, and future apps register their personas at first AI-feature commit; the studio never has to retrofit persona registration after launch.
- **Audit-emit volume rises** (every LLM call now has a structured prompt tuple in the audit payload). Per [ADR-0030 D7](./ADR-0030-grid-wide-audit-substrate.md), this is in the Audit Node's normal load; no new infrastructure is required.
- **The classification CI gate in `HoneyDrunk.Prompts` is the first place the Grid's classification taxonomy from [ADR-0049](./ADR-0049-data-classification-pii-handling-and-retention-schedule.md) is enforced at the file level.** This is a useful forcing function — it surfaces the rare case where a developer is tempted to inline tenant or PII data into a prompt body and rejects it at PR time.

### Catalog and Reference Updates Required

This ADR identifies the updates required at acceptance. The updates themselves are filed as scope-agent-dispatched packets, not authored in this ADR text:

- [`catalogs/nodes.json`](../catalogs/nodes.json) — adds `honeydrunk-prompts` entry (assigned by the paired standup ADR; sector AI; visibility public).
- [`catalogs/relationships.json`](../catalogs/relationships.json) — adds `honeydrunk-prompts` with `consumes: ["honeydrunk-kernel"]` (the loader runtime uses Kernel primitives for lifecycle and DI); `consumed_by_planned: ["honeydrunk-ai", "honeydrunk-agents", "honeydrunk-operator", "honeydrunk-memory", "honeydrunk-knowledge", "honeydrunk-evals", "honeydrunk-lore"]`.
- [`catalogs/grid-health.json`](../catalogs/grid-health.json) — adds the Node row.
- [`catalogs/modules.json`](../catalogs/modules.json) — adds the Node entry with the three planned packages (`HoneyDrunk.Prompts.Abstractions`, `HoneyDrunk.Prompts`, `HoneyDrunk.Prompts.Tests.Fakes`).
- [`catalogs/contracts.json`](../catalogs/contracts.json) — adds the `IPromptResolver` interface and the `PersonaId`, `PromptId`, `PersonaContent`, `PromptContent`, `ResolvedMessages` records.
- [`constitution/sectors.md`](../constitution/sectors.md) — adds `Prompts` to the AI sector table.
- [`constitution/invariants.md`](../constitution/invariants.md) — adds the four invariants listed above with final numbers assigned at acceptance.
- [`constitution/ai-sector-architecture.md`](../constitution/ai-sector-architecture.md) — adds the prompt-registry layer to the AI sector's substrate description.
- [`infrastructure/reference/tech-stack.md`](../infrastructure/reference/tech-stack.md) — adds `HoneyDrunk.Prompts` to the current Nodes table once the standup ADR ships.
- [`initiatives/roadmap.md`](../initiatives/roadmap.md) — adds the prompts package and the standup ADR's follow-up packets to the active initiatives section.
- [`repos/HoneyDrunk.Prompts/`](../repos/) — folder created by the standup ADR with `overview.md`, `boundaries.md`, `invariants.md`.

### Follow-up Work

- File the paired `HoneyDrunk.Prompts` standup ADR (next available ADR number after this wave).
- Author the migration packet that seeds the registry with `honeyclaw-bear-keeper.persona.md` (extracted from OpenClaw config) and `lore-wiki-ingest.prompt.md` (extracted from the Lore wiki-ingest skill).
- Wire the Honeyclaw export workflow (release-time export of `honeyclaw-bear-keeper.persona.md` to OpenClaw's configured location; exact mechanism decided in the standup ADR).
- Extend [ADR-0030](./ADR-0030-grid-wide-audit-substrate.md)'s audit-entry schema for LLM-call events to include the prompt tuple. The schema extension is additive per Audit's append-only-by-interface posture.
- Update `.claude/agents/review.md` per [ADR-0044](./ADR-0044-grid-aware-cloud-code-review-and-ai-authored-pr-discipline.md) — new PR-review checklist items for `HoneyDrunk.Prompts` PRs: classification field present and not `Restricted`, no inlined PII, parameter declarations cover every placeholder, body change triggers minor bump.
- Update `.claude/agents/scope.md` — packets that introduce LLM calls must declare which persona/prompt id they consume from `HoneyDrunk.Prompts`; absent declaration is grounds to amend the packet before filing.
- Author the Evals-as-release-gate follow-up ADR (whether and how a prompts package release blocks on affected Evals suites passing).
- Confirm with each AI-sector Node's first feature packet that prompts resolve through `IPromptResolver`, not inline.

## Alternatives Considered

### Per-prompt semver, every file versioned independently

Considered. Each prompt file carries its own semver in frontmatter; consumers pin to per-prompt versions; the package is a thin index.

Rejected. The combinatorial explosion is real: ten consumers each pinned to N prompts at independent versions is N × 10 pin records to maintain. The studio is too small to operate it. Package-level semver moves all prompts together as a coherent release, which is the right granularity at studio scale. The audit emit's hash captures per-file identity for forensic purposes; per-file semver adds tracking cost without forensic benefit.

### Prompts as Azure App Configuration values

Considered. Use the existing operator-runtime mutability surface for prompts.

Rejected per D1. Three structural reasons: prompts are multi-kilobyte bodies that fit App Configuration's key-value shape poorly; prompt changes lose their code-review diff surface; and the operator-runtime mutability is the wrong shape — prompts are release-surface, not operator-tunable.

### Prompts in a database table with content-addressed hash

Considered. The database row gives audit-grade immutability and a natural query surface.

Rejected for v1. Reviewable text changes are the higher-value property in the prompt iteration loop; a database row's diff is not reviewable in a PR. The audit-grade hash property is achieved at the package-build step (D3) without requiring database storage. If a future scenario demands query-time prompt-corpus search (e.g., "find every prompt that mentions a specific phrase"), a derived index can be built without making the database the source of truth.

### Prompts embedded in each Node's source

Considered. Status quo for the few Nodes that have shipped prompts already (Lore, Honeyclaw).

Rejected for the go-forward stance. Same reasoning that forbids inlined model names per Invariant 28 — a Grid-wide primitive duplicated across N Nodes is unmaintainable. The cross-Node prompt-lookup capability is impossible with inlined prompts.

### Skip the persona-vs-prompt distinction; everything is a prompt with optional system content

Considered. Smaller schema, fewer concepts.

Rejected per D2. The distinction is load-bearing for iteration ergonomics — a persona's system text is iterated rarely and reused across many task prompts; collapsing them forces every task prompt to re-inline the persona text. The distinction also matches the real-world shape (Honeyclaw has one persona and zero task-specific prompts; Knowledge has zero personas and many task prompts; Operator has both). Modeling the real shape is cheaper than collapsing it.

### Hot-reload prompts via Event Grid (Vault pattern)

Considered. Same mechanism Vault uses for secret rotation per [ADR-0006](./ADR-0006-secret-rotation-and-lifecycle.md).

Rejected per D4. The Evals-coverage problem is fatal: a hot-reloaded prompt invalidates the Evals score that greenlit the prior release. Vault's hot-reload is acceptable because the *behavior* a secret produces is independent of the secret's value (the credential authenticates the same way regardless of the bytes). The behavior a prompt produces is the function of the prompt's bytes — exactly the property hot-reload would undermine.

### Honeyclaw's persona lives in OpenClaw, Grid registry is a downstream copy

Considered. OpenClaw is the system Honeyclaw runs in; let OpenClaw's config win.

Rejected per D7. The iteration loop is the wrong shape — the studio iterates on Honeyclaw alongside other personas, and the Grid registry is where that iteration happens. The Grid is the source of truth; OpenClaw is the runtime consumer. The export workflow keeps the runtime in sync without inverting source-of-truth.

### Defer the PDR-app personas until each app ships

Considered. Hearth, Lately, Curiosities are not built yet; their personas can register when they materialize.

Rejected per D8. Prompt registries that "fill in later" never get filled in. Registering at first AI-feature commit is the discipline; the alternative is a year-later cleanup initiative. The cost of registering early is negligible (one PR per app's first feature); the cost of cleanup is real.

### Fold the `HoneyDrunk.Prompts` Node standup into this ADR

Considered. One ADR covering both policy and Node shape; smaller paper trail.

Rejected per D12. The standup-ADR convention separates "is there a Node for this" from "what is the policy this Node implements." Folding them would set the wrong precedent for future policy ADRs. The paired-ADR shape ([ADR-0058](./ADR-0058-grid-wide-caching-strategy.md) / [ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md) is the most recent precedent) is the right shape.

### Defer the registry until after the AI-sector standup wave settles

Considered. The standup wave is still in Proposed; let the Nodes scaffold first, retrofit the registry later.

Rejected. Every Node that scaffolds without the registry inlines prompts in its first feature packet. The cleanup cascade later is exactly the kind of work this ADR exists to prevent. Better to land the policy now, before the seed Nodes' first feature packets, so they consume `IPromptResolver` from day one.

### Use `IPromptResolver` from `HoneyDrunk.Kernel.Abstractions` instead of a separate package

Considered. Treat prompt resolution as a Kernel-level primitive.

Rejected. Kernel.Abstractions is intentionally tight (context propagation, lifecycle, identity); adding prompt-domain types broadens its surface for no offsetting benefit. The Cache Node standup ([ADR-0059](./ADR-0059-stand-up-honeydrunk-cache-node.md)) made the same call for `ICacheStore<T>` — Kernel hosts the contract, but the implementation Node hosts the runtime. The prompt-resolver case is structurally similar but with one difference: prompts are domain content (the AI sector's identity substrate), not a substrate primitive every Node universally consumes. The right home is `HoneyDrunk.Prompts.Abstractions`, owned by the Prompts Node.

### Use the file path as the lookup key instead of an explicit `id` field

Considered. The path `personas/honeyclaw-bear-keeper.persona.md` is already unique; a separate `id` is redundant.

Rejected. Coupling the lookup key to the file path forbids ever moving the file. Moving a persona's file (e.g., renaming a directory, archiving an old prompt to a `legacy/` folder) would silently break every consumer. The explicit `id` field is decoupled from filesystem layout; a file can move without changing its `id`.

### Single-brace `{name}` placeholders instead of double-brace `{{ name }}`

Considered. Single-brace is what C# interpolation, Python f-strings, and many template engines use.

Rejected per D9. Single-brace placeholders are exactly the pattern those interpolation systems would accidentally capture if the prompt text passes through one of them en route to the LLM. Double-brace Mustache-style placeholders are distinctive and uncapturable by accident.

### Add the registry to `HoneyDrunk.AI` rather than create a new Node

Considered. AI is the closest existing Node; adding `IPromptResolver` to `HoneyDrunk.AI.Abstractions` and the loader to `HoneyDrunk.AI` would avoid a Node-count increment.

Rejected. Operator, Memory, Knowledge, Evals, Lore, and Honeyclaw consume prompts and do not all consume AI (e.g., Honeyclaw runs outside the Grid; Operator's safety filters might use a different routing layer). Forcing every prompt consumer to take a runtime dependency on `HoneyDrunk.AI` inverts the abstractions-first rule (Invariant 44) — prompt resolution should be a primitive consumers compose, not a feature of the inference Node. A separate Node keeps the dependency direction clean.

### Require all prompts to declare `model_compatibility` rather than making it optional

Considered. Force every prompt to pin to one or more model ids.

Rejected for v1. Some prompts genuinely are model-agnostic (a generic summarization prompt that works on every chat model the registry approves). Forcing a `model_compatibility` declaration on those would either be a fiction (listing every model) or a lie (listing a subset that excludes models the prompt actually works on). Making it optional, with explicit semantics ("absent means no constraint"), models reality.
