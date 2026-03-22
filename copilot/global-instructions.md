# Global Agent Instructions

These rules apply to all agents operating within the HoneyDrunk Grid.

## Before Starting Any Work

1. **Identify the target repo.** Use `/routing/repo-discovery-rules.md` to determine which repo owns the work.
2. **Load repo context.** Read `/repos/{node-name}/overview.md`, `boundaries.md`, and `invariants.md`.
3. **Check current focus.** Read `/initiatives/current-focus.md` to understand priorities.
4. **Classify the request.** Use `/routing/request-types.md` to determine the request type.
5. **Determine tier.** Use `/catalogs/flow_tiers.json` to classify the change tier.

## During Work

- **Respect boundaries.** Never add code that belongs in another Node. If unsure, check `boundaries.md`.
- **Preserve invariants.** Never violate rules in `constitution/invariants.md` or repo-specific `invariants.md`.
- **Follow dependency direction.** Changes flow upstream-first. Check `catalogs/relationships.json`.
- **Use templates.** When generating issues, use templates from `/issues/templates/`.

## Code Conventions (All .NET Repos)

- .NET 10.0, C# with primary constructors
- Nullable reference types enabled everywhere
- `PascalCase` for public types/members, `camelCase` for locals/parameters
- XML documentation on all public APIs
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`
- HoneyDrunk.Standards analyzers enforced

## Communication

- Be direct and concise
- Reference specific files, interfaces, and line numbers
- When proposing cross-repo changes, always list affected repos in dependency order
- When in doubt, suggest creating an ADR first
