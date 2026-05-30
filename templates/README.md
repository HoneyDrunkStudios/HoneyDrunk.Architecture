# Grid templates

Canonical, version-controlled artifacts that the Grid copies or mirrors into
individual repos (or into vendor dashboards). Each template is the **single
source of truth** for its shape; the place it gets applied is downstream of the
file here.

| Template | Applied where | Bound by |
|---|---|---|
| [`.coderabbit.yaml`](./.coderabbit.yaml) | CodeRabbit **Global Overrides** (org-wide); optionally per-repo | ADR-0079 D1 |

---

## `.coderabbit.yaml` — CodeRabbit (Reviewer 2)

CodeRabbit is the third-party-AI reviewer in the canonical PR-review stack
(ADR-0079 D1): vendor-independent from Microsoft (Copilot) and Anthropic (the
Grid-aware `review` agent). It is **not** Grid-aware — invariant/ADR enforcement
stays with the Grid-aware agent (Reviewers 3/4, run by the local worker per
ADR-0086). CodeRabbit's value is a different model with a different set of blind
spots.

### How it is deployed across the Grid

CodeRabbit applies configuration in priority order: **Global Overrides
(org-wide) → per-repo `.coderabbit.yaml` → dashboard UI settings**, deep-merged
when inheritance applies. The Grid uses **Global Overrides** as the primary
surface:

- **One-time:** the operator pastes this file's contents into
  *Organization Settings → Global Overrides* in the CodeRabbit dashboard. It then
  enforces across **every current and future** HoneyDrunk repo automatically — no
  per-repo file, no fan-out workflow, no drift. New Nodes are covered the moment
  their repo exists and has the CodeRabbit GitHub App installed (org-wide install
  covers this too).
- Full setup steps: [`infrastructure/walkthroughs/coderabbit-org-setup.md`](../infrastructure/walkthroughs/coderabbit-org-setup.md).

This is deliberately **not** a per-repo file fan-out. Twenty-plus identical
`.coderabbit.yaml` files would drift; Global Overrides is one enforced source.

### When to adopt a per-repo `.coderabbit.yaml`

Only when a repo wants to **refine** the baseline — not to restate it. Because
Global Overrides deep-merge with a per-repo file, the per-repo file states only
its *delta*. Examples:

- `HoneyDrunk.Vault` adding a stricter `path_instructions` entry on
  `**/Vault/**` secret-handling paths.
- `HoneyDrunk.Audit` adding an append-only-pattern instruction on `**/Audit/**`.

### How to adopt a per-repo file

1. Copy [`./.coderabbit.yaml`](./.coderabbit.yaml) to the target repo root, **or**
   start a minimal file containing only the keys you are changing.
2. Trim it to the delta (the Global Override carries the baseline).
3. Commit and push to the repo's default branch. CodeRabbit reads it
   automatically on the next PR — no CI change required.

Per-repo adoption is incremental and driven by observed reviewer noise, never a
blocking precondition. Keep the file as small as the refinement requires.

### Invariant 8

`.coderabbit.yaml` is a public-repo artifact. It carries **no** secrets, DSNs,
connection strings, or API keys. CodeRabbit authenticates via its installed
GitHub App, not via anything in this file.
