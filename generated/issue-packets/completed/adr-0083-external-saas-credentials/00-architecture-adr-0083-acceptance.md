---
name: Architecture Decision
type: architecture-decision
tier: 3
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["chore", "tier-3", "meta", "docs", "adr-0083", "wave-1"]
dependencies: []
adrs: ["ADR-0083"]
accepts: ["ADR-0083"]
wave: 1
initiative: adr-0083-external-saas-credentials
node: honeydrunk-architecture
---

# Accept ADR-0083 — flip status, add the unified sensitive-inventory invariant (103), register the initiative

## Summary
Flip ADR-0083 (Sensitive Inventory and External-SaaS Credential Rotation Procedure) from Proposed to Accepted: update the ADR header, update the ADR index row in `adrs/README.md`, write the unified sensitive-inventory invariant as **invariant 103** (pre-assigned in `constitution/invariant-reservations.md` alongside ADR-0082's 102 by the refine pass to avoid the "first merge wins" race) into `constitution/invariants.md`, and register the `adr-0083-external-saas-credentials` initiative in `initiatives/active-initiatives.md`.

## Context
ADR-0083 closes the gap that ADR-0005 and ADR-0006 left uncovered: a class of credential the Grid uses today — external-SaaS tokens that authenticate CI to a third-party service or authenticate cross-repo Actions to GitHub itself — lives as GitHub organization-level secrets (not in any `kv-hd-*` vault), binds to operator user accounts (not Managed Identities), and has provider-imposed expiration with no automation. Four concrete cases are in the wild or imminent (`SONAR_TOKEN` at 60 days, `NUGET_API_KEY` at 365 days, `GH_ISSUE_TOKEN` plus peer fine-grained PATs, and the imminent Stripe/Resend/Twilio trio).

The operator's broadened framing during drafting expanded scope from "external-SaaS credentials that need rotation" to "everything the Grid holds that is operationally load-bearing": non-rotating identifiers (`HIVE_APP_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, Discord guild ID), webhook-signing-secret slot names whose values rotate elsewhere but whose existence is permanent, OIDC federated-credential configurations whose subject patterns are operationally binding even though they are not secrets, long-lived Azure Key Vault signing/encryption keys, and resource identifiers (Key Vault names, Container Apps environments, Service Bus namespaces). The recognition was that **lost or forgotten credentials are themselves a bigger lottery-bus-factor risk than missed rotations**, and the same registry artifact closes both.

ADR-0083 decides:

- **D1** — `HoneyDrunk.Vault.Rotation` does **not** expand to cover external-SaaS PATs. External-SaaS rotation stays manual indefinitely. Re-evaluation trigger: active rotation-needing-credential count exceeds ten, or a single high-blast-radius credential rotates more than every 30 days.
- **D2** — The canonical inventory lives at **`infrastructure/reference/sensitive-inventory.md`** with a Grid-wide single-file Markdown table; record shape includes `Name`, `Kind`, `Provider`, `Where Stored`, `Bound To`, `Rotates`, `Expiration Cadence` (optional), `Current Expiration` (optional), `Rotation Procedure` (optional), `Use Cases`, `Blast Radius if Missed`, `Owner`, `Notes` (optional). One summary row per Vault for ADR-0006-governed contents — not per secret.
- **D3** — Tracking surface is GitHub issues with due dates in `HoneyDrunk.Architecture`, labeled `external-credential-rotation`, titled `[Rotate] {credential-name} — expires {YYYY-MM-DD}`. **Not** calendar reminders. Closed on rotation, new issue opened immediately. Non-rotating entries get no standing issue. ADR-0084's Discord-alerts amendment composes on top of this surface once ADR-0084 lands; this ADR does not preempt that.
- **D4** — Per-provider rotation walkthroughs live under `infrastructure/walkthroughs/{provider-or-credential}-rotation.md`. Three mandatory first-wave walkthroughs unblocked by acceptance: `sonarcloud-token-rotation.md`, `nuget-api-key-rotation.md`, `github-pat-rotation.md`. Non-rotating entries get no walkthrough.
- **D5** — Scheduled drift-detection workflow `HoneyDrunk.Actions/.github/workflows/external-credentials-check.yml` (cron: daily 09:00 ET) parses the inventory, filters by `Rotates: yes`, computes days-to-expiry against `TimeProvider.GetUtcNow()` per ADR-0063, escalates at T-30 / T-7 / T+0 (SEV-2 incident per ADR-0054).
- **D6** — Onboarding hook: the standup procedure per ADR-0082 D5 gains a credential-onboarding step. The inventory row exists **before** the artifact enters any CI surface. Procedural enforcement is the `review` agent per ADR-0044 D3 rubric category 9 (Security).
- **D7** — One new invariant binds the discipline: every credential, identifier, or load-bearing identity binding the Grid holds has an inventory row; rotation-needing items additionally carry a walkthrough and standing tracking issue. The number is **103**, pre-assigned in `constitution/invariant-reservations.md` alongside ADR-0082's 102 by the refine pass.

ADR-0083 is a **process / governance** ADR. The concrete artifacts — the inventory file, the three walkthroughs, the Actions workflow, the standing issues, the standup-document amendment, the Vault.Rotation overview cross-link, the vendor-inventory cross-link — land in packets 01–07. Every other packet in this initiative references ADR-0083's D-decisions as live rules, so the acceptance flip must land first.

This is a docs/governance-only packet. No code, no workflow, no .NET project.

## Scope
- `adrs/ADR-0083-external-saas-credential-rotation.md` — flip `**Status:** Proposed` to `**Status:** Accepted`.
- `adrs/README.md` — add or update the ADR-0083 row in the index table. If a row already exists, update its Status column to Accepted. If no row exists, append one in the existing table format, citing the Sector (`Infrastructure / cross-cutting`), Date (`2026-05-25`), and a one-sentence impact summary.
- `constitution/invariants.md` — add the new sensitive-inventory invariant under a new `## Sensitive Inventory Invariants` section (or appended to the existing tail section), numbered **103** (pre-assigned per the registry).
- `constitution/invariant-reservations.md` — **no edit needed in this packet for the reservation row** (the row claiming 103 for ADR-0083 was pre-assigned alongside ADR-0082's 102 by the refine pass). Optionally mark the row's Status as `Proposed → Accepted` if the registry's convention tracks acceptance status there.
- `initiatives/active-initiatives.md` — register the `adr-0083-external-saas-credentials` initiative with the packet checklist for this folder.

## Proposed Implementation
1. Edit the ADR-0083 header: `**Status:** Proposed` → `**Status:** Accepted`. No other D-decision text changes in this packet.
2. Update the ADR-0083 index row in `adrs/README.md`. Match the existing six-column format (`| ADR-XXXX | Title | Status | Date | Sector | Impact |`). Append the row directly to keep the index consistent with `hive-sync` expectations.
3. **Confirm the pre-assigned invariant slot.** Open `constitution/invariant-reservations.md` and verify the row claiming **103** for ADR-0083 already exists in the **Active Reservations** table (the refine pass pre-assigned 102 to ADR-0082 and 103 to ADR-0083 to avoid the placeholder race; both rows live in the registry). Optionally mark the ADR-0083 row's Status as `Proposed → Accepted`. No upward-shift contingency — the slot is fixed at 103.
4. Add the new invariant to `constitution/invariants.md`, numbered **103** per step 3. The text, taken from ADR-0083 D7 verbatim in substance:

   > **103 — Every credential, identifier, secret, or load-bearing identity binding the Grid holds — including but not limited to GitHub Personal Access Tokens, GitHub App IDs and private keys, SonarCloud tokens, NuGet API keys, Azure subscription and tenant IDs, OIDC federated-credential configurations, webhook signing secrets, Discord webhook URLs, Stripe / Resend / Twilio API keys, resource identifiers (Key Vault names, Container Apps environments, Service Bus namespaces), and any provider-issued artifact whose loss, exposure, or expiration would cost the Grid recovery time — must have a row in `infrastructure/reference/sensitive-inventory.md` with the columns specified in ADR-0083 D2, including `Kind`, `Use Cases`, and `Rotates`.**
   >
   > **Additionally, for inventory rows with `Rotates: yes`**, the row must also carry: (1) a `Current Expiration` date no later than the provider's enforced maximum; (2) a per-provider rotation walkthrough at `infrastructure/walkthroughs/{provider-or-credential}-rotation.md` linked from the `Rotation Procedure` column; and (3) an open GitHub issue in `HoneyDrunk.Architecture` labeled `external-credential-rotation` with the credential name and current expiration date in its title.
   >
   > Artifacts whose rotation lifecycle is fully managed by `HoneyDrunk.Vault.Rotation` (ADR-0006 Tier 2 — runtime workload secrets resolved through `ISecretStore`) carry `Rotates: automated-elsewhere (ADR-0006)`; the inventory row remains required, but the rotation-discipline triplet (walkthrough, standing issue, escalation) is out of scope of this invariant for those rows — they are governed by Invariant 20.
   >
   > Non-rotating identifiers (`Rotates: no`) — non-expiring IDs, OIDC subject patterns, resource identifiers, Discord webhook URLs and similar — require **only** the inventory row, no walkthrough and no standing issue.
   >
   > Enforcement: human review at PR time, supplemented by the `review` agent per ADR-0044 D3 category 9 (Security). The scheduled `external-credentials-check.yml` workflow per ADR-0083 D5 catches `Rotates: yes` rows whose expiration has lapsed without an updated value, and surfaces them as SEV-2 incidents per ADR-0054. The `node-audit` agent surfaces missing rows of any `Kind` on its periodic pass.

   Create a new `## Sensitive Inventory Invariants` section after the existing tail section (currently `## Audit Invariants`), or place it immediately after the existing Secrets/Vault block if structural grouping favors that — but do not interleave with unrelated sections.
5. Register the initiative in `initiatives/active-initiatives.md` with the wave structure and packet checklist for this folder. Match the format used by ADR-0042, ADR-0045, ADR-0077, ADR-0080 sibling ADR-acceptance initiative entries.

## Affected Files
- `adrs/ADR-0083-external-saas-credential-rotation.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`

## NuGet Dependencies
None. This packet touches only Markdown governance files; no .NET project is created or modified.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule "architecture, ADR, invariant, sector, catalog, routing → HoneyDrunk.Architecture" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency — sensitive-inventory discipline is governance, not contract.

## Acceptance Criteria
- [ ] ADR-0083 header reads `**Status:** Accepted`
- [ ] An ADR-0083 row exists in `adrs/README.md` with Status `Accepted`, Date `2026-05-25`, Sector `Infrastructure / cross-cutting`, and a one-sentence impact summary in the existing row format
- [ ] `constitution/invariant-reservations.md` carries an `Active Reservations` row claiming a contiguous block of size 1 for ADR-0083 above the highest existing reservation (expected: `102`, but the load-bearing claim lives in the registry), with `(N1)` summary and the packet 00 path
- [ ] `constitution/invariants.md` carries the new sensitive-inventory invariant numbered **103** (pre-assigned in `invariant-reservations.md`), under a new `## Sensitive Inventory Invariants` section (or contiguous with the existing Secrets section if structural grouping favors that), citing ADR-0083
- [ ] Invariant **103** is a single numbered clause with the four bound parts (membership rule, rotation-discipline triplet, automated-elsewhere carve-out, non-rotating-id carve-out, enforcement) — **not** split into multiple numbered invariants
- [ ] `initiatives/active-initiatives.md` registers the `adr-0083-external-saas-credentials` initiative with a packet checklist matching the structure used by sibling initiative entries (ADR-0077, ADR-0080)
- [ ] Repo-level `CHANGELOG.md` carries a dated entry for the ADR-0083 acceptance, matching the convention used by prior ADR-acceptance packets (ADR-0042/0045/0077/0080)
- [ ] No `infrastructure/reference/sensitive-inventory.md` creation in this packet (that lands in packet 01)
- [ ] No `infrastructure/walkthroughs/*-rotation.md` creation in this packet (those land in packets 02/03/04)
- [ ] No `HoneyDrunk.Actions` edits in this packet (that lands in packet 05)
- [ ] No catalog schema change (no `catalogs/*.json` edit)

## Human Prerequisites
None.

## Referenced ADR Decisions
**ADR-0083 D1 — Vault.Rotation does not expand.** External-SaaS PATs stay manual indefinitely. Re-evaluation trigger: active rotation-needing-credential count exceeds ten, or a single high-blast-radius credential rotates more than every 30 days. The cost discipline is per-provider rotation API engineering scaling with provider count, against fewer than ten total credentials.

**ADR-0083 D2 — Inventory file at `infrastructure/reference/sensitive-inventory.md`.** Grid-wide single-file Markdown table; record shape per the D2 table. JSON alternative rejected because consumers are humans, not tooling. Per-Node split rejected because items don't partition by Node.

**ADR-0083 D3 — Tracking surface is GitHub issues.** Standing issue per rotation-needing credential, labeled `external-credential-rotation`, titled `[Rotate] {credential-name} — expires {YYYY-MM-DD}`. Closed on rotation, new issue opened. Non-rotating entries get no standing issue. ADR-0084 will add Discord alerts as the escalation surface; this ADR does not preempt that.

**ADR-0083 D4 — Walkthroughs at `infrastructure/walkthroughs/`.** One per rotation-needing provider. Three first-wave: SonarCloud, NuGet, GitHub PATs. Non-rotating entries get no walkthrough.

**ADR-0083 D5 — `external-credentials-check.yml`.** Scheduled drift-detection workflow in HoneyDrunk.Actions, filters by `Rotates: yes`, escalates T-30 / T-7 / T+0. Drift-detection only; does not call provider APIs.

**ADR-0083 D6 — Onboarding hook.** ADR-0082 D5's standup-procedure document gains a sensitive-inventory step. Inventory row exists before the artifact enters any CI surface.

**ADR-0083 D7 — One new invariant.** Single clause with two bound parts: broader inventory-membership rule (everything the Grid holds) and narrower rotation-discipline rule (rotation-needing subset). Complements, does not replace, invariant 20.

**Invariants 8, 20 (referenced by invariant 103).** Invariant 8 ("Secret values never appear in logs, traces, exceptions, or telemetry") is fully preserved — the inventory carries credential names and expiration dates, never values. Invariant 20 ("No secret may exceed its tier's rotation SLA without an active exception") binds Vault-stored secrets; invariant 103 binds the inventory-and-tracking discipline for credentials outside the Vault, plus non-rotating identifiers and load-bearing identity bindings. Together they cover the full surface; neither upstream invariant is modified.

## Constraints
- **Acceptance precedes flip.** ADR-0083 stays Proposed until this packet's PR merges. Do not flip the ADR in any other packet.
- **Invariant number 103 is pre-assigned in the reservation registry.** The row claiming 103 for ADR-0083 already exists in `constitution/invariant-reservations.md` (paired with ADR-0082's 102 by the refine pass). This packet writes the invariant text into `constitution/invariants.md` referencing 103 directly. **No "first merge wins" contingency** between ADR-0082 and ADR-0083 — both slots are fixed. Never reuse a number already claimed by another sibling reservation.
- **One invariant, not two or three.** ADR-0083 D7 commits a single numbered invariant with multiple bound clauses. Do not split into N1/N2/N3 for "inventory rule," "rotation rule," and "enforcement rule" — that violates the ADR's design. Block size in the reservation registry is 1 (one slot at 103).
- **Invariant 103 text preserves Invariant 8's full force.** The inventory carries names and expiration dates only — never values. The invariant text must not relax Invariant 8 in any way and must not introduce any new exception to Invariant 9 ("Vault is the only source of secrets") — external-SaaS PATs were never in Vault's scope to begin with (per D1 and ADR-0005's gap), so the new invariant does not contradict invariant 9 but does broaden the surface invariant 9 covers vs. what 103 covers.
- **Section placement.** Create `## Sensitive Inventory Invariants` as a new section in `constitution/invariants.md`. Place it after the existing tail section, or contiguous with the existing Secrets/Vault block (after invariant 22 if structurally helpful). Do **not** interleave with unrelated sections.
- **No content beyond acceptance in this packet.** The inventory file, the walkthroughs, the Actions workflow, the standing issues, the standup-document amendment, and the cross-links all live in subsequent packets per the dispatch plan. This packet is the governance/invariants flip only.
- **Match the existing `adrs/README.md` row format.** The repo's ADR index uses a six-column markdown table (`| ID | Title | Status | Date | Sector | Impact |`). Append the ADR-0083 row in that format. Do not invent a new column or alter the table header.

## Labels
`chore`, `tier-3`, `meta`, `docs`, `adr-0083`, `wave-1`

## Agent Handoff

**Objective:** Flip ADR-0083 to Accepted, add the unified sensitive-inventory invariant to `constitution/invariants.md`, and register the external-SaaS-credentials initiative.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Land ADR-0083 so packets 01–07 can reference its decisions as live rules and start shipping the inventory file, walkthroughs, scheduled workflow, standing issues, and cross-links.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 1.
- ADRs: ADR-0083 (primary), invariants 8 and 20 (referenced by invariant 103), ADR-0005 (the env-var Vault bootstrap that does not cover GitHub org secrets), ADR-0006 (Vault.Rotation Tier 2 scope this ADR explicitly does not expand), ADR-0008 (initiative/packet conventions), ADR-0014 (ADR-acceptance reconciliation pattern that `hive-sync` follows).

**Acceptance Criteria:** As listed above.

**Dependencies:** None.

**Constraints:**
- Acceptance precedes flip — ADR-0083 stays Proposed until this PR merges.
- Invariant 103 is pre-assigned in `constitution/invariant-reservations.md` (paired with ADR-0082's 102 by the refine pass); write it directly into `constitution/invariants.md`. No upward-shift contingency.
- One invariant only, not two or three — block size = 1 in the reservation registry. Single numbered clause with bound parts.
- Invariant 103 text preserves Invariant 8's full force (names and expiration dates only; never values) and does not modify invariants 9 or 20.
- Create a new `## Sensitive Inventory Invariants` section in `constitution/invariants.md`. Do not interleave with unrelated sections.
- No inventory file, walkthrough, workflow, standing issue, or cross-link creation in this packet — all deferred to packets 01–07.
- Match the existing `adrs/README.md` six-column row format.

**Key Files:**
- `adrs/ADR-0083-external-saas-credential-rotation.md`
- `adrs/README.md`
- `constitution/invariants.md`
- `constitution/invariant-reservations.md`
- `initiatives/active-initiatives.md`
- `CHANGELOG.md`

**Contracts:** None changed.

**PR Body Metadata:**
- `Authorship: agent`
- `Packet: generated/issue-packets/proposed/adr-0083-external-saas-credentials/00-architecture-adr-0083-acceptance.md`
