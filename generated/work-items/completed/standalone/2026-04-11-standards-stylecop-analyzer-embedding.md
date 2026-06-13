---
name: Embed StyleCop and NetAnalyzer DLLs in HoneyDrunk.Standards package
type: bug-fix
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Standards
labels: ["bug", "tier-2", "infrastructure"]
dependencies: []
adrs: []
wave: "N/A"
initiative: standalone
node: honeydrunk-standards
version_bump: true
target_version: 0.2.7
---

# Bug Fix: StyleCop analyzer DLLs not loaded by CLI builds

## Summary

StyleCop SA\* rules are enforced by Visual Studio but silently ignored by `dotnet build` and CI pipelines. This is a split-brain enforcement gap: PRs pass CI with 0 SA warnings while the IDE shows errors. Fix: embed the analyzer DLLs directly in the `HoneyDrunk.Standards` `.nupkg` and wire them in the `.targets` file.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Standards`

## Root Cause

Two mechanisms in `0.2.6` are both broken for CLI builds:

**1. `buildTransitive/HoneyDrunk.Standards.props` — PackageReference injection (lines 75–87)**

```xml
<ItemGroup Condition="'$(HD_EnableAnalyzers)' == 'true'">
  <PackageReference Include="StyleCop.Analyzers" Version="1.2.0-beta.556" ...>
    <PrivateAssets>all</PrivateAssets>
    ...
  </PackageReference>
  <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="9.0.0" ...>
    <PrivateAssets>all</PrivateAssets>
    ...
  </PackageReference>
</ItemGroup>
```

NuGet restore runs **before** MSBuild imports `.props` from resolved packages. By the time this `<PackageReference>` is injected, restore is already finished. The packages are never downloaded for the consumer and the analyzer DLLs never reach the compiler's `/analyzer:` list.

**2. `PrivateAssets="all"` on the Standards `.csproj`**

StyleCop is a dependency of the Standards package itself with `PrivateAssets="all"`, which correctly prevents it from flowing to consumers via NuGet's dependency graph — but it also means the DLLs are only available at pack time, not at the consumer's build time.

**Why Visual Studio works:** VS uses its own Roslyn host and resolves analyzers from its extension/package cache independently of MSBuild restore ordering.

**Rejected fix:** Removing `PrivateAssets="all"` would force StyleCop on all consumers regardless of the `HD_UseStyleCop=false` toggle, since NuGet's dependency graph ignores MSBuild conditions.

## Fix

Pack the StyleCop (and NetAnalyzers) DLLs directly inside the `.nupkg` under `analyzers/dotnet/cs/`. Reference them from the `.targets` file using the existing `HD_UseStyleCop` / `HD_EnableAnalyzers` toggles.

## Changes Required

### 1. `HoneyDrunk.Standards.csproj` — add pack target to embed analyzer DLLs

Add a `<PropertyGroup>` that declares the package versions as properties (single source of truth, must stay in sync with the `<PackageReference>` declarations), and a `BeforeTargets="GenerateNuspec"` target that includes the DLLs as pack items:

```xml
<!-- Version constants — must match the <PackageReference> declarations below -->
<PropertyGroup>
  <_StyleCopVersion>1.2.0-beta.556</_StyleCopVersion>
  <_NetAnalyzersVersion>9.0.0</_NetAnalyzersVersion>
</PropertyGroup>

<Target Name="HD_EmbedAnalyzerDlls" BeforeTargets="GenerateNuspec">
  <!-- StyleCop DLLs -->
  <ItemGroup>
    <None Include="$(NuGetPackageRoot)stylecop.analyzers\$(_StyleCopVersion)\analyzers\dotnet\cs\StyleCop.Analyzers.dll"
          Pack="true"
          PackagePath="analyzers/dotnet/cs/StyleCop.Analyzers.dll"
          Visible="false" />
    <None Include="$(NuGetPackageRoot)stylecop.analyzers\$(_StyleCopVersion)\analyzers\dotnet\cs\StyleCop.Analyzers.CodeFixes.dll"
          Pack="true"
          PackagePath="analyzers/dotnet/cs/StyleCop.Analyzers.CodeFixes.dll"
          Visible="false" />
  </ItemGroup>

  <!-- NetAnalyzers DLLs -->
  <ItemGroup>
    <None Include="$(NuGetPackageRoot)microsoft.codeanalysis.netanalyzers\$(_NetAnalyzersVersion)\analyzers\dotnet\cs\Microsoft.CodeAnalysis.CSharp.NetAnalyzers.dll"
          Pack="true"
          PackagePath="analyzers/dotnet/cs/Microsoft.CodeAnalysis.CSharp.NetAnalyzers.dll"
          Visible="false" />
    <None Include="$(NuGetPackageRoot)microsoft.codeanalysis.netanalyzers\$(_NetAnalyzersVersion)\analyzers\dotnet\cs\Microsoft.CodeAnalysis.NetAnalyzers.dll"
          Pack="true"
          PackagePath="analyzers/dotnet/cs/Microsoft.CodeAnalysis.NetAnalyzers.dll"
          Visible="false" />
  </ItemGroup>
</Target>
```

> **Note:** `$(NuGetPackageRoot)` resolves to the global NuGet packages cache (e.g. `~/.nuget/packages/` on Linux, `%USERPROFILE%\.nuget\packages\` on Windows). It is set by NuGet during restore and is available to MSBuild targets. Verify the actual subfolder layout for each package in the local cache if the exact DLL filenames differ.

The existing `<PackageReference Include="StyleCop.Analyzers" ...>` and `<PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" ...>` with `PrivateAssets="all"` **stay** in the `.csproj` — they are needed at pack time to ensure the packages are restored and the DLLs are available.

### 2. `buildTransitive/HoneyDrunk.Standards.targets` — add `<Analyzer>` items

Add conditional `<Analyzer>` items in a new target or `ItemGroup` so consuming projects load the embedded DLLs:

```xml
<!-- ============================================
     Embedded Analyzer References
     ============================================ -->
<ItemGroup Condition="'$(HD_EnableAnalyzers)' == 'true'">

  <!-- StyleCop: loaded from embedded DLLs in the package -->
  <Analyzer
    Condition="'$(HD_UseStyleCop)' == 'true'"
    Include="$(MSBuildThisFileDirectory)../analyzers/dotnet/cs/StyleCop.Analyzers.dll" />
  <Analyzer
    Condition="'$(HD_UseStyleCop)' == 'true'"
    Include="$(MSBuildThisFileDirectory)../analyzers/dotnet/cs/StyleCop.Analyzers.CodeFixes.dll" />

  <!-- NetAnalyzers: loaded from embedded DLLs in the package -->
  <Analyzer Include="$(MSBuildThisFileDirectory)../analyzers/dotnet/cs/Microsoft.CodeAnalysis.CSharp.NetAnalyzers.dll" />
  <Analyzer Include="$(MSBuildThisFileDirectory)../analyzers/dotnet/cs/Microsoft.CodeAnalysis.NetAnalyzers.dll" />

</ItemGroup>
```

`$(MSBuildThisFileDirectory)` is the `buildTransitive/` folder at runtime. `../analyzers/dotnet/cs/` navigates to the `analyzers/dotnet/cs/` folder packed alongside it.

### 3. `buildTransitive/HoneyDrunk.Standards.props` — remove broken PackageReference injections

Remove the entire `<ItemGroup>` that injects `PackageReference` items into consuming projects (the broken mechanism). This is currently the last `<ItemGroup>` in the file, containing both the StyleCop and NetAnalyzers references.

**Remove (lines 75–87 in 0.2.6):**
```xml
<!-- ============================================
     Analyzer Package References
     ============================================ -->
<ItemGroup Condition="'$(HD_EnableAnalyzers)' == 'true'">
  <!-- StyleCop for naming and ordering conventions -->
  <PackageReference Include="StyleCop.Analyzers" Version="1.2.0-beta.556" Condition="'$(HD_UseStyleCop)' == 'true'">
    <PrivateAssets>all</PrivateAssets>
    <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
  </PackageReference>
  
  <!-- Microsoft Code Quality Analyzers -->
  <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="9.0.0">
    <PrivateAssets>all</PrivateAssets>
    <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
  </PackageReference>
</ItemGroup>
```

The `stylecop.json`, `.editorconfig`, and `HoneyDrunk.Standards.globalconfig` `<AdditionalFiles>` / `<EditorConfigFiles>` / `<GlobalAnalyzerConfigFiles>` items in `.props` are correct and must stay — they flow config to the analyzer, not the analyzer DLLs themselves.

### 4. Version bump to `0.2.7`

This is a **behavior change** — analyzers that were silently absent from CLI builds will now run. Consumers will see new build errors. Bump all non-test projects in the solution to `0.2.7` in a single commit before starting feature work.

Add a `[0.2.7]` CHANGELOG entry:

```
## [0.2.7] — 2026-04-11

### Fixed
- StyleCop SA* analyzer DLLs now loaded by `dotnet build` and CI pipelines.
  Previously, `PackageReference` injection from `.props` was silently skipped
  because NuGet restore runs before `.props` from resolved packages are imported.
  Analyzer DLLs are now embedded in the package under `analyzers/dotnet/cs/` and
  referenced directly from `.targets`.

### Breaking
- All consumer repos will see new SA* and CA* errors on first build after upgrade.
  These violations existed before but were invisible to CLI builds. Each repo needs
  a cleanup pass to fix or add targeted suppressions.

### Removed
- Broken `<PackageReference>` injections from `buildTransitive/HoneyDrunk.Standards.props`.
  These never worked for CLI builds and are replaced by embedded DLL references in `.targets`.
```

## Acceptance Criteria

- [ ] `dotnet build` on any consumer project (e.g. `HoneyDrunk.Vault`) produces SA\* diagnostics matching what Visual Studio shows
- [ ] `dotnet build` with `<HD_UseStyleCop>false</HD_UseStyleCop>` suppresses all SA\* rules in both IDE and CLI
- [ ] `dotnet build` with `<HD_EnableAnalyzers>false</HD_EnableAnalyzers>` suppresses all analyzers (StyleCop + NetAnalyzers) in both IDE and CLI
- [ ] `dotnet pack` produces a `.nupkg` with `analyzers/dotnet/cs/StyleCop.Analyzers.dll` and `StyleCop.Analyzers.CodeFixes.dll` inside it
- [ ] No new transitive NuGet dependencies added to consumer package graphs (`dotnet list package` on a consumer shows no new `StyleCop.Analyzers` or `Microsoft.CodeAnalysis.NetAnalyzers` entries)
- [ ] All projects bumped to `0.2.7`
- [ ] CHANGELOG entry added

## Downstream Impact

Every consumer repo (`HoneyDrunk.Kernel`, `HoneyDrunk.Vault`, `HoneyDrunk.Transport`, `HoneyDrunk.Auth`, `HoneyDrunk.Pulse`, `HoneyDrunk.Web.Rest`, `HoneyDrunk.Notify`) will see new SA\* errors on first `dotnet build` after upgrading to `0.2.7`. This is expected — those violations already exist; they were just invisible to CI. Each repo will need a cleanup pass (separate issues, separate PRs) to resolve the newly-visible diagnostics.

**Do not file those cleanup issues as part of this task.** This packet only covers the Standards package itself.

## Dependencies

None. Foundational fix — no upstream packages need to change.

## Agent Handoff

**Objective:** Fix the broken analyzer embedding in `HoneyDrunk.Standards` so that StyleCop SA\* rules are enforced by `dotnet build` / CI, not just Visual Studio. Bump to `0.2.7`.
**Target:** HoneyDrunk.Standards, branch from `main`
**ADRs:** None

**Constraints:**
- The existing `PrivateAssets="all"` on StyleCop and NetAnalyzers in the `.csproj` must stay — removing it would break the opt-out contract by forcing packages on all consumers
- The `stylecop.json`, `.editorconfig`, and `.globalconfig` items in `.props` must stay — they are config, not DLL references, and they work correctly
- Do not add any new runtime dependencies to the package (NuGet `<dependencies>` in the nuspec must remain empty for the `net10.0` target group)
- `HD_UseStyleCop=false` must continue to completely suppress StyleCop in consumers; verify this in the `<Analyzer>` item conditions

**Key Files:**
- `HoneyDrunk.Standards.csproj` — add `HD_EmbedAnalyzerDlls` pack target
- `buildTransitive/HoneyDrunk.Standards.props` — remove the broken `<PackageReference>` injection `<ItemGroup>`
- `buildTransitive/HoneyDrunk.Standards.targets` — add `<Analyzer>` items referencing embedded DLLs
- `CHANGELOG.md` — add `[0.2.7]` entry
