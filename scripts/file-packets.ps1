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
    Where-Object { $_.Name -notmatch '^(dispatch-plan|handoff-)' } |
    Sort-Object Name

Write-Host "`n=== Filing packets from: $InitiativeFolder ===" -ForegroundColor Cyan
Write-Host "Project: The Hive (#$ProjectNumber)`n"

foreach ($packet in $packets) {
    $fm = Parse-Frontmatter $packet.FullName
    if (-not $fm) {
        Write-Host "SKIP (no frontmatter): $($packet.Name)" -ForegroundColor Yellow
        continue
    }

    $targetRepo = $fm["target_repo"]
    $tier = $fm["tier"]
    $wave = $fm["wave"]
    $node = $fm["node"]
    $initiative = $fm["initiative"]
    $adrs = if ($fm["adrs"] -is [array]) { $fm["adrs"] -join ", " } else { $fm["adrs"] }
    $labels = if ($fm["labels"] -is [array]) { $fm["labels"] -join "," } else { $fm["labels"] }

    # Extract title from first H1
    $title = (Get-Content $packet.FullName | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1) -replace '^#\s+(Feature|Chore|Bug|CI):\s*', ''

    if (-not $targetRepo -or -not $title) {
        Write-Host "SKIP (missing target_repo or title): $($packet.Name)" -ForegroundColor Yellow
        continue
    }

    if ($WaveFilter -gt 0 -and $wave -ne "$WaveFilter") {
        Write-Host "SKIP (wave $wave, filter is $WaveFilter): $($packet.Name)" -ForegroundColor DarkGray
        continue
    }

    Write-Host "--- $($packet.Name) ---" -ForegroundColor Green
    Write-Host "  Repo:  $targetRepo"
    Write-Host "  Title: $title"
    Write-Host "  Wave:  $wave | Tier: $tier | Node: $node"
    Write-Host "  ADRs:  $adrs"
    Write-Host "  Labels: $labels"

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would file issue and set board fields`n" -ForegroundColor Magenta
        continue
    }

    # Ensure labels exist on target repo
    if ($labels) {
        foreach ($label in ($labels -split ',')) {
            $label = $label.Trim()
            gh label create $label --repo $targetRepo --force 2>&1 | Out-Null
        }
    }

    # Create issue
    $issueUrl = gh issue create --repo $targetRepo --title $title --body-file $packet.FullName --label $labels 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR filing issue: $issueUrl" -ForegroundColor Red
        continue
    }
    Write-Host "  Issue: $issueUrl" -ForegroundColor Cyan

    # Add to project
    gh project item-add $ProjectNumber --owner $OrgOwner --url $issueUrl 2>&1 | Out-Null

    # Get the item ID we just added
    $allItems = gh project item-list $ProjectNumber --owner $OrgOwner --format json | ConvertFrom-Json
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

    Write-Host "  Board fields set`n" -ForegroundColor Green
}

Write-Host "`n=== Done ===" -ForegroundColor Cyan
