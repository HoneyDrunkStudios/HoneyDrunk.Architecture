# Tag and Release Conventions

How git tags map to release actions across the HoneyDrunk Grid. A single repo
can carry **multiple tag schemes at once** — git tags are independent named
refs, not one repo-wide version. Each scheme triggers exactly one workflow.

**Last Updated:** 2026-05-16

---

## The two schemes

| Scheme | Tag pattern | Triggers | Used by |
|--------|-------------|----------|---------|
| **Library / NuGet** | `v*` (e.g. `v0.4.0`) | `publish.yml` → NuGet publish | Every repo that ships NuGet packages |
| **Deployable** | `{component}-v*` (e.g. `functions-v0.1.0`) | `release-{component}.yml` → Azure deploy | Repos with deployable Nodes (per ADR-0015) |

The patterns are **disjoint** — `v*` only matches tags starting with `v`, so
`functions-v0.1.0` (starts with `f`) never matches `v*`, and `v0.4.0` never
matches `functions-v*`. Pushing a deploy tag does **not** trigger a NuGet
publish, and vice versa. No cross-firing.

### Trigger matrix (Notify as the example)

| Tag pushed | `publish.yml` (`v*`) | `release-functions.yml` (`functions-v*`) | `release-worker.yml` (`worker-v*`) |
|---|---|---|---|
| `v0.4.0` | ✅ NuGet publish | ❌ | ❌ |
| `functions-v0.1.0` | ❌ | ✅ deploy | ❌ |
| `worker-v0.1.0` | ❌ | ❌ | ✅ deploy |

---

## Library / NuGet versioning — lockstep per solution

Repos that publish NuGet packages version the **entire solution as one unit**:

- One `v{semver}` tag covers every package in the solution.
- **All packages share that version and are published together, even if a
  given package had no code change in that release.** We do not independently
  version packages within a solution.
- The version line is continuous and monotonic: `v0.3.0` → `v0.4.0` → …
- Driven by `publish.yml` (`on: push: tags: ['v*']`).

Rationale: consumers reference a coherent set. Lockstep versioning means
"Notify 0.4.0" is one knowable surface, not a matrix of per-package versions
that have to be cross-checked for compatibility.

---

## Deployable versioning — independent per component

A deployable repo often contains **more than one independently shippable
artifact** plus its NuGet packages. Notify, for example, produces:

- NuGet packages (`v*` line)
- `Notify.Functions` deployable (`functions-v*` line)
- `Notify.Worker` deployable (`worker-v*` line)

Each deployable has its **own version line**, incremented independently, so you
can redeploy the Worker without implying a Functions release or a NuGet bump.
Deploy workflows are **purely tag-triggered** — no `workflow_run` chaining off
NuGet publish. Deploying is an explicit, separate decision from publishing.

First deploy of any component starts at `{component}-v0.1.0`.

### Current component prefixes

| Repo | Deployable | Tag prefix |
|------|------------|------------|
| `HoneyDrunk.Notify` | Notify.Functions | `functions-v*` |
| `HoneyDrunk.Notify` | Notify.Worker | `worker-v*` |
| `HoneyDrunk.Pulse` | Pulse.Collector | `collector-v*` |

---

## Picking a version number

- **NuGet/library:** bump the whole solution. Even an unchanged package goes
  to the new `v{semver}`. Continue the existing line (don't restart).
- **Deployable:** independent per-component semver, starting `…-v0.1.0`. It is
  *not* required to match the repo's NuGet version. Coupling a deployable's
  version to the NuGet line is allowed but discouraged — it forfeits the
  independent release cadence that prefixed tags exist to provide.

---

## How to Update This File

- **New deployable Node:** add a row to *Current component prefixes* and define
  its `{component}-v*` prefix. The release workflow must trigger only on that
  prefix.
- **New tag scheme:** add it to *The two schemes* with its pattern, the single
  workflow it triggers, and a disjointness note vs. existing patterns.
- **Convention change:** update the rule and the rationale; never leave the
  matrix tables inconsistent with the actual workflow triggers.
