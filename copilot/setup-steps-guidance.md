# Setup Steps Guidance

How agents should generate setup/onboarding steps for new contributors or new repo bootstrapping.

## New Contributor Onboarding

For any HoneyDrunk .NET repo:

1. Clone the repo
2. Ensure .NET 10.0 SDK is installed
3. Run `dotnet restore` from the solution directory
4. Run `dotnet build -c Release` (warnings are errors)
5. Run `dotnet test` to verify tests pass
6. Read the repo's `README.md` and `copilot-instructions.md`
7. Read the Architecture repo's `/repos/{node-name}/overview.md` and `boundaries.md`

## New Repo Bootstrap

When creating a new Node repo:

1. Create repo from the HoneyDrunk template (if available)
2. Add `Directory.Build.props` referencing HoneyDrunk.Standards
3. Create solution with `{Node}.Abstractions` and `{Node}` projects
4. Create `{Node}.Tests` project with xUnit + FluentAssertions
5. Add `.github/copilot-instructions.md` following existing repos as templates
6. Add entry to `catalogs/nodes.json` in Architecture repo
7. Add entry to `catalogs/relationships.json` if it depends on other Nodes
8. Create `/repos/{node-name}/` context files in Architecture repo
9. Set up CI via HoneyDrunk.Actions reusable workflows

## Common Build Commands

```bash
dotnet restore
dotnet build -c Release
dotnet test --no-build -c Release
dotnet pack -c Release
```
