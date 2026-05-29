function Get-GridAgentHostConfig {
    param(
        [string]$Path,
        [string]$RunnerRoot
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        $examplePath = Join-Path $RunnerRoot "config/host.psd1.example"
        throw "Host config '$Path' was not found. Copy '$examplePath' to '$Path' and customize local paths."
    }

    $config = Import-PowerShellDataFile -LiteralPath $Path
    $defaults = @{
        HostId = "$env:COMPUTERNAME:$PID"
        RuntimeRoot = Join-Path $env:TEMP "HoneyDrunkGridAgentRunner"
    }

    foreach ($key in $defaults.Keys) {
        if (-not $config.ContainsKey($key) -or [string]::IsNullOrWhiteSpace([string]$config[$key])) {
            $config[$key] = $defaults[$key]
        }
    }

    foreach ($pathKey in @("LogRoot", "StateRoot", "CacheRoot", "LockRoot", "ArtifactRoot")) {
        if (-not $config.ContainsKey($pathKey) -or [string]::IsNullOrWhiteSpace([string]$config[$pathKey])) {
            $config[$pathKey] = Join-Path $config.RuntimeRoot $pathKey.Replace("Root", "").ToLowerInvariant()
        }
    }

    return $config
}

function Get-GridAgentJobSpec {
    param(
        [string]$RunnerRoot,
        [string]$JobId
    )

    $path = Join-Path $RunnerRoot "config/jobs/$JobId.psd1"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Job spec '$JobId' was not found at '$path'."
    }

    $spec = Import-PowerShellDataFile -LiteralPath $path
    $spec.SpecPath = $path
    return $spec
}

function Assert-GridAgentJobSpec {
    param([hashtable]$Spec)

    $required = @(
        "JobId", "Description", "Enabled", "TriggerKind", "Schedule", "ConcurrencyKey",
        "TimeoutMinutes", "MaxMissedRuns", "Repo", "WorkingDirectory", "PromptPath",
        "AgentCommands", "WriteMode", "OutputContract", "RequiredSecrets",
        "AllowedTools", "RetainArtifactsDays", "PortabilityNotes"
    )

    foreach ($key in $required) {
        if (-not $Spec.ContainsKey($key)) {
            throw "Job spec '$($Spec.JobId)' is missing required key '$key'."
        }
    }

    if ($Spec.TriggerKind -notin @("label-queue", "schedule", "manual")) {
        throw "Job spec '$($Spec.JobId)' has unsupported TriggerKind '$($Spec.TriggerKind)'."
    }

    if ($Spec.WriteMode -notin @("comment-only", "commit", "pr", "none")) {
        throw "Job spec '$($Spec.JobId)' has unsupported WriteMode '$($Spec.WriteMode)'."
    }

    foreach ($pathKey in @("WorkingDirectory", "PromptPath")) {
        Assert-PortableRunnerPath -Value $Spec[$pathKey] -FieldName $pathKey -JobId $Spec.JobId
    }
}

function Assert-PortableRunnerPath {
    param(
        [string]$Value,
        [string]$FieldName,
        [string]$JobId
    )

    if ([System.IO.Path]::IsPathRooted($Value)) {
        throw "Job spec '$JobId' has host-specific absolute path in '$FieldName': '$Value'."
    }

    if ($Value -match "^[A-Za-z]:\\") {
        throw "Job spec '$JobId' has Windows absolute path in '$FieldName': '$Value'."
    }
}

function Resolve-RunnerRepoPath {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec
    )

    if (-not $HostConfig.ContainsKey("Repositories") -or -not $HostConfig.Repositories.ContainsKey($JobSpec.Repo)) {
        throw "Host config is missing repository path for '$($JobSpec.Repo)'."
    }

    return $HostConfig.Repositories[$JobSpec.Repo]
}

Export-ModuleMember -Function Get-GridAgentHostConfig, Get-GridAgentJobSpec, Assert-GridAgentJobSpec, Resolve-RunnerRepoPath
