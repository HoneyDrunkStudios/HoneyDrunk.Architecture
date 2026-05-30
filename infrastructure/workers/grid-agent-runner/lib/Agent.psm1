function Invoke-ScheduledAgentJob {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [hashtable]$Logger,
        [switch]$DryRun
    )

    $repoPath = Resolve-RunnerRepoPath -HostConfig $HostConfig -JobSpec $JobSpec
    $workingDirectory = Join-Path $repoPath $JobSpec.WorkingDirectory
    $promptPath = Join-Path $repoPath $JobSpec.PromptPath

    if (-not (Test-Path -LiteralPath $workingDirectory)) {
        throw "Working directory '$workingDirectory' does not exist for job '$($JobSpec.JobId)'."
    }

    if (-not (Test-Path -LiteralPath $promptPath)) {
        throw "Prompt path '$promptPath' does not exist for job '$($JobSpec.JobId)'."
    }

    if ($DryRun) {
        Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Dry-run scheduled job validated paths." -Data @{
            repo = $JobSpec.Repo
            prompt_path = $JobSpec.PromptPath
            write_mode = $JobSpec.WriteMode
        }

        return @{
            status = "dry-run"
            message = "Validated scheduled job '$($JobSpec.JobId)' without invoking agents."
            latest_output = $JobSpec.OutputContract.LatestOutput
            artifacts = @($JobSpec.OutputContract.LatestOutput)
        }
    }

    foreach ($command in $JobSpec.AgentCommands) {
        [void](Invoke-AgentCommand -CommandSpec $command -PromptPath $promptPath -WorkingDirectory $workingDirectory -Logger $Logger -TimeoutMinutes $JobSpec.TimeoutMinutes)
    }

    return @{
        status = "completed"
        message = "Scheduled job '$($JobSpec.JobId)' completed."
        latest_output = $JobSpec.OutputContract.LatestOutput
        artifacts = @($JobSpec.OutputContract.LatestOutput)
    }
}

function Invoke-AgentCommand {
    param(
        [hashtable]$CommandSpec,
        [string]$PromptPath,
        [string]$WorkingDirectory,
        [hashtable]$Logger,
        [int]$TimeoutMinutes
    )

    $configuredExecutable = [string]$CommandSpec.Executable
    $executable = Resolve-AgentExecutable -Executable $configuredExecutable
    $arguments = @()
    if ($CommandSpec.ContainsKey("Arguments")) {
        $arguments = @($CommandSpec.Arguments)
    }

    $arguments = $arguments | ForEach-Object { $_.Replace("{PromptPath}", $PromptPath) }

    Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Invoking agent command." -Data @{
        executable = $executable
        configured_executable = $configuredExecutable
        working_directory = $WorkingDirectory
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $executable
    foreach ($arg in $arguments) {
        [void]$startInfo.ArgumentList.Add($arg)
    }

    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.RedirectStandardInput = $CommandSpec.ContainsKey("PromptStdin") -and [bool]$CommandSpec.PromptStdin
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    Protect-AgentChildEnvironment -StartInfo $startInfo

    $promptText = $null
    if ($startInfo.RedirectStandardInput) {
        $promptText = Get-Content -LiteralPath $PromptPath -Raw
    }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    if ($startInfo.RedirectStandardInput) {
        $process.StandardInput.Write($promptText)
        $process.StandardInput.Close()
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timeoutMs = [Math]::Max(1, $TimeoutMinutes) * 60 * 1000
    if (-not $process.WaitForExit($timeoutMs)) {
        $process.Kill()
        throw "Agent command '$executable' timed out after $TimeoutMinutes minutes."
    }

    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()

    if ($process.ExitCode -ne 0) {
        throw "Agent command '$executable' failed with exit code $($process.ExitCode): $stderr"
    }

    return $stdout
}

function Resolve-AgentExecutable {
    param([string]$Executable)

    if ([string]::IsNullOrWhiteSpace($Executable)) {
        return $Executable
    }

    if ([System.IO.Path]::IsPathRooted($Executable) -or $Executable.Contains("\") -or $Executable.Contains("/")) {
        return $Executable
    }

    $command = Get-Command -Name $Executable -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $command) {
        return $command.Source
    }

    if ($Executable -ieq "codex" -and -not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $codexBinary = Get-ChildItem -LiteralPath (Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin") -Filter "codex.exe" -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if ($null -ne $codexBinary) {
            return $codexBinary.FullName
        }
    }

    return $Executable
}

function Protect-AgentChildEnvironment {
    param([System.Diagnostics.ProcessStartInfo]$StartInfo)

    $exactNames = @(
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GITHUB_TOKEN",
        "GH_TOKEN",
        "AZURE_CLIENT_ID",
        "AZURE_CLIENT_SECRET",
        "AZURE_TENANT_ID",
        "AZURE_SUBSCRIPTION_ID",
        "ARM_CLIENT_ID",
        "ARM_CLIENT_SECRET",
        "ARM_TENANT_ID",
        "ARM_SUBSCRIPTION_ID",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY",
        "AWS_SESSION_TOKEN",
        "GOOGLE_APPLICATION_CREDENTIALS",
        "HF_TOKEN",
        "HUGGINGFACE_HUB_TOKEN",
        "NPM_TOKEN",
        "NUGET_API_KEY",
        "SONAR_TOKEN",
        "SENTRY_AUTH_TOKEN",
        "SLACK_BOT_TOKEN"
    )

    foreach ($name in $exactNames) {
        [void]$StartInfo.Environment.Remove($name)
    }

    $prefixes = @(
        "AZURE_",
        "ARM_",
        "AWS_",
        "GOOGLE_",
        "GCLOUD_",
        "HONEYDRUNK_SECRET_"
    )

    $keys = @($StartInfo.Environment.Keys)
    foreach ($key in $keys) {
        foreach ($prefix in $prefixes) {
            if ($key.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                [void]$StartInfo.Environment.Remove($key)
                break
            }
        }
    }

    $StartInfo.Environment["HONEYDRUNK_RUNNER_CHILD_AGENT"] = "1"
}

Export-ModuleMember -Function Invoke-ScheduledAgentJob, Invoke-AgentCommand
