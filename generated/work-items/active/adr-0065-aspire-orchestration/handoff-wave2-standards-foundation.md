# Handoff — Wave 2: Standards Foundation

**Initiative:** `adr-0065-aspire-orchestration`
**Wave transition:** Wave 1 (governance + reference) → Wave 2 (Standards extensions + template)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 1 landed

- **Packet 00** — ADR-0065 flipped to **Accepted**. Two new invariants added to `constitution/invariants.md` under a new `## Local-Dev Orchestration Invariants` section. The numbers come from the ADR-0065 row in `constitution/invariant-reservations.md` (reserved pair `78–79` at authoring; shifted up at merge if a parallel packet 00 raced ahead):
  1. Every multi-process containerized Node ships an Aspire AppHost project as its local-dev inner loop. Single-process Nodes may ship one optionally; library-only Nodes (Kernel, Vault, Transport, Standards, Auth, Web.Rest, Data) have no runtime and are exempt.
  2. Aspire-generated infrastructure templates (Bicep, ARM) are never used as the production deployment authority. Production deployment authoring stays in `HoneyDrunk.Standards` shared workflows and each Node's curated Bicep per ADR-0015.
- **Packet 01** — `infrastructure/reference/tech-stack.md` moved `.NET Aspire` from Planned / Future to the adopted section with the local-dev-only framing; added the dev Service Bus namespace row. `.claude/agents/scope.md` carries the AppHost-requirement rule for new multi-process Nodes. `.claude/agents/review.md` carries two new review-checklist items (multi-process Node AppHost presence; no Aspire-generated Bicep in production paths).

ADR-0065's decisions are now live rules. Packet 02 implements the Standards-side foundation every per-Node AppHost in the Grid will consume.

## What Wave 2 must deliver (packet 02)

Build the Standards alignment per ADR-0065 D6 in **`HoneyDrunk.Standards`**:

- **`HoneyDrunk.Standards.Aspire`** (new package) — `HoneyDrunkAspireExtensions` static class with:
  - `AddGridTelemetry<T>(this IResourceBuilder<T>)` — wires OTLP env vars on a resource builder; default endpoint is Aspire's dashboard.
  - `AddGridCosmosEmulator(IDistributedApplicationBuilder, string name)` — Cosmos Emulator container, Linux mode (per D9).
  - `AddGridAzurite(IDistributedApplicationBuilder, string name)` — Azurite emulator container.
  - `AddGridServiceBusDev(IDistributedApplicationBuilder, string name)` — connection-string resource from `dotnet user-secrets` key `ConnectionStrings:ServiceBus`; creates per-session subscription on AppHost launch **and deletes it on AppHost shutdown via an `IDistributedApplicationLifecycleHook`** (best-effort; orphan cleanup documented in packet 03).
  - `AddGridKeyVaultDev(IDistributedApplicationBuilder, string name)`, `AddGridAppConfigDev(IDistributedApplicationBuilder, string name)` — connection-string resources, dev-session-auth.
  - (AppHost-level composition method) `AddPulseCollector(this IDistributedApplicationBuilder, bool opt = false)` — the D4 dual-emit opt-in switch.
- **`HoneyDrunk.Standards.Templates.AspireAppHost`** (new template package) — a `dotnet new` template producing a `{Node}.AppHost` scaffold with the analyzer baseline, the Aspire AppHost SDK target, and a starter `Program.cs` referencing the Grid extensions.
- Pin the Aspire SDK version inline on each new `PackageReference`. The Standards solution does **not** use Central Package Management today (verified — no `Directory.Packages.props`); do not introduce CPM in this packet.
- Tests use Aspire's non-launching syntax-check mode — no Docker Desktop, no live Azure (invariant 15, D10).
- This is the **version-bumping packet**: bump every non-test `.csproj` in the `HoneyDrunk.Standards` solution to the same new minor version in one commit (invariant 27). New public surface; additive minor bump per ADR-0035.

## Frozen / do-not-touch

- **`HoneyDrunk.Standards` shared workflows + curated Bicep — the production deployment authority (ADR-0015, ADR-0065 D5).** Wave 2 ships local-dev assets; nothing here writes `azd` paths, generated production Bicep, or `AzurePublisher` outputs to the production deployment surface. The new packages do not change how production deploys.
- **The existing `HoneyDrunk.Standards` analyzer + EditorConfig surface.** New projects reference `HoneyDrunk.Standards` with `PrivateAssets: all` (invariant 26) just like every other Standards-solution project; no analyzer rule changes here.

## Invariants binding Wave 2

- **Invariant 13** — all public APIs carry XML documentation.
- **Invariant 15** — unit tests do not depend on external services. The Aspire extension tests run in non-launching mode; no Docker Desktop, no Azure, no Cosmos Emulator at test time.
- **Invariant 26** — new projects reference `HoneyDrunk.Standards` with `PrivateAssets: all`.
- **Invariant 27** — all projects in a solution share one version and move together. Packet 02 is the bumping work-item: bump every non-test `.csproj` in one commit. Partial bumps are forbidden.
- **Invariant 12** — new packages get `CHANGELOG.md` + `README.md` from the first commit. Unchanged packages get no per-package CHANGELOG entry.
- **D5 (the second new Aspire invariant)** — Aspire-generated Bicep / ARM is never the production deployment authority. Nothing in this packet writes such files.

## Aspire SDK version pin — record in the PR

Confirm the current stable Aspire SDK version at execution time and pin all new `Aspire.*` `PackageReference`s in this packet to that version inline (the Standards solution has no CPM today; pin inline). Record the version in the PR description.

## Acceptance gate for the wave

Packet 02's PR passes the `pr-core.yml` tier-1 gate. The new packages (`HoneyDrunk.Standards.Aspire`, `HoneyDrunk.Standards.Templates.AspireAppHost`) compile, tests pass in non-launching mode, and the solution version is bumped one minor across every non-test `.csproj`.

**Human package release at the Wave 2 boundary — agents never tag.** Packet 04 (Notify.AppHost) and packet 05 (Pulse.AppHost) compile against `HoneyDrunk.Standards.Aspire` and (for packet 04) `HoneyDrunk.Standards.Templates.AspireAppHost`. Those artifacts reach the NuGet feed only after a human pushes a git release tag on `HoneyDrunk.Standards`. After packet 02 merges, a human must tag/release `HoneyDrunk.Standards` so packets 04 and 05 can compile. This is a hard gate between Wave 2 and Wave 4.

Wave 3 (packet 03 — dev Service Bus provisioning, Human) and Wave 4 (packets 04 + 05) start after this human release. Packet 03 can in practice start as soon as packet 00 merges (it depends only on the ADR being Accepted, not on the Standards extensions) — but its output (the `sb-hd-dev` namespace) is consumed by packet 04 at launch time, so it should be completed before packet 04's developer verification step.
