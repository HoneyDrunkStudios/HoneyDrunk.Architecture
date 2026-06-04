# Implementation Notes — ADR-0015 Container Apps Rollout

**Initiative:** `adr-0015-container-apps-rollout`
**Authored:** 2026-06-04 by the implementing agent (Claude Code), per ADR-0008 § Implementation-Notes Packets.
**Implementing PRs:**
- Release workflows (initial): HoneyDrunk.Notify **#11** (`Notify.Functions` + `Notify.Worker` tag-based release) · HoneyDrunk.Pulse **#12** (`Pulse.Collector` Container Apps deploy).
- Release workflows (restructured to the staged approval-gate model): HoneyDrunk.Notify **#54** · HoneyDrunk.Pulse **#42** — see the ADR-0033 implementation-notes; ADR-0033 was layered on top of these ADR-0015 workflows.
- Worker parked on standby: HoneyDrunk.Notify **#55** + HoneyDrunk.Architecture **#557** (ADR-0015 standby note).
- Dev bring-up fixes (the bulk of the Azure work): HoneyDrunk.Actions **#181** (artifact path), **#183** (Flex hidden-files + container revision name), **#185 → #186** (Functions health-check hostname); HoneyDrunk.Notify **#56** (Functions isolated-worker startup crash).
- Hand-applied dev provisioning (RBAC / ingress / probes): **not in any PR** — applied live via `az` in subscription `honeydrunk-dev` (`82073da5`); this is the concrete spec for ADR-0077 (Bicep IaC).

> Wave 1 packets (`01` walkthroughs, `02` `job-deploy-container-app.yml`) completed earlier and were already in `completed/`. This record covers Wave 2 (packets `03/04/05`) and, more importantly, the **Azure bring-up** that issues `Notify#3`, `Notify#4`, and `Pulse#3` actually tracked — the part that only became real when the first deploys ran (2026-06-02 → 2026-06-04). ADR-0015's scope (2026-04-18) predates the implementation-notes process, so this is a retrospective overlay by the implementing agent; the original decision and packets `01–05` are **not** edited.

## What shipped

All three first-generation deployables run on Azure Container Apps / Flex Consumption in **dev**, deployed through the sanctioned ADR-0033 pipeline:

| Deployable | Kind | Dev status |
|---|---|---|
| `Pulse.Collector` | Container App (`ca-hd-pulse-dev`) | **Deployed, Running/Healthy** on our image |
| `Notify.Functions` | Flex Consumption Function App (`func-hd-notify-dev`) | **Deployed, healthy** — `/api/health` → 200, all 3 functions registered |
| `Notify.Worker` | Container App (`ca-hd-notify-worker-dev`) | **Parked on standby** — revisions deactivated, 0 replicas, manual-dispatch CI only |

The reusable `job-deploy-container-app.yml` / `job-deploy-function.yml` workflows + composite actions (Wave 1, packet 02) underpin all three and are reused by every future deployable.

## Deltas (decided ➜ as-built) and why

1. **Notify.Worker — deploy ➜ park.** *Decided (packet 04):* bring up `Notify.Worker` as a running Container App dispatcher. *As-built:* the release workflow was built, but the Worker is **parked on standby** — not deployed/running. **Why:** `Notify.Functions` and `Notify.Worker` both dispatched the **same** `notify-queue` Storage queue (scaffolded together, no recorded reason). Functions is the sole active dispatcher; rather than retire the Worker, keep the code and stop paying for / auto-deploying it until a distinct second lane (bulk/throttled/scheduled on a separate queue) exists. Recorded as an ADR-0015 standby note (Notify #55, Architecture #557). `Notify#4` is therefore resolved as **"release workflow built; deployment intentionally parked,"** not "running in dev."

2. **Dev substrate was hand-provisioned from placeholders.** *Decided (packet Human-Prereqs):* portal-provision each app per the Wave 1 walkthroughs. *As-built:* the dev apps existed as `simple-hello-world` placeholders and were missing almost all runtime wiring; everything was **hand-fixed live via `az`**, because the walkthroughs were authored before the apps were correctly stood up. Concretely, per deployable:
   - Container App system MI → **AcrPull** on `acrhdshareddev` (+ `containerapp registry set --identity system`) — else image pull `UNAUTHORIZED`.
   - Container App + Function App system MIs → **Key Vault Secrets User** on the Node KV.
   - Each app's MI → **App Configuration Data Reader** on `appcs-hd-shared-dev` — else `AddAppConfiguration` 403s and the app crashes on startup (data-plane RBAC propagation takes minutes).
   - Deploy SP → KV Secrets User and **Contributor on the managed environment** `cae-hd-dev` (cross-RG) so the Pulse SP can `join` it (fixes `LinkedAuthorizationFailed`).
   - `az role assignment` throws `MissingSubscription` after device-code login → role grants applied via `az rest` PUT to the Authorization RP.
   - Collector placeholder cruft (perpetuated by `containerapp revision copy`): ingress `targetPort` **80 → 8080**; explicit Liveness/Readiness/Startup probes on **TCP :80** cleared (they were killing the healthy app).
   **Why captured here:** none of this is codified — it is the concrete spec / acceptance case for **ADR-0077 (Bicep IaC)**.

3. **Notify.Functions isolated worker crashed on startup.** *As-built delta surfaced during bring-up:* the Flex worker aborted with exit 134 (SIGABRT) before any telemetry — `App Configuration bootstrap requires a mutable IConfigurationManager instance on the service collection`. `HoneyDrunk.Vault.Providers.AppConfiguration.AddAppConfiguration()` resolves `IConfiguration` from the service collection and requires the mutable `ConfigurationManager`; `WebApplicationBuilder` registers it as an instance but `FunctionsApplication.CreateBuilder` does not. **Fixed consumer-side** in Notify **#56** (register `builder.Configuration` before the Vault bootstrap). A durable fix in the Vault package (resolve the manager from any `IHostApplicationBuilder`) is deferred — see Follow-ups.

4. **CI control-plane bugs blocked the first real deploys.** Surfaced and fixed on the critical path:
   - `actions/upload-artifact@v6` rejects `.`/`..` path segments → `job-dotnet-publish-artifact.yml` produced `././publish` → Actions **#181** (`realpath` normalization).
   - Flex deploy "Cannot find required `.azurefunctions` directory" (hidden dir dropped by upload) + container `InvalidRevisionName` (`revision copy --query name` returns the app name) → Actions **#183**.
   - The `deploy-function` post-deploy health check probed `https://<name>.azurewebsites.net`, which **does not route for Flex Consumption** (regional hostname only) → HTTP 000 false-negative → Actions **#185** (switch to `defaultHostName`) then **#186** (`az resource show`, because `az functionapp show` returns null for `defaultHostName`/`state`/`hostNames` on Flex — a CLI quirk — plus correct slot child-resource addressing).

## Verification / reality check

The ADR-0033 pipeline now deploys all three lines green in dev:
- **Collector** — `Deploy to Container App: success`; traffic revision Running/Healthy on our image.
- **Functions** — `Deploy to Function App: success`; health check `Probing https://func-hd-notify-dev-<hash>.eastus2-01.azurewebsites.net/api/health → HTTP 200`; host registers `HealthFunction`, `NotifyDispatcherFunction`, `VaultInvalidationFunction`.
- **Worker** — parked; no dev deployment by design.

`Notify#3` (Functions) and `Pulse#3` (Collector) are satisfied (release workflow + Azure bring-up complete). `Notify#4` (Worker) is satisfied as **release workflow built + deployment parked**.

## Follow-ups surfaced

- **ADR-0077 (Bicep IaC)** — codify all of Delta 2 (managed identities, role assignments, ingress/targetPort, probes, App Config seeding). This rollout is the concrete evidence/spec for it. *(Primary follow-up.)*
- **HoneyDrunk.Vault** — make `AddAppConfiguration` resolve the mutable `IConfigurationManager` from any `IHostApplicationBuilder` (or add an overload), so future Functions consumers don't need the Notify #56 workaround.
- **App Configuration seeding** — `appcs-hd-shared-dev` has no `honeydrunk-notify` label keys; Notify runs on code defaults (issue `#326`).
- **Prod bring-up** — mirror the dev provisioning, arm the `prod` Environment required-reviewers, and resolve the registry-topology / double-gate items noted in the ADR-0033 implementation-notes.
- **Notify.Worker reactivation** — only when a distinct second dispatch lane (separate queue) exists; the parked workflow + Container App are preserved for one-step reactivation.
