# Implementation Notes — ADR-0033 Environment-Gated Deploy-Trigger Model

**Initiative:** `adr-0033-deploy-trigger-model`
**Authored:** 2026-06-01 by the implementing agent (Claude Code), per ADR-0008 § Implementation-Notes Packets.
**Implementing PRs:** HoneyDrunk.Notify #54 (`release-functions.yml` + `release-worker.yml`, closed #19/#20) · HoneyDrunk.Pulse #42 (`release-collector.yml`, closed #18) · HoneyDrunk.Actions #181 (out-of-band control-plane fix surfaced during implementation).

> First worked instance of the implementation-notes process. ADR-0033's scope (2026-05-20) predates the process, so this record is reconstructed retrospectively by the implementing agent rather than executed from a scope-emitted stub. The original decision (ADR-0033) and packets 01/02/03 are **not** edited — this is a retrospective overlay.

## What shipped

All three release lines adopted an **ADO-style staged approval-gate promotion** model: per-environment deploy jobs under static GitHub Environments. `push → main` (path-filtered) runs `deploy-dev` (continuous); a `<line>-v*` tag runs `deploy-staging` and then a **gated** `deploy-prod`. The prod gate is the `prod` GitHub Environment's required-reviewers rule; `deploy-prod` `needs: deploy-staging` and `resolve-prod` also `needs: deploy-staging`, so the approval pause occurs **after** staging, not in parallel. HoneyDrunk.Actions reusable deploy workflows were not modified for trigger policy (ADR-0012 preserved).

## Deltas (decided ➜ as-built) and why

1. **Promotion shape — D1.** *Decided:* one tag trigger selects `staging`/`prod`; dev via path-filtered push. *As-built:* a **staged pipeline** — tag → `deploy-staging` → (manual gate) → `deploy-prod` in one run, with per-environment jobs. **Why:** the operator asked to "wire it up fully" (active staging/prod, not deferred) and then chose an ADO-style staged approval gate for promotion. That UX is GitHub-native via Environments + required reviewers, which attach to a job's `environment:` — so the design became one job per environment.
2. **Trigger→env mapping — D2.** *Decided:* a single `resolve` job maps trigger→env via conditional, emitting `target_environment`. *As-built:* **no dynamic mapping/`classify`** — static `resolve-{dev,staging,prod}` + `deploy-{dev,staging,prod}` jobs gated by `if:` on the trigger; each carries a literal `environment:`. **Why:** static per-env jobs are what let the prod Environment gate attach to exactly one job; a dynamic single-environment expression can't express a staged gate.
3. **Concurrency — D5.** *Decided:* top-level `concurrency` keyed on resolved env. *As-built:* **job-level** concurrency per static env (`release-<line>-<env>`), `cancel-in-progress: true` for dev only. **Why:** with static per-env jobs the key is known per job; top-level couldn't reference the (now job-static) environment cleanly.
4. **Promotion artifact — D6.** *Decided:* rebuild-from-tag for every env; identical-artifact promotion deferred. *As-built:* **Functions = build-once same-artifact** (one `build` job; all three deploys reuse the run artifact); **containers rebuild the tagged source per per-env registry** (`acrhdshared<env>`), with literal same-artifact promotion deferred pending a **registry-topology decision** (shared cross-env registry or `az acr import`). **Why:** Functions artifacts persist within a run, so same-artifact is free; container images live in per-env registries, so true promote-the-same-image needs infra that doesn't exist yet.
5. **Prod gate — D7.** *Decided:* environment protection rules are a *complement* for staging/prod; the rejected "approval-gate, no tags" alternative degraded version-of-record. *As-built:* the gate is **active** — but we **kept the SemVer tag as the promotion trigger** and added the approval gate on top, so version-of-record is preserved and the rejected alternative is reconciled, not adopted. `dev` stays unprotected (D7 intact).
6. **Worker path filter — packet 02 (factual correction).** *Packet said:* exclude core `HoneyDrunk.Notify/**` and `HoneyDrunk.Notify.Abstractions/**` ("Functions only"). *As-built:* **included** them, plus `HoneyDrunk.Notify.ProviderSupport/**`. **Why:** they are in the Worker's transitive build closure (`Worker → Hosting.AspNetCore → core + Abstractions`; Providers/Queue compile `ProviderSupport/*.cs` via `<Compile Include>` shared source). The packet was wrong; excluding them would silently skip the dev deploy on shared-library changes — the exact failure D3 exists to prevent.
7. **Shared *source* dirs (both filter sets).** Added `HoneyDrunk.Notify.HostBootstrap/**` and `HoneyDrunk.Notify.ProviderSupport/**` (Notify) and confirmed `HoneyDrunk.Telemetry.Sink.*/**` covers `Telemetry.Sink.Shared` (Pulse). **Why:** these are compiled in via `<Compile Include>` with no `.csproj`, so a ProjectReference-only scan (which the packets relied on) misses them though they change the deployed binary.
8. **Restore/build inputs.** Added `NuGet.config` (Notify) and `.dockerignore` (Worker, Collector) to the filters. **Why:** both affect the published artifact / image; flagged by Copilot.
9. **Least privilege.** `id-token: write` scoped to the deploy job (workflow default read-only), and an empty-`HD_ENV` fail-fast guard added per env. **Why:** CodeRabbit (zizmor) + Copilot; beyond the packets but correct.
10. **CHANGELOG — dropped.** *Packets + dispatch plan required:* a dated CHANGELOG entry per repo. *As-built:* **none.** **Why:** neither HoneyDrunk.Notify nor HoneyDrunk.Pulse has a repo-level `CHANGELOG.md` (404) — the packet assumption was unsatisfiable as written. Operator confirmed dropping it.

## Known convention deviation

- **ADR numbers in workflow comments.** The dispatch plan's doc convention is *no ADR numbers in workflow/code comments* (only as packet frontmatter). The shipped workflows **retain** `ADR-0033`/`D1`… references in their header/inline comments. **Why:** operator chose readability/traceability for these release workflows. Recorded as a deliberate deviation; an optional follow-up can strip them to conform.

## Control-plane bug found & fixed during implementation

- The first real Functions dev deploy failed at "Upload published artifact": `actions/upload-artifact@v6` rejects `.`/`..` path segments, and the reusable `job-dotnet-publish-artifact.yml` built the upload path as `<working-directory>/<publish-output>` = `././publish`. A v6-bump regression affecting **every** consumer. Fixed in **HoneyDrunk.Actions #181** (`realpath -m --relative-to` normalization). Out of ADR-0033 scope but on the critical path, so fixed to unblock.

## Verification / reality check

The merge triggered the first-ever real `deploy-dev` runs. **Trigger logic proven correct:** `resolve-dev` succeeded on all three, OIDC login worked, staging/prod correctly skipped. The deploys then failed on **dev infrastructure gaps** (not workflow logic), which is the real remaining wall:
- **Functions** — Key Vault fetch: dev deploy SP can't read `kv-hd-notify-dev`, or secrets unseeded.
- **Worker** — image pull `UNAUTHORIZED`: Container App identity lacks **AcrPull** on `acrhdshareddev`.
- **Collector** — `LinkedAuthorizationFailed`: Pulse SP lacks `managedEnvironments/join` on `cae-hd-dev` (cross-RG in `rg-hd-notify-dev`).

These are Azure RBAC + secret-seeding gaps in the dev subscription (`82073da5`), undocumented because dev was hand-provisioned. They belong to **ADR-0077 (Infrastructure-as-Code, Bicep)** — concrete evidence for accepting and implementing it (its Identity module is exactly "managed identities, role assignments, RBAC scopes").

## Follow-ups surfaced

- Reconcile ADR-0033 D1/D2/D5/D6/D7 with this as-built record (the ADR gets a dated `## Implementation Notes` pointer; decision history preserved).
- **Prod provisioning:** configure the `prod` Environment required-reviewers (arms the gate); resolve the **double-gate** (both `resolve-prod` and `deploy-prod` enter `environment: prod` → two approvals — collapse via repo-level OIDC vars or a control-plane change); decide **registry topology** for container same-artifact promotion.
- **Dev infra:** AcrPull, managed-env join, Key Vault secret access + seeding — apply directly now, codify under ADR-0077 (Bicep).
- **Optional:** strip ADR numbers from the three workflow comments to conform to the doc convention.
- **Process:** update the scope agent to emit Implementation-Notes packets (ADR-0008 amendment follow-up).
