# Handoff — Wave 1 → Wave 2: Scalar.AspNetCore reference middleware

**Read once at the Wave 1 → Wave 2 transition. Immutable (invariant 24).**

## What Wave 1 produced

- **ADR-0075 is Accepted** (packet 00). Status flipped; `adrs/README.md` updated; `initiatives/active-initiatives.md` registers the `adr-0075-docs-tooling` initiative with the wave structure. **`constitution/invariants.md` was NOT edited** — ADR-0075 explicitly commits zero new Grid-wide invariants ("No new Grid-wide invariants introduced. The following are committed conventions enforced at packet authoring and review."). The four committed conventions (Scalar for new OpenAPI surfaces; Docusaurus for standalone docs sites; per-Node `overview.md` as default per-Node docs; both tools consume Web.UI tokens) are enforced at packet authoring and review.
- **The Grid records the Scalar + Docusaurus tooling convention** (packet 01). A new convention note (strong default: `constitution/docs-tooling.md`) carries the four conventions verbatim-in-substance from ADR-0075, citing ADR-0057 / ADR-0071 / ADR-0029 / ADR-0070 as related. `catalogs/contracts.json`, `catalogs/grid-health.json`, `catalogs/nodes.json`, and `catalogs/modules.json` were **not** edited — none of those schemas represents tooling conventions.

## Wave 2 packet

One work-item:

- **Packet 02 (`Actor=Agent`)** — add `Scalar.AspNetCore` to `HoneyDrunk.Web.Rest.AspNetCore` as the canonical in-product OpenAPI renderer; expose `AddHoneyDrunkOpenApi(IServiceCollection)` + `MapHoneyDrunkOpenApiReference(IEndpointRouteBuilder)` extensions.

## Critical context for Wave 2 execution

- **This is a new feature, not a Swagger UI replacement.** A scan of `HoneyDrunk.Web.Rest.AspNetCore` finds **no** Swashbuckle `PackageReference`, no `AddSwaggerGen` / `UseSwaggerUI` call sites. Web.Rest does not currently ship Swagger UI — packet 02 sets the new default rather than replacing existing usage. (The ADR's D4 grandfather posture remains: if a different Node elsewhere ships Swagger UI, that Node migrates opportunistically when its API surface is touched for other reasons — not as part of this initiative.)
- **`HoneyDrunk.Web.Rest.AspNetCore` is the right project.** Per `repos/HoneyDrunk.Web.Rest/boundaries.md`: Web.Rest.AspNetCore owns HTTP-surface conventions (correlation, exception mapping, request logging, model validation, minimal-API helpers, JSON conventions). OpenAPI-renderer middleware is an HTTP-surface convention; it fits within Web.Rest's owned surface. The "What Web.Rest Does NOT Own" list (auth middleware, business logic, transport messaging, data access) does not include OpenAPI rendering.
- **Document generation stays opt-in to the host.** Per ADR-0057, `Microsoft.AspNetCore.OpenApi` generates the OpenAPI document; the host opts in. `AddHoneyDrunkOpenApi()` calls `services.AddOpenApi()` for the host (so the host gets both rendering and document-generation services from one call), but the **decision** to expose an OpenAPI surface remains opt-in — the host calls `AddHoneyDrunkOpenApi()` or it doesn't. Web.Rest does not force every Web.Rest consumer to host an OpenAPI document.
- **Per-environment availability — production is opt-in.** ADR-0075 D1's rule: dev/staging enabled by default; prod enabled at the Node's discretion. Implement this with a `HoneyDrunkOpenApiOptions.EnableInProduction` default of `false`. `MapHoneyDrunkOpenApiReference()` reads `IHostEnvironment` at startup and is a **no-op** in Production unless the host opts in. The Notify Cloud case (consumer-facing API, prod-enabled) becomes an explicit `options.EnableInProduction = true` decision in that Node's host wiring.
- **Web.UI tokens via a hook, not a requirement.** ADR-0075 D5 commits both tools to consume Web.UI tokens for visual coherence. Web.UI Node is still **Proposed** (ADR-0071) — the tokens package doesn't exist yet. Implement the hook (`HoneyDrunkOpenApiOptions.CustomCssPath`) so a host can point Scalar at a Web.UI-CSS-aligned stylesheet when the tokens package ships, but **do not require** Web.UI to exist to use this packet.
- **The extension shape is fixed by the work-item:**
  ```csharp
  IServiceCollection AddHoneyDrunkOpenApi(this IServiceCollection services, Action<HoneyDrunkOpenApiOptions>? configure = null);
  IEndpointRouteBuilder MapHoneyDrunkOpenApiReference(this IEndpointRouteBuilder app, string pattern = "/scalar");
  ```
- **`HoneyDrunkOpenApiOptions` shape:** `DocumentName` (`"v1"`), `DocumentPath` (`"/openapi/{documentName}.json"`), `EnableInProduction` (`false`), `CustomCssPath` (nullable string). XML docs on every public member (invariant 13). Match the existing `Configuration/` folder convention in the AspNetCore project for the options POCO's location.
- **Version-state check — invariant 27.** `HoneyDrunk.Web.Rest` is at v0.5.0 (LIVE). All projects in the solution share one version and move together. Check the in-progress version state at edit time:
  - If v0.5.0 is the last released version and no in-progress entry exists, **bump to v0.6.0** (minor — additive public surface in `HoneyDrunk.Web.Rest.AspNetCore`).
  - If an in-progress v0.6.0 entry already exists in the CHANGELOG, **append** to it without re-bumping.
  - Record the decision in the PR.
- **CHANGELOG discipline.** Repo-level `CHANGELOG.md` new version entry (or append). `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` — actual change, write an entry. Other per-package CHANGELOGs (Abstractions, Canary, Tests) — only if those packages actually changed (invariant 27 — per-package CHANGELOG entries only for packages with actual changes; no noise entries for alignment bumps). `README.md` in `HoneyDrunk.Web.Rest.AspNetCore` — new OpenAPI-reference quick-start section.
- **NuGet packages added:**
  - `Scalar.AspNetCore` — pin current stable major; confirm exact version at edit time. MIT-licensed per ADR-0075 D1.
  - `Microsoft.AspNetCore.OpenApi` — .NET 10–aligned version. ADR-0057's source-of-truth for document generation.
- **Testing discipline.** Unit tests in `HoneyDrunk.Web.Rest.Tests` cover options binding (defaults + overrides), no-op-in-production behavior, chainable returns. Tests use `WebApplicationFactory` against minimal hosts (in-process; no external services per invariant 15; no `Thread.Sleep` per invariant 51). An optional canary in `HoneyDrunk.Web.Rest.Canary` exercises the composition end-to-end: `GET /scalar` returns 200 in Development, 404 in Production with default options.

## Wave 2 exit criteria

- `HoneyDrunk.Web.Rest.AspNetCore.csproj` carries `PackageReference` entries for `Scalar.AspNetCore` (pinned current stable major) and `Microsoft.AspNetCore.OpenApi` (.NET 10–aligned).
- `HoneyDrunkOpenApiOptions` exists with `DocumentName` / `DocumentPath` / `EnableInProduction` / `CustomCssPath`, full XML docs.
- `AddHoneyDrunkOpenApi(IServiceCollection, Action<HoneyDrunkOpenApiOptions>?)` and `MapHoneyDrunkOpenApiReference(IEndpointRouteBuilder, string pattern)` extensions exist; the Map extension is no-op in Production with `EnableInProduction = false`.
- Unit tests cover options binding, the no-op-in-production behavior, and chainable returns.
- (Optional) canary verifies the end-to-end composition.
- `HoneyDrunk.Web.Rest.AspNetCore/README.md` documents the OpenAPI-reference quick-start; `HoneyDrunk.Web.Rest.AspNetCore/CHANGELOG.md` carries the new public-surface entry; repo-level `CHANGELOG.md` has a new version entry (or appended).
- Every non-test `.csproj` in the solution shares the bumped version (invariant 27).
- The solution builds; existing tests pass; new tests pass; no new build warnings.
- Invariants 1, 3, 12, 13, 15, 26, 27, 51 all satisfied.
