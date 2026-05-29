function Get-GridAgentJobStatePath {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec
    )

    return Join-Path $HostConfig.StateRoot "$($JobSpec.JobId).json"
}

function Read-GridAgentJobState {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec
    )

    $path = Get-GridAgentJobStatePath -HostConfig $HostConfig -JobSpec $JobSpec
    if (-not (Test-Path -LiteralPath $path)) {
        return @{}
    }

    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
}

function Update-GridAgentJobState {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [datetime]$StartedAt,
        [datetime]$FinishedAt,
        [hashtable]$Result,
        [switch]$DryRun
    )

    $path = Get-GridAgentJobStatePath -HostConfig $HostConfig -JobSpec $JobSpec
    $previous = Read-GridAgentJobState -HostConfig $HostConfig -JobSpec $JobSpec

    $missedRuns = 0
    if ($previous.ContainsKey("missed_runs")) {
        $missedRuns = [int]$previous.missed_runs
    }

    if ($Result.status -eq "failed") {
        $missedRuns++
    }
    elseif ($Result.status -in @("completed", "dry-run", "skipped", "empty")) {
        $missedRuns = 0
    }

    $state = [ordered]@{
        job_id = $JobSpec.JobId
        host_id = $HostConfig.HostId
        started_at = $StartedAt.ToString("o")
        finished_at = $FinishedAt.ToString("o")
        last_success = if ($Result.status -in @("completed", "dry-run", "empty")) { $FinishedAt.ToString("o") } elseif ($previous.ContainsKey("last_success")) { $previous.last_success } else { $null }
        status = $Result.status
        message = $Result.message
        missed_runs = $missedRuns
        latest_output = if ($Result.ContainsKey("latest_output")) { $Result.latest_output } elseif ($JobSpec.OutputContract.ContainsKey("LatestOutput")) { $JobSpec.OutputContract.LatestOutput } else { $null }
        dry_run = [bool]$DryRun
        artifacts = $Result.artifacts
    }

    $state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding UTF8
}

Export-ModuleMember -Function Get-GridAgentJobStatePath, Read-GridAgentJobState, Update-GridAgentJobState
