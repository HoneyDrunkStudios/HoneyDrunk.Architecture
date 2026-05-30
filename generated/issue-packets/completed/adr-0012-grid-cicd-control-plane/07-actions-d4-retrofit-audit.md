---
name: CI Change
type: ci-change
tier: 1
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-1", "ci-cd", "ops", "audit", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-actions
---

# CI Change: Audit reusable workflows for D4 direct-CLI compliance + cross-repo nightly-security re-runs

## Summary
Audit every `uses:` reference across `HoneyDrunk.Actions/.github/workflows/*.yml` and composite actions against ADR-0012 D4 (reusable workflows invoke tool CLIs directly, not third-party marketplace wrappers). Document the audit outcome in `docs/d4-retrofit-audit.md`. **Scope-time inspection has already identified three concrete D4 violations** (see Known Violations below); migrating them is **out of scope here** and tracked in three separate small-blast-radius packets (07a Trivy, 07b SBOM, 07c actionlint). This packet (a) lands the audit doc with those three violations enumerated, (b) confirms no additional violations exist beyond the three, and (c) manually triggers nightly-security across every Live + workflow-bearing Grid repo via `workflow_dispatch` to verify the gitleaks false-positive class from the triggering incident is gone end-to-end.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0012 D4 is the policy: tool CLIs invoked directly, marketplace wrappers banned for any tool with a stable CLI. The gitleaks retrofit was the immediate trigger. The ADR's Follow-up Work names "Retrofit existing reusable workflows to install their tool CLIs directly per D4" as a discrete packet: "The gitleaks step is already done in this ADR's landing. Remaining: any other reusable workflow that wraps a third-party CLI via a marketplace action. Audit in a follow-up packet, migrate per-workflow."

**Scope-time inspection has already found three live violations**, all in `HoneyDrunk.Actions/.github/workflows/`:

1. `release.yml` line 317: `uses: anchore/sbom-action@v0` — wraps `syft` (which has a stable CLI). Forbidden under D4. Migration packet: **07b**.
2. `release.yml` line 606: `uses: aquasecurity/trivy-action@0.35.0` — wraps the Trivy CLI (which has a stable CLI and which `nightly-security.yml` already invokes via `docker run aquasec/trivy`, the canonical pattern). Forbidden under D4. Migration packet: **07a**.
3. `actions-ci.yml` line 22: `uses: docker://rhysd/actionlint:1.7.12` — a Docker-image reference, not a marketplace action. **ADR-0012 D4 is silent on Docker-image refs.** This case forces an explicit policy clarification (does D4's "third-party marketplace wrapper" prohibition extend to `docker://` image refs?) before any migration. Decision packet: **07c**.

The companion deliverable — re-running nightly-security across every workflow-bearing Grid repo via `workflow_dispatch` — confirms the gitleaks false-positive class from the triggering incident (six findings on documentation placeholder API keys + 32-char hex AKV identifiers) is now suppressed grid-wide via the shared `.github/config/gitleaks.toml` allowlist. This part of packet 07 is independent of the D4 retrofit and is preserved as-is.

**Why audit + migrate are split.** Each migration is its own small-blast-radius PR. Bundling all three into one PR makes the diff harder to review and rolls a Trivy regression and an SBOM regression and an actionlint Docker-ref policy decision into one revert. Three small PRs land independently, reviewed independently, and any single rollback is contained.

## Proposed Implementation

### `docs/d4-retrofit-audit.md` (new)

Structure:

1. **Purpose.** One paragraph explaining what D4 mandates and what the audit confirmed.

2. **Audit method.** Short paragraph describing the audit procedure:
   - Enumerate every `uses:` line across `.github/workflows/*.yml` and `.github/actions/**/action.yml` via `grep -h 'uses:' .github/workflows/*.yml .github/actions/**/action.yml | sort -u`.
   - Classify each entry as one of:
     - **First-party exception** — `actions/*`, `github/codeql-action/*`. Permitted per D4.
     - **Local composite** — `./.github/actions/...` or `./.github/actions-repo/...`. Permitted (under our control).
     - **Permitted third-party** — `azure/login`, etc. — first-party of the cloud provider, no stable CLI equivalent that would be cleaner. Permitted, listed.
     - **Forbidden third-party wrapper** — anything else. Each forbidden entry triggers a follow-up packet.
   - For tool invocations that should be direct CLI (gitleaks, Trivy, dotnet-format, etc.), confirm the workflow installs the CLI in a `run:` step and invokes it directly, not via a wrapper.

3. **Audit table.** Every `uses:` entry from the scan, with classification.

4. **Direct-CLI tool invocations confirmed.** A short list of every tool CLI invoked directly:
   - `gitleaks` — installed via direct curl + checksum verification at pinned version 8.21.2 (or current pin) in `nightly-security.yml`.
   - `trivy` — invoked via Docker run with pinned image `aquasec/trivy:0.69.3` (or current pin) in `nightly-security.yml`.
   - Any others (dotnet-format, dotnet outdated, etc.) — listed similarly.

5. **Audit conclusion.** Expected at execution time given scope-time findings:
   > "Three D4 violations confirmed. Migration tracked in three separate packets (07a Trivy, 07b SBOM, 07c actionlint Docker-ref decision). No other violations found beyond the enumerated three."
   
   If the systematic audit surfaces a **fourth or more** violation beyond the three already enumerated, file an additional migration packet per violation and update the conclusion count. The audit's job is to confirm the floor — three known — and detect anything additional.

6. **Cross-references.** Invariant 38, ADR-0012 D4, and the gitleaks fix landing PR (if traceable from git log). Cross-link 07a, 07b, 07c migration packets by issue number once filed.

7. **Re-run verification.** A subsection documenting the manual re-run procedure (see below) and its outcome (Pass / Fail per repo, with links to the run pages). This subsection is independent of the D4 retrofit; it verifies the gitleaks false-positive class is suppressed grid-wide.

### Manual re-run of nightly-security across every Live + workflow-bearing Grid repo

After the audit doc is committed, the executing agent (or operator if the cloud agent lacks cross-repo `workflow_dispatch` permissions) triggers `nightly-security.yml` via `workflow_dispatch` on every Grid repo whose `.github/workflows/` contains `nightly-security.yml`. At scope-time (2026-04-26), that set is:

- HoneyDrunk.Kernel
- HoneyDrunk.Transport
- HoneyDrunk.Vault
- HoneyDrunk.Auth
- HoneyDrunk.Web.Rest
- HoneyDrunk.Data
- HoneyDrunk.Pulse
- HoneyDrunk.Notify

Repos to skip and why:
- HoneyDrunk.Vault.Rotation — no `nightly-security.yml` at scope-time (only `deploy.yml`, `publish.yml`, `validate-pr.yml`).
- HoneyDrunk.Communications — repo not yet scaffolded.
- HoneyDrunk.Studios — `.github/workflows/` is empty.
- HoneyDrunk.Architecture — no `nightly-security.yml`.
- HoneyDrunk.Actions — has `nightly-security.yml` but as the host of the reusable workflow itself; skip the self-test for this verification (the gitleaks change has been validated via Actions' own runs at ADR landing time).

The verified set is **8 repos** at scope-time. Re-verify before triggering — if Vault.Rotation has scaffolded `nightly-security.yml` between scope-time and execution, include it.

For each:
- Run via `gh workflow run nightly-security.yml --repo HoneyDrunkStudios/<name>` (the agent has `gh` available).
- Wait for completion via `gh run watch` or polling.
- Confirm the `gitleaks-secrets-scan` job exits 0 (no findings) AND the gitleaks step's console output reports `0 leaks found, 0 commits scanned` (or whatever current output format produces a definitive zero).
- Document the result in the audit doc's "Re-run verification" subsection: per-repo outcome plus a run URL.

If any repo's run still produces gitleaks findings on the previously-flagged false-positive shapes (placeholder API keys in `.md` files, 32-char hex AKV identifiers in docs), the audit conclusion flips to "incomplete" and a follow-up packet is filed to either (a) refine the shared allowlist regex, (b) fix per-repo overrides, or (c) re-investigate as a real finding. Do not close this packet until every workflow-bearing repo's re-run is clean OR every remaining finding is documented and triaged.

### `docs/CHANGELOG.md` (or repo-root)

Append entry referencing ADR-0012 D4 and this audit.

## Affected Files
- `docs/d4-retrofit-audit.md` (new)
- `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) — entry

## NuGet Dependencies
None. Audit + docs only.

## Boundary Check
- [x] Single-repo, doc-only edit (audit findings).
- [x] No reusable-workflow YAML edits in this packet — migrations, if needed, are separate follow-up packets.
- [x] Re-runs are operational verification on already-shipped workflows in other repos; no code change to those repos.

## Acceptance Criteria
- [ ] `docs/d4-retrofit-audit.md` exists with the seven sections listed in the Proposed Implementation.
- [ ] Every `uses:` entry across `.github/workflows/*.yml` and `.github/actions/**/action.yml` appears in the audit table with an explicit classification.
- [ ] The audit table includes the three known violations and classifies each as `Forbidden third-party wrapper` (Trivy, SBOM) or `Forbidden Docker-image ref pending policy decision` (actionlint), with cross-links to the 07a / 07b / 07c migration packets.
- [ ] Direct-CLI tool invocations are enumerated (gitleaks, Trivy via `docker run aquasec/trivy` in `nightly-security.yml`, plus any others discovered).
- [ ] If a **fourth or further** forbidden third-party wrapper is found beyond the three already enumerated, an additional migration packet is filed (cite the issue number in the audit doc) before this packet's PR merges. The audit conclusion section reflects the total count.
- [ ] Re-run verification subsection documents per-repo outcomes for every workflow-bearing repo's `workflow_dispatch` trigger (8 repos at scope-time; verify and update list at execution time), with run URLs and gitleaks finding counts.
- [ ] Every re-run reports zero gitleaks findings on the previously-flagged false-positive shapes. Any non-zero finding is triaged in the doc (real-leak vs. allowlist-needs-refinement).
- [ ] `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) updated with an entry.

## Human Prerequisites
- [ ] **`workflow_dispatch` permission.** The cloud agent may not have permission to trigger workflows in repos other than the one it is executing in. If `gh workflow run` returns 403/404 for a Grid repo, the operator triggers the dispatches manually via the repo's Actions tab → nightly-security → "Run workflow" button. The audit doc still records the outcome regardless of who triggered the dispatch.
- [ ] **Repos without `nightly-security.yml`** — at scope-time, Vault.Rotation and Communications do not have `nightly-security.yml` in their workflow set, and Studios's `.github/workflows/` is empty. Skip those repos' re-runs and note in the doc as "deferred — workflow not present at execution time." The audit conclusion is gated on repos that actually carry `nightly-security.yml`.

## Referenced Invariants

> **Invariant 38 (post-acceptance numbering — see packet 01):** Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

The audit's job is to confirm the surface complies with this invariant.

## Referenced ADR Decisions

**ADR-0012 D4 (Direct CLI invocation):** "Reusable workflows in `HoneyDrunk.Actions` invoke tool CLIs directly via `run:` shell steps, installing the CLI at a pinned version in the same step. The install is cheap (a single `curl`/`tar`/`mv`, or `dotnet tool install`, or equivalent), the flags passed to the CLI are the flags documented by the tool itself, and any breaking change in the tool's flags becomes visible at the next version bump — reviewable in a PR diff, not silently absorbed."

**ADR-0012 D4 (Permitted exceptions):** "First-party GitHub actions — `actions/checkout`, `actions/setup-dotnet`, `actions/setup-node`, `actions/upload-artifact`, `actions/download-artifact`, `actions/cache`. ... `github/codeql-action/*`. ... Composite actions inside `HoneyDrunk.Actions`."

**ADR-0012 D8 (Gitleaks shared config + direct CLI):** The reference implementation. The gitleaks retrofit landed with the ADR; the rest of the audit confirms the pattern is consistent.

**ADR-0012 Follow-up Work — "Extend the Vault gitleaks fix to every repo":** "By landing the shared config (already done in this ADR) and re-running nightly-security across all 11 repos to confirm the false-positive class is gone. No per-repo action needed; the shared config automatically applies." The re-run verification in this packet implements this follow-up.

## Dependencies
- Soft-blocked by packet 01 for invariant 38 numbering.
- **Soft-relates to packets 07a, 07b, 07c** (the three migration packets). The audit doc links those three packets in its conclusion. Packets 07a/b/c may merge before, after, or in parallel with this packet — they are independent deliverables. The audit doc text is accurate at audit time even if the migrations have not landed yet (it lists the violations as "Migration tracked in 07a / 07b / 07c").

## Labels
`chore`, `tier-1`, `ci-cd`, `ops`, `audit`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Confirm D4 compliance across all reusable workflows and verify the gitleaks false-positive class is suppressed grid-wide.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Land the audit doc that closes ADR-0012's "Retrofit existing reusable workflows" follow-up + the cross-repo re-run that closes the "Extend Vault gitleaks fix" follow-up.
- Feature: ADR-0012 Grid CI/CD Control Plane, D4 + D8 verification.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01 for invariant numbering.

**Constraints:**
- **Invariant 38 (post-acceptance):** The audit's correctness criterion is "every third-party non-first-party `uses:` is classified, every direct-CLI invocation is documented, no marketplace wrapper escapes the table." A clean audit conclusion has zero forbidden wrappers; a non-clean conclusion files follow-up packets and reflects the count in the doc.
- **No workflow YAML edits.** This packet writes the audit doc; it does not migrate workflows. If the audit finds a violation, file a follow-up packet for the migration, do not bundle. Bundle would mean a migration PR landing without an explicit decision moment.
- **Re-run verification is gated on the audit conclusion.** If the audit is clean, run the dispatches against every workflow-bearing repo (8 at scope-time; verify the set at execution time). If the audit is not clean, complete the file follow-up step first, then run the dispatches against the current (still-non-compliant) state — the dispatches verify gitleaks behavior, which is independent of whatever migrations are still pending.

**Key Files:**
- `.github/workflows/nightly-security.yml` — primary read target (gitleaks + Trivy + CodeQL).
- `.github/workflows/nightly-deps.yml` — read target (dotnet/npm work).
- `.github/workflows/pr-core.yml` — read target (composed job-* references).
- `.github/workflows/release.yml`, `publish.yml`, deploy variants — read targets.
- `.github/actions/**/action.yml` — composite-action read targets.
- `.github/config/gitleaks.toml` — read target for allowlist sanity check.
- `docs/CHANGELOG.md` — append entry.

**Contracts:** No code or schema contracts. The audit doc shape is its own contract — future re-audits read it for the prior-state baseline.
