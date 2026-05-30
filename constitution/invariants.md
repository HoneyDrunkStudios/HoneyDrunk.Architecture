# Grid Invariants

Rules that must never be violated across the HoneyDrunk Grid. Canary tests enforce these at build time. Architecture reviews enforce them at design time.

## Dependency Invariants

1. **Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.**
   Only `Microsoft.Extensions.*` abstractions are permitted.

2. **Runtime packages depend on Abstractions, never on other runtime packages at the same layer.**
   `HoneyDrunk.Transport` depends on `HoneyDrunk.Kernel.Abstractions`, not `HoneyDrunk.Kernel`.

3. **Provider packages depend on their parent Node's contracts, not internal implementation details.**
   When a Node splits contracts into a separate package (e.g. `HoneyDrunk.Kernel.Abstractions`),
   providers reference that package. When a Node bundles contracts into its main package
   (e.g. `HoneyDrunk.Vault`), providers reference the main package. In either case, providers
   must only consume exported interfaces — never internal types, caches, or resilience plumbing.

4. **No circular dependencies.** The dependency graph is a DAG. Kernel is always at the root.

## Context Invariants

5. **GridContext must be present in every scoped operation.**
   Every HTTP request, message handler, and background job must have a populated `IGridContext`, including a non-null `TenantId`.

6. **CorrelationId is never null or empty, and TenantId is never absent, in a live GridContext.**
   `CorrelationId` is generated at the entry point and propagated through all downstream calls. Missing tenant context defaults to the `TenantId.Internal` sentinel; external tenant values must be valid `TenantId` ULIDs.

7. **Context mappers are static and stateless.**
   `HttpContextMapper`, `MessagingContextMapper`, `JobContextMapper` — no instance state.

## Secrets & Trust Invariants

8. **Secret values never appear in logs, traces, exceptions, or telemetry.**
   Only secret names/identifiers may be traced. `VaultTelemetry` enforces this.

9. **Vault is the only source of secrets.**
   No Node reads secrets directly from environment variables, config files, or provider SDKs. All access goes through `ISecretStore`.

9a. **Tenant-scoped secrets are a Vault usage pattern, not an `ISecretStore` contract change.**
   Tenant-owned secrets use `tenant-{tenantId}-{secretName}` and resolve through `TenantScopedSecretResolver`; `TenantId.Internal` uses the standard node-level secret path.

10. **Auth tokens are validated, never issued.**
    HoneyDrunk.Auth validates JWT Bearer tokens. It is not an identity provider.

## Packaging Invariants

11. **One repo per Node (or tightly coupled Node family).**
    Each repo has its own solution, CI pipeline, and versioning.

12. **Semantic versioning with CHANGELOG and README.**
    Breaking changes bump major. New features bump minor. Fixes bump patch. Changelogs follow [Keep a Changelog](https://keepachangelog.com/) format. Two tiers:
    - **Repo-level `CHANGELOG.md`** (next to the `.slnx` file): Mandatory. Every repo must have one. Covers the full release holistically. Every version that ships must have an entry here. This is the source for auto-generated release notes (see `HoneyDrunk.Actions` `release/generate-notes` composite action).
    - **Per-package `CHANGELOG.md`** (inside each package directory): Updated only when that specific package has functional changes. Do not add noise entries for packages that were version-bumped solely to align with the solution (see invariant 27). Consumers use these to understand what changed in the package they depend on.
    Every package directory must also contain a `README.md` describing the package's purpose, installation, and public API surface. New projects must have both files from the first commit.

13. **All public APIs have XML documentation.**
    Enforced by HoneyDrunk.Standards analyzers.

## Testing Invariants

14. **Canary tests validate cross-Node boundaries.**
    Each Node that depends on another has a `.Canary` project verifying integration assumptions.

15. **Unit tests and in-process integration tests never depend on external services.**
    Use InMemory providers (`InMemorySecretStore`, `InMemoryBroker`, `InMemoryQueue`) for isolation. Container-based integration tests (Tier 2b per ADR-0047) are the scoped exception, allowed because they are local, ephemeral, and deterministic. See ADR-0047 D4.

16. **No test code in runtime packages.**
    Tests live in dedicated `.Tests` or `.Canary` projects only.

50. **Every Node has a `*.Tests.Unit` project; deployable Nodes also have a `*.Tests.Integration` project; HTTP-fronted Nodes also have a `*.Tests.E2E` project.**
    A missing required test tier is a CI gate failure. See ADR-0047 D1, D11.

51. **Test code contains no `Thread.Sleep`.**
    Async work waits via `await`, polling primitives with explicit timeouts, or synchronously-completing fakes. `Thread.Sleep` is a CI flakiness multiplier. Enforced by an analyzer rule on test projects. See ADR-0047 D10.

## Infrastructure & Configuration Invariants

17. **One Key Vault per deployable Node per environment.**
    Named `kv-hd-{service}-{env}`, with Azure RBAC enabled. Access policies are forbidden. Library-only Nodes (Kernel, Vault, Transport, Architecture) have no vault. See ADR-0005.

18. **Vault URIs and App Configuration endpoints reach Nodes via environment variables.**
    `AZURE_KEYVAULT_URI` and `AZURE_APPCONFIG_ENDPOINT` are set as App Service config at deploy time. Never derived by convention, never hardcoded. See ADR-0005.

19. **Service names in Azure resource naming must be ≤ 13 characters.**
    Required to fit within Azure's 24-character Key Vault name limit (`kv-hd-{service}-{env}`). See ADR-0005.

20. **No secret may exceed its tier's rotation SLA without an active exception.**
    Tier 1 (Azure-native): ≤ 30 days. Tier 2 (third-party via rotation Function): ≤ 90 days. Certificates: auto-renewed 30 days before expiry. Exceptions must be logged in Log Analytics. See ADR-0006.

21. **Applications must never pin to a specific secret version.**
    All secret reads resolve the latest version via `ISecretStore`. Pinning breaks Event Grid cache invalidation and rotation propagation. See ADR-0006.

22. **Every Key Vault must have diagnostic settings routed to the shared Log Analytics workspace.**
    Required for rotation SLA monitoring, unauthorized access alerting, and audit. See ADR-0006.

## Work Tracking Invariants

23. **Every tracked work item has a GitHub Issue in its target repo.**
    No work tracked exclusively in packet files, chat logs, or external tools. Issues live where the code lives. See ADR-0008.

24. **Issue packets are immutable once filed as a GitHub Issue.**
    Filing is the point of no return. Before a packet is filed, it may be amended to fill in missing operational context (e.g. NuGet dependencies, key files, constraints) without violating this rule. After filing, state lives on the org Project board, never in the packet file. If requirements change materially post-filing, write a new packet rather than editing the old one. See ADR-0008.

25. **Dispatch plans are initiative narratives, not live state.**
    The org Project board is the source of truth for in-flight work. Dispatch plans are updated at wave boundaries as historical records. See ADR-0008.

26. **Issue packets for .NET code work must include an explicit `## NuGet Dependencies` section.**
    Any packet that creates or modifies .NET projects must list every `PackageReference` entry required — both additions to existing projects and the full reference list for new projects. `HoneyDrunk.Standards` must be explicitly listed on every new .NET project (StyleCop + EditorConfig analyzers, `PrivateAssets: all`). Cloud agent execution cannot infer or guess package lists; an absent section is grounds to stop and flag rather than proceed. This section must be present before the packet is filed as a GitHub Issue (see invariant 24 — pre-filing amendments are permitted; post-filing corrections require a new packet).

27. **All projects in a solution share one version and move together.**
    When a version bump is warranted, every `.csproj` in the solution (excluding test projects) is updated to the same new version in a single commit. Partial bumps — where some projects in a solution are on a different version than others — are forbidden. Releases are triggered by pushing a git tag; agents never push tags. The first packet to land on a solution in an initiative bumps the version; subsequent packets on the same solution append to the CHANGELOG only. The repo-level `CHANGELOG.md` must always get an entry for the new version. Per-package changelogs are updated only for packages with actual changes — do not add alignment-bump noise entries (see invariant 12). See invariant 26 and ADR-0008.

## AI Invariants

28. **Application code must never hardcode a model name or provider.**
    All model selection goes through `IModelRouter` in HoneyDrunk.AI. Routing policies are stored in App Configuration (ADR-0005) and are operator-configurable without a redeploy. See ADR-0010.

29. **Observation connectors must delegate credential resolution to Vault.**
    No connector stores credentials directly. Connection secrets (webhook secrets, API tokens for external services) are resolved via `ISecretStore` at connection establishment. See ADR-0010.

30. **HoneyDrunk.Observe events must be normalized to the canonical observation format before routing out of the Observe boundary.**
    Raw external formats (GitHub webhook JSON, Azure alert schema) never cross the Observe boundary — only normalized `IObservationEvent` types. See ADR-0010.

44. **Downstream AI-sector Nodes take a runtime dependency only on `HoneyDrunk.AI.Abstractions`.**
    Composition against `HoneyDrunk.AI` and any `HoneyDrunk.AI.Providers.*` package is a host-time concern resolved at application startup from App Configuration. This is the same abstraction/runtime split applied for Vault and Transport, restated here because it is the specific rule that allows blocked AI-sector Nodes (Capabilities, Operator, Agents, Memory, Knowledge, Evals) to proceed on `Abstractions` alone without waiting for provider packages. See ADR-0016 D9.

45. **Token cost rates, routing policies, and capability declarations are sourced from Azure App Configuration via Vault's `IConfigProvider`.**
    Hardcoded rates, policies, or capability declarations in application code are forbidden. Rate-table refresh is operator-driven — change the config value, restart or hot-reload, no deploy required. This applies in particular to the cost-rate table consumed by `ICostLedger`: token prices per model are operator-configurable, never compiled constants. See ADR-0016 D5 and ADR-0005.

46. **The HoneyDrunk.AI Node CI must include a contract-shape canary that fails the build on shape drift to `IChatClient`, `IEmbeddingGenerator`, `IModelProvider`, or `IModelRouter` without a corresponding version bump.**
    These four are the hot-path abstractions every downstream consumer compiles against. Accidental shape drift on any of them breaks every AI-sector Node simultaneously. The canary makes this a compile-time failure at AI's own CI, not a discovery at consumer sites. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.AI.Abstractions`; the obligation is to keep the gate, not to use any specific implementation. See ADR-0016 D8.

## Code Review Invariants

31. **Every PR traverses the tier-1 gate before merge.**
    Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken. See ADR-0011 D2 and D5.

32. **Agent-authored PRs must link to their packet in the PR body.**
    The review agent resolves the packet via this link and uses it as the primary scope anchor. Absent the link, the PR is treated as out-of-band, must carry the `out-of-band` label, and receives a degraded review in which the agent runs against the Grid context only (invariants, boundaries, relationships, diff) without a packet-scope check. See ADR-0011 D3 and D9.

33. **Review-agent and scope-agent context-loading contracts are coupled.**
    The set of files loaded by the review agent (per `.claude/agents/review.md`) must be a superset of the set loaded by the scope agent (per `.claude/agents/scope.md`). Divergence is an anti-pattern; updates to either agent's context-loading section must be mirrored in the other. The coupling exists so there is no class of defect the scope agent could introduce at packet-authoring time that the review agent cannot catch at PR time for lack of information. See ADR-0011 D4.

52. **Every non-draft PR on an `enabled` repo runs the cloud-wired `review` agent.**
    A repo is `enabled` when it carries a `.honeydrunk-review.yaml` with `enabled: true`. Skip is via the `skip-review` PR label or `enabled: false` config — both explicit, both visible. See ADR-0044 D1 and D11.

53. **Agent-authored PRs touching a high-risk Node receive two independent LLM-review perspectives before merge.**
    The catalog of high-risk Nodes lives in `catalogs/grid-health.json` under the `review_risk_class` field once ADR-0044 packet 13 lands. Until that field exists, this invariant is accepted as the Phase-3 target state but is not enforceable. The second perspective is a contrarian-prompt pass by default; the human may also invoke `refine` against the packet and diff for manual escalation. Separate multi-agent cloud review modes are intentionally out of scope for ADR-0044. See ADR-0044 D8.

## Hosting Platform Invariants

34. **Containerized deployable Nodes run on Azure Container Apps, named `ca-hd-{service}-{env}`, one per Node per environment, with system-assigned Managed Identity.**
    See ADR-0015.

35. **One shared Container Apps Environment (`cae-hd-{env}`) and one shared Azure Container Registry (`acrhdshared{env}`) serve every containerized Node within a given environment.**
    Per-Node compute environments or registries are forbidden without a follow-up ADR. See ADR-0015.

36. **Container App revision mode is `Multiple` with explicit traffic splitting on deploy.**
    Single-revision mode is forbidden — it removes the rollback seam. See ADR-0015.

## Grid CI/CD Invariants

37. **`HoneyDrunk.Actions` is the source of truth for shared CI/CD configuration.** Shared tool configurations (gitleaks rules, CodeQL query packs, Trivy policy, dotnet-format rules, etc.) live under `HoneyDrunk.Actions/.github/config/`. Caller repos do not duplicate these files; they consume them via reusable-workflow checkout at job runtime. A caller repo may commit a `.<tool>.<ext>` at its root as a per-repo override, which is expected to extend the shared baseline rather than replace it. See ADR-0012 D2, D3.

38. **Reusable workflows invoke tool CLIs directly.** Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

39. **Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions.** Callers that omit `permissions:` inherit the repository default, which is insufficient for any reusable workflow that requests a `write` scope. Validation failure is not detected until the next scheduled run; grid-health (invariant 40) is the safety net. See ADR-0012 D5.

40. **Grid pipeline health is centrally visible.** The `HoneyDrunk.Actions` `🕸️ Grid Health` issue is the single canonical view of CI/CD state across the Grid, updated at least daily by the grid-health aggregator. Staleness of that issue is itself a signal — the aggregator's own failure surfaces as the issue not updating. Real-time per-failure notification is separately delivered by the operator's GitHub profile notification settings ("Only notify for failed workflows"), and both mechanisms are mandatory. See ADR-0012 D6, D7.

41. **New Grid repos are added to `HoneyDrunk.Architecture/repos/` at creation time.** The grid-health aggregator reads the repo catalog to know which repos to poll; a repo missing from the catalog is invisible to grid observability. This invariant re-mandates the existing ADR-0008 / architecture-repo convention from the CI/CD visibility angle. See ADR-0012 D6.

## Hive Sync Invariants

37. **Completed issue packets are moved to `completed/`.** When a filed issue is closed on GitHub, the `hive-sync` agent moves its source packet from `generated/issue-packets/active/` to `generated/issue-packets/completed/` and updates the path key in `generated/issue-packets/filed-packets.json`. No other agent moves packets between lifecycle directories. The `hive-sync` agent may update existing entries' paths in `filed-packets.json` but may not add or remove entries (that remains the `file-issues` agent's exclusive concern). See ADR-0014 D2, D4.

38. **The Architecture repo tracks all Hive board items.** Every issue on The Hive (org Project #4) is represented in either an initiative tracking file (for packet-originated work, including `active-initiatives.md`, `archived-initiatives.md`, etc.) or `initiatives/board-items.md` (for non-initiative work — nightly-security issues, grid-health-aggregator issues, and any other issue mirrored onto The Hive without a `filed-packets.json` entry). The `hive-sync` agent is responsible for maintaining this correspondence and runs through OpenClaw scheduled/manual execution. See ADR-0014 D1, D3.

## Multi-Tenant Boundary Invariants

39. **Tenant mechanics stay at intake and post-dispatch boundaries.** Tenant resolution, tenant rate-limit checks, billing-event emission, and tenant-scoped secret lookup must live in intake middleware/orchestration edges or post-dispatch tails. Core dispatch paths for internal Grid callers must remain tenant-agnostic and default to `TenantId.Internal` without caller-specific branches. See ADR-0026.

## Communications Invariants

40. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Communications.Abstractions`.** Composition against `HoneyDrunk.Communications` is a host-time concern; packaged testing fixtures, when introduced, are test-time only. See ADR-0019.

41. **Preference enforcement, cadence rules, and suppression logic for outbound messages live in HoneyDrunk.Communications, not in HoneyDrunk.Notify.** Notify owns delivery mechanics; Communications owns decision logic. See ADR-0019 D4.

42. **Every orchestrated send records a decision-log entry via `ICommunicationDecisionLog`.** A send without a recorded decision is a build or runtime failure, depending on the enforcement point selected by the consuming host. See ADR-0019.

43. **Communications CI must include a contract-shape canary for the hot-path orchestration contracts.** Shape drift on `ICommunicationOrchestrator`, `IMessageIntent` / `MessageIntent`, `IPreferenceStore`, or `ICadencePolicy` is a build failure unless paired with an intentional version bump. See ADR-0019 D8.

## Audit Invariants

47. **Durable, attributable security, action, and data-change events are emitted to the `HoneyDrunk.Audit` substrate via `IAuditLog`, on a durable channel separate from observability telemetry.**
    Login attempts, authorization grants and denials, privileged-action execution, system/integration activity, and record create/update/delete events are recorded durably and attributably through `IAuditLog`. Auditable events routed only to sampled or retention-bounded observability (Pulse / Loki) are a boundary violation — observability answers "is the system healthy in aggregate," audit answers "who did what, when, against what, and was it allowed." Data-change details that include sensitive fields must be redacted before append. The audit channel and the telemetry channel are never merged: audit *records* are not telemetry and never flow to Pulse, and the Audit Node's own operational telemetry flows one-way to Pulse with no runtime dependency on Pulse. Phase-1 audit integrity is append-only-by-interface (`IAuditLog` exposes no update and no delete method); it is explicitly **not** tamper-evident, and Phase 1 must not be documented or marketed as such. See ADR-0030 D1, D3, D6, D7, D9.

48. **Downstream Nodes take a runtime dependency only on `HoneyDrunk.Audit.Abstractions`.**
    Emitters and readers compile against `HoneyDrunk.Audit.Abstractions` only. Composition against `HoneyDrunk.Audit.Data` is a host-time concern resolved at application startup; consumer Nodes must not reference `HoneyDrunk.Audit.Data` in production composition. Packaged testing fixtures, when introduced, are test-time only. See ADR-0031 D9.

49. **The HoneyDrunk.Audit Node CI must include a contract-shape canary for the full `HoneyDrunk.Audit.Abstractions` public surface.**
    Shape drift on `IAuditLog`, `IAuditQuery`, `AuditEntry`, or the supporting query/category/outcome/target/change value types is a build failure unless paired with an intentional version bump. The implementation may be the existing `job-api-compatibility.yml` reusable workflow scoped to `HoneyDrunk.Audit.Abstractions`; the obligation is to keep the gate, not to use any specific implementation. See ADR-0031 D8.

## Standup Procedure Invariants

102. **Node registration is mandatory before the first non-bootstrap PR merges.**
    Every Node repo must have, before its first non-bootstrap PR merges:
    1. an entry in `catalogs/nodes.json` (Node row),
    2. a corresponding edges section in `catalogs/relationships.json`,
    3. an entry in `catalogs/grid-health.json`,
    4. a context folder at `repos/{NodeName}/` with all five files (`overview.md`, `boundaries.md`, `invariants.md`, `active-work.md`, `integration-points.md`),
    5. a sector row in `constitution/sectors.md`,
    6. a `repo-to-node.yml` mapping in `HoneyDrunk.Actions/.github/config/`,
    7. a `.honeydrunk-review.yaml` at the repo root with `enabled: true` or `enabled: false` explicitly declared,
    8. a `pr.yml` workflow calling `HoneyDrunk.Actions`'s `pr-core.yml`,
    9. branch protection on `main` requiring the `pr-core / core` status check, **and**
    10. **org-secret repo binding** — the org admin has bound the new repo to every org Actions secret the repo's workflows reference. Minimum set for any Node consuming `pr-core.yml` is `SONAR_TOKEN` (ADR-0011 D11). Per-class conditional additions (`NUGET_API_KEY`, `LABELS_FANOUT_PAT`, `HIVE_FIELD_MIRROR_TOKEN`, `HIVE_APP_ID`, `HIVE_APP_PRIVATE_KEY`, the ADR-0084 Discord webhook stack, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`) follow the matrix in `constitution/node-standup.md`. GitHub does not auto-propagate org secrets with `Selected repositories` access policy, so without this step the new repo's first non-bootstrap PR consuming any of those secrets hard-fails — silently in the case of empty-string substitution, loudly for explicit-required wiring.

    A "bootstrap PR" is the scaffold PR itself (the first PR after repo creation, landing the scaffold packet — exemplar `03-{node}-node-scaffold.md`). A bootstrap PR is permitted to introduce items 7, 8, 9, and 10 in the same commit as the rest of the scaffold; the invariant binds the *second* PR (the first feature PR). Items 1–6 must exist before the scaffold PR (they are Phase A; the scaffold is Phase C; Phase A merges first per D3's prerequisite gate).

    Enforcement is procedural — human review at PR time, supplemented by the `review` agent per ADR-0044 D3 category 10 (Enterprise readiness / supportability) for items 1–9 (catalog rows, context folder, sectors row, repo-to-node mapping, `.honeydrunk-review.yaml`, `pr.yml`, branch protection), the `node-audit` agent per ADR-0043's Tactical source, and the `hive-sync` agent's reconciliation pass per invariant 38. **Item 10 — org-secret repo binding — is NOT checkable by the `review` agent at v1**: the GitHub org-secret repository-access policy is admin-only API surface, and the `review` agent runs without an admin token. Item-10 enforcement reduces to operator memory and the per-class binding matrix in `constitution/node-standup.md` at v1. A future packet may add a manual `gh secret list` operator checklist step or a dedicated admin-token cron, but neither is committed by ADR-0082. No CI gate at this time (the catalogs and the new repo are in different repositories — a cross-repo CI gate is an unblocked follow-up, not committed by ADR-0082). See ADR-0082 D6, D8.

## Vendor Posture Invariants

99. **Every vendor surface in the Grid carries one of the three postures from ADR-0080 D1: Accept (deep, intentional), Hedge (active), or Abstract (already portable).**
    Posture is documented in ADR-0080's per-vendor table (D2) or, for new vendors introduced after that ADR's acceptance, in the source ADR that adopts the vendor. The three-posture vocabulary is the only vendor-posture language the Grid uses; "multi-cloud," "vendor-neutral," "cloud-agnostic," and similar enterprise-shaped framings are explicitly not in the Grid's vocabulary. See ADR-0080 D1, D2.

100. **No vendor-proprietary feature is consumed in application code.**
    Proprietary features (Azure Cache for Redis modules, Entra-proprietary claims, Stripe-specific webhook semantics, Cloudflare Workers, Twilio Studio flows, etc.) are allowed only at the `*.Providers.*` package layer; application code consumes Grid-defined interfaces and standard protocols (Redis-protocol-only per ADR-0076 D3, OIDC-standard claims only per ADR-0078 D3, OTel-first emit per ADR-0040, EF Core LINQ provider-agnostic per ADR-0072, normalized webhook intake per ADR-0062). This follows the same abstraction/runtime/provider shape that invariants 1, 2, 3 codify for internal Grid packaging, and that invariant 44 codifies for the AI sector; invariants 9 / 9a / 47 / 48 are the per-surface analogues already in place for Vault secrets and Audit append-by-interface. The connection to invariants 1/2/3 is structural shape, not scope expansion — 1/2/3 are intra-Grid packaging rules, this invariant is additive at the vendor-surface boundary. Enforced through the standard Grid review mechanisms: the Grid-aware `review` agent per ADR-0044 checks provider-package vs. application-code boundaries at PR time, and the `.coderabbit.yaml` per ADR-0079 may carry vendor-leakage rules over time. See ADR-0080 D3.

101. **"Accept (deep, intentional)" posture vendors have a per-vendor governance file under `governance/vendor-postures/{vendor}.md`.**
    The file documents the lock-in honestly: every surface depended on, the exit cost per surface, the cheap hedges already in place, and the canonical home for "vendor-exit playbook" references from source ADRs. Hedge and Abstract posture vendors use the source ADR as document-of-record; no separate governance file is required at acceptance, with the bar for promotion being "the source ADR's cited hedge is no longer the only relevant context." See ADR-0080 D5.
