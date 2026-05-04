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
- Before creating a new helper, mapper, validator, factory, extension method, or orchestration method, scan the current type, sibling types, and repo-level shared locations for existing behavior to reuse or extend.
- Prefer cohesive shared methods over one-off near-duplicates; extract repeated logic once the same shape appears twice or when the behavior is becoming a policy boundary.
- Do not create generic utility dumping grounds. Keep shared code close to its domain unless it is clearly cross-cutting.
- If duplication is intentional because two paths are expected to diverge, call that out in the PR or a short code comment.

## Communication

- Be direct and concise
- Reference specific files, interfaces, and line numbers
- When proposing cross-repo changes, always list affected repos in dependency order
- When in doubt, suggest creating an ADR first
