# HoneyDrunk Workflow Standard

**Status:** Active
**Owner:** HoneyDrunk.Actions
**Applies to:** HoneyDrunk.* repositories with GitHub Actions workflows

## Rule

Consumer repositories own workflow triggers, version/tag parsing, environment/variable resolution, and repo-specific metadata only. Build, test, scan, package, release-note, GitHub Release, container deploy, Function App deploy, scaffold preflight, and artifact publish mechanics live in `HoneyDrunk.Actions` reusable workflows or composite actions.

Repo-local workflows must not reimplement reusable mechanics with direct marketplace actions such as `actions/checkout`, `actions/setup-dotnet`, `actions/upload-artifact`, `softprops/action-gh-release`, `docker/login-action`, or Azure deploy actions unless `HoneyDrunk.Actions` is the repository being changed.

## Standard Caller Shapes

| Concern | Consumer workflow responsibility | Reusable workflow owner |
|---|---|---|
| PR validation | trigger, permissions, project path, optional Sonar/coverage wiring | `pr-core.yml`, `job-sonarcloud.yml`, `coverage-baseline-ratchet.yml` |
| Grid review request | pull request trigger and webhook variables/secrets | `job-review-request.yml` |
| Nightly security | schedule and project path | `nightly-security.yml` |
| Dependency updates | schedule, project path, update mode | `nightly-deps.yml` |
| Missing scaffold guard | expected project path and skip message | `job-solution-preflight.yml` |
| NuGet release | version/tag parsing and package metadata | `release.yml` |
| GitHub Release notes | product name, description, package list, docs URL | `release.yml` |
| Function App artifact build | solution path, publish project, artifact name | `job-dotnet-publish-artifact.yml` |
| Function App deploy | environment and resolved Azure target names | `job-deploy-function.yml` |
| Container App deploy | environment, image/build context, resolved Azure target names | `job-deploy-container-app.yml` |

## Release Standard

Package and library repositories should use a thin tag/dispatch workflow that computes the release version and calls `HoneyDrunk.Actions/.github/workflows/release.yml@main`. If a GitHub Release is required, pass `create-github-release: true` plus release metadata into the reusable workflow. Do not create a separate repo-local `github-release` job.

Deployable Function App repositories should call `job-dotnet-publish-artifact.yml` for restore/build/test/publish/upload, then call `job-deploy-function.yml` for deployment. Repo-local workflows may resolve environment-scoped variables, but must not carry local checkout/setup-dotnet/upload-artifact steps.

Container App repositories should call `job-deploy-container-app.yml`. Repo-local workflows may resolve environment-scoped variables and select build context/image names, but build/push/deploy/traffic-shift mechanics stay centralized.

## Migration Note

Older nodes may still carry copied `publish.yml` release-wrapper jobs or scaffold preflight shell snippets. Those are legacy drift and should be replaced with the standard reusable callers as Actions support lands.
