---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Web.Rest
labels: ["feature", "tier-2", "core", "adr-0075", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0075", "ADR-0057"]
accepts: ["ADR-0075"]
wave: 2
initiative: adr-0075-docs-tooling
node: honeydrunk-web-rest
---

# Add Scalar.AspNetCore as the OpenAPI-rendering reference middleware in HoneyDrunk.Web.Rest.AspNetCore

## Summary
Ship `Scalar.AspNetCore` in `HoneyDrunk.Web.Rest.AspNetCore` as the canonical in-product OpenAPI renderer per ADR-0075 D1. Add a `MapHoneyDrunkOpenApiReference()` endpoint extension (and corresponding `AddHoneyDrunkOpenApi()` service-collection extension) that hosting Nodes call to expose Scalar at `/scalar` (or the path the Node chooses). `Microsoft.AspNetCore.OpenApi` continues to generate the OpenAPI document per ADR-0057 — this packet adds only the renderer. This is the **first concrete Scalar adoption** in the Grid; it sets the reference middleware composition that future Nodes consume.

## Context
ADR-0075 D1 replaces Swagger UI with Scalar as the canonical in-product OpenAPI renderer. The ADR's Follow-up Work names this as the first work-item: "Ship `Scalar.AspNetCore` in the Web.Rest reference middleware composition."

**Repo-state ground truth — read before editing.**
- `HoneyDrunk.Web.Rest` is at v0.5.0 (LIVE per `catalogs/grid-health.json`). The solution comprises `HoneyDrunk.Web.Rest.Abstractions`, `HoneyDrunk.Web.Rest.AspNetCore`, `HoneyDrunk.Web.Rest.Canary`, and `HoneyDrunk.Web.Rest.Tests`.
- **No Swagger UI exists in Web.Rest today** — a scan of `HoneyDrunk.Web.Rest.AspNetCore` finds no `Swashbuckle.AspNetCore` `PackageReference`, no `AddSwaggerGen` / `UseSwaggerUI` call sites. Web.Rest's `AspNetCore` package today ships correlation, exception mapping, request logging, model validation, minimal-API helpers, and the Vault/Auth/Transport integration — but no OpenAPI rendering. **This is a new feature, not a Swagger UI replacement** for Web.Rest itself.
- `Microsoft.AspNetCore.OpenApi` is **not currently referenced** in `HoneyDrunk.Web.Rest.AspNetCore.csproj`. The Web.Rest reference middleware does not own document generation today either — consuming Nodes that need an OpenAPI document add `Microsoft.AspNetCore.OpenApi` themselves per ADR-0057. The decision here is whether this packet adds `Microsoft.AspNetCore.OpenApi` as a Web.Rest dependency, or leaves it to the host. The strong default: **leave document generation to the host** (per ADR-0057's "OpenAPI document is the host's concern") and have `MapHoneyDrunkOpenApiReference()` assume an OpenAPI endpoint exists at the standard path (`/openapi/v1.json` for .NET 10's `MapOpenApi()` default). The Scalar middleware reads from that endpoint. This keeps `HoneyDrunk.Web.Rest.AspNetCore` from forcing every consumer to host an OpenAPI document — only those that opt in to Scalar via `MapHoneyDrunkOpenApiReference()` need one.
- The boundary check from `repos/HoneyDrunk.Web.Rest/boundaries.md`: Web.Rest owns response envelope contracts, correlation propagation, exception-to-HTTP-status mapping, validation contracts, pagination, JSON conventions, and request logging scopes. **OpenAPI-renderer middleware fits naturally** — it is an HTTP-surface convention (the "what does the API expose at well-known paths" question), parallel to existing middleware conventions in this package.

**Scalar package shape (Scalar.AspNetCore).**
- NuGet: `Scalar.AspNetCore` — MIT-licensed, native ASP.NET Core middleware. The standard composition is `app.MapScalarApiReference()` mounted on the host's `WebApplication`. Confirm the exact current API at edit time — versions evolve. Use the latest stable major and document the pinned version in `Directory.Packages.props` or the project's `PackageReference`.
- The middleware does not own document generation; it consumes whatever OpenAPI document the host exposes. The default Scalar configuration points at the .NET 10 default `Microsoft.AspNetCore.OpenApi` endpoint (`/openapi/v1.json`). Confirm at edit time.

**The Web.Rest extension shape.**
- Add a new file `Extensions/HoneyDrunkWebRestOpenApiExtensions.cs` (or extend `HoneyDrunkWebRestEndpointRouteBuilderExtensions.cs` if the existing convention groups endpoint extensions) with:
  - `IServiceCollection AddHoneyDrunkOpenApi(this IServiceCollection services, Action<HoneyDrunkOpenApiOptions>? configure = null)` — registers options + the Microsoft OpenAPI services (calls `services.AddOpenApi()` from `Microsoft.AspNetCore.OpenApi`, the host opts in).
  - `IEndpointRouteBuilder MapHoneyDrunkOpenApiReference(this IEndpointRouteBuilder app, string pattern = "/scalar")` — maps Scalar at the configured path, defaulting to `/scalar`. Configures Scalar to point at the standard `/openapi/v1.json` endpoint.
  - A `HoneyDrunkOpenApiOptions` POCO with at least:
    - `string DocumentName` (default `"v1"` — matches Microsoft's default OpenAPI document name).
    - `string DocumentPath` (default `"/openapi/{documentName}.json"` — matches `Microsoft.AspNetCore.OpenApi`'s default route).
    - `bool EnableInProduction` (default `false` — per ADR-0075 D1's per-environment availability; production must be explicit opt-in).
  - Scalar theming hooks per ADR-0075 D5 — accept a hook for Web.UI tokens consumption (when ADR-0071's tokens package ships) but do not require it. The minimum: a `string? CustomCssPath` option so a host can point Scalar at a Web.UI-CSS-aligned stylesheet.
- The endpoint extension must respect `EnableInProduction` — when the runtime environment is Production and `EnableInProduction` is false, `MapHoneyDrunkOpenApiReference()` is a no-op (logs at debug level, returns the builder unchanged). This implements ADR-0075 D1's "prod enabled at the Node's discretion" rule with a safe default.

**Quick-start update.** `HoneyDrunk.Web.Rest.AspNetCore/README.md` needs a new section showing the OpenAPI-reference composition pattern. Example (confirm shape at edit time):
```csharp
builder.Services.AddRest(...);
builder.Services.AddHoneyDrunkOpenApi(options =>
{
    options.EnableInProduction = false; // dev/staging only by default
});

var app = builder.Build();
app.UseGridContext();
app.UseRest();
app.MapHoneyDrunkOpenApiReference();
```

**Version bump.** Per invariant 27, all projects in `HoneyDrunk.Web.Rest` share one version and move together. This packet ships new public types in `HoneyDrunk.Web.Rest.AspNetCore` (`AddHoneyDrunkOpenApi`, `MapHoneyDrunkOpenApiReference`, `HoneyDrunkOpenApiOptions`) — a **minor** bump (additive public surface). Check the in-progress version state of `HoneyDrunk.Web.Rest` at edit time: if v0.5.0 is the last released version, bump to v0.6.0; if an unreleased v0.6.0 entry exists in CHANGELOG, append to it without re-bumping.

**Boundary check.** Web.Rest.AspNetCore owns HTTP-surface conventions; the OpenAPI-renderer endpoint is HTTP-surface-shaped. The `boundaries.md` "What Web.Rest Does NOT Own" list (auth middleware, business logic, transport messaging, data access) does not include OpenAPI rendering; this packet fits within Web.Rest's owned surface.

## Scope
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/HoneyDrunk.Web.Rest.AspNetCore.csproj` — add `<PackageReference Include="Scalar.AspNetCore" Version="..." />` (pin to current stable major) and `<PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="..." />` (the version aligned with .NET 10 / the host's framework reference).
- A new extension class `Extensions/HoneyDrunkWebRestOpenApiExtensions.cs` (or extension to the existing endpoint-route-builder extensions) with `AddHoneyDrunkOpenApi`, `MapHoneyDrunkOpenApiReference`, and `HoneyDrunkOpenApiOptions`.
- Unit tests in `HoneyDrunk.Web.Rest.Tests` for the options-binding and the no-op-in-production behavior.
- Optional canary test in `HoneyDrunk.Web.Rest.Canary` exercising the composition end-to-end (a test host that mounts both the OpenAPI document endpoint and Scalar, asserts `/scalar` returns 200 in dev and is unmapped/404 in production with `EnableInProduction=false`).
- `HoneyDrunk.Web.Rest.AspNetCore/README.md` — add an OpenAPI-reference quick-start section.
- `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` — per-package entry for the new public surface.
- Repo-level `CHANGELOG.md` — version bump entry (or append to existing in-progress entry).
- Every non-test `.csproj` in the solution — version bumped together if this packet bumps (invariant 27).

## Proposed Implementation
1. Add `Scalar.AspNetCore` (pin current stable major; confirm version at edit time) and `Microsoft.AspNetCore.OpenApi` (.NET 10–aligned version) as `PackageReference` entries in `HoneyDrunk.Web.Rest.AspNetCore.csproj`. Maintain the existing `PrivateAssets`/license-expression conventions in the project file.
2. Create `HoneyDrunkOpenApiOptions` POCO with `DocumentName` (default `"v1"`), `DocumentPath` (default `"/openapi/{documentName}.json"`), `EnableInProduction` (default `false`), and `CustomCssPath` (nullable). Add XML docs on every public member (invariant 13).
3. Add `IServiceCollection AddHoneyDrunkOpenApi(this IServiceCollection services, Action<HoneyDrunkOpenApiOptions>? configure = null)`:
   - Binds the options.
   - Calls `services.AddOpenApi(options.DocumentName, ...)` so the host doesn't have to.
   - Returns the service collection.
4. Add `IEndpointRouteBuilder MapHoneyDrunkOpenApiReference(this IEndpointRouteBuilder app, string pattern = "/scalar")`:
   - Resolves `IOptions<HoneyDrunkOpenApiOptions>` and `IHostEnvironment` from `app.ServiceProvider`.
   - If `env.IsProduction()` and `!options.EnableInProduction`, logs at debug level and returns the builder unchanged.
   - Otherwise, calls `app.MapOpenApi(options.DocumentPath)` (the document endpoint per ADR-0057) and `app.MapScalarApiReference(opts => opts.WithOpenApiRoutePattern(options.DocumentPath).WithCustomCss(options.CustomCssPath))` at `pattern`. Confirm the exact Scalar configuration API at edit time.
   - Returns the builder.
5. Unit tests in `HoneyDrunk.Web.Rest.Tests`:
   - Options bind correctly (defaults are stable; explicit overrides apply).
   - `MapHoneyDrunkOpenApiReference` is a no-op in Production with `EnableInProduction=false`.
   - `MapHoneyDrunkOpenApiReference` returns the same builder instance (chainable).
   - Tests use `WebApplicationFactory<T>` against a minimal test host; no external services (invariant 15); no `Thread.Sleep` (invariant 51).
6. Optional canary test in `HoneyDrunk.Web.Rest.Canary`:
   - End-to-end composition: host with `AddRest()` + `AddHoneyDrunkOpenApi()` + `MapHoneyDrunkOpenApiReference()`.
   - Asserts `GET /scalar` returns 200 OK and HTML content in Development.
   - Asserts `GET /scalar` returns 404 in Production with the default `EnableInProduction=false`.
   - Asserts `GET /openapi/v1.json` returns 200 OK and valid OpenAPI 3.x JSON.
7. Update `HoneyDrunk.Web.Rest.AspNetCore/README.md` Quick Start with an OpenAPI-reference section showing the `AddHoneyDrunkOpenApi` + `MapHoneyDrunkOpenApiReference` composition. Document the per-environment default (dev/staging on; prod off) and the `EnableInProduction` opt-in.
8. **Per-package CHANGELOG entry** in `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` — new public surface (additive). Per-package CHANGELOG entries only for packages with actual changes (invariant 27); the Abstractions, Canary, and Tests projects get changelog entries only if they actually changed.
9. **Repo-level CHANGELOG** — new version entry (e.g., v0.6.0) if this is the version-bumping packet, or append to the existing in-progress entry. Cite ADR-0075 D1.
10. **Version bump.** Update every non-test `.csproj` `<Version>` to the new version (invariant 27 — all projects move together).

## Affected Files
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/HoneyDrunk.Web.Rest.AspNetCore.csproj`
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Extensions/HoneyDrunkWebRestOpenApiExtensions.cs` (new) or extension to the existing endpoint-route extensions file
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Configuration/HoneyDrunkOpenApiOptions.cs` (new — match the existing `Configuration/` folder convention)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Tests/...` (new test class for the OpenAPI extensions)
- Optional: `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Canary/...` (new canary test)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/README.md`
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md`
- Repo-level `CHANGELOG.md`
- Every non-test `.csproj` in `HoneyDrunk.Web.Rest/` (version bump per invariant 27)

## NuGet Dependencies
- **`Scalar.AspNetCore`** — MIT-licensed; native ASP.NET Core middleware; the canonical in-product OpenAPI renderer per ADR-0075 D1. Pin to current stable major; confirm exact version at edit time.
- **`Microsoft.AspNetCore.OpenApi`** — .NET 10–aligned version; produces the OpenAPI document per ADR-0057. The Scalar middleware reads from `/openapi/v1.json` by default.
- No new HoneyDrunk runtime dependency added beyond what `HoneyDrunk.Web.Rest.AspNetCore` already references.
- `HoneyDrunk.Standards` analyzers stay on per invariant 26 (already referenced).

## Boundary Check
- [x] `HoneyDrunk.Web.Rest.AspNetCore` is the right project — Web.Rest.AspNetCore owns HTTP-surface conventions; OpenAPI-renderer middleware is HTTP-surface-shaped. `repos/HoneyDrunk.Web.Rest/boundaries.md`'s "What Web.Rest Does NOT Own" list does not include OpenAPI rendering.
- [x] Document generation stays opt-in to the host via `AddHoneyDrunkOpenApi()` — Web.Rest does not force every consumer to expose an OpenAPI document.
- [x] No new cross-Node runtime dependency.
- [x] No abstraction-package change — this is hosting-side only. `HoneyDrunk.Web.Rest.Abstractions` is untouched.

## Acceptance Criteria
- [ ] `HoneyDrunk.Web.Rest.AspNetCore.csproj` adds `PackageReference` entries for `Scalar.AspNetCore` (pinned current stable major) and `Microsoft.AspNetCore.OpenApi` (.NET 10–aligned)
- [ ] `HoneyDrunkOpenApiOptions` exists with `DocumentName`, `DocumentPath`, `EnableInProduction`, `CustomCssPath` and full XML docs (invariant 13)
- [ ] `AddHoneyDrunkOpenApi(IServiceCollection, Action<HoneyDrunkOpenApiOptions>?)` exists and wires Microsoft OpenAPI services
- [ ] `MapHoneyDrunkOpenApiReference(IEndpointRouteBuilder, string pattern = "/scalar")` exists, maps Scalar at the configured pattern, points at the configured `DocumentPath`, and is a no-op in Production when `EnableInProduction = false`
- [ ] Unit tests cover: options binding (defaults + overrides); no-op-in-production behavior; chainable return values; tests run in-process per invariant 15 and contain no `Thread.Sleep` per invariant 51
- [ ] (Optional but recommended) A canary in `HoneyDrunk.Web.Rest.Canary` exercises the composition end-to-end and asserts `/scalar` returns 200 in Development and 404 in Production-with-default-options
- [ ] `HoneyDrunk.Web.Rest.AspNetCore/README.md` documents the OpenAPI-reference composition pattern with the per-environment default rule
- [ ] Per-package `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` carries an entry for the new public surface
- [ ] Repo-level `CHANGELOG.md` has a new version entry (or appends to in-progress) citing ADR-0075 D1
- [ ] Every non-test `.csproj` in the solution shares the bumped version (invariant 27)
- [ ] The solution builds; existing tests pass; the new tests pass; build warnings are not introduced
- [ ] No invariant violation: invariants 1, 3, 12, 13, 15, 26, 27, 51 all satisfied

## Human Prerequisites
None. This packet is pure code + docs — no Azure resource, no portal step.

## Referenced ADR Decisions
**ADR-0075 D1 — Scalar is the canonical in-product OpenAPI renderer.** `Scalar.AspNetCore` replaces Swagger UI in every Grid Node that exposes an OpenAPI spec. `Microsoft.AspNetCore.OpenApi` generates the document per ADR-0057; Scalar renders it. Per-environment availability: dev/staging enabled by default; prod enabled at the Node's discretion (Notify Cloud's public API surface keeps Scalar in prod; internal-only Nodes may keep it dev/staging-only). The Web.Rest reference middleware composition is the first concrete adoption.

**ADR-0075 D4 — Migration is opportunistic, not a campaign.** Web.Rest does not currently ship Swagger UI — this packet sets the default rather than replacing existing usage. Existing Nodes elsewhere in the Grid that ship Swagger UI grandfather until their API surface is touched for other reasons.

**ADR-0075 D5 — Both tools consume Web.UI tokens.** The `CustomCssPath` option is the hook for Web.UI-CSS-aligned theming when the Web.UI tokens package ships (ADR-0071). This packet provides the hook without requiring Web.UI to exist yet.

**ADR-0057 — OpenAPI as the source of truth, generated by `Microsoft.AspNetCore.OpenApi`.** Document generation is the host's concern; Scalar consumes the standard `/openapi/v1.json` endpoint. This packet does not change document generation.

## Constraints
> **Invariant 1 — Abstractions packages have zero runtime dependencies on other HoneyDrunk packages.** `HoneyDrunk.Web.Rest.Abstractions` is NOT touched in this packet. The Scalar dependency lands only in `HoneyDrunk.Web.Rest.AspNetCore`, a hosting-side package.

> **Invariant 3 — Provider packages depend on their parent Node's contracts, not internals.** Web.Rest's hosting integration consumes its own contracts; no new cross-package coupling.

> **Invariant 12 — Semantic versioning with CHANGELOG and README.** Repo-level CHANGELOG bumps (or appends), `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` updated, README updated.

> **Invariant 13 — All public APIs have XML documentation.** Every public member of `HoneyDrunkOpenApiOptions`, `AddHoneyDrunkOpenApi`, and `MapHoneyDrunkOpenApiReference` carries XML docs; enforced by `HoneyDrunk.Standards`.

> **Invariant 15 — Unit tests never depend on external services.** The OpenAPI-extension tests run in-process via `WebApplicationFactory`.

> **Invariant 26 — Work items for .NET code work include an explicit `## NuGet Dependencies` section.** This packet has it; `HoneyDrunk.Standards` analyzers remain on every project.

> **Invariant 27 — All projects in a solution share one version and move together.** Perform the in-progress version-state check on the `HoneyDrunk.Web.Rest` solution: bump if at a released version (v0.5.0 → v0.6.0); append if an unreleased v0.6.0 entry exists. Record the decision in the PR.

> **Invariant 51 — Test code contains no `Thread.Sleep`.** The new tests use polling or completion signals, not sleep.

- **Per-environment availability — production is opt-in.** The `EnableInProduction` default is `false`; `MapHoneyDrunkOpenApiReference` no-ops in Production unless the host explicitly opts in. This implements ADR-0075 D1's "prod enabled at the Node's discretion" rule with a safe default.
- **Web.UI tokens hook, not requirement.** The `CustomCssPath` option lets a host point Scalar at a Web.UI-aligned stylesheet but does not require Web.UI to exist — the Web.UI Node is still proposed (ADR-0071).
- **No document-generation change.** ADR-0057 owns document generation; this packet only adds the renderer. Web.Rest does not assume responsibility for the OpenAPI document.

## Labels
`feature`, `tier-2`, `core`, `adr-0075`, `wave-2`

## Agent Handoff

**Objective:** Ship `Scalar.AspNetCore` as the canonical in-product OpenAPI renderer in `HoneyDrunk.Web.Rest.AspNetCore`, with `AddHoneyDrunkOpenApi()` / `MapHoneyDrunkOpenApiReference()` extensions and a per-environment-aware default.

**Target:** `HoneyDrunk.Web.Rest`, branch from `main`.

**Context:**
- Goal: Set the Grid's reference middleware composition for OpenAPI rendering. Every future Node with an OpenAPI surface composes against this.
- Feature: ADR-0075 Documentation Tooling rollout, Wave 2.
- ADRs: ADR-0075 D1/D4/D5 (primary), ADR-0057 (OpenAPI document generation — unchanged), ADR-0071 (Web.UI tokens — the CustomCssPath hook).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `work-item:00` — soft. ADR-0075 should be Accepted before its tooling lands.

**Constraints:**
- Production is opt-in — `EnableInProduction = false` by default; `MapHoneyDrunkOpenApiReference` no-ops in Production unless the host explicitly enables it.
- Web.UI tokens via `CustomCssPath` is a hook, not a requirement — Web.UI Node is still proposed (ADR-0071).
- Document generation stays with `Microsoft.AspNetCore.OpenApi`; this packet does not change ADR-0057's source-of-truth.
- Perform the invariant-27 version-state check on `HoneyDrunk.Web.Rest` — bump or append; record the decision.
- Invariants 1, 3, 12, 13, 15, 26, 27, 51 all in scope — see Constraints inline.

**Key Files:**
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/HoneyDrunk.Web.Rest.AspNetCore.csproj`
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Extensions/HoneyDrunkWebRestOpenApiExtensions.cs` (new) — or extension to the existing endpoint-route extensions file
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/Configuration/HoneyDrunkOpenApiOptions.cs` (new)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.Tests/...` (new tests for the OpenAPI extensions)
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/README.md`
- `HoneyDrunk.Web.Rest/HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md`; repo-level `CHANGELOG.md`

**Contracts:**
- New public surface in `HoneyDrunk.Web.Rest.AspNetCore`: `AddHoneyDrunkOpenApi(IServiceCollection, Action<HoneyDrunkOpenApiOptions>?)`, `MapHoneyDrunkOpenApiReference(IEndpointRouteBuilder, string pattern)`, `HoneyDrunkOpenApiOptions`. Additive — minor version bump.
