# Handoff — Wave 3 → Wave 4: operator runbooks + Grid-wide security tooling

**Initiative:** `adr-0056-threat-model`
**Wave transition:** Wave 3 (artifact v1 + governance plumbing + `SECURITY.md`) → Wave 4 (operator runbooks + tooling enablement)
**Read once at the wave boundary. Immutable per invariant 24.**

## What Wave 3 produced

- **Packet 02 — `constitution/threat-model.md` v1.** Every TBD in v0 is replaced with a real mitigation entry. 60 STRIDE bullets across TB-1 through TB-10 cite the implementing slice-ADRs (ADR-0006, ADR-0010, ADR-0011, ADR-0015, ADR-0026, ADR-0028, ADR-0030, ADR-0033, ADR-0040, ADR-0041, ADR-0044, ADR-0045, plus Proposed-status ADRs 0046/0049/0050/0051/0052/0054). 8 AI-overlay entries fill section 6, with AI-1/AI-4/AI-7/AI-8 explicitly named as deferred to owning-Node tracks and the residual risk of each deferral spelled out. The asset table's `Threat IDs` column is populated. Header bumped to v1; last-reviewed = packet 02's merge date.
- **Packet 03 — Standup-ADR template + `hive-sync` extension.** The canonical standup-ADR authoring guidance now requires a "threat model entry" section. `hive-sync.md` has a new sub-scan: standup-ADR-vs-artifact Node-list consistency, with the pre-invariant-93 backfill exemption (Accepted standups before packet 00's merge date are not retroactively flagged). Invariant 93 is now enforceable at authoring time (the template) and at scan time (`hive-sync`).
- **Packet 04 — `SECURITY.md` authoring.** Org-level `SECURITY.md` lands at `HoneyDrunkStudios/.github/SECURITY.md` (may have required Human Prerequisite for the `.github` meta-repo creation). Disclosure email `security@honeydrunkstudios.com`, 90-day window, Disclose.io core safe-harbor text verbatim, explicit out-of-scope list, no-bug-bounty-at-v1. Per-public-repo template is in this repo's templates location for future divergence; no per-repo PRs filed.

ADR-0056's substrate is now operationally useful for the operator's quarterly review (D5) and for the canonical review agents that read `constitution/threat-model.md` from this point on.

## What Wave 4 must deliver (packets 05, 06, 07, 08)

**Packet 05 — Security incident response runbook extensions** in `business/context/`:
- SEV-1 default with legitimate/illegitimate downgrade examples.
- Tenant notification: 72-hour GDPR window as the cross-jurisdictional default, via `ICommunicationOrchestrator` per ADR-0019, content aligning with ADR-0050.
- Forensic preservation hold: extends the 730-day audit retention during active investigation; export-and-hold mechanism is **pending Audit Phase-2** with an interim manual-export-to-Blob note.
- Post-mortem threat-model-amendment section: three-question prompt; `generated/incidents/_template.md` extended (Option A default) or `_template-security.md` variant (Option B).

**Packet 06 — Found-secret rotation runbook** in `business/context/`:
- Response posture: rotation, not deletion; history rewriting cosmetic.
- 1-hour high-sensitivity / 4-hour lower-sensitivity time-to-rotation targets; time starts at detection.
- Pre-staged concrete commands per secret class (model API keys for each provider, Stripe production keys, Azure subscription credentials, Auth signing keys, then SaaS keys at lower sensitivity).
- Universal rotation sequence: rotate at source → update Vault → confirm in use → address git history (cosmetic) → log incident.

**Packet 07 — Pentest scoping prep + DIY adversarial-probe playbook** in `business/context/`:
- Pentest scoping: firm-selection criteria; pre-Notify-Cloud-GA scope (TB-1 through TB-4 + auth probe); $5–15K budget per ADR-0052; deliverable expectations; annual cadence with skipped-year accepted-risk posture.
- DIY playbook: quarterly cadence; concrete OWASP ZAP + Burp Community + Garak / PromptInject steps; result-recording template; "DIY is not a substitute" framing.

**Packet 08 — `HoneyDrunk.Actions` Grid-wide security tooling enablement**:
- Canonical `dependabot.yml` template at `templates/dependabot.yml` — auto-PR for patches, no auto-merge anywhere, weekly cadence, NuGet + github-actions ecosystems baseline.
- Scaffolded `job-cve-to-packet.yml` reusable workflow consuming Dependabot alerts and authoring critical-severity packets via `file-packets.yml`.
- Operator playbook at `docs/security-tooling-enablement.md` documenting the GitHub Settings-UI toggles (Dependabot alerts, secret scanning, push protection, CodeQL on public repos) + GHAS cost-tier note + backlog burn-down expectations.

## Critical context for Wave 4 execution

- **Packets 05-08 are parallel.** None depends on another within Wave 4. Packet 07 depends on packet 02 (v1 artifact); packets 05/06/08 depend only on packet 00.
- **`business/context/` location convention.** Three packets (05, 06, 07) write to `business/context/`. The convention from ADR-0040 packet 08 / ADR-0045 packet 06 is: extend an existing related file if one exists; otherwise create new. Verify at edit time.
- **Audit Phase-2 dependency is named, not silent.** Packet 05's forensic-preservation export is **pending Audit Phase-2** (df-5 in packet 09's tracker). The runbook names this explicitly and ships an interim manual-export workaround.
- **Operator portal preference.** Per the memory note, the operator prefers portal-first over CLI. Packet 08's tooling-enablement playbook documents the Settings-UI clicks; packet 06's pre-staged commands include portal URLs first, CLI commands second.
- **No real secret values in packet 06.** Per invariant 8 (referenced in packet 00's invariant 95 context). Pre-staged commands use placeholders and Vault secret names; portal links retrieve new values.
- **Critical-only auto-create in packet 08.** High / Medium / Low severities ride Dependabot's standard PR flow without packet creation. Critical alone gets the auto-issue-packet. ADR-0056 D7 is explicit.
- **No auto-merge anywhere.** Patch-version Dependabot PRs go through review per ADR-0044 invariant 52. The `dependabot.yml` allows auto-PR but never auto-merge.

## Human Prerequisites surfaced across Wave 4

Wave 4 carries the most consequential Human Prerequisites in the initiative:

- **Packet 04 (already landed in Wave 3) Human Prerequisites:** `HoneyDrunkStudios/.github` meta-repo creation; `security@honeydrunkstudios.com` email alias; PGP key setup (optional); Disclose.io text re-verification.
- **Packet 06 Human Prerequisites:** verify current high-sensitivity secret inventory; re-verify portal URLs.
- **Packet 07 Human Prerequisites:** engaging a specific pentest firm (gated on Notify.Cloud GA decision); installing OWASP ZAP + Burp Community + Garak / PromptInject; provisioning `dev` test user / tenant; verifying Garak / PromptInject project state.
- **Packet 08 Human Prerequisites:** **largest portal-click surface in the initiative** — enable Dependabot alerts org-wide + Dependabot security updates + dependency graph + secret scanning + push protection + CodeQL on public repos. Decide GHAS cost-tier for private repos. Triage initial 50-200 alerts and historical secret-scan results.

These are operator actions. Packets 05-08 do not block on them — the runbooks/playbooks ship and the operator follows when ready. Filing of the packets as GitHub issues will create board items that surface the Human Prerequisites as checklist items on each issue.

## Invariants binding Wave 4

- **Invariant 8** — Secret values never appear in logs, traces, exceptions, or telemetry — **or in committed runbook files.** Packet 06 uses placeholders and Vault secret names; never real secret values.
- **Invariant 17** — One Key Vault per deployable Node per environment. Packet 06's rotation sequence respects per-Node / per-env Vault scoping (`kv-hd-{service}-{env}`).
- **Invariant 22** — Diagnostic settings route Key Vault audit to Log Analytics. Packet 06's "confirm rotated credential is in use" step reads from Vault's audit logs.
- **Invariant 41** — Preference enforcement / cadence rules / suppression for outbound messages live in Communications, not in Notify. Packet 05's breach-notification path uses Communications' `ICommunicationOrchestrator`, not Notify directly.
- **Invariant 42** — Every orchestrated send records a decision-log entry via `ICommunicationDecisionLog`. Breach notifications are no exception.
- **Invariant 47** — Durable audit emission via `IAuditLog`. Rotation events and breach-notification events are recorded automatically.
- **Invariant 52** — Every non-draft PR on an enabled repo runs the review agent. Dependabot PRs are not exempt — they run through the same review surface. Packet 08's `dependabot.yml` explicitly excludes auto-merge to preserve this.

## Wave 4 acceptance gate

Each Wave 4 packet passes the `pr-core.yml` tier-1 gate (or, for packet 08 in `HoneyDrunk.Actions`, the equivalent CI gate for that repo). After Wave 4:

- The operator has runbooks for: security incidents (packet 05), found-secret rotation (packet 06), pentest scoping + DIY probes (packet 07).
- The CI/CD control plane has: canonical `dependabot.yml`, scaffolded auto-CVE-packet workflow, security-tooling enablement playbook (packet 08).
- The artifact's quarterly-review cadence is fully operational.

Wave 5 (packet 09 — cross-track follow-up tracker) closes the initiative by registering the seven deferred items in `initiatives/active-initiatives.md` and reconciling with `constitution/threat-model.md` section 9.

## What is NOT in Wave 4 (or anywhere in this initiative)

These remain deferred. Wave 4 does not produce them:

- AI-1 `PromptEnvelope` code in HoneyDrunk.AI (df-1; HoneyDrunk.AI track).
- AI-4 immutable-tool-description code in HoneyDrunk.Capabilities (df-2; ADR-0017 standup).
- AI-7 high-blast-radius routing code in HoneyDrunk.Capabilities (df-3; ADR-0017 standup).
- AI-8 90-day model-key rotation in Vault (df-4; Vault.Rotation follow-up).
- Audit investigation-extended-retention export interface (df-5; Audit Phase-2).
- `.claude/agents/security.md` artifact loading (df-6; ADR-0046 scope-out).
- SBOM tooling selection (df-7; follow-up ADR / ADR-0035 amendment).
- Per-repo `dependabot.yml` adoption PRs (fan-out follows the `pr-core.yml` adoption pattern).
- Engaging a specific pentest firm (operator action; gated on Notify.Cloud GA).
- The first DIY adversarial-probe pass (operator-driven quarterly cadence; starts when the operator schedules it).

Packet 09 captures the seven `df-N` deferrals as planning inputs to the right owning tracks.
