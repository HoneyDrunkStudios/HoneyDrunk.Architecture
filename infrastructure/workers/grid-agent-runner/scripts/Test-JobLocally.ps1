param(
    [Parameter(Mandatory = $true)]
    [string]$JobId,

    [string]$ConfigPath,

    [switch]$InvokeAgents
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-Psd1Literal {
    param([string]$Value)

    return "'" + $Value.Replace("'", "''") + "'"
}

$runnerRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $runnerRoot "../../..")).Path

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $runtimeRoot = Join-Path ([System.IO.Path]::GetTempPath()) "HoneyDrunkGridAgentRunnerSmoke"
    $candidateLorePaths = @(
        (Join-Path (Split-Path -Parent $repoRoot) "HoneyDrunk.Lore"),
        (Join-Path (Split-Path -Parent (Split-Path -Parent $repoRoot)) "HoneyDrunk.Lore")
    )

    $lorePath = $candidateLorePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($lorePath)) {
        $lorePath = Join-Path (Split-Path -Parent $repoRoot) "HoneyDrunk.Lore"
    }

    $ConfigPath = Join-Path $runtimeRoot "host.smoke.psd1"
    New-Item -ItemType Directory -Force -Path $runtimeRoot | Out-Null

    $architecturePathLiteral = ConvertTo-Psd1Literal -Value $repoRoot
    $lorePathLiteral = ConvertTo-Psd1Literal -Value $lorePath
    $runtimePathLiteral = ConvertTo-Psd1Literal -Value $runtimeRoot

    @"
@{
    HostId = 'smoke:$env:COMPUTERNAME:$PID'
    RuntimeRoot = $runtimePathLiteral
    Repositories = @{
        'HoneyDrunk.Architecture' = $architecturePathLiteral
        'HoneyDrunk.Lore' = $lorePathLiteral
    }
    Vault = @{
        Name = 'smoke-only'
        AzCliPath = 'az'
    }
}
"@ | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $runnerRoot "Invoke-GridAgentRunner.ps1"),
    "-JobId", $JobId,
    "-ConfigPath", $ConfigPath,
    "-Once"
)

if (-not $InvokeAgents) {
    $arguments += "-DryRun"
}

& pwsh @arguments
exit $LASTEXITCODE
