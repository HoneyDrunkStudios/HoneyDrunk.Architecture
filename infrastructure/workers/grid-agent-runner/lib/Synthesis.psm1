function Join-ReviewFindings {
    param(
        [string]$CodexVerdictPath,
        [string]$ClaudeVerdictPath
    )

    $parts = @()
    if (Test-Path -LiteralPath $CodexVerdictPath) {
        $parts += "## Codex findings"
        $parts += (Get-Content -LiteralPath $CodexVerdictPath -Raw)
    }

    if (Test-Path -LiteralPath $ClaudeVerdictPath) {
        $parts += "## Claude findings"
        $parts += (Get-Content -LiteralPath $ClaudeVerdictPath -Raw)
    }

    if ($parts.Count -eq 0) {
        return "No raw review findings were available for synthesis."
    }

    return ($parts -join [Environment]::NewLine)
}

Export-ModuleMember -Function Join-ReviewFindings
