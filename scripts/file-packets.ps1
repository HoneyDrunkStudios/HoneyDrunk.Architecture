<#
.SYNOPSIS
    Files issue packets from an initiative folder into their target repos
    and populates The Hive project board fields from packet frontmatter.

.PARAMETER InitiativeFolder
    Path to the initiative folder under generated/issue-packets/active/.

.PARAMETER ProjectNumber
    The Hive org project number (default: 4).

.PARAMETER WaveFilter
    Only file packets matching this wave number. Omit to file all.

.PARAMETER DryRun
    Preview what would be filed without creating anything.

.EXAMPLE
    .\scripts\file-packets.ps1 -InitiativeFolder "generated/issue-packets/active/adr-0005-0006-rollout" -WaveFilter 1
#>

param(
    [Parameter(Mandatory)]
    [string]$InitiativeFolder,

    [int]$ProjectNumber = 4,

    [int]$WaveFilter = 0,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$OrgOwner = "HoneyDrunkStudios"
$ProjectItemLookupLimit = 5000

# Resolve to absolute path
if (-not [System.IO.Path]::IsPathRooted($InitiativeFolder)) {
    $InitiativeFolder = Join-Path $PSScriptRoot ".." $InitiativeFolder
}

# Get project ID
$projectJson = gh project list --owner $OrgOwner --format json | ConvertFrom-Json
$project = $projectJson.projects | Where-Object { $_.number -eq $ProjectNumber }
if (-not $project) { throw "Project #$ProjectNumber not found in $OrgOwner" }
$projectId = $project.id

# Load field metadata
$fieldsJson = gh project field-list $ProjectNumber --owner $OrgOwner --format json | ConvertFrom-Json

function Get-FieldId($name) { ($fieldsJson.fields | Where-Object { $_.name -eq $name }).id }
function Get-OptionId($fieldName, $optionName) {
    $field = $fieldsJson.fields | Where-Object { $_.name -eq $fieldName }
    ($field.options | Where-Object { $_.name -eq $optionName }).id
}

$fWave = Get-FieldId "Wave"
$fInit = Get-FieldId "Initiative"
$fNode = Get-FieldId "Node"
$fTier = Get-FieldId "Tier"
$fAdr  = Get-FieldId "ADR"
$fActor = Get-FieldId "Actor"

function Parse-Frontmatter($filePath) {
    $content = Get-Content $filePath -Raw
    if ($content -notmatch '(?s)^---\s*\n(.*?)\n---') { return $null }
    $yaml = @{}
    foreach ($line in ($Matches[1] -split "`n")) {
        if ($line -match '^\s*(\w+)\s*:\s*(.+)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim()
            # Handle JSON arrays in YAML
            if ($val -match '^\[') {
                $val = ($val -replace '[\[\]"]','') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
            }
            $yaml[$key] = $val
        }
    }
    return $yaml
}

# Collect packet files (skip dispatch-plan.md and handoff-*.md)
$packets = Get-ChildItem "$InitiativeFolder\*.md" |
    Where-Object { $_.Name -notmatch '^(dispatch-plan|handoff-)' }

$isStandaloneFolder = (Split-Path $InitiativeFolder -Leaf) -eq "standalone"

if ($isStandaloneFolder) {
    # Standalone packets are date-prefixed and filed in lexical filename order.
    $packets = $packets | Sort-Object Name
}
else {
    # Initiative packets must use NN- prefix so filing order is explicit and stable.
    $packets = $packets |
        ForEach-Object {
            if ($_.BaseName -notmatch '^(\d{2})-') {
                throw "Packet '$($_.Name)' is missing required NN- execution-order prefix for initiative filing."
            }

            [pscustomobject]@{
                Order = [int]$Matches[1]
                File  = $_
            }
        } |
        Sort-Object Order, @{ Expression = { $_.File.Name } } |
        ForEach-Object { $_.File }
}

Write-Host "`n=== Filing packets from: $InitiativeFolder ===" -ForegroundColor Cyan
Write-Host "Project: The Hive (#$ProjectNumber)`n"

foreach ($packet in $packets) {
    $fm = Parse-Frontmatter $packet.FullName
    if (-not $fm) {
        Write-Host "SKIP (no frontmatter): $($packet.Name)" -ForegroundColor Yellow
        continue
    }

    $targetRepo = $fm["target_repo"]
    $targetReposRaw = $fm["target_repos"]
    $tier = $fm["tier"]
    $wave = $fm["wave"]
    $node = $fm["node"]
    $initiative = $fm["initiative"]
    $actorRaw = $fm["actor"]
    $adrs = if ($fm["adrs"] -is [array]) { $fm["adrs"] -join ", " } else { $fm["adrs"] }
    $labels = if ($fm["labels"] -is [array]) { $fm["labels"] -join "," } else { $fm["labels"] }
    $labelValues = @()
    if ($labels) {
        $labelValues = $labels -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    $actor = $null
    if ($actorRaw) {
        $actorCandidate = "$actorRaw".Trim().ToLowerInvariant()
        if ($actorCandidate -eq "human") {
            $actor = "Human"
        }
        elseif ($actorCandidate -eq "agent") {
            $actor = "Agent"
        }
        else {
            Write-Host "WARN: Unknown actor '$actorRaw' in $($packet.Name). Expected 'agent' or 'human'." -ForegroundColor Yellow
        }
    }
    if (-not $actor -and ($labelValues | Where-Object { $_.ToLowerInvariant() -eq "human-only" })) {
        $actor = "Human"
    }
    if (-not $actor) {
        $actor = "Agent"
    }

    $targetRepos = @()
    if ($targetRepo) {
        $targetRepos += $targetRepo
    }
    if ($targetReposRaw) {
        if ($targetReposRaw -is [array]) {
            $targetRepos += $targetReposRaw
        }
        else {
            $targetRepos += $targetReposRaw
        }
    }
    $targetRepos = $targetRepos | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique
    $targetRepos = $targetRepos | ForEach-Object {
        if ($_ -match '^[^/]+/[^/]+$') {
            $_
        }
        else {
            "$OrgOwner/$_"
        }
    } | Select-Object -Unique

    # Extract title from first H1
    $title = (Get-Content $packet.FullName | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1) -replace '^#\s+(Feature|Chore|Bug|CI):\s*', ''

    if ($targetRepo -and $targetReposRaw) {
        throw "Packet '$($packet.Name)' contains both target_repo and target_repos. Use exactly one."
    }

    if (-not $targetRepos -or $targetRepos.Count -eq 0 -or -not $title) {
        Write-Host "SKIP (missing target repo(s) or title): $($packet.Name)" -ForegroundColor Yellow
        continue
    }

    if ($WaveFilter -gt 0 -and $wave -ne "$WaveFilter") {
        Write-Host "SKIP (wave $wave, filter is $WaveFilter): $($packet.Name)" -ForegroundColor DarkGray
        continue
    }

    Write-Host "--- $($packet.Name) ---" -ForegroundColor Green
    Write-Host "  Repo(s): $($targetRepos -join ', ')"
    Write-Host "  Title: $title"
    Write-Host "  Wave:  $wave | Tier: $tier | Node: $node"
    Write-Host "  Actor: $actor"
    Write-Host "  ADRs:  $adrs"
    Write-Host "  Labels: $labels"

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would file issue and set board fields`n" -ForegroundColor Magenta
        continue
    }

    foreach ($repo in $targetRepos) {
        Write-Host "  Filing into: $repo" -ForegroundColor DarkCyan

        # Ensure labels exist on target repo
        if ($labels) {
            foreach ($label in $labelValues) {
                gh label create $label --repo $repo --force 2>&1 | Out-Null
            }
        }

        # Create issue
        $issueCreateArgs = @(
            "issue", "create",
            "--repo", $repo,
            "--title", $title,
            "--body-file", $packet.FullName
        )

        if ($labels) {
            foreach ($label in $labelValues) {
                $issueCreateArgs += @("--label", $label)
            }
        }

        $issueUrl = gh @issueCreateArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR filing issue in $repo : $issueUrl" -ForegroundColor Red
            continue
        }
        Write-Host "  Issue: $issueUrl" -ForegroundColor Cyan

        # Add to project
        gh project item-add $ProjectNumber --owner $OrgOwner --url $issueUrl 2>&1 | Out-Null

        # Use an explicit high limit so recent items are still discoverable on large boards.
        $allItems = gh project item-list $ProjectNumber --owner $OrgOwner --limit $ProjectItemLookupLimit --format json | ConvertFrom-Json
        $itemId = ($allItems.items | Where-Object { $_.content.url -eq $issueUrl }).id

        if (-not $itemId) {
            Write-Host "  WARN: Could not find item on board to set fields" -ForegroundColor Yellow
            continue
        }

        # Set board fields
        if ($wave) {
            $optId = Get-OptionId "Wave" "Wave $wave"
            if ($optId) { gh project item-edit --project-id $projectId --id $itemId --field-id $fWave --single-select-option-id $optId 2>&1 | Out-Null }
        }
        if ($initiative) {
            $optId = Get-OptionId "Initiative" $initiative
            if ($optId) { gh project item-edit --project-id $projectId --id $itemId --field-id $fInit --single-select-option-id $optId 2>&1 | Out-Null }
        }
        if ($node) {
            $optId = Get-OptionId "Node" $node
            if ($optId) { gh project item-edit --project-id $projectId --id $itemId --field-id $fNode --single-select-option-id $optId 2>&1 | Out-Null }
        }
        if ($tier) {
            $optId = Get-OptionId "Tier" "$tier"
            if ($optId) { gh project item-edit --project-id $projectId --id $itemId --field-id $fTier --single-select-option-id $optId 2>&1 | Out-Null }
        }
        if ($adrs) {
            gh project item-edit --project-id $projectId --id $itemId --field-id $fAdr --text $adrs 2>&1 | Out-Null
        }
        if ($fActor -and $actor) {
            $optId = Get-OptionId "Actor" $actor
            if ($optId) {
                gh project item-edit --project-id $projectId --id $itemId --field-id $fActor --single-select-option-id $optId 2>&1 | Out-Null
            }
            else {
                Write-Host "  WARN: Actor option '$actor' not found on project board" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "  Board fields set`n" -ForegroundColor Green
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
