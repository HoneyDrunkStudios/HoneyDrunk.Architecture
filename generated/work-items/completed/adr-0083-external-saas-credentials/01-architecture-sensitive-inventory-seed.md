---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "meta", "docs", "adr-0083", "wave-2"]
dependencies: ["work-item:00"]
adrs: ["ADR-0083"]
wave: 2
initiative: adr-0083-external-saas-credentials
node: honeydrunk-architecture
---

# Seed `infrastructure/reference/sensitive-inventory.md` with 15 live/imminent rows + seed 3 new repo labels

## Summary
Create the new `infrastructure/reference/sensitive-inventory.md` file per ADR-0083 D2 with the 15 live/imminent seed rows enumerated in ADR-0083 §Follow-up Work, and seed three new GitHub repo labels (`external-credential-rotation`, `urgent`, `imminent`) in `HoneyDrunk.Architecture` via the existing label-setup pattern. This packet is the **foundation** for Wave 2 walkthroughs (02/03/04), the Wave 3 standing-issue creation (06), and the Actions drift-detection workflow (05) — all of which depend on this file existing.

## Context
ADR-0083 D2 commits the canonical inventory location at `infrastructure/reference/sensitive-inventory.md`, sibling to the existing reference documents (`vendor-inventory.md`, `azure-resource-inventory.md`, `deployment-map.md`, `owned-domains.md`, `tech-stack.md`). The file does not yet exist.

The inventory is **the canonical index of every credential, identifier, secret, and identity binding the Grid holds**. Values continue to live in their authoritative location — GitHub organization secrets for CI-shaped credentials, Azure Key Vault for runtime workload secrets governed by ADR-0006, environment configuration for non-rotating IDs, IaC for resource identifiers. The inventory is the **index** that makes the existence of each artifact discoverable; it never duplicates values.

Per ADR-0083 §Follow-up Work, the seed split is **live/imminent** (lands at acceptance, this packet) vs **planned** (lands with the consuming ADR's acceptance — Discord rows land with ADR-0084, Notify-Cloud commercial rows land with PDR-0002). Total seed-row count at ADR-0083 acceptance: **15 rows**.

This packet also seeds three new labels on `HoneyDrunk.Architecture` required by D3 (`external-credential-rotation`) and D5 (`urgent`, `imminent`). The labels are applied to standing rotation issues by packet 06 and by the scheduled `external-credentials-check.yml` workflow per D5.

This is a docs/governance + repo-config packet. No code, no .NET project.

## Scope
- Create file `infrastructure/reference/sensitive-inventory.md` with the 15 seed rows enumerated below.
- Seed three new labels (`external-credential-rotation`, `urgent`, `imminent`) in the `HoneyDrunk.Architecture` repo via the existing label-setup pattern (the seed lives in `.github/labels.yml` if that convention is in use; otherwise via the `seed-labels.yml` workflow's input set — match what the repo already does).

## Proposed Implementation

### 1. Create `infrastructure/reference/sensitive-inventory.md`

Header section (above the table):

```markdown
# Sensitive Inventory

**Purpose:** The canonical index of every credential, identifier, secret, and identity binding the Grid holds. Per ADR-0083 D2.

**Scope:** Names and metadata only — never values. Per Invariant 8 (secrets never appear in logs/traces) and the new invariant 103 per ADR-0083 D7.

**Maintenance:**
- New entries land via the standup-procedure onboarding hook per ADR-0083 D6 and ADR-0082.
- Existing entries' `Current Expiration` updates land at rotation time per the relevant walkthrough under `infrastructure/walkthroughs/`.
- The scheduled `external-credentials-check.yml` workflow per ADR-0083 D5 parses this file and escalates at T-30 / T-7 / T+0.
- Schema integrity is enforced by `external-credentials-check.yml`'s schema-check sub-step — table-format drift fails the workflow fast.

**Cross-references:**
- `infrastructure/reference/vendor-inventory.md` — product-level vendor inventory; per-vendor cross-link to artifacts here.
- `ADR-0006` — Vault.Rotation Tier 1/2 SLA for Azure-Key-Vault-stored secrets (rows here with `Rotates: automated-elsewhere (ADR-0006)`).
- `ADR-0083` — this inventory's governing ADR.
```

Table — use the D2 column set exactly. Substitute the **actual current expiration** for the SonarCloud, NuGet, GitHub PAT, and webhook-secret rows by inspecting the GitHub org secret metadata at PR-author time. If the agent cannot read GitHub org secret metadata, the agent writes a **provisional ISO 8601 date** (computed as `today + provider-cap-days` — e.g., `today + 60` for SonarCloud, `today + 365` for NuGet, `today + 366` for fine-grained GitHub PATs) and flags the row in `## Human Prerequisites` as "provisional — operator corrects on first rotation." **Every `Rotates: yes` row carries a real ISO 8601 `YYYY-MM-DD` date.** The placeholder string `TBD — operator to fill at first rotation` is forbidden because packet 05's parser (`inventory-evaluate.py`) expects strict ISO 8601 and would fail fast on non-date text. The provisional date is a known-stale guess that the operator corrects at first rotation; it is never a placeholder string.

The 15 seed rows (per ADR-0083 §Follow-up Work — live/imminent set):

| # | Name | Kind | Provider | Rotates | Notes |
|---|------|------|----------|---------|-------|
| 1 | `SONAR_TOKEN` | `external-saas-pat` | SonarCloud | `yes` | 60-day cap (free tier) |
| 2 | `NUGET_API_KEY` | `external-saas-api-key` | NuGet.org | `yes` | 365-day cap |
| 3 | `GH_ISSUE_TOKEN` | `external-saas-pat` | GitHub | `yes` | fine-grained PAT |
| 4 | `HIVE_APP_ID` | `non-rotating-id` | GitHub | `no` | GitHub App ID per ADR-0014 |
| 5 | `HIVE_APP_PRIVATE_KEY` | `github-app-credential` | GitHub | `no` | rotate-on-compromise only |
| 6 | `HIVE_FIELD_MIRROR_TOKEN` | `external-saas-pat` | GitHub | `yes` | live PAT fallback for `hive-field-mirror.yml` |
| 7 | `LABELS_FANOUT_PAT` | `external-saas-pat` | GitHub | `yes` | live PAT for `seed-labels-fanout.yml` |
| 8 | `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` | `webhook-signing-secret` | OpenClaw bridge | `yes` | per ADR-0044 D2 |
| 9 | `AZURE_TENANT_ID` | `non-rotating-id` | Azure | `no` | used across every Azure-touching workflow |
| 10 | `AZURE_SUBSCRIPTION_ID` | `non-rotating-id` | Azure | `no` | used across every Azure-touching workflow |
| 11 | OIDC federated-credential configurations (per repo) | `oidc-federated-credential` | Azure | `no` | one summary row; subject-pattern doc per repo |
| 12 | Application Insights connection strings | `connection-string` | Azure | `no` | instrumentation-key revocation is the security path |
| 13 | Azure Key Vault contents (summary) | `azure-key-vault-secret` | Azure | `automated-elsewhere (ADR-0006)` | single summary row; see ADR-0006 |
| 14 | `ANTHROPIC_API_KEY` | `external-saas-api-key` | Anthropic | `yes` | planned — declared input to `agent-run.yml`, not yet live |
| 15 | `OPENAI_API_KEY` | `external-saas-api-key` | OpenAI | `yes` | planned — declared input to `agent-run.yml`, not yet live |

For each row, populate the D2-mandated columns: `Name`, `Kind`, `Provider`, `Where Stored`, `Bound To`, `Rotates`, `Expiration Cadence` (optional but populate where known), `Current Expiration` (optional; required for `Rotates: yes` rows; `n/a` for `Rotates: no` and `automated-elsewhere`), `Rotation Procedure` (relative link under `infrastructure/walkthroughs/` for `Rotates: yes` rows that have a walkthrough — for the SonarCloud, NuGet, and GitHub-PAT rows the link points at the file packets 02/03/04 land; for `Rotates: no` and `automated-elsewhere` rows the cell is `n/a`), `Use Cases` (bulleted), `Blast Radius if Missed`, `Owner` (today: solo-dev — use the operator's GitHub handle / name), `Notes` (optional; carries the "60-day cap on free tier," `status: planned`, "instrumentation-key revocation is the security path," etc. content called out in ADR-0083 §Follow-up Work).

**Column placement note.** Use a Markdown table. Because some cells (Use Cases especially) contain bulleted lists, use inline `<br>`-separated bullets or HTML `<ul><li>` blocks inside the cell — the schema-check sub-step in `external-credentials-check.yml` (per D5, lands in packet 05) must be able to parse the table reliably. Establish the format here; packet 05's parser is built against this format.

### 2. Seed three new labels on `HoneyDrunk.Architecture`

Per ADR-0083 §Follow-up Work and D3 / D5. Add to the repo's label-seed convention (today: `.github/labels.yml` consumed by `seed-labels.yml` per the `HoneyDrunk.Actions` workflow set, or whichever pattern the repo already uses for label management — match the existing convention; do not invent a new one).

- **`external-credential-rotation`** — color: a distinct color from existing `*-rotation` labels (suggested: `#D93F0B` orange-red), description: "Standing rotation issue for an external-SaaS credential per ADR-0083 D3."
- **`urgent`** — color: a high-attention red (suggested: `#B60205`), description: "Expiration within 30 days per ADR-0083 D5."
- **`imminent`** — color: an even-higher-attention red (suggested: `#9B0000`), description: "Expiration within 7 days per ADR-0083 D5."

If `urgent` already exists as a generic label in the repo, do not redefine it; reuse the existing label. Verify before adding. (The label-seed convention typically no-ops on existing labels with the same name; confirm against the actual workflow.)

## Affected Files
- `infrastructure/reference/sensitive-inventory.md` (new)
- `.github/labels.yml` (or whichever label-seed file the repo uses)
- `CHANGELOG.md` — append to the in-progress entry from packet 00 (do not bump version; this is governance content)

## NuGet Dependencies
None.

## Boundary Check
- [x] All edits in `HoneyDrunk.Architecture`. Routing rule for "architecture, ADR, invariant, sector, catalog, routing" maps exactly.
- [x] No code change in any other repo.
- [x] No new cross-Node runtime dependency.
- [x] Per Invariant 8 ("Secret values never appear in logs, traces, exceptions, or telemetry"), the inventory file carries credential **names** and **expiration dates** only, never values. This is preserved.

## Acceptance Criteria
- [ ] `infrastructure/reference/sensitive-inventory.md` exists with the header section and a 15-row table covering the live/imminent set per ADR-0083 §Follow-up Work
- [ ] Every row carries all D2-mandated columns: `Name`, `Kind`, `Provider`, `Where Stored`, `Bound To`, `Rotates`, `Use Cases`, `Blast Radius if Missed`, `Owner`. Optional columns (`Expiration Cadence`, `Current Expiration`, `Rotation Procedure`, `Notes`) populated per the per-row guidance above
- [ ] `Rotates: yes` rows for SonarCloud, NuGet, and GitHub PATs link `Rotation Procedure` to `infrastructure/walkthroughs/sonarcloud-token-rotation.md`, `infrastructure/walkthroughs/nuget-api-key-rotation.md`, and `infrastructure/walkthroughs/github-pat-rotation.md` respectively (the files land in packets 02/03/04; the relative links may be present before the files exist — they resolve on merge of those packets)
- [ ] `Rotates: yes` rows carry a **real ISO 8601 `YYYY-MM-DD` date** in `Current Expiration`. Where the agent cannot read GitHub org secret metadata, the cell carries a **provisional ISO 8601 date** (`today + provider-cap-days`, e.g., `today + 60` for SonarCloud) flagged in `## Human Prerequisites` as "provisional — operator corrects on first rotation." The placeholder string `TBD — operator to fill at first rotation` is forbidden — packet 05's parser expects strict ISO 8601 and would fail fast on non-date text
- [ ] `Rotates: no` and `Rotates: automated-elsewhere` rows carry `n/a` in `Current Expiration`, `Expiration Cadence`, and `Rotation Procedure`
- [ ] The Azure Key Vault row is a **single summary row** (`Kind: azure-key-vault-secret`, `Rotates: automated-elsewhere (ADR-0006)`, `Use Cases` lists consumer Nodes) — not one row per Vault secret. Per ADR-0083 D2 §"One summary row, not per-secret rows"
- [ ] The OIDC federated-credential row is a **single summary row** with a link to the per-repo subject-pattern documentation — not one row per repo. Per ADR-0083 §Follow-up Work
- [ ] No row carries a secret **value** — only the secret's name and metadata (Invariant 8 preserved)
- [ ] No row from the **planned** set (`DISCORD_WEBHOOK_*`, Discord guild ID, `STRIPE_API_KEY`, `RESEND_API_KEY`, `TWILIO_API_KEY`) appears in the seed; those land with their consuming ADR's acceptance (ADR-0084, PDR-0002)
- [ ] Three new labels exist on the `HoneyDrunk.Architecture` repo: `external-credential-rotation`, `urgent`, `imminent`. If `urgent` already exists as a generic label, it is reused — not redefined
- [ ] Repo-level `CHANGELOG.md` appends to the in-progress entry from packet 00 (no new version bump; this is governance content)
- [ ] No standing rotation issues opened in this packet (those land in packet 06)
- [ ] No walkthrough files created in this packet (those land in packets 02/03/04)
- [ ] No `HoneyDrunk.Actions` edits in this packet (the scheduled workflow lands in packet 05)

## Human Prerequisites
- [ ] **Replace provisional ISO 8601 dates with the actual `Current Expiration`** for every `Rotates: yes` row where the agent wrote a `today + provider-cap-days` guess (likely all `Rotates: yes` rows — `SONAR_TOKEN`, `NUGET_API_KEY`, `GH_ISSUE_TOKEN`, `HIVE_FIELD_MIRROR_TOKEN`, `LABELS_FANOUT_PAT`, `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET`, and the two planned API keys). Source: GitHub org secrets page → individual secret → expiration metadata; for `OPENCLAW_GRID_REVIEW_WEBHOOK_SECRET` use the issuance date plus the chosen rotation cadence per ADR-0044 D2. **All values remain strict ISO 8601 `YYYY-MM-DD` at all times** — packet 05's parser requires it. The `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` rows are `status: planned` — set the provisional date to a far-future ISO date (e.g., `2099-01-01`) and mark in the `Notes` column "`status: planned`, not yet provisioned; date is a far-future sentinel that packet 05's parser treats as no-escalation."
- [ ] **Verify label colors** if the repo has a house style for label colors that differs from the suggested defaults. The suggested colors above (`#D93F0B`, `#B60205`, `#9B0000`) are a reasonable escalation gradient; the operator may override.

## Referenced ADR Decisions
**ADR-0083 D2 — Inventory location, scope, and record shape.** The file lives at `infrastructure/reference/sensitive-inventory.md`. The Grid-wide single-file Markdown table is the canonical index of every credential, identifier, secret, and identity binding the Grid holds. Names and metadata only — never values. Record shape per the D2 column table; one summary row per Vault for ADR-0006-governed contents; one summary row for OIDC federated-credential configurations.

**ADR-0083 D3 — Standing-issue label `external-credential-rotation`.** Required to exist on `HoneyDrunk.Architecture` before packet 06 can open standing rotation issues. Seeded here.

**ADR-0083 D5 — Labels `urgent` and `imminent`.** Applied by the scheduled `external-credentials-check.yml` workflow at T-30 and T-7 respectively. Seeded here.

**ADR-0083 §Follow-up Work — 15 seed rows.** The "live or imminent" set. The "planned" set defers to consuming ADRs (Discord rows with ADR-0084, Notify-Cloud commercial rows with PDR-0002).

**Invariant 8 — "Secret values never appear in logs, traces, exceptions, or telemetry."** Fully preserved by this packet. The inventory file carries names and dates only.

## Constraints
- **Never write a secret value into the file.** The inventory contains names, identifiers, and expiration dates only. This preserves invariant 8 ("Secret values never appear in logs, traces, exceptions, or telemetry") under the broader interpretation that the inventory file is operator-readable Markdown and a value committed here is the same exposure class as a value in a log.
- **Seed only the 15 live/imminent rows.** Do not pre-seed the planned set (`DISCORD_WEBHOOK_*`, Discord guild ID, `STRIPE_API_KEY`, `RESEND_API_KEY`, `TWILIO_API_KEY`). Those rows land with their consuming ADR's acceptance packet — ADR-0084 for Discord, PDR-0002 for Stripe/Resend/Twilio. Pre-seeding here would couple this initiative to those other initiatives' schedules and introduce drift.
- **One summary row for Azure Key Vault contents.** Do not enumerate per-secret rows for Vault-stored secrets — they are governed by ADR-0006, and ADR-0083 D2 explicitly carves out one summary row pointing at ADR-0006's surface.
- **One summary row for OIDC federated-credential configurations.** Per ADR-0083 §Follow-up Work: "one row summarizing the pattern with a link to the per-repo subject-pattern documentation rather than one row per repo." Do not enumerate per-repo.
- **The table format must be parseable by `external-credentials-check.yml`'s schema-check sub-step (packet 05).** Use a single Markdown table with consistent column headers. If multi-line content is needed inside a cell (e.g., bulleted `Use Cases`), use HTML `<ul><li>` blocks or `<br>`-separated bullets — do not break the row across multiple Markdown table rows. The schema-check sub-step in packet 05 will be authored against the format established here; consistency is load-bearing.
- **Do not introduce a JSON sibling file.** Per ADR-0083 D2 §Rejected alternative, the JSON form was explicitly rejected. Markdown only.
- **Match existing label-seed convention.** Inspect the repo's existing label-management mechanism (`.github/labels.yml` consumed by a workflow, or equivalent). Do not invent a new convention.

## Labels
`feature`, `tier-2`, `meta`, `docs`, `adr-0083`, `wave-2`

## Agent Handoff

**Objective:** Ship `infrastructure/reference/sensitive-inventory.md` with the 15 live/imminent seed rows per ADR-0083 D2 and §Follow-up Work, and seed the three new repo labels (`external-credential-rotation`, `urgent`, `imminent`) required by D3 and D5.

**Target:** `HoneyDrunk.Architecture`, branch from `main` after packet 00 has merged.

**Context:**
- Goal: Foundation for Wave 2 walkthroughs and Wave 3 standing issues + drift-detection workflow. Every downstream packet depends on this file existing.
- Feature: ADR-0083 Sensitive Inventory rollout, Wave 2.
- ADRs: ADR-0083 D2 (record shape), D3 (standing-issue label), D5 (urgent/imminent labels), §Follow-up Work (15-row seed set); Invariant 8 (preserve names-only); ADR-0006 (Vault contents one-summary-row carve-out).

**Acceptance Criteria:** As listed above.

**Dependencies:** Packet 00 (ADR-0083 acceptance flip and invariant landing) must have merged.

**Constraints:**
- Never write a secret value into the file. Names and dates only. Invariant 8: "Secret values never appear in logs, traces, exceptions, or telemetry" — preserved.
- Seed only the 15 live/imminent rows. Do not pre-seed the planned set.
- One summary row each for Azure Key Vault contents and OIDC federated-credential configurations.
- The Markdown table format established here is load-bearing for packet 05's parser — keep it consistent and parseable.
- No JSON sibling file. Markdown only.
- Match the existing label-seed convention; do not invent a new one.

**Key Files:**
- `infrastructure/reference/sensitive-inventory.md` (new)
- `.github/labels.yml` (or the repo's existing label-seed file)
- `CHANGELOG.md`

**Contracts:** None changed.

**PR Body Metadata:**
- `Authorship: agent`
- `Work Item: generated/work-items/proposed/adr-0083-external-saas-credentials/01-architecture-sensitive-inventory-seed.md`
