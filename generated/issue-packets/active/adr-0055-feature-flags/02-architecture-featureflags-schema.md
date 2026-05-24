---
name: Repo Feature
type: repo-feature
tier: 2
target_repo: HoneyDrunkStudios/HoneyDrunk.Architecture
labels: ["feature", "tier-2", "core", "docs", "adr-0055", "wave-1"]
dependencies: ["packet:00"]
adrs: ["ADR-0055"]
accepts: ["ADR-0055"]
wave: 1
initiative: adr-0055-feature-flags
node: honeydrunk-architecture
---

# Author the featureflags-v1.json schema for per-Node featureflags.json registries

## Summary
Author the JSON Schema document `featureflags-v1.json` defining the shape of every Node's `featureflags.json` registry per ADR-0055 D6. The schema lives in the Architecture repo at `schemas/featureflags-v1.json`, is published at the canonical URL `https://schemas.honeydrunkstudios.com/featureflags-v1.json` (Studios site publishes schemas/ to that hostname per the existing schema-publishing pattern), and is the single source of truth that the CI validation workflow (packet 06) and the Roslyn analyzer (packet 06) parse against.

## Context
ADR-0055 D6 commits to a per-Node `featureflags.json` registry, cited inline in the ADR as:
```json
{
  "$schema": "https://schemas.honeydrunkstudios.com/featureflags-v1.json",
  "flags": [
    {
      "name": "release.notify.bulk-send",
      "category": "release",
      "description": "Bulk-send feature for Notify; ships in 0.4.0",
      "owner": "HoneyDrunk.Notify",
      "created": "2026-05-22",
      "expires_on": "2026-08-20",
      "expected_orphan": false
    }
  ]
}
```

The schema URL is **named in the ADR** but the schema document does not yet exist. Until it does, every consuming Node's `featureflags.json` carries a `$schema` reference to a 404 URL, and the CI validation workflow (packet 06) has nothing concrete to validate against. This packet fixes both by authoring the schema and pinning it for publication.

The schema must cover every field ADR-0055 D6 names, including the optional/conditional ones:
- **Required on every flag:** `name`, `category`, `description`, `owner`.
- **Required by category:**
  - `category: release` requires `expires_on` (a date) and `created` (a date). Per ADR-0055 D7, default expiry is 90 days from creation; the schema enforces the *presence* of `expires_on`, not the 90-day default — the default is the operator workflow at flag creation.
  - `category: permission` requires `annual_review_due` (a date); `expires_on` must be `null` or omitted (permission flags do not expire per D7).
  - `category: operational` requires `annual_review_due` (a date); `expires_on` must be `null` or omitted (operational flags do not expire per D7).
- **Optional on every flag:** `expected_orphan` (boolean, default `false`), `hotpath` (boolean, default `false`; controls the D10 1% sampling), `tags` (array of strings).
- **Variant flags:** if the flag is a variant flag (consumed via `GetVariantAsync<T>` per D4), the entry declares `variants` (an array of `{ name, value }` objects). For binary flags, `variants` is omitted.

The schema also constrains the file-root shape: `$schema` is a URL pointing to this document; `flags` is a non-empty array of flag entries.

Studios site publishes `schemas/` at `https://schemas.honeydrunkstudios.com/` per the existing schema-publishing pattern. Confirm at edit time that this routing is configured; if it is not, the schema is still authored at `schemas/featureflags-v1.json` in the Architecture repo and the consumers (packet 06's validation workflow and analyzer) resolve it against the file path until Studios serves it. The ADR's URL is the **intent**; the actual served URL is a deployment detail that does not block this packet's authoring.

This is a docs/schema packet. No code, no .NET project.

## Scope
- `schemas/featureflags-v1.json` (new) — the JSON Schema document.
- `docs/feature-flags-registry-format.md` (new) — a human-readable guide to authoring `featureflags.json`, with worked examples for each category (`release`, `permission`, `operational`), the variant case, and the `expected_orphan` and `hotpath` markings. This lives alongside the schema so consumers reading the schema have prose to read.
- Optionally, a stub README entry under `schemas/README.md` if that file exists.

## Proposed Implementation
1. **`schemas/featureflags-v1.json`** — author a JSON Schema 2020-12 document (or whichever draft the existing schema files in the repo target — match at edit time). Top-level shape:
   - `$schema`: `"https://json-schema.org/draft/2020-12/schema"`.
   - `$id`: `"https://schemas.honeydrunkstudios.com/featureflags-v1.json"`.
   - `title`: `"HoneyDrunk Feature-Flags Registry v1"`.
   - `description`: A one-paragraph description citing ADR-0055 D6 as the source.
   - `type: "object"`, required `["$schema", "flags"]`.
   - `properties.$schema`: a URL constant pointing at this document.
   - `properties.flags`: `type: "array"`, `minItems: 1`, `items: { $ref: "#/$defs/flag" }`.
2. **`$defs.flag`** — the per-flag entry shape. Use `oneOf` over the three categories so the conditional required fields are enforced:
   - **Common required fields** (in each `oneOf` branch): `name` (string, pattern `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$` per D5), `category` (enum, one of `release` / `permission` / `operational`), `description` (non-empty string), `owner` (string, matches `HoneyDrunk.<Node>`), `created` (date).
   - **`release` branch**: requires `expires_on` (date); allows `expected_orphan`, `hotpath`, `tags`, `variants`.
   - **`permission` branch**: requires `annual_review_due` (date); forbids non-null `expires_on` (set `expires_on` to `null` or omit); allows `expected_orphan`, `hotpath`, `tags`, `variants`.
   - **`operational` branch**: requires `annual_review_due` (date); forbids non-null `expires_on`; allows `expected_orphan`, `hotpath`, `tags`, `variants`.
3. **`$defs.variant`** — shape for a single variant: `{ name: string, value: string|number|boolean|object }`. Variants are optional; presence makes the flag a variant flag.
4. **Field semantics in the schema description text** (for human/agent readers, not enforced by JSON Schema):
   - `expected_orphan: true` documents that the flag is intentionally consumed only by configuration paths (e.g., the operator dashboard's flag-list view), so the "every registered flag is used in code" CI rule (packet 06 D6 enforcement) does not false-positive on it.
   - `hotpath: true` opts the flag into the 1% sampling of `feature_flag_evaluated` log emission per ADR-0055 D10. Default is 100% logging.
   - `tags` is a free-form array for additional metadata (e.g., links to PRs, ownership detail). Not validated by CI.
5. **`docs/feature-flags-registry-format.md`** — human-readable guide. Cover:
   - The three categories and their lifecycle policies (D1, D7).
   - Worked example for each: a release flag (`release.notify.bulk-send`), a permission flag (`permission.lately.video-posts`), an operational flag (`operational.pulse.collector-emit-disable`).
   - The variant case — a release flag with three variants (`baseline`, `v2`, `v3`).
   - The `expected_orphan` escape hatch.
   - The `hotpath` marking and its observability consequence (D10).
   - The naming convention (D5) and how it composes with the schema regex.
   - The CI gates packet 06 will enforce (every used flag registered; every registered flag used or `expected_orphan`; expiry on release; naming/category coherence).
6. **Schema URL publication.** Confirm that `https://schemas.honeydrunkstudios.com/` serves the Architecture repo's `schemas/` directory. If it does, no further action — the file at `schemas/featureflags-v1.json` will be reachable. If it does not, document the gap in the doc with a note that consumers will pin against the in-repo path until publication is wired (this is a Studios-site concern, not a packet 02 concern; file as a separate task only if the publication path is not yet configured).

## Affected Files
- `schemas/featureflags-v1.json` (new)
- `docs/feature-flags-registry-format.md` (new)
- `schemas/README.md` (if it exists, add a one-line entry for the new schema)

## NuGet Dependencies
None. This packet authors JSON and Markdown; no .NET project is created or modified.

## Boundary Check
- [x] Schema and docs live in `HoneyDrunk.Architecture`. The schema is the cross-Node contract for `featureflags.json`; Architecture is the right home.
- [x] No code change in any other repo.
- [x] The schema URL is a Studios-site serving concern, not a code change in Studios.

## Acceptance Criteria
- [ ] `schemas/featureflags-v1.json` exists as a valid JSON Schema 2020-12 (or matching the existing schema draft used in the repo) document
- [ ] The schema's `$id` is `https://schemas.honeydrunkstudios.com/featureflags-v1.json`
- [ ] The schema enforces the flag-name regex `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$` per ADR-0055 D5
- [ ] The schema uses `oneOf` over the three categories such that `release` requires `expires_on`, `permission` requires `annual_review_due` (and forbids non-null `expires_on`), `operational` requires `annual_review_due` (and forbids non-null `expires_on`)
- [ ] The schema covers optional fields: `expected_orphan` (bool, default false), `hotpath` (bool, default false), `tags` (array of strings), `variants` (array of `{name, value}`)
- [ ] The schema validates an example `featureflags.json` matching the ADR-0055 D6 inline example
- [ ] `docs/feature-flags-registry-format.md` is a human-readable guide covering all three categories, the variant case, `expected_orphan`, `hotpath`, the naming convention, and the CI gates
- [ ] No invariant change in this packet (invariants land in packet 00)
- [ ] If `schemas/README.md` exists, it lists the new schema with a one-line description

## Human Prerequisites
- [ ] Confirm that `https://schemas.honeydrunkstudios.com/` serves the Architecture repo's `schemas/` directory (the existing schema-publishing routing). If it does not, file a separate Studios-site task — packet 06's CI validation workflow and analyzer can pin to the in-repo path until the public URL is live; this packet still ships the schema file. The ADR-cited URL is the *intent*, and the schema authoring is not blocked.

## Referenced ADR Decisions
**ADR-0055 D6 — Per-Node `featureflags.json` with CI validation.** Each Node declares its flags at `src/HoneyDrunk.<Node>/featureflags.json`. The file references this schema via `$schema`. CI enforces every-flag-used-is-registered, every-registered-flag-used-or-expected-orphan, naming convention, category coherence, release-flag expiry, permission/operational annual-review-due.

**ADR-0055 D5 — Naming `{category}.{node}.{feature}`.** Three dot-separated segments. Schema regex: `^(release|permission|operational)\.[a-z0-9]+\.[a-z0-9-]+$`.

**ADR-0055 D7 — Flag expiry.** Release flags require `expires_on`; permission/operational require `annual_review_due` (do not expire). Default at creation for release: 90 days from creation (operator workflow, not schema-enforced).

**ADR-0055 D10 — `hotpath: true` marking.** Hotpath flags sample evaluation logging at 1%; the default is 100% logging. The schema carries the marking; packet 06's runtime and emit pipeline respect it.

## Constraints
- **Schema must be valid against the JSON Schema draft used by the repo.** Check the existing schemas under `schemas/` at edit time and match the draft (likely 2020-12 or 2019-09).
- **The `$schema` field in the schema document itself** points at the JSON Schema meta-schema; the **`$id`** is the document's own canonical URL (`https://schemas.honeydrunkstudios.com/featureflags-v1.json`).
- **Don't enforce the 90-day default in the schema.** Per ADR-0055 D7, 90 days is the *operator workflow default at creation*. The schema enforces presence of `expires_on`; the CI workflow in packet 06 checks the value against today's date. The 90-day default is the human/tooling layer.
- **`expected_orphan` escape hatch.** Critical for operator-only flags consumed only by the dashboard's flag-list view; without it, every operator-only flag false-positives the dual-validation check. Document this clearly.

## Labels
`feature`, `tier-2`, `core`, `docs`, `adr-0055`, `wave-1`

## Agent Handoff

**Objective:** Author the `featureflags-v1.json` JSON Schema and the human-readable registry-format guide.

**Target:** `HoneyDrunk.Architecture`, branch from `main`.

**Context:**
- Goal: Pin the schema that every consuming Node's `featureflags.json` references, and that packet 06's CI workflow + Roslyn analyzer validate against.
- Feature: ADR-0055 Feature Flag rollout, Wave 1.
- ADRs: ADR-0055 D5/D6/D7/D10 (primary).

**Acceptance Criteria:** As listed above.

**Dependencies:**
- `packet:00` — ADR-0055 should be Accepted before the schema it pins lands.

**Constraints:**
- Match the JSON Schema draft used by the repo's existing schemas.
- `$id` is the canonical URL; `$schema` is the meta-schema.
- The schema enforces structure, not the 90-day expiry default (operator-workflow concern).
- `expected_orphan` is essential — escape hatch for operator-only flags.

**Key Files:**
- `schemas/featureflags-v1.json` (new)
- `docs/feature-flags-registry-format.md` (new)
- `schemas/README.md` (if it exists)

**Contracts:** None — the schema *is* the contract for `featureflags.json` files; this packet ships it.
