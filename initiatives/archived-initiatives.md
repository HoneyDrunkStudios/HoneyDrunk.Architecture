# Archived Initiatives

Completed and cancelled initiatives. Active and planned work lives in [active-initiatives.md](active-initiatives.md).

---

## Completed

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
