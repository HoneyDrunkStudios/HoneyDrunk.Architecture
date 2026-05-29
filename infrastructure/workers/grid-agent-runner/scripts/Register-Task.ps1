param(
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "config/host.psd1"),
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

function New-RunnerTaskTriggers {
    param([hashtable]$Spec)

    $schedule = $Spec.Schedule
    $triggers = @()

    if ($schedule.ContainsKey("AtStartup") -and $schedule.AtStartup) {
        $triggers += New-ScheduledTaskTrigger -AtStartup
    }

    if ($schedule.ContainsKey("AtLogon") -and $schedule.AtLogon) {
        $triggers += New-ScheduledTaskTrigger -AtLogOn
    }

    switch ($schedule.Type) {
        "interval" {
            $seconds = [int]$schedule.IntervalSeconds
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Seconds $seconds) -RepetitionDuration (New-TimeSpan -Days 3650)
            $triggers += $trigger
        }
        "daily" {
            $time = [datetime]::Parse($schedule.TimeLocal)
            $triggers += New-ScheduledTaskTrigger -Daily -At $time
        }
        "weekly" {
            $timeText = if ($schedule.ContainsKey("TimeLocal")) { $schedule.TimeLocal } else { $schedule.TimeUtc }
            $time = [datetime]::Parse($timeText)
            $triggers += New-ScheduledTaskTrigger -Weekly -DaysOfWeek $schedule.DaysOfWeek -At $time
        }
        default {
            if ($Spec.TriggerKind -ne "manual") {
                throw "Unsupported schedule type '$($schedule.Type)' for job '$($Spec.JobId)'."
            }
        }
    }

    return $triggers
}

if (-not $IsWindows) {
    throw "Register-Task.ps1 requires Windows Task Scheduler. Use the job specs with cron/systemd on non-Windows hosts."
}

$runnerRoot = Split-Path -Parent $PSScriptRoot
$jobSpecModule = Join-Path $runnerRoot "lib/JobSpec.psm1"
Import-Module $jobSpecModule -Force

foreach ($id in $JobId) {
    $spec = Get-GridAgentJobSpec -RunnerRoot $runnerRoot -JobId $id
    Assert-GridAgentJobSpec -Spec $spec

    $taskName = Get-TaskName -JobId $id
    $actionArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$(Join-Path $runnerRoot "Invoke-GridAgentRunner.ps1")`"",
        "-JobId", $id,
        "-ConfigPath", "`"$ConfigPath`"",
        "-Once"
    ) -join " "

    $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument $actionArgs
    $triggers = New-RunnerTaskTriggers -Spec $spec
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes $spec.TimeoutMinutes)

    if ($WhatIf) {
        Write-Host "Would register scheduled task '$taskName' for job '$id'."
        continue
    }

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Settings $settings -Description $spec.Description -Force | Out-Null
    Write-Host "Registered scheduled task '$taskName'."
}
