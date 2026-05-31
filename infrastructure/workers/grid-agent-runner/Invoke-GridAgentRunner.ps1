param(
    [Parameter(Mandatory = $true)]
    [string]$JobId,

    [string]$ConfigPath = (Join-Path $PSScriptRoot "config/host.psd1"),

    [switch]$DryRun,

    [switch]$Once
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$libRoot = Join-Path $PSScriptRoot "lib"
Import-Module (Join-Path $libRoot "Logging.psm1") -Force
Import-Module (Join-Path $libRoot "JobSpec.psm1") -Force
Import-Module (Join-Path $libRoot "State.psm1") -Force
Import-Module (Join-Path $libRoot "Scheduler.psm1") -Force
Import-Module (Join-Path $libRoot "Secrets.psm1") -Force
Import-Module (Join-Path $libRoot "GitHub.psm1") -Force
Import-Module (Join-Path $libRoot "Agent.psm1") -Force
Import-Module (Join-Path $libRoot "Synthesis.psm1") -Force
Import-Module (Join-Path $libRoot "Queue.psm1") -Force
Import-Module (Join-Path $libRoot "Notify.psm1") -Force

$hostConfig = Get-GridAgentHostConfig -Path $ConfigPath -RunnerRoot $PSScriptRoot
$jobSpec = Get-GridAgentJobSpec -RunnerRoot $PSScriptRoot -JobId $JobId
Assert-GridAgentJobSpec -Spec $jobSpec

Initialize-RunnerDirectories -HostConfig $hostConfig
$logger = New-RunnerLogger -HostConfig $hostConfig -JobId $JobId

Write-RunnerLog -Logger $logger -Level "INFO" -Message "Starting runner job '$JobId'." -Data @{
    dry_run = [bool]$DryRun
    trigger_kind = $jobSpec.TriggerKind
    write_mode = $jobSpec.WriteMode
}

if (-not $DryRun) {
    Assert-RunnerSafetyConfig -HostConfig $hostConfig -JobSpec $jobSpec -RunnerRoot $PSScriptRoot -ConfigPath $ConfigPath
}

Invoke-WithRunnerLock -HostConfig $hostConfig -JobSpec $jobSpec -ScriptBlock {
    param($lockedHostConfig, $lockedJobSpec)

    $startedAt = (Get-Date).ToUniversalTime()
    $result = @{
        status = "unknown"
        message = $null
        artifacts = @()
    }

    try {
        if ($lockedJobSpec.Enabled -ne $true) {
            $result.status = "skipped"
            $result.message = "Job is disabled in the committed spec."
            Write-RunnerLog -Logger $logger -Level "WARN" -Message $result.message
            return
        }

        switch ($lockedJobSpec.TriggerKind) {
            "label-queue" {
                $result = Invoke-GridReviewQueueTick -HostConfig $lockedHostConfig -JobSpec $lockedJobSpec -Logger $logger -DryRun:$DryRun
            }
            "schedule" {
                $result = Invoke-ScheduledAgentJob -HostConfig $lockedHostConfig -JobSpec $lockedJobSpec -Logger $logger -DryRun:$DryRun
            }
            "manual" {
                $result = Invoke-ScheduledAgentJob -HostConfig $lockedHostConfig -JobSpec $lockedJobSpec -Logger $logger -DryRun:$DryRun
            }
            default {
                throw "Unsupported TriggerKind '$($lockedJobSpec.TriggerKind)' for job '$($lockedJobSpec.JobId)'."
            }
        }
    }
    catch {
        $result.status = "failed"
        $result.message = $_.Exception.Message
        Write-RunnerLog -Logger $logger -Level "ERROR" -Message "Job '$JobId' failed." -Data @{ error = $_.Exception.Message }
        throw
    }
    finally {
        $finishedAt = (Get-Date).ToUniversalTime()
        Update-GridAgentJobState -HostConfig $lockedHostConfig -JobSpec $lockedJobSpec -StartedAt $startedAt -FinishedAt $finishedAt -Result $result -DryRun:$DryRun
        Write-RunnerLog -Logger $logger -Level "INFO" -Message "Finished runner job '$JobId'." -Data @{
            status = $result.status
            message = $result.message
        }
        Invoke-RunnerCompletionNotification -HostConfig $lockedHostConfig -JobSpec $lockedJobSpec -Result $result -StartedAt $startedAt -FinishedAt $finishedAt -Logger $logger -DryRun:$DryRun
    }
}

if (-not $Once) {
    Write-RunnerLog -Logger $logger -Level "INFO" -Message "Runner job '$JobId' completed one scheduled invocation."
}
