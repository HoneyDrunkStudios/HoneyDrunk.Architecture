function Invoke-WithRunnerLock {
    param(
        [hashtable]$HostConfig,
        [hashtable]$JobSpec,
        [scriptblock]$ScriptBlock
    )

    $lockName = ($JobSpec.ConcurrencyKey -replace "[^A-Za-z0-9_.-]", "_") + ".lock"
    $lockPath = Join-Path $HostConfig.LockRoot $lockName
    $lockStream = $null

    try {
        $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $metadata = [System.Text.Encoding]::UTF8.GetBytes("pid=$PID host=$($HostConfig.HostId) started=$((Get-Date).ToUniversalTime().ToString('o'))")
        $lockStream.SetLength(0)
        $lockStream.Write($metadata, 0, $metadata.Length)
        $lockStream.Flush()

        & $ScriptBlock $HostConfig $JobSpec
    }
    catch [System.IO.IOException] {
        throw "Job '$($JobSpec.JobId)' is already running or lock '$lockPath' is held."
    }
    finally {
        if ($null -ne $lockStream) {
            $lockStream.Dispose()
        }

        Remove-Item -LiteralPath $lockPath -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Invoke-WithRunnerLock
