function Initialize-RunnerDirectories {
    param([hashtable]$HostConfig)

    foreach ($key in @("RuntimeRoot", "LogRoot", "StateRoot", "CacheRoot", "LockRoot", "ArtifactRoot")) {
        if (-not $HostConfig.ContainsKey($key)) {
            throw "Host config is missing '$key'."
        }

        New-Item -ItemType Directory -Force -Path $HostConfig[$key] | Out-Null
    }
}

function New-RunnerLogger {
    param(
        [hashtable]$HostConfig,
        [string]$JobId
    )

    $logPath = Join-Path $HostConfig.LogRoot "$JobId.log"
    return @{
        JobId = $JobId
        Path = $logPath
        HostId = $HostConfig.HostId
    }
}

function Write-RunnerLog {
    param(
        [hashtable]$Logger,
        [ValidateSet("DEBUG", "INFO", "WARN", "ERROR")]
        [string]$Level,
        [string]$Message,
        [hashtable]$Data = @{}
    )

    $entry = [ordered]@{
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        level = $Level
        job_id = $Logger.JobId
        host_id = $Logger.HostId
        message = $Message
    }

    if ($Data.Count -gt 0) {
        $entry.data = Redact-RunnerLogData -Data $Data
    }

    ($entry | ConvertTo-Json -Depth 8 -Compress) | Add-Content -Path $Logger.Path -Encoding UTF8
}

function Redact-RunnerLogData {
    param([hashtable]$Data)

    $redacted = @{}
    foreach ($key in $Data.Keys) {
        if ($key -match "(?i)(secret|token|key|password|private)") {
            $redacted[$key] = "[redacted]"
        }
        else {
            $redacted[$key] = $Data[$key]
        }
    }

    return $redacted
}

Export-ModuleMember -Function Initialize-RunnerDirectories, New-RunnerLogger, Write-RunnerLog
