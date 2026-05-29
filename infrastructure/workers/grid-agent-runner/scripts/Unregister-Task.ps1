param(
    [string[]]$JobId = @("grid-review", "hive-sync", "lore-source", "lore-ingest", "lore-signal-review"),
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TaskName {
    param([string]$JobId)

    $text = ($JobId -split "-") | ForEach-Object {
        if ($_.Length -eq 0) { $_ } else { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }
    }

    return "HoneyDrunk" + ($text -join "")
}

if (-not $IsWindows) {
    throw "Unregister-Task.ps1 requires Windows Task Scheduler."
}

foreach ($id in $JobId) {
    $taskName = Get-TaskName -JobId $id
    if ($WhatIf) {
        Write-Host "Would unregister scheduled task '$taskName'."
        continue
    }

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Unregistered scheduled task '$taskName' if it existed."
}
