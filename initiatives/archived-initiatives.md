# Archived Initiatives

Completed and cancelled initiatives. Active and planned work lives in [active-initiatives.md](active-initiatives.md).

---

## Completed

### ADR-0080 Vendor Lock-In Posture and Exit-Readiness Hedges
**Status:** Complete
**Completed:** 2026-05-30
**Scope:** Architecture
**Initiative:** `adr-0080-vendor-lockin`
**Board:** [The Hive — org Project #4](https://github.com/orgs/HoneyDrunkStudios/projects/4)
**Description:** Commit the Grid's vendor posture as a chosen position per ADR-0080 — assign each load-bearing vendor one of three postures (Accept / Hedge / Abstract), restate the cheap Grid-wide hedges as policy, define the decision-point triggers that fire a re-evaluation conversation, and create the `governance/vendor-postures/` canonical home with Azure and GitHub Accept-posture stubs. Governance-only; no code changes (all D3 hedges already hold at the code level via the source ADRs and invariants 1/2/3/44).

**Tracking (all shipped via PR #515):**
- [x] Architecture#347: Accept ADR-0080 — flip status, add the three vendor-posture invariants (99–101), register the initiative (packet 00)
- [x] Architecture#348: Create `governance/vendor-postures/` and ship the Azure exit-playbook stub (packet 01)
- [x] Architecture#349: Ship the GitHub exit-playbook stub (packet 02)
- [x] Architecture#350: Cross-link ADR-0076 / ADR-0077 / ADR-0078 to `governance/vendor-postures/azure.md` (packet 03)

**Exit criteria:** ADR-0080 is Accepted; invariants 99–101 are live under `## Vendor Posture Invariants`; `governance/vendor-postures/azure.md` and `governance/vendor-postures/github.md` stubs exist; ADR-0076/0077/0078 cite the resolved canonical home instead of the charter-aware draft. **All met by PR #515.**


### ADR-0082 Canonical Node Standup Procedure
**Status:** Complete
**Scope:** Architecture only (one canonical procedure document + five per-class walkthroughs + one org-secret repo-binding walkthrough)
**Completed:** 2026-05-29
**Initiative:** `adr-0082-node-standup`
**Description:** Accept ADR-0082 and commit the canonical Grid Node standup procedure — the single source of truth every standup packet, ADR, and AI agent references instead of re-deriving the checklist from the most recent precedent. Wave 1 lands acceptance + invariant 102 (the node-registration-mandatory rule from D6). Wave 2 lands `constitution/node-standup.md` — the load-bearing deliverable defining the three-phase chain (D3), the eighteen mandatory steps (D4), the class-specific steps a–z (D5), and the per-class org-secret binding matrix (D8). Wave 3 lands the six per-class walkthroughs in `infrastructure/walkthroughs/`. No code change in any other repo; no catalog or relationships edges added by this initiative — the procedure governs how future catalog entries land, not its own.

**Tracking (Wave 1 — governance / acceptance):**
- [x] Architecture#459: Accept ADR-0082, write invariant 102 (D6 node-registration-mandatory rule under the new `## Standup Procedure Invariants` section), flip the `adrs/README.md` row, mark the reservation accepted, register this initiative (packet 00; shipped via PR #505, closed 2026-05-29)

**Tracking (Wave 2 — canonical procedure document):**
- [x] Architecture#460: Author `constitution/node-standup.md` per D1 — three-phase chain, eighteen mandatory steps, class-specific steps a–z, per-class org-secret binding matrix (packet 01; shipped via PR #508, closed 2026-05-29)

**Tracking (Wave 3 — per-class walkthroughs + org-secret repo-binding walkthrough, parallel):**
- [x] Architecture#461: Author `infrastructure/walkthroughs/node-standup-core-dotnet.md` (packet 02; shipped via PR #510, closed 2026-05-29)
- [x] Architecture#462: Author `infrastructure/walkthroughs/node-standup-ops-deployable-dotnet.md` (packet 03; shipped via PR #510, closed 2026-05-29)
- [x] Architecture#463: Author `infrastructure/walkthroughs/node-standup-meta-docs.md` (packet 04; shipped via PR #510, closed 2026-05-29)
- [x] Architecture#464: Author `infrastructure/walkthroughs/node-standup-ai-seed.md` (packet 05; shipped via PR #510, closed 2026-05-29)
- [x] Architecture#465: Author `infrastructure/walkthroughs/node-standup-studios-typescript.md` (packet 06; shipped via PR #510, closed 2026-05-29)
- [x] Architecture#466: Author `infrastructure/walkthroughs/org-secret-repo-binding.md` (packet 07; shipped via PR #510, closed 2026-05-29)

> **Sync (2026-05-29):** 8/8 issues closed (100%). All eight deliverables verified present on `main`: `constitution/node-standup.md` (PR #508), invariant 102 + `## Standup Procedure Invariants` section (PR #505), and all six `infrastructure/walkthroughs/*.md` (PR #510). The earlier issue-tracker lag (#459, #460, #462–#466 merged but not auto-closed by their PRs) was resolved on 2026-05-29 by closing the issues manually; all eight packets moved to `completed/adr-0082-node-standup/`. Initiative archived.

**Cross-cutting amendments queued (not in this initiative):** ADR-0083's Architecture#473 amends `constitution/node-standup.md` for the sensitive-inventory onboarding hook and Vault.Rotation cross-link once both ADRs are Accepted; ADR-0084's Architecture#480 amends it to add the operator-alert routing step. Both queue behind packet 01 of this initiative landing the file (which it now has).

**Exit criteria:** ADR-0082 is Accepted with invariant 102 live in `constitution/invariants.md`; `constitution/node-standup.md` exists as the single canonical procedure source; all five per-class walkthroughs plus the org-secret repo-binding walkthrough exist in `infrastructure/walkthroughs/`; every future Node standup packet references this initiative's deliverables instead of re-deriving from precedent. **All met.**

---

### Code Review Pipeline (ADR-0011)
**Status:** Complete
**Scope:** Architecture, Actions, plus per-repo SonarQube Cloud onboarding across 12 .NET repos
**Completed:** 2026-05-28
**Initiative:** `adr-0011-code-review-pipeline`
**Description:** ADR-0011 Accepted 2026-05-25 along with the full SonarQube Cloud rollout to the 12 .NET-active Grid repos. SonarQube Cloud organization provisioned on the OSS plan; `SONAR_TOKEN` GitHub org secret with selected-repository scope; reusable `job-sonarcloud.yml` in `HoneyDrunk.Actions` running both PR-time analysis (after `pr-core` succeeds) and main-branch analysis (with `dotnet test` fallback when no `pr-core` artifact exists). The org-level GitHub ruleset requiring `SonarCloud Code Analysis` on the 12 onboarded repos is enforced (Active). Initial-scan findings (Reliability, Maintainability, Security Hotspots on Communications/Observe) have been triaged. ADR-0011 is amended by ADR-0044 (cloud-wires the review agent; reverses D10 local-only stance) and gap-closed by ADR-0047 (integration + E2E test tiers).

**Tracking (Wave 1 — foundation):**
- [x] Architecture: Accept ADR-0011 — flip status, ADR index, invariants 31–33 qualifier strip, `agent_couplings` catalog entry, SonarQube Cloud org walkthrough (packets 01 + 04 bundled)
- [x] Actions: `job-sonarcloud.yml` reusable workflow (packet 02; merged Actions PR #130)
- [x] Actions: `agent-run.yml` packet-link injection — workflow asserts canonical `> Packet: <permalink>` line into PR bodies via `gh pr edit` (packet 03; merged Actions PR #130)
- [x] Actions: `sonar.cs.opencover.reportsPaths` flag re-added after sonar-project.properties path proved unviable on .NET (merged Actions PR #132)
- [x] Actions: `push:main` coverage-generation fallback so main-branch analysis has data even when `pr-core` doesn't run (merged Actions PR #133)
- [x] Packets 05a/05b superseded by ADR-0044 Actions#86 — `out-of-band` label seeded Grid-wide via the labels-as-code fan-out shipped under that initiative

**Tracking (Wave 2 — per-repo onboarding):**
- [x] HoneyDrunk.Kernel (#59 + #60 push:main follow-up) — Pattern A canonical template
- [x] HoneyDrunk.Audit (#12) — Pattern B canonical template + `pr-core.yml` → `pr.yml` rename
- [x] HoneyDrunk.Transport (#34) — Pattern A
- [x] HoneyDrunk.Vault (#40) — Pattern A
- [x] HoneyDrunk.Auth (#31) — Pattern A
- [x] HoneyDrunk.Web.Rest (#26) — Pattern A (ASP.NET Core variant)
- [x] HoneyDrunk.Data (#31) — Pattern A
- [x] HoneyDrunk.Notify (#42) — Pattern A
- [x] HoneyDrunk.Pulse (#33) — Pattern A
- [x] HoneyDrunk.Communications (#26) — Pattern B + rename
- [x] HoneyDrunk.AI (#16) — Pattern B (no rename, already used `pr.yml`)
- [x] HoneyDrunk.Observe (#5) — Pattern B + rename (Seed-phase Node)

**Tracking (gate-cleanup before closure):**
- [x] Initial-scan findings reviewed and dispositioned (fix / accept / follow-up) per ADR-0011 D11's new-code-only enforcement posture.
- [x] Unreviewed Security Hotspots on Communications and Observe cleared in the SonarCloud UI.
- [x] Org-level GitHub ruleset for SonarCloud flipped Evaluate → Active; `SonarCloud Code Analysis` is now a load-bearing required check on the 12 onboarded repos.
- [x] `feat/adr0011-sonar-quality-gate` work in `HoneyDrunk.Actions` deployed so future findings are caught by the gate going forward.

**Deferred (Wave 3 — future onboarding, NOT scoped in this initiative):**
- HoneyDrunk.Vault.Rotation — non-canonical workflow shape (uses `validate-pr.yml` instead of `pr.yml`); onboard when its CI conforms to the Grid convention.
- HoneyDrunk.Studios — TypeScript/Next.js; SonarQube-JS onboarding evaluated as a separate one-off when Studios CI is otherwise wired.
- HoneyDrunk.Architecture, HoneyDrunk.Lore, HoneyDrunk.Standards — docs / wiki / analyzer pack; no application code to analyze.
- HoneyDrunk.Evals, HoneyDrunk.Sim — GitHub repos don't exist yet (in `catalogs/nodes.json` as Seed Nodes only).
- 6 empty AI-sector Seed Nodes (HoneyDrunk.Capabilities, .Agents, .Memory, .Knowledge, .Flow, .Operator) — scaffolded repos with zero `csproj` files; onboard when the first .NET code lands.

**Out of scope (Unresolved Consequences in the ADR):**
- Integration tests (Gap 1) — slot defined; closed by ADR-0047.
- E2E / Playwright tests (Gap 3) — slot defined; closed by ADR-0047.
- Cost discipline tooling (Gap 4) — review agent's checklist covers it qualitatively.
- Private-repo SonarQube Cloud (Gap 5) — opt-in per repo, no Wave-3 fan-out.

---

### Grid CI/CD Control Plane (ADR-0012)
**Status:** Complete
**Scope:** Architecture, Actions
**Completed:** 2026-05-27
**Initiative:** `adr-0012-grid-cicd-control-plane`
**Description:** ADR-0012 is accepted and its follow-up rollout has landed: the repo catalog carries tracked workflows, HoneyDrunk.Actions owns the grid-health aggregator and shared CI/CD documentation, the direct-CLI and action-pin inventories are current, caller workflow permissions were audited across the Grid, and the Node 20 deprecated-action bump has shipped.

**Tracking:**
- [x] Architecture#443: Accept ADR-0012, finalize invariants 37-41, register initiative, and reconcile review discipline.
- [x] Architecture#443: Add the GitHub profile workflow-failure notification runbook.
- [x] Architecture#444: Add `tracked_workflows` coverage to the repo catalog.
- [x] Actions#131: Author the grid-health aggregator.
- [x] Actions#131: Refresh canonical consumer permissions documentation.
- [x] Actions#131: Author the action-pin inventory.
- [x] Actions#131: Complete the D4 direct-CLI retrofit audit.
- [x] Architecture#447: Add the caller-workflow permissions audit.
- [x] Actions#153: Bump Node 20 deprecated actions and update pin inventory.
- [x] Architecture#448 and cross-repo follow-ups: grant missing caller permissions surfaced by the audit.

---

### Architecture Command Center
**Status:** Complete  
**Scope:** Architecture  
**Completed:** 2026-03-28  
**Description:** HoneyDrunk.Architecture stood up as the central command center. Catalogs, routing rules, issue templates, copilot instructions, per-repo context docs, and Azure infrastructure documentation all in place.  

---

## Cancelled

### ~~HoneyDrunk.Tools~~ (Scrapped)
**Status:** Cancelled  
**Scope:** Ops  
**Description:** Originally planned as a separate CLI for scanning, accessibility checks, and CI automation. Decision made to implement this logic directly as composite actions within HoneyDrunk.Actions instead.  
