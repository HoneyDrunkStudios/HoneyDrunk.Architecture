---
name: CI Change
type: ci-change
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Actions
labels: ["chore", "tier-2", "ci-cd", "ops", "adr-0012", "wave-1"]
dependencies: []
adrs: ["ADR-0012"]
wave: 1
initiative: adr-0012-grid-cicd-control-plane
node: honeydrunk-actions
---

# CI Change: Decide D4 stance on `docker://` image refs and migrate `actions-ci.yml` actionlint step accordingly

## Summary
The actionlint step in `actions-ci.yml` line 22 uses `uses: docker://rhysd/actionlint:1.7.12` — a Docker-image reference, **not** a marketplace action. ADR-0012 D4 prohibits "third-party marketplace wrappers" but is **silent on `docker://` image refs**. This is a real policy ambiguity that the actionlint case forces an explicit decision on. This packet (a) records the decision in `docs/d4-retrofit-audit.md` (or in a short follow-up amendment to the ADR if the decision is meaningful enough to belong there), and (b) migrates `actions-ci.yml` accordingly. The two viable outcomes are:

- **Outcome A — `docker://` is acceptable.** The Docker-image ref names a specific image at a specific tag; there is no "wrapper layer" between the workflow and the tool — the GitHub runner pulls the image and `args:` is passed directly to the entrypoint. This is mechanically equivalent to a `docker run` invocation. **Decision lands as a one-paragraph clarification in the audit doc; no code change needed; line 22 stays.**
- **Outcome B — `docker://` is forbidden, prefer install-and-invoke.** Even though there is no wrapper layer, `docker://` adds a Docker-pull dependency that a direct `go install` (or `curl | tar`) would not. **Decision lands as a clarification in the audit doc; line 22 is migrated to install actionlint directly via `bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash) 1.7.12` and invoke it.**

The default recommendation is **Outcome B** (consistent with the spirit of D4 — the runner builds the tool environment from a known-pinned recipe rather than pulling a pre-baked image). But the decision is the operator's, and this packet records it.

## Target Repo
`HoneyDrunkStudios/HoneyDrunk.Actions`

## Motivation
ADR-0012 D4's prose names "third-party marketplace wrapper" as the forbidden shape. The audit packet (07) catalogs three D4 violations; two are unambiguous marketplace wrappers (Trivy, SBOM, handled in 07a/07b). The third is `docker://rhysd/actionlint:1.7.12`, which is mechanically different from a marketplace wrapper:

- **Marketplace wrapper** — a third-party `action.yml` defines `inputs:`, runs unknown shell, eventually invokes the underlying tool. The wrapper layer can drift independently of the tool. Forbidden under D4.
- **`docker://` image ref** — GitHub runner pulls the image at the pinned tag; `args:` is passed directly to the image's entrypoint. There is no third-party action layer between the workflow and the tool. Closer to "direct invocation but containerized."
- **`run: docker run image cmd`** — the canonical D4-compliant pattern (used in `nightly-security.yml` for Trivy).

D4 does not adjudicate between the second and third forms. The audit packet (07) flags this as an ambiguity that must be resolved before its conclusion can read "clean."

This packet forces the decision. Once landed, the audit doc has unambiguous guidance for any future case (e.g. if a new tool is added via `docker://`).

## Proposed Implementation

### Phase 1 — Record the decision

Add a new section to `docs/d4-retrofit-audit.md` (created in packet 07) titled:

```markdown
## Policy clarification — `docker://` image refs vs `run: docker run`

ADR-0012 D4 forbids third-party marketplace wrappers but is silent on Docker-image refs (`uses: docker://owner/image:tag`). The actionlint step in `actions-ci.yml` line 22 surfaces the ambiguity. The decision adopted here:

**[CHOSEN OUTCOME — fill in A or B at execution time after the operator decides.]**

**Outcome A (`docker://` is acceptable):** A Docker-image ref at a pinned tag is treated as direct invocation for D4 purposes. Rationale: there is no third-party wrapper layer between the workflow and the tool's entrypoint. Going forward, `uses: docker://owner/image:tag` is a permitted form for tools that ship a published Docker image but whose binary install is awkward. New uses must pin to an immutable tag (digest preferred over semver tag).

**Outcome B (`docker://` is forbidden, prefer install-and-invoke):** Even though there is no wrapper layer, `docker://` introduces a Docker-pull dependency at every run. The canonical D4 form remains either (a) `run: docker run image cmd` (matching the Trivy pattern in `nightly-security.yml`) or (b) install the binary directly via `curl | tar | mv` (matching the gitleaks pattern in `nightly-security.yml`). New uses of `docker://` are forbidden; existing uses are migrated.

This clarification is appended to ADR-0012 only if the decision is meaningful enough to belong in the source ADR. The default home is this audit doc.
```

The operator chooses A or B at execution time. The agent fills in the chosen outcome in the doc, removing the unchosen variant text.

### Phase 2 — Migrate (only if Outcome B)

If Outcome B is chosen, edit `.github/workflows/actions-ci.yml` lines ~21-24:

**Before:**
```yaml
- name: Run actionlint
  uses: docker://rhysd/actionlint:1.7.12
  with:
    args: -color -shellcheck=
```

**After (Outcome B):**
```yaml
- name: Install actionlint
  shell: bash
  env:
    ACTIONLINT_VERSION: 1.7.12
  run: |
    set -euo pipefail
    INSTALL_DIR="$RUNNER_TEMP/actionlint"
    mkdir -p "$INSTALL_DIR"
    bash <(curl -sSfL https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash) "$ACTIONLINT_VERSION" "$INSTALL_DIR"
    echo "$INSTALL_DIR" >> "$GITHUB_PATH"

- name: Run actionlint
  shell: bash
  run: |
    set -euo pipefail
    actionlint -color -shellcheck=
```

The `download-actionlint.bash` installer is maintained by the actionlint upstream and pins to the requested version. This matches D4's "install the CLI in a `run:` step at a pinned version" pattern.

If Outcome A is chosen, no workflow edit is needed. The doc clarification is the entire deliverable.

### Phase 3 — Update `docs/action-pins.md` if it exists

If Outcome B is chosen and `docs/action-pins.md` exists, update the `rhysd/actionlint` row: change pin form from `docker://rhysd/actionlint:1.7.12` to `actionlint binary v1.7.12 (installed via download-actionlint.bash)` and Status to `Current`.

If Outcome A is chosen and `docs/action-pins.md` exists, the row stays but a Notes entry is added: "Permitted under D4 per the docker:// clarification in d4-retrofit-audit.md."

### Phase 4 — Optional ADR amendment

If the decision feels architecturally meaningful enough to live in ADR-0012 itself rather than only in the audit doc, propose a one-paragraph amendment to ADR-0012 D4. The amendment would clarify the `docker://` policy alongside the existing first-party-action exception list. **Default: do not amend the ADR.** The audit doc is the canonical home; amending an Accepted ADR for a clarification is heavier than the situation warrants.

If the operator opts to amend the ADR, the amendment is a separate small PR in `HoneyDrunk.Architecture` (touch `adrs/ADR-0012-grid-cicd-control-plane.md` D4 prose only; do not change invariant numbers or any other ADR section). That separate PR is filed as a follow-up, not bundled here.

### `docs/CHANGELOG.md` (or repo-root)

Append entry referencing ADR-0012 D4 and this decision. Note which outcome was chosen.

## Affected Files

If Outcome A:
- `docs/d4-retrofit-audit.md` — clarification section appended
- `docs/CHANGELOG.md` (or repo-root) — entry

If Outcome B:
- `docs/d4-retrofit-audit.md` — clarification section appended
- `.github/workflows/actions-ci.yml` — actionlint step migrated to direct install + invocation
- `docs/action-pins.md` — row updated (if file exists)
- `docs/CHANGELOG.md` (or repo-root) — entry

## NuGet Dependencies
None.

## Boundary Check
- [x] Single-repo edit. Scope is the actionlint step in `actions-ci.yml` plus the audit doc.
- [x] No semantic change to actionlint's behavior — same flags (`-color -shellcheck=`), same workflow position.
- [x] If Outcome B, the migration matches the canonical D4 pattern (install + invoke).

## Acceptance Criteria
- [ ] `docs/d4-retrofit-audit.md` contains a "Policy clarification — `docker://` image refs vs `run: docker run`" section with **exactly one** of the two outcomes filled in (the unchosen variant text is removed, not left commented out).
- [ ] If Outcome B was chosen: `actions-ci.yml` line ~22 no longer references `docker://rhysd/actionlint`. The replacement step pair installs actionlint via `download-actionlint.bash` and runs `actionlint -color -shellcheck=`.
- [ ] If Outcome A was chosen: `actions-ci.yml` is unchanged from current state; the audit doc clarification is the sole deliverable.
- [ ] Smoke test: the `actions-ci.yml` workflow runs successfully on a no-op PR after the migration (Outcome B) or the clarification (Outcome A).
- [ ] If `docs/action-pins.md` exists, its `rhysd/actionlint` row reflects the post-decision state.
- [ ] `docs/CHANGELOG.md` (or repo-root `CHANGELOG.md`) updated, naming which outcome was chosen.

## Human Prerequisites
- [ ] **Choose Outcome A or B.** This is a policy decision the operator must make. The default recommendation is Outcome B (forbid `docker://`, prefer install-and-invoke) for consistency with the spirit of D4 — but Outcome A is a legitimate alternative for tools that distribute primarily as Docker images. The agent does not choose; the operator does.
- [ ] **Smoke test trigger** if Outcome B: after merge, trigger `actions-ci.yml` on a no-op PR or via `workflow_dispatch` if available, and confirm actionlint runs and exits cleanly. The flag `-shellcheck=` (with empty value) disables shellcheck integration; preserve that exactly.
- [ ] **Optional: ADR amendment.** If the chosen outcome feels architecturally meaningful, the operator may choose to amend ADR-0012 D4 directly with a one-paragraph clarification. That amendment is filed as a separate small PR in `HoneyDrunk.Architecture`, not bundled here.

## Referenced Invariants

> **Invariant 38 (post-acceptance numbering — see packet 01):** Reusable workflows invoke tool CLIs directly. Wrapping a tool in a third-party marketplace action is forbidden for any tool that provides a stable CLI. Exceptions: first-party GitHub actions under `actions/*`, `github/codeql-action/*`, and composite actions authored inside `HoneyDrunk.Actions`. See ADR-0012 D4.

The invariant text says "third-party marketplace action" — `docker://rhysd/actionlint:1.7.12` is debatable as a "marketplace action." The clarification this packet records resolves the debate.

## Referenced ADR Decisions

**ADR-0012 D4 (Direct CLI invocation):** Tool CLIs are installed via `run:` shell steps at a pinned version, or invoked via `docker run image cmd` (the Trivy pattern in `nightly-security.yml`). The text is silent on `docker://` image refs; this packet's clarification resolves the silence either by extending the permitted-forms list (Outcome A) or by holding the line at install-and-invoke (Outcome B).

**ADR-0012 D8 (Gitleaks shared config + direct CLI):** Reference pattern for direct binary install. The Outcome B migration matches this pattern.

## Dependencies
- Soft-blocked by packet 01 for invariant 38 numbering.
- Soft-relates to packet 07 (audit doc — this packet adds a section to the same doc and closes the third of three known violations).

## Labels
`chore`, `tier-2`, `ci-cd`, `ops`, `adr-0012`, `wave-1`

## Agent Handoff

**Objective:** Force an explicit policy decision on `docker://` image refs under D4, record it in the audit doc, and migrate `actions-ci.yml` if the chosen outcome requires it.
**Target:** HoneyDrunk.Actions, branch from `main`

**Context:**
- Goal: Close the third of three D4 violations enumerated in packet 07's audit, but only after resolving a real policy ambiguity that ADR-0012 left implicit.
- Feature: ADR-0012 Grid CI/CD Control Plane, D4 retrofit + clarification.
- ADRs: ADR-0012.

**Acceptance Criteria:** As listed above.

**Dependencies:**
- Soft-blocked by packet 01.
- Soft-relates to packet 07 (audit doc shared with this packet).

**Constraints:**
- **Operator decision required.** The agent does not choose A vs B unilaterally — surface both options in the PR description, default-recommend Outcome B, and wait for operator confirmation before committing the chosen variant. (If the agent has a clear instruction in the issue body or a follow-up comment, proceed.)
- **No half-states.** The audit doc must record exactly one outcome, with the unchosen variant text removed. Do not leave both variants in the doc as `<!-- alternative -->` comments.
- **Invariant 38 (post-acceptance):** The chosen outcome must be defensible against the invariant's intent — tool environment built from a known-pinned recipe, no third-party drift surface between workflow and tool.
- **Preserve actionlint flags exactly.** `-color -shellcheck=` (with empty value to disable shellcheck integration) must round-trip through the migration unchanged.

**Key Files:**
- `.github/workflows/actions-ci.yml` — primary edit target (line ~22), only if Outcome B.
- `docs/d4-retrofit-audit.md` — clarification section appended either way.
- `docs/action-pins.md` — row update target (if exists).
- `adrs/ADR-0012-grid-cicd-control-plane.md` — touched only if the operator opts for the optional ADR amendment, and that touch lands in a separate PR in `HoneyDrunk.Architecture`, not here.

**Contracts:** Behavioral contract is the actionlint workflow's behavior on a no-op PR. Preserved exactly under either outcome.
