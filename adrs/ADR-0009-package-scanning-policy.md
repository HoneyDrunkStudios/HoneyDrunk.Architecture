# ADR-0009: Package Scanning — Vulnerability and Dependency Freshness

**Status:** Proposed
**Date:** 2026-04-11
**Deciders:** HoneyDrunk Studios
**Sector:** Core

## Context

The HoneyDrunk Grid spans 11+ repos across .NET (NuGet) and npm stacks. `HoneyDrunk.Actions` already contains the reusable workflows and actions needed for package scanning:

- `security/vulnerability-scan` — runs `dotnet list package --vulnerable --include-transitive`
- `job-static-analysis.yml` — calls the vulnerability scan on every PR, default threshold `high`
- `nightly-security.yml` — deep nightly scan: vulnerable packages (including transitive), CodeQL SAST, gitleaks full-history secret scan, Trivy IaC misconfiguration
- `nightly-deps.yml` — detects outdated NuGet and npm packages; optionally creates grouped update PRs
- `deps/check-deprecated` — detects deprecated packages
- `pr-core.yml` — orchestrates build, test, static analysis (including vulnerability scan), and secret scan on every PR

As of April 2026, none of the consuming repos have any GitHub Actions workflows. The scanning infrastructure exists but is deployed nowhere.

Two distinct concerns must be treated separately:

1. **Vulnerability** — a package has a known CVE (reported via the NuGet advisory database / OSV). This is a security risk. Severity determines urgency.
2. **Outdated** — a newer version exists but no CVE is reported. This is a maintenance concern, not a security emergency.

Conflating them leads to either ignoring real CVEs (outdated noise drowns out signal) or unnecessary PR blocks (every version lag treated as a security issue).

Repos are public. Known-vulnerable dependencies are a real and visible risk to users and downstream consumers of published NuGet packages.

## Decision

### 1. PR-time vulnerability scanning blocks on `high` or `critical`

Every PR runs `job-static-analysis.yml` (via `pr-core.yml`) which calls `security/vulnerability-scan` with `fail-on-severity: high`. A PR with a `High` or `Critical` CVE cannot merge.

`Moderate` and `Low` severity vulnerabilities do **not** block PRs. They are surfaced nightly (see below).

### 2. Nightly deep vulnerability scan on all .NET repos

Each .NET repo wires up a consumer workflow calling `nightly-security.yml@main` on a nightly schedule (`0 2 * * *`). This scan:
- Runs `dotnet list package --vulnerable --include-transitive` and reports all findings including `Moderate` and `Low`
- Runs CodeQL SAST (`security-and-quality` queries)
- Runs gitleaks full-history secret scan
- Runs Trivy IaC misconfiguration scan when IaC files are present
- Uploads SARIF results to the GitHub Security tab
- Creates a GitHub Issue when findings are present (`create-issues: true`)

### 3. Nightly outdated package check on all .NET repos

Each repo wires up a consumer workflow calling `nightly-deps.yml@main` on a weekly schedule (`0 3 * * 1`, Monday mornings). This scan:
- Reports all outdated NuGet packages (`dotnet list package --outdated --include-transitive`)
- Checks for deprecated packages
- Does **not** block PRs — informational only
- Does **not** auto-create update PRs by default (`create-update-prs: false`)

Auto-update PRs (`create-update-prs: true`) may be enabled per-repo once the nightly dep workflow is stable, using `group-updates: true` to batch updates into a single PR.

### 4. npm (Studios) out of scope for this ADR

Studios will be addressed separately. This ADR covers `.NET`/`NuGet` repos only.

### 5. No Dependabot

Dependabot is not enabled. It creates one PR per package per repo, generating excessive noise for a solo developer with 11+ repos. The `nightly-deps.yml` grouped-update mode is the preferred automation path when auto-updates are warranted.

### 6. Transitive dependencies always included

All scans pass `--include-transitive`. A vulnerability in a transitive dependency is still a vulnerability in the built output.

### 7. Response SLA expectations

| Severity | Expected Response |
|----------|-------------------|
| Critical | Address before next merge to `main` |
| High | PR blocked — must be resolved to merge |
| Moderate | Address within current sprint (nightly issue tracks it) |
| Low | Backlog — address during regular maintenance windows |
| Outdated (no CVE) | Address during regular maintenance windows; no SLA |
| Deprecated | Address before the package reaches end-of-life |

## Consequences

### Positive

- **CVEs cannot be merged silently.** The PR gate blocks `High+` before code ships.
- **Moderate and transitive CVEs are visible.** Nightly scan + GitHub Issues creates a paper trail without blocking day-to-day work.
- **Outdated packages stay visible.** Weekly nightly-deps run means drift accumulates in a report, not invisibly.
- **All scanning is automated.** Solo developer and AI agents don't need to run scans manually.
- **SARIF results feed the GitHub Security tab.** Findings are queryable and tracked with remediation state.

### Negative

- **PR gate adds latency.** The `job-static-analysis.yml` step takes ~30–60 seconds per PR. Acceptable trade-off.
- **Nightly workflows consume Actions minutes.** Minimal for public repos (free tier). Monitor if repos go private.
- **Nightly issues can accumulate.** If findings aren't addressed, the issue count grows. Managed via the `create-issues` flag and issue de-duplication in the workflow (updates existing open issues rather than creating duplicates).

## Alternatives Considered

### Enable Dependabot

Creates individual PRs per package per repo. With 11+ repos and dozens of dependencies each, this generates dozens of open PRs simultaneously. The `nightly-deps.yml` grouped update approach is a better fit for solo operation.

### Block PRs at `moderate`

Would block merges for moderate-severity CVEs that may have no applicable exploit path in the codebase. `High+` is the industry-standard threshold for PR blocking; `moderate` is surfaced nightly instead.

### Block PRs on outdated packages

Outdated packages without CVEs are a maintenance concern, not a security gate. Blocking PRs on version lag would create constant friction with no security benefit.

### Manual scanning only

Relies on the developer remembering to run `dotnet list package --vulnerable` before each release. Unacceptable given the scope of 11+ repos and AI agent collaborators who do not run ad-hoc scans.

### GitHub Advanced Security / Dependabot Alerts only

Available for public repos on free tier. The decision to use `dotnet list package --vulnerable` directly means scans are reproducible, logged as artifacts, and visible in CI — not just in the GitHub web UI. GHAS alerts supplement but do not replace the CI gate.

## Implementation

Tracked as GitHub Issues in each consuming repo under initiative `adr-0009-package-scanning-rollout`.

Target repos: `HoneyDrunk.Kernel`, `HoneyDrunk.Auth`, `HoneyDrunk.Data`, `HoneyDrunk.Transport`, `HoneyDrunk.Vault`, `HoneyDrunk.Pulse`, `HoneyDrunk.Notify`, `HoneyDrunk.Web.Rest`

Each repo requires three new files:

1. `.github/workflows/pr.yml` — calls `pr-core.yml@main` (includes vulnerability scan gate)
2. `.github/workflows/nightly-security.yml` — calls `nightly-security.yml@main` on nightly schedule
3. `.github/workflows/nightly-deps.yml` — calls `nightly-deps.yml@main` on weekly schedule
