---
name: Repo Feature
type: repo-feature
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0053", "wave-3"]
dependencies: ["packet:00"]
adrs: ["ADR-0053", "ADR-0005", "ADR-0047"]
accepts: ["ADR-0053"]
wave: 3
initiative: adr-0053-release-cadence
node: honeydrunk-architecture
---

# Author the local-dev `## Quick Start` template and the "first 60 seconds" audit playbook

## Summary
Author the canonical `## Quick Start` section template (per ADR-0053 D11) for every Live Node's `repos/{name}/overview.md`, and the paired "first 60 seconds" audit playbook that runs the template against every Live Node and surfaces any Node that misses the 60-second boot target. The template + playbook is the substrate; packet 08 executes the audit; per-Node remediation packets land in each Node's own track.

## Context
ADR-0053 D11 reads: "Every Node must boot locally with `dotnet run` against either (a) the InMemory contract-compatible fakes per Invariant 15, or (b) the Testcontainers-driven Tier 2b dependencies per ADR-0047 D4. No Azure dependency is required for first-line development work. The forcing function: the first 60 seconds of trying a Node must be `git clone && dotnet run`."

The decomposition mirrors ADR-0045 packet 07's playbook-not-per-Node-packets choice. Writing 12+ packets one per Node would prematurely decompose work that has not been validated against each Node's actual boot path. **This packet ships the template + the audit checklist; packet 08 runs the audit.** Each Node that misses the 60-second target becomes a small follow-up in that Node's own track.

**Template scope per ADR-0053 D11.** "A `## Quick Start` section with: clone command, prerequisites (Docker for Testcontainers, .NET SDK version), boot command, expected log lines. If a Node cannot meet the 60-second target, the gap is recorded as a follow-up."

The template needs to handle both Node shapes:
- **Library-only Nodes** (Kernel, Vault, Transport, Architecture, Standards, etc.) — boot path is "build the solution; run the unit tests"; the 60-second target is "tests run green, no Azure dependency."
- **Deployable Nodes** (Notify.Functions, Notify.Worker, Pulse.Collector, future Studios, future AI-sector deployables) — boot path is "build; `dotnet run` against the InMemory profile or Testcontainers; expected log lines"; the 60-second target is "the process boots and emits the readiness log line."

**Vault bootstrap is env-var-driven per ADR-0005.** "Local secrets come from `.env` files (gitignored) loaded into environment variables; `HoneyDrunk.Vault` reads from env vars when configured for the `local` profile. No real Key Vault is required to boot a Node locally." The template documents this path; each Node's Quick Start lists its required env vars (with placeholder values; no actual secrets).

This is a docs packet. No code, no .NET project.

## Scope
- `infrastructure/conventions/local-dev-quick-start-template.md` (new) — the canonical `## Quick Start` template covering both library-only and deployable Node shapes.
- `infrastructure/conventions/local-dev-audit-playbook.md` (new) — the "first 60 seconds" audit playbook that runs the template against a Node and records the result (pass / miss + the specific gap).
- `infrastructure/README.md` — reference the two new docs.

## Proposed Implementation
1. **`infrastructure/conventions/local-dev-quick-start-template.md`** — the canonical `## Quick Start` section template. Two variants:
   - **Library-only Node template:**
     ```markdown
     ## Quick Start

     **Prerequisites:**
     - .NET SDK <version> (check with `dotnet --list-sdks`)

     **Clone and build:**
     ```sh
     git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.<Node>.git
     cd HoneyDrunk.<Node>
     dotnet build
     dotnet test
     ```

     **Expected outcome (first 60 seconds):**
     - `dotnet test` runs green
     - No Azure provisioning required
     ```
   - **Deployable Node template:**
     ```markdown
     ## Quick Start

     **Prerequisites:**
     - .NET SDK <version>
     - Docker Desktop (for Testcontainers-driven Tier 2b dependencies, if applicable)
     - A copy of `.env.example` renamed to `.env` (gitignored; placeholder values are fine for local boot)

     **Clone and boot:**
     ```sh
     git clone https://github.com/HoneyDrunkStudios/HoneyDrunk.<Node>.git
     cd HoneyDrunk.<Node>
     cp .env.example .env
     dotnet run --project src/<entrypoint-project>
     ```

     **Expected log lines (first 60 seconds):**
     - `<canonical readiness line — e.g. "Application started. Press Ctrl+C to shut down.">`
     - Optionally: `<a Node-specific "ready" line — health-check endpoint, queue subscription, etc.>`

     **No Azure dependency required.** The Node boots against InMemory contract-compatible fakes (per invariant 15) or Testcontainers-driven dependencies (per ADR-0047 D4). Real Azure resources are not provisioned by `dotnet run`.
     ```
   - The template covers **placeholders** the executing agent (or operator) substitutes: `<Node>`, `<version>`, `<entrypoint-project>`, `<canonical readiness line>`, the env-var list with placeholder values.
   - **No real secrets** in any per-Node Quick Start. The env-var list documents the **names** of the secrets (e.g. `NOTIFY_RESEND_API_KEY`) with a placeholder value (`<your-resend-api-key>`); the actual value is gitignored in `.env`.
2. **`infrastructure/conventions/local-dev-audit-playbook.md`** — the audit playbook describing how to run the Quick Start template against a Node:
   - **Step 1 — Prerequisites check.** Confirm the Node's `repos/{name}/overview.md` carries a `## Quick Start` section. If missing, record as a gap.
   - **Step 2 — Clone-and-boot timing.** On a clean machine state (or a fresh clone), execute the documented `git clone && dotnet run` (or `dotnet test` for library-only Nodes). Time the first-run from `dotnet run` invocation to the canonical readiness log line. Target: ≤ 60 seconds.
   - **Step 3 — Azure-dependency check.** Confirm the boot path does not reach an Azure endpoint (no `AZURE_KEYVAULT_URI` resolution against a real vault; no App Configuration endpoint resolution; no Azure SDK authentication step). Local profile = `local`; env-var-driven secrets per ADR-0005.
   - **Step 4 — Record the result.** Pass / miss + the specific gap. Misses become follow-up packets in the Node's own track (e.g. "the Node requires a real Service Bus connection string to boot — add a `local` profile with an InMemory broker") — those packets are written by the Node's own scope pass, not pre-written here.
   - **Step 5 — Aggregate.** The audit produces a Grid-wide summary (each Node + pass/miss + gap-if-miss). Packet 08 runs the audit and lands the summary as a doc in `infrastructure/`.
3. **`infrastructure/README.md`** — add rows for the two new conventions docs.

## Affected Files
- `infrastructure/conventions/local-dev-quick-start-template.md` (new)
- `infrastructure/conventions/local-dev-audit-playbook.md` (new)
- `infrastructure/README.md`

## NuGet Dependencies
None. This packet authors documentation; no .NET project is created or modified.

## Boundary Check
- [x] All artefacts in `HoneyDrunk.Architecture` — cross-Node Grid conventions live here.
- [x] No code change in any Node — the template is applied per Node in packet 08 (audit) and downstream per-Node packets (remediation).
- [x] Deliberately does not pre-write per-Node packets — each Node's gap is recorded by the audit and decomposed in that Node's own track (mirroring the ADR-0045 packet 07 pattern).

## Acceptance Criteria
- [ ] `infrastructure/conventions/local-dev-quick-start-template.md` exists with the two template variants (library-only Nodes; deployable Nodes), each covering prerequisites, clone-and-build/run commands, expected log lines, and the no-Azure-dependency rule
- [ ] The template includes the `.env`-driven local-secret convention per ADR-0005 and explicitly forbids real secret values in `repos/{name}/overview.md`
- [ ] `infrastructure/conventions/local-dev-audit-playbook.md` exists with the five-step audit recipe (prerequisites check, clone-and-boot timing, Azure-dependency check, record result, aggregate)
- [ ] `infrastructure/README.md` references both new conventions docs in its index
- [ ] No per-Node packet is pre-written here — packet 08 runs the audit; per-Node remediation packets land in each Node's own track
- [ ] No invariant change in this packet (invariants land in packet 00)
- [ ] No `.csproj` version bump — Markdown-only

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0053 D11 — Local-dev parity.** "Every Node must boot locally with `dotnet run` against InMemory or Testcontainers dependencies; no Azure dependency required for first-line dev work. The first 60 seconds of trying a Node must be `git clone && dotnet run`. The 'first 60 seconds' experience is documented per Node in `repos/{name}/overview.md`. If a Node cannot meet the 60-second target, the gap is recorded as a follow-up."

**ADR-0053 D12 — Configuration parity.** Environment-specific configuration lives in Azure App Configuration; local profile reads from gitignored `.env` files loaded as environment variables.

**ADR-0053 D16 Phase 5 — Local-dev parity audit.** "Every Live Node's `repos/{name}/overview.md` gets a `## Quick Start` section per D11. Any Node that cannot meet the 60-second target gets a follow-up packet."

**ADR-0005 — Vault env-var bootstrap.** Local secrets come from `.env` files (gitignored) loaded as env vars; `HoneyDrunk.Vault` reads from env vars on the `local` profile. No real Key Vault required to boot locally.

**ADR-0047 D4 — Tier 2b Testcontainers.** Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception to invariant 15; they are local, ephemeral, and deterministic. Deployable Nodes that need a Tier 2b dependency for local boot reference Testcontainers in their Quick Start.

**Invariant 15 — Unit tests and in-process integration tests never depend on external services.** "Use InMemory providers (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`) for isolation. Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception, allowed because they are local, ephemeral, and deterministic."

## Constraints
> **Invariant 8 — Secret values never appear in logs, traces, exceptions, or telemetry — or in committed files.** The Quick Start template uses placeholder values for env-var examples (e.g. `<your-resend-api-key>`). Real secret values are gitignored in `.env`. The template forbids real secrets in `overview.md`.

> **Invariant 9 — Vault is the only source of secrets.** The local profile reads from env vars (loaded from `.env`); the env-var path is `HoneyDrunk.Vault`'s `local` profile per ADR-0005. No Node reads secrets directly from `Environment.GetEnvironmentVariable` outside the Vault path.

> **Invariant 15 — Unit tests and in-process integration tests never depend on external services.** The library-only Node template's "expected outcome" is `dotnet test` running green with no external service.

- **Template, not per-Node packets.** Do not pre-write per-Node Quick Start sections here — those land per-Node via packet 08's audit and downstream remediation.
- **Concise.** The template is a section template, not a tutorial. Match the length and tone of `repos/HoneyDrunk.Kernel/overview.md`'s existing structure (short, scannable).
- **No real secrets.** Placeholder env-var values only; real values gitignored.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0053`, `wave-3`

## Agent Handoff

**Objective:** Author the canonical `## Quick Start` section template and the paired audit playbook so packet 08 can run the "first 60 seconds" audit Grid-wide.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Codify D11's local-dev parity requirement once; downstream per-Node application is mechanical.
- Feature: ADR-0053 Environments, Branching, and Release Cadence rollout, Wave 3.
- ADRs: ADR-0053 D11/D12/D16 Phase 5 (primary), ADR-0005 (Vault env-var bootstrap), ADR-0047 D4 (Testcontainers).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0053 should be Accepted before its local-dev parity playbook lands.

**Constraints:**
- Template only — no per-Node packets pre-written.
- Two variants (library-only Node; deployable Node).
- No real secrets in any template example.
- Concise; section template, not a tutorial.

**Key Files:**
- `infrastructure/conventions/local-dev-quick-start-template.md` (new)
- `infrastructure/conventions/local-dev-audit-playbook.md` (new)
- `infrastructure/README.md`

**Contracts:** None changed.
