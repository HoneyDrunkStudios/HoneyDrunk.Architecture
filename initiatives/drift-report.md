# Drift Report

Tracked automatically by the hive-sync agent. Items listed here are
inconsistencies between Accepted decisions and the rest of the Architecture
repo. The agent surfaces these - it does not fix them. Resolution is the
scope/adr-composer/human's responsibility.

Last synced: 2026-05-11

## Invariants Named in ADRs but Missing from `invariants.md`

_No drift detected._

## Capability Matrix Rows with No Agent File

_No drift detected._

## Agent Files with No Capability Matrix Row

_No drift detected._

## Nodes in `nodes.json` with Missing GitHub Repos

| Node | Repo URL | Detail | First Surfaced |
|------|----------|--------|----------------|
| HoneyDrunk.Studios | https://github.com/HoneyDrunkStudios/HoneyDrunk.Studios | `gh repo view` could not resolve the repository. Catalog may point at the wrong repo name or the repo may be missing/private beyond current token scope. | 2026-05-07 |
| HoneyDrunk.Evals | https://github.com/HoneyDrunkStudios/HoneyDrunk.Evals | `gh repo view` could not resolve the repository. Catalog lists the Node, but the GitHub repo is not present/resolvable. | 2026-05-07 |
| HoneyDrunk.Sim | https://github.com/HoneyDrunkStudios/HoneyDrunk.Sim | `gh repo view` could not resolve the repository. Catalog lists the Node, but the GitHub repo is not present/resolvable. | 2026-05-07 |

### Auth Issues (token-scope problems, not drift)

_No drift detected._

## Nodes Named in ADRs but Missing from `nodes.json`

_No drift detected._
