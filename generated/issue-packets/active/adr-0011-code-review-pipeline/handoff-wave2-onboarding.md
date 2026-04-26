# Handoff — Wave 1 → Wave 2 (Per-repo SonarCloud Onboarding)

This handoff is read **once**, at the moment Wave 1 of the ADR-0011 Code Review Pipeline initiative completes and Wave 2 (Kernel and Web.Rest SonarCloud onboardings) begins. Per ADR-0008 D7, handoffs are ephemeral baton passes — not live trackers — and are immutable under invariant 24.

The agents executing Kernel#NN (packet 06) and Web.Rest#NN (packet 07) read this handoff to understand exactly what Wave 1 delivered and what stable surfaces are now in place for them to consume.

## Wave 1 deliverables — what is now stable

### 1. ADR-0011 is Accepted

`adrs/ADR-0011-code-review-and-merge-flow.md` reads `**Status:** Accepted`. The ADR index row (`adrs/README.md`) reflects Accepted. Invariants 31, 32, 33 in `constitution/invariants.md` no longer carry the "(Proposed — this invariant takes effect when ADR-0011 is accepted)" qualifier. They are live rules.

`catalogs/relationships.json` has a new `agent_couplings` array (sibling to the existing `nodes` array) with the `scope-review-context-loading` entry — invariant 33 is now machine-discoverable.

The Wave 2 packets (06, 07) reference invariant 31 (tier-1 gate required), invariant 32 (PR-body packet link), and ADR-0011 D2 / D11 as binding rules — not aspirational.

### 2. `job-sonarcloud.yml` exists in HoneyDrunk.Actions

The reusable workflow `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-sonarcloud.yml@main` is callable via `workflow_call`. Its declared inputs:

- `dotnet-version` (default `'10.0.x'`)
- `runs-on` (default `'ubuntu-latest'`)
- `working-directory` (default `'.'`)
- `project-path` (default `''`)
- `sonar-organization` (required)
- `sonar-project-key` (required)
- `sonar-host-url` (default `'https://sonarcloud.io'`)
- `coverage-artifact-name` (default `'coverage-reports-ubuntu-latest'`)

Declared secrets:
- `sonar-token` (required)
- `github-token` (optional — falls back to `github.token`)

The job carries an `if:` trigger guard: `${{ github.event_name == 'pull_request' || (github.event_name == 'push' && github.ref == 'refs/heads/main') }}`. A misconfigured caller (e.g. wired to `push` on a feature branch) produces a skipped no-op rather than a paid SonarCloud run. Wave 2 callers are correctly configured (`pr.yml` triggers on `pull_request`); the guard passes naturally.

What the workflow does:
- Checks out the consumer repo with `fetch-depth: 0` (full git history for SCM blame).
- Carries a job-level `if:` trigger guard that refuses to run unless `github.event_name == 'pull_request'` or (`push` && `ref == refs/heads/main`). Defence-in-depth for ADR-0011 D11 cost discipline.
- Sets up .NET (the configured version) and Java 17 Temurin (mandatory for the Sonar Scanner CLI).
- Caches `~/.sonar/cache` and `./.sonar/scanner` for fast cold and warm runs.
- Installs `dotnet-sonarscanner` as a tool into `./.sonar/scanner`.
- Downloads the coverage artifact named `coverage-artifact-name` (already published by `pr-core.yml`'s `job-build-and-test.yml`) and points the scanner at `**/coverage.opencover.xml`.
- Runs `dotnet-sonarscanner begin → dotnet build → dotnet-sonarscanner end`.
- Reports the SonarCloud quality gate as a check run, with PR decoration via the `GITHUB_TOKEN` flowed in.

Permissions block: `contents: read`, `pull-requests: write`, `checks: write`. No broader permissions.

What the workflow does **not** do:
- Re-run `dotnet test`. Coverage comes from the upstream `pr-core.yml` artifact only.
- Wire itself into `pr-core.yml`. The wiring lives in each consuming repo's `pr.yml`.

### 3. `agent-run.yml` accepts a `packet-path` input — and the workflow asserts the link

`HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/agent-run.yml@main` now accepts an optional `packet-path` input. When supplied, the workflow does two things:

1. **Prompt-envelope injection (soft, primary path).** Appends the following block to the agent's prompt envelope:
   ```
   ---

   **Issue packet for this run:** `<packet-path>`
   **Packet permalink:** <permalink>

   When you open a pull request for this work, include the following line verbatim in the PR body:

   > Packet: <permalink>

   If you cannot include the link for any reason, label the PR `out-of-band` and explain why in the PR body.
   ```

2. **Post-hoc assert step (hard, mechanical guarantor).** After the agent run completes, a new "Assert PR-body packet link" step locates the PR the agent opened on the run's branch in `inputs.checkout-target` and uses `gh pr edit` to ensure the `> Packet: <permalink>` line is present in the PR body. Idempotent (no edit if line already present), soft on edge cases (no-PR / no-checkout-target / detached-HEAD all log a notice and exit 0).

Existing callers without `packet-path` are unaffected (input default is empty; both the resolve and assert steps no-op).

The `> Packet: <permalink>` quoted-block format is the contract the local review agent's packet-resolution logic in `.claude/agents/review.md` consumes. Wave 2 PRs opened by cloud agents include this line **regardless of LLM behaviour** — the workflow is the source of the line. Wave 2 PRs opened locally by the human can include it manually or rely on the local review agent reading the packet directly from disk.

### 4. SonarCloud organization + GitHub App + `SONAR_TOKEN`

The portal walkthrough `infrastructure/sonarcloud-organization-setup.md` was followed end-to-end during Wave 1. Resulting state:

- SonarCloud organization `honeydrunkstudios` exists, bound to the `HoneyDrunkStudios` GitHub org, on the Free plan (zero recurring cost on the public-repo path).
- The SonarCloud GitHub App is installed on **eleven public repos** with "Selected repositories" scope: HoneyDrunk.Kernel, HoneyDrunk.Transport, HoneyDrunk.Vault, HoneyDrunk.Vault.Rotation, HoneyDrunk.Auth, HoneyDrunk.Web.Rest, HoneyDrunk.Data, HoneyDrunk.Pulse, HoneyDrunk.Notify, HoneyDrunk.Actions, HoneyDrunk.Architecture. **HoneyDrunk.Studios is excluded** (TypeScript; separate future onboarding).
- `SONAR_TOKEN` is provisioned as a GitHub organization-level secret, with "Selected repositories" scoped to the same eleven repos.
- Default New Code definition: 30 days at the organization level. Per-repo overrides only when documented.
- Default quality gate: "Sonar way" (SonarCloud built-in).

For Wave 2:
- Kernel and Web.Rest are both on the eleven-repo install list, and the secret is accessible to both.
- The only remaining per-repo SonarCloud-side step is "Analyze new project → import → confirm project key" — a Human Prerequisite in each Wave 2 packet.

### 5. `out-of-band` label exists across active Grid repos

Two-packet split:
- **Packet 05a** shipped `.github/config/labels.yml` and the reusable `seed-labels.yml` workflow in HoneyDrunk.Actions.
- **Packet 05b** shipped the cross-repo fan-out workflow `seed-labels-fanout.yml` in HoneyDrunk.Actions, which uses the `LABELS_FANOUT_PAT` repo secret (fine-grained PAT scoped to the eleven Grid repos with `Issues: Write`) to call `gh label create/edit` against each repo. The human ran the fan-out workflow once via `workflow_dispatch`.

Result: the label `out-of-band` (color `ed7d31`, descriptive text per ADR-0011 D9) exists on every one of the eleven public repos enumerated above. Studios excluded.

For Wave 2: if a Kernel or Web.Rest PR is opened without a packet link (out-of-band), the human or the review agent flags it and applies the existing `out-of-band` label — the label does not need to be created ad hoc.

### 6. Agent definitions audited

`.claude/agents/scope.md` and `.claude/agents/review.md` were both audited as part of the Wave 1 acceptance packet. Both already reflect ADR-0011 D4 (coupled context-loading contracts), D6 (Cost Discipline checklist), and D7 (Grid-alignment check), and reference invariant 33. **No edits were needed; the audit recorded "no edits required" in the PR body.**

For Wave 2: the local review agent invoked against a Kernel or Web.Rest PR carries the full Grid-aware review surface. No agent-side gaps to work around.

## What Wave 2 must do

Both Wave 2 packets (06 Kernel, 07 Web.Rest) follow the same shape:

1. **Add `sonar-project.properties` at the inner project subdir** — `HoneyDrunk.Kernel/sonar-project.properties` and `HoneyDrunk.Web.Rest/sonar-project.properties` (next to the `.slnx`). **Not** at the git repo root. The scanner discovers it from the `working-directory` `pr.yml` already sets (`HoneyDrunk.Kernel` / `HoneyDrunk.Web.Rest`). Project key (`honeydrunkstudios_HoneyDrunk.<Repo>`), source dirs, test dirs, coverage report path, and exclusions inside.
2. **Add a `sonarcloud` job to `pr.yml`** with `needs: pr-core`, calling `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-sonarcloud.yml@main`, passing the project key and `coverage-artifact-name: 'coverage-reports-ubuntu-latest'`. Do not pass `actions-ref` — that input was removed from `job-sonarcloud.yml` because it was unused.
3. **Import the project into SonarCloud** via the GitHub App (Human Prerequisite).
4. **Wait for the first SonarCloud-enabled PR to run** — the SonarCloud GitHub App will publish its check.
5. **Read the literal check name from the first run's Checks tab** (historically "SonarCloud Code Analysis", but verify each time — do not paste blindly). Add it to branch protection on `main` (Human Prerequisite). GitHub rejects branch-protection rules that reference checks which have never run, so steps 4 and 5 cannot be combined.

**Test asymmetry note:** Kernel has no `.Canary` project on disk (verified 2026-04-26); its `sonar.tests` line lists only `HoneyDrunk.Kernel.Tests`. Web.Rest does have a `.Canary` project; its `sonar.tests` lists both `HoneyDrunk.Web.Rest.Tests` and `HoneyDrunk.Web.Rest.Canary`. The two packets diverge intentionally on this line.

Wave 2 packets must:
- Verify project layout (source dirs, test dirs, project file paths) against the actual `.slnx` and directory tree before committing.
- Reuse the coverage artifact — never re-run `dotnet test`.
- Keep permissions minimal (`contents: read`, `checks: write`, `pull-requests: write`).
- Use the project key SonarCloud actually generates on import — do not invent a different format.
- Document any initial findings on the legacy codebase rather than relaxing the gate to force a pass.

## Stable contracts Wave 2 depends on

- Reusable workflow path: `HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-sonarcloud.yml@main`
- Org-level GitHub secret name: `SONAR_TOKEN` (exact, all caps)
- Coverage artifact name: `coverage-reports-ubuntu-latest` (published by `pr-core.yml`'s `job-build-and-test.yml`)
- SonarCloud organization key: `honeydrunkstudios` (lowercase, one word, no dot, no separator).
- SonarCloud project key format: `honeydrunkstudios_HoneyDrunk.<Repo>` — verify against the auto-generated value during import.
- SonarCloud GitHub App check name (for branch protection): historically "SonarCloud Code Analysis" — but this is **not** an authoritative source. Read the literal string from the first PR's check list before pasting into branch protection.

## Invariants now binding for Wave 2 PRs

> **Invariant 31:** Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. *(Wave 2 packets add tier-2 SonarCloud as an additional required check — they do not weaken tier 1.)*

> **Invariant 32:** Agent-authored PRs must link to their packet in the PR body. The review agent resolves the packet via this link. *(Wave 2 PRs opened via the cloud `agent-run.yml` workflow with `packet-path` will include the link automatically. Wave 2 PRs opened locally must include it manually.)*

> **Invariant 33:** Review-agent and scope-agent context-loading contracts are coupled. *(Already satisfied; both agent files reflect the coupling. No Wave 2 action.)*

## Acceptance criteria for the handoff itself

- [x] Wave 1 packets 01, 02, 03, 04, 05a, 05b all merged.
- [x] ADR-0011 reads Accepted; ADR index reflects Accepted; invariants 31–33 carry no "(Proposed)" qualifier.
- [x] `catalogs/relationships.json` contains the `agent_couplings` array with the `scope-review-context-loading` entry.
- [x] `job-sonarcloud.yml` callable from any repo via `workflow_call`; trigger guard `if:` in place.
- [x] `agent-run.yml` accepts `packet-path`; prompt-side injection AND post-hoc assert step both in place.
- [x] SonarCloud org `honeydrunkstudios` exists; GitHub App on the eleven repos; `SONAR_TOKEN` org secret with selected-repos scope.
- [x] `out-of-band` label exists on the eleven repos (verified by browsing each repo's `/labels` page after the 05b fan-out run).
- [x] `LABELS_FANOUT_PAT` exists as a HoneyDrunk.Actions repo secret.
- [x] `scope.md` / `review.md` audit pass logged in packet 01's PR body — review.md Cost Discipline section has all six D6 items (hot-path logging, LLM cost cap, unguarded CI, Azure SKU, outbound HTTP, catalog loops).

When all of the above are checked, Wave 2 starts. Packets 06 (Kernel) and 07 (Web.Rest) run in parallel.

— end of handoff —
