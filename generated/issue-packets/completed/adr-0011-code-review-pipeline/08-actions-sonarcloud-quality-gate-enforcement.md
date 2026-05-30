---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["feature", "tier-2", "ci-cd", "ops", "adr-0011"]
dependencies: ["packet:02"]
adrs: ["ADR-0011"]
initiative: adr-0011-code-review-pipeline
node: honeydrunk-actions
---

# CI: Enforce SonarCloud quality thresholds in `pr-core.yml`

## Summary

Add a tier-2 PR gate to `HoneyDrunk.Actions/pr-core.yml` that, after the existing `job-sonarcloud.yml` analysis finishes, polls the SonarCloud Web API for per-PR `new_*` measures (`new_violations`, `new_bugs`, `new_vulnerabilities`, `new_code_smells`, `new_security_hotspots`) and fails the PR when any metric exceeds its configurable threshold. Default thresholds: all zero (no new issues allowed). The gate has a `warn` / `enforce` mode that defaults to `warn` for a soft-launch period, matching the same warnings-only posture ADR-0044 packet 14 established for PR size discipline.

Why this exists: SonarCloud's custom Quality Gates are a paid feature on private organizations. The HoneyDrunk SonarCloud organization is on the free/OSS plan, which gates every project on the built-in "Sonar way" definition. That default gate does **not** condition on `new_violations > 0` — it conditions on coverage (≥ 80% on new code), duplications (≤ 3% on new code), and unreviewed security hotspots (100% reviewed). The result: Vault PR #44 showed 6 new issues and SonarCloud's check ran green, because the only paid-tier control we'd need to flip the check red (a custom gate with a `new_violations is greater than 0` condition) is unreachable on our plan.

ADR-0011 D11 named SonarCloud as "the third-party static analysis tool for tier 2" and ADR-0011 D8 listed "SonarCloud quality gate — public repo" as a required-blocking check. The intent of the ADR is that Sonar enforces quality at PR time. The free-tier limitation makes the *delivery mechanism* a poor fit — the data is there, the gate isn't. This packet moves the threshold logic into `pr-core.yml` (where gate logic already lives — coverage ratchet, NuGet consistency, PR size) and treats SonarCloud as a data source. Same posture the existing `pr.yml` skip-when-pr-core-failed pattern already encodes: tier-1 gates live in pr-core, SonarCloud is invoked from the consumer's `pr.yml` as a downstream tier-2 stage.

## Target Repo

`HoneyDrunkStudios/HoneyDrunk.Actions` — primary changes land in `pr-core.yml` (or, equivalently, a new `job-sonarcloud-quality-gate.yml` reusable workflow that `pr-core.yml` invokes; see "Proposed Implementation" for the shape decision). `docs/consumer-usage.md` and `docs/CHANGELOG.md` updated alongside.

**No consumer `pr.yml` changes required.** Consumer repos invoke `pr-core.yml@main` today; the new gate is internal to `pr-core.yml` and reads its threshold inputs from `pr-core.yml`'s existing input surface (extended in this packet with safe defaults). Repos that want to override defaults pass the new inputs through their `pr.yml` `with:` block — opt-in, additive, non-breaking.

## Motivation

### Why now

- **Stage 7 of the ADR-0011 pipeline is built but the gate it produces is silently weaker than intended.** All 12 onboarded repos now run `job-sonarcloud.yml` on every PR (Wave 2 of `adr-0011-code-review-pipeline` complete per `initiatives/active-initiatives.md`). The org-level GitHub ruleset that requires `SonarCloud Code Analysis` as a status check exists in Evaluate mode. But the check the ruleset will eventually enforce comes from SonarCloud's default Sonar way gate, which doesn't fail on new issues. Flipping the ruleset to Active without this packet would lock in the silent-pass behavior.
- **Vault PR #44 is the live counterexample.** 6 new issues, gate "Passed", no signal on the PR. The pattern the user expects from the Grid's gate posture (catch defects at PR time, not later) is being undermined by a default gate that doesn't enforce what the ADR named.
- **The fix is internal to `pr-core.yml` and doesn't require any consumer-repo change.** That makes it a single-PR change that propagates the new posture to all 12 .NET consumers the moment it merges (they all consume `pr-core.yml@main`).

### Why a single packet (not per-repo)

The threshold logic and the SonarCloud Web API call live in `HoneyDrunk.Actions` (invariant 37 — Actions is the source of truth for shared CI/CD configuration). All 12 .NET consumer repos consume `pr-core.yml` at `@main`, so a single Actions PR turns the gate on across the entire fleet at once. Per-repo opt-out (e.g., Transport with its 61 maintainability findings) is reachable via threshold overrides in the consumer's `pr.yml` `with:` block, but no per-repo packet is needed to deliver the mechanism.

### Why `new_*` metrics, not absolute

Per `active-initiatives.md`, several onboarded repos carry legacy findings from their first SonarCloud scan: Transport (2 Reliability + 61 Maintainability), and unreviewed Security Hotspots on Communications and Observe. Gating on absolute counts (`bugs`, `code_smells`) would fail every PR on those repos until the backlog is triaged. Gating on `new_*` metrics (the leak-period definition SonarCloud already uses for its built-in gate's coverage/duplication conditions) is the **only** correct posture: the PR is responsible for what *it* introduces, not what already existed. This is also what the ADR-0011 D11 leak-period baseline points at — new-code definition inherits from the organization default (30 days), per the `sonar-project.properties` templates already shipped in Wave 2.

### Why a soft-launch warn-only period

Two reasons the gate should warn-only on first deployment, then flip to enforce per-repo (or grid-wide) as a trivial follow-up:

1. **Unknown thresholds matter.** None of the 12 repos has run a PR through this gate yet. The default (`new_violations = 0`) is the strict posture the ADR points at, but a noisy SonarCloud rule (rare but possible, e.g., a new `cs:S6961` finding that fires on idiomatic .NET 10 patterns) could fire on a PR that shouldn't reasonably fail. Soft-launch lets the operator observe what the gate actually flags before it becomes branch-protection-blocking.
2. **Symmetry with ADR-0044 packet 14.** PR-size discipline (already in `pr-core.yml`) is in Phase 2 warnings-only with an explicit Phase 3 toggle point in the comment at the end of the `pr-size-check` job. This packet adopts the same shape — a `sonar-quality-gate-mode: warn|enforce` input with the toggle point clearly marked so the eventual flip to `enforce` is a one-line change in either `pr-core.yml`'s default or per-consumer.

## Proposed Implementation

### Shape decision: extend `pr-core.yml` directly, or new `job-sonarcloud-quality-gate.yml`?

**Choose: new `job-sonarcloud-quality-gate.yml` reusable workflow, invoked from `pr-core.yml` after the existing pipeline finishes.**

Reasoning:

- `pr-core.yml` is already large (~1300 lines) and the existing tier-2-equivalent Python gates (coverage, NuGet consistency, PR size) all live inline. Adding another inline Python block for the SonarCloud API call would push the file past readable.
- The SonarCloud quality gate is the canonical tier-2 stage per ADR-0011 D2 — it deserves its own reusable workflow at the same shape as `job-sonarcloud.yml`. The two workflows are paired: `job-sonarcloud.yml` produces the data; `job-sonarcloud-quality-gate.yml` enforces the thresholds. A consumer that wants to use one without the other (e.g., a private repo that runs SonarCloud purely advisory) can.
- The job-level `if:` trigger guard in the new workflow can match `job-sonarcloud.yml`'s (`pull_request` only; not push:main where SonarCloud runs against the main branch baseline). The PR-only constraint means the API call needs `pullRequest=<N>` always — no second code path for push events. This is also a cost-discipline point: a single API call per PR.
- The new workflow is `workflow_call`-only and accepts the same `sonar-organization` / `sonar-project-key` / `sonar-token` inputs as `job-sonarcloud.yml`. It also accepts the threshold inputs described below.

The alternative (inline in `pr-core.yml`) is rejected on file-size grounds and on parity-with-`job-sonarcloud.yml` grounds. The wiring from `pr-core.yml` is just a `uses:` block, same as how `job-sonarcloud.yml` would be wired if it were called from `pr-core.yml` (today it's called from the consumer's `pr.yml`, but that's a separable question — see "Out of scope" below).

### `job-sonarcloud-quality-gate.yml` shape

```yaml
name: SonarQube Cloud Quality Gate (Job)

on:
  workflow_call:
    inputs:
      sonar-organization:
        description: 'SonarQube Cloud organization key (e.g. honeydrunkstudios)'
        required: true
        type: string

      sonar-project-key:
        description: 'SonarQube Cloud project key (e.g. honeydrunkstudios_HoneyDrunk.Kernel)'
        required: true
        type: string

      sonar-host-url:
        description: 'SonarQube Cloud host URL'
        required: false
        type: string
        default: 'https://sonarcloud.io'

      mode:
        description: 'Gate mode: warn (warnings-only) or enforce (fail PR)'
        required: false
        type: string
        default: 'warn'

      max-new-violations:
        description: 'Maximum new_violations allowed (informational metric — union of bugs+vulns+smells)'
        required: false
        type: number
        default: 0

      max-new-bugs:
        description: 'Maximum new_bugs allowed'
        required: false
        type: number
        default: 0

      max-new-vulnerabilities:
        description: 'Maximum new_vulnerabilities allowed'
        required: false
        type: number
        default: 0

      max-new-code-smells:
        description: 'Maximum new_code_smells allowed'
        required: false
        type: number
        default: 0

      max-new-security-hotspots:
        description: 'Maximum new_security_hotspots allowed'
        required: false
        type: number
        default: 0

      runs-on:
        description: 'GitHub runner to use'
        required: false
        type: string
        default: 'ubuntu-latest'

    secrets:
      sonar-token:
        description: 'SONAR_TOKEN — same org secret used by job-sonarcloud.yml'
        required: true

permissions:
  contents: read
  pull-requests: write
  checks: write

jobs:
  sonar-quality-gate:
    name: SonarQube Cloud Quality Gate
    runs-on: ${{ inputs.runs-on }}
    if: ${{ github.event_name == 'pull_request' }}
    steps:
      - name: Fetch SonarCloud measures and enforce thresholds
        env:
          SONAR_TOKEN: ${{ secrets.sonar-token }}
          SONAR_HOST_URL: ${{ inputs.sonar-host-url }}
          SONAR_ORGANIZATION: ${{ inputs.sonar-organization }}
          SONAR_PROJECT_KEY: ${{ inputs.sonar-project-key }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          MODE: ${{ inputs.mode }}
          MAX_NEW_VIOLATIONS: ${{ inputs.max-new-violations }}
          MAX_NEW_BUGS: ${{ inputs.max-new-bugs }}
          MAX_NEW_VULNERABILITIES: ${{ inputs.max-new-vulnerabilities }}
          MAX_NEW_CODE_SMELLS: ${{ inputs.max-new-code-smells }}
          MAX_NEW_SECURITY_HOTSPOTS: ${{ inputs.max-new-security-hotspots }}
        shell: bash
        run: |
          set -euo pipefail
          python3 <<'PY'
          # Python body sketch — full implementation is the executing agent's job.
          # Key shape: poll measures endpoint, parse metric values, compare against
          # thresholds, emit ::error:: annotations per breached metric, link to the
          # SonarCloud PR summary, exit 1 only when mode==enforce.
          import json, os, sys, time, urllib.parse, urllib.request

          host = os.environ['SONAR_HOST_URL'].rstrip('/')
          org = os.environ['SONAR_ORGANIZATION']
          key = os.environ['SONAR_PROJECT_KEY']
          pr  = os.environ['PR_NUMBER']
          mode = (os.environ.get('MODE') or 'warn').lower()
          token = os.environ['SONAR_TOKEN']

          metrics = [
              ('new_violations',         int(os.environ['MAX_NEW_VIOLATIONS'])),
              ('new_bugs',               int(os.environ['MAX_NEW_BUGS'])),
              ('new_vulnerabilities',    int(os.environ['MAX_NEW_VULNERABILITIES'])),
              ('new_code_smells',        int(os.environ['MAX_NEW_CODE_SMELLS'])),
              ('new_security_hotspots',  int(os.environ['MAX_NEW_SECURITY_HOTSPOTS'])),
          ]

          # SonarCloud's PR analysis is asynchronous — the analysis upload kicks off
          # processing on Sonar's side and returns immediately. The /api/measures
          # endpoint may return stale or empty data if polled before processing
          # finishes. Retry with backoff for a bounded window (≤ ~30s) before
          # giving up. If the analysis never completes, treat as informational
          # (not a hard fail) — see "Respects the existing skip semantics" below.

          query = urllib.parse.urlencode({
              'component': key,
              'pullRequest': pr,
              'metricKeys': ','.join(m for m, _ in metrics),
          })
          url = f'{host}/api/measures/component?{query}'
          req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})

          attempts = 0
          values = {}
          while attempts < 6:
              try:
                  with urllib.request.urlopen(req, timeout=10) as resp:
                      payload = json.loads(resp.read().decode('utf-8'))
                  measures = (payload.get('component') or {}).get('measures') or []
                  if measures:
                      for m in measures:
                          # `period.value` is what the new-code metric exposes for
                          # PR analyses; `value` is the absolute (don't read it).
                          period = m.get('period') or {}
                          values[m['metric']] = period.get('value')
                      break
              except Exception as exc:
                  print(f'::notice::SonarCloud API attempt {attempts+1} failed: {exc}')
              attempts += 1
              time.sleep(5)

          # PR summary URL for any failure annotation.
          summary = f'{host}/summary/new_code?id={urllib.parse.quote(key)}&pullRequest={pr}'

          if not values:
              # Soft-pass when the data isn't available — matches the existing
              # skip-when-pr-core-failed pattern in consumer pr.yml. Print a
              # notice so the human knows; don't exit nonzero.
              print('::warning::SonarCloud measures not available for this PR after retries; quality gate is informational only on this run.')
              print(f'::notice::SonarCloud PR summary: {summary}')
              sys.exit(0)

          failures = []
          for metric, threshold in metrics:
              raw = values.get(metric)
              if raw is None:
                  # Metric not returned (project may not measure hotspots if disabled).
                  continue
              try:
                  actual = int(float(raw))
              except (TypeError, ValueError):
                  continue
              if actual > threshold:
                  failures.append(f'{metric}={actual} (threshold {threshold})')

          if not failures:
              print('::notice::SonarCloud quality gate passed (all new-code metrics within thresholds).')
              print(f'::notice::SonarCloud PR summary: {summary}')
              sys.exit(0)

          msg = 'SonarCloud quality gate: ' + '; '.join(failures)
          # ALWAYS print the breach annotations so reviewers see them in the
          # Checks tab regardless of mode.
          for f in failures:
              print(f'::error::{msg.split(": ")[0]}: {f}')
          print(f'::error::See SonarCloud PR summary: {summary}')

          if mode == 'enforce':
              sys.exit(1)
          print('::warning::Gate mode is `warn` (soft-launch). Not failing the PR; flip to `enforce` to make this blocking. (ADR-0011 packet 08 toggle point — see job comment.)')
          sys.exit(0)
          PY

      # Phase-flip toggle point (mirrors pr-size-check ADR-0044 packet 14
      # convention): change the default `mode` input above from 'warn' to
      # 'enforce' when the Grid adopts the harder posture grid-wide. Per-repo
      # flips happen via the consumer's `pr.yml` setting
      # `sonar-quality-gate-mode: enforce` before that.
```

### `pr-core.yml` extension

Add inputs to `pr-core.yml` that flow through to the new job:

```yaml
inputs:
  # ... existing inputs ...

  enable-sonar-quality-gate:
    description: 'Enforce SonarCloud new-code thresholds via the SonarCloud Web API after sonar analysis (ADR-0011 D11)'
    required: false
    type: boolean
    default: false  # Off by default until the new gate is wired into consumer pr.yml's

  sonar-quality-gate-mode:
    description: 'Mode for the SonarCloud quality gate: warn (soft-launch, default) or enforce (blocking)'
    required: false
    type: string
    default: 'warn'

  sonar-organization:
    description: 'SonarQube Cloud organization key (required when enable-sonar-quality-gate is true)'
    required: false
    type: string
    default: ''

  sonar-project-key:
    description: 'SonarQube Cloud project key (required when enable-sonar-quality-gate is true)'
    required: false
    type: string
    default: ''

  sonar-max-new-violations:
    description: 'Maximum new_violations allowed by the SonarCloud quality gate'
    required: false
    type: number
    default: 0

  sonar-max-new-bugs:
    description: 'Maximum new_bugs allowed by the SonarCloud quality gate'
    required: false
    type: number
    default: 0

  sonar-max-new-vulnerabilities:
    description: 'Maximum new_vulnerabilities allowed by the SonarCloud quality gate'
    required: false
    type: number
    default: 0

  sonar-max-new-code-smells:
    description: 'Maximum new_code_smells allowed by the SonarCloud quality gate'
    required: false
    type: number
    default: 0

  sonar-max-new-security-hotspots:
    description: 'Maximum new_security_hotspots allowed by the SonarCloud quality gate'
    required: false
    type: number
    default: 0

secrets:
  # ... existing secrets ...
  sonar-token:
    description: 'SONAR_TOKEN — required when enable-sonar-quality-gate is true'
    required: false
```

And add the job invocation, gated by `enable-sonar-quality-gate`:

```yaml
jobs:
  # ... existing jobs ...

  sonar-quality-gate:
    name: SonarQube Cloud Quality Gate
    if: ${{ inputs.enable-sonar-quality-gate && github.event_name == 'pull_request' }}
    uses: HoneyDrunkStudios/HoneyDrunk.Actions/.github/workflows/job-sonarcloud-quality-gate.yml@main
    with:
      sonar-organization: ${{ inputs.sonar-organization }}
      sonar-project-key: ${{ inputs.sonar-project-key }}
      mode: ${{ inputs.sonar-quality-gate-mode }}
      max-new-violations: ${{ inputs.sonar-max-new-violations }}
      max-new-bugs: ${{ inputs.sonar-max-new-bugs }}
      max-new-vulnerabilities: ${{ inputs.sonar-max-new-vulnerabilities }}
      max-new-code-smells: ${{ inputs.sonar-max-new-code-smells }}
      max-new-security-hotspots: ${{ inputs.sonar-max-new-security-hotspots }}
      runs-on: ${{ inputs.runs-on }}
    secrets:
      sonar-token: ${{ secrets.sonar-token }}
```

**Sequencing question — does this `needs:` `job-sonarcloud.yml`?** No, because `job-sonarcloud.yml` is invoked from the **consumer's** `pr.yml` today, not from `pr-core.yml`. The new `sonar-quality-gate` job runs in parallel with the consumer's existing `sonarcloud` job in `pr.yml`. The new gate's API call retry-with-backoff handles the timing race: SonarCloud analysis upload takes seconds-to-tens-of-seconds; the gate polls the API for up to ~30s before treating the absence of data as informational. If a future refactor moves `job-sonarcloud.yml` *into* `pr-core.yml`, the `needs:` wiring can be added then.

**Update the `pr-summary` job:**

- Add `sonar-quality-gate` to its `needs:` list (with `if: always()` semantics so a skipped/warn job doesn't break the summary).
- Add a row for "SonarCloud Quality Gate" to the job-results block, showing `enforced` / `warn` / `skipped` and the count of breached metrics if any.
- When `mode=warn` and findings exist, surface them in the PR comment as a warning section so reviewers see them even when the gate is soft-launched.
- When the `sonar-quality-gate` job result is `failure` and `enable-sonar-quality-gate=true` and `sonar-quality-gate-mode=enforce`, treat it as a tier-1-equivalent failure in the overall status determination (icon=`:x:`, status=`Failed`). When `mode=warn`, treat the job result as success regardless of breaches.

### Default posture across all 12 onboarded repos

- `enable-sonar-quality-gate` defaults `false` in `pr-core.yml`. **No consumer behavior changes** at merge time of this PR.
- Per-repo opt-in is a one-line addition to each consumer's `pr.yml`:
  ```yaml
  with:
    enable-sonar-quality-gate: true
    sonar-quality-gate-mode: warn   # default; explicit for clarity
    sonar-organization: 'honeydrunkstudios'
    sonar-project-key: 'honeydrunkstudios_HoneyDrunk.Vault'   # per repo
  secrets:
    sonar-token: ${{ secrets.SONAR_TOKEN }}
  ```
- Per-repo opt-ins are NOT part of this packet. They are out-of-scope per-repo follow-up packets, one per consumer, when the operator is ready to flip the gate on for that repo. Once Vault (or any repo) opts in and the operator has observed a few PRs in `warn` mode without surprises, flipping `sonar-quality-gate-mode: enforce` is a single-line change in that repo's `pr.yml`. When the operator wants the entire fleet to enforce, flip the default in `pr-core.yml` from `warn` to `enforce` (one-line change; the comment at the end of the job marks the toggle point).

### Skip semantics

- **SonarCloud didn't run on this PR.** Possible causes: PR from a fork (secrets unavailable), `SONAR_TOKEN` rotation gap, SonarCloud outage, consumer `pr.yml` skipped Sonar because `pr-core` failed (per the existing `pr.yml` pattern). The gate polls the API for ~30s; if no measures come back, it emits a `::warning::` and exits 0 regardless of mode. **Match the existing skip-when-pr-core-failed pattern.**
- **SonarCloud is disabled for this repo.** The consumer doesn't pass `enable-sonar-quality-gate: true`. The new job is skipped; the PR summary doesn't reference it. No-op.
- **Mode is `warn`.** Breaches are surfaced as `::error::` annotations (still visible in the Checks tab and the PR summary), but the job exits 0 — branch protection does not block. The toggle to `enforce` is one input flip.

## Affected Files

- `HoneyDrunk.Actions/.github/workflows/job-sonarcloud-quality-gate.yml` — new reusable workflow.
- `HoneyDrunk.Actions/.github/workflows/pr-core.yml` — new inputs, new job invocation, summary integration.
- `HoneyDrunk.Actions/docs/consumer-usage.md` — new section documenting opt-in shape and threshold knobs.
- `HoneyDrunk.Actions/docs/CHANGELOG.md` — append to the existing `[Unreleased]` section.

No consumer repo changes. No `pr.yml` changes in any of the 12 onboarded repos.

## Acceptance Criteria

- [ ] `.github/workflows/job-sonarcloud-quality-gate.yml` exists, is `workflow_call`-only, declares the inputs listed above with the documented defaults, and carries a job-level `if: github.event_name == 'pull_request'` trigger guard.
- [ ] The new job calls `GET https://sonarcloud.io/api/measures/component?component=<key>&pullRequest=<N>&metricKeys=new_violations,new_bugs,new_vulnerabilities,new_code_smells,new_security_hotspots` with `Authorization: Bearer ${SONAR_TOKEN}`, parses the `period.value` field from each returned measure (NOT the absolute `value` field), and compares against the per-metric threshold input.
- [ ] Breaches produce `::error::` annotations naming each breached metric and link to the SonarCloud PR summary URL `https://sonarcloud.io/summary/new_code?id=<key>&pullRequest=<N>`.
- [ ] Mode `enforce`: exits 1 on any breach. Mode `warn`: emits the error annotations but exits 0.
- [ ] When the SonarCloud API returns no measures within ~30s (retry with backoff, max 6 attempts at 5s spacing), the job prints an informational warning and exits 0 regardless of mode. The PR is not blocked on API unavailability.
- [ ] `pr-core.yml` accepts the new inputs (`enable-sonar-quality-gate`, `sonar-quality-gate-mode`, `sonar-organization`, `sonar-project-key`, `sonar-max-new-*`) and the new secret (`sonar-token`). Defaults match the section above. The new job is gated by `if: inputs.enable-sonar-quality-gate && github.event_name == 'pull_request'`.
- [ ] Existing consumers (none of which set `enable-sonar-quality-gate: true` today) see no behavior change. Verify by reading any one of Vault/Kernel/Web.Rest `pr.yml` and confirming the `with:` block does not need to grow.
- [ ] `pr-summary` job adds the SonarCloud quality gate to its `needs:`, the job-results block, and the overall status calculation. Behavior: `mode=warn` breaches do not flip the overall PR Core status to Failed; `mode=enforce` breaches do.
- [ ] `docs/consumer-usage.md` has a new section "SonarCloud quality gate (ADR-0011 D11)" with:
  - Why the gate exists (free-tier limitation + ADR-0011 D11 intent).
  - The two-step opt-in (add the inputs to `pr.yml`; flip `mode` from `warn` to `enforce` when ready).
  - The threshold inputs and what each new-code metric measures.
  - The skip semantics (fork PRs, SonarCloud outages).
  - A note that `mode=warn` is the recommended starting posture for any newly-opted-in repo.
- [ ] `docs/CHANGELOG.md` `[Unreleased]` `Added` section includes a new entry for the SonarCloud quality gate enforcement workflow + `pr-core.yml` wiring + soft-launch posture. **Do not rename `[Unreleased]` to a version number** — that happens at release time, in a separate version-bumping PR (per `feedback_release-changelog-freeze.md`).
- [ ] Smoke test (operator, post-merge): pick one repo (suggest **HoneyDrunk.Vault** — the live counterexample), open a follow-up PR adding the four lines to `pr.yml` (`enable-sonar-quality-gate: true`, `sonar-organization`, `sonar-project-key`, `secrets.sonar-token`), and confirm:
  - On a green PR, the new job runs, reports `passed`, and the PR summary includes a "SonarCloud Quality Gate: passed" line.
  - On a deliberately-broken PR (introduce a new unused private field or similar `S1144`-grade code smell), the new job emits `::error::new_code_smells=1 (threshold 0)`, the PR comment surfaces the warning, but the PR is not blocked because `sonar-quality-gate-mode: warn` (default).
  - Then flip the Vault PR to `sonar-quality-gate-mode: enforce`, re-push, confirm the PR check goes red and merge is blocked.
  - Revert the Vault test PR.

## Boundary Check

- **Single repo (HoneyDrunk.Actions).** Per invariant 37 ("HoneyDrunk.Actions is the source of truth for shared CI/CD configuration"), gate logic and SonarCloud-integration glue belong here. The 12 consumer repos consume `pr-core.yml@main` and inherit the new gate the moment it merges (gated off by default; opt-in per consumer).
- **No ADR amendment.** ADR-0011 D8 already names the SonarCloud quality gate as a required check on public repos; D11 already names SonarCloud as the third-party static analysis tool. This packet executes the existing intent of the ADR via a different delivery mechanism — gate logic in pr-core, SonarCloud as data source — because the free-tier SonarCloud organization can't host the custom quality gate the ADR's wording assumes. The structural posture is unchanged: tier-1 gates live in pr-core via branch protection; tier 2 includes a SonarCloud-fed gate that blocks on new-code breaches. The path to "required check" changes from "the SonarCloud GitHub App's status check" to "the `SonarQube Cloud Quality Gate` job emitted by pr-core" — both are tier 2, both are blocking on enforce-mode, both surface in the PR Checks tab.
- **No consumer-repo packets needed for the gate itself.** Per-repo opt-in is a one-line change in each consumer's `pr.yml`, which is normal operator work — not a packet-grade change. If the operator wants packets for the opt-ins for traceability, those are filed as a separate fan-out initiative (similar to the Wave-3 fan-out that already exists conceptually for the remaining onboardings). This packet does not file them.
- **No constitutional invariant changes.** Invariant 37 (HoneyDrunk.Actions ownership) and invariants 31-33 (PR pipeline) are preserved.
- **No new external dependency.** SonarCloud is already a dependency; this packet adds a second API call to it (`/api/measures/component`) using the same `SONAR_TOKEN` already provisioned.

## Referenced Invariants

- **Invariant 31 (ADR-0011 D2/D5)** — Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken. — This packet preserves tier 1 unchanged. The new SonarCloud quality gate is tier 2; it does not modify tier-1 posture.
- **Invariant 37 (ADR-0012 D2/D3)** — HoneyDrunk.Actions is the source of truth for shared CI/CD configuration. Shared tool configurations live under `HoneyDrunk.Actions/.github/config/`. Caller repos do not duplicate these files; they consume them via reusable-workflow checkout at job runtime. A caller repo may commit a `.<tool>.<ext>` at its root as a per-repo override, which is expected to extend the shared baseline rather than replace it. — This packet adds gate logic to `HoneyDrunk.Actions`; consumers consume it via `pr-core.yml`.
- **Invariant 38 (ADR-0012 D4)** — Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. — This packet uses a direct HTTPS call to SonarCloud's Web API (`urllib.request` from the standard library); no marketplace action wraps the call. Aligned.
- **Invariant 39 (ADR-0012 D5)** — Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. — The new job declares `contents: read`, `pull-requests: write` (for the eventual PR-comment annotation surface), `checks: write`. `pr-core.yml` already requests this superset; no consumer `pr.yml` change is needed because consumers already pass the superset to `pr-core.yml@main`.

## Referenced ADR Decisions

- **ADR-0011 D2** — Ordered review pipeline, fail-fast cheap-first. Tier 2 includes "Static analysis — SonarCloud" as required-blocking on public repos. This packet operationalizes the blocking semantics via a pr-core-resident gate rather than the SonarCloud-native check, because the SonarCloud-native check on free-tier organizations is the default Sonar way gate, which does not condition on `new_violations > 0`.
- **ADR-0011 D8** — How failures surface. "SonarCloud quality gate — public repo — PR check (red) + inline annotations — Blocks merge: Yes (branch protection)." This packet preserves the blocking-on-enforce semantics; in `warn` mode the gate is informational (consistent with the ADR-0044 packet-14 PR-size precedent for a soft-launch warnings-only period during transition).
- **ADR-0011 D11** — SonarCloud is the third-party static analysis tool; public-repos-first. The "Output: required PR check (quality gate status), inline PR annotations for findings at or above the severity threshold defined in the SonarCloud project settings" line is fulfilled by this packet via the pr-core-resident gate (free-tier limitation prevents the project-settings approach).
- **ADR-0011 D11 (paragraph on SonarCloud OSS plan)** — "SonarQube Cloud OSS plan: free for unlimited public LOC; private LOC is paid per LOC and is intentionally out of scope." Gap 5 names the private-repo case. This packet does not change the public/private posture; it works on any project the operator has imported into SonarCloud, public or private, but the OSS organization remains public-only by default.

## Constraints

- Do **not** rename `[Unreleased]` to a version number in `docs/CHANGELOG.md` (per `feedback_release-changelog-freeze.md` — that rename happens at tag-push time, in a separate version-bumping PR, with the date appended).
- Do **not** modify any consumer repo's `pr.yml` in this packet. The new gate is opt-in via input; per-repo opt-ins are out-of-scope follow-ups.
- Do **not** flip `enable-sonar-quality-gate` default to `true` in this packet. Defaults stay `false` so the merge of this PR is a no-op for all 12 consumers. Per-repo opt-in proves the gate before any default flip.
- Do **not** flip the `sonar-quality-gate-mode` default to `enforce` in this packet. Defaults stay `warn` so the first repo to opt in does so on the soft-launch posture, by default. Flipping to `enforce` is a one-line change in the consumer's `pr.yml` once the operator has observed real PRs in `warn` mode without surprise.
- Do **not** add the new gate to the org-level GitHub ruleset's required-checks list in this packet. That happens in a separate operator-action when the gate has proven itself across at least two consumer repos. (The ruleset already lists `SonarCloud Code Analysis` — the SonarCloud-native check — which stays present and continues to enforce the default Sonar way gate alongside the new pr-core gate.)
- Do **not** use a marketplace action to call the SonarCloud Web API. Direct `urllib.request` (or `curl`) only, per invariant 38.
- Do **not** SHA-pin any newly-introduced `actions/*` reference. Use the existing `@v4`-style references in `pr-core.yml` as the precedent (per user-oleg-honeydrunk memory).
- Do **not** commit with LF line endings — `dotnet format --verify-no-changes` will fail in the next consumer's PR Core run. Run `dotnet format` locally before committing if any C# file is touched (this packet touches YAML and Markdown only, but the discipline still applies for whitespace-sensitive YAML — confirm CRLF on every new YAML file).
- Do **not** add the `paths:` filter to the new workflow. The pr-core orchestration already controls when this gate runs.

## Human Prerequisites

None for the packet itself — `SONAR_TOKEN` is already provisioned at the org level with `Selected repositories` scope per the existing ADR-0011 packet-04 walkthrough, and that's the only secret this gate needs.

Post-merge operator steps (out-of-scope for this packet, listed here so they're not forgotten):

- [ ] After merge, pick one repo (suggest **HoneyDrunk.Vault** — the live counterexample driving this packet) and add the four-line opt-in to its `pr.yml` (`enable-sonar-quality-gate: true`, `sonar-organization`, `sonar-project-key`, `secrets.sonar-token`) as a separate follow-up PR. Observe the new check in PR `warn` mode through 3-5 real PRs before flipping to `enforce`.
- [ ] When ready, flip Vault's `sonar-quality-gate-mode` from `warn` to `enforce` in a one-line follow-up PR.
- [ ] When the pattern is proven, fan out the opt-in to the other 11 onboarded repos (Kernel, Audit, Transport, Auth, Web.Rest, Data, Notify, Pulse, Communications, AI, Observe) — one PR per repo, or one bulk PR using `seed-labels-fanout`-style script if the operator prefers. Either approach is fine; the gate logic doesn't care.
- [ ] When grid-wide enforce is the steady state, flip the `pr-core.yml` defaults from `warn` to `enforce` and from `enable-sonar-quality-gate: false` to `true` in a single follow-up PR (the toggle-point comment in the workflow marks this).
- [ ] Optional, deferred: add the new check name (likely `SonarQube Cloud Quality Gate` or whatever the job name resolves to in the Checks tab — verify after first run) to the org-level GitHub ruleset's required-checks list. This is what makes branch protection enforce the gate alongside the existing `SonarCloud Code Analysis` check. Sequencing matters: the check must have run at least once before GitHub will let it be added to the ruleset.

## Dependencies

This packet depends on packet 02 (`02-actions-job-sonarcloud-workflow.md`) only for the existence of the `SONAR_TOKEN` secret + `job-sonarcloud.yml` data source. Packet 02 has merged (per `active-initiatives.md` Wave 1 complete). No hard dependency on packets 04 / 06 / 07; the new gate calls SonarCloud directly, doesn't require any consumer-repo onboarding to land first beyond the SonarCloud organization being live (which packet 04 delivered).

## Agent Handoff

**Objective:** Add a tier-2 SonarCloud quality-gate enforcement workflow to HoneyDrunk.Actions that fails the PR when new-code metrics exceed configurable thresholds, with a soft-launch warn-only default.

**Target:** `HoneyDrunkStudios/HoneyDrunk.Actions`, branch from `main`.

**Context:**
- Goal: Operationalize ADR-0011 D8/D11's "SonarCloud quality gate is a required check on public repos" intent on a free-tier SonarCloud organization, where the SonarCloud-native custom quality gate is paid-only and the default Sonar way gate does not enforce `new_violations > 0`.
- Feature: `pr-core.yml` extension + new `job-sonarcloud-quality-gate.yml` reusable workflow.
- ADRs: ADR-0011 (D2, D8, D11). ADR-0012 (D2-D5; CI ownership and reusable-workflow conventions). ADR-0044 (warnings-only-then-enforce precedent for soft-launch — packet 14 PR-size discipline).
- Packets in the same initiative folder: 01-architecture-adr-0011-acceptance, 02-actions-job-sonarcloud-workflow (this packet's hard dependency, already merged), 03-actions-agent-run-packet-link, 04-architecture-sonarcloud-org-walkthrough, 06-kernel-sonarcloud-onboarding, 07-web-rest-sonarcloud-onboarding. The Wave-2 onboardings established the `job-sonarcloud.yml` data flow this packet builds on.
- Cross-link: ADR-0011 D11's contract for the SonarCloud stage says "Output: required PR check (quality gate status), inline PR annotations" — that's what this gate produces, via the pr-core API-poll rather than the SonarCloud GitHub App's native check (which on free-tier is the unmodifiable Sonar way default).
- Live counterexample driving this work: HoneyDrunk.Vault PR #44 — 6 new issues, gate "Passed".

**Acceptance Criteria:** (see `## Acceptance Criteria` above — all items must be ticked.)

**Dependencies:**
- Packet 02 (already merged — `job-sonarcloud.yml` ships the upstream SonarCloud analysis; `SONAR_TOKEN` is provisioned).
- Packet 04 (already merged — SonarCloud organization exists, GitHub App installed on the 12 onboarded repos).

**Constraints (full text inlined per scope-agent self-containment rule):**

- **Invariant 31** — Every PR traverses the tier-1 gate before merge. Build, unit tests, analyzers, vulnerability scan, and secret scan are required branch-protection checks on every .NET repo in the Grid, delivered via `pr-core.yml` in `HoneyDrunk.Actions`. Bypassing tier 1 via force-push to `main` or admin override is forbidden except for `hotfix-infra` scenarios where the gate itself is broken. (Preserved — this packet does not modify tier 1.)
- **Invariant 37** — HoneyDrunk.Actions is the source of truth for shared CI/CD configuration. Shared tool configurations (gitleaks rules, CodeQL query packs, Trivy policy, dotnet-format rules, etc.) live under `HoneyDrunk.Actions/.github/config/`. Caller repos do not duplicate these files; they consume them via reusable-workflow checkout at job runtime. A caller repo may commit a `.<tool>.<ext>` at its root as a per-repo override, which is expected to extend the shared baseline rather than replace it. (Aligned — gate logic lands in HoneyDrunk.Actions; consumers inherit via `pr-core.yml@main`.)
- **Invariant 38** — Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. (Aligned — the SonarCloud API call uses `urllib.request` directly; no marketplace action wraps it.)
- **Invariant 39** — Caller workflows declare a `permissions:` block that is a superset of the reusable workflow's declared permissions. Callers that omit `permissions:` inherit the repository default, which is insufficient for any reusable workflow that requests a `write` scope. Validation failure is not detected until the next scheduled run; grid-health is the safety net. (Honored — the new job declares its `permissions:` block; `pr-core.yml`'s existing block is already a superset.)
- **ADR-0011 D11 cost discipline** — Median PR run target under 60 seconds; SonarCloud is `pull_request` + `push:main` only (job-level `if:` guard). The new quality-gate workflow scopes itself to `pull_request` only (no `push:main` needed — main-branch analysis runs against the leak-period baseline, not against per-PR thresholds). The API call is one round-trip with retry-with-backoff capped at ~30s. Adds well under 60s to median PR runtime.

**Boundaries not to cross:**

- Do not edit any consumer `pr.yml` in this PR.
- Do not flip `enable-sonar-quality-gate` default from `false` to `true`. Per-repo opt-in is operator work, post-merge.
- Do not flip `sonar-quality-gate-mode` default from `warn` to `enforce`. Soft-launch is the explicit policy.
- Do not add the new check name to the org-level branch-protection ruleset in this PR. That's operator work post-merge after the gate has run on at least one real PR.
- Do not introduce a new external dependency. Standard-library Python (`urllib.request`, `json`, `time`) only.
- Do not write to `docs/CHANGELOG.md` outside the existing `[Unreleased]` block (per `feedback_release-changelog-freeze.md`).

**Key Files:**

- `HoneyDrunk.Actions/.github/workflows/pr-core.yml` — extend inputs + add the new job.
- `HoneyDrunk.Actions/.github/workflows/job-sonarcloud.yml` — read only (existing tier-2 data source; this workflow is unchanged).
- `HoneyDrunk.Actions/.github/workflows/job-sonarcloud-quality-gate.yml` — new file.
- `HoneyDrunk.Actions/docs/consumer-usage.md` — add a section on the new opt-in surface.
- `HoneyDrunk.Actions/docs/CHANGELOG.md` — append to `[Unreleased]` `Added`.

**Contracts:**

- SonarCloud Web API endpoint: `GET https://sonarcloud.io/api/measures/component?component=<key>&pullRequest=<N>&metricKeys=<csv>` with `Authorization: Bearer <SONAR_TOKEN>`. Response shape: `{ "component": { "key": "...", "measures": [ { "metric": "new_violations", "period": { "index": 1, "value": "0" } }, ... ] } }`. The `period.value` is a stringified integer for new-code metrics; the absolute `value` is for non-leak-period metrics. Read `period.value` only.
- SonarCloud PR analysis is asynchronous. Retry with backoff up to ~30s before treating empty `measures` as "data not yet available."
- The PR summary URL format is `https://sonarcloud.io/summary/new_code?id=<urlencoded-key>&pullRequest=<N>`.
- The job's `if:` guard must be `github.event_name == 'pull_request'` — analyses on `push:main` don't have a PR number to query and don't have a leak-period delta to threshold.
- The reusable workflow's `secrets:` block declares `sonar-token` as required. `pr-core.yml` declares it as optional (because the gate is opt-in via `enable-sonar-quality-gate`).

**Test approach:**

- The job is exercisable end-to-end the moment one consumer repo opts in. Suggest the operator open a follow-up PR in HoneyDrunk.Vault (the live counterexample) immediately after merging this packet, with the four-line opt-in and `mode: warn`. Verify:
  - Green PR → "passed" annotation in the Checks tab, no blocking.
  - Deliberately-broken PR (add an `S1144` violation — a private field that's never used) → `::error::new_code_smells=1 (threshold 0)`, PR summary surfaces the warning, PR not blocked (warn mode).
  - Same broken PR with `mode: enforce` → `::error::` annotation, PR check goes red, branch protection blocks.
- The SonarCloud API timing (async upload) is the riskiest part. If first runs see "data not yet available" warnings, increase the retry window or add an explicit "wait for analysis complete" pre-step (poll `/api/ce/component?component=<key>` until status==SUCCESS) — but only if the simpler retry-on-measures approach proves unreliable in practice. Don't over-engineer up front.

**Filing context:** initiative packet — closes ADR-0011 D11's "the quality gate is a required check" intent on the free-tier SonarCloud organization. Lives in `adr-0011-code-review-pipeline/` as packet 08, alongside the existing 01-07. No ADR amendment, no new ADR, no contract change.
