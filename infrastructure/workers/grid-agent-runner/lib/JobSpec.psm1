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
        RuntimeRoot = Join-Path ([System.IO.Path]::GetTempPath()) "HoneyDrunkGridAgentRunner"
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

function Get-RunnerSafetyConfig {
    param([hashtable]$HostConfig)

    $defaults = @{
        Enabled = $false
        OperatorAcknowledgedUntrustedInputs = $false
        AllowedReviewRepositories = @()
        AllowForkPullRequests = $false
        AllowPrivateHeadRepositories = $false
        RequireQueueComment = $true
        RequireNonRepositoryRunnerRoot = $true
        TrustedRunnerRoot = $null
    }

    $safety = @{}
    foreach ($key in $defaults.Keys) {
        $safety[$key] = $defaults[$key]
    }

    if ($HostConfig.ContainsKey("Safety") -and $null -ne $HostConfig.Safety) {
        foreach ($key in $HostConfig.Safety.Keys) {
            $safety[$key] = $HostConfig.Safety[$key]
        }
    }

    foreach ($key in @("Enabled", "OperatorAcknowledgedUntrustedInputs", "AllowForkPullRequests", "AllowPrivateHeadRepositories", "RequireQueueComment", "RequireNonRepositoryRunnerRoot")) {
        $safety[$key] = Convert-RunnerSafetyBoolean -Value $safety[$key] -Name "Safety.$key"
    }

    return $safety
}

function Assert-RunnerSafetyConfig {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [string]$RunnerRoot,
        [string]$ConfigPath
    )

    $safety = Get-RunnerSafetyConfig -HostConfig $HostConfig
    if (-not $safety.Enabled) {
        throw "Runner safety gate is disabled for job '$($JobSpec.JobId)'. Set Safety.Enabled to true in host.psd1 only on the operator-controlled runner host."
    }

    if (-not $safety.OperatorAcknowledgedUntrustedInputs) {
        throw "Runner safety gate for job '$($JobSpec.JobId)' requires Safety.OperatorAcknowledgedUntrustedInputs=true after reviewing the hostile-input rules."
    }

    if ($JobSpec.TriggerKind -eq "label-queue") {
        $allowed = @($safety.AllowedReviewRepositories | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        if ($allowed.Count -eq 0) {
            throw "Label-queue job '$($JobSpec.JobId)' requires Safety.AllowedReviewRepositories to be explicit."
        }

        if (-not $safety.RequireQueueComment) {
            throw "Label-queue job '$($JobSpec.JobId)' requires Safety.RequireQueueComment=true so runner claims can be recovered after interrupted runs."
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($RunnerRoot)) {
        Assert-RunnerSourceTrust -HostConfig $HostConfig -Safety $safety -RunnerRoot $RunnerRoot -ConfigPath $ConfigPath
    }
}

function Convert-RunnerSafetyBoolean {
    param(
        [object]$Value,
        [string]$Name
    )

    if ($Value -is [bool]) {
        return $Value
    }

    if ($Value -is [string]) {
        $trimmed = $Value.Trim()
        if ($trimmed.Equals("true", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }

        if ($trimmed.Equals("false", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    throw "Invalid runner safety configuration '$Name'. Expected boolean true/false, got '$Value'."
}

function Assert-RunnerSourceTrust {
    param(
        [hashtable]$HostConfig,
        [hashtable]$Safety,
        [string]$RunnerRoot,
        [string]$ConfigPath
    )

    $runnerFullPath = ConvertTo-RunnerFullPath -Path $RunnerRoot
    if (-not [string]::IsNullOrWhiteSpace([string]$Safety.TrustedRunnerRoot)) {
        $trustedFullPath = ConvertTo-RunnerFullPath -Path ([string]$Safety.TrustedRunnerRoot)
        if (-not $runnerFullPath.Equals($trustedFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Runner root '$runnerFullPath' does not match Safety.TrustedRunnerRoot '$trustedFullPath'. Register scheduled tasks from the operator-installed runner copy."
        }
    }

    if ($Safety.RequireNonRepositoryRunnerRoot) {
        $gitControlPath = Find-RunnerGitControlPath -Path $runnerFullPath
        if (-not [string]::IsNullOrWhiteSpace($gitControlPath)) {
            throw "Runner root '$runnerFullPath' is inside a Git worktree controlled by '$gitControlPath'. Install the runner into an operator-controlled runtime directory before enabling non-dry-run jobs."
        }

        if ($HostConfig.ContainsKey("Repositories") -and $null -ne $HostConfig.Repositories) {
            foreach ($repoKey in $HostConfig.Repositories.Keys) {
                $repoPath = [string]$HostConfig.Repositories[$repoKey]
                if (-not [string]::IsNullOrWhiteSpace($repoPath) -and (Test-RunnerPathInside -ChildPath $runnerFullPath -ParentPath $repoPath)) {
                    throw "Runner root '$runnerFullPath' is inside configured repository '$repoKey'. Install the runner into an operator-controlled runtime directory before enabling non-dry-run jobs."
                }
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $configFullPath = ConvertTo-RunnerFullPath -Path $ConfigPath
        if ($Safety.RequireNonRepositoryRunnerRoot -and (Test-RunnerPathInside -ChildPath $configFullPath -ParentPath $runnerFullPath)) {
            throw "Host config '$configFullPath' is inside the runner code directory. Keep host.psd1 outside cloned source and outside the installed runner code."
        }
    }
}

function ConvertTo-RunnerFullPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    try {
        $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
        $fullPath = $resolved.Path
    }
    catch {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }

    return $fullPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Test-RunnerPathInside {
    param(
        [string]$ChildPath,
        [string]$ParentPath
    )

    $childFullPath = ConvertTo-RunnerFullPath -Path $ChildPath
    $parentFullPath = ConvertTo-RunnerFullPath -Path $ParentPath

    if ([string]::IsNullOrWhiteSpace($childFullPath) -or [string]::IsNullOrWhiteSpace($parentFullPath)) {
        return $false
    }

    if ($childFullPath.Equals($parentFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $prefix = $parentFullPath + [System.IO.Path]::DirectorySeparatorChar
    return $childFullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Find-RunnerGitControlPath {
    param([string]$Path)

    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    $directory = if ($item.PSIsContainer) { $item } else { $item.Directory }
    while ($null -ne $directory) {
        $gitPath = Join-Path $directory.FullName ".git"
        if (Test-Path -LiteralPath $gitPath) {
            return $gitPath
        }

        $directory = $directory.Parent
    }

    return $null
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

Export-ModuleMember -Function Get-GridAgentHostConfig, Get-GridAgentJobSpec, Assert-GridAgentJobSpec, Resolve-RunnerRepoPath, Get-RunnerSafetyConfig, Assert-RunnerSafetyConfig
