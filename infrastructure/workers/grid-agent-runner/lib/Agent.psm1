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

    $executable = $CommandSpec.Executable
    $arguments = @()
    if ($CommandSpec.ContainsKey("Arguments")) {
        $arguments = @($CommandSpec.Arguments)
    }

    $arguments = $arguments | ForEach-Object { $_.Replace("{PromptPath}", $PromptPath) }

    Write-RunnerLog -Logger $Logger -Level "INFO" -Message "Invoking agent command." -Data @{
        executable = $executable
        working_directory = $WorkingDirectory
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $executable
    foreach ($arg in $arguments) {
        [void]$startInfo.ArgumentList.Add($arg)
    }

    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    [void]$startInfo.Environment.Remove("ANTHROPIC_API_KEY")
    [void]$startInfo.Environment.Remove("OPENAI_API_KEY")

    $process = [System.Diagnostics.Process]::Start($startInfo)
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

Export-ModuleMember -Function Invoke-ScheduledAgentJob, Invoke-AgentCommand
