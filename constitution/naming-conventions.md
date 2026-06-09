# Naming Conventions

Canonical naming rules for all artifacts in the HoneyDrunk Grid.

**Last Updated:** 2026-05-17

---

## Node IDs

Used in `catalogs/nodes.json`, `relationships.json`, `services.json`, and the website data schema.

- **Format:** `honeydrunk-{name}` (kebab-case)
- **Examples:** `honeydrunk-kernel`, `honeydrunk-transport`, `honeydrunk-web-rest`
- **No exceptions:** all Node IDs use the `honeydrunk-` prefix.

When creating a new Node, always use the `honeydrunk-` prefix. Pulse now follows the same prefix rule as every other Node.

---

## GitHub Repositories

- **Format:** `HoneyDrunk.{Name}` (PascalCase, dot-separated)
- **Examples:** `HoneyDrunk.Kernel`, `HoneyDrunk.Transport`, `HoneyDrunk.Web.Rest`
- **Multi-word names** use dots: `HoneyDrunk.Web.Rest`, not `HoneyDrunk.WebRest`

---

## NuGet Packages

- **Format:** `HoneyDrunk.{Node}[.{SubPackage}]` (PascalCase, dot-separated)
- **Core package:** `HoneyDrunk.Kernel`
- **Abstractions:** `HoneyDrunk.Kernel.Abstractions`
- **Providers:** `HoneyDrunk.Vault.Providers.AzureKeyVault`
- **Transport implementations:** `HoneyDrunk.Transport.AzureServiceBus`

### Package Suffixes

| Suffix | Purpose | Example |
|--------|---------|---------|
| `.Abstractions` | Contracts-only, zero runtime dependencies | `HoneyDrunk.Kernel.Abstractions` |
| `.Providers.{Name}` | Provider slot implementation | `HoneyDrunk.Vault.Providers.File` |
| `.AspNetCore` | ASP.NET Core integration layer | `HoneyDrunk.Auth.AspNetCore` |
| `.InMemory` | In-memory implementation for testing | `HoneyDrunk.Transport.InMemory` |
| `.Tests` | Test project (not published) | `HoneyDrunk.Kernel.Tests` |
| `.Canary` | Cross-boundary canary tests (not published) | `HoneyDrunk.Transport.Canary` |

---

## C# Namespaces

- **Format:** Mirrors package name exactly
- **Root:** `HoneyDrunk.{Node}`
- **Sub-namespaces** follow folder structure: `HoneyDrunk.Kernel.Context`, `HoneyDrunk.Transport.Pipeline`
- **Abstractions:** `HoneyDrunk.{Node}.Abstractions`

---

## C# Types

- **Classes/Interfaces:** PascalCase (`GridContext`, `ITransportPublisher`)
- **Interfaces:** Prefix with `I` (`ISecretStore`, `IGridContext`)
- **Private fields:** `_camelCase` with underscore prefix
- **Locals/parameters:** `camelCase`
- **Constants:** PascalCase (`MaxRetries`, not `MAX_RETRIES`)

---

## Project Folder Structure

Repos use a doubled nesting pattern:

```
HoneyDrunk.{Node}/                    ← Git repo root
├── HoneyDrunk.{Node}/                ← Solution folder
│   ├── HoneyDrunk.{Node}.slnx
│   ├── HoneyDrunk.{Node}/           ← Main library project
│   ├── HoneyDrunk.{Node}.Abstractions/
│   ├── HoneyDrunk.{Node}.Tests/
│   └── ...provider/integration projects
├── LICENSE
└── README.md
```

---

## Service IDs

Used in `catalogs/services.json` to identify deployable processes.

- **Format:** `{node-short}-{role}` (kebab-case)
- **Examples:** `pulse-collector`, `notify-worker`, `notify-functions`, `studios-website`
- `node-short` drops the `honeydrunk-` prefix for brevity

---

## File Naming

| Artifact | Format | Example |
|----------|--------|---------|
| C# source files | PascalCase, matches public type | `GridContext.cs` |
| Test files | `{TypeName}Tests.cs` | `GridContextTests.cs` |
| Issue packets | `{YYYY-MM-DD}-{repo-short}-{description}.md` | `2026-03-22-kernel-add-websocket-mapper.md` |
| ADRs | `ADR-{NNNN}-{kebab-case-title}.md` | `ADR-0001-node-vs-service.md` |
| LDRs (Loop Definition Records) | `loop-{NNNN}-{kebab-case-slug}.md` in `loops/` | `loop-0001-hive-sync.md` |
| Config/YAML | Descriptive, kebab-case | `pr-core.yml`, `local.settings.json` |

---

## Commit Messages

- **Format:** Conventional commits
- **Prefixes:** `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`
- **First line:** Present tense, under 50 characters
- **Examples:** `feat: add WebSocket context mapper`, `fix: correlation mismatch in outbox`

---

## Loop IDs (LDRs)

Used in `loops/` and in the matching ADR-0086 runner job specs.

- **Format:** `loop-{NNNN}-{slug}` (zero-padded sequence + kebab-case slug)
- **Examples:** `loop-0001-hive-sync`, `loop-0002-backlog-strategic`
- **Never reused:** a loop `id` is the unit of fleet identity (ADR-0093 D1/D8). Retired
  loops keep their id; the number is not recycled.
- **Runner jobs match the id:** a loop's runner job `JobId` equals its LDR `id` so the
  schedule and the decision record cross-reference (ADR-0093 D7; see the runner README's
  loop-job convention).

---

## Branch Naming

- **Features:** `feat/{short-description}`
- **Fixes:** `fix/{short-description}`
- **Chores:** `chore/{short-description}`

---

## Known Exceptions

None currently. Pulse previously used the short catalog ID `pulse`, but the canonical Node ID is now `honeydrunk-pulse`.
