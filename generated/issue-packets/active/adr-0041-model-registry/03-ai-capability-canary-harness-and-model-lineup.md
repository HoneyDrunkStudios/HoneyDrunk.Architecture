---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.AI
labels: ["feature", "tier-2", "ai", "adr-0041", "wave-3"]
dependencies: ["packet:02"]
adrs: ["ADR-0041"]
accepts: ["ADR-0041"]
wave: 3
initiative: adr-0041-model-registry
node: honeydrunk-ai
---

# Add the capability canary harness and the initial model lineup to HoneyDrunk.AI

## Summary
Populate `models.json` with the initial model lineup for the three approved API providers (registered at `ApprovalState=Preview`), add the `HoneyDrunk.AI.Tests.Canaries` capability-canary harness that asserts each declared capability against a cheap live provider call, and wire the canary into a nightly per-environment workflow that flips `ApprovalState` via `IApprovalStateWriter` on sustained failure.

## Context
ADR-0041 D3 decides every registered model has a **capability canary** in `HoneyDrunk.AI.Tests.Canaries` that asserts each declared capability against a live (cheap) call. The canary runs nightly per environment, flips a model to `Preview` if it fails for ≤24h, and to `Deprecated` if it fails for ≥7 days. ADR-0041 D4 decides adding a model is a packet that registers it at `Preview`, adds the canary, and gates the PR on the canary passing.

Packet 02 shipped `IModelRegistry`, `IApprovalStateWriter`, and `models.json` with the four providers and an empty `models` array. This packet adds the first batch of model entries and the canary harness that validates them.

The canary is the contract-shape canary pattern (ADR-0016, invariant 46) applied to provider-axis reality rather than Grid-axis interface shape — it catches "the provider silently changed something" before a Grid consumer hits the regression.

This packet lands on the `HoneyDrunk.AI` solution after packet 02 — it **appends to the existing in-progress `[0.2.0]` CHANGELOG entry** and does NOT bump the version again (invariant 27).

## Scope
- `src/HoneyDrunk.AI/models.json` — add `ModelRegistration` entries for the initial lineup, all at `ApprovalState=Preview`.
- `tests/HoneyDrunk.AI.Tests.Canaries/` — new project: the capability-canary harness.
- `tests/HoneyDrunk.AI.Tests.Canaries/` per-model canary classes.
- `src/HoneyDrunk.AI/Registry/` — the `IApprovalStateWriter` implementation gains the `IAuditLog` Audit emit path (`HoneyDrunk.Audit.Abstractions` hard dependency — see Constraints).
- A nightly canary workflow in `.github/workflows/` (or extend an existing scheduled workflow).
- `HoneyDrunk.AI.slnx` — add the new Canaries project.
- CHANGELOG append (no version bump).

## Proposed Implementation

### Initial model lineup (`models.json`)
Add `ModelRegistration` entries, **all at `ApprovalState=Preview`** per ADR-0041 D4 (no model starts `Approved`; a follow-up packet flips after the 14-day window). Use opaque `ModelId` values of the form `{provider}.{model}`. Suggested v1 lineup — confirm exact current model identifiers and list prices at implementation time, prices change:
- **Anthropic** — `anthropic.claude-opus`, `anthropic.claude-sonnet`, `anthropic.claude-haiku` (the current Opus/Sonnet/Haiku tier).
- **OpenAI** — `openai.gpt-4` (or current flagship), `openai.gpt-4-mini` (current cost tier), `openai.text-embedding` (the current embedding model).
- **Azure OpenAI** — the same OpenAI models served via Azure OpenAI, distinct `ProviderId=azure-openai`, distinct deployment-name-based `ModelId` (e.g. `azure-openai.gpt-4`).
- **`local`** — no models (D9 — the slot stays empty at v1).

Each entry carries a `CostProfile` with a realistic `MaxBudgetPerCallUsd` per-call ceiling and a `RoutingHints` with a latency tier. The `ModelCapabilityDeclaration` per model is the frozen ADR-0016 record — populate `MaxContextTokens`, `SupportsStreaming`, `SupportsVision`, `SupportsFunctionCalling`, `SupportedRegions` from each model's published capabilities.

### Capability canary harness (`HoneyDrunk.AI.Tests.Canaries`)
Create a new test project `tests/HoneyDrunk.AI.Tests.Canaries/HoneyDrunk.AI.Tests.Canaries.csproj`:
- The harness reads model data **strictly through `IModelRegistry`** — `GetRegistered()` / `GetById()` / `GetByCapability()`. It must NEVER read `models.json` (the embedded resource) directly; `models.json` is loaded only by `DeclarativeModelRegistry`. For each registered model, it asserts each declared capability against a **live, minimal-cost** provider call. ADR-0041 D3 sets a per-canary-call cost ceiling of **$0.01** — the harness must enforce this (a canary call exceeding $0.01 is itself a failure).
- For each capability: `SupportsStreaming` → a 1-token streaming call; `SupportsFunctionCalling` → a trivial tool-call probe; `SupportsVision` → a tiny image probe; `MaxContextTokens` → a metadata/declared check (do not actually send a max-context prompt — that would blow the $0.01 ceiling; assert the declared value is plausible / non-zero).
- **Known limitation — vision probe cost.** A minimal vision call still incurs image-token overhead and can exceed the $0.01 per-call ceiling depending on provider image-tokenization. Treat the $0.01 ceiling as the design target; if a provider's smallest possible vision probe genuinely exceeds it, record the actual minimum as a documented known limitation in the Canaries project `README.md` rather than failing the canary purely on the ceiling. Use the smallest image the provider accepts (a 1×1 or minimal-dimension image) to minimize the overhead.
- The harness must distinguish a **capability regression** (provider removed a feature) from a **transient outage** (provider 5xx / timeout). ADR-0041 D3's flip windows (≤24h → Preview, ≥7d → Deprecated) imply the canary records pass/fail history; the simplest v1 is per-run pass/fail with the nightly workflow tracking sustained failure across runs.
- These are **live-network tests** — they are NOT part of the tier-1 unit gate. Mark them so `pr.yml` does not run them by default; they run in the nightly canary workflow and (per D4) as an opt-in PR validation when a model is added/changed. Do NOT make them violate invariant 15 in the unit-test path — invariant 15 says *unit and in-process integration tests* never depend on external services; the canary is a separate Tier (a live provider-reality probe), the same exception class as ADR-0047's container integration tier. Keep it in its own `.Canaries` project, excluded from the unit-test run.
- No `Thread.Sleep` (invariant 51) — use `await` and polling primitives with explicit timeouts.

### `ApprovalState` flip path — durable persistence via a `models.json` PR
- Packet 02 shipped `IApprovalStateWriter` as a **transient per-process in-memory overlay** — and `models.json` is the durable source of `ApprovalState`. **A flip applied through the in-memory writer inside an ephemeral nightly CI job evaporates when the job ends and never reaches the running Node.** Therefore the nightly canary workflow persists an `ApprovalState` change by **opening a PR that edits `models.json`** — catalog-as-data, consistent with the `models.json` loader. The flip is durable once that PR merges; the running Node picks it up on its next load/deploy when it reconciles `ApprovalState` from `models.json`. The in-memory `IApprovalStateWriter` overlay is used only within a single process and is reconciled from `models.json` on load.
- Concretely: a model whose canary fails for ≤24h gets a PR flipping its `models.json` entry to `Preview`; ≥7 days, a PR flipping it to `Deprecated` (D3). The 24h/7d windows are evaluated by the nightly workflow against recorded canary history. The workflow opens the PR (e.g. via `gh pr create` against a branch with the edited `models.json`); a human or auto-merge policy lands it.
- Per ADR-0041 D3 and D10, every flip is recorded in Audit (`HoneyDrunk.Audit`, ADR-0030). **`HoneyDrunk.Audit` is a scaffolded Node** with buildable `HoneyDrunk.Audit.Abstractions` (`IAuditLog`) and `HoneyDrunk.Audit.Data` projects. **Treat `HoneyDrunk.Audit.Abstractions` as a HARD dependency** for the flip-Audit emit: the flip path takes a runtime dependency on `HoneyDrunk.Audit.Abstractions` only (invariant 48 — never `HoneyDrunk.Audit.Data`) and emits an `AuditEntry` on each flip. Verify at execution time that `HoneyDrunk.Audit.Abstractions` is on the package feed; if it is not yet published, treat that as a **blocker to resolve** (get the package published) — not a reason to ship a permanent local seam. Do not architect the flip path around a long-lived local audit-sink interface.
- A canary status flip files a packet per ADR-0008 (D3) — for v1 this can be the nightly workflow opening a GitHub issue on a flip (alongside the `models.json` PR); a full packet-generation pipeline is out of scope. Opening an issue with the model id, the failing capability, and the new state is sufficient.

### Nightly canary workflow
- Add `.github/workflows/canary-models.yml` (or extend an existing scheduled workflow) that runs the `HoneyDrunk.AI.Tests.Canaries` project nightly, per environment. It pulls provider keys from the environment's Vault, runs the canary, records pass/fail, and on sustained failure **opens a PR editing `models.json` to flip `ApprovalState`** (the durable persistence path — see the flip-path section) and opens a tracking issue. It does NOT rely on an in-memory `IApprovalStateWriter` flip surviving the job — that overlay is process-local and evaporates with the ephemeral job.
- The workflow needs provider API keys — supplied via the environment's Vault / GitHub environment secrets, never inline.

### CHANGELOG / version
- Packet 02 already bumped the solution to `0.2.0`. **This packet appends to the existing in-progress `[0.2.0]` entry** in the repo-level `CHANGELOG.md` and the per-package `CHANGELOG.md` for `HoneyDrunk.AI` — it does NOT add a new version section (invariant 27).
- The new `HoneyDrunk.AI.Tests.Canaries` project is a test project — it does not carry the solution version, but per invariant 12 a new project gets a `README.md` from its first commit; a per-package `CHANGELOG.md` on a test project is not required.

## Affected Files
- `src/HoneyDrunk.AI/models.json` — model entries added
- `tests/HoneyDrunk.AI.Tests.Canaries/` — new project (csproj, harness, per-model canaries, README)
- `src/HoneyDrunk.AI/Registry/` — `IApprovalStateWriter` flip path + `IAuditLog` Audit emit
- `.github/workflows/canary-models.yml` — new (or an extension of an existing scheduled workflow); opens a `models.json`-editing PR on a flip
- `HoneyDrunk.AI.slnx` — add the Canaries project
- `CHANGELOG.md` (repo-level, append to `[0.2.0]`), `src/HoneyDrunk.AI/CHANGELOG.md` (append)

## NuGet Dependencies
`tests/HoneyDrunk.AI.Tests.Canaries/HoneyDrunk.AI.Tests.Canaries.csproj` is a new project. Required `PackageReference` entries:
- `HoneyDrunk.Standards` — mandatory on every new .NET project, `PrivateAssets: all` (invariant 26).
- The test framework + assertion + runner packages used by the existing `HoneyDrunk.AI.Tests` project — match the exact package set and versions of `tests/HoneyDrunk.AI.Tests/HoneyDrunk.AI.Tests.csproj` (read that csproj and mirror it; do not guess versions).
- `ProjectReference` to `src/HoneyDrunk.AI/HoneyDrunk.AI.csproj`, `src/HoneyDrunk.AI.Abstractions/HoneyDrunk.AI.Abstractions.csproj`, and the three live provider packages (`HoneyDrunk.AI.Providers.Anthropic`, `HoneyDrunk.AI.Providers.OpenAI`, `HoneyDrunk.AI.Providers.AzureOpenAI`) so the canary can make real provider calls.
- The flip path consumes `HoneyDrunk.Audit.Abstractions` (`IAuditLog`) as a **hard dependency** — add that `PackageReference` to `src/HoneyDrunk.AI/HoneyDrunk.AI.csproj` (`.Abstractions` only, never `HoneyDrunk.Audit.Data`). `HoneyDrunk.Audit` is a scaffolded Node with buildable `Abstractions` + `Data` projects; verify the package is on the feed at execution time. If it is not yet published, treat that as a blocker to resolve (publish it) — not a reason to ship a permanent local audit seam.

## Boundary Check
- [x] All code in `HoneyDrunk.AI`. AI-sector model/canary work maps to the AI Node.
- [x] The canary is a live-provider-reality probe in a dedicated `.Canaries` project — excluded from the tier-1 unit gate, consistent with invariant 15 (unit/in-process tests use no external services; the canary is a separate tier).
- [x] The flip-Audit dependency is on `HoneyDrunk.Audit.Abstractions` only (invariant 48) — `HoneyDrunk.Audit.Data` is never referenced.

## Acceptance Criteria
- [ ] `models.json` carries the initial model lineup for Anthropic, OpenAI, and Azure OpenAI, every entry at `ApprovalState=Preview`
- [ ] Each model entry has a `CostProfile` with a `MaxBudgetPerCallUsd` ceiling and a `RoutingHints` latency tier
- [ ] `HoneyDrunk.AI.Tests.Canaries` project exists with a capability canary per registered model, asserting each declared capability against a cheap live call bounded by the $0.01 per-call ceiling
- [ ] The Canaries project is excluded from the `pr.yml` tier-1 unit-test run; it does not make the unit gate depend on external providers
- [ ] A nightly per-environment workflow runs the canaries, records pass/fail, and on sustained failure persists the `ApprovalState` change by **opening a PR that edits `models.json`** (≤24h → `Preview`, ≥7d → `Deprecated`) and opens a tracking GitHub issue — it does NOT rely on an in-memory `IApprovalStateWriter` flip surviving the ephemeral job
- [ ] The canary harness reads model data strictly through `IModelRegistry` — it never reads the `models.json` embedded resource directly
- [ ] Every `ApprovalState` flip is recorded via `IAuditLog` (`HoneyDrunk.Audit.Abstractions`, a hard dependency, `.Abstractions` only); if the package is not yet on the feed at execution, that is a blocker to resolve, not a reason to ship a permanent local seam
- [ ] No `Thread.Sleep` anywhere in the Canaries project (invariant 51)
- [ ] No version bump — the repo-level and `HoneyDrunk.AI` per-package CHANGELOGs append to the existing in-progress `[0.2.0]` entry
- [ ] The new Canaries project has a `README.md` from its first commit (invariant 12) and references `HoneyDrunk.Standards`
- [ ] Solution builds; `pr.yml` tier-1 gate passes (canaries excluded from that run)

## Human Prerequisites
- [ ] **Provider API keys seeded in Vault** for Anthropic, OpenAI, and Azure OpenAI, at the Vault paths `models.json` references (set up in packet 02's registration). Without these the nightly canary cannot make live calls. This is a portal/Vault action the agent cannot perform.
- [ ] **GitHub environment secrets / Vault access for the nightly workflow** — the `canary-models.yml` workflow needs read access to the provider keys per environment. Configure the GitHub repository environments (`dev`, `staging`, `prod`) and their secret access in the GitHub UI.
- [ ] **Accept the recurring canary cost** — ADR-0041 estimates under $5/month at v1 (~10 models × ~5 capabilities × per-environment nightly runs, each bounded at $0.01). This is a known, accepted Azure/provider cost.
- [ ] The nightly canary workflow is `Actor=Agent` to author; the secret wiring and cost acceptance above are the human prerequisites — they happen before the workflow first runs, not during the agent's PR.

## Referenced ADR Decisions
**ADR-0041 D3 — Capability declaration asserted by canary.** Every registered model has a capability canary in `HoneyDrunk.AI.Tests.Canaries` asserting each declared capability against a cheap live call (per-call $0.01 ceiling). Runs nightly per environment. Flips `ApprovalState` to `Preview` if a canary fails ≤24h, to `Deprecated` if ≥7 days. Files a packet on a status flip.

**ADR-0041 D4 — Adding a model: packet workflow.** A new model is registered at `Preview`, gets a capability canary, the PR cannot merge until the canary passes, and the model stays `Preview` for at least 14 days in production. A follow-up packet flips it to `Approved` after the window and after at least one Studio-internal consumer is pinned to it.

**ADR-0041 D10 — Registry read-only at runtime.** The only runtime mutation is the canary-driven `ApprovalState` flip through `IApprovalStateWriter`; every flip is recorded in Audit per ADR-0030.

**ADR-0041 Operational Consequences.** The canary harness incurs nightly provider cost — bounded by per-call $0.01 ceilings, ~10 models × ~5 capabilities × per-environment runs = under $5/month at v1. Recorded as a known cost.

**Invariant 15 (testing).** Unit tests and in-process integration tests never depend on external services. The capability canary is a deliberate separate tier — a live provider-reality probe — in its own `.Canaries` project, the same exception class as ADR-0047's container integration tier. It is excluded from the unit-test gate.

**Invariant 48 (audit).** Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`; `HoneyDrunk.Audit.Data` is never referenced in production composition.

## Constraints
- **All models start `Preview` (D4).** No model is registered at `Approved`. A separate follow-up packet flips them after the 14-day production preview window.
- **$0.01 per-canary-call ceiling (D3).** Each canary call must be minimal-cost; a call exceeding $0.01 is itself a canary failure. Do not send max-context prompts to test `MaxContextTokens` — assert the declared value instead.
- **Canaries are not unit tests.** Keep them in `HoneyDrunk.AI.Tests.Canaries`, excluded from `pr.yml`'s tier-1 unit run. Invariant 15 forbids external-service dependencies in unit/in-process tests — the canary is a separate live-probe tier and must not contaminate the unit gate.
- **Canary reads via `IModelRegistry` only.** The harness never reads the `models.json` embedded resource directly — model data is resolved strictly through `IModelRegistry`.
- **`ApprovalState` is persisted via a `models.json` PR.** `models.json` is the durable source of approval state; the in-memory `IApprovalStateWriter` overlay is process-local and evaporates with the ephemeral nightly job. The nightly workflow persists a flip by opening a PR that edits `models.json`. Do not rely on an in-memory flip reaching the running Node.
- **No version bump (invariant 27).** Packet 02 is the bumping packet for this initiative on the `HoneyDrunk.AI` solution. This packet appends to the in-progress `[0.2.0]` CHANGELOG entry only.
- **`HoneyDrunk.Audit.Abstractions` is a hard dependency.** `HoneyDrunk.Audit` is a scaffolded Node with buildable `Abstractions` + `Data` projects. The flip-Audit emit consumes `HoneyDrunk.Audit.Abstractions` (`IAuditLog`), `.Abstractions` only, never `HoneyDrunk.Audit.Data`. If the package is not on the feed at execution time, treat that as a blocker to resolve (publish it) — not a reason for a permanent local seam.
- **Provider keys are Vault references.** The nightly workflow resolves keys from Vault / GitHub environment secrets — never inline. Secret scanning is a tier-1 gate.
- **`ModelCapabilityDeclaration` is frozen.** Populate it per model; do not change its shape (ADR-0016).

## Labels
`feature`, `tier-2`, `ai`, `adr-0041`, `wave-3`

## Agent Handoff

**Objective:** Populate `models.json` with the initial model lineup and add the capability-canary harness + nightly flip workflow.

**Target:** `HoneyDrunk.AI`, branch from `main`.

**Context:**
- Goal: Validate every registered model's declared capabilities against provider reality, and drive `ApprovalState` from canary results.
- Feature: ADR-0041 AI Model Registry and Approval Workflow rollout, Wave 3.
- ADRs: ADR-0041 D3/D4/D10 (primary), ADR-0016 (frozen `ModelCapabilityDeclaration`), ADR-0030 (Audit emit on flip).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:02` — hard. The registry, `IModelRegistry`, `IApprovalStateWriter`, and `models.json` must exist before models and canaries are added.

**Constraints:**
- All models start `Preview`; no model registered at `Approved`.
- $0.01 per-canary-call ceiling — minimal-cost probes only; vision probe may exceed it (known limitation, documented in the Canaries README).
- Canary reads model data strictly through `IModelRegistry` — never reads `models.json` directly.
- `ApprovalState` flips are persisted by opening a `models.json`-editing PR — `models.json` is the durable source; the in-memory overlay is process-local.
- Canaries live in their own `.Canaries` project, excluded from the tier-1 unit gate.
- No version bump — append to the in-progress `[0.2.0]` CHANGELOG.
- `HoneyDrunk.Audit.Abstractions` is a hard dependency for the flip-Audit emit (`.Abstractions` only); absence on the feed is a blocker, not a permanent-seam excuse.
- Provider keys are Vault references — never inline.

**Key Files:**
- `src/HoneyDrunk.AI/models.json`
- `tests/HoneyDrunk.AI.Tests.Canaries/` — new project
- `src/HoneyDrunk.AI/Registry/` — flip path
- `.github/workflows/canary-models.yml`

**Contracts:**
- Consumes `IModelRegistry`, `IApprovalStateWriter` from packet 02.
- Consumes `IAuditLog` / `AuditEntry` from `HoneyDrunk.Audit.Abstractions` (hard dependency, `.Abstractions` only).
- No Abstractions shape change in this packet.
