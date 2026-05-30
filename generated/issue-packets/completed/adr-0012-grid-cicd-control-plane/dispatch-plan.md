# Dispatch Plan: ADR-0012 Grid CI/CD Control Plane Rollout

**Date:** 2026-04-26
**Trigger:** ADR-0012 (Grid CI/CD Control Plane) Proposed 2026-04-13 — scoped 2026-04-26
**Type:** Multi-repo (Architecture + Actions)
**Sector:** Meta + Ops
**Site sync required:** No. ADR-0012 governs CI/CD mechanics; the Studios website does not surface workflow state, action pins, or grid-health output today. Re-evaluate if a "Grid health" public surface is ever added — the data already lives at a stable URL (the `🕸️ Grid Health` issue), making future site-sync mechanically simple.
**Rollback plan:**
- Architecture-side edits (packets 01, 02, 03, 08) revert cleanly via `git revert` — all are doc/markdown/JSON edits with no consumer side effects beyond reading the catalog.
- Actions-side workflow additions (packets 04, 05, 06, 07) are additive and not yet referenced by callers — reverting removes the workflow without breaking anything.
- Packet 09 (Node 20 bump) is the one packet whose revert affects callers: reverting reverts the workflow files to v4 pins, which still work but bring back the deprecation warnings. Safe to revert; no breaking impact.
- Packet 04 (grid-health aggregator) creates a `🕸️ Grid Health` issue on first run. Revert leaves the issue in place; close it manually if desired. No data loss.
- Per-repo follow-up packets filed by packet 08 (caller-permissions audit) are independent issues; rolling back this initiative does not auto-close them — they remain in their respective repos as small chore items. Close manually if the audit is being abandoned.

## Summary

ADR-0012 names `HoneyDrunk.Actions` as the Grid's CI/CD control plane and binds five Grid CI/CD invariants (37-41 post-acceptance, renumbered from the ADR's draft 34-38 because ADR-0015 has claimed 34-36 in the meantime). The headline deliverable is the **grid-health aggregator** (D6) — a daily scheduled workflow that produces a single `🕸️ Grid Health` issue plus per-repo failure issues with idempotent open/close semantics. The supporting deliverables close documentation, audit, and operational gaps named in the ADR's Unresolved Consequences.

**Twelve packets across two repos:**

- 5 Architecture packets (acceptance + invariants, notifications runbook, tracked_workflows catalog, caller-permissions audit, plus zero-or-more per-repo follow-ups filed by the audit packet)
- 7 Actions packets (grid-health aggregator, consumer-usage refresh, action-pins inventory, D4 retrofit audit, **three D4 migrations** — 07a Trivy / 07b SBOM / 07c actionlint Docker-ref decision — and Node 20 actions bump)

Two waves. Wave 1 is foundation work that runs in parallel after packet 01 lands. Wave 2 contains the two packets with hard internal dependencies on Wave 1 outputs.

**Note on packet 07 split.** Initial scope-time inspection treated D4 retrofit as "verification-only" — refinement caught three live D4 violations in `HoneyDrunk.Actions/.github/workflows/`: `aquasecurity/trivy-action` and `anchore/sbom-action` in `release.yml`, plus a `docker://rhysd/actionlint` Docker-image ref in `actions-ci.yml` (the third forces an explicit D4 policy decision since the ADR is silent on Docker-image refs). The audit packet 07 was reframed to enumerate the three known violations and validate no fourth exists; the migrations land as three independent small-blast-radius PRs (07a / 07b / 07c) so any single rollback is contained.

## Important constraints (from ADR-0012 itself)

- **Invariant numbering precedence.** ADR-0015 owns 34-36 in the live `constitution/invariants.md`. ADR-0012's invariants are renumbered from the draft 34-38 to 37-41. Packet 01 lands the renumber in the ADR body, the constitution, and (where relevant) every cross-reference inside the new invariant text.
- **The aggregator (packet 04) is the headline; everything else supports it.** The headline is hard-blocked on packet 03 (catalog data). All Wave 1 docs (02, 05, 06, 08) are needed for invariant 39 / 40 / 41 enforceability but do not block the aggregator's implementation work.
- **D7 (profile notifications) is operator-side.** Packet 02 ships the runbook; the actual portal click is a Human Prerequisite. The aggregator's recursive failure design (D6) means the operator's profile notifications are the safety net for the aggregator's own failures.
- **Invariant 33 symmetry.** Packet 01 amends `.claude/agents/review.md` with the caller-permissions Request Changes rule. The amendment is to the **rule list**, not the **context-loading section** — symmetry with `scope.md` is preserved by construction. If the executing agent finds itself wanting to add a file to either agent's required reading, stop and surface — that requires a coordinated edit.
- **Pre-existing site-sync deferral.** No public surface today reflects ADR-0012 outputs; site-sync is deferred indefinitely until a future "Grid health" page is decided. Tracked in this dispatch plan only — not a separate packet.

## Wave Diagram

### Wave 1 — Foundation (nine packets, parallel after packet 01)

Run packet 01 first. Once it merges, packets 02, 03, 05, 06, 07, 07a, 07b, 07c, 08 run in parallel. Each is independent; the soft blocks on 01 are for invariant numbering only and resolve once 01 merges.

- [ ] `HoneyDrunk.Architecture`: **Accept ADR-0012** — flip status, renumber invariants 34-38 to 37-41, register initiative, amend `.claude/agents/review.md` with caller-permissions rule — [`01-architecture-adr-0012-acceptance.md`](01-architecture-adr-0012-acceptance.md)

After packet 01 lands:

- [ ] `HoneyDrunk.Architecture`: GitHub profile notifications runbook at `infrastructure/github-notifications.md` — [`02-architecture-github-notifications-runbook.md`](02-architecture-github-notifications-runbook.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 40 numbering).
- [ ] `HoneyDrunk.Architecture`: Add `tracked_workflows` to repo catalog — [`03-architecture-tracked-workflows-catalog.md`](03-architecture-tracked-workflows-catalog.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 41 numbering).
- [ ] `HoneyDrunk.Actions`: Refresh `docs/consumer-usage.md` with canonical `permissions:` blocks per D5/D9 — [`05-actions-consumer-usage-refresh.md`](05-actions-consumer-usage-refresh.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 39/40 numbering).
- [ ] `HoneyDrunk.Actions`: Author `docs/action-pins.md` inventory (D10) — [`06-actions-action-pins-inventory.md`](06-actions-action-pins-inventory.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 38 numbering).
- [ ] `HoneyDrunk.Actions`: D4 retrofit audit + cross-repo nightly-security re-runs — [`07-actions-d4-retrofit-audit.md`](07-actions-d4-retrofit-audit.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 38 numbering).
- [ ] `HoneyDrunk.Actions`: Migrate `release.yml` Trivy step to direct Docker invocation (D4) — [`07a-actions-trivy-direct-cli-migration.md`](07a-actions-trivy-direct-cli-migration.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 38 numbering).
- [ ] `HoneyDrunk.Actions`: Migrate `release.yml` SBOM step to direct `syft` CLI (D4) — [`07b-actions-sbom-direct-cli-migration.md`](07b-actions-sbom-direct-cli-migration.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 38 numbering).
- [ ] `HoneyDrunk.Actions`: Decide D4 stance on `docker://` image refs and migrate `actions-ci.yml` actionlint accordingly — [`07c-actions-actionlint-docker-ref-decision.md`](07c-actions-actionlint-docker-ref-decision.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 38 numbering).
- [ ] `HoneyDrunk.Architecture`: Caller-workflow `permissions:` audit across every Live + workflow-bearing Grid repo — [`08-architecture-caller-permissions-audit.md`](08-architecture-caller-permissions-audit.md)
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant 39 numbering).
  - Blocked by: Wave 1 — `05-actions-consumer-usage-refresh.md` (soft, link-don't-copy: audit doc cross-links to consumer-usage.md as canonical baseline source).

**Wave 1 exit criteria** (before Wave 2 starts):

- ADR-0012 reads `**Status:** Accepted`; constitution contains invariants 37-41 with the renumbered cross-references; index row reflects Accepted.
- `.claude/agents/review.md` contains the caller-permissions Request Changes rule.
- `infrastructure/github-notifications.md` exists; the operator has clicked through the portal walkthrough and verified D7 fires email on a deliberate failure.
- `catalogs/grid-health.json` has `tracked_workflows` populated for every repo entry; `_meta.schema_version` reads `"1.1"`.
- `HoneyDrunk.Actions/docs/consumer-usage.md` reflects the canonical `permissions:` blocks for every reusable workflow consumer example.
- `HoneyDrunk.Actions/docs/action-pins.md` exists with the inventory of every third-party action pin and its deprecation status.
- `HoneyDrunk.Actions/docs/d4-retrofit-audit.md` exists with the audit table; the three known D4 violations (Trivy, SBOM, actionlint) are documented and cross-linked to 07a/07b/07c; the audit confirms no fourth violation exists; nightly-security re-runs across every workflow-bearing Grid repo report zero false-positive findings.
- 07a (Trivy direct Docker invocation) and 07b (direct `syft` CLI) have merged in `release.yml`; 07c lands the explicit D4 stance on `docker://` image refs and migrates the actionlint step accordingly.
- `infrastructure/caller-permissions-audit.md` exists; per-repo follow-up issues filed for any non-Pass rows; the four-state count is recorded.

### Wave 2 — Hard-blocked execution (two packets)

- [ ] `HoneyDrunk.Actions`: **Grid health aggregator** (`grid-health-report.yml`) — [`04-actions-grid-health-aggregator.md`](04-actions-grid-health-aggregator.md)
  - Blocked by: Wave 1 — `03-architecture-tracked-workflows-catalog.md` (**hard** — aggregator reads `tracked_workflows`).
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft, invariant numbering).
- [ ] `HoneyDrunk.Actions`: **Bump Node 20 deprecated actions** to v5 + update pin inventory — [`09-actions-node20-actions-bump.md`](09-actions-node20-actions-bump.md)
  - Blocked by: Wave 1 — `06-actions-action-pins-inventory.md` (**hard** — atomic PR updates inventory and workflows together).
  - Blocked by: Wave 1 — `01-architecture-adr-0012-acceptance.md` (soft).

**Wave 2 exit criteria:**

- `grid-health-report.yml` exists and a `workflow_dispatch` run has produced a sane `🕸️ Grid Health` issue body. Per-repo failure issues open and close idempotently across two consecutive runs (verified by triggering twice and observing zero duplicates).
- `GRID_HEALTH_PAT` repo secret is provisioned and scoped to `Issues: Write` on every node with non-empty `tracked_workflows` plus `HoneyDrunk.Actions` and `HoneyDrunk.Architecture`.
- Every Node 20-runtime action across reusable workflows and composite actions is bumped to v5 (or its latest available successor); `docs/action-pins.md` reflects the new state with `Status: Current`.
- Smoke tests post-Node-20-bump (`nightly-security.yml` + `nightly-deps.yml` against Kernel) report `conclusion: success` with no new deprecation warnings.

## Out-of-scope items from ADR-0012

These items in ADR-0012 are explicitly **not** addressed by this initiative:

- **Gap 4 partial — automated catalog drift detection.** Packet 04 includes a "Catalog drift" section in the rendered Grid Health report (one extra `gh api` call), which is the partial fix. A separate dedicated workflow that posts drift to a different surface is **deferred** — the partial fix in 04 is sufficient for today.
- **Gap 5 — automated action-pin diff workflow.** ADR-0012 D10's optional weekly diff workflow that auto-flags pin drift against the inventory is **explicitly deferred**. The hand-maintained inventory (packet 06) is sufficient at today's growth rate. Revisit if multiple action bumps are missed.
- **Per-repo override files for shared CI config.** ADR-0012 D3's repo-local override mechanism for `.gitleaks.toml` (and future tools) is mechanism-only; no per-repo override exists today. No packet here. Filed if/when a repo needs the override.
- **Pulling shared config for tools beyond gitleaks.** ADR-0012 Gap 2 names CodeQL query packs, Trivy IaC policy, dotnet-format rules as future shared-config additions. Not urgent. Each will be a small standalone packet when friction surfaces.

If any of these gaps becomes urgent, it is scoped via a new initiative — not appended here.

## `gh` CLI Commands — File All Wave 1 + Wave 2 Issues

Paths are relative to the `HoneyDrunk.Architecture` repo root. All nine packets file in one pass; wave is execution sequencing, not a filing gate. Blocking relationships are wired afterward via `addBlockedBy`.

```bash
PACKETS="generated/issue-packets/active/adr-0012-grid-cicd-control-plane"

# --- Wave 1: Foundation ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Accept ADR-0012 — flip status, renumber invariants 37-41, register initiative" \
  --body-file $PACKETS/01-architecture-adr-0012-acceptance.md \
  --label "feature,tier-2,meta,docs,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Author GitHub profile notifications runbook (infrastructure/github-notifications.md)" \
  --body-file $PACKETS/02-architecture-github-notifications-runbook.md \
  --label "feature,tier-1,meta,docs,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Add tracked_workflows to repo catalog for grid-health aggregator consumption" \
  --body-file $PACKETS/03-architecture-tracked-workflows-catalog.md \
  --label "feature,tier-2,meta,catalog,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Refresh docs/consumer-usage.md with canonical permissions blocks per D5/D9" \
  --body-file $PACKETS/05-actions-consumer-usage-refresh.md \
  --label "chore,tier-1,ci-cd,ops,docs,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Author docs/action-pins.md — third-party action pin inventory (D10)" \
  --body-file $PACKETS/06-actions-action-pins-inventory.md \
  --label "chore,tier-1,ci-cd,ops,docs,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Audit reusable workflows for D4 direct-CLI compliance + re-run nightly-security grid-wide" \
  --body-file $PACKETS/07-actions-d4-retrofit-audit.md \
  --label "chore,tier-1,ci-cd,ops,audit,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Migrate release.yml Trivy step from aquasecurity/trivy-action to direct Docker invocation (D4)" \
  --body-file $PACKETS/07a-actions-trivy-direct-cli-migration.md \
  --label "chore,tier-1,ci-cd,ops,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Migrate release.yml SBOM step from anchore/sbom-action to direct syft CLI (D4)" \
  --body-file $PACKETS/07b-actions-sbom-direct-cli-migration.md \
  --label "chore,tier-1,ci-cd,ops,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Decide D4 stance on docker:// image refs and migrate actions-ci.yml actionlint step (D4)" \
  --body-file $PACKETS/07c-actions-actionlint-docker-ref-decision.md \
  --label "chore,tier-2,ci-cd,ops,adr-0012,wave-1"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Architecture \
  --title "Audit caller-workflow permissions across every Live + workflow-bearing Grid repo (D5)" \
  --body-file $PACKETS/08-architecture-caller-permissions-audit.md \
  --label "chore,tier-2,meta,docs,audit,adr-0012,wave-1"

# --- Wave 2: Hard-blocked execution ---

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Author grid-health-report.yml aggregator workflow (D6 implementation)" \
  --body-file $PACKETS/04-actions-grid-health-aggregator.md \
  --label "feature,tier-2,ci-cd,ops,adr-0012,wave-2"

gh issue create --repo HoneyDrunkStudios/HoneyDrunk.Actions \
  --title "Bump Node 20 deprecated actions to v5 across reusable workflows + update pin inventory" \
  --body-file $PACKETS/09-actions-node20-actions-bump.md \
  --label "chore,tier-2,ci-cd,ops,adr-0012,wave-2"
```

## After filing — board fields and blocking relationships

For each issue: `gh project item-add 4 --owner HoneyDrunkStudios --url <ISSUE_URL>` then set Status=Backlog (or Ready), Wave (1 or 2), Initiative=`adr-0012-grid-cicd-control-plane`, Node (`honeydrunk-architecture` / `honeydrunk-actions`), Tier (per packet frontmatter), Actor=Agent (default — every packet is delegable; packet 02 has substantial Human Prerequisites for the per-account portal click but the runbook authoring is delegable; packet 04 has a Human Prerequisite for `GRID_HEALTH_PAT` provisioning but the workflow authoring is delegable).

Wire the following `addBlockedBy` relationships:

- `02-architecture-github-notifications-runbook` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `03-architecture-tracked-workflows-catalog` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `05-actions-consumer-usage-refresh` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `06-actions-action-pins-inventory` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `07-actions-d4-retrofit-audit` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `07a-actions-trivy-direct-cli-migration` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `07b-actions-sbom-direct-cli-migration` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `07c-actions-actionlint-docker-ref-decision` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `08-architecture-caller-permissions-audit` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `08-architecture-caller-permissions-audit` blocked-by `05-actions-consumer-usage-refresh` (soft, link-don't-copy: audit doc cross-links to consumer-usage.md as canonical baseline source rather than copying it inline)
- `04-actions-grid-health-aggregator` blocked-by `03-architecture-tracked-workflows-catalog` (**hard**)
- `04-actions-grid-health-aggregator` blocked-by `01-architecture-adr-0012-acceptance` (soft)
- `09-actions-node20-actions-bump` blocked-by `06-actions-action-pins-inventory` (**hard**)
- `09-actions-node20-actions-bump` blocked-by `01-architecture-adr-0012-acceptance` (soft)

Note: 07a/07b/07c are **independent** of the 07 audit packet (they may merge before, after, or in parallel with 07). The audit doc cross-links them, but no blocking edge exists.

Total blocking edges: 14 (12 soft for sequencing; 2 hard for Wave 2 dependencies on Wave 1 deliverables).

## Notes

- **Acceptance precedes flip.** Per the scope-agent convention, ADR-0012 stays Proposed today. Packet 01's PR is the moment it flips to Accepted; the flip, the renumber, the constitution edits, the trackers, and the `review.md` amendment all land in one merge — no early flip.
- **Aggregator is the headline.** Packet 04 is the deliverable that closes Gap 1 (the highest-priority gap in the ADR's Unresolved Consequences). Without it, pipeline visibility falls back to D7 alone, which does not catch staleness or missing runs.
- **`tracked_workflows` shape.** ADR-0012's draft text refers to a per-repo JSON file under `repos/*.json`, but the actual Architecture catalog uses `repos/{Name}/*.md` for context docs and `catalogs/grid-health.json` for JSON state. Packet 03 lands `tracked_workflows` in `grid-health.json` where the JSON-shaped data already lives — this is the practical interpretation of the ADR's intent. The aggregator (packet 04) reads from the same file.
- **D4 retrofit has three known violations.** Refinement-time inspection found three live D4 violations in `HoneyDrunk.Actions/.github/workflows/`: `aquasecurity/trivy-action@0.35.0` in `release.yml` (07a), `anchore/sbom-action@v0` in `release.yml` (07b), and `docker://rhysd/actionlint:1.7.12` in `actions-ci.yml` (07c — forces an explicit D4 stance on `docker://` image refs since the ADR is silent). The gitleaks step in `nightly-security.yml` (direct CLI install + invocation), the Trivy step in `nightly-security.yml` (direct Docker run), and CodeQL (`github/codeql-action/*`, first-party exception) are confirmed compliant. Packet 07 confirms no fourth violation exists; 07a/07b/07c land the migrations as three independent small PRs.
- **Caller-permissions audit may file zero per-repo follow-ups.** The triggering incident's seven broken callers were fixed in-session at ADR-0012's drafting time. Packet 08 verifies the today-state and confirms either zero or some-small-number of remaining violations. If zero, packet 08's per-repo follow-up section reads "None — all callers compliant."
- **Node 20 bump is not urgent.** Deadline 2026-09-16; today is 2026-04-26. Packet 09 lands well before the deadline to remove deprecation noise from nightly logs and to flush v5 behavior surprises early.
- **No new repo, no new ADR, no new contract.** This initiative ships docs + workflow + catalog data + agent rule. The Grid topology (Nodes, sectors, contracts) is unchanged. The catalog gains a new field (`tracked_workflows`) but the schema extension is additive and backwards-compatible.
- **No Azure resources are provisioned.** GitHub Actions hosting is the only infra; no Azure cost. The single secret is `GRID_HEALTH_PAT` (a fine-grained PAT scoped to `Issues: Write` on every node with non-empty `tracked_workflows` plus `HoneyDrunk.Actions` and `HoneyDrunk.Architecture`, one-year expiry; documented in `infrastructure/secrets-inventory.md` per packet 04 Human Prerequisites).
- **The dispatch plan is the one exception to packet immutability** (per ADR-0008 D7). Updates at wave boundaries are the historical record. Packet bodies are immutable post-filing per invariant 24.

## Archival

Per ADR-0008 D10, when every packet in this initiative reaches `Done` on the org Project board and the Wave 2 exit criteria are met, the entire `active/adr-0012-grid-cicd-control-plane/` folder is moved to `archive/adr-0012-grid-cicd-control-plane/` in a single commit. Partial archival is forbidden.

Per-repo follow-up packets filed by packet 08 (caller-permissions audit) live in their own repos' issue trackers and are not part of this initiative folder's archival — they close on their own cadence as their respective PRs merge.

## Known Gaps (pre-existing — not owned by this initiative)

- **`infrastructure/github-projects-field-ids.md` does not exist.** The "After filing" guidance above references it as the source of truth for board custom-field option IDs. This is a pre-existing dangling reference also used by ADR-0005/0006, ADR-0010 Phase 1, ADR-0011, ADR-0015, and `scope.md`. Filing this initiative's nine packets requires hand-populating Wave / Initiative / Node / Tier / Actor field values via the GitHub UI or by copy-pasting IDs from another already-filed packet's project-item state. Recommendation: ship `infrastructure/github-projects-field-ids.md` as a **separate standalone packet** outside this initiative. Do not let it block Wave 1 filing.
- **Workflow-bearing repo enumeration drifts.** The audit packets (07 re-run list, 08 caller list) reference the set of repos with `nightly-security.yml` / caller workflows at scope-time. As Communications and Vault.Rotation come online, the set extends. Each audit doc explicitly notes "verify the set at execution time" and treats divergence as expected, not as a defect.

## Revision history

- **2026-04-26 initial scope** — nine packets across two waves. Aggregator (D6) is the Wave 2 headline; pin inventory (D10) is the Wave 2 prerequisite for the Node 20 bump.
- **2026-04-27 refinement applied** — packet 07 split into 07 (audit) + 07a (Trivy migration) + 07b (SBOM migration) + 07c (Docker-ref decision + actionlint migration) after refinement found three live D4 violations the initial scope missed; packet 03 `tracked_workflows` table corrected (9/10 Live repos use `weekly-deps.yml` not `nightly-deps.yml`; `publish.yml` added everywhere it exists); packet 04 staleness windows extended to cover `weekly-deps.yml` and a generic `weekly-*.yml` fallback, plus an explicit `_meta.schema_version >= "1.1"` assertion and emoji variation-selector verification step; packet 01 review.md insertion specified as new `### 9. CI/CD Workflow Compliance` section after Cost Discipline; packet 08 reference-state pattern flipped from inline-copy to link-don't-copy (cross-links `consumer-usage.md` as canonical baseline). Total packets: 12. Total blocking edges: 14.
