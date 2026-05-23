# ADR-0055: Feature Flag and Progressive Rollout Strategy

**Status:** Proposed
**Date:** 2026-05-22
**Deciders:** HoneyDrunk Studios
**Sector:** Core / cross-cutting

## Context

The Grid has no formal feature-flag ADR. Today, the closest thing to progressive rollout lives in two places, neither of which addresses the application-level flagging concern:

- **ADR-0015 D-revisions** enforces multi-revision Azure Container Apps for traffic splitting. That is **deploy-level only** — it splits inbound traffic across two revisions of the same container image. It cannot toggle a feature on for a specific tenant, percentage-roll a feature within a single revision, or kill-switch a misbehaving code path without a redeploy.
- **ADR-0005 (Config & Secrets Strategy)** commits to **Azure App Configuration** as the configuration backend. App Configuration has a first-class feature-flags surface (`Microsoft.FeatureManagement`), but no ADR has committed to using it; today, the surface sits unused.

The forcing functions for codifying this now:

- **Consumer-app PDRs** (PDR-0003 Lately, PDR-0005 Hearth, PDR-0006 Currents, PDR-0007 Arcadia, PDR-0008 Curiosities) all anticipate trunk-based development (cross-ref ADR-0053). Trunk-based dev **requires** application-level feature flags to decouple deploy from release; without them, unfinished work either blocks the trunk or ships visible-but-broken.
- **Notify.Cloud (PDR-0002)** introduces **per-tenant** feature enablement — paid-tier features that exist in the deployed code but are gated to specific tenants by entitlement. Container Apps revisions cannot express "tenant A on, tenant B off" within a shared revision.
- **The AI-sector standup wave** (ADR-0016 through ADR-0025) introduces nine Nodes whose experimental code paths (alternative agent routing, eval-time-only capabilities, model swaps) are exactly the kind of surface flags excel at.
- **ADR-0044 D3 category 11 (Testing Quality)** and **ADR-0047 (Testing Patterns)** assume some mechanism for testing both flag-on and flag-off states; the mechanism is not currently named.
- **ADR-0053 (Trunk-Based Development)** explicitly defers the flag-system commitment to a future ADR. This is that ADR.

This decision selects the flag-system architecture, names the three flag categories with distinct lifecycle policies, commits the App Configuration backend (no new vendor), commits the abstraction shape and naming, and binds the operator surface, observability, and anti-patterns.

## Decision

### D1 — Three flag categories with distinct lifecycle policies

Not all feature flags are the same. Treating them uniformly produces either (a) operational dead weight from stale release-flag debt or (b) accidental deletion of long-lived business-state flags. The Grid commits to **three named categories**, each with explicit lifecycle, review cadence, and policy:

| Category | Purpose | Lifecycle | Default state | Review |
|----------|---------|-----------|---------------|--------|
| **Release** | Temporarily hide unfinished work behind a flag to enable trunk-based development; expire and remove once shipped | Days to weeks | Off in staging/prod, on in dev (per D9) | `ExpiresOn` date (default 90 days); expired flag fails CI |
| **Permission** | Per-tenant, per-tier, or per-principal feature enablement that encodes long-lived business state | Long-lived (months to years) | Off unless tenant entitled | Annual review surfaced in operator dashboard |
| **Operational** | Kill-switch for misbehaving features; safety net for production incidents | Long-lived; rarely flipped | On (feature live); flipped off during incidents | Annual review; flip events audited per ADR-0030 |

Each category has different review and removal expectations, **and they are not interchangeable.** A release flag that survives past its `ExpiresOn` date is a CI failure (D7); a permission flag does not expire (D7); an operational flag is intentionally long-lived (D7). Forcing a category at flag-creation time prevents the most common feature-flag failure mode — release flags accumulating into permanent technical debt because nobody knew it was safe to delete them.

The category is part of the flag name (D5), so the policy is visible at the point of use.

### D2 — Backend (v1): Azure App Configuration's feature-flags surface

The Grid commits to **Azure App Configuration** as the v1 flag store. App Configuration already holds typed configuration per ADR-0005; its feature-flag surface (`Microsoft.FeatureManagement.AzureAppConfiguration`) provides:

- **Native feature-flag model** — flags as first-class resources, not generic key/value pairs masquerading as flags.
- **Label-based environment scoping** — `dev`, `staging`, `prod` labels per flag value, consistent with ADR-0005's environment-scoping pattern.
- **Built-in targeting filters** — percentage rollout, time-window enablement, custom targeting filters (the hook for D3's `TenantTargetingFilter`).
- **Push refresh via Event Grid** — flag changes propagate to consumers in seconds, not requiring app restart, leveraging the Sentinel + Event Grid pattern App Configuration already supports.
- **No new vendor relationship.** App Configuration is already provisioned per ADR-0005; no new account, no new billing line, no new secret to rotate. The cost contribution of flags on top of existing config is negligible at v1 Grid scale.

This is the same pattern as ADR-0040 (Azure Monitor over Grafana Cloud) and ADR-0045 (App Insights over Sentry): prefer the option that leverages the existing sunk-cost relationship over the best-in-class third party, unless evidence shows the existing option is the bottleneck.

D11 names an explicit escalation path (LaunchDarkly or self-hosted GrowthBook) if App Configuration's flag surface proves inadequate; that decision is not made today.

### D3 — Targeting capabilities: percentage, time-window, and `TenantTargetingFilter`

App Configuration supports three targeting modes out of the box:

- **Percentage filter** — a flag is on for X% of evaluations. Used for canary rollouts (release category) and operational gradient ("turn off for 10% to see if errors drop").
- **Time-window filter** — a flag is on between specified UTC timestamps. Used for scheduled launches (release category) and incident-bounded operational toggles.
- **Custom targeting filters** — pluggable `IFeatureFilter` implementations that receive evaluation context.

The Grid implements one custom targeting filter:

**`TenantTargetingFilter`** (lives in `HoneyDrunk.FeatureFlags` per D4) — resolves the active `TenantId` from `RequestContext` (per ADR-0026) and matches it against the flag's `tenants:` or `tier:` configuration. The configuration shape:

```json
{
  "id": "permission.lately.video-posts",
  "enabled": true,
  "conditions": {
    "client_filters": [
      {
        "name": "TenantTargeting",
        "parameters": {
          "tenants": ["tenant-abc-123", "tenant-def-456"],
          "tiers": ["pro", "studio"],
          "default_rollout_percentage": 0
        }
      }
    ]
  }
}
```

`TenantTargetingFilter` reads `RequestContext.TenantId` and `RequestContext.TenantTier`, matches against `tenants:` (explicit list) or `tiers:` (tier-based enablement), and falls back to `default_rollout_percentage:` for tenants matching neither. This composes with the built-in percentage filter for staged tier rollouts.

The filter is the only custom filter the Grid commits to at v1. Additional custom filters (e.g., `RegionTargetingFilter`, `CapabilityTargetingFilter`) may be added later if real demand surfaces; the abstraction is open by design.

### D4 — Abstraction: `IFeatureGate` in Kernel; implementation in `HoneyDrunk.FeatureFlags`

The flag-system abstraction follows the established `HoneyDrunk.X.Abstractions` / `HoneyDrunk.X` split:

- **`IFeatureGate` interface** lives in **`HoneyDrunk.Kernel.Abstractions`**. Kernel holds Grid-wide abstractions per Invariant; depending on a flag system is a Grid-wide concern; the interface belongs in the Kernel abstractions surface.
- **Concrete implementation** lives in a **new Node `HoneyDrunk.FeatureFlags`**, with the published package `HoneyDrunk.FeatureFlags` providing the `Microsoft.FeatureManagement`-backed implementation and the `TenantTargetingFilter` from D3.

**Why a new Node rather than folding the implementation into Kernel:** the same reasoning as Vault and Observe — Kernel holds abstractions; concrete vendor-specific implementations live in sibling Nodes so the backend can be swapped without touching Kernel. App Configuration is the v1 backing; if D11 ever fires (escalate to LaunchDarkly), the swap is `HoneyDrunk.FeatureFlags` → `HoneyDrunk.FeatureFlags.LaunchDarkly`, with `IFeatureGate` unchanged. Folding the implementation into Kernel would couple Kernel to App Configuration and force a Kernel version bump to swap providers — the exact pattern the Abstractions split is designed to prevent.

`IFeatureGate` shape:

```csharp
public interface IFeatureGate
{
    ValueTask<bool> IsEnabledAsync(string flagName);
    ValueTask<bool> IsEnabledAsync(string flagName, ITargetingContext context);
    ValueTask<T> GetVariantAsync<T>(string flagName, T defaultValue);
}

public interface ITargetingContext
{
    string? TenantId { get; }
    string? PrincipalId { get; }
    string? Tier { get; }
    IReadOnlyDictionary<string, string> Tags { get; }
}
```

`ITargetingContext` is populated from `RequestContext` (per ADR-0026) by the default DI registration. Code that holds a `RequestContext` does not need to construct the targeting context manually; the second overload is for off-request paths (background workers, scheduled jobs) where the targeting context must be constructed explicitly.

`GetVariantAsync<T>` is the **variant** evaluation primitive — when a flag isn't binary but selects between named variants (e.g., `release.ai.routing-strategy` returning `"baseline"`, `"v2"`, or `"v3"`). Variants are a built-in `Microsoft.FeatureManagement` concept; exposing them through the same interface keeps consumers from reaching past `IFeatureGate` to the underlying SDK.

The Kernel-abstraction / sibling-implementation split also keeps the testing story clean: `InMemoryFeatureGate` lives in `HoneyDrunk.Kernel.Abstractions.Testing` per Invariant 15, so unit tests in any Node can flip flags without depending on App Configuration.

### D5 — Flag naming convention: `{category}.{node}.{feature}`

Every flag name has three dot-separated segments, in order:

1. **`category`** — one of `release`, `permission`, `operational` (D1). Validated at registration time (D6); unknown categories fail registration.
2. **`node`** — the lowercase Node name owning the flag (e.g., `notify`, `lately`, `pulse`). Co-locates flag ownership with the Node responsible.
3. **`feature`** — the kebab-case feature identifier (e.g., `bulk-send`, `video-posts`, `collector-emit-disable`). Brief, descriptive, stable.

Examples:

- `release.notify.bulk-send` — release flag for the bulk-send feature in Notify; expires when shipped.
- `permission.lately.video-posts` — permission flag gating video posts to entitled tenants.
- `operational.pulse.collector-emit-disable` — operational kill-switch to stop Pulse collectors from emitting.

The convention is enforced at registration (D6): a flag name that does not match `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$` fails CI validation. The category prefix makes the lifecycle policy visible at every use site — `release.*` flags carry expiry pressure visible to anyone reading the code; `permission.*` flags carry the audit/authorization weight (D8/D10) visible at every check.

### D6 — Flag registration: per-Node `featureflags.json` with CI validation

Each Node consuming flags declares them in a `featureflags.json` file committed to the Node's repo at `src/HoneyDrunk.<Node>/featureflags.json`. The file shape:

```json
{
  "$schema": "https://schemas.honeydrunkstudios.com/featureflags-v1.json",
  "flags": [
    {
      "name": "release.notify.bulk-send",
      "category": "release",
      "description": "Bulk-send feature for Notify; ships in 0.4.0",
      "owner": "HoneyDrunk.Notify",
      "created": "2026-05-22",
      "expires_on": "2026-08-20",
      "expected_orphan": false
    },
    {
      "name": "permission.lately.video-posts",
      "category": "permission",
      "description": "Video posts gated to Pro+ tier tenants",
      "owner": "HoneyDrunk.Lately",
      "created": "2026-05-22",
      "expires_on": null,
      "annual_review_due": "2027-05-22"
    }
  ]
}
```

CI validation (a new `job-featureflags-validate.yml` in HoneyDrunk.Actions per ADR-0012) enforces:

- **Every flag used in code is registered.** A static analyzer (custom Roslyn rule) scans the assembly for `IFeatureGate.IsEnabledAsync("…")` and `GetVariantAsync<…>("…")` calls; any literal flag string not present in `featureflags.json` fails the build. (Variable-fed flag names are flagged as a separate warning — they defeat static analysis and should be avoided.)
- **Every registered flag is used in code or marked `expected_orphan: true`.** `expected_orphan` exists for flags consumed by configuration-only paths (e.g., the operator dashboard reading the flag list to render); without this escape hatch, every operator-only flag would false-positive.
- **Naming convention** (D5) — flag name matches the regex.
- **Category coherence** — declared `category` matches the prefix in `name`.
- **Release-flag expiry** — `category: release` flags must have a non-null `expires_on`; expired release flags (today's date past `expires_on`) fail CI.
- **Permission/operational annual review** — flags with `annual_review_due` in the past produce a CI warning (not blocker) and surface in the operator dashboard.

The dual validation (used→registered and registered→used) catches both the most common flag rot symptoms: undeclared flag strings drifting through code, and dead flags accumulating in the registry after the feature was removed.

### D7 — Flag expiry: release flags have hard expiry; permission/operational require annual review

The lifecycle policies from D1 are enforced concretely:

- **Release flags** carry a mandatory `expires_on` date in `featureflags.json` (D6). Default at creation: **90 days from creation date**. After `expires_on`, the flag fails CI validation until either (a) the flag and all its references are removed (the feature is now permanently live), (b) the flag is recategorized (rare; usually means the flag was actually a permission or operational flag mislabeled) and the new category's rules apply, or (c) the `expires_on` is extended with a recorded justification in the `featureflags.json` history. CI does not auto-extend; extension is an explicit human decision visible in git history.
- **Permission flags** do not expire. They carry an `annual_review_due` date (default: one year from creation). Past-due review produces a CI warning and a row in the operator dashboard's "review needed" view; it does not fail CI. Permission flags encode long-lived business state (tenant entitlements); failing CI on them would force the operator to choose between flipping a paying tenant off and ignoring CI.
- **Operational flags** do not expire and require annual review identically to permission flags. They are intentionally long-lived as safety nets; an operational kill-switch that "expired" would be a load-bearing-fence-removed antipattern.

The 90-day release-flag default is the trade-off: long enough for feature work to ship in one or two release cycles; short enough that abandoned flags surface quickly. A team that consistently extends past 90 days is signaling that release-flag work needs a different work pattern (probably "ship in smaller increments").

### D8 — Per-tenant flag policy: drive code paths, not UX text

Permission flags evaluate against the active `TenantId` (D3 via `TenantTargetingFilter`). The policy that matters:

- **Flags drive code paths.** A permission flag must control which code executes (which queue is published to, which validation runs, which integration is called). A flag controlling whether a UI button is visible **as a function of code branching** is fine; a flag controlling whether the button label says "Send" or "Broadcast" is **not** — that's a UX/i18n change, belongs in the i18n surface, not the flag system.
- **Permission flags must not be used as ad-hoc authorization checks.** Authorization decisions ("can this principal perform this action?") belong in `HoneyDrunk.Capabilities` per ADR-0051. Permission flags are coarser — they gate the **availability** of a feature to a tenant, not the **authority** of a principal to invoke it. The two layers compose: a permission flag enables the feature; a Capabilities check authorizes the action. Conflating them puts authorization logic in App Configuration, where it is not audited at the granularity ADR-0030 requires, and where flag changes do not flow through the Capabilities-grant review pathway.
- **Permission flag flips are audit-bearing events** (D10) per ADR-0030. The audit record captures the operator who flipped the flag, the tenant scope of the change, the previous and new state, and the timestamp. This makes permission-flag changes auditable similarly to Capabilities grants, without conflating the two layers.

### D9 — Local-dev affordances: flags default to enabled in dev, disabled elsewhere

The "off by default in lower environments, on by default in dev" inversion is the single most useful local-dev affordance for a trunk-based codebase (ADR-0053):

- **In `dev` environment** (loaded via App Configuration label `dev`): all flags default to **enabled** unless explicitly overridden in the `dev`-labeled flag value. Devs writing in-progress flagged code see their own code paths running locally without per-flag opt-in ceremony.
- **In `staging` and `prod`** (labels `staging` and `prod`): all flags default to **disabled** unless explicitly enabled. The standard production-safety posture.
- **In CI** (label `ci`): flags default to disabled, mirroring prod. CI tests that need a flag on enable it explicitly via the test fixture (`InMemoryFeatureGate.SetFlag("…", enabled: true)` per the testing pattern in D4); this surfaces test-time intent explicitly rather than relying on environment-default magic.

The inversion is encoded in `Microsoft.FeatureManagement`'s `RequirementType.All` vs `Any` is not the mechanism — instead, the dev label in App Configuration carries the explicit "enabled by default" definition for each flag; the staging/prod labels carry the production definition. The CI validation in D6 enforces that every flag has both a `dev` and a non-dev label defined; missing one fails CI.

### D10 — Observability: structured logs, sampling, audit for permission flips

Every flag evaluation emits a structured log line via `HoneyDrunk.Observe` (per ADR-0010 and ADR-0040). The log shape:

```json
{
  "event": "feature_flag_evaluated",
  "flag.name": "permission.lately.video-posts",
  "flag.category": "permission",
  "flag.decision": true,
  "flag.variant": null,
  "tenant.id": "tenant-abc-123",
  "principal.id": "prn-789",
  "agent.id": null,
  "trace_id": "abc-def-…"
}
```

To avoid log explosion on hot-path flags (a flag checked thousands of times per request), evaluation logging is **sampled at 1% for hot-path flags** (flags marked `hotpath: true` in `featureflags.json`); all other flags are logged at 100%. The `hotpath` marking is explicit; the default is "log every evaluation," which is the safer-for-debuggability default.

**Permission-flag flips are audit events** per ADR-0030 — these are quasi-authorization decisions (D8) and the audit substrate is the right surface for them. The audit record captures operator identity, tenant scope, previous/new state, and timestamp. Operational-flag flips are also audited (kill-switch usage during incidents is exactly the kind of event the post-mortem needs visibility into). Release-flag flips are logged but not audited — release-flag toggling is routine dev workflow and audit-logging it adds noise without value.

Cross-references: ADR-0040 (Azure Monitor / App Insights as the log backend), ADR-0030 (Audit substrate for flips), ADR-0051 (Capabilities — for distinguishing flags from authorization).

### D11 — Operator surface: `operator flags …` CLI subcommand

The Operator Node (per ADR-0018) gains a `flags` subcommand:

- `operator flags list [--node <node>] [--category <cat>]` — list flags, with current state per environment.
- `operator flags show <flag-name>` — detailed view of a single flag: current state per environment, targeting rules, lifecycle metadata, last-flipped timestamp and operator.
- `operator flags enable <flag-name> [--env <env>] [--tenant <tenant-id>] [--percentage <0–100>]` — enable a flag, optionally scoped to env/tenant/percentage. Permission and operational flips are audited per D10.
- `operator flags disable <flag-name> [--env <env>] [--tenant <tenant-id>]` — disable; same audit semantics.
- `operator flags expire <flag-name>` — for release flags only; immediately marks the flag as expired (triggers CI failure on next build), forcing the cleanup PR.
- `operator flags review-due [--node <node>]` — list permission/operational flags past their `annual_review_due`.

The Operator Node reads and writes via the App Configuration SDK directly; the dependency is `HoneyDrunk.FeatureFlags.Abstractions` (for the targeting types) plus the App Configuration management SDK (for the write path; the runtime SDK is read-only). All write operations capture `RequestContext.PrincipalId` for the audit record.

The operator dashboard (web UI, when it lands per ADR-0018 Phase 2) surfaces the same operations through a richer interface — review-due flags as a dashboard, flip history per flag, percentage-rollout sliders. CLI lands first; UI is downstream.

### D12 — Cross-cutting: flags vs config

The distinction matters because the two surfaces drift toward each other if not bounded:

- **Configuration** (ADR-0005) carries **typed values** that affect application behavior: connection strings, timeout milliseconds, retry counts, queue names. Config changes typically require app restart (or push-refresh for hot-reload-capable settings). Config does not have lifecycle policy — a connection string is good until it isn't.
- **Feature flags** (this ADR) carry **boolean enablement** (with percentage and targeting filters): "is this feature on?" Flags are designed to flip without restart, are audited (for permission/operational), and have explicit lifecycle policies.

A boolean field in App Configuration is **not** a feature flag. The decision rule: if the value answers "is this feature on for this evaluation?" and benefits from percentage rollout, tenant targeting, or kill-switch semantics, it's a flag. If it answers "what value should the application use?" and would be inappropriate to flip mid-traffic, it's config.

App Configuration holds both; the surface inside `Microsoft.FeatureManagement` (with feature-flag metadata, targeting filters, audit) is the flag surface, and the rest is config. The CI validator (D6) refuses to register a feature flag whose value is not boolean (or a named-variant enum), enforcing the boundary at registration time.

### D13 — Anti-patterns explicitly forbidden

The following patterns are forbidden by this ADR; the `review` agent per ADR-0044 D3 enforces them as part of the code-review checklist:

- **Flag-checking inside a tight loop.** Each `IsEnabledAsync` call is cheap but not free; calling it 10,000 times in a loop is wasteful and produces a log-line storm even after D10's sampling. Pattern: hoist the evaluation outside the loop, or cache the result on a per-request scope (`IFeatureGate` has request-scoped caching by default; consumers should rely on it rather than introducing local caches).
- **Using a flag as a stand-in for an authorization check.** Authorization decisions belong in `HoneyDrunk.Capabilities` per ADR-0051. A permission flag may gate feature availability; the Capabilities check authorizes the principal's invocation of it. Conflating the two puts authorization logic in App Configuration (under-audited, no granular grant review).
- **Flag-checking in code that does not have access to `RequestContext`.** If a code path needs to evaluate a tenant-targeted flag but is not in the request scope (e.g., a background worker processing a queue message), the **fix is to plumb the context through, not to bypass it** by hard-coding tenant IDs or constructing a fake targeting context. The Grid's principle is that targeting context flows with the work; bypassing it produces a flag-evaluation outcome that doesn't match what the request would produce, causing observability and audit gaps.
- **String-concatenating flag names at the call site.** `IsEnabledAsync($"release.{node}.{feature}")` defeats the static analyzer in D6 (no literal string to match against `featureflags.json`). Pattern: hold flag names as `const string` declarations near the consumer, so the static analyzer can resolve them and the registry stays accurate.
- **Long-lived release flags.** A release flag that has been extended past its `expires_on` more than once is a signal that the feature work is not progressing in shippable increments; the right response is to address the work-pattern issue, not to extend the flag indefinitely.
- **Permission flags whose only effect is UX text.** Per D8; UX-only changes belong in i18n, not the flag system.

### D14 — Phased rollout

- **Phase 1 (Week 1–2) — `IFeatureGate` abstraction + `HoneyDrunk.FeatureFlags` Node standup.** Add `IFeatureGate`, `ITargetingContext`, and `InMemoryFeatureGate` to `HoneyDrunk.Kernel.Abstractions` (and `HoneyDrunk.Kernel.Abstractions.Testing`). Stand up the `HoneyDrunk.FeatureFlags` Node with the `Microsoft.FeatureManagement.AzureAppConfiguration`-backed implementation, the `TenantTargetingFilter`, and the App Configuration label conventions per D9.
- **Phase 2 (Week 2–3) — CI validation + first consumer.** Author `job-featureflags-validate.yml` in HoneyDrunk.Actions per ADR-0012. Author the Roslyn analyzer for static flag-string discovery. Pilot consumption in `HoneyDrunk.Notify` (one release flag for an in-progress bulk-send feature) to validate the end-to-end loop: declare → use → CI validates → flip via operator CLI → log emitted → audit recorded.
- **Phase 3 (Week 4–6) — Operator CLI subcommand.** Author `operator flags …` per D11. Wire audit emission to `HoneyDrunk.Audit` per ADR-0030. Document the CLI workflows in the operator runbook.
- **Phase 4 (Month 2) — Per-tenant entitlement integration for Notify.Cloud.** Wire `TenantTargetingFilter` into Notify.Cloud's tenant-tier resolution; first permission flag (`permission.notify.bulk-send-cloud` or similar) gates a Cloud-only feature.
- **Phase 5 (Month 2–3) — Consumer-app PDR rollouts.** As Lately, Hearth, Currents, Arcadia, Curiosities reach standup, each adopts `IFeatureGate` from day one. Trunk-based dev (ADR-0053) becomes practical because the flag substrate is in place.
- **Phase 6 (Month 3+) — Escalation evaluation.** Review observed flag count, flip frequency, operator pain points. Decide whether any D11-class escalation trigger has fired (next subsection's hypotheticals). If not, hold on App Configuration.

Each phase is a discrete go/no-go.

### D15 — Escalation path: LaunchDarkly or self-hosted GrowthBook

Azure App Configuration's flag surface is the v1 default chosen for cost and the existing-Azure-relationship argument. It is **not** the best-in-class option. The Grid commits to the following documented escalation triggers — if any fires, the next ADR amendment moves flags to a dedicated flag platform:

| Trigger | Symptom | Action |
|---|---|---|
| Operator workflow pain | Flag count exceeds ~100 active flags and App Configuration's UI / SDK becomes the operator bottleneck | Evaluate LaunchDarkly (richer dashboard, targeting UX) and GrowthBook (self-hosted, similar UX) |
| Experimentation needs | A/B testing with statistical significance, conversion tracking, automated decision rollouts become a requirement | LaunchDarkly's experimentation surface or a dedicated experimentation platform; App Configuration is not built for this |
| Multi-tenant operator delegation | Tenant-scoped operator personas need to flip flags within their tenant boundary; App Configuration's RBAC is workspace-level, not flag-level | LaunchDarkly's project/environment model, or build a thin authorization layer on top of App Configuration |
| Cost escalation | App Configuration's flag-evaluation API cost becomes meaningful (extremely unlikely at v1 Grid scale) | Re-evaluate per-flag pricing of LaunchDarkly vs hosting GrowthBook |

The escalation preserves the substrate: `IFeatureGate` abstraction stays, `HoneyDrunk.FeatureFlags.LaunchDarkly` (or `.GrowthBook`) backing comes online, consumers re-register their DI to the new backing. Flag names, lifecycle policy, audit hooks, operator CLI semantics all survive. The cost is the implementation of the new backing plus the migration of existing flag definitions to the new platform's storage shape.

LaunchDarkly is rejected as v1 (per Alternatives) primarily on cost (per-seat pricing scales poorly for a solo-dev shop) and on the existing-Azure-relationship argument; reconsidered if the triggers above fire.

### D16 — Relationship to ADR-0015, ADR-0005, ADR-0030, ADR-0053

- **ADR-0015 D-revisions (Container Apps traffic splitting)** — orthogonal. Container Apps revisions split traffic between **deployed versions** of a service; feature flags toggle **code paths** within a single version. The two layers compose: a new revision can deploy with a release flag off in prod, then the flag is flipped on (per-tenant or by percentage) without a redeploy. ADR-0015's traffic-splitting is for the deploy-side rollback story; flags are for the application-side enablement story.
- **ADR-0005 (Config & Secrets Strategy)** — extended. ADR-0005 selects App Configuration as the config backend; this ADR commits to the App Configuration feature-flags surface as the flag backend. Both surfaces live in the same App Configuration resource; the boundary between them is D12.
- **ADR-0030 (Grid-Wide Audit Substrate)** — extended. Permission and operational flag flips emit audit events per D10. Release-flag flips do not (D10 rationale).
- **ADR-0053 (Trunk-Based Development)** — completed. ADR-0053 deferred the flag-system commitment; this ADR provides it. Trunk-based dev's "decouple deploy from release" property is unlocked.

## Consequences

### Affected Nodes

- **HoneyDrunk.Kernel** — `HoneyDrunk.Kernel.Abstractions` gains `IFeatureGate`, `ITargetingContext`, `Feature`/`Variant` types. `HoneyDrunk.Kernel.Abstractions.Testing` gains `InMemoryFeatureGate` for unit tests per Invariant 15.
- **HoneyDrunk.FeatureFlags** — **new Node**, standup governed by this ADR. Holds the `Microsoft.FeatureManagement.AzureAppConfiguration`-backed `IFeatureGate` implementation and the `TenantTargetingFilter`. Sector: Core.
- **HoneyDrunk.Actions** — gains `job-featureflags-validate.yml` reusable workflow and the Roslyn analyzer NuGet package for flag-string static analysis.
- **HoneyDrunk.Vault** — App Configuration access patterns are unchanged from ADR-0005 (managed identity); no new secrets in v1.
- **HoneyDrunk.Operator** (per ADR-0018) — gains `operator flags …` subcommand per D11.
- **HoneyDrunk.Audit** — receives permission/operational flip events per D10 / ADR-0030.
- **HoneyDrunk.Observe** — receives feature-flag-evaluation log events per D10 / ADR-0040.
- **HoneyDrunk.Notify** — Phase 2 pilot consumer; first release flag and the end-to-end loop validation.
- **HoneyDrunk.Notify.Cloud** (PDR-0002) — Phase 4 consumer; per-tenant permission flag for paid-tier features.
- **HoneyDrunk.Lately / Hearth / Currents / Arcadia / Curiosities** (PDR-0003/0005/0006/0007/0008) — Phase 5 consumers; flag substrate in place from day one of their standup.
- **HoneyDrunk.Architecture** — `catalogs/nodes.json` gains `HoneyDrunk.FeatureFlags` entry; `catalogs/contracts.json` gains `IFeatureGate` under the Kernel-published contracts; `catalogs/relationships.json` captures the FeatureFlags → App Configuration external dependency; `constitution/feature-flow-catalog.md` gains a new "feature-flag evaluation" flow.

### Invariants

Adds two:

- **Invariant: feature flags are evaluated through `IFeatureGate`, never via direct SDK calls to `Microsoft.FeatureManagement` or the App Configuration client.** Preserves backend reversibility (D15 escalation), audit hookup (D10), and PII scrubbing on log emission.
- **Invariant: feature-flag names follow `{category}.{node}.{feature}` and are registered in the consuming Node's `featureflags.json` before first use.** CI gate per D6.

(Final invariant numbers assigned when the implementing work updates `constitution/invariants.md`; `hive-sync` reconciles per the ADR-0044 pattern.)

### Operational Consequences

- **No new vendor relationship at v1.** Flags share the App Configuration resource already provisioned per ADR-0005. No new account, no new billing line, no new secret to rotate.
- **Release-flag discipline is a new operator habit.** Expiry pressure (D7) means the operator must actually delete flags when features ship; a build that breaks because `release.notify.bulk-send` expired is the intended forcing function, not a bug.
- **Permission-flag review cadence is annual but unenforced** (warning, not gate). The operator dashboard surfaces past-due reviews; whether they get reviewed is operator discipline.
- **Operational flags carry incident-response weight.** A kill-switch that isn't tested doesn't work; the operator runbook should include periodic exercise of operational-flag flip paths (a quarterly fire drill, not enforced by CI).
- **Static flag-string analysis is a new CI surface.** The Roslyn analyzer adds ~5–10s to PR CI; the value (preventing undeclared flags from drifting in) is high relative to the cost.
- **The flag/config boundary (D12) is a judgment call** at the edges. The CI validator catches the obvious case (non-boolean values declared as flags) but not the philosophical case (e.g., a feature flag that probably should have been config). The `review` agent per ADR-0044 D3 carries the case-by-case judgment.

### Follow-up Work

- Stand up `HoneyDrunk.FeatureFlags` Node per Phase 1 (catalog entry, package skeleton, App Configuration backing, `TenantTargetingFilter`).
- Add `IFeatureGate`, `ITargetingContext`, `InMemoryFeatureGate` to `HoneyDrunk.Kernel.Abstractions` per Phase 1.
- Author `job-featureflags-validate.yml` and the Roslyn analyzer in HoneyDrunk.Actions per Phase 2.
- Pilot consumption in `HoneyDrunk.Notify` per Phase 2 (first release flag, end-to-end loop validation).
- Author `operator flags …` CLI subcommand per Phase 3.
- Wire permission/operational flip events to `HoneyDrunk.Audit` per Phase 3 / ADR-0030.
- Wire flag-evaluation log events to `HoneyDrunk.Observe` per Phase 3 / ADR-0040.
- Document the `featureflags.json` schema at `https://schemas.honeydrunkstudios.com/featureflags-v1.json`.
- Update `.claude/agents/review.md` with the D13 anti-pattern checklist.
- Add a new "feature-flag evaluation" flow to `constitution/feature-flow-catalog.md`.
- Update `constitution/invariants.md` with the two new invariants.
- Pilot per-tenant permission flag for Notify.Cloud per Phase 4.
- Document the D15 escalation triggers in `business/context/` so the operator can recognize them.

## Alternatives Considered

### LaunchDarkly as v1 backend

Considered as the v1 default. Strong product: industry-leading targeting UX, robust SDK story across languages, mature experimentation surface, well-trodden operator workflows. **Rejected as v1** on three grounds:

- **Cost.** LaunchDarkly's pricing is per-seat with meaningful minimums; for a solo-dev shop, the per-month cost is non-trivial relative to the budget posture committed to in ADR-0052. The App Configuration flag surface is essentially free at v1 Grid scale (existing relationship, included in the App Configuration line we already pay).
- **Existing-relationship argument.** Same logic as ADR-0040 (Azure Monitor over Grafana Cloud), ADR-0045 (App Insights over Sentry), ADR-0047 (Azure Load Testing over k6). Azure relationship is sunk-cost; LaunchDarkly is a net-new vendor with its own account, billing, secret rotation, and incident exposure.
- **Capability headroom.** The v1 flag needs (release/permission/operational with tenant targeting and percentage rollout) fit cleanly inside App Configuration's surface. LaunchDarkly's premium features (experimentation, debugger, audit log with per-environment-permissions) are not load-bearing at v1; reaching for them speculatively is the same pattern ADR-0045 D11 rejected.

Documented as the D15 escalation path with explicit triggers. Picked when real evidence shows App Configuration's flag surface is the bottleneck, not before.

### GrowthBook self-hosted

Considered. Open-source, free, full feature-flag platform with experimentation. Rejected on operational burden: self-hosting requires a database, a hosting environment, monitoring, backup, security patching, and version upgrades. For a solo-dev shop, that surface area is a daily-tax that App Configuration does not impose. The savings (zero license cost) are real but smaller than the ops cost.

Documented as the alternative escalation target under D15 if LaunchDarkly's cost is also unacceptable.

### Unleash self-hosted

Considered. Same shape as GrowthBook (open-source, self-hosted). Rejected for the same reason: ops burden exceeds the value at v1 scale.

### No formal flag system; ad-hoc `appsettings.json` booleans

Considered (and is the de-facto current state). Cheapest option. Rejected because:

- **Trunk-based dev (ADR-0053) requires flags.** Without per-flag enablement, in-progress work either blocks the trunk (defeating trunk-based) or ships visible (defeating the safety property). The flag system is load-bearing for the work-pattern commitment.
- **Per-tenant entitlement (Notify.Cloud) requires targeting.** `appsettings.json` booleans are deploy-time, not request-time, and cannot vary per tenant within a shared deployment.
- **Operational kill-switches require runtime control.** `appsettings.json` changes require redeploy; an operational flag that needs a redeploy to flip is not a kill-switch in any meaningful sense.

The three forcing functions together make a formal flag system necessary, not optional.

### Build a custom flag system in `HoneyDrunk.Kernel`

Considered. Full control over the implementation. Rejected because `Microsoft.FeatureManagement` already implements the abstraction shape the Grid needs (`IFeatureManager`, custom filters, label-aware refresh) with mature behavior around caching, refresh, and DI integration. Reimplementing that surface inside Kernel is meaningful work with no advantage; the abstraction (`IFeatureGate`) sits one layer above `IFeatureManager` and lets the implementation use the library without coupling consumers to it. The custom-built option is reconsidered only if `Microsoft.FeatureManagement` introduces a blocking constraint (none currently identified).

### Skip per-Node `featureflags.json`; declare flags in code only

Considered. Pure-code declaration is the simpler version; no JSON file, no schema. Rejected because:

- **Operator visibility.** The operator needs a single place to see "what flags does this Node consume?" without code-archaeology. The JSON file is that place.
- **CI validation.** The "every flag used in code is registered" / "every registered flag is used" dual-validation requires a registry; code-only declaration loses one side.
- **Lifecycle metadata.** `expires_on`, `annual_review_due`, `owner`, `description` need somewhere to live; attributes on a `const string` would work but make the surface harder to inspect tooling-side.

The JSON registry is mild overhead with material operator and CI benefits.

### Skip lifecycle policies; treat all flags identically

Considered. Simpler model — every flag is just a flag. Rejected because the three categories have genuinely different operational profiles: release flags **should** be deleted; permission flags **should not** be deleted; operational flags **should** survive even when "unused" because their value is precisely their availability. Treating them identically forces one policy to win, and any choice harms one of the three.

The three-category model is small enough overhead (one field at registration) and produces dramatically better lifecycle outcomes.

### Defer the flag-system commitment until Notify.Cloud needs it

Rejected. The forcing functions are not just Notify.Cloud:

- ADR-0053 trunk-based dev needs flags **now** (already accepted).
- The AI-sector standup wave (ADR-0016+) wants flags from day one of standup.
- The consumer-app PDRs (0003/0005/0006/0007/0008) want flags from day one of standup.

Deferring would force each of those consumers to either reinvent or wait. The flag substrate is closer to "Kernel-adjacent infrastructure" than "Notify.Cloud feature work" in its centrality; standing it up early is the right sequencing.
