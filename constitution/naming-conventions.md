# Naming Conventions

Canonical naming rules for all artifacts in the HoneyDrunk Grid.

**Last Updated:** 2026-03-22

---

## Node IDs

Used in `catalogs/nodes.json`, `relationships.json`, `services.json`, and the website data schema.

- **Format:** `honeydrunk-{name}` (kebab-case)
- **Examples:** `honeydrunk-kernel`, `honeydrunk-transport`, `honeydrunk-web-rest`
- **Exception:** `pulse` — historical, no prefix

When creating a new Node, always use the `honeydrunk-` prefix. The `pulse` exception is grandfathered and should not be repeated.

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
| Config/YAML | Descriptive, kebab-case | `pr-core.yml`, `local.settings.json` |

---

## Commit Messages

- **Format:** Conventional commits
- **Prefixes:** `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`
- **First line:** Present tense, under 50 characters
- **Examples:** `feat: add WebSocket context mapper`, `fix: correlation mismatch in outbox`

---

## Branch Naming

- **Features:** `feat/{short-description}`
- **Fixes:** `fix/{short-description}`
- **Chores:** `chore/{short-description}`

---

## Known Exceptions

| Item | Convention | Actual | Reason |
|------|-----------|--------|--------|
| Pulse node ID | `honeydrunk-pulse` | `pulse` | Historical — predates convention. Grandfathered. |
| Pulse repo name | `HoneyDrunk.Pulse` | `HoneyDrunk.Pulse` | Repo name follows convention; only the catalog ID is short. |
