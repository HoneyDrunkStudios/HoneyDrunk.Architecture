# Drift Report

Tracked automatically by the hive-sync agent. Items listed here are
inconsistencies between Accepted decisions and the rest of the Architecture
repo. The agent surfaces these - it does not fix them. Resolution is the
scope/adr-composer/human's responsibility.

Last synced: 2026-05-21

## Invariants Named in ADRs but Missing from `invariants.md`

_No drift detected._

## Capability Matrix Rows with No Agent File

_No drift detected._

## Agent Files with No Capability Matrix Row

_No drift detected._

## Issue Packet Manifest Drift

| Path | Issue | Detail | First Surfaced |
|------|-------|--------|----------------|
| `generated/issue-packets/active/adr-0010-observe-ai-routing-phase-1/04-ai-add-routing-contracts.md` | HoneyDrunk.AI#1 | Manifest references a packet file that no longer exists; a `.superseded.md` packet for the same original scope remains and is separately filed as HoneyDrunk.AI#3. Human/scope agent should reconcile duplicate open issues before executing ADR-0010/ADR-0016 AI work. | 2026-05-18 |

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
