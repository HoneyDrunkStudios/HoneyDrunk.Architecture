# Dispatch Plan: Code Review Pipeline (ADR-0011)

**Date:** 2026-04-26 (revised after refine review).
**Trigger:** ADR-0011 (Code Review and Merge Flow) — Proposed 2026-04-12, scoped 2026-04-26.
**Type:** Multi-repo
**Sector:** Meta + Ops + Core (CI wiring)
**Site sync required:** No, deferred. Today the Studios website does not surface the constitution, ADR catalogue, or PR-pipeline metadata. Site sync is **deferred** until SonarCloud quality gates and the `out-of-band` label become public-facing artifacts on the Studios site (likely tied to a future "Grid health" or "engineering practices" page). Re-evaluate when Studios CI is wired up and a public surface is decided.
**Rollback plan:** Architecture-side edits revert cleanly via `git revert` — qualifier strip, ADR index flip, catalog `agent_couplings` add, and tracker entries are docs/text-only. The new `job-sonarcloud.yml` is additive and not yet referenced by `pr-core.yml`, so reverting it has no consumer impact. The `agent-run.yml` amendment adds a default-empty optional input plus a soft-failing post-hoc step — reverting is safe and existing callers stay green throughout. The `out-of-band` label seeding is idempotent — running an explicit `gh label delete` per repo cleans it up. Per-repo SonarCloud onboardings (06, 07) revert by removing `sonar-project.properties` from the inner project subdir, removing the `sonarcloud` job from `pr.yml`, and removing the SonarCloud check from branch protection (manual UI step).

## Summary

ADR-0011 names an 11-stage tiered PR review pipeline with explicit owners and artifact contracts. Most of the pipeline already exists (`pr-core.yml` ships tier 1; Copilot review fills the automatic-LLM-reviewer slot; the local `review` agent is defined in `.claude/agents/review.md`). What was missing as of the 2026-04-12 draft date:

1. The ADR was Proposed, not Accepted.
2. Invariants 31–33 were live in `constitution/invariants.md` but carried a "(Proposed — takes effect when ADR-0011 is accepted)" qualifier.
3. The third-party static analysis stage (D11 = SonarCloud) had no reusable workflow file.
4. The cloud agent-execution workflow (`agent-run.yml`) did not inject packet links into agent-authored PR bodies, leaving invariant 32 enforcement to per-prompt discipline.
5. The `out-of-band` label that invariant 32 references existed on no Grid repo.
6. The SonarCloud organization itself had not been provisioned, and per-repo onboarding had not started.
7. `catalogs/relationships.json` did not encode the invariant-33 agent-to-agent coupling (no machine-discoverable signal of the scope/review context-loading symmetry).

This initiative ships **eight packets** across two waves (revised from seven after the refine review split packet 05 into 05a + 05b for clean cross-repo apply semantics). Wave 1 is foundation work that runs in parallel after the first acceptance packet lands. Wave 2 onboards the first two repos as canonical templates. Wave 3 (the deferred fan-out across the remaining 8 .NET repos) is named here but **not scoped in this initiative** — those packets are filed when the Wave 2 templates prove out.

## Important constraints (from ADR-0011 itself)

- **D10 forbids cloud-wiring the review agent.** This dispatch plan does not include a `pr-review-agent.yml`. The review agent stays local-only, invoked by the human via Claude Code.
- **The review agent is advisory (D5).** The dispatch plan does not include any "make the review agent a required check" packet. The branch-protection required-check posture stays on tier 1 + SonarCloud (per D8).
- **Invariants 29–30 are reserved for ADR-0010** (Observation Layer, accepted 2026-04-12). New invariants in this ADR begin at 31. The acceptance packet must not touch invariants 29–30.
- **Studios is excluded from the .NET fan-out.** SonarCloud onboarding for the TypeScript/Next.js Studios site is a separate future packet, not part of this initiative. Studios is also excluded from the `out-of-band` fan-out (no .NET PR pipeline to label against).

## Wave Diagram

### Wave 1 — Foundation (parallel after packet 01, with one internal hard-block)

Run packet 01 first. Once it merges, packets 02, 03, 04, 05a run in parallel. Packet 05b is hard-blocked on 05a and starts after 05a merges.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0011** — flip ADR Status, ADR index, strip "(Proposed)" qualifier from invariants 31–33, audit `scope.md` and `review.md`, add `agent_couplings` to `relationships.json`, register initiative in trackers — [`01-architecture-adr-0011-acceptance.md`](01-architecture-adr-0011-acceptance.md)

After packet 01 lands:

- [ ] `HoneyDrunk.Actions`: Author `job-sonarcloud.yml` reusable workflow — [`02-actions-job-sonarcloud-workflow.md`](02-actions-job-sonarcloud-workflow.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0011-acceptance.md` (soft, for invariant references).
- [ ] `HoneyDrunk.Actions`: Inject packet link into PR body via `agent-run.yml` `packet-path` input + post-hoc assert step — [`03-actions-agent-run-packet-link.md`](03-actions-agent-run-packet-link.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0011-acceptance.md` (soft, invariant 32 rationale).
- [ ] `HoneyDrunk.Architecture`: SonarCloud organization setup walkthrough doc + portal work — [`04-architecture-sonarcloud-org-walkthrough.md`](04-architecture-sonarcloud-org-walkthrough.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0011-acceptance.md` (soft, D11 reference).
- [ ] `HoneyDrunk.Actions`: Labels-as-code config + reusable `seed-labels.yml` workflow — [`05a-actions-labels-as-code.md`](05a-actions-labels-as-code.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0011-acceptance.md` (soft, invariant 32 rationale).
- [ ] `HoneyDrunk.Actions`: Cross-repo fan-out — apply `out-of-band` to the eleven Grid repos via `seed-labels-fanout.yml` + PAT — [`05b-actions-out-of-band-label-fanout.md`](05b-actions-out-of-band-label-fanout.md)
  - Blocked by: Wave 1 — `05a-actions-labels-as-code.md` (**hard** — fan-out reads the labels.yml shipped by 05a).
  - Blocked by: Wave 1 — `01-architecture-adr-0011-acceptance.md` (soft).

**Wave 1 exit criteria** (before Wave 2 starts):

- ADR-0011 reads `**Status:** Accepted`; invariants 31–33 carry no "(Proposed)" qualifier; index row reflects Accepted.
- `catalogs/relationships.json` contains the `agent_couplings` array with the `scope-review-context-loading` entry.
- `job-sonarcloud.yml` exists in `HoneyDrunk.Actions/.github/workflows/` and is callable via `workflow_call`. Its job-level `if:` trigger guard is in place (defence-in-depth for the `pull_request` + `push:main` rule).
- `agent-run.yml` accepts `packet-path` and (a) injects `> Packet: <permalink>` markdown into the agent's prompt envelope when supplied AND (b) runs a post-hoc "Assert PR-body packet link" step that mechanically asserts the line into any PR the agent opened. Existing callers unaffected.
- `infrastructure/sonarcloud-organization-setup.md` exists; the `honeydrunkstudios` SonarCloud org exists; the SonarCloud GitHub App is installed on the eleven enumerated public repos (Studios excluded); `SONAR_TOKEN` is provisioned at the org level with "Selected repositories" scope.
- `out-of-band` label exists on every active Grid repo (Studios excluded) with the configured color/description — verified by browsing each repo's `/labels` page after packet 05b's `seed-labels-fanout.yml` run.
- `LABELS_FANOUT_PAT` exists as a HoneyDrunk.Actions repo secret, scoped to the eleven Grid repos with `Issues: Write` only.
- `.claude/agents/scope.md` and `.claude/agents/review.md` audit pass — both already reference ADR-0011 D4/D6/D7 and the coupled context-loading contract per invariant 33.

### Wave 2 — Canonical onboarding templates (parallel, with internal merge → first-run → branch-protection ordering each)

Both packets run in parallel after Wave 1's exit criteria are met. Each packet has a real **internal three-step sequence** that this dispatch plan tracks explicitly because GitHub branch protection rejects rules that reference checks which have never run:

1. **Merge the packet PR.** `pr.yml` now includes the `sonarcloud` job. The `sonar-project.properties` file is in place at `HoneyDrunk.<Repo>/sonar-project.properties` (inner project subdir, not git root — the scanner discovers it from the `working-directory` `pr.yml` runs in).
2. **First SonarCloud-enabled PR runs.** This can be a follow-up PR or any new PR after the merge. On this first run, the SonarCloud GitHub App publishes its check. The exact check name is read from the live Checks tab — historically "SonarCloud Code Analysis", but verify each time and copy the literal string.
3. **Add the SonarCloud check to branch protection on `main`.** Only after step 2 — adding the rule before the first run produces a "this check has never run on this branch" rejection from GitHub. The human pastes the check name observed in step 2.

Together they establish the two dominant onboarding shapes:

- [ ] `HoneyDrunk.Kernel`: Onboard SonarCloud (first canonical template — pure library + Abstractions + tests, **no canary project**) — [`06-kernel-sonarcloud-onboarding.md`](06-kernel-sonarcloud-onboarding.md)
  - Blocked by: Wave 1 — `02-actions-job-sonarcloud-workflow.md` (hard).
  - Blocked by: Wave 1 — `04-architecture-sonarcloud-org-walkthrough.md` (hard).
- [ ] `HoneyDrunk.Web.Rest`: Onboard SonarCloud (ASP.NET Core variant template — Abstractions + AspNetCore + tests + canary) — [`07-web-rest-sonarcloud-onboarding.md`](07-web-rest-sonarcloud-onboarding.md)
  - Blocked by: Wave 1 — `02-actions-job-sonarcloud-workflow.md` (hard).
  - Blocked by: Wave 1 — `04-architecture-sonarcloud-org-walkthrough.md` (hard).

Note: Kernel has no `.Canary` project on disk (verified 2026-04-26); packet 06 reflects this. Web.Rest does have a `.Canary` project; packet 07 reflects this. The two `sonar.tests` lines diverge intentionally — do not reconcile them.

**Wave 2 exit criteria** (before Wave 3 fan-out is scoped):

- Kernel and Web.Rest both have `sonar-project.properties` at the inner project subdir (`HoneyDrunk.Kernel/sonar-project.properties`, `HoneyDrunk.Web.Rest/sonar-project.properties`) — **not** at the git repo root — a `sonarcloud` job in `pr.yml` chained `needs: pr-core`, projects imported into SonarCloud, and the SonarCloud check (literal name observed from the first run) as a required branch-protection check on `main`.
- The first SonarCloud quality gate run on each repo has completed (passing or with documented legacy findings).
- Both repos' configurations have been reviewed and either (a) judged correct as written, or (b) corrected based on real layout / extension-method file paths.

### Wave 3 — Deferred fan-out (NOT scoped in this initiative)

Tracked here so the work does not get lost. Not filed until Wave 2 templates prove out.

Eight remaining .NET repos onboard SonarCloud, each as a small packet (~5-line `sonar-project.properties` at the inner project subdir + `pr.yml` `sonarcloud` job + portal import + branch protection):

- HoneyDrunk.Transport (use packet 06 as template — pure library shape)
- HoneyDrunk.Vault (packet 06 template — Abstractions + Providers)
- HoneyDrunk.Auth (packet 07 template — has Auth.AspNetCore sub-package)
- HoneyDrunk.Data (packet 06 template — multi-package family)
- HoneyDrunk.Pulse (packet 06 template)
- HoneyDrunk.Notify (packet 06 template)
- HoneyDrunk.Vault.Rotation (packet 06 template — Function App, but still a .NET project)
- HoneyDrunk.Actions (packet 06 template if any .NET test projects exist; if Actions is purely YAML, defer entirely as a separate packet that reasons about whether SonarCloud applies)

**Wave 3 trigger:** Wave 2 merged, Kernel and Web.Rest quality gates green for at least one PR cycle, no template-level corrections needed.

**Excluded from Wave 3 entirely:**

- HoneyDrunk.Studios — TypeScript/Next.js. SonarCloud-JS onboarding is a separate one-off packet (or a follow-up initiative) when Studios CI is otherwise wired up. Not part of this rollout.

## Out-of-scope items from ADR-0011

These ADR-0011 sections are explicitly **not** addressed by this initiative. They live as Unresolved Consequences in the ADR and are tracked there:

- **Gap 1 — Integration tests (stage 6).** Slot defined; no test runner exists. No packet here.
- **Gap 3 — E2E / Playwright tests (stage 10).** Slot defined; no infra exists. No packet here.
- **Gap 4 — Cost discipline tooling.** Review agent's qualitative checklist (D6) covers it. No tool packet here.
- **Gap 5 — SonarCloud on private repos.** Per-repo opt-in, no Wave-3 fan-out. No packet here.

If any of these gaps becomes urgent, it is scoped via a new initiative (or appended to a future revision of this one) — but it does not block Wave 1 or Wave 2 acceptance.

## `gh` CLI Commands — File All Wave 1 + Wave 2 Issues

Paths are relative to the `HoneyDrunk.Architecture` repo root. All eight packets are filed in one pass; wave is execution sequencing, not a filing gate. Blocking relationships are wired afterward via `addBlockedBy`.

```bash
PACKETS="generated/issue-packets/active/adr-0011-code-review-pipeline"

# --- Wave 1: Foundation ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Accept ADR-0011 — flip status, finalize invariants 31-33, register pipeline initiative" \
  --body-file $PACKETS/01-architecture-adr-0011-acceptance.md \
  --label "feature,tier-2,meta,docs,adr-0011,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Author job-sonarcloud.yml reusable workflow (tier-2 SonarCloud analysis)" \
  --body-file $PACKETS/02-actions-job-sonarcloud-workflow.md \
  --label "feature,tier-2,ci-cd,ops,adr-0011,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Inject packet link into agent-authored PR bodies in agent-run.yml" \
  --body-file $PACKETS/03-actions-agent-run-packet-link.md \
  --label "feature,tier-2,ci-cd,ops,adr-0011,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Portal walkthrough — SonarCloud organization setup, GitHub App, SONAR_TOKEN" \
  --body-file $PACKETS/04-architecture-sonarcloud-org-walkthrough.md \
  --label "feature,tier-2,meta,docs,infrastructure,adr-0011,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Labels-as-code config and reusable seed-labels workflow" \
  --body-file $PACKETS/05a-actions-labels-as-code.md \
  --label "chore,tier-1,ci-cd,ops,adr-0011,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Fan out out-of-band label across the eleven Grid repos" \
  --body-file $PACKETS/05b-actions-out-of-band-label-fanout.md \
  --label "chore,tier-1,ci-cd,ops,adr-0011,wave-1"

# --- Wave 2: Canonical onboarding templates ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Kernel \
  --title "Onboard SonarCloud — first canonical .NET template" \
  --body-file $PACKETS/06-kernel-sonarcloud-onboarding.md \
  --label "feature,tier-2,ci-cd,core,adr-0011,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Web.Rest \
  --title "Onboard SonarCloud — ASP.NET Core variant template" \
  --body-file $PACKETS/07-web-rest-sonarcloud-onboarding.md \
  --label "feature,tier-2,ci-cd,core,adr-0011,wave-2"
```

## After filing — board fields and blocking relationships

For each issue: `gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>` then set Status=Backlog (or Ready), Wave (1 or 2), Initiative=`adr-0011-code-review-pipeline`, Node (`honeydrunk-architecture` / `honeydrunk-actions` / `honeydrunk-kernel` / `honeydrunk-web-rest`), Tier (per packet frontmatter), Actor=Agent (default — none of these packets is `Actor=Human`; packet 04 has substantial Human Prerequisites but the doc-authoring critical path is delegable; packet 05b requires a one-time human PAT setup and a one-time `workflow_dispatch` click but the workflow itself is delegable).

Wire the following `addBlockedBy` relationships:

- `02-actions-job-sonarcloud-workflow` blocked-by `01-architecture-adr-0011-acceptance` (soft)
- `03-actions-agent-run-packet-link` blocked-by `01-architecture-adr-0011-acceptance` (soft)
- `04-architecture-sonarcloud-org-walkthrough` blocked-by `01-architecture-adr-0011-acceptance` (soft)
- `05a-actions-labels-as-code` blocked-by `01-architecture-adr-0011-acceptance` (soft)
- `05b-actions-out-of-band-label-fanout` blocked-by `05a-actions-labels-as-code` (**hard**)
- `05b-actions-out-of-band-label-fanout` blocked-by `01-architecture-adr-0011-acceptance` (soft)
- `06-kernel-sonarcloud-onboarding` blocked-by `02-actions-job-sonarcloud-workflow` (hard)
- `06-kernel-sonarcloud-onboarding` blocked-by `04-architecture-sonarcloud-org-walkthrough` (hard)
- `07-web-rest-sonarcloud-onboarding` blocked-by `02-actions-job-sonarcloud-workflow` (hard)
- `07-web-rest-sonarcloud-onboarding` blocked-by `04-architecture-sonarcloud-org-walkthrough` (hard)

Total blocking edges: 10 (5 soft for Wave 1 sequencing; 5 hard for Wave 1 internal 05b dependency + Wave 2 dependencies).

## Notes

- **Acceptance precedes flip.** Per the scope-agent convention, ADR-0011 stays Proposed today. Packet 01's PR is the moment it flips to Accepted; the flip and the qualifier strip and the index row update and the catalog `agent_couplings` add all land in one merge — no early flip.
- **The agent files (`scope.md`, `review.md`) were updated in advance.** Both already reference ADR-0011 D4 / D6 / D7 and the invariant 33 coupling. The acceptance packet's audit task confirms this and documents the audit outcome in the PR body. No edits to the agent files are expected. The Cost Discipline section in `review.md` was confirmed (2026-04-26) to contain all six D6 items: hot-path logging without sampling, LLM cost cap, unguarded CI, Azure SKU justification, outbound HTTP in hot paths, unbounded catalog loops.
- **Invariants 31–33 are already live text in `constitution/invariants.md`** with the "(Proposed)" qualifier. The acceptance packet strips the qualifier; it does not introduce the invariants.
- **`sonar-project.properties` lives at the inner project subdir, not the git root.** Both Wave 2 packets explicitly call this out; the scanner discovers it from the `working-directory` `pr.yml` runs in (`HoneyDrunk.Kernel/` and `HoneyDrunk.Web.Rest/`). Putting it at the git root means the scanner cannot find it and analysis runs without project configuration.
- **Wave 2 packets each have a strict internal three-step ordering** — merge → first-run → branch-protection. GitHub rejects branch-protection rules that reference checks which have never run, so the human cannot pre-stage the branch-protection rule.
- **Invariant 32 enforcement is mechanical.** Packet 03 ships both the prompt-side instruction (best-effort) and the post-hoc workflow assert step (mechanical guarantor). Even if the LLM ignores the prompt, the workflow asserts the line into the PR body via `gh pr edit`.
- **The dispatch plan is the one exception to packet immutability** (per ADR-0008 D7). Updates at wave boundaries are the historical record. Packet bodies are immutable post-filing per invariant 24.
- **Studios is the one excluded repo** across every packet that touches per-repo work (04 step 4, 05a/05b seed list, the Wave-3 fan-out). Its TypeScript posture and lack of CI today are the reasons; a future Studios SonarCloud-JS onboarding is a separate initiative. Site sync is also deferred (see "Site sync required" above).
- **No new repo, no new ADR, no new contract.** This initiative only ships docs + workflow + per-repo CI wiring. The Grid topology (Nodes, sectors, contracts) is unchanged. The catalog gains a new agent-coupling entry but the schema extension is additive.
- **No Azure resources are provisioned.** SonarCloud is third-party SaaS; the only "infra" is a SonarCloud organization, a GitHub org-level secret (`SONAR_TOKEN`), and a HoneyDrunk.Actions repo secret (`LABELS_FANOUT_PAT`). Cost: $0 recurring on the public-repo path.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and the exit criteria above are met, the entire `active/adr-0011-code-review-pipeline/` folder moves to `archive/adr-0011-code-review-pipeline/` in a single commit. Partial archival is forbidden.

The Wave-3 deferred fan-out, when scoped, lives in a **new** initiative folder (likely `adr-0011-sonarcloud-fanout` or similar) — not appended to this one. Initiative folders are scoped to a wave-set, not to "everything an ADR ever does."

## Known Gaps (pre-existing — not owned by this initiative)

- **`infrastructure/github-projects-field-ids.md` does not exist.** The "After filing" guidance above and packet 05a's per-repo workflow setup both reference it as the source of truth for board custom-field option IDs. This is a pre-existing dangling reference also relied on by the ADR-0005/0006 rollout, ADR-0010 Phase 1, and `scope.md`. **Consequence for this initiative:** the human filing the issues hand-populates Wave / Initiative / Node / Tier / Actor field values via the GitHub UI or by copy-pasting IDs from another already-filed packet's project-item state. Recommendation: ship `infrastructure/github-projects-field-ids.md` as a **separate standalone packet**, not as part of this initiative. Do not let it block Wave 1 filing.
- **No `file-packets` driver currently consumes `agent-run.yml`'s new `packet-path` input.** Packet 03 ships the input + the post-hoc assert step; an existing or future driver workflow (out of scope for this initiative) will populate it. Until then, the input is optional and unused — which is the correct pre-rollout state per packet 03's design.

## Revision history

- **2026-04-26 initial scope** — seven packets across two waves.
- **2026-04-26 refine revision** — eight packets across the same two waves. Splits packet 05 into 05a (labels-as-code config + reusable seed-labels workflow) and 05b (cross-repo fan-out via PAT + dispatcher workflow). Corrects packet 06 `sonar.tests` (Kernel has no `.Canary` project). Corrects file location for `sonar-project.properties` in packets 06 and 07 (inner project subdir, not git root). Adds branch-protection sequencing notes (merge → first-run → paste check name). Adds trigger-guard `if:` to `job-sonarcloud.yml` (packet 02). Removes unused `actions-ref` input from `job-sonarcloud.yml` (packet 02) and from packets 06/07 callers. Upgrades packet 03 from prompt-only to prompt + post-hoc workflow assert. Adds `agent_couplings` catalog entry to packet 01 (invariant 33 machine-discoverability). Site sync flag changed from "No" to "No, deferred — re-evaluate when SonarCloud / out-of-band become public-facing artifacts."
